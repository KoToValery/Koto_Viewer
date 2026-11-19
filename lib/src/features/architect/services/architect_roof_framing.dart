import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import '../rendering/architect_path_solid.dart';
import '../rendering/architect_vertical_clip.dart';
import 'architect_roof_junctions.dart';
import 'architect_roof_ridge_beams.dart';
import 'architect_roof_wall_plates.dart';

enum ArchitectRoofDiagonalKind { hip, valley }

/// A single timber shared by two roof planes. The upper face follows the
/// seam's longitudinal slope and sits below the timber faces on both sides.
class ArchitectRoofDiagonalRafter {
  final ArchitectRoofDiagonalKind kind;
  final Offset start, end;
  final List<String> roofIds;
  final double width, depth;
  final Path footprint;
  final double _startTop, _endTop;

  const ArchitectRoofDiagonalRafter._(
    this.kind,
    this.start,
    this.end,
    this.roofIds,
    this.width,
    this.depth,
    this.footprint,
    this._startTop,
    this._endTop,
  );

  Offset get axis => (end - start) / (end - start).distance;

  double topAt(Offset p) =>
      _startTop +
      (_endTop - _startTop) *
          BimLineGeometry.parameter(p, start, end, finite: false);

  double bottomAt(Offset p) => topAt(p) - depth;

  List<Triangle3D> mesh({Path? planClip, bool openSeam = false}) {
    final path = planClip == null
        ? footprint
        : Path.combine(PathOperation.intersect, footprint, planClip);
    final triangles = ArchitectPathSolid.between(
      path,
      bottomAt,
      topAt,
      const Color(0xffb8864b),
      contourTolerance: .00001,
    );
    if (!openSeam) return triangles;
    // The assembled timber has no vertical face where its two roof owners meet.
    final normal = Offset(-axis.dy, axis.dx);
    bool isInteriorSeam(Triangle3D face) {
      if (face.normal.z.abs() > 1e-7) return false;
      final vertices = [face.v0, face.v1, face.v2];
      if (!vertices.every(
        (v) =>
            BimLineGeometry.dot(Offset(v.x, v.y) - start, normal).abs() < 1e-5,
      )) {
        return false;
      }
      final center = (face.v0 + face.v1 + face.v2) * (1 / 3);
      final p = Offset(center.x, center.y);
      return footprint.contains(p + normal * .0001) &&
          footprint.contains(p - normal * .0001);
    }

    return triangles.where((face) => !isInteriorSeam(face)).toList();
  }
}

/// The layout and solids used by 3D and roof sections at timber junctions.
/// It operates on the resolved roof footprints, including trimmed valleys.
class ArchitectRoofFraming {
  static const _planTolerance = .0001;
  static const _joinHeightTolerance = .001;
  final List<ArchitectRoofDiagonalRafter> diagonals;
  final Map<String, _RafterField> _fields;
  final double _elevation;

  ArchitectRoofFraming._(this.diagonals, this._fields, this._elevation);

  bool joins(ArchitectRoofPlane roof) =>
      diagonals.any((beam) => beam.roofIds.contains(roof.id));

  static (double, double) _verticalRafterOffsets(ArchitectRoofPlane roof) {
    final cosine = math.max(math.cos(roof.slopeRadians), .25);
    final bottom = roof.assembly.preset == ArchitectRoofPreset.logTimber
        ? (roof.assembly.totalThickness -
                  ArchitectRoofWallPlate.rafterBottomDepth(roof)) /
              cosine
        : 0.0;
    return (bottom, bottom + roof.assembly.timber.rafterHeight / cosine);
  }

