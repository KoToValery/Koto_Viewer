import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/architect_elements.dart';
import 'architect_polygon_geometry.dart';
import 'architect_stair_geometry.dart';
import 'architect_stair_layout_resolver.dart';
import 'architect_stair_rules.dart';

enum StairDraftMode { flight, landing, cell, edit }

class ArchitectStairDraftController extends ChangeNotifier {
  ArchitectStair _stair;
  ArchitectStairLayout _layout;
  final bool create;
  final List<(ArchitectStair, ArchitectStairLayout)> _history = [];
  final List<(ArchitectStair, ArchitectStairLayout)> _future = [];
  StairDraftMode mode = StairDraftMode.flight;
  final points = <Offset>[];
  Offset? start, cursor, _entryAxis;
  String? selectedId;
  ArchitectStairDesign? fitCandidate;
  bool _gesture = false;
  ArchitectStair? _cachedPreview;
  (ArchitectStair, ArchitectStairLayout, ArchitectStairDesign?)? _previewKey;
  int _serial = 0;
  StairLayoutProblem? inputProblem;

  ArchitectStairDraftController(ArchitectStair stair, {required this.create})
    : _stair = stair,
      _layout = stair.design?.layout ?? ArchitectStairLayout(flights: []) {
    if (!create && stair.design?.layout == null) {
      _layout = ArchitectStairLayoutResolver.fromStair(stair);
    }
    _stair = _stair.copyWith(
      design: stair.design!.copyWith(
        layout: _layout.flights.isEmpty ? null : _layout,
        shape: StairShape.straight,
        winderSteps: false,
        manualGoing: stair.design!.going,
        autoRisers: create,
      ),
    );
    if (_layout.flights.isNotEmpty) {
      mode = StairDraftMode.edit;
      selectedId = _layout.flights.first.id;
    }
  }
  ArchitectStairLayout get layout => _layout;
  ArchitectStair get baseStair => _stair;
  ArchitectStairDesign get design => _layout.flights.isEmpty
      ? _stair.design!
      : _stair.design!.copyWith(
          layout: _layout.copyWith(
            landings: _layout.landings
                .take(_layout.flights.length - 1)
                .toList(),
          ),
        );
  bool get canUndo => _history.isNotEmpty || points.isNotEmpty || start != null;
  String _id(String kind) {
    final ids = {
      ..._layout.flights.map((f) => f.id),
      ..._layout.landings.map((l) => l.id),
    };
    var id = '';
    do {
      id = '${kind}_${_serial++}';
    } while (ids.contains(id));
    return id;
  }

  Offset toWorld(Offset p) =>
      _stair.startPoint +
      _stair.unitVector * p.dx +
      _stair.normalVector * p.dy * (design.turnLeft ? -1 : 1);
  Offset toLocal(Offset p) {
    final q = p - _stair.startPoint;
    return Offset(
      ArchitectStairGeometry.dot(q, _stair.unitVector),
      ArchitectStairGeometry.dot(q, _stair.normalVector) *
          (design.turnLeft ? -1 : 1),
    );
  }

  ArchitectStairFlightSpec? get selectedFlight =>
      _layout.flights.where((f) => f.id == selectedId).firstOrNull;
  ArchitectStairLandingSpec? get selectedLanding =>
      _layout.landings.where((l) => l.id == selectedId).firstOrNull;
  List<Offset> get selectedPolygon =>
      selectedId == 'cell' ? _layout.cell : selectedLanding?.polygon ?? [];
  bool get complete =>
      _layout.flights.isNotEmpty &&
      _layout.landings.length == _layout.flights.length - 1 &&
      start == null &&
      points.isEmpty;
  ArchitectStair? get preview {
    if (_layout.flights.isEmpty) return null;
    final key = (_stair, _layout, fitCandidate);
    if (key == _previewKey) return _cachedPreview;
    _previewKey = key;
    final l = _layout.copyWith(
      landings: _layout.landings.take(_layout.flights.length - 1).toList(),
    );
    return _cachedPreview = _stair.copyWith(
      width: l.flights.first.width,
      design: (fitCandidate ?? design).copyWith(
        layout: fitCandidate?.layout ?? l,
      ),
    );
  }

