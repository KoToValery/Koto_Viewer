import 'dart:async';
import 'package:flutter/services.dart';

class IntentService {
  static const MethodChannel _channel = MethodChannel('com.koto.kotoviewer/intent');

  void listenForFileIntents(Function(String filePath) onFileOpened) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileOpened' || call.method == 'onPdfOpened') {
        final String? filePath = call.arguments as String?;
        if (filePath != null && filePath.isNotEmpty) {
          onFileOpened(filePath);
        }
      }
    });

    _getInitialFilePath().then((filePath) {
      if (filePath != null && filePath.isNotEmpty) {
        onFileOpened(filePath);
      }
    });
  }

  /// Backward-compatible alias
  void listenForPdfIntents(Function(String filePath) onPdfOpened) =>
      listenForFileIntents(onPdfOpened);

  Future<String?> _getInitialFilePath() async {
    try {
      final String? path = await _channel.invokeMethod<String>('getInitialFilePath');
      return path;
    } catch (_) {
      try {
        return await _channel.invokeMethod<String>('getInitialPdfPath');
      } catch (_) {
        return null;
      }
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}
