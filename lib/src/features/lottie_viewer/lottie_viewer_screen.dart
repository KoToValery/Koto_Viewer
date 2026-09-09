import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';

class LottieViewerScreen extends StatefulWidget {
  final String filePath;

  const LottieViewerScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<LottieViewerScreen> createState() => _LottieViewerScreenState();
}

class _LottieViewerScreenState extends State<LottieViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  LottieComposition? _composition;
  bool _isPlaying = true;
  bool _isLooping = true;
  double _playbackSpeed = 1.0;
  int _bgMode = 0; // 0=checkerboard, 1=dark, 2=light
  bool _isLoaded = false;
  String _animationName = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addListener(() {
      setState(() {});
    });
    _tryParseAnimationName();
  }

  Future<void> _tryParseAnimationName() async {
    try {
      final file = File(widget.filePath);
      final content = await file.readAsString();
      final data = jsonDecode(content);
      if (data is Map<String, dynamic> && data.containsKey('nm')) {
        setState(() {
          _animationName = data['nm']?.toString() ?? '';
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.stop();
      } else {
        if (_controller.value == 1.0) {
          _controller.value = 0.0;
        }
        _controller.forward();
        if (_isLooping) {
          _controller.repeat();
        }
      }
      _isPlaying = !_isPlaying;
    });
  }

  void _toggleLoop() {
    setState(() {
      _isLooping = !_isLooping;
      if (_isPlaying) {
        if (_isLooping) {
          _controller.repeat();
        } else {
          _controller.forward();
        }
      }
    });
  }

  void _changeSpeed(double speed) {
    if (_composition == null) return;
    setState(() {
      _playbackSpeed = speed;
      _controller.duration = Duration(
          milliseconds:
              (_composition!.duration.inMilliseconds * (1.0 / _playbackSpeed))
                  .round());
      if (_isPlaying) {
        if (_isLooping) {
          _controller.repeat();
        } else {
          _controller.forward();
        }
      }
    });
  }

  void _showInfoSheet() {
    if (_composition == null) return;
    final file = File(widget.filePath);
    final size = file.lengthSync();
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Animation Info',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_animationName.isNotEmpty)
                  Text('Name: $_animationName'),
                Text('Frame Rate: ${_composition!.frameRate} fps'),
                Text('Duration: ${_composition!.duration.inMilliseconds} ms'),
                Text('File Size: ${(size / 1024).toStringAsFixed(2)} KB'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckerboard() {
    return CustomPaint(
      painter: _CheckerboardPainter(),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildBackground() {
    switch (_bgMode) {
      case 1:
        return Container(color: Colors.black);
      case 2:
        return Container(color: Colors.white);
      case 0:
      default:
        return _buildCheckerboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        actions: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _isLoaded ? _togglePlayPause : null,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _isLoaded ? _showInfoSheet : null,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.shareXFiles([XFile(widget.filePath)]);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildBackground(),
                Center(
                  child: InteractiveViewer(
                    child: Lottie.file(
                      File(widget.filePath),
                      controller: _controller,
                      onLoaded: (composition) {
                        _composition = composition;
                        _controller.duration = composition.duration;
                        if (_isLooping) {
                          _controller.repeat();
                        } else {
                          _controller.forward();
                        }
                        setState(() => _isLoaded = true);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(_controller.value.toStringAsFixed(2)),
                    Expanded(
                      child: Slider(
                        value: _controller.value,
                        onChanged: (val) {
                          setState(() {
                            _controller.value = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: _isLoaded ? _togglePlayPause : null,
                      ),
                      IconButton(
                        icon: Icon(
                          _isLooping ? Icons.repeat_on : Icons.repeat,
                          color: _isLooping
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        onPressed: _isLoaded ? _toggleLoop : null,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('0.5x'),
                        selected: _playbackSpeed == 0.5,
                        onSelected: (_) => _changeSpeed(0.5),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('1x'),
                        selected: _playbackSpeed == 1.0,
                        onSelected: (_) => _changeSpeed(1.0),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('2x'),
                        selected: _playbackSpeed == 2.0,
                        onSelected: (_) => _changeSpeed(2.0),
                      ),
                      const SizedBox(width: 16),
                      ChoiceChip(
                        label: const Text('🔲'),
                        selected: _bgMode == 0,
                        onSelected: (_) => setState(() => _bgMode = 0),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('🌑'),
                        selected: _bgMode == 1,
                        onSelected: (_) => setState(() => _bgMode = 1),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('☀'),
                        selected: _bgMode == 2,
                        onSelected: (_) => setState(() => _bgMode = 2),
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
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double squareSize = 16.0;
    final paint1 = Paint()..color = const Color(0xFFCCCCCC);
    final paint2 = Paint()..color = const Color(0xFFFFFFFF);

    for (int y = 0; y < size.height / squareSize; y++) {
      for (int x = 0; x < size.width / squareSize; x++) {
        final paint = (x + y) % 2 == 0 ? paint1 : paint2;
        canvas.drawRect(
          Rect.fromLTWH(
              x * squareSize, y * squareSize, squareSize, squareSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