  List<StairLayoutIssue> get issues =>
      complete ? ArchitectStairLayoutResolver.check(preview!.design!) : [];
  void _remember() {
    _future.clear();
    _history.add((_stair, _layout));
    fitCandidate = null;
    inputProblem = null;
  }

  void undo() {
    fitCandidate = null;
    if (points.isNotEmpty) {
      points.removeLast();
    } else if (start != null) {
      start = null;
      _entryAxis = null;
    } else if (_history.isNotEmpty) {
      _future.add((_stair, _layout));
      final old = _history.removeLast();
      _stair = old.$1;
      _layout = old.$2;
      mode = StairDraftMode.edit;
      selectedId = null;
    }
    inputProblem = null;
    notifyListeners();
  }

  void redo() {
    if (_future.isEmpty) return;
    _history.add((_stair, _layout));
    final next = _future.removeLast();
    _stair = next.$1;
    _layout = next.$2;
    start = null;
    points.clear();
    selectedId = null;
    fitCandidate = null;
    inputProblem = null;
    mode = StairDraftMode.edit;
    notifyListeners();
  }

  void select(String id) {
    mode = StairDraftMode.edit;
    start = null;
    points.clear();
    selectedId = id;
    fitCandidate = null;
    notifyListeners();
  }

  void beginFlight() {
    if (_layout.flights.isNotEmpty &&
        _layout.landings.length != _layout.flights.length) {
      addLanding();
    }
    mode = StairDraftMode.flight;
    start = null;
    points.clear();
    inputProblem = null;
    notifyListeners();
  }

  void aim(Offset world) {
    cursor = toLocal(world);
    notifyListeners();
  }

  ArchitectStairFlightSpec? get candidateFlight {
    if (start == null || cursor == null) return null;
    var delta = cursor! - start!;
    if (_entryAxis != null)
      delta =
          _entryAxis! *
          math.max(0.0, ArchitectStairGeometry.dot(delta, _entryAxis!));
    if (delta.distance < .01) return null;
    final width = _layout.flights.lastOrNull?.width ?? _stair.width;
    return ArchitectStairFlightSpec(
      id: 'candidate',
      origin: start!,
      axis: delta / delta.distance,
      width: width,
      risers: math.max(2, (delta.distance / design.going).round() + 1),
    );
  }

  void pick(Offset world, {double tolerance = .15}) {
    final p = toLocal(world);
    cursor = p;
    inputProblem = null;
    if (mode == StairDraftMode.cell || mode == StairDraftMode.landing) {
      if (points.length >= 3 && (p - points.first).distance < tolerance) {
        finishPolygon();
        return;
      }
      points.add(p);
      notifyListeners();
      return;
    }
    if (mode == StairDraftMode.edit) {
      for (final f in _layout.flights.reversed) {
        if (ArchitectPolygonGeometry.contains(f.footprint(design.going), p)) {
          select(f.id);
          return;
        }
      }
      for (final l in _layout.landings.reversed) {
        if (ArchitectPolygonGeometry.contains(l.polygon, p)) {
          select(l.id);
          return;
        }
      }
      return;
    }
    if (start == null) {
      if (_layout.flights.isEmpty) {
        _remember();
        final delta = p;
        _layout = _layout.copyWith(
          cell: _layout.cell.map((q) => q - delta).toList(),
        );
        _stair = _stair.copyWith(
          startPoint: world,
          endPoint: world + _stair.unitVector,
        );
        start = Offset.zero;
        cursor = start;
        _entryAxis = null;
      } else {
        final polygon = _layout.landings.last.polygon;
        var best = tolerance;
        Offset? point, axis;
        final width = _layout.flights.last.width;
        for (var i = 0; i < polygon.length; i++) {
          final a = polygon[i], v = polygon[(i + 1) % polygon.length] - a;
          if (v.distance + 1e-6 < width) continue;
          final margin = math.min(.5, width / 2 / v.distance);
          final t = (ArchitectStairGeometry.dot(p - a, v) / v.distanceSquared)
              .clamp(margin, 1 - margin);
          final q = a + v * t;
          if ((q - p).distance > best) continue;
          final n = ArchitectPolygonGeometry.normal(polygon, i);
          final previous = _layout.flights.last;
          if (ArchitectStairGeometry.pointSegmentDistance(
                q,
                previous.end(design.going) -
                    previous.normal * previous.width / 2,
                previous.end(design.going) +
                    previous.normal * previous.width / 2,
              ) <
              1e-6)
            continue;
          best = (q - p).distance;
          point = q;
          axis = n;
        }
        if (point == null) {
          inputProblem = StairLayoutProblem.connection;
        } else {
          start = point;
          _entryAxis = axis;
        }
      }
    } else {
      final f = candidateFlight;
      if (f == null || _layout.risers + f.risers > 500) return;
      _remember();
      final added = ArchitectStairFlightSpec(
        id: _id('flight'),
        origin: f.origin,
        axis: f.axis,
        width: f.width,
        risers: f.risers,
      );
      _layout = _layout.copyWith(flights: [..._layout.flights, added]);
      selectedId = added.id;
      mode = StairDraftMode.edit;
      start = null;
      _entryAxis = null;
    }
    notifyListeners();
  }

