import 'dart:io';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/file_opener_service.dart';
import '../../core/services/recent_files_service.dart';
import 'models/pcb_models.dart';
import 'parser/gerber_parser.dart';
import 'parser/drill_parser.dart';
import 'parser/pcb_archive_parser.dart';
import '../kicad_viewer/parser/kicad_pcb_parser.dart';
import '../kicad_viewer/parser/kicad_sch_parser.dart';
import 'rendering/pcb_multi_layer_painter.dart';
import 'services/pcb_pad_numbering_service.dart';
import 'widgets/pcb_image_zoom_dialog.dart';

/// PCB Multi-Layer Project & Gerber/Drill Viewer Screen.
/// Supports Proteus ARES ZIP archives, Altium, KiCad, Eagle, EasyEDA, and individual Gerber/Drill files.
class PcbViewerScreen extends StatefulWidget {
  final String filePath;

  const PcbViewerScreen({super.key, required this.filePath});

  @override
  State<PcbViewerScreen> createState() => _PcbViewerScreenState();
}

enum PcbViewerMode {
  board2D('Gerbers', Icons.layers_outlined),
  images('Photos & Renders', Icons.image_outlined),
  model3D('3D Models', Icons.view_in_ar_outlined),
  bom('BOM & Parts', Icons.list_alt_rounded),
  schematics('Schematics', Icons.schema_outlined),
  docs('Docs & Reports', Icons.picture_as_pdf_outlined),
  allFiles('All Files', Icons.folder_zip_outlined);

  final String label;
  final IconData icon;
  const PcbViewerMode(this.label, this.icon);
}

