import 'dart:async';

import 'package:flutter/foundation.dart';

import '../analysis/load_rundown.dart';
import '../models/element_check_models.dart';
import '../models/structural_element.dart';

// === SECTION: INDEX ===
// === SECTION: CONTROLLER ===
//
// Runs the preliminary checks off the UI thread. A newer request supersedes
// an older one; a result for a superseded project is dropped, never shown.
// Between a project change and its result the previous report stays visible
// and `isStale` is true, so the UI can dim it instead of flashing empty.

// === SECTION: CONTROLLER ===

typedef CheckRunner = Future<PreliminaryCheckReport> Function(
  StructuralProject project,
  double cadUnitsPerMeter,
);

Future<PreliminaryCheckReport> _runLiveInIsolate(
  StructuralProject project,
  double cadUnitsPerMeter,
) => compute(LoadRundown.analyzeEntry, (project, cadUnitsPerMeter));

Future<PreliminaryCheckReport> _runFullInIsolate(
  StructuralProject project,
  double cadUnitsPerMeter,
) => compute(LoadRundown.analyzeFullEntry, (project, cadUnitsPerMeter));

class PreliminaryCheckController extends ChangeNotifier {
  PreliminaryCheckController({
    CheckRunner? runner,
    CheckRunner? fullRunner,
    this.debounce = const Duration(milliseconds: 180),
  }) : _runner = runner ?? _runLiveInIsolate,
       _fullRunner = fullRunner ?? runner ?? _runFullInIsolate;

  final CheckRunner _runner;
  final CheckRunner _fullRunner;
  final Duration debounce;

  PreliminaryCheckReport _report = PreliminaryCheckReport.empty;
  bool _stale = false;
  bool _running = false;
  bool _fullRunning = false;
  Object? _error;
  int _revision = 0;
  Timer? _timer;
  bool _disposed = false;

  PreliminaryCheckReport get report => _report;

  /// The shown report belongs to an older version of the project.
  bool get isStale => _stale;
  bool get isRunning => _running;
  bool get isFullRunning => _fullRunning;

  /// Non-null when the last run failed; the previous report is kept.
  Object? get error => _error;

  /// Schedules a fast live check of [project] (0.50 m mesh).
  void request(
    StructuralProject project,
    double cadUnitsPerMeter, {
    bool immediate = false,
  }) {
    _schedule(project, cadUnitsPerMeter, immediate: immediate, full: false);
  }

  /// Runs an immediate full-precision building check (0.25 m mesh).
  Future<PreliminaryCheckReport?> requestFull(
    StructuralProject project,
    double cadUnitsPerMeter,
  ) => _schedule(project, cadUnitsPerMeter, immediate: true, full: true);

  Future<PreliminaryCheckReport?> _schedule(
    StructuralProject project,
    double cadUnitsPerMeter, {
    required bool immediate,
    required bool full,
  }) {
    final revision = ++_revision;
    _timer?.cancel();
    if (!_stale) {
      _stale = true;
      _notify();
    }
    final completer = Completer<PreliminaryCheckReport?>();

    Future<void> run() async {
      _running = true;
      _fullRunning = full;
      _notify();
      try {
        final fn = full ? _fullRunner : _runner;
        final result = await fn(project, cadUnitsPerMeter);
        if (revision != _revision || _disposed) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        _report = result;
        _error = null;
        _stale = false;
        if (!completer.isCompleted) completer.complete(result);
      } catch (e) {
        if (revision != _revision || _disposed) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        _error = e;
        if (!completer.isCompleted) completer.complete(null);
      } finally {
        if (revision == _revision) {
          _running = false;
          _fullRunning = false;
        }
      }
      _notify();
    }

    if (immediate) {
      unawaited(run());
    } else {
      _timer = Timer(debounce, () => unawaited(run()));
    }
    return completer.future;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
