// === SECTION: TABLE OF CONTENTS ===
// 1. RoofDrawMode (Rectangle 2-point vs. Polygon multi-point drafting)
// 2. ArchitectRoofTool (Interactive state machine, drafting points, auto-roof & eaves edge switching)

import 'package:flutter/material.dart';
import '../models/architect_project.dart';
import 'architect_element_id.dart';
import 'architect_roof_geometry.dart';

// === SECTION: ROOF DRAW MODE ===

enum RoofDrawMode {
  rectangle,
  polygon,
  multiPitch,
}

// === SECTION: ARCHITECT ROOF TOOL ===

class ArchitectRoofTool extends ChangeNotifier {
  RoofDrawMode drawMode = RoofDrawMode.rectangle;
  double slopeDegrees = 22.0;
  double eavesOverhang = 0.50;
  ArchitectRoofEavesCut eavesCut = ArchitectRoofEavesCut.plumb;
  ArchitectRoofAssembly activeAssembly = ArchitectRoofAssembly.fromPreset(
    ArchitectRoofPreset.pitchedTiles,
  );

  final List<Offset> draftPoints = [];
  Offset? candidatePoint;
  String? lastSnapLabel;
  List<(Offset, Offset)> activeMagneticGuides = const [];

  bool get isDrafting => draftPoints.isNotEmpty;

  void setDrawMode(RoofDrawMode mode) {
    if (drawMode == mode) return;
    drawMode = mode;
    clearDraft();
  }

  void setSlopeDegrees(double value) {
    slopeDegrees = value.clamp(0.0, 75.0);
    notifyListeners();
  }

  void setEavesOverhang(double value) {
    eavesOverhang = value.clamp(0.0, 2.50);
    notifyListeners();
  }

  void setEavesCut(ArchitectRoofEavesCut value) {
    eavesCut = value;
    notifyListeners();
  }

  void setAssembly(ArchitectRoofAssembly value) {
    activeAssembly = value;
    notifyListeners();
  }

  void setPreset(ArchitectRoofPreset preset) {
    activeAssembly = ArchitectRoofAssembly.fromPreset(preset);
    if (preset == ArchitectRoofPreset.flatWarm && slopeDegrees > 5.0) {
      slopeDegrees = 1.5;
      eavesOverhang = 0.0;
    } else if (preset != ArchitectRoofPreset.flatWarm && slopeDegrees < 5.0) {
      slopeDegrees = 22.0;
      if (eavesOverhang == 0.0) eavesOverhang = 0.50;
    }
    notifyListeners();
  }

  void updateCandidate(
    Offset? point, {
    String? snapLabel,
    List<(Offset, Offset)> magneticGuides = const [],
  }) {
    candidatePoint = point;
    lastSnapLabel = snapLabel;
    activeMagneticGuides = magneticGuides;
    notifyListeners();
  }

  /// Adds a point during interactive drafting.
  /// In `RoofDrawMode.rectangle`, the 2nd point immediately completes and returns the new plane.
  /// In `RoofDrawMode.polygon` or `multiPitch`, tapping near the first point closes and returns the planes.
  List<ArchitectRoofPlane>? addDraftPoint(
    Offset point, {
    required ArchitectStorey storey,
    double closeRadius = 0.35,
  }) {
    if (drawMode == RoofDrawMode.rectangle) {
      if (draftPoints.isEmpty) {
        draftPoints.add(point);
        candidatePoint = point;
        notifyListeners();
        return null;
      }
      final p0 = draftPoints.first;
      final rect = Rect.fromPoints(p0, point);
      if (rect.width < 0.25 || rect.height < 0.25) {
        return null;
      }
      final corners = [
        rect.topLeft,
        rect.topRight,
        rect.bottomRight,
        rect.bottomLeft,
      ];
      // Default eaves to the longer edge nearest to the first picked point
      final eavesIdx = rect.width >= rect.height
          ? ((p0.dy - rect.top).abs() <= (p0.dy - rect.bottom).abs() ? 0 : 2)
          : ((p0.dx - rect.right).abs() <= (p0.dx - rect.left).abs() ? 1 : 3);
      final created = _buildPlane(
        storey: storey,
        points: corners,
        eavesEdgeIndex: eavesIdx,
      );
      clearDraft();
      return [created];
    }

    // Polygon or Multi-pitch mode
    if (draftPoints.length >= 3 &&
        (point - draftPoints.first).distance <= closeRadius) {
      return finishDraft(storey: storey);
    }
    if (draftPoints.isEmpty || (point - draftPoints.last).distance > 0.05) {
      draftPoints.add(point);
      candidatePoint = point;
      notifyListeners();
    }
    return null;
  }

