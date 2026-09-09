import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets/viewer_loading_screen.dart';
import 'dicom_parser.dart';
import 'dicom_renderer.dart';

// ---------------------------------------------------------------------------
// Compute isolate payload
// ---------------------------------------------------------------------------
class _ParsePayload {
  final String filePath;
  const _ParsePayload(this.filePath);
}

class _ParseResult {
  final DicomHeader header;
  final Uint8List fileBytes;
  const _ParseResult(this.header, this.fileBytes);
}

_ParseResult _parseInIsolate(_ParsePayload payload) {
  final bytes = File(payload.filePath).readAsBytesSync();
  final header = DicomParser.parse(bytes);
  return _ParseResult(header, bytes);
}

// ---------------------------------------------------------------------------
// Main screen
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

  // Parsed data
  DicomHeader? _header;
  Uint8List? _fileBytes;

  // Rendering state
  ui.Image? _currentImage;
  bool _isRendering = false;

  // Windowing
  double _windowCenter = 127;
  double _windowWidth = 256;
  bool _showWindowing = true;

  // Multi-frame navigation
  int _currentFrame = 0;

  // UI state
  bool _showMetadata = false;

  static const Color _accent = Color(0xFF0EA5E9); // cyan-blue, medical

  @override
  void initState() {
    super.initState();
    _loadDicom();
  }

  @override
  void dispose() {
    _currentImage?.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Loading
  // --------------------------------------------------------------------------

  Future<void> _loadDicom() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await compute(
        _parseInIsolate,
        _ParsePayload(widget.filePath),
      );

      if (!mounted) return;

      final header = result.header;

      // Determine initial windowing
      double wc = header.windowCenter ?? 127;
      double ww = header.windowWidth ?? 256;

      // Apply modality suggestion if header has no windowing
      if (header.windowCenter == null) {
        final preset = DicomRenderer.suggestPresetForModality(header.modality);
        if (preset != null) {
          wc = preset.center;
          ww = preset.width;
        }
      }

      setState(() {
        _header = header;
        _fileBytes = result.fileBytes;
        _windowCenter = wc;
        _windowWidth = ww.clamp(1, 65535);
        _showWindowing = header.isMonochrome && header.bitsAllocated >= 16;
        _isLoading = false;
      });

      await _renderFrame(0);
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

  Future<void> _renderFrame(int frameIndex) async {
    if (_header == null || _fileBytes == null) return;
    if (_isRendering) return;

    setState(() => _isRendering = true);

    try {
      final result = await DicomRenderer.renderFrame(
        fileBytes: _fileBytes!,
        header: _header!,
        frameIndex: frameIndex,
        windowCenter: _header!.isMonochrome ? _windowCenter : null,
        windowWidth: _header!.isMonochrome ? _windowWidth : null,
      );

      if (!mounted) return;

      final old = _currentImage;
      setState(() {
        _currentImage = result.image;
        _currentFrame = frameIndex;
        _isRendering = false;
      });
      // Dispose previous image after setState to avoid race
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
    _renderFrame(_currentFrame);
  }

  void _applyPreset(WindowPreset preset) {
    setState(() {
      _windowCenter = preset.center;
      _windowWidth = preset.width;
    });
    _renderFrame(_currentFrame);
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split(Platform.pathSeparator).last;
    final fileSize = File(widget.filePath).existsSync()
        ? File(widget.filePath).lengthSync()
        : 0;

    if (_isLoading) {
      return ViewerLoadingScreen(
        fileName: fileName,
        fileSizeBytes: fileSize,
        icon: Icons.medical_services_outlined,
        accentColor: _accent,
        loadingTitle: 'Parsing DICOM file...',
        statusMessage: 'Reading header & pixel data',
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
          // Metadata panel (collapsible)
          if (_header != null) _buildMetadataPanel(),
          // Image canvas
          Expanded(child: _buildImageCanvas()),
          // Bottom controls
          if (_header != null) _buildBottomControls(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String fileName) {
    return AppBar(
      backgroundColor: const Color(0xFF12121A),
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          if (_header != null)
            Text(
              '${_header!.modality ?? "DICOM"} · '
              '${_header!.rows}×${_header!.columns}'
              '${_header!.numberOfFrames > 1 ? " · ${_header!.numberOfFrames} frames" : ""}',
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
            ),
        ],
      ),
      actions: [
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

  // --------------------------------------------------------------------------
  // Metadata panel
  // --------------------------------------------------------------------------

  Widget _buildMetadataPanel() {
    if (!_showMetadata || _header == null) return const SizedBox.shrink();
    final h = _header!;

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
            _metaRow('Patient', h.formattedPatientName),
            if (h.patientId != null) _metaRow('Patient ID', h.patientId!),
            if (h.patientSex != null) _metaRow('Sex', h.patientSex!),
            if (h.patientBirthDate != null)
              _metaRow('DOB', h.patientBirthDate!),
            const Divider(color: Colors.white12, height: 14),
            _metaRow('Modality', h.modality ?? '—'),
            _metaRow('Study Date', h.formattedStudyDate),
            if (h.studyDescription != null)
              _metaRow('Study', h.studyDescription!),
            if (h.seriesDescription != null)
              _metaRow('Series', h.seriesDescription!),
            if (h.institutionName != null)
              _metaRow('Institution', h.institutionName!),
            const Divider(color: Colors.white12, height: 14),
            _metaRow('Dimensions', '${h.columns} × ${h.rows} px'),
            _metaRow('Bits', '${h.bitsAllocated} allocated / ${h.bitsStored} stored'),
            _metaRow('Photometric', h.photometricInterpretation),
            _metaRow('Samples/px', '${h.samplesPerPixel}'),
            if (h.numberOfFrames > 1)
              _metaRow('Frames', '${h.numberOfFrames}'),
            if (h.rescaleSlope != null)
              _metaRow('Rescale', 'm=${h.rescaleSlope} b=${h.rescaleIntercept}'),
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

  // --------------------------------------------------------------------------
  // Image canvas
  // --------------------------------------------------------------------------

  Widget _buildImageCanvas() {
    if (_currentImage == null) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }

    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.1,
          maxScale: 20,
          child: Center(
            child: RawImage(
              image: _currentImage,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
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
    );
  }

  // --------------------------------------------------------------------------
  // Bottom controls
  // --------------------------------------------------------------------------

  Widget _buildBottomControls() {
    final h = _header!;
    return Container(
      color: const Color(0xFF12121A),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Multi-frame navigation
          if (h.numberOfFrames > 1) _buildFrameNavigation(h),
          // Windowing controls
          if (_showWindowing) _buildWindowingControls(h),
        ],
      ),
    );
  }

  Widget _buildFrameNavigation(DicomHeader h) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.layers_outlined, color: Colors.white38, size: 14),
            const SizedBox(width: 6),
            Text(
              'Frame ${_currentFrame + 1} / ${h.numberOfFrames}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.skip_previous, color: Colors.white70, size: 20),
              onPressed: _currentFrame > 0
                  ? () => _renderFrame(_currentFrame - 1)
                  : null,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.skip_next, color: Colors.white70, size: 20),
              onPressed: _currentFrame < h.numberOfFrames - 1
                  ? () => _renderFrame(_currentFrame + 1)
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
            value: _currentFrame.toDouble(),
            min: 0,
            max: (h.numberOfFrames - 1).toDouble(),
            divisions: h.numberOfFrames > 1 ? h.numberOfFrames - 1 : null,
            onChanged: (v) => setState(() => _currentFrame = v.round()),
            onChangeEnd: (v) => _renderFrame(v.round()),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildWindowingControls(DicomHeader h) {
    final wcMin = -2048.0;
    final wcMax = 4096.0;
    final wwMin = 1.0;
    final wwMax = 8192.0;

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
                      label: Text(
                        p.name,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: const Color(0xFF1E1E30),
                      side: BorderSide(color: _accent.withValues(alpha: 0.3)),
                      labelStyle: const TextStyle(color: Colors.white70),
                      onPressed: () => _applyPreset(p),
                    ),
                  )),
              // Reset to header values
              if (h.windowCenter != null)
                ActionChip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  label: const Text(
                    'Reset',
                    style: TextStyle(fontSize: 11),
                  ),
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
        // Window Center
        _windowSlider(
          label: 'WC',
          value: _windowCenter,
          min: wcMin,
          max: wcMax,
          display: _windowCenter.toStringAsFixed(0),
          onChanged: (v) => setState(() => _windowCenter = v),
          onChangeEnd: (_) => _onWindowingChanged(),
        ),
        // Window Width
        _windowSlider(
          label: 'WW',
          value: _windowWidth,
          min: wwMin,
          max: wwMax,
          display: _windowWidth.toStringAsFixed(0),
          onChanged: (v) => setState(() => _windowWidth = v.clamp(1, wwMax)),
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
  // Error screen
  // --------------------------------------------------------------------------

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
                'Cannot display DICOM file',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
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
                onPressed: _loadDicom,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
