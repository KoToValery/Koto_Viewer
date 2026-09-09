import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';

class _IcoFrame {
  final int width;
  final int height;
  final Uint8List pngBytes;

  _IcoFrame({
    required this.width,
    required this.height,
    required this.pngBytes,
  });
}

class ImageViewerScreen extends StatefulWidget {
  final String filePath;

  const ImageViewerScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isLoading = true;
  String? _error;

  List<_IcoFrame>? _icoFrames;
  Uint8List? _psdBytes;
  bool _isIco = false;
  bool _isPsd = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final lower = widget.filePath.toLowerCase();
    _isIco = lower.endsWith('.ico');
    _isPsd = lower.endsWith('.psd') || lower.endsWith('.psb');

    try {
      if (_isIco) {
        final frames = await compute(_decodeIcoCompute, widget.filePath);
        if (mounted) {
          setState(() {
            _icoFrames = frames;
            _isLoading = false;
            if (frames.isEmpty) {
              _error = "Could not decode ICO frames.";
            }
          });
        }
      } else if (_isPsd) {
        final bytes = await compute(_decodePsdCompute, widget.filePath);
        if (mounted) {
          setState(() {
            _psdBytes = bytes;
            _isLoading = false;
            if (bytes == null) {
              _error = "Could not decode PSD file.";
            }
          });
        }
      } else {
        setState(() {
          _error = "Unsupported format.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  static List<_IcoFrame> _decodeIcoCompute(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    final decoder = img.IcoDecoder();
    if (!decoder.isValidFile(bytes)) return [];
    decoder.startDecode(bytes);
    final frames = <_IcoFrame>[];
    final count = (decoder.numFrames() as num).toInt();
    for (int i = 0; i < count; i++) {
      final frame = decoder.decodeFrame(i);
      if (frame != null) {
        frames.add(_IcoFrame(
          width: frame.width,
          height: frame.height,
          pngBytes: Uint8List.fromList(img.encodePng(frame)),
        ));
      }
    }
    // Sort by size descending
    frames.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return frames;
  }

  static Uint8List? _decodePsdCompute(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    final decoded = img.PsdDecoder().decode(bytes);
    if (decoded == null) return null;
    return Uint8List.fromList(img.encodePng(decoded));
  }

  void _showIcoFrameFullScreen(_IcoFrame frame) {
    showDialog(
      context: context,
      builder: (context) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('${frame.width} x ${frame.height}'),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(frame.pngBytes),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.shareXFiles([XFile(widget.filePath)]);
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    if (_isLoading) {
      final fileName = widget.filePath.split(Platform.pathSeparator).last;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Decoding $fileName...'),
          ],
        ),
      );
    }

    if (_isPsd && _psdBytes != null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(8.0),
            child: const Text(
              'Flattened composite preview — layers are not shown.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: Center(
              child: InteractiveViewer(
                child: Image.memory(_psdBytes!),
              ),
            ),
          ),
        ],
      );
    }

    if (_isIco && _icoFrames != null) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _icoFrames!.length,
        itemBuilder: (context, index) {
          final frame = _icoFrames![index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showIcoFrameFullScreen(frame),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.memory(frame.pngBytes, fit: BoxFit.contain),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${frame.width}x${frame.height}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return const SizedBox();
  }
}
