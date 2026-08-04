import 'package:flutter/services.dart';

/// Native share service with filtered app categories
class NativeShareService {
  static const _channel = MethodChannel('com.koto.pdf_viewer/share');

  /// Share ONLY to Email apps (Gmail, Outlook, etc.)
  static Future<bool> shareViaEmail(
    String filePath, {
    String? subject,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('shareViaEmail', {
        'filePath': filePath,
        'subject': subject ?? 'PDF Document',
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error sharing via email: ${e.message}');
      return false;
    }
  }

  /// Share ONLY to Messaging apps (Viber, WhatsApp, Messenger, Telegram)
  static Future<bool> shareViaMessaging(
    String filePath, {
    String? text,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('shareViaMessaging', {
        'filePath': filePath,
        'text': text ?? 'PDF Document',
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error sharing via messaging: ${e.message}');
      return false;
    }
  }

  /// Share ONLY to Cloud Storage apps (Google Drive, Dropbox, OneDrive)
  static Future<bool> shareViaCloud(String filePath) async {
    try {
      final result = await _channel.invokeMethod<bool>('shareViaCloud', {
        'filePath': filePath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error sharing via cloud: ${e.message}');
      return false;
    }
  }

  /// Check if specific app is installed
  static Future<bool> isAppInstalled(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>('isAppInstalled', {
        'packageName': packageName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking app installation: ${e.message}');
      return false;
    }
  }
}