class _PcbViewerScreenState extends State<PcbViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;

  PcbProject? _project;
  PcbTheme _pcbTheme = PcbTheme.fr4Green;
  bool _showGrid = true;
  bool _showPadNumbers = true;
  int _selectedImageIndex = 0;
  String _bomSearchQuery = '';
  String _archiveSearchQuery = '';
  PcbFileCategory? _archiveFilterCategory;
  PcbViewerMode _activeMode = PcbViewerMode.board2D;

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
        final l10n = mounted ? AppLocalizations.of(context) : null;
        if (mounted) {
          setState(() {
            _errorMessage = l10n?.fileNotFoundOrInaccessible ?? 'File not found: ${widget.filePath}';
            _isLoading = false;
          });
        }
        return;
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
          throw const FormatException('The archive is empty or contains no readable files.');
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
      // 5. Standalone BOM or CSV File
      else if (lower.endsWith('.bom') || lower.endsWith('.csv')) {
        final bomEntries = PcbArchiveParser.parseBom(bytes, _fileName);
        if (bomEntries.isEmpty) {
          throw const FormatException('The BOM file is empty or unsupported format.');
        }
        project = PcbProject(
          projectName: _fileName.replaceAll(RegExp(r'\.(bom|csv)$', caseSensitive: false), ''),
          sourcePath: widget.filePath,
          layers: [],
          boundingBox: PcbBoundingBox.defaultBox,
          bomEntries: bomEntries,
          images: [],
          archiveFiles: [],
          viewSide: PcbViewSide.top,
        );
      }
      // 6. Single Gerber Layer
      else {
        final doc = GerberParser.parse(bytes, fileName: _fileName);
        project = _wrapSingleDocument(doc);
      }

      if (mounted) {
        setState(() {
          _project = project;
          _isLoading = false;
          if (project.layers.isNotEmpty) {
            _activeMode = PcbViewerMode.board2D;
          } else if (project.images.isNotEmpty) {
            _activeMode = PcbViewerMode.images;
          } else if (project.model3DFiles.isNotEmpty) {
            _activeMode = PcbViewerMode.model3D;
          } else if (project.bomEntries.isNotEmpty) {
            _activeMode = PcbViewerMode.bom;
          } else if (project.schematicFiles.isNotEmpty) {
            _activeMode = PcbViewerMode.schematics;
          } else if (project.documentFiles.isNotEmpty || project.reportFiles.isNotEmpty) {
            _activeMode = PcbViewerMode.docs;
          } else {
            _activeMode = PcbViewerMode.allFiles;
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitToScreen();
        });
      }
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'PcbViewer._loadPcbFile.fs');
      try {
        await RecentFilesService.removeRecentFile(widget.filePath);
      } on Exception catch (_) {
        // Ignore recent files cleanup failure
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage = l10n?.fileNotFoundOrInaccessible ?? 'File not found or cannot be accessed.';
          _isLoading = false;
        });
      }
    } on ArchiveException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'PcbViewer._loadPcbFile.archive');
      try {
        await RecentFilesService.removeRecentFile(widget.filePath);
      } on Exception catch (_) {
        // Ignore recent files cleanup failure
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage = l10n?.errorReadingPcb(e.message) ?? 'Error reading PCB project: ${e.message}';
          _isLoading = false;
        });
      }
    } on FormatException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'PcbViewer._loadPcbFile.format');
      try {
        await RecentFilesService.removeRecentFile(widget.filePath);
      } on Exception catch (_) {
        // Ignore recent files cleanup failure
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage = l10n?.errorReadingPcb(e.message) ?? 'Error reading PCB project: ${e.message}';
          _isLoading = false;
        });
      }
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'PcbViewer._loadPcbFile');
      try {
        await RecentFilesService.removeRecentFile(widget.filePath);
      } on Exception catch (_) {
        // Ignore recent files cleanup failure
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage = l10n?.errorReadingPcb(e.toString()) ?? 'Error reading PCB project: $e';
          _isLoading = false;
        });
      }
    }
  }

  PcbProject _wrapSingleDocument(PcbDocument doc) {
    final proj = PcbProject(
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
    return PcbPadNumberingService.assignPadNumbers(proj);
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Archive Images (${images.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.zoom_in, size: 18),
                        label: const Text('Interactive Zoom'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          PcbImageZoomDialog.show(context, images: images, initialIndex: 0);
                        },
                      ),
                    ],
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
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      img.fileName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.zoom_in, size: 20),
                                    tooltip: 'Zoom in (Приближаване)',
                                    onPressed: () {
                                      Navigator.pop(context);
                                      PcbImageZoomDialog.show(context, images: images, initialIndex: index);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                PcbImageZoomDialog.show(context, images: images, initialIndex: index);
                              },
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Image.memory(
                                    img.bytes,
                                    fit: BoxFit.contain,
                                    errorBuilder: (ctx, err, stack) => const Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.zoom_in, size: 14, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'Tap to zoom',
                                          style: TextStyle(color: Colors.white, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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



  Future<void> _openArchiveFile(PcbArchiveFileItem file) async {
    final pdfItem = PdfItem.fromPath(file.fileName);
    if (pdfItem.fileType == KotoFileType.other || pdfItem.fileType == KotoFileType.zip) {
      _showUnsupportedSnackbar(file);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.extractingFile(file.fileName)),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final baseName = file.fileName.split(RegExp(r'[\\/]')).last;
      final tempFile = File('${tempDir.path}/koto_extracted/$baseName');
      await tempFile.parent.create(recursive: true);
      await tempFile.writeAsBytes(file.bytes);

      if (!mounted) return;
      await FileOpenerService.openFile(
        context: context,
        filePath: tempFile.path,
        addToRecent: false,
      );
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'PcbViewer._openArchiveFile');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening ${file.fileName}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showUnsupportedSnackbar(PcbArchiveFileItem file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.unsupportedArchiveFormat),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () {
            Share.shareXFiles([XFile.fromData(file.bytes, name: file.fileName)]);
          },
        ),
      ),
    );
  }

  Widget _buildArchiveFileItemWidget(PcbArchiveFileItem file, ThemeData theme) {
    final pdfItem = PdfItem.fromPath(file.fileName);
    final isSupported = pdfItem.fileType != KotoFileType.other && pdfItem.fileType != KotoFileType.zip;
    final typeLabel = isSupported ? _getFileTypeLabel(pdfItem.fileType) : null;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSupported
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          _getFileIcon(file.fileName),
          color: isSupported ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          size: 22,
        ),
      ),
      title: Text(
        file.fileName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Row(
        children: [
          Text(
            file.formattedSize,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (typeLabel != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: isSupported
          ? IconButton(
              icon: Icon(Icons.open_in_new, size: 20, color: theme.colorScheme.primary),
              tooltip: context.l10n.openArchiveFile,
              onPressed: () => _openArchiveFile(file),
            )
          : IconButton(
              icon: Icon(Icons.share_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
              tooltip: 'Share',
              onPressed: () {
                Share.shareXFiles([XFile.fromData(file.bytes, name: file.fileName)]);
              },
            ),
      onTap: isSupported ? () => _openArchiveFile(file) : () => _showUnsupportedSnackbar(file),
    );
  }

  IconData _getFileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.ico')) {
      return Icons.image_outlined;
    }
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.docx') || lower.endsWith('.doc') || lower.endsWith('.rtf')) {
      return Icons.description_outlined;
    }
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls') || lower.endsWith('.csv') || lower.contains('bom')) {
      return Icons.table_chart_outlined;
    }
    if (lower.endsWith('.txt') || lower.endsWith('.log')) {
      return Icons.article_outlined;
    }
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
      return Icons.text_snippet_outlined;
    }
    if (lower.endsWith('.dxf') || lower.endsWith('.dwg')) {
      return Icons.architecture_outlined;
    }
    if (lower.endsWith('.step') ||
        lower.endsWith('.stp') ||
        lower.endsWith('.iges') ||
        lower.endsWith('.igs') ||
        lower.endsWith('.stl') ||
        lower.endsWith('.obj') ||
        lower.endsWith('.ifc')) {
      return Icons.view_in_ar_outlined;
    }
    if (lower.endsWith('.gbr') ||
        lower.endsWith('.gtl') ||
        lower.endsWith('.gbl') ||
        lower.endsWith('.drl') ||
        lower.endsWith('.kicad_sch') ||
        lower.endsWith('.kicad_pcb')) {
      return Icons.memory_outlined;
    }
    if (lower.endsWith('.epub') || lower.endsWith('.fb2')) {
      return Icons.auto_stories_outlined;
    }
    if (lower.endsWith('.gpx') ||
        lower.endsWith('.kml') ||
        lower.endsWith('.kmz') ||
        lower.endsWith('.geojson')) {
      return Icons.route_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _getFileTypeLabel(KotoFileType type) {
    switch (type) {
      case KotoFileType.pdf:
        return 'PDF';
      case KotoFileType.docx:
      case KotoFileType.rtf:
        return 'Word Document';
      case KotoFileType.xlsx:
        return 'Spreadsheet';
      case KotoFileType.csv:
        return 'CSV Data';
      case KotoFileType.txt:
        return 'Text File';
      case KotoFileType.md:
        return 'Markdown';
      case KotoFileType.dxf:
      case KotoFileType.dwg:
        return 'CAD Drawing';
      case KotoFileType.image:
        return 'Image';
      case KotoFileType.step:
      case KotoFileType.iges:
      case KotoFileType.ifc:
      case KotoFileType.fbx:
      case KotoFileType.threeMf:
        return '3D Model';
      case KotoFileType.kicad:
        return 'KiCad Circuit';
      case KotoFileType.code:
        return 'Code / Config';
      case KotoFileType.epub:
      case KotoFileType.fb2:
        return 'E-Book';
      case KotoFileType.gpx:
      case KotoFileType.kml:
      case KotoFileType.kmz:
      case KotoFileType.geojson:
        return 'GPS Route';
      case KotoFileType.font:
        return 'Font';
      case KotoFileType.svg:
        return 'SVG Vector';
      case KotoFileType.plt:
        return 'HPGL Plot';
      case KotoFileType.dicom:
        return 'DICOM Medical';
      default:
        return 'File';
    }
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
        backgroundColor: (_activeMode == PcbViewerMode.board2D && _project != null && _project!.layers.isNotEmpty)
            ? (isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B))
            : theme.scaffoldBackgroundColor,
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
          actions: [
            if (_activeMode == PcbViewerMode.board2D && _project != null && _project!.layers.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.layers_outlined, size: 20),
                tooltip: 'PCB Layers (${_project?.visibleLayers ?? 0}/${_project?.totalLayers ?? 0})',
                onPressed: _showLayersSheet,
              ),
              _buildThemeMenu(theme),
              IconButton(
                icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off, size: 20),
                tooltip: '1mm Measurement Grid',
                onPressed: () => setState(() => _showGrid = !_showGrid),
              ),
              if (_project!.hasPadNumbers)
                IconButton(
                  icon: Icon(_showPadNumbers ? Icons.tag : Icons.tag_outlined, size: 20),
                  tooltip: 'Toggle Pad Numbers',
                  onPressed: () => setState(() => _showPadNumbers = !_showPadNumbers),
                ),
            ],
            IconButton(
              icon: const Icon(Icons.info_outline, size: 20),
              tooltip: 'Board / Archive Properties',
              onPressed: _showInfoSheet,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              tooltip: 'Share',
              onPressed: _shareFile,
            ),
          ],
          bottom: _buildAppBarBottom(theme, isDark),
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
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF059669)),
                    const SizedBox(height: 16),
                    Text(
                      'Analyzing and Combining PCB Layers...',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
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
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
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

            switch (_activeMode) {
              case PcbViewerMode.board2D:
                return _build2DCanvasView(theme);
              case PcbViewerMode.model3D:
                return _buildModel3DView(theme);
              case PcbViewerMode.schematics:
                return _buildSchematicsView(theme);
              case PcbViewerMode.images:
                return _buildImageGalleryView(theme);
              case PcbViewerMode.bom:
                return _buildDirectBomView(theme);
              case PcbViewerMode.docs:
                return _buildDocsView(theme);
              case PcbViewerMode.allFiles:
                return _buildArchiveFileExplorerView(theme);
            }
          },
        ),
      ),
    );
  }

  List<PcbViewerMode> get _availableModes {
    if (_project == null) return const [];
    final modes = <PcbViewerMode>[];
    if (_project!.layers.isNotEmpty) modes.add(PcbViewerMode.board2D);
    if (_project!.images.isNotEmpty) modes.add(PcbViewerMode.images);
    if (_project!.model3DFiles.isNotEmpty) modes.add(PcbViewerMode.model3D);
    if (_project!.bomEntries.isNotEmpty || _project!.assemblyFiles.isNotEmpty) modes.add(PcbViewerMode.bom);
    if (_project!.schematicFiles.isNotEmpty) modes.add(PcbViewerMode.schematics);
    if (_project!.documentFiles.isNotEmpty || _project!.reportFiles.isNotEmpty) modes.add(PcbViewerMode.docs);
    if (_project!.archiveFiles.length > 1) modes.add(PcbViewerMode.allFiles);
    return modes;
  }

  PreferredSizeWidget? _buildAppBarBottom(ThemeData theme, bool isDark) {
    final modes = _availableModes;
    if (modes.length <= 1) {
      if (_project != null && _project!.layers.isNotEmpty) {
        return PreferredSize(
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
                IconButton(
                  icon: const Icon(Icons.layers_outlined, size: 20),
                  tooltip: 'PCB Layers (${_project?.visibleLayers ?? 0}/${_project?.totalLayers ?? 0})',
                  onPressed: _showLayersSheet,
                ),
                _buildThemeMenu(theme),
                IconButton(
                  icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off, size: 20),
                  tooltip: '1mm Measurement Grid',
                  onPressed: () => setState(() => _showGrid = !_showGrid),
                ),
                if (_project!.hasPadNumbers)
                  IconButton(
                    icon: Icon(_showPadNumbers ? Icons.tag : Icons.tag_outlined, size: 20),
                    tooltip: 'Toggle Pad Numbers',
                    onPressed: () => setState(() => _showPadNumbers = !_showPadNumbers),
                  ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  tooltip: 'Board Properties',
                  onPressed: _showInfoSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  tooltip: 'Share',
                  onPressed: _shareFile,
                ),
              ],
            ),
          ),
        );
      }
      return null;
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: modes.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final mode = modes[index];
            final isSelected = mode == _activeMode;
            final count = _getModeCount(mode);

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _activeMode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode.icon,
                      size: 17,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.white12 : Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  int _getModeCount(PcbViewerMode mode) {
    if (_project == null) return 0;
    switch (mode) {
      case PcbViewerMode.board2D:
        return _project!.layers.length;
      case PcbViewerMode.model3D:
        return _project!.model3DFiles.length;
      case PcbViewerMode.schematics:
        return _project!.schematicFiles.length;
      case PcbViewerMode.images:
        return _project!.images.length;
      case PcbViewerMode.bom:
        return _project!.bomEntries.length;
      case PcbViewerMode.docs:
        return _project!.documentFiles.length + _project!.reportFiles.length;
      case PcbViewerMode.allFiles:
        return _project!.archiveFiles.length;
    }
  }

  Widget _buildThemeMenu(ThemeData theme) {
    return PopupMenuButton<PcbTheme>(
      icon: const Icon(Icons.palette_outlined, size: 20),
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
    );
  }

  Widget _build2DCanvasView(ThemeData theme) {
    if (_project == null || _project!.layers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_clear_outlined, size: 48, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'No 2D Gerber or CAD layers available in this project.',
              style: TextStyle(color: Colors.white70),
            ),
            if (_availableModes.length > 1) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.folder_zip_outlined),
                label: const Text('View Archive Files'),
                onPressed: () => setState(() => _activeMode = PcbViewerMode.allFiles),
              ),
            ],
          ],
        ),
      );
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
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: Center(
              child: CustomPaint(
                size: Size(canvasW, canvasH),
                painter: PcbMultiLayerPainter(
                  project: _project!,
                  theme: _pcbTheme,
                  showGrid: _showGrid,
                  showPadNumbers: _showPadNumbers,
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
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
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
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.fullscreen, size: 22),
                tooltip: 'Interactive Zoom Viewer',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => PcbImageZoomDialog.show(
                  context,
                  images: _project!.images,
                  initialIndex: _selectedImageIndex,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Main Image Area with Interactive Pan & Zoom
        Expanded(
          child: Container(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF121212)
                : const Color(0xFFF1F5F9),
            child: InteractiveViewer(
              minScale: 0.2,
              maxScale: 10.0,
              boundaryMargin: const EdgeInsets.all(500),
              child: Center(
                child: Image.memory(
                  currentImg.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('Could not load image', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
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
            color: theme.colorScheme.surface,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 90,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
              ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.colorScheme.surface,
          child: TextField(
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search designator, value, package (e.g. R1, 10k)...',
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.search, size: 20, color: theme.colorScheme.onSurfaceVariant),
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
          child: filteredBom.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(
                        'No components match "$_bomSearchQuery"',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.paddingOf(context).bottom),
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
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '×${item.quantity}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      subtitle: item.footprint.isNotEmpty
                          ? Text(
                              'Package: ${item.footprint}${item.description.isNotEmpty ? " • ${item.description}" : ""}',
                              style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                            )
                          : (item.description.isNotEmpty
                              ? Text(
                                  item.description,
                                  style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                                )
                              : null),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildModel3DView(ThemeData theme) {
    if (_project == null || _project!.model3DFiles.isEmpty) return const SizedBox.shrink();
    final models = _project!.model3DFiles;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.view_in_ar_rounded, color: Color(0xFF3B82F6), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3D CAD Models (${models.length})',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Interactive 3D board assembly and mechanical models',
                    style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...models.map((model) {
          final ext = model.fileName.split('.').last.toUpperCase();
          final baseName = model.fileName.replaceAll('\\', '/').split('/').last;
          return Card(
            color: theme.colorScheme.surface,
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.view_in_ar, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              baseName,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ext,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  model.formattedSize,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.open_in_full_rounded, size: 18),
                          label: const Text('Open in 3D CAD Viewer', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openArchiveFile(model),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: 'Share File',
                        onPressed: () {
                          Share.shareXFiles([XFile.fromData(model.bytes, name: baseName)]);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSchematicsView(ThemeData theme) {
    if (_project == null || _project!.schematicFiles.isEmpty) return const SizedBox.shrink();
    final schematics = _project!.schematicFiles;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schema_rounded, color: Color(0xFF8B5CF6), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Circuit Schematics (${schematics.length})',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Electrical schematics, diagrams and netlists',
                    style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...schematics.map((sch) {
          final isPdf = sch.fileName.toLowerCase().endsWith('.pdf');
          final isKicad = sch.fileName.toLowerCase().endsWith('.kicad_sch');
          final baseName = sch.fileName.replaceAll('\\', '/').split('/').last;

          return Card(
            color: theme.colorScheme.surface,
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (isPdf ? Colors.redAccent : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPdf ? Icons.picture_as_pdf_outlined : Icons.schema_outlined,
                          color: isPdf ? Colors.redAccent : const Color(0xFF8B5CF6),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              baseName,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isPdf ? Colors.red : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isPdf ? 'PDF Schematic' : (isKicad ? 'KiCad Schematic' : 'Schematic'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPdf ? Colors.red[700] : const Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  sch.formattedSize,
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: Icon(isPdf ? Icons.visibility_outlined : Icons.schema_outlined, size: 18),
                          label: Text(
                            isPdf ? 'Open PDF Schematic' : 'View KiCad Schematic',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: isPdf ? const Color(0xFFDC2626) : const Color(0xFF7C3AED),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openArchiveFile(sch),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: 'Share',
                        onPressed: () {
                          Share.shareXFiles([XFile.fromData(sch.bytes, name: baseName)]);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDocsView(ThemeData theme) {
    if (_project == null) return const SizedBox.shrink();
    final docs = _project!.documentFiles;
    final reports = _project!.reportFiles;
    final allDocs = [...docs, ...reports];

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description_outlined, color: Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documentation & Reports (${allDocs.length})',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fabrication drawings, drill maps, manufacturing reports and notes',
                    style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...allDocs.map((doc) {
          final isPdf = doc.fileName.toLowerCase().endsWith('.pdf');
          final isRpt = doc.fileName.toLowerCase().endsWith('.rpt');
          final baseName = doc.fileName.replaceAll('\\', '/').split('/').last;

          return Card(
            color: theme.colorScheme.surface,
            elevation: 1.5,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isPdf ? Colors.redAccent : (isRpt ? Colors.teal : Colors.blueGrey))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPdf
                      ? Icons.picture_as_pdf_outlined
                      : (isRpt ? Icons.assessment_outlined : Icons.description_outlined),
                  color: isPdf ? Colors.redAccent : (isRpt ? Colors.teal : Colors.blueGrey),
                  size: 24,
                ),
              ),
              title: Text(
                baseName,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface),
              ),
              subtitle: Text(
                '${doc.formattedSize} • ${doc.fileName}',
                style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton.filledTonal(
                icon: const Icon(Icons.open_in_new, size: 18),
                tooltip: 'Open',
                onPressed: () => _openArchiveFile(doc),
              ),
              onTap: () => _openArchiveFile(doc),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildArchiveFileExplorerView(ThemeData theme) {
    final allFiles = _project!.archiveFiles;

    final filteredFiles = allFiles.where((file) {
      if (_archiveFilterCategory != null && file.category != _archiveFilterCategory) {
        return false;
      }
      if (_archiveSearchQuery.isNotEmpty &&
          !file.fileName.toLowerCase().contains(_archiveSearchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    final categories = PcbFileCategory.values.where((cat) {
      return allFiles.any((f) => f.category == cat);
    }).toList();

    return Column(
      children: [
        // Search bar & Count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_zip_outlined, size: 22, color: Color(0xFF059669)),
                  const SizedBox(width: 10),
                  Text(
                    'Archive Explorer (${allFiles.length} files)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredFiles.length} shown',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search files in archive...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.search, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  suffixIcon: _archiveSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _archiveSearchQuery = ''),
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _archiveSearchQuery = v.trim()),
              ),
            ],
          ),
        ),

        // Category Filter Chips
        if (categories.length > 1)
          Container(
            height: 44,
            color: theme.colorScheme.surface,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    selected: _archiveFilterCategory == null,
                    label: Text('All (${allFiles.length})'),
                    onSelected: (_) => setState(() => _archiveFilterCategory = null),
                  ),
                ),
                ...categories.map((cat) {
                  final count = allFiles.where((f) => f.category == cat).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      selected: _archiveFilterCategory == cat,
                      avatar: Icon(cat.icon, size: 14, color: cat.color),
                      label: Text('${cat.displayName} ($count)'),
                      onSelected: (selected) {
                        setState(() {
                          _archiveFilterCategory = selected ? cat : null;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        const Divider(height: 1),

        // Files List
        Expanded(
          child: filteredFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('No files match the filter',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + MediaQuery.paddingOf(context).bottom),
                  itemCount: filteredFiles.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _buildArchiveFileItemWidget(filteredFiles[index], theme);
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
