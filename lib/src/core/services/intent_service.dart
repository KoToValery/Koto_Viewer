import 'dart:async';
import 'package:flutter/services.dart';

class IntentService {
  static const MethodChannel _channel = MethodChannel('com.koto.pdfviewer/intent');

  void listenForPdfIntents(Function(String filePath) onPdfOpened) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPdfOpened') {
        final String? filePath = call.arguments as String?;
        if (filePath != null && filePath.isNotEmpty) {
          onPdfOpened(filePath);
        }
      }
    });

    _getInitialPdfPath().then((filePath) {
      if (filePath != null && filePath.isNotEmpty) {
        onPdfOpened(filePath);
      }
    });
  }

  Future<String?> _getInitialPdfPath() async {
    try {
      final String? path = await _channel.invokeMethod<String>('getInitialPdfPath');
      return path;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}
