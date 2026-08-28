import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/recent_files_service.dart';
import 'models/pcb_models.dart';
import 'parser/gerber_parser.dart';
import 'parser/drill_parser.dart';
import 'parser/pcb_archive_parser.dart';
import '../kicad_viewer/parser/kicad_pcb_parser.dart';
import '../kicad_viewer/parser/kicad_sch_parser.dart';
import 'rendering/pcb_multi_layer_painter.dart';

/// PCB Multi-Layer Project & Gerber/Drill Viewer Screen.
/// Supports Proteus ARES ZIP archives, Altium, KiCad, Eagle, EasyEDA, and individual Gerber/Drill files.
class PcbViewerScreen extends StatefulWidget {
  final String filePath;

  const PcbViewerScreen({super.key, required this.filePath});

  @override
  State<PcbViewerScreen> createState() => _PcbViewerScreenState();
}

class _PcbViewerScreenState extends State<PcbViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;

  PcbProject? _project;
  PcbTheme _pcbTheme = PcbTheme.fr4Green;
  bool _showGrid = true;
  int _selectedImageIndex = 0;
  String _bomSearchQuery = '';

  final TransformationController _transformController = TransformationController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadPcbFile();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadPcbFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File not found: ${widget.filePath}');
      }

      _fileSizeBytes = await file.length();
      final bytes = await file.readAsBytes();

      final lower = _fileName.toLowerCase();
      PcbProject project;

      // 1. Check if it's a ZIP archive containing PCB files, images, or BOM
      if (lower.endsWith('.zip') || PcbArchiveParser.isPcbZip(bytes, fileName: _fileName)) {
        project = PcbArchiveParser.parseZip(
          bytes,
          archiveName: _fileName,
          filePath: widget.filePath,
        );

        if (project.layers.isEmpty && project.images.isEmpty && project.bomEntries.isEmpty && project.archiveFiles.isEmpty) {
          throw Exception('The archive is empty or contains no readable files.');
        }
      }
      // 2. KiCad Schematics / Symbols
      else if (lower.endsWith('.kicad_sch') || lower.endsWith('.sch') || lower.endsWith('.kicad_sym')) {
        final doc = KicadSchParser.parse(bytes, fileName: _fileName);
        project = _wrapSingleDocument(doc);
      }
      // 3. KiCad PCB / Board
      else if (lower.endsWith('.kicad_pcb') || lower.endsWith('.brd')) {
        final doc = KicadPcbParser.parse(bytes, fileName: _fileName);
        project = _wrapSingleDocument(doc);
      }
      // 4. CNC Drill Files (Excellon)
      else if (lower.endsWith('.drl') ||
          lower.endsWith('.xln') ||
          lower.endsWith('.exc') ||
          lower.endsWith('.drd')) {
        final doc = DrillParser.parse(bytes, fileName: _fileName);
        project = _wrapSingleDocument(doc);
      }
      // 5. Single Gerber Layer
      else {
        final doc = GerberParser.parse(bytes, fileName: _fileName);
        project = _wrapSingleDocument(doc);
      }

      if (mounted) {
        setState(() {
          _project = project;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitToScreen();
        });
      }
    } catch (e) {
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error reading PCB project: $e';
          _isLoading = false;
        });
      }
    }
  }

  PcbProject _wrapSingleDocument(PcbDocument doc) {
    return PcbProject(
      projectName: _fileName,
      sourcePath: widget.filePath,
      layers: [
        PcbLayerItem(
          fileName: _fileName,
          type: doc.layerType,
          document: doc,
          order: 50,
        ),
      ],
      boundingBox: doc.boundingBox,
      viewSide: doc.layerType == PcbLayerType.copperBottom ||
              doc.layerType == PcbLayerType.solderMaskBottom ||
              doc.layerType == PcbLayerType.silkscreenBottom
          ? PcbViewSide.bottom
          : PcbViewSide.top,
    );
  }

  Size _viewportSize = Size.zero;
  bool _hasInitialFitted = false;

  void _fitToScreen() {
    if (_project == null || _viewportSize.isEmpty) {
      return;
    }

    final double contentW = math.max(50.0, (_project!.boundingBox.widthMm * 10.0) + 48.0);
    final double contentH = math.max(50.0, (_project!.boundingBox.heightMm * 10.0) + 48.0);

    const double padding = 40.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);

    final double scale = math.min(availW / contentW, availH / contentH).clamp(0.01, 100.0);

    final double dx = (_viewportSize.width - contentW * scale) / 2.0;
    final double dy = (_viewportSize.height - contentH * scale) / 2.0;

    final matrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale, scale);

    _transformController.value = matrix;
    _hasInitialFitted = true;
  }

  void _zoomIn() {
    _zoomBy(1.3);
  }

  void _zoomOut() {
    _zoomBy(1 / 1.3);
  }

  void _zoomBy(double factor, {Offset? focalPoint}) {
    if (_viewportSize.isEmpty) return;

    final targetPoint = focalPoint ?? Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final currentMatrix = _transformController.value;

    final translation = currentMatrix.getTranslation();
    final scale = currentMatrix.getMaxScaleOnAxis();

    final newScale = (scale * factor).clamp(0.002, 2000.0);

    final dx = targetPoint.dx - (targetPoint.dx - translation.x) * (newScale / scale);
    final dy = targetPoint.dy - (targetPoint.dy - translation.y) * (newScale / scale);

    final newMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(newScale);

    _transformController.value = newMatrix;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final double zoomFactor = event.scrollDelta.dy < 0 ? 1.15 : 0.85;
      _zoomBy(zoomFactor, focalPoint: event.localPosition);
    }
  }

  void _handlePointerPan(PointerMoveEvent event) {
    if (event.buttons == kTertiaryButton) {
      final Matrix4 matrix = _transformController.value.clone();
      matrix.translate(event.delta.dx, event.delta.dy);
      setState(() {
        _transformController.value = matrix;
      });
    }
  }

  void _showLayersSheet() {
    if (_project == null) return;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.35,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.layers_rounded, color: Color(0xFF059669)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PCB Layers Management',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${_project!.visibleLayers} of ${_project!.totalLayers} layers visible',
                                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              final allVisible = _project!.layers.every((l) => l.isVisible);
                              setState(() {
                                for (final l in _project!.layers) {
                                  l.isVisible = !allVisible;
                                }
                              });
                              setSheetState(() {});
                            },
                            child: Text(_project!.layers.every((l) => l.isVisible) ? 'Hide All' : 'Show All'),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: _project!.layers.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final layer = _project!.layers[index];
                            final doc = layer.document;

                            return CheckboxListTile(
                              value: layer.isVisible,
                              activeColor: const Color(0xFF059669),
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setState(() {
                                  layer.isVisible = val ?? true;
                                });
                                setSheetState(() {});
                              },
                              secondary: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: layer.type.defaultAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24, width: 1.5),
                                ),
                              ),
                              title: Text(
                                layer.displayName,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${doc.trackCount > 0 ? "${doc.trackCount} tracks • " : ""}'
                                '${doc.padCount > 0 ? (layer.type == PcbLayerType.drill ? "${doc.padCount} drill holes" : "${doc.padCount} pads • ") : ""}'
                                '${doc.holeCount > 0 ? "${doc.holeCount} holes" : ""}'
                                '${(doc.trackCount == 0 && doc.padCount == 0 && doc.holeCount == 0) ? "Empty layer" : ""}',
                                style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showImagesSheet() {
    if (_project == null) return;
    final theme = Theme.of(context);
    final images = _project!.images;

    if (images.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Архивни Изображения (${images.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      final img = images[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              child: Text(
                                img.fileName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Image.memory(
                              img.bytes,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBomSheet() {
    if (_project == null) return;
    final theme = Theme.of(context);
    final bom = _project!.bomEntries;

    if (bom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Bill of Materials (BOM) file found in this archive.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredBom = bom.where((e) {
              final q = searchQuery.toLowerCase();
              return e.designator.toLowerCase().contains(q) ||
                  e.value.toLowerCase().contains(q) ||
                  e.footprint.toLowerCase().contains(q) ||
                  e.description.toLowerCase().contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.40,
              maxChildSize: 0.90,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.list_alt_rounded, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bill of Materials (BOM)',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${_project!.totalComponents} total parts • ${bom.length} items',
                                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search designator, value, package (e.g. R1, 10k)...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          setSheetState(() => searchQuery = val);
                        },
                      ),
                      const Divider(height: 20),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filteredBom.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filteredBom[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.designator,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.value.isNotEmpty ? item.value : item.description,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '×${item.quantity}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              subtitle: item.footprint.isNotEmpty
                                  ? Text(
                                      'Package: ${item.footprint}${item.description.isNotEmpty ? " • ${item.description}" : ""}',
                                      style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showInfoSheet() {
    if (_project == null) return;
    final theme = Theme.of(context);
    final bounds = _project!.boundingBox;

    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    int totalTracks = 0;
    int totalPads = 0;
    int totalHoles = 0;
    for (final l in _project!.layers) {
      totalTracks += l.document.trackCount;
      totalPads += l.document.padCount;
      totalHoles += l.document.holeCount;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.memory_rounded, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PCB Project • Specifications',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _project!.projectName,
                          style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_project!.layers.isNotEmpty)
                _buildInfoRow('Project Layers:', '${_project!.totalLayers} layers (${_project!.visibleLayers} visible)'),
              _buildInfoRow('File Archive Size:', formattedSize),
              if (_project!.archiveFiles.isNotEmpty)
                _buildInfoRow('Files in Archive:', '${_project!.archiveFiles.length} files'),
              if (_project!.images.isNotEmpty)
                _buildInfoRow('Archive Images:', '${_project!.images.length} images'),
              if (_project!.layers.isNotEmpty) ...[
                _buildInfoRow(
                  'Board Dimensions (mm):',
                  '${bounds.widthMm.toStringAsFixed(2)} × ${bounds.heightMm.toStringAsFixed(2)} mm',
                ),
                _buildInfoRow(
                  'Board Dimensions (in):',
                  '${bounds.widthInches.toStringAsFixed(2)}" × ${bounds.heightInches.toStringAsFixed(2)}"',
                ),
              ],
              if (_project!.bomEntries.isNotEmpty)
                _buildInfoRow('BOM Components:', '${_project!.totalComponents} parts (${_project!.bomEntries.length} items)'),
              if (totalTracks > 0) _buildInfoRow('Total Traces & Tracks:', '$totalTracks lines/arcs'),
              if (totalPads > 0) _buildInfoRow('Total Component Pads:', '$totalPads pads'),
              if (totalHoles > 0) _buildInfoRow('Total Drill Holes / Vias:', '$totalHoles holes'),
            ],
          ),
        );
      },
    );
  }

  void _showArchiveFilesSheet() {
    if (_project == null || _project!.archiveFiles.isEmpty) return;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_zip_outlined, color: Color(0xFF059669)),
                      const SizedBox(width: 10),
                      Text(
                        'Archive Files (${_project!.archiveFiles.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _project!.archiveFiles.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final file = _project!.archiveFiles[index];
                      return ListTile(
                        leading: Icon(
                          _getFileIcon(file.fileName),
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          file.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        trailing: Text(
                          file.formattedSize,
                          style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getFileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.bmp')) {
      return Icons.image_outlined;
    }
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls') || lower.endsWith('.csv') || lower.contains('bom')) {
      return Icons.table_chart_outlined;
    }
    if (lower.endsWith('.gbr') || lower.endsWith('.gtl') || lower.endsWith('.gbl') || lower.endsWith('.drl')) {
      return Icons.memory_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _shareFile() {
    Share.shareXFiles([XFile(widget.filePath)], subject: _fileName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (_errorMessage != null) {
          RecentFilesService.removeRecentFile(widget.filePath);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_errorMessage != null) {
                RecentFilesService.removeRecentFile(widget.filePath);
              }
              Navigator.of(context).pop(_errorMessage == null);
            },
          ),
          title: Text(
            _project?.projectName ?? _fileName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Spacer(),

                  // Layers Drawer Button (only if project has layers)
                  if (_project != null && _project!.layers.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.layers_outlined, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      tooltip: 'PCB Layers (${_project?.visibleLayers ?? 0}/${_project?.totalLayers ?? 0})',
                      onPressed: _showLayersSheet,
                    ),

                  // Images Button (if project has images)
                  if (_project != null && _project!.images.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.image_outlined, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      tooltip: 'Images (${_project!.images.length})',
                      onPressed: _showImagesSheet,
                    ),

                  // BOM Button (if project has BOM)
                  if (_project != null && _project!.bomEntries.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.list_alt_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      tooltip: 'Bill of Materials (${_project!.bomEntries.length})',
                      onPressed: _showBomSheet,
                    ),

                  // Archive Files Button (if multiple files in archive)
                  if (_project != null && _project!.archiveFiles.length > 1)
                    IconButton(
                      icon: const Icon(Icons.folder_zip_outlined, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      tooltip: 'Archive Contents (${_project!.archiveFiles.length})',
                      onPressed: _showArchiveFilesSheet,
                    ),

                  // Theme Menu (only if layers exist)
                  if (_project != null && _project!.layers.isNotEmpty)
                    PopupMenuButton<PcbTheme>(
                      icon: const Icon(Icons.palette_outlined, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      tooltip: 'PCB Canvas Theme',
                      onSelected: (t) => setState(() => _pcbTheme = t),
                      itemBuilder: (context) => PcbTheme.values.map((t) {
                        return PopupMenuItem<PcbTheme>(
                          value: t,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: t.substrate,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: t.copper, width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(t.label),
                              if (_pcbTheme == t) ...[
                                const Spacer(),
                                Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  // Grid Toggle (only if layers exist)
                  if (_project != null && _project!.layers.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        _showGrid ? Icons.grid_on : Icons.grid_off,
                        size: 20,
                        color: _showGrid ? theme.colorScheme.primary : null,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      tooltip: '1mm PCB Measurement Grid',
                      onPressed: () => setState(() => _showGrid = !_showGrid),
                    ),

                  // Information Sheet
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: 'Board / Archive Properties',
                    onPressed: _showInfoSheet,
                  ),

                  // Share
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: 'Share',
                    onPressed: _shareFile,
                  ),
                ],
              ),
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
            if (!_hasInitialFitted && _project != null && !_viewportSize.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fitToScreen();
              });
            }

            if (_isLoading) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF059669)),
                    SizedBox(height: 16),
                    Text('Analyzing and Combining PCB Layers...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              );
            }

            if (_errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadPcbFile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_project == null) {
              return const SizedBox.shrink();
            }

            // Standalone Archive View (when no CAD Gerber/Drill layers exist)
            if (_project!.layers.isEmpty) {
              if (_project!.images.isNotEmpty) {
                return _buildImageGalleryView(theme);
              } else if (_project!.bomEntries.isNotEmpty) {
                return _buildDirectBomView(theme);
              } else {
                return _buildArchiveFileExplorerView(theme);
              }
            }

            final double canvasW = math.max(50.0, (_project!.boundingBox.widthMm * 10.0) + 48.0);
            final double canvasH = math.max(50.0, (_project!.boundingBox.heightMm * 10.0) + 48.0);

            return Stack(
              children: [
                // Interactive Canvas with Mouse Pan and Wheel Zoom
                Listener(
                  onPointerSignal: _handlePointerSignal,
                  onPointerMove: _handlePointerPan,
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.002,
                    maxScale: 2000.0,
                    boundaryMargin: const EdgeInsets.all(2500.0),
                    child: Center(
                      child: CustomPaint(
                        size: Size(canvasW, canvasH),
                        painter: PcbMultiLayerPainter(
                          project: _project!,
                          theme: _pcbTheme,
                          showGrid: _showGrid,
                          scaleFactor: 10.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Floating Side Switcher (TOP / BOTTOM / ALL)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: SegmentedButton<PcbViewSide>(
                      segments: const [
                        ButtonSegment(
                          value: PcbViewSide.top,
                          label: Text('TOP', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          icon: Icon(Icons.flip_to_front, size: 14),
                        ),
                        ButtonSegment(
                          value: PcbViewSide.bottom,
                          label: Text('BOTTOM', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          icon: Icon(Icons.flip_to_back, size: 14),
                        ),
                        ButtonSegment(
                          value: PcbViewSide.composite,
                          label: Text('ALL', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          icon: Icon(Icons.view_carousel_outlined, size: 14),
                        ),
                      ],
                      selected: {_project!.viewSide},
                      onSelectionChanged: (newSet) {
                        setState(() {
                          _project!.viewSide = newSet.first;
                        });
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),

                // Floating Zoom Controls
                Positioned(
                  bottom: 24,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFloatingButton(
                        icon: Icons.add,
                        tooltip: 'Zoom In (+)',
                        onTap: _zoomIn,
                        theme: theme,
                      ),
                      const SizedBox(height: 8),
                      _buildFloatingButton(
                        icon: Icons.remove,
                        tooltip: 'Zoom Out (-)',
                        onTap: _zoomOut,
                        theme: theme,
                      ),
                      const SizedBox(height: 8),
                      _buildFloatingButton(
                        icon: Icons.fit_screen_outlined,
                        tooltip: 'Fit Board to View (Center)',
                        onTap: _fitToScreen,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageGalleryView(ThemeData theme) {
    if (_project == null || _project!.images.isEmpty) return const SizedBox.shrink();
    if (_selectedImageIndex >= _project!.images.length) _selectedImageIndex = 0;
    final currentImg = _project!.images[_selectedImageIndex];

    return Column(
      children: [
        // Top status / selector bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              const Icon(Icons.image_outlined, size: 20, color: Color(0xFF059669)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  currentImg.fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedImageIndex + 1} / ${_project!.images.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Main Image Area with Interactive Pan & Zoom
        Expanded(
          child: Container(
            color: Colors.black87,
            child: InteractiveViewer(
              minScale: 0.2,
              maxScale: 10.0,
              boundaryMargin: const EdgeInsets.all(500),
              child: Center(
                child: Image.memory(
                  currentImg.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Could not load image', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Bottom Thumbnail strip if multiple images
        if (_project!.images.length > 1)
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: theme.colorScheme.surface,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _project!.images.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final img = _project!.images[index];
                final isSelected = index == _selectedImageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedImageIndex = index),
                  child: Container(
                    width: 74,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : Colors.grey.withValues(alpha: 0.3),
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(img.bytes, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDirectBomView(ThemeData theme) {
    final bom = _project!.bomEntries;
    final filteredBom = bom.where((e) {
      final q = _bomSearchQuery.toLowerCase();
      return e.designator.toLowerCase().contains(q) ||
          e.value.toLowerCase().contains(q) ||
          e.footprint.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              const Icon(Icons.list_alt_rounded, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Text(
                'Bill of Materials (${bom.length} items, ${_project!.totalComponents} parts)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.colorScheme.surface,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search designator, value, package (e.g. R1, 10k)...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() => _bomSearchQuery = val);
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filteredBom.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = filteredBom[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.designator,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.value.isNotEmpty ? item.value : item.description,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '×${item.quantity}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                subtitle: item.footprint.isNotEmpty
                    ? Text(
                        'Package: ${item.footprint}${item.description.isNotEmpty ? " • ${item.description}" : ""}',
                        style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveFileExplorerView(ThemeData theme) {
    final files = _project!.archiveFiles;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              const Icon(Icons.folder_zip_outlined, size: 20, color: Color(0xFF059669)),
              const SizedBox(width: 10),
              Text(
                'Archive Files (${files.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: files.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final file = files[index];
              return ListTile(
                leading: Icon(_getFileIcon(file.fileName), color: theme.colorScheme.primary),
                title: Text(file.fileName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                trailing: Text(file.formattedSize, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}