  /// Closes the draft and generates either a single polygon plane or a coordinated multi-pitch roof.
  List<ArchitectRoofPlane>? finishDraft({required ArchitectStorey storey}) {
    if (drawMode == RoofDrawMode.multiPitch) {
      return finishMultiPitchDraft(storey: storey);
    }
    final single = finishPolygonDraft(storey: storey);
    return single != null ? [single] : null;
  }

  ArchitectRoofPlane? finishPolygonDraft({required ArchitectStorey storey}) {
    if (draftPoints.length < 3) return null;
    final pts = List<Offset>.from(draftPoints);
    final created = _buildPlane(
      storey: storey,
      points: pts,
      eavesEdgeIndex: 0,
    );
    clearDraft();
    return created;
  }

  List<ArchitectRoofPlane>? finishMultiPitchDraft({
    required ArchitectStorey storey,
  }) {
    if (draftPoints.length < 3) return null;
    final pts = List<Offset>.from(draftPoints);
    final planes = ArchitectRoofGeometry.decomposeMultiPitchPolygon(
      eavesPolygon: pts,
      storey: storey,
      slopeDegrees: slopeDegrees,
      baseElevationOffset: storey.height,
      eavesOverhang: eavesOverhang,
      assembly: activeAssembly,
    );
    clearDraft();
    return planes.isNotEmpty ? planes : null;
  }

  void undoLastDraftPoint() {
    if (draftPoints.isNotEmpty) {
      draftPoints.removeLast();
      notifyListeners();
    }
  }

  void clearDraft() {
    draftPoints.clear();
    candidatePoint = null;
    lastSnapLabel = null;
    activeMagneticGuides = const [];
    notifyListeners();
  }

  /// Preview polygon for the 2D canvas while drafting.
  List<Offset> get previewPolygon {
    if (draftPoints.isEmpty) return const [];
    if (drawMode == RoofDrawMode.rectangle) {
      final p0 = draftPoints.first;
      final p1 = candidatePoint ?? p0;
      final r = Rect.fromPoints(p0, p1);
      return [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    }
    return [
      ...draftPoints,
      if (candidatePoint != null &&
          (candidatePoint! - draftPoints.last).distance > 0.02)
        candidatePoint!,
    ];
  }

  ArchitectRoofPlane _buildPlane({
    required ArchitectStorey storey,
    required List<Offset> points,
    required int eavesEdgeIndex,
  }) => ArchitectRoofPlane(
    id: ArchitectElementId.next('roof'),
    storeyId: storey.id,
    points: points,
    eavesEdgeIndex: eavesEdgeIndex,
    slopeDegrees: slopeDegrees,
    baseElevationOffset: storey.height,
    eavesOverhang: eavesOverhang,
    eavesCut: eavesCut,
    assembly: activeAssembly.copyWith(),
  );

  /// Finds if [worldPoint] taps near an edge of [roof] (within [tolerance] metres)
  /// so the user can switch which edge is the eaves with 1 tap!
  static int? hitTestEdgeIndex(
    ArchitectRoofPlane roof,
    Offset worldPoint, {
    double tolerance = 0.35,
  }) {
    if (roof.points.length < 3) return null;
    var bestIdx = -1;
    var bestDist = tolerance;
    for (var i = 0; i < roof.points.length; i++) {
      final a = roof.points[i];
      final b = roof.points[(i + 1) % roof.points.length];
      final d = _pointToSegmentDistance(worldPoint, a, b);
      if (d <= bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx >= 0 ? bestIdx : null;
  }

  static List<ArchitectRoofPlane> generateAutoRoof({
    required ArchitectProject project,
    required AutoRoofType type,
    required ArchitectRoofTool tool,
  }) => ArchitectRoofGeometry.generateAutoRoof(
    project: project,
    type: type,
    slopeDegrees: tool.slopeDegrees,
    eavesOverhang: tool.eavesOverhang,
    preset: tool.activeAssembly.preset,
  );

  static double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-8) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lenSq).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}
