import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/widgets/viewer_loading_screen.dart';
import 'dicom_geometry.dart';
import 'dicom_models.dart';
import 'dicom_parser.dart';
import 'dicom_renderer.dart';
import 'dicom_study_loader.dart';

// ---------------------------------------------------------------------------
// Main Screen
// ---------------------------------------------------------------------------
class DicomViewerScreen extends StatefulWidget {
  final String filePath;

  const DicomViewerScreen({super.key, required this.filePath});

  @override
  State<DicomViewerScreen> createState() => _DicomViewerScreenState();
}

class _DicomViewerScreenState extends State<DicomViewerScreen> {
  // Loading state
  bool _isLoading = true;
  String? _error;

  // Study & Multi-Viewport State
  DicomStudyItem? _study;
  DicomViewportLayout _layout = DicomViewportLayout.single;
  int _activeViewportIndex = 0;
  final List<DicomViewportState> _viewports = [];

  // Interaction modes: Pan/Zoom, Window/Level, Ruler
  DicomInteractionMode _interactionMode = DicomInteractionMode.panZoom;

  // Feature Toggles
  bool _showReferenceLines = true;
  bool _showOverlays = true;
  bool _showMetadata = false;

  // Series thumbnail image cache
  final Map<String, ui.Image?> _seriesThumbnails = {};

  // Cine loop playback for active viewport
  Timer? _cineTimer;
  bool _isPlayingCine = false;

  static const Color _accent = Color(0xFF0EA5E9); // cyan-blue medical accent

  DicomViewportState? get _activeViewport {
    if (_viewports.isEmpty) return null;
    return _viewports[_activeViewportIndex.clamp(0, _viewports.length - 1)];
  }

  DicomSeriesItem? get _activeSeries {
    final vp = _activeViewport;
    if (_study == null || vp == null || _study!.series.isEmpty) return null;
    return _study!.series[vp.seriesIndex.clamp(0, _study!.series.length - 1)];
  }

  DicomSliceItem? get _currentSlice {
    final s = _activeSeries;
    final vp = _activeViewport;
    if (s == null || vp == null || s.slices.isEmpty) return null;
    return s.slices[vp.sliceIndex.clamp(0, s.sliceCount - 1)];
  }

  DicomHeader? get _currentHeader => _currentSlice?.header;

  @override
  void initState() {
    super.initState();
    _loadDicomStudy();
  }

