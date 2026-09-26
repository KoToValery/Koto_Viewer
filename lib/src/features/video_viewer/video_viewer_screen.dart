import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/services/project_bundle_service.dart';
import '../project_viewer/widgets/project_presentation_bar.dart';

/// Full-screen high-performance video player designed for architectural presentations.
/// Supports MP4, MOV, MKV, WebM, AVI, etc. with immersive mode, looping,
/// speed controls, double-tap seek, and Project Presentation Switcher.
class VideoViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;
  final bool addToRecent;
  final ProjectBundleInfo? projectBundle;
  final int? currentProjectIndex;
  final void Function(int newIndex)? onSwitchProjectItem;

  const VideoViewerScreen({
    super.key,
    required this.filePath,
    this.title,
    this.addToRecent = true,
    this.projectBundle,
    this.currentProjectIndex,
    this.onSwitchProjectItem,
  });

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  bool _showControls = true;
  Timer? _hideControlsTimer;

  bool _isLooping = false;
  double _playbackSpeed = 1.0;
  bool _isMuted = false;
  double _lastVolume = 1.0;

  // Double-tap seek feedback
  bool _showSeekFeedback = false;
  bool _isSeekForward = true;
  Timer? _seekFeedbackTimer;

  // Orientation state
  bool _isLandscapeLocked = false;

  String get _displayName {
    if (widget.title != null && widget.title!.isNotEmpty) {
      return widget.title!;
    }
    return widget.filePath.split(Platform.pathSeparator).last.split('/').last;
  }

  @override
  void initState() {
    super.initState();
    // Schedule immersive sticky after the first frame to avoid window layout collisions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('Video file not found at ${widget.filePath}');
      }

      final controller = VideoPlayerController.file(file);
      _controller = controller;

      // Yield frame so the route transition animation completes cleanly without dropping frames
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onControllerUpdate);

      // Auto-adapt orientation if the video is wide (16:9 / horizontal)
      if (controller.value.aspectRatio > 1.2) {
        // Landscape video
      }

      await controller.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        _scheduleControlsHiding();
      }
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'VideoViewerScreen._initPlayer');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null) return;
    if (_controller!.value.hasError) {
      if (!_hasError) {
        setState(() {
          _hasError = true;
          _errorMessage = _controller!.value.errorDescription;
        });
      }
      return;
    }

    // Only rebuild the widget tree when controls are actually visible!
    // When controls are hidden, the native VideoPlayer texture renders on the GPU
    // without burdening the Flutter UI thread on every frame.
    if (_showControls) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();

    // Only restore system UI if exiting standalone viewer
    // (Presentation mode maintains immersive mode across slides and restores on exit)
    if (widget.projectBundle == null) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    super.dispose();
  }

  void _scheduleControlsHiding() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _scheduleControlsHiding();
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _hideControlsTimer?.cancel();
      setState(() {
        _showControls = true;
      });
    } else {
      _controller!.play();
      _scheduleControlsHiding();
    }
  }

  Future<void> _seekRelative(Duration offset, {required bool forward}) async {
    if (_controller == null || !_isInitialized) return;
    final current = _controller!.value.position;
    final total = _controller!.value.duration;
    var target = current + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;

    await _controller!.seekTo(target);

    // Show visual +10s / -10s ripple feedback
    _seekFeedbackTimer?.cancel();
    setState(() {
      _showSeekFeedback = true;
      _isSeekForward = forward;
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showSeekFeedback = false;
        });
      }
    });

    _scheduleControlsHiding();
  }

  void _toggleLooping() {
    if (_controller == null) return;
    final nextLoop = !_isLooping;
    _controller!.setLooping(nextLoop);
    setState(() {
      _isLooping = nextLoop;
    });
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nextLoop ? l10n.videoLoopOn : l10n.videoLoopOff),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _scheduleControlsHiding();
  }

  void _toggleOrientationLock() {
    final next = !_isLandscapeLocked;
    setState(() {
      _isLandscapeLocked = next;
    });

    if (next) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _scheduleControlsHiding();
  }

  void _toggleMute() {
    if (_controller == null) return;
    if (_isMuted) {
      _controller!.setVolume(_lastVolume > 0 ? _lastVolume : 1.0);
      setState(() {
        _isMuted = false;
      });
    } else {
      _lastVolume = _controller!.value.volume;
      _controller!.setVolume(0.0);
      setState(() {
        _isMuted = true;
      });
    }
    _scheduleControlsHiding();
  }

  void _setSpeed(double speed) {
    if (_controller == null) return;
    _controller!.setPlaybackSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
    });
    _scheduleControlsHiding();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Layer
            if (_isInitialized && _controller != null)
              GestureDetector(
                onTap: _toggleControls,
                onDoubleTapDown: (details) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < screenWidth / 2) {
                    _seekRelative(const Duration(seconds: -10), forward: false);
                  } else {
                    _seekRelative(const Duration(seconds: 10), forward: true);
                  }
                },
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio > 0
                        ? _controller!.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            else if (_hasError)
              _buildErrorView()
            else
              _buildLoadingView(),

            // Double tap feedback overlay
            if (_showSeekFeedback) _buildSeekFeedback(),

            // Controls Overlay
            if (_showControls && _isInitialized) _buildControlsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.amberAccent),
          SizedBox(height: 16),
          Text(
            'Loading video...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Could not play video',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unsupported format or corrupt video stream.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekFeedback() {
    return Positioned(
      left: _isSeekForward ? null : 40,
      right: _isSeekForward ? 40 : null,
      child: AnimatedOpacity(
        opacity: _showSeekFeedback ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isSeekForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                color: Colors.amberAccent,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _isSeekForward ? '+10s' : '-10s',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Action Bar
          _buildTopBar(),

          // Center Play/Pause & Skip Buttons
          _buildCenterControls(isPlaying),

          // Bottom Bar (Progress, Time, Loop, Speed, Project Next)
          _buildBottomBar(position, duration),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Loop Toggle
          IconButton(
            tooltip: _isLooping ? 'Loop: ON' : 'Loop: OFF',
            icon: Icon(
              Icons.repeat_rounded,
              color: _isLooping ? Colors.amberAccent : Colors.white70,
              size: 24,
            ),
            onPressed: _toggleLooping,
          ),
          // Speed Selector
          PopupMenuButton<double>(
            initialValue: _playbackSpeed,
            tooltip: 'Playback Speed',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            onSelected: _setSpeed,
            itemBuilder: (ctx) => [
              0.5,
              0.75,
              1.0,
              1.25,
              1.5,
              2.0,
            ].map((s) => PopupMenuItem(value: s, child: Text('${s}x'))).toList(),
          ),
          // Orientation lock
          IconButton(
            tooltip: _isLandscapeLocked ? 'Unlock Orientation' : 'Lock Landscape',
            icon: Icon(
              _isLandscapeLocked ? Icons.screen_lock_landscape_rounded : Icons.screen_rotation_rounded,
              color: _isLandscapeLocked ? Colors.amberAccent : Colors.white70,
              size: 24,
            ),
            onPressed: _toggleOrientationLock,
          ),
          // Mute / Unmute
          IconButton(
            tooltip: _isMuted ? 'Unmute' : 'Mute',
            icon: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: _isMuted ? Colors.redAccent : Colors.white70,
              size: 24,
            ),
            onPressed: _toggleMute,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 42,
          color: Colors.white,
          icon: const Icon(Icons.replay_10_rounded),
          onPressed: () => _seekRelative(const Duration(seconds: -10), forward: false),
        ),
        const SizedBox(width: 32),
        Material(
          color: Colors.amberAccent,
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _togglePlayPause,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 48,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(width: 32),
        IconButton(
          iconSize: 42,
          color: Colors.white,
          icon: const Icon(Icons.forward_10_rounded),
          onPressed: () => _seekRelative(const Duration(seconds: 10), forward: true),
        ),
      ],
    );
  }

  Widget _buildBottomBar(Duration position, Duration duration) {
    final maxMs = duration.inMilliseconds.toDouble();
    final posMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 0.0);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Project items bar if part of bundle
          if (widget.projectBundle != null) _buildProjectSwitchBar(),

          // Seek bar and times
          Row(
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.amberAccent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.amberAccent,
                    overlayColor: Colors.amberAccent.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: maxMs > 0 ? maxMs : 1.0,
                    value: posMs,
                    onChanged: (value) {
                      _controller?.seekTo(Duration(milliseconds: value.toInt()));
                      _scheduleControlsHiding();
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSwitchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ProjectPresentationBar(
        projectBundle: widget.projectBundle!,
        currentIndex: widget.currentProjectIndex ?? 0,
        onSwitchProjectItem: widget.onSwitchProjectItem,
        onExit: () => Navigator.of(context).pop(),
      ),
    );
  }
}