  void addLanding() {
    if (_layout.flights.isEmpty ||
        _layout.landings.length >= _layout.flights.length)
      return;
    _remember();
    final f = _layout.flights.last, end = fEnd;
    final a = end - f.normal * f.width / 2, b = end + f.normal * f.width / 2;
    final depth = math.max(f.width, design.landingDepth);
    final l = ArchitectStairLandingSpec(
      id: _id('landing'),
      polygon: [a, a + f.axis * depth, b + f.axis * depth, b],
    );
    _layout = _layout.copyWith(landings: [..._layout.landings, l]);
    selectedId = l.id;
    mode = StairDraftMode.edit;
    notifyListeners();
  }

  Offset get fEnd => _layout.flights.last.end(design.going);
  void beginPolygon({required bool cell}) {
    start = null;
    points.clear();
    fitCandidate = null;
    if (!cell && selectedLanding == null) return;
    mode = cell ? StairDraftMode.cell : StairDraftMode.landing;
    notifyListeners();
  }

  void finishPolygon() {
    if (!ArchitectPolygonGeometry.valid(points)) {
      inputProblem = StairLayoutProblem.polygon;
      notifyListeners();
      return;
    }
    _remember();
    if (mode == StairDraftMode.cell) {
      _layout = _layout.copyWith(cell: List.of(points));
      selectedId = 'cell';
    } else {
      _layout = _layout.copyWith(
        landings: [
          for (final l in _layout.landings)
            l.id == selectedId ? l.copyWith(polygon: List.of(points)) : l,
        ],
      );
    }
    points.clear();
    mode = StairDraftMode.edit;
    notifyListeners();
  }

  void beginGesture() {
    if (!_gesture) {
      _remember();
      _gesture = true;
    }
  }

  void endGesture() {
    _gesture = false;
    notifyListeners();
  }

  void moveVertex(int index, Offset world) {
    final polygon = List<Offset>.of(selectedPolygon);
    if (index >= polygon.length) return;
    polygon[index] = toLocal(world);
    _replacePolygon(polygon);
    notifyListeners();
  }

  void moveEdge(int index, Offset worldDelta) {
    final polygon = List<Offset>.of(selectedPolygon);
    if (index >= polygon.length) return;
    final delta = toLocal(toWorld(Offset.zero) + worldDelta);
    polygon[index] += delta;
    polygon[(index + 1) % polygon.length] += delta;
    _replacePolygon(polygon);
    notifyListeners();
  }

  void insertVertex(int edge) {
    final p = ArchitectPolygonGeometry.insertMidpoint(selectedPolygon, edge);
    if (p != null) {
      _remember();
      _replacePolygon(p);
      notifyListeners();
    }
  }

  void removeVertex(int index) {
    final p = ArchitectPolygonGeometry.removeVertex(selectedPolygon, index);
    if (p != null) {
      _remember();
      _replacePolygon(p);
      notifyListeners();
    }
  }

  void _replacePolygon(List<Offset> polygon) {
    if (selectedId == 'cell') {
      _layout = _layout.copyWith(cell: polygon);
    } else {
      _layout = _layout.copyWith(
        landings: [
          for (final l in _layout.landings)
            l.id == selectedId ? l.copyWith(polygon: polygon) : l,
        ],
      );
    }
  }