  static ArchitectRoofFraming build(
    ArchitectStorey storey,
    ArchitectRoofJunctions junctions,
    List<ArchitectRoofRidgeBeam> ridges,
  ) {
    final roofs = [
      for (final roof in storey.roofs)
        if (roof.assembly.panels == null &&
            roof.assembly.timber.hasRafters &&
            roof.slopeDegrees >= 1 &&
            roof.points.length >= 3)
          roof,
    ]..sort((a, b) => a.id.compareTo(b.id));
    final fields = {
      for (final roof in roofs)
        roof.id: _RafterField(roof, junctions.footprint(roof)),
    };
    final beams = <ArchitectRoofDiagonalRafter>[];
    if (fields.length < 2) {
      return ArchitectRoofFraming._(beams, fields, storey.elevation);
    }
    for (var i = 0; i < roofs.length; i++) {
      final a = fields[roofs[i].id]!;
      for (final roof in roofs.skip(i + 1)) {
        final b = fields[roof.id]!;
        if (!a.bounds.inflate(_planTolerance).overlaps(b.bounds)) continue;
        final pairFootprint = Path.combine(
          PathOperation.union,
          a.footprint,
          b.footprint,
        );
        for (final (start, end) in _sharedEdges(a, b)) {
          final axis = (end - start) / (end - start).distance;
          final normal = Offset(-axis.dy, axis.dx);
          final mid = (start + end) / 2;
          const probe = .002;
          final aInside = a.footprint.contains(mid + normal * probe)
              ? normal
              : -normal;
          if (!a.footprint.contains(mid + aInside * probe) ||
              !b.footprint.contains(mid - aInside * probe)) {
            continue;
          }
          final aRoof = a.roof, bRoof = b.roof;
          bool meets(double Function(Offset) za, double Function(Offset) zb) =>
              [start, mid, end].every(
                (point) => (za(point) - zb(point)).abs() < _joinHeightTolerance,
              );
          if (!meets(aRoof.topElevationAt, bRoof.topElevationAt) &&
              !meets(aRoof.undersideElevationAt, bRoof.undersideElevationAt)) {
            continue;
          }
          final fold =
              aRoof.topElevationAt(mid + aInside * probe) -
              aRoof.topElevationAt(mid) +
              bRoof.topElevationAt(mid - aInside * probe) -
              bRoof.topElevationAt(mid);
          if (fold.abs() < 1e-6) continue;
          final kind = fold > 0
              ? ArchitectRoofDiagonalKind.valley
              : ArchitectRoofDiagonalKind.hip;
          if (kind == ArchitectRoofDiagonalKind.hip &&
              (aRoof.topElevationAt(start) - aRoof.topElevationAt(end)).abs() <
                  _joinHeightTolerance) {
            continue; // The existing level ridge owns this fold.
          }
          final width = [
            a.width,
            b.width,
            aRoof.assembly.timber.ridgePurlinWidth,
            bRoof.assembly.timber.ridgePurlinWidth,
          ].reduce(math.max);
          final aBand = _verticalRafterOffsets(aRoof);
          final bBand = _verticalRafterOffsets(bRoof);
          final depth = [
            aBand.$2 - aBand.$1,
            bBand.$2 - bBand.$1,
            aRoof.assembly.timber.ridgePurlinHeight,
            bRoof.assembly.timber.ridgePurlinHeight,
          ].reduce(math.max);
          final side = aInside * (width / 2);
          double timberTop(Offset p) =>
              storey.elevation +
              [
                aRoof.undersideElevationAt(p) + aBand.$2,
                bRoof.undersideElevationAt(p) + bBand.$2,
                aRoof.undersideElevationAt(p + side) + aBand.$2,
                bRoof.undersideElevationAt(p - side) + bBand.$2,
              ].reduce(math.min);
          final strip = _polygon([
            start + side,
            end + side,
            end - side,
            start - side,
          ]);
          var outline = Path.combine(
            PathOperation.intersect,
            strip,
            pairFootprint,
          );
          final startTop = timberTop(start), endTop = timberTop(end);
          double topAt(Offset p) =>
              startTop +
              (endTop - startTop) *
                  BimLineGeometry.dot(p - start, axis) /
                  (end - start).distance;
          void trimAt(
            Path seat,
            ArchitectHeightPlane bottom,
            ArchitectHeightPlane top,
          ) {
            if (!outline.getBounds().overlaps(seat.getBounds())) return;
            final overlap = Path.combine(
              PathOperation.intersect,
              outline,
              seat,
            );
            final belowTop = ArchitectVerticalClip.positive(
              overlap,
              (p) => topAt(p) - bottom(p) - 1e-7,
            );
            final cut = ArchitectVerticalClip.positive(
              belowTop,
              (p) => top(p) - topAt(p) + depth - 1e-7,
            );
            outline = Path.combine(PathOperation.difference, outline, cut);
          }

          for (final ridge in ridges) {
            trimAt(ridge.footprint, (_) => ridge.bottom, (_) => ridge.top);
          }
          for (final beam in beams) {
            trimAt(beam.footprint, beam.bottomAt, beam.topAt);
          }
          if (outline.getBounds().isEmpty) continue;
          beams.add(
            ArchitectRoofDiagonalRafter._(
              kind,
              start,
              end,
              [aRoof.id, bRoof.id],
              width,
              depth,
              outline,
              startTop,
              endTop,
            ),
          );
          _pairStations(a, b, start, end);
        }
      }
    }
    return ArchitectRoofFraming._(beams, fields, storey.elevation);
  }

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  static Iterable<(Offset, Offset)> _sharedEdges(
    _RafterField first,
    _RafterField second,
  ) sync* {
    for (final (a, b) in first.edges) {
      final length = (b - a).distance;
      if (length < .02) continue;
      final axis = (b - a) / length;
      for (final (c, d) in second.edges) {
        if (BimLineGeometry.cross(axis, c - a).abs() > _planTolerance ||
            BimLineGeometry.cross(axis, d - a).abs() > _planTolerance) {
          continue;
        }
        final from = BimLineGeometry.dot(axis, c - a);
        final to = BimLineGeometry.dot(axis, d - a);
        final low = math.max(0.0, math.min(from, to));
        final high = math.min(length, math.max(from, to));
        if (high - low >= .02) yield (a + axis * low, a + axis * high);
      }
    }
  }

