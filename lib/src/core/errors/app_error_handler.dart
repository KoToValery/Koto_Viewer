import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'global_crash_widget.dart';

/// Represents a single recorded error with metadata.
class AppErrorRecord {
  final DateTime timestamp;
  final dynamic error;
  final StackTrace? stackTrace;
  final String errorContext;
  final bool isFatal;

  AppErrorRecord({
    required this.timestamp,
    required this.error,
    this.stackTrace,
    this.errorContext = 'general',
    this.isFatal = false,
  });

  String get summary => error?.toString() ?? 'Unknown error';

  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.writeln('[$timestamp] Context: $errorContext | Fatal: $isFatal');
    buffer.writeln('Error: $error');
    if (stackTrace != null) {
      buffer.writeln('Stack Trace:');
      buffer.writeln(stackTrace);
    }
    return buffer.toString();
  }
}

/// Centralized error handler and logger for KoToViewer.
///
/// Hooks into Flutter framework errors, root isolate platform dispatcher errors,
/// and provides a friendly crash screen replacement for ErrorWidget.
class AppErrorHandler {
  static final List<AppErrorRecord> _errors = [];
  static const int maxStoredErrors = 100;
  static GlobalKey<NavigatorState>? navigatorKey;
  static bool _initialized = false;

  static List<AppErrorRecord> get errors => List.unmodifiable(_errors);

  /// Initializes all global error listeners and crash widget builder.
  static void init({GlobalKey<NavigatorState>? navKey}) {
    if (navKey != null) {
      navigatorKey = navKey;
    }

    if (_initialized) return;
    _initialized = true;

    // 1. Flutter Framework / Widget build errors
    FlutterError.onError = (FlutterErrorDetails details) {
      recordError(
        details.exception,
        details.stack,
        context: details.context?.toString() ?? 'FlutterError',
        isFatal: false,
      );

      // In debug mode, also dump to standard console
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }
    };

    // 2. Uncaught asynchronous errors in root isolate
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(
        error,
        stack,
        context: 'PlatformDispatcher.onError',
        isFatal: true,
      );
      // Return true so the runtime knows the error is handled
      return true;
    };

    // 3. User-friendly Crash Widget replacing red / grey screen of death
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return GlobalCrashWidget(details: details);
    };
  }

  /// Records an error in the memory buffer.
  static void recordError(
    dynamic error,
    StackTrace? stack, {
    String context = 'general',
    bool isFatal = false,
  }) {
    try {
      final record = AppErrorRecord(
        timestamp: DateTime.now(),
        error: error,
        stackTrace: stack,
        errorContext: context,
        isFatal: isFatal,
      );

      _errors.add(record);
      if (_errors.length > maxStoredErrors) {
        _errors.removeAt(0);
      }

      if (kDebugMode) {
        debugPrint('🚨 [AppErrorHandler] ($context) Error: $error');
      }
    } catch (_) {
      // Avoid recursive crash inside error handler
    }
  }

  /// Clears stored error history.
  static void clearErrors() {
    _errors.clear();
  }

  /// Generates a full formatted diagnostic report.
  static String exportErrorReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== KoToViewer Error Report ===');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    try {
      buffer.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    } catch (_) {}
    buffer.writeln('Total recorded errors: ${_errors.length}');
    buffer.writeln('================================\n');

    if (_errors.isEmpty) {
      buffer.writeln('No errors recorded in current session.');
    } else {
      for (int i = 0; i < _errors.length; i++) {
        buffer.writeln('--- Error #${i + 1} ---');
        buffer.writeln(_errors[i].toFormattedString());
        buffer.writeln();
      }
    }
    return buffer.toString();
  }
}
