import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'models/pcb_models.dart';
import 'parser/gerber_parser.dart';
import 'parser/drill_parser.dart';
import 'rendering/pcb_painter.dart';

/// PCB Gerber RS-274X and Excellon Drill Viewer Screen.
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

  PcbDocument? _document;
  PcbTheme _pcbTheme = PcbTheme.fr4Green;
  bool _showGrid = true;

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
      PcbDocument doc;

      if (lower.endsWith('.drl') ||
          lower.endsWith('.xln') ||
          lower.endsWith('.exc') ||
          lower.endsWith('.drd')) {
        doc = DrillParser.parse(bytes, fileName: _fileName);
      } else {
        doc = GerberParser.parse(bytes, fileName: _fileName);
      }

      if (mounted) {
        setState(() {
          _document = doc;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error reading PCB file: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
  }

  void _zoomIn() {
    final matrix = _transformController.value.clone()..scale(1.25, 1.25);
    _transformController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformController.value.clone()..scale(0.8, 0.8);
    _transformController.value = matrix;
  }

  void _showInfoSheet() {
    if (_document == null) return;
    final theme = Theme.of(context);
    final bounds = _document!.boundingBox;

    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

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
                          'PCB Layer • Properties',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _fileName,
                          style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow('Layer Type:', _document!.layerType.displayName),
              _buildInfoRow('File Size:', formattedSize),
              _buildInfoRow(
                'Board Dimensions (mm):',
                '${bounds.widthMm.toStringAsFixed(2)} × ${bounds.heightMm.toStringAsFixed(2)} mm',
              ),
              _buildInfoRow(
                'Board Dimensions (in):',
                '${bounds.widthInches.toStringAsFixed(2)}" × ${bounds.heightInches.toStringAsFixed(2)}"',
              ),
              if (_document!.trackCount > 0) _buildInfoRow('Traces & Tracks:', '${_document!.trackCount} lines/arcs'),
              if (_document!.padCount > 0) _buildInfoRow('SMD & THT Pads:', '${_document!.padCount} flashed pads'),
              if (_document!.regionCount > 0) _buildInfoRow('Copper Pours:', '${_document!.regionCount} regions'),
              if (_document!.holeCount > 0) _buildInfoRow('Drill Holes / Vias:', '${_document!.holeCount} holes'),
            ],
          ),
        );
      },
    );
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fileName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (_document != null)
              Text(
                '${_document!.layerType.displayName} • ${_document!.boundingBox.widthMm.toStringAsFixed(1)} × ${_document!.boundingBox.heightMm.toStringAsFixed(1)} mm',
                style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
              ),
          ],
        ),
        actions: [
          // Theme Menu
          PopupMenuButton<PcbTheme>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'PCB Theme',
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

          // Grid Toggle
          IconButton(
            icon: Icon(
              _showGrid ? Icons.grid_on : Icons.grid_off,
              color: _showGrid ? theme.colorScheme.primary : null,
            ),
            tooltip: '1mm PCB Grid',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),

          // Information Sheet
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'PCB Properties',
            onPressed: _showInfoSheet,
          ),

          // Share
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareFile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF059669)),
                  SizedBox(height: 16),
                  Text('Loading PCB Gerber / Drill File...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
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
                )
              : Stack(
                  children: [
                    // Interactive Canvas with Infinite Vector Zoom & Pan
                    InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.01,
                      maxScale: 1000.0,
                      boundaryMargin: const EdgeInsets.all(1500.0),
                      child: Center(
                        child: CustomPaint(
                          size: Size(
                            (_document!.boundingBox.widthMm * 10.0) + 40.0,
                            (_document!.boundingBox.heightMm * 10.0) + 40.0,
                          ),
                          painter: PcbPainter(
                            document: _document!,
                            theme: _pcbTheme,
                            showGrid: _showGrid,
                            scaleFactor: 10.0,
                          ),
                        ),
                      ),
                    ),

                    // Floating Layer Badge
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.layers_rounded, size: 14, color: _document!.layerType.defaultAccent),
                            const SizedBox(width: 6),
                            Text(
                              _document!.layerType.displayName,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ],
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
                            tooltip: 'Fit to Board',
                            onTap: _resetView,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
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