  void updateFlight(ArchitectStairFlightSpec next, {bool remember = true}) {
    final old = _layout.flights.firstWhere((f) => f.id == next.id);
    if (remember) _remember();
    final index = _layout.flights.indexOf(old);
    List<Offset> portChange(
      List<Offset> polygon,
      Offset a,
      Offset b,
      Offset c,
      Offset e,
    ) => [
      for (final p in polygon)
        ArchitectStairGeometry.pointSegmentDistance(p, a, b) < 1e-6
            ? c +
                  (e - c) *
                      (ArchitectStairGeometry.dot(p - a, b - a) /
                          (b - a).distanceSquared)
            : p,
    ];
    final landings = List<ArchitectStairLandingSpec>.of(_layout.landings);
    for (final pair in [
      (index - 1, old.origin, next.origin),
      (index, old.end(design.going), next.end(design.going)),
    ]) {
      if (pair.$1 < 0 || pair.$1 >= landings.length) continue;
      final l = landings[pair.$1];
      landings[pair.$1] = l.copyWith(
        polygon: portChange(
          l.polygon,
          pair.$2 - old.normal * old.width / 2,
          pair.$2 + old.normal * old.width / 2,
          pair.$3 - next.normal * next.width / 2,
          pair.$3 + next.normal * next.width / 2,
        ),
      );
    }
    _layout = _layout.copyWith(
      flights: [for (final f in _layout.flights) f.id == next.id ? next : f],
      landings: landings,
    );
    notifyListeners();
  }

  void setRun(double value) {
    final f = selectedFlight;
    if (f == null || !value.isFinite || value <= 0) return;
    updateFlight(
      f.copyWith(
        fixedRun: value,
        risers: f.countLocked
            ? f.risers
            : math.max(2, (value / design.going).round() + 1),
      ),
    );
  }

  void replaceDesign(ArchitectStairDesign next) {
    _remember();
    _layout = ArchitectStairLayoutResolver.reconnect(
      _layout,
      _layout.copyWith(
        goingLocked: next.layout?.goingLocked ?? _layout.goingLocked,
      ),
      design.going,
      next.going,
    );
    _stair = _stair.copyWith(
      design: next.copyWith(
        clearLayout: _layout.flights.isEmpty,
        layout: _layout.flights.isEmpty
            ? null
            : _layout.copyWith(
                landings: _layout.landings
                    .take(_layout.flights.length - 1)
                    .toList(),
              ),
      ),
    );
    notifyListeners();
  }

  void setGoing(double value, {required bool locked}) {
    if (!value.isFinite || value <= 0) return;
    _remember();
    _layout = ArchitectStairLayoutResolver.reconnect(
      _layout,
      _layout.copyWith(goingLocked: locked),
      design.going,
      value,
    );
    _stair = _stair.copyWith(design: design.copyWith(manualGoing: value));
    notifyListeners();
  }

  void proposeFit() {
    if (!complete) return;
    fitCandidate = ArchitectStairLayoutResolver.fit(
      preview!.design!,
      accepts: (d) => !ArchitectStairRules.check(
        preview!.copyWith(design: d),
      ).any((c) => c.state == StairCheckState.error),
    );
    inputProblem = fitCandidate == null ? StairLayoutProblem.length : null;
    notifyListeners();
  }

  void acceptFit() {
    final next = fitCandidate;
    if (next == null) return;
    _remember();
    _layout = next.layout!;
    _stair = _stair.copyWith(design: next);
    notifyListeners();
  }

  void rejectFit() {
    fitCandidate = null;
    notifyListeners();
  }

  void removeLastPart() {
    if (_layout.flights.isEmpty) return;
    _remember();
    if (_layout.landings.length == _layout.flights.length) {
      _layout = _layout.copyWith(
        landings: _layout.landings.take(_layout.landings.length - 1).toList(),
      );
    } else {
      _layout = _layout.copyWith(
        flights: _layout.flights.take(_layout.flights.length - 1).toList(),
      );
    }
    selectedId = null;
    start = null;
    mode = StairDraftMode.edit;
    notifyListeners();
  }
}