  static void _pairStations(
    _RafterField a,
    _RafterField b,
    Offset start,
    Offset end,
  ) {
    final aRun = (a.station(end) - a.station(start)).abs();
    final bRun = (b.station(end) - b.station(start)).abs();
    final count = math.max(
      1,
      math.max(aRun / a.spacing, bRun / b.spacing).ceil(),
    );
    if (aRun / count < a.width || bRun / count < b.width) return;
    for (final field in [a, b]) {
      final s0 = field.station(start), s1 = field.station(end);
      field.pairedRanges.add((math.min(s0, s1), math.max(s0, s1)));
      for (var i = 0; i < count; i++) {
        field.pairedStations.add(s0 + (s1 - s0) * (i + .5) / count);
      }
    }
  }

  /// Each rafter is a separate solid so a section can expose the gaps and
  /// slice the same end cuts used in the 3D model.
  Iterable<List<Triangle3D>> rafters(
    ArchitectRoofPlane roof, {
    required List<ArchitectRoofRidgeBeam> seats,
    Rect? sectionBounds,
  }) sync* {
    final field = _fields[roof.id]!;
    final low = roof.points.map((p) => field.run(p)).reduce(math.min);
    final high = roof.points.map((p) => field.run(p)).reduce(math.max);
    var clearFootprint = field.footprint;
    for (final beam in diagonals) {
      if (!beam.roofIds.contains(roof.id)) continue;
      clearFootprint = Path.combine(
        PathOperation.difference,
        clearFootprint,
        beam.footprint,
      );
    }
    final (bottom, top) = _verticalRafterOffsets(roof);
    double bottomAt(Offset p) =>
        _elevation + roof.undersideElevationAt(p) + bottom;
    double topAt(Offset p) => _elevation + roof.undersideElevationAt(p) + top;
    final knuckle = low + roof.effectiveBreakDistance;
    for (final station in field.stations()) {
      final a = station - field.width / 2, b = station + field.width / 2;
      final pieces = roof.isMansard && knuckle > low + .1 && knuckle < high - .1
          ? [(low, knuckle), (knuckle, high)]
          : [(low, high)];
      for (final (from, to) in pieces) {
        final strip = _polygon([
          field.point(a, from),
          field.point(b, from),
          field.point(b, to),
          field.point(a, to),
        ]);
        if (sectionBounds != null &&
            !strip.getBounds().overlaps(sectionBounds)) {
          continue;
        }
        final outline = Path.combine(
          PathOperation.intersect,
          clearFootprint,
          strip,
        );
        if (outline.getBounds().isEmpty) continue;
        var parts = [ArchitectVerticalPart(outline, bottomAt, topAt)];
        for (final seat in seats) {
          parts = ArchitectVerticalClip.subtract(
            parts,
            seat.footprint,
            (_) => seat.bottom,
            (_) => seat.top,
          );
        }
        for (final part in parts) {
          yield [
            for (final triangle in ArchitectPathSolid.between(
              part.path,
              part.bottom,
              part.top,
              const Color(0xffd7a86e),
              contourTolerance: .00001,
            ))
              Triangle3D(
                v0: triangle.v0,
                v1: triangle.v1,
                v2: triangle.v2,
                color: triangle.normal.z > 1e-7
                    ? const Color(0xffd7a86e)
                    : const Color(0xffc49256),
                isDoubleSided: true,
              ),
          ];
        }
      }
    }
  }
}

class _RafterField {
  final ArchitectRoofPlane roof;
  final Path footprint;
  final Rect bounds;
  final List<(double, double)> pairedRanges = [];
  final List<double> pairedStations = [];
  late final Offset _origin = roof.eavesEdge.$1;
  late final Offset _up = roof.slopeDirection;
  late final Offset _across = Offset(_up.dy, -_up.dx);
  late final List<(Offset, Offset)> edges = [
    for (final ring in ArchitectPathSolid.contours(
      footprint,
      tolerance: .00001,
    ))
      for (var i = 0; i < ring.length; i++)
        (ring[i], ring[(i + 1) % ring.length]),
  ];

  _RafterField(this.roof, this.footprint) : bounds = footprint.getBounds();

  double get width => roof.assembly.timber.rafterWidth.clamp(.05, .16);
  double get spacing => math.max(.35, roof.assembly.timber.rafterSpacing);
  double station(Offset p) => BimLineGeometry.dot(p - _origin, _across);
  double run(Offset p) => BimLineGeometry.dot(p - _origin, _up);
  Offset point(double station, double run) =>
      _origin + _across * station + _up * run;

  Iterable<double> stations() sync* {
    final distances = roof.points.map(station);
    final low = distances.reduce(math.min), high = distances.reduce(math.max);
    final candidates = [...pairedStations];
    pairedRanges.sort((a, b) => a.$1.compareTo(b.$1));
    void fill(double from, double to) {
      final length = to - from;
      if (length < width) return;
      final count = (length / spacing).ceil();
      for (var i = 0; i < count; i++) {
        candidates.add(from + length * (i + .5) / count);
      }
    }

    var cursor = low;
    for (final (from, to) in pairedRanges) {
      fill(cursor, from);
      cursor = math.max(cursor, to);
    }
    fill(cursor, high);
    final sorted = candidates..sort();
    double? last;
    for (final s in sorted) {
      if (last != null && s - last < width - 1e-7) continue;
      yield s;
      last = s;
    }
  }
}