  @override
  void dispose() {
    _stopCine();
    for (final vp in _viewports) {
      vp.dispose();
    }
    for (final img in _seriesThumbnails.values) {
      img?.dispose();
    }
    _study?.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Loading & Initialization
  // --------------------------------------------------------------------------

  Future<void> _loadDicomStudy() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final study = await DicomStudyLoader.load(widget.filePath);

      if (!mounted) return;

      final seriesCount = study.series.length;
      final newViewports = <DicomViewportState>[];

      // If study has >= 2 series, default to splitVertical (1x2) as seen in user reference
      DicomViewportLayout initialLayout;
      int initialViewportCount;

      if (seriesCount >= 4) {
        initialLayout = DicomViewportLayout.grid2x2;
        initialViewportCount = 4;
      } else if (seriesCount >= 2) {
        initialLayout = DicomViewportLayout.splitVertical;
        initialViewportCount = 2;
      } else {
        initialLayout = DicomViewportLayout.single;
        initialViewportCount = 1;
      }

      for (int i = 0; i < 4; i++) {
        final sIdx = i % seriesCount;
        final firstHeader = study.series[sIdx].firstSlice.header;
        double? wc = firstHeader.windowCenter;
        double? ww = firstHeader.windowWidth;

        if (wc == null) {
          final preset = DicomRenderer.suggestPresetForModality(firstHeader.modality);
          if (preset != null) {
            wc = preset.center;
            ww = preset.width;
          }
        }

        newViewports.add(DicomViewportState(
          viewportIndex: i,
          seriesIndex: sIdx,
          sliceIndex: 0,
          windowCenter: wc ?? 127.0,
          windowWidth: (ww ?? 256.0).clamp(1.0, 65535.0),
          accentColor: DicomViewportColors.getColor(i),
        ));
      }

      setState(() {
        _study = study;
        _layout = initialLayout;
        _activeViewportIndex = 0;
        _viewports.clear();
        _viewports.addAll(newViewports);
        _isLoading = false;
      });

      // Render initial slices for the visible viewports
      for (int i = 0; i < initialViewportCount && i < _viewports.length; i++) {
        _renderViewportSlice(_viewports[i]);
      }

      // Generate series thumbnails in the background
      _generateThumbnails();
    } on DicomParseException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DicomViewer._loadDicomStudy.parse');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _error = l10n != null ? l10n.dicomParseError(e.message) : 'DICOM Parse Error: ${e.message}';
        _isLoading = false;
      });
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DicomViewer._loadDicomStudy.fs');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _error = l10n?.fileNotFoundOrInaccessible ?? 'File not found or cannot be accessed.';
        _isLoading = false;
      });
    } on FormatException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DicomViewer._loadDicomStudy.format');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _error = l10n != null ? l10n.errorLoadingDicom(e.message) : 'Error loading DICOM study: ${e.message}';
        _isLoading = false;
      });
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DicomViewer._loadDicomStudy');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _error = l10n != null ? l10n.errorLoadingDicom(e.toString()) : 'Error loading DICOM study: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateThumbnails() async {
    if (_study == null) return;
    for (final series in _study!.series) {
      if (series.slices.isEmpty) continue;
      final slice = series.firstSlice;
      try {
        final bytes = await slice.getBytes();
        final res = await DicomRenderer.renderFrame(
          fileBytes: bytes,
          header: slice.header,
          frameIndex: slice.frameIndex,
        );
        if (mounted) {
          setState(() {
            _seriesThumbnails[series.seriesInstanceUID] = res.image;
          });
        }
      } catch (_) {
        // Thumbnail generation is best-effort
      }
    }
  }

  // --------------------------------------------------------------------------
  // Rendering
  // --------------------------------------------------------------------------

  Future<void> _renderViewportSlice(DicomViewportState vp, {double? initialWc, double? initialWw}) async {
    if (_study == null || _study!.series.isEmpty) return;
    final series = _study!.series[vp.seriesIndex.clamp(0, _study!.series.length - 1)];
    if (series.slices.isEmpty || vp.isRendering) return;

    setState(() => vp.isRendering = true);

    try {
      final slice = series.slices[vp.sliceIndex.clamp(0, series.sliceCount - 1)];
      final bytes = await slice.getBytes();
      final header = slice.header;

      final overrideWc = initialWc ?? (header.isMonochrome ? vp.windowCenter : null);
      final overrideWw = initialWw ?? (header.isMonochrome ? vp.windowWidth : null);

      final result = await DicomRenderer.renderFrame(
        fileBytes: bytes,
        header: header,
        frameIndex: slice.frameIndex,
        windowCenter: overrideWc,
        windowWidth: overrideWw,
      );

      if (!mounted) return;

      final oldImage = vp.renderedImage;
      setState(() {
        vp.renderedImage = result.image;
        if (initialWc == null || initialWw == null) {
          vp.windowCenter = result.windowCenter.clamp(-2048.0, 4096.0);
          vp.windowWidth = result.windowWidth.clamp(1.0, 8192.0);
        }
        vp.isRendering = false;
      });
      oldImage?.dispose();
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DicomViewer._renderViewportSlice');
      if (!mounted) return;
      setState(() => vp.isRendering = false);
    }
  }

  void _onWindowingChanged(DicomViewportState vp) {
    _renderViewportSlice(vp);
  }

  void _applyPreset(DicomViewportState vp, WindowPreset preset) {
    setState(() {
      vp.windowCenter = preset.center;
      vp.windowWidth = preset.width;
    });
    _renderViewportSlice(vp);
  }

  // --------------------------------------------------------------------------
  // Navigation & Slicing
  // --------------------------------------------------------------------------

  void _goToSlice(int targetSlice, [int? viewportIdx]) {
    if (_study == null || _viewports.isEmpty) return;
    final idx = viewportIdx ?? _activeViewportIndex;
    final vp = _viewports[idx.clamp(0, _viewports.length - 1)];
    final series = _study!.series[vp.seriesIndex.clamp(0, _study!.series.length - 1)];
    final clamped = targetSlice.clamp(0, series.sliceCount - 1);

    if (clamped != vp.sliceIndex) {
      setState(() {
        vp.sliceIndex = clamped;
        vp.measurements.clear();
      });
      _renderViewportSlice(vp);
    }
  }

  void _switchViewportSeries(DicomViewportState vp, int newSeriesIndex) {
    if (_study == null || newSeriesIndex == vp.seriesIndex) return;
    _stopCine();
    setState(() {
      vp.seriesIndex = newSeriesIndex;
      vp.sliceIndex = 0;
      vp.measurements.clear();
    });

    final series = _study!.series[newSeriesIndex.clamp(0, _study!.series.length - 1)];
    final header = series.firstSlice.header;
    double? wc = header.windowCenter;
    double? ww = header.windowWidth;
    if (wc == null) {
      final preset = DicomRenderer.suggestPresetForModality(header.modality);
      if (preset != null) {
        wc = preset.center;
        ww = preset.width;
      }
    }
    setState(() {
      vp.windowCenter = wc ?? 127.0;
      vp.windowWidth = (ww ?? 256.0).clamp(1.0, 65535.0);
    });

    _renderViewportSlice(vp, initialWc: wc, initialWw: ww);
  }

  void _changeLayout(DicomViewportLayout newLayout) {
    if (newLayout == _layout) return;
    setState(() {
      _layout = newLayout;
      if (_activeViewportIndex >= newLayout.totalViewports) {
        _activeViewportIndex = 0;
      }
    });

    // Ensure all visible viewports have rendered slices
    final count = newLayout.totalViewports;
    for (int i = 0; i < count && i < _viewports.length; i++) {
      if (_viewports[i].renderedImage == null) {
        _renderViewportSlice(_viewports[i]);
      }
    }
  }

  void _toggleCine() {
    if (_isPlayingCine) {
      _stopCine();
    } else {
      _startCine();
    }
  }

  void _startCine() {
    final s = _activeSeries;
    final vp = _activeViewport;
    if (s == null || vp == null || s.sliceCount <= 1) return;
    setState(() => _isPlayingCine = true);
    _cineTimer?.cancel();
    _cineTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final currentVp = _activeViewport;
      if (currentVp == null) return;
      final currentSeries = _study!.series[currentVp.seriesIndex];
      final next = (currentVp.sliceIndex + 1) % currentSeries.sliceCount;
      _goToSlice(next, currentVp.viewportIndex);
    });
  }

  void _stopCine() {
    _cineTimer?.cancel();
    _cineTimer = null;
    if (mounted) setState(() => _isPlayingCine = false);
  }

  // --------------------------------------------------------------------------
  // Reference Lines Calculation (Localizer / Scout Lines)
  // --------------------------------------------------------------------------

  List<DicomReferenceLineEntry> _calculateReferenceLinesFor(DicomViewportState targetVp) {
    if (!_showReferenceLines || _study == null) return const [];

    final results = <DicomReferenceLineEntry>[];
    final targetSeries = _study!.series[targetVp.seriesIndex.clamp(0, _study!.series.length - 1)];
    final targetSlice = targetSeries.slices[targetVp.sliceIndex.clamp(0, targetSeries.sliceCount - 1)];
    final targetHeader = targetSlice.header;

    final visibleCount = _layout.totalViewports;
    for (int i = 0; i < visibleCount && i < _viewports.length; i++) {
      final otherVp = _viewports[i];
      if (otherVp.viewportIndex == targetVp.viewportIndex) continue;

      final otherSeries = _study!.series[otherVp.seriesIndex.clamp(0, _study!.series.length - 1)];
      final otherSlice = otherSeries.slices[otherVp.sliceIndex.clamp(0, otherSeries.sliceCount - 1)];
      final otherHeader = otherSlice.header;

      final refLine = DicomGeometry.calculateIntersection(
        targetHeader: targetHeader,
        sourceHeader: otherHeader,
        sourceSliceIndex: otherVp.sliceIndex,
        sourceTotalSlices: otherSeries.sliceCount,
        sourceSeriesDescription: otherSeries.seriesDescription,
      );

      if (refLine != null) {
        results.add(DicomReferenceLineEntry(
          line: refLine,
          color: otherVp.accentColor,
        ));
      }
    }

    return results;
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split(Platform.pathSeparator).last;
    final file = File(widget.filePath);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;

    if (_isLoading) {
      final l10n = context.l10n;
      return ViewerLoadingScreen(
        fileName: fileName,
        fileSizeBytes: fileSize,
        icon: Icons.medical_services_outlined,
        accentColor: _accent,
        loadingTitle: l10n.loadingDicom,
        statusMessage: l10n.statusScanningSeries,
        onCancel: () => Navigator.of(context).pop(),
      );
    }

    if (_error != null) {
      return _buildErrorScreen(fileName);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: _buildAppBar(fileName),
      body: Column(
        children: [
          // Collapsible Metadata Panel
          if (_study != null) _buildMetadataPanel(),

          // Interaction mode toolbar
          _buildToolbar(),

          // Multi-Viewport Canvas Grid
          Expanded(child: _buildMultiViewportGrid()),

          // Series Thumbnail Filmstrip (bottom row matching reference pictures)
          if (_study != null && _study!.series.isNotEmpty)
            _buildSeriesFilmstrip(),

          // Bottom navigation & Windowing controls for active viewport
          if (_study != null && _activeViewport != null)
            _buildBottomControls(_activeViewport!),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String fileName) {
    final s = _activeSeries;
    final h = _currentHeader;

    return AppBar(
      backgroundColor: const Color(0xFF12121A),
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _study?.patientName.isNotEmpty == true && _study?.patientName != 'Unknown'
                ? '${_study!.patientName} · $fileName'
                : fileName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          if (s != null && h != null)
            Text(
              '${s.modality} · ${h.columns}×${h.rows}'
              '${s.sliceCount > 1 ? " · ${s.sliceCount} slices" : ""}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
      actions: [
        // Layout selector popup
        PopupMenuButton<DicomViewportLayout>(
          tooltip: context.l10n.dicomLayout,
          icon: const Icon(Icons.grid_view_outlined, color: Colors.white70),
          color: const Color(0xFF1E1E2E),
          onSelected: _changeLayout,
          itemBuilder: (context) => [
            _layoutMenuItem(DicomViewportLayout.single, '1×1 Single', Icons.crop_square),
            _layoutMenuItem(DicomViewportLayout.splitVertical, '1×2 Vertical', Icons.view_agenda_outlined),
            _layoutMenuItem(DicomViewportLayout.splitHorizontal, '2×1 Horizontal', Icons.view_column_outlined),
            _layoutMenuItem(DicomViewportLayout.grid2x2, '2×2 Grid', Icons.grid_view),
          ],
        ),

        // Cross-Reference / Localizer Lines Toggle
        IconButton(
          icon: Icon(
            _showReferenceLines ? Icons.center_focus_strong : Icons.center_focus_weak,
            color: _showReferenceLines ? _accent : Colors.white60,
          ),
          tooltip: context.l10n.dicomReferenceLines,
          onPressed: () => setState(() => _showReferenceLines = !_showReferenceLines),
        ),

        // Overlay text toggle
        IconButton(
          icon: Icon(
            _showOverlays ? Icons.branding_watermark : Icons.branding_watermark_outlined,
            color: _showOverlays ? _accent : Colors.white60,
          ),
          tooltip: 'Toggle HUD text',
          onPressed: () => setState(() => _showOverlays = !_showOverlays),
        ),

        // Metadata sheet toggle
        IconButton(
          icon: Icon(
            Icons.info_outline,
            color: _showMetadata ? _accent : Colors.white70,
          ),
          tooltip: 'Show metadata',
          onPressed: () => setState(() => _showMetadata = !_showMetadata),
        ),

        // Share
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white70),
          onPressed: () => Share.shareXFiles([XFile(widget.filePath)]),
        ),
      ],
    );
  }

  PopupMenuItem<DicomViewportLayout> _layoutMenuItem(
    DicomViewportLayout layout,
    String label,
    IconData icon,
  ) {
    final isSelected = _layout == layout;
    return PopupMenuItem<DicomViewportLayout>(
      value: layout,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? _accent : Colors.white70),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? _accent : Colors.white,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, size: 16, color: _accent),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final vp = _activeViewport;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: const Color(0xFF13131D),
      child: Row(
        children: [
          // Pan & Zoom mode
          _toolButton(
            icon: Icons.pan_tool_outlined,
            tooltip: 'Pan & Zoom',
            isActive: _interactionMode == DicomInteractionMode.panZoom,
            onPressed: () =>
                setState(() => _interactionMode = DicomInteractionMode.panZoom),
          ),
          // Window/Level drag mode
          _toolButton(
            icon: Icons.brightness_6_outlined,
            tooltip: 'Window / Level Drag (Drag on screen)',
            isActive: _interactionMode == DicomInteractionMode.windowLevel,
            onPressed: () => setState(
                () => _interactionMode = DicomInteractionMode.windowLevel),
          ),
          // Ruler mode
          _toolButton(
            icon: Icons.straighten_outlined,
            tooltip: 'Ruler Measurement (mm)',
            isActive: _interactionMode == DicomInteractionMode.ruler,
            onPressed: () =>
                setState(() => _interactionMode = DicomInteractionMode.ruler),
          ),
          const Spacer(),
          if (vp != null && vp.measurements.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.amberAccent,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.clear, size: 14),
              label: Text('Clear (${vp.measurements.length})',
                  style: const TextStyle(fontSize: 11)),
              onPressed: () => setState(() => vp.measurements.clear()),
            ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: isActive ? _accent.withValues(alpha: 0.25) : Colors.transparent,
          foregroundColor: isActive ? _accent : Colors.white60,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPressed,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Multi-Viewport Grid Layout
  // --------------------------------------------------------------------------

  Widget _buildMultiViewportGrid() {
    if (_viewports.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    switch (_layout) {
      case DicomViewportLayout.single:
        return _buildViewportCard(_viewports[_activeViewportIndex.clamp(0, _viewports.length - 1)]);

      case DicomViewportLayout.splitVertical:
        return Column(
          children: [
            Expanded(child: _buildViewportCard(_viewports[0])),
            Expanded(child: _buildViewportCard(_viewports[1])),
          ],
        );

      case DicomViewportLayout.splitHorizontal:
        return Row(
          children: [
            Expanded(child: _buildViewportCard(_viewports[0])),
            Expanded(child: _buildViewportCard(_viewports[1])),
          ],
        );

      case DicomViewportLayout.grid2x2:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildViewportCard(_viewports[0])),
                  Expanded(child: _buildViewportCard(_viewports[1])),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildViewportCard(_viewports[2])),
                  Expanded(child: _buildViewportCard(_viewports[3])),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildViewportCard(DicomViewportState vp) {
    final isSelected = vp.viewportIndex == _activeViewportIndex;
    final series = _study!.series[vp.seriesIndex.clamp(0, _study!.series.length - 1)];
    final slice = series.slices[vp.sliceIndex.clamp(0, series.sliceCount - 1)];
    final header = slice.header;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_activeViewportIndex != vp.viewportIndex) {
          setState(() => _activeViewportIndex = vp.viewportIndex);
        }
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D11),
          border: Border.all(
            color: isSelected ? vp.accentColor : vp.accentColor.withValues(alpha: 0.45),
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Column(
            children: [
              // Top Bar in each Viewport: Series dropdown and Caliper button
              _buildViewportHeader(vp, series),
              // Viewport Canvas with interactive gestures & reference lines
              Expanded(
                child: _buildViewportCanvas(vp, series, slice, header),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewportHeader(DicomViewportState vp, DicomSeriesItem series) {
    return Container(
      height: 32,
      color: const Color(0xFF14141E),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Dropdown menu button to change series directly in this viewport
          PopupMenuButton<int>(
            tooltip: 'Select Series',
            color: const Color(0xFF1E1E2E),
            padding: EdgeInsets.zero,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  series.seriesDescription,
                  style: TextStyle(
                    color: vp.accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 16, color: vp.accentColor),
              ],
            ),
            onSelected: (newSeriesIndex) {
              _switchViewportSeries(vp, newSeriesIndex);
            },
            itemBuilder: (context) {
              return List.generate(_study!.series.length, (idx) {
                final s = _study!.series[idx];
                final isCurrent = idx == vp.seriesIndex;
                return PopupMenuItem<int>(
                  value: idx,
                  child: Row(
                    children: [
                      if (isCurrent)
                        Icon(Icons.check, size: 14, color: vp.accentColor)
                      else
                        const SizedBox(width: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${s.seriesDescription} (${s.sliceCount})',
                          style: TextStyle(
                            color: isCurrent ? vp.accentColor : Colors.white,
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              });
            },
          ),
          const Spacer(),
          // Caliper / Ruler button for this viewport
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 16,
              color: _interactionMode == DicomInteractionMode.ruler && _activeViewportIndex == vp.viewportIndex
                  ? vp.accentColor
                  : Colors.white54,
            ),
            tooltip: 'Ruler Measurement',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () {
              setState(() {
                _activeViewportIndex = vp.viewportIndex;
                _interactionMode = _interactionMode == DicomInteractionMode.ruler
                    ? DicomInteractionMode.panZoom
                    : DicomInteractionMode.ruler;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildViewportCanvas(
    DicomViewportState vp,
    DicomSeriesItem series,
    DicomSliceItem slice,
    DicomHeader header,
  ) {
    if (vp.renderedImage == null) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    final imageSize = Size(
      vp.renderedImage!.width.toDouble(),
      vp.renderedImage!.height.toDouble(),
    );

    final refLines = _calculateReferenceLinesFor(vp);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              if (event.scrollDelta.dy > 0) {
                _goToSlice(vp.sliceIndex + 1, vp.viewportIndex);
              } else if (event.scrollDelta.dy < 0) {
                _goToSlice(vp.sliceIndex - 1, vp.viewportIndex);
              }
            }
          },
          child: Stack(
            children: [
              // 1. InteractiveViewer (Pan & Zoom mode)
              Positioned.fill(
                child: InteractiveViewer(
                  panEnabled: _interactionMode == DicomInteractionMode.panZoom,
                  scaleEnabled: _interactionMode == DicomInteractionMode.panZoom,
                  minScale: 0.1,
                  maxScale: 25,
                  child: Center(
                    child: RawImage(
                      image: vp.renderedImage,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),

              // 2. Gesture Detector for Window/Level and Ruler modes
              if (_interactionMode != DicomInteractionMode.panZoom &&
                  vp.viewportIndex == _activeViewportIndex)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      if (_interactionMode == DicomInteractionMode.ruler) {
                        final imgCoords = _screenToImageCoords(
                            details.localPosition, constraints.biggest, imageSize);
                        if (imgCoords != null) {
                          setState(() {
                            vp.draftMeasurement = DicomMeasurement(
                              start: imgCoords,
                              end: imgCoords,
                              pixelSpacingRow: header.pixelSpacingRow,
                              pixelSpacingCol: header.pixelSpacingCol,
                            );
                          });
                        }
                      }
                    },
                    onPanUpdate: (details) {
                      if (_interactionMode == DicomInteractionMode.windowLevel) {
                        setState(() {
                          vp.windowWidth = (vp.windowWidth + details.delta.dx * 3.0)
                              .clamp(1.0, 8192.0);
                          vp.windowCenter = (vp.windowCenter - details.delta.dy * 3.0)
                              .clamp(-2048.0, 4096.0);
                        });
                        _onWindowingChanged(vp);
                      } else if (_interactionMode == DicomInteractionMode.ruler &&
                          vp.draftMeasurement != null) {
                        final imgCoords = _screenToImageCoords(
                            details.localPosition, constraints.biggest, imageSize);
                        if (imgCoords != null) {
                          setState(() {
                            vp.draftMeasurement = DicomMeasurement(
                              start: vp.draftMeasurement!.start,
                              end: imgCoords,
                              pixelSpacingRow: header.pixelSpacingRow,
                              pixelSpacingCol: header.pixelSpacingCol,
                            );
                          });
                        }
                      }
                    },
                    onPanEnd: (_) {
                      if (_interactionMode == DicomInteractionMode.ruler &&
                          vp.draftMeasurement != null) {
                        setState(() {
                          vp.measurements.add(vp.draftMeasurement!);
                          vp.draftMeasurement = null;
                        });
                      }
                    },
                  ),
                ),

              // 3. Ruler CustomPainter overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RulerPainter(
                      measurements: vp.measurements,
                      currentDraft: vp.draftMeasurement,
                      imageSize: imageSize,
                    ),
                  ),
                ),
              ),

              // 4. Cross-Reference (Localizer / Scout) Lines Overlay
              if (_showReferenceLines && refLines.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LocalizerLinesPainter(
                        lines: refLines,
                        imageSize: imageSize,
                      ),
                    ),
                  ),
                ),

              // 5. Medical HUD Corner Overlays
              if (_showOverlays)
                _buildViewportHud(vp, series, slice, header),

              // 6. Rendering indicator
              if (vp.isRendering)
                const Positioned(
                  bottom: 8,
                  right: 8,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Offset? _screenToImageCoords(
      Offset localPos, Size containerSize, Size imageSize) {
    if (imageSize.width == 0 || imageSize.height == 0) return null;
    final fitted = applyBoxFit(BoxFit.contain, imageSize, containerSize);
    final dst = Alignment.center
        .inscribe(fitted.destination, Offset.zero & containerSize);

    if (!dst.contains(localPos)) return null;

    final normX = (localPos.dx - dst.left) / dst.width;
    final normY = (localPos.dy - dst.top) / dst.height;

    return Offset(
      normX * imageSize.width,
      normY * imageSize.height,
    );
  }

  Widget _buildViewportHud(
    DicomViewportState vp,
    DicomSeriesItem series,
    DicomSliceItem slice,
    DicomHeader h,
  ) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              // Bottom-Left: Window Level and Window Width (WL / WW)
              Align(
                alignment: Alignment.bottomLeft,
                child: _hudText(
                  'WL: ${vp.windowCenter.toInt()}\nWW: ${vp.windowWidth.toInt()}',
                  color: const Color(0xFF60A5FA),
                ),
              ),
              // Bottom-Right: Series number & Instance / Slice number (SE / IM)
              Align(
                alignment: Alignment.bottomRight,
                child: _hudText(
                  'SE: ${vp.seriesIndex + 1}\nIM: ${vp.sliceIndex + 1}/${series.sliceCount}',
                  textAlign: TextAlign.right,
                  color: Colors.white,
                  highlightSecondLineColor: const Color(0xFF60A5FA),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hudText(
    String text, {
    TextAlign textAlign = TextAlign.left,
    Color color = Colors.white,
    Color? highlightSecondLineColor,
  }) {
    final lines = text.split('\n');
    if (lines.length == 2 && highlightSecondLineColor != null) {
      return RichText(
        textAlign: textAlign,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4),
              Shadow(color: Colors.black, blurRadius: 8),
            ],
          ),
          children: [
            TextSpan(text: '${lines[0]}\n', style: TextStyle(color: color)),
            TextSpan(text: lines[1], style: TextStyle(color: highlightSecondLineColor)),
          ],
        ),
      );
    }

    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.35,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4),
          Shadow(color: Colors.black, blurRadius: 8),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Series Thumbnail Filmstrip (matching reference images)
  // --------------------------------------------------------------------------

  Widget _buildSeriesFilmstrip() {
    if (_study == null || _study!.series.isEmpty) return const SizedBox.shrink();

    final activeVp = _activeViewport;

    return Container(
      height: 72,
      color: const Color(0xFF101018),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _study!.series.length,
        itemBuilder: (context, index) {
          final s = _study!.series[index];

          // Check if any visible viewport is currently displaying this series
          DicomViewportState? assignedVp;
          final visibleCount = _layout.totalViewports;
          for (int v = 0; v < visibleCount && v < _viewports.length; v++) {
            if (_viewports[v].seriesIndex == index) {
              assignedVp = _viewports[v];
              break;
            }
          }

          final isCurrentActive = activeVp?.seriesIndex == index;
          final borderColor = assignedVp != null
              ? assignedVp.accentColor
              : (isCurrentActive ? _accent : Colors.white12);

          final thumbImage = _seriesThumbnails[s.seriesInstanceUID];

          return GestureDetector(
            onTap: () {
              if (activeVp != null && activeVp.seriesIndex != index) {
                _switchViewportSeries(activeVp, index);
              }
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF181824),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: borderColor,
                  width: assignedVp != null ? 2.0 : 1.0,
                ),
              ),
              child: Stack(
                children: [
                  // Thumbnail image or placeholder
                  Positioned.fill(
                    child: thumbImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: RawImage(
                              image: thumbImage,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.view_in_ar,
                              size: 24,
                              color: assignedVp != null
                                  ? assignedVp.accentColor.withValues(alpha: 0.6)
                                  : Colors.white24,
                            ),
                          ),
                  ),
                  // Slice count badge at bottom right (e.g. "25", "48")
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '${s.sliceCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Bottom Controls
  // --------------------------------------------------------------------------

  Widget _buildBottomControls(DicomViewportState vp) {
    final series = _study!.series[vp.seriesIndex.clamp(0, _study!.series.length - 1)];
    final slice = series.slices[vp.sliceIndex.clamp(0, series.sliceCount - 1)];
    final header = slice.header;
    final showWindowing = header.isMonochrome && header.bitsAllocated >= 16;

    return Container(
      color: const Color(0xFF12121A),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slice navigation (if active series has multiple slices)
          if (series.sliceCount > 1)
            _buildSliceNavigation(vp, series),
          // Windowing controls
          if (showWindowing)
            _buildWindowingControls(vp, header),
        ],
      ),
    );
  }

  Widget _buildSliceNavigation(DicomViewportState vp, DicomSeriesItem series) {
    final count = series.sliceCount;
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.layers_outlined, color: Colors.white38, size: 14),
            const SizedBox(width: 6),
            Text(
              'Slice ${vp.sliceIndex + 1} / $count (${series.seriesDescription})',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Spacer(),
            // Cine Loop Play/Pause
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                _isPlayingCine ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: _isPlayingCine ? vp.accentColor : Colors.white70,
                size: 22,
              ),
              tooltip: _isPlayingCine ? 'Pause Cine' : 'Play Cine',
              onPressed: _toggleCine,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.skip_previous, color: Colors.white70, size: 20),
              onPressed: vp.sliceIndex > 0
                  ? () => _goToSlice(vp.sliceIndex - 1, vp.viewportIndex)
                  : null,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.skip_next, color: Colors.white70, size: 20),
              onPressed: vp.sliceIndex < count - 1
                  ? () => _goToSlice(vp.sliceIndex + 1, vp.viewportIndex)
                  : null,
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: vp.accentColor,
            thumbColor: vp.accentColor,
            inactiveTrackColor: Colors.white12,
            overlayColor: vp.accentColor.withValues(alpha: 0.2),
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: vp.sliceIndex.toDouble(),
            min: 0,
            max: (count - 1).toDouble(),
            divisions: count > 1 ? count - 1 : null,
            onChanged: (v) => _goToSlice(v.round(), vp.viewportIndex),
          ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildWindowingControls(DicomViewportState vp, DicomHeader h) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Presets row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Presets: ',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              ...WindowPreset.presets.map((p) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ActionChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      label: Text(p.name, style: const TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFF1E1E30),
                      side: BorderSide(color: vp.accentColor.withValues(alpha: 0.3)),
                      labelStyle: const TextStyle(color: Colors.white70),
                      onPressed: () => _applyPreset(vp, p),
                    ),
                  )),
              if (h.windowCenter != null)
                ActionChip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  label: const Text('Reset', style: TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFF1E1E30),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  labelStyle: const TextStyle(color: Colors.white38),
                  onPressed: () {
                    setState(() {
                      vp.windowCenter = h.windowCenter!;
                      vp.windowWidth = h.windowWidth ?? 256;
                    });
                    _onWindowingChanged(vp);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Window Center (Level)
        _windowSlider(
          accentColor: vp.accentColor,
          label: 'WC',
          value: vp.windowCenter,
          min: -2048.0,
          max: 4096.0,
          display: vp.windowCenter.toStringAsFixed(0),
          onChanged: (v) => setState(() => vp.windowCenter = v),
          onChangeEnd: (_) => _onWindowingChanged(vp),
        ),
        // Window Width
        _windowSlider(
          accentColor: vp.accentColor,
          label: 'WW',
          value: vp.windowWidth,
          min: 1.0,
          max: 8192.0,
          display: vp.windowWidth.toStringAsFixed(0),
          onChanged: (v) => setState(() => vp.windowWidth = v.clamp(1, 8192.0)),
          onChangeEnd: (_) => _onWindowingChanged(vp),
        ),
      ],
    );
  }

  Widget _windowSlider({
    required Color accentColor,
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: TextStyle(
              color: accentColor.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor,
              thumbColor: accentColor,
              inactiveTrackColor: Colors.white12,
              overlayColor: accentColor.withValues(alpha: 0.15),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Metadata Panel
  // --------------------------------------------------------------------------

  Widget _buildMetadataPanel() {
    if (!_showMetadata) return const SizedBox.shrink();
    final h = _currentHeader;
    final s = _activeSeries;
    if (h == null || s == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(color: _accent.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metaRow('Patient', _study?.patientName ?? h.formattedPatientName),
            _metaRow('Patient ID', _study?.patientId ?? h.patientId ?? '—'),
            if (_study?.patientSex != null || h.patientSex != null)
              _metaRow('Sex', _study?.patientSex ?? h.patientSex!),
            if (_study?.patientAge != null || h.patientAge != null)
              _metaRow('Age', _study?.patientAge ?? h.patientAge!),
            if (h.patientBirthDate != null)
              _metaRow('DOB', h.patientBirthDate!),
            const Divider(color: Colors.white12, height: 14),
            _metaRow('Modality', s.modality),
            _metaRow('Study Date', _study?.studyDate ?? h.formattedStudyDate),
            if (h.studyDescription != null)
              _metaRow('Study', h.studyDescription!),
            _metaRow('Series', s.seriesDescription),
            if (h.institutionName != null)
              _metaRow('Institution', h.institutionName!),
            const Divider(color: Colors.white12, height: 14),
            _metaRow('Dimensions', '${h.columns} × ${h.rows} px'),
            _metaRow('Bits', '${h.bitsAllocated} allocated / ${h.bitsStored} stored'),
            if (h.pixelSpacingRow != null)
              _metaRow('Pixel Spacing', '${h.pixelSpacingRow!.toStringAsFixed(3)} × ${h.pixelSpacingCol!.toStringAsFixed(3)} mm'),
            if (h.sliceThickness != null)
              _metaRow('Slice Thickness', '${h.sliceThickness!.toStringAsFixed(2)} mm'),
            if (h.sliceLocation != null)
              _metaRow('Slice Location', '${h.sliceLocation!.toStringAsFixed(1)} mm'),
            _metaRow('Photometric', h.photometricInterpretation),
            const Divider(color: Colors.white12, height: 14),
            _metaRow('Transfer Syntax', h.transferSyntaxLabel),
            if (h.manufacturer != null)
              _metaRow('Manufacturer', h.manufacturer!),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: _accent.withValues(alpha: 0.85),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String fileName) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121A),
        foregroundColor: Colors.white,
        title: Text(fileName),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Cannot display DICOM file or study',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error ?? 'Unknown error',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _loadDicomStudy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cross-Reference (Localizer / Scout) Lines Custom Painter
// ---------------------------------------------------------------------------
class DicomReferenceLineEntry {
  final DicomReferenceLine line;
  final Color color;

  const DicomReferenceLineEntry({required this.line, required this.color});
}

class _LocalizerLinesPainter extends CustomPainter {
  final List<DicomReferenceLineEntry> lines;
  final Size imageSize;

  _LocalizerLinesPainter({
    required this.lines,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final fitted = applyBoxFit(BoxFit.contain, imageSize, size);
    final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & size);

    Offset toCanvas(Offset p) {
      final normX = p.dx / imageSize.width;
      final normY = p.dy / imageSize.height;
      return Offset(
        dst.left + normX * dst.width,
        dst.top + normY * dst.height,
      );
    }

    for (final entry in lines) {
      final refLine = entry.line;
      final p1 = toCanvas(refLine.start);
      final p2 = toCanvas(refLine.end);

      // 1. Dark halo shadow so line is distinct on bright bone areas
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.7)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, shadowPaint);

      // 2. Main vivid reference line in the source viewport's accent color
      final linePaint = Paint()
        ..color = entry.color
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, linePaint);

      // 3. Small end dots for clarity
      final dotPaint = Paint()
        ..color = entry.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p1, 2.5, dotPaint);
      canvas.drawCircle(p2, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LocalizerLinesPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Ruler Custom Painter
// ---------------------------------------------------------------------------
class _RulerPainter extends CustomPainter {
  final List<DicomMeasurement> measurements;
  final DicomMeasurement? currentDraft;
  final Size imageSize;

  _RulerPainter({
    required this.measurements,
    this.currentDraft,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final fitted = applyBoxFit(BoxFit.contain, imageSize, size);
    final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & size);

    Offset toCanvas(Offset p) {
      final normX = p.dx / imageSize.width;
      final normY = p.dy / imageSize.height;
      return Offset(
        dst.left + normX * dst.width,
        dst.top + normY * dst.height,
      );
    }

    final linePaint = Paint()
      ..color = const Color(0xFFFACC15) // yellow medical caliper
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFFFACC15)
      ..style = PaintingStyle.fill;

    void drawMeasurement(DicomMeasurement m) {
      final p1 = toCanvas(m.start);
      final p2 = toCanvas(m.end);

      canvas.drawLine(p1, p2, linePaint);
      canvas.drawCircle(p1, 4, dotPaint);
      canvas.drawCircle(p2, 4, dotPaint);

      final textSpan = TextSpan(
        text: ' ${m.formattedDistance} ',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xFFFACC15),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final mid = Offset(
        (p1.dx + p2.dx) / 2 - textPainter.width / 2,
        (p1.dy + p2.dy) / 2 - 16,
      );
      textPainter.paint(canvas, mid);
    }

    for (final m in measurements) {
      drawMeasurement(m);
    }
    if (currentDraft != null) {
      drawMeasurement(currentDraft!);
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) => true;
}
