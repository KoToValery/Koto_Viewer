import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets/viewer_loading_screen.dart';
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

  // Study & Series state
  DicomStudyItem? _study;
  int _activeSeriesIndex = 0;
  int _currentSliceIndex = 0;

  // Rendering state
  ui.Image? _currentImage;
  bool _isRendering = false;

  // Windowing
  double _windowCenter = 127;
  double _windowWidth = 256;
  bool _showWindowing = true;

  // Interaction modes: Pan/Zoom, Window/Level, Ruler
  DicomInteractionMode _interactionMode = DicomInteractionMode.panZoom;

  // Measurement states
  final List<DicomMeasurement> _measurements = [];
  DicomMeasurement? _draftMeasurement;

  // Cine loop playback
  Timer? _cineTimer;
  bool _isPlayingCine = false;

  // UI state
  bool _showMetadata = false;
  bool _showOverlays = true;

  static const Color _accent = Color(0xFF0EA5E9); // cyan-blue medical accent

  DicomSeriesItem get _activeSeries =>
      _study!.series[_activeSeriesIndex.clamp(0, _study!.series.length - 1)];

  DicomSliceItem get _currentSlice =>
      _activeSeries.slices[_currentSliceIndex.clamp(0, _activeSeries.sliceCount - 1)];

  DicomHeader get _currentHeader => _currentSlice.header;

  @override
  void initState() {
    super.initState();
    _loadDicomStudy();
  }

  @override
  void dispose() {
    _stopCine();
    _currentImage?.dispose();
    _study?.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Loading
  // --------------------------------------------------------------------------

  Future<void> _loadDicomStudy() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final study = await DicomStudyLoader.load(widget.filePath);

      if (!mounted) return;

      final firstHeader = study.series.first.firstSlice.header;
      double? wc = firstHeader.windowCenter;
      double? ww = firstHeader.windowWidth;

      if (wc == null) {
        final preset = DicomRenderer.suggestPresetForModality(firstHeader.modality);
        if (preset != null) {
          wc = preset.center;
          ww = preset.width;
        }
      }

      setState(() {
        _study = study;
        _activeSeriesIndex = 0;
        _currentSliceIndex = 0;
        _windowCenter = wc ?? 127;
        _windowWidth = (ww ?? 256).clamp(1, 65535);
        _showWindowing = firstHeader.isMonochrome && firstHeader.bitsAllocated >= 16;
        _isLoading = false;
      });

      await _renderCurrentSlice(initialWc: wc, initialWw: ww);
    } on DicomParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'DICOM Parse Error:\n${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // --------------------------------------------------------------------------
  // Rendering
  // --------------------------------------------------------------------------

  Future<void> _renderCurrentSlice({double? initialWc, double? initialWw}) async {
    if (_study == null || _activeSeries.slices.isEmpty) return;
    if (_isRendering) return;

    setState(() => _isRendering = true);

    try {
      final slice = _currentSlice;
      final bytes = await slice.getBytes();
      final header = slice.header;

      final overrideWc = initialWc ?? (header.isMonochrome ? _windowCenter : null);
      final overrideWw = initialWw ?? (header.isMonochrome ? _windowWidth : null);

      final result = await DicomRenderer.renderFrame(
        fileBytes: bytes,
        header: header,
        frameIndex: slice.frameIndex,
        windowCenter: overrideWc,
        windowWidth: overrideWw,
      );

      if (!mounted) return;

      final old = _currentImage;
      setState(() {
        _currentImage = result.image;
        if (initialWc == null || initialWw == null) {
          _windowCenter = result.windowCenter.clamp(-2048.0, 4096.0);
          _windowWidth = result.windowWidth.clamp(1.0, 8192.0);
        }
        _isRendering = false;
      });
      old?.dispose();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isRendering = false;
      });
    }
  }

  void _onWindowingChanged() {
    _renderCurrentSlice();
  }

  void _applyPreset(WindowPreset preset) {
    setState(() {
      _windowCenter = preset.center;
      _windowWidth = preset.width;
    });
    _renderCurrentSlice();
  }

  // --------------------------------------------------------------------------
  // Navigation
  // --------------------------------------------------------------------------

  void _goToSlice(int index) {
    if (_study == null) return;
    final maxSlice = _activeSeries.sliceCount - 1;
    final target = index.clamp(0, maxSlice);
    if (target != _currentSliceIndex) {
      setState(() {
        _currentSliceIndex = target;
        _measurements.clear();
      });
      _renderCurrentSlice();
    }
  }

  void _switchSeries(int seriesIndex) {
    if (_study == null || seriesIndex == _activeSeriesIndex) return;
    _stopCine();
    setState(() {
      _activeSeriesIndex = seriesIndex;
      _currentSliceIndex = 0;
      _measurements.clear();
    });

    final header = _activeSeries.firstSlice.header;
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
      _windowCenter = wc ?? 127;
      _windowWidth = (ww ?? 256).clamp(1, 65535);
      _showWindowing = header.isMonochrome && header.bitsAllocated >= 16;
    });

    _renderCurrentSlice(initialWc: wc, initialWw: ww);
  }

  void _toggleCine() {
    if (_isPlayingCine) {
      _stopCine();
    } else {
      _startCine();
    }
  }

  void _startCine() {
    if (_activeSeries.sliceCount <= 1) return;
    setState(() => _isPlayingCine = true);
    _cineTimer?.cancel();
    _cineTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final next = (_currentSliceIndex + 1) % _activeSeries.sliceCount;
      _goToSlice(next);
    });
  }

  void _stopCine() {
    _cineTimer?.cancel();
    _cineTimer = null;
    if (mounted) setState(() => _isPlayingCine = false);
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
      return ViewerLoadingScreen(
        fileName: fileName,
        fileSizeBytes: fileSize,
        icon: Icons.medical_services_outlined,
        accentColor: _accent,
        loadingTitle: 'Loading DICOM study...',
        statusMessage: 'Scanning series, slices & metadata',
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
          // Multi-series tab selector if multiple series exist
          if (_study != null && _study!.series.length > 1)
            _buildSeriesSelector(),

          // Metadata panel (collapsible)
          if (_study != null) _buildMetadataPanel(),

          // Interaction mode toolbar
          _buildToolbar(),

          // Image canvas with overlays & gesture support
          Expanded(child: _buildImageCanvas()),

          // Bottom navigation & Windowing controls
          if (_study != null) _buildBottomControls(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String fileName) {
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
          Text(
            '${_activeSeries.modality} · ${h.columns}×${h.rows}'
            '${_activeSeries.sliceCount > 1 ? " · ${_activeSeries.sliceCount} slices" : ""}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      actions: [
        // Overlay toggle
        IconButton(
          icon: Icon(
            _showOverlays ? Icons.grid_view : Icons.grid_off_outlined,
            color: _showOverlays ? _accent : Colors.white60,
          ),
          tooltip: 'Toggle HUD text',
          onPressed: () => setState(() => _showOverlays = !_showOverlays),
        ),
        // Metadata toggle
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

  Widget _buildSeriesSelector() {
    return Container(
      height: 42,
      color: const Color(0xFF161622),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: _study!.series.length,
        itemBuilder: (context, index) {
          final s = _study!.series[index];
          final isSelected = index == _activeSeriesIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              selected: isSelected,
              label: Text(
                '${s.seriesDescription} (${s.sliceCount})',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
              ),
              selectedColor: _accent.withValues(alpha: 0.35),
              backgroundColor: const Color(0xFF1E1E2E),
              side: BorderSide(
                color: isSelected ? _accent : Colors.white12,
              ),
              onSelected: (selected) {
                if (selected && index != _activeSeriesIndex) {
                  _switchSeries(index);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
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
          if (_measurements.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.amberAccent,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.clear, size: 14),
              label: Text('Clear (${_measurements.length})',
                  style: const TextStyle(fontSize: 11)),
              onPressed: () => setState(() => _measurements.clear()),
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
  // Image Canvas with Gesture support & HUD Overlays
  // --------------------------------------------------------------------------

  Widget _buildImageCanvas() {
    if (_currentImage == null) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    final imageSize = Size(
      _currentImage!.width.toDouble(),
      _currentImage!.height.toDouble(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              if (event.scrollDelta.dy > 0) {
                _goToSlice(_currentSliceIndex + 1);
              } else if (event.scrollDelta.dy < 0) {
                _goToSlice(_currentSliceIndex - 1);
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
                      image: _currentImage,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),

              // 2. Gesture Detector for Window/Level and Ruler modes
              if (_interactionMode != DicomInteractionMode.panZoom)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      if (_interactionMode == DicomInteractionMode.ruler) {
                        final imgCoords = _screenToImageCoords(
                            details.localPosition, constraints.biggest, imageSize);
                        if (imgCoords != null) {
                          setState(() {
                            _draftMeasurement = DicomMeasurement(
                              start: imgCoords,
                              end: imgCoords,
                              pixelSpacingRow: _currentHeader.pixelSpacingRow,
                              pixelSpacingCol: _currentHeader.pixelSpacingCol,
                            );
                          });
                        }
                      }
                    },
                    onPanUpdate: (details) {
                      if (_interactionMode == DicomInteractionMode.windowLevel) {
                        setState(() {
                          _windowWidth = (_windowWidth + details.delta.dx * 3.0)
                              .clamp(1.0, 8192.0);
                          _windowCenter = (_windowCenter - details.delta.dy * 3.0)
                              .clamp(-2048.0, 4096.0);
                        });
                        _onWindowingChanged();
                      } else if (_interactionMode == DicomInteractionMode.ruler &&
                          _draftMeasurement != null) {
                        final imgCoords = _screenToImageCoords(
                            details.localPosition, constraints.biggest, imageSize);
                        if (imgCoords != null) {
                          setState(() {
                            _draftMeasurement = DicomMeasurement(
                              start: _draftMeasurement!.start,
                              end: imgCoords,
                              pixelSpacingRow: _currentHeader.pixelSpacingRow,
                              pixelSpacingCol: _currentHeader.pixelSpacingCol,
                            );
                          });
                        }
                      }
                    },
                    onPanEnd: (_) {
                      if (_interactionMode == DicomInteractionMode.ruler &&
                          _draftMeasurement != null) {
                        setState(() {
                          _measurements.add(_draftMeasurement!);
                          _draftMeasurement = null;
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
                      measurements: _measurements,
                      currentDraft: _draftMeasurement,
                      imageSize: imageSize,
                    ),
                  ),
                ),
              ),

              // 4. Medical HUD Corner Overlays
              if (_showOverlays) _buildHudOverlays(),

              // 5. Rendering indicator
              if (_isRendering)
                const Positioned(
                  bottom: 8,
                  right: 8,
                  child: SizedBox(
                    width: 18,
                    height: 18,
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

  Widget _buildHudOverlays() {
    final h = _currentHeader;
    final series = _activeSeries;

    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              // Top-Left: Patient Name, ID, Age/Sex
              Align(
                alignment: Alignment.topLeft,
                child: _hudText(
                  '${_study?.patientName ?? h.formattedPatientName}\n'
                  'ID: ${_study?.patientId ?? h.patientId ?? "—"}'
                  '${_study?.patientAge != null ? "\nAge: ${_study!.patientAge}" : ""}'
                  '${_study?.patientSex != null ? " (${_study!.patientSex})" : ""}',
                ),
              ),
              // Top-Right: Modality, Study Date, Series Description
              Align(
                alignment: Alignment.topRight,
                child: _hudText(
                  '${series.modality} · ${_study?.studyDate ?? h.formattedStudyDate}\n'
                  '${series.seriesDescription}\n'
                  '${h.institutionName ?? ""}',
                  textAlign: TextAlign.right,
                ),
              ),
              // Bottom-Left: Slice info, thickness, Windowing
              Align(
                alignment: Alignment.bottomLeft,
                child: _hudText(
                  'Slice: ${_currentSliceIndex + 1} / ${series.sliceCount}'
                  '${h.formattedSliceLocation != null ? "\nLoc: ${h.formattedSliceLocation}" : ""}'
                  '${h.formattedSliceThickness != null ? "\nThick: ${h.formattedSliceThickness}" : ""}\n'
                  'W: ${_windowWidth.toInt()}  L: ${_windowCenter.toInt()}',
                ),
              ),
              // Bottom-Right: Matrix & Spacing
              Align(
                alignment: Alignment.bottomRight,
                child: _hudText(
                  '${h.columns}×${h.rows} px\n'
                  '${h.pixelSpacingRow != null ? "Pixel: ${h.pixelSpacingRow!.toStringAsFixed(2)} mm" : ""}\n'
                  '${_study != null && _study!.series.length > 1 ? "Series ${_activeSeriesIndex + 1}/${_study!.series.length}" : ""}',
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hudText(String text, {TextAlign textAlign = TextAlign.left}) {
    return Text(
      text,
      textAlign: textAlign,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 4),
          Shadow(color: Colors.black, blurRadius: 8),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Bottom Controls
  // --------------------------------------------------------------------------

  Widget _buildBottomControls() {
    final h = _currentHeader;
    return Container(
      color: const Color(0xFF12121A),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slice navigation (if series has multiple slices)
          if (_activeSeries.sliceCount > 1) _buildSliceNavigation(),
          // Windowing controls
          if (_showWindowing) _buildWindowingControls(h),
        ],
      ),
    );
  }

  Widget _buildSliceNavigation() {
    final count = _activeSeries.sliceCount;
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.layers_outlined, color: Colors.white38, size: 14),
            const SizedBox(width: 6),
            Text(
              'Slice ${_currentSliceIndex + 1} / $count',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Spacer(),
            // Cine Loop Play/Pause
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                _isPlayingCine ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: _isPlayingCine ? _accent : Colors.white70,
                size: 22,
              ),
              tooltip: _isPlayingCine ? 'Pause Cine' : 'Play Cine',
              onPressed: _toggleCine,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.skip_previous, color: Colors.white70, size: 20),
              onPressed: _currentSliceIndex > 0
                  ? () => _goToSlice(_currentSliceIndex - 1)
                  : null,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.skip_next, color: Colors.white70, size: 20),
              onPressed: _currentSliceIndex < count - 1
                  ? () => _goToSlice(_currentSliceIndex + 1)
                  : null,
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _accent,
            thumbColor: _accent,
            inactiveTrackColor: Colors.white12,
            overlayColor: _accent.withValues(alpha: 0.2),
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: _currentSliceIndex.toDouble(),
            min: 0,
            max: (count - 1).toDouble(),
            divisions: count > 1 ? count - 1 : null,
            onChanged: (v) => _goToSlice(v.round()),
          ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildWindowingControls(DicomHeader h) {
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
                      side: BorderSide(color: _accent.withValues(alpha: 0.3)),
                      labelStyle: const TextStyle(color: Colors.white70),
                      onPressed: () => _applyPreset(p),
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
                      _windowCenter = h.windowCenter!;
                      _windowWidth = h.windowWidth ?? 256;
                    });
                    _onWindowingChanged();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Window Center (Level)
        _windowSlider(
          label: 'WC',
          value: _windowCenter,
          min: -2048.0,
          max: 4096.0,
          display: _windowCenter.toStringAsFixed(0),
          onChanged: (v) => setState(() => _windowCenter = v),
          onChangeEnd: (_) => _onWindowingChanged(),
        ),
        // Window Width
        _windowSlider(
          label: 'WW',
          value: _windowWidth,
          min: 1.0,
          max: 8192.0,
          display: _windowWidth.toStringAsFixed(0),
          onChanged: (v) => setState(() => _windowWidth = v.clamp(1, 8192.0)),
          onChangeEnd: (_) => _onWindowingChanged(),
        ),
      ],
    );
  }

  Widget _windowSlider({
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
              color: _accent.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _accent,
              thumbColor: _accent,
              inactiveTrackColor: Colors.white12,
              overlayColor: _accent.withValues(alpha: 0.15),
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
            _metaRow('Modality', _activeSeries.modality),
            _metaRow('Study Date', _study?.studyDate ?? h.formattedStudyDate),
            if (h.studyDescription != null)
              _metaRow('Study', h.studyDescription!),
            _metaRow('Series', _activeSeries.seriesDescription),
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
