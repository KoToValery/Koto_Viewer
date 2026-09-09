import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class FontViewerScreen extends StatefulWidget {
  final String filePath;

  const FontViewerScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<FontViewerScreen> createState() => _FontViewerScreenState();
}

class _FontViewerScreenState extends State<FontViewerScreen> {
  late final String _fontFamily;
  bool _isLoading = false;
  bool _fontLoaded = false;
  String? _error;
  double _fontSize = 24.0;
  final TextEditingController _customTextController = TextEditingController(
      text: 'The quick brown fox jumps over the lazy dog');

  @override
  void initState() {
    super.initState();
    _fontFamily = 'KotoPreview_${widget.filePath.hashCode.abs()}';
    _loadFont();
  }

  Future<void> _loadFont() async {
    final lower = widget.filePath.toLowerCase();
    if (lower.endsWith('.woff') || lower.endsWith('.woff2')) {
      setState(() {
        _error = "WOFF/WOFF2 preview is not supported. Please convert to TTF or OTF first.";
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final fontLoader = FontLoader(_fontFamily);
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await fontLoader.load();
      setState(() {
        _fontLoaded = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _customTextController.dispose();
    super.dispose();
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

    if (_isLoading || !_fontLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionTitle('Size Specimens'),
              _buildSizeSpecimens(),
              const Divider(height: 32),
              _buildSectionTitle('Alphabet'),
              Text(
                'A B C D E F G H I J K L M N O P Q R S T U V W X Y Z\na b c d e f g h i j k l m n o p q r s t u v w x y z',
                style: TextStyle(fontFamily: _fontFamily, fontSize: 24),
              ),
              const Divider(height: 32),
              _buildSectionTitle('Cyrillic'),
              Text(
                'Съешь же ещё этих мягких французских булок, да выпей чаю',
                style: TextStyle(fontFamily: _fontFamily, fontSize: _fontSize),
              ),
              const Divider(height: 32),
              _buildSectionTitle('Digits & Symbols'),
              Text(
                '0123456789 !@#%&*()-+=<>?',
                style: TextStyle(fontFamily: _fontFamily, fontSize: 20),
              ),
              const Divider(height: 32),
              _buildSectionTitle('Custom Text'),
              TextField(
                controller: _customTextController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Type here to preview',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text(
                _customTextController.text,
                style: TextStyle(fontFamily: _fontFamily, fontSize: _fontSize),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              const Icon(Icons.format_size, size: 16),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 12.0,
                  max: 96.0,
                  divisions: 84,
                  label: '${_fontSize.round()} pt',
                  onChanged: (val) {
                    setState(() {
                      _fontSize = val;
                    });
                  },
                ),
              ),
              const Icon(Icons.format_size, size: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSizeSpecimens() {
    const sizes = [12.0, 18.0, 24.0, 36.0, 48.0];
    const text = 'The quick brown fox jumps over the lazy dog';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sizes.map((size) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 40,
                child: Text('${size.round()}',
                    style: const TextStyle(color: Colors.grey)),
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontFamily: _fontFamily, fontSize: size),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
