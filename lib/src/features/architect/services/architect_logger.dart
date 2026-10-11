import 'package:flutter/foundation.dart';

/// Centralized diagnostic logging utility for the architectural workspace,
/// viewport gestures, zoom/pan transforms, and zone drafting/editing operations.
class ArchitectLogger {
  static bool enabled = kDebugMode;
  static final List<String> _history = [];
  static const int _maxHistory = 150;

  static List<String> get history => List.unmodifiable(_history);

  static void log(String category, String message) {
    if (!enabled && !kDebugMode) return;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final entry = '[$timeStr][$category] $message';

    _history.add(entry);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }

    debugPrint(entry);
  }

  static void clear() {
    _history.clear();
  }
}
