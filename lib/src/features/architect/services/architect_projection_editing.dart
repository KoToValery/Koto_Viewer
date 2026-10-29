import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import 'architect_selection.dart';
import 'architect_slab_geometry.dart';
import 'architect_command_controller.dart';

enum ArchitectProjectionKind {
  door,
  window,
  roof,
  stair,
  column,
  beam,
  slab,
  wall,
}

enum ArchitectOpeningDistance { left, right, sill, head }

class ArchitectProjectedElement {
  final String id;
  final ArchitectStorey storey;
  final ArchitectProjectionKind kind;
  final ArchitectWall? host;
  const ArchitectProjectedElement(this.id, this.storey, this.kind, [this.host]);
  bool get isOpening => host != null;
}

class ArchitectOpeningMeasure {
  final ArchitectOpeningDistance kind;
  final double value;
  final Offset from, to;
  const ArchitectOpeningMeasure(this.kind, this.value, this.from, this.to);
}

class ArchitectProjectionEditing {
  static ArchitectProjectedElement? find(ArchitectProject p, String id) {
    for (final s in p.storeys) {
      for (final w in s.walls) {
        if (w.doors.any((e) => e.id == id)) {
          return ArchitectProjectedElement(
            id,
            s,
            ArchitectProjectionKind.door,
            w,
          );
        }
        if (w.windows.any((e) => e.id == id)) {
          return ArchitectProjectedElement(
            id,
            s,
            ArchitectProjectionKind.window,
            w,
          );
        }
        if (w.id == id) {
          return ArchitectProjectedElement(id, s, ArchitectProjectionKind.wall);
        }
      }
      if (s.roofs.any((e) => e.id == id)) {
        return ArchitectProjectedElement(id, s, ArchitectProjectionKind.roof);
      }
      if (s.stairs.any((e) => e.id == id)) {
        return ArchitectProjectedElement(id, s, ArchitectProjectionKind.stair);
      }
      if (s.columns.any((e) => e.id == id)) {
        return ArchitectProjectedElement(id, s, ArchitectProjectionKind.column);
      }
      if (s.beams.any((e) => e.id == id)) {
        return ArchitectProjectedElement(id, s, ArchitectProjectionKind.beam);
      }
      if (s.slabs.any((e) => e.id == id)) {
        return ArchitectProjectedElement(id, s, ArchitectProjectionKind.slab);
      }
    }
    return null;
  }

  static String? pick(
    ArchitectProject project,
    Map<String, Path> paths,
    Offset point,
    double tolerance,
  ) {
    final candidates = paths.entries
        .where((e) => find(project, e.key) != null)
        .toList();
    candidates.sort((a, b) {
      final ar = find(project, a.key)!, br = find(project, b.key)!;
      final priority = ar.kind.index.compareTo(br.kind.index);
      return priority != 0
          ? priority
          : a.value.getBounds().size.shortestSide.compareTo(
              b.value.getBounds().size.shortestSide,
            );
    });
    for (final margin in [0.0, tolerance]) {
      for (final e in candidates) {
        if (!e.value.getBounds().inflate(margin).contains(point)) continue;
        if (e.value.contains(point) ||
            (margin > 0 &&
                [
                  Offset(margin, 0),
                  Offset(-margin, 0),
                  Offset(0, margin),
                  Offset(0, -margin),
                ].any((d) => e.value.contains(point + d)))) {
          return e.key;
        }
      }
    }
    return null;
  }

  static ArchitectProject properties(
    ArchitectProject p,
    String id,
    Map<String, double> values,
    Map<String, String> texts,
  ) {
    final ref = find(p, id);
    if (ref == null) throw ArgumentError('Unknown element');
    final result =
        SetArchitectElementProperties(
              storeyId: ref.storey.id,
              elementIds: {id},
              values: values,
              textValues: texts,
            )
            .apply(p.copyWith(activeStoreyId: ref.storey.id))
            .copyWith(activeStoreyId: p.activeStoreyId);
    if (ref.isOpening) validateOpening(result, id);
    return result;
  }

  static Map<String, dynamic> _record(
    ArchitectProject p,
    ArchitectProjectedElement ref,
  ) => ArchitectSelection.record(
    p.copyWith(activeStoreyId: ref.storey.id),
    ref.id,
  );

  /// Nominal jamb/sill/head edges, unaffected by trim or partial visibility.
  static Rect? openingBounds(
    ArchitectProject p,
    String id,
    Offset origin,
    Offset right,
  ) {
    final ref = find(p, id);
    if (ref == null || !ref.isOpening) return null;
    final host = ref.host!, data = _record(p, ref);
    final centre =
        host.centerStart +
        host.unitVector *
            ((data['offsetRatio'] as num).toDouble() * host.length) -
        origin;
    final x = centre.dx * right.dx + centre.dy * right.dy;
    final half =
        (data['width'] as num).toDouble() /
        2 *
        (host.unitVector.dx * right.dx + host.unitVector.dy * right.dy).abs();
    final z =
        ref.storey.elevation +
        host.baseOffset +
        (data['sillHeight'] as num).toDouble();
    return Rect.fromLTRB(
      x - half,
      z,
      x + half,
      z + (data['height'] as num).toDouble(),
    );
  }

  static ArchitectProject align(
    ArchitectProject p,
    String id,
    String side,
    Offset origin,
    Offset right,
    Iterable<String> visible,
  ) {
    final a = openingBounds(p, id, origin, right);
    if (a == null) throw ArgumentError('Not an opening');
    final lateral = side == 'left' || side == 'right';
    final candidates = <Rect>[];
    for (final target in visible) {
      if (target == id) continue;
      final b = openingBounds(p, target, origin, right);
      if (b != null) candidates.add(b);
    }
    candidates.sort((b, c) {
      // Side edges normally line up openings on successive floors. Avoid
      // aligning a jamb through an adjacent opening on the same floor.
      bool overlaps(Rect r) =>
          math.min(a.bottom, r.bottom) - math.max(a.top, r.top) > 1e-6;
      final priority = lateral
          ? (overlaps(b) ? 1 : 0).compareTo(overlaps(c) ? 1 : 0)
          : 0;
      return priority != 0
          ? priority
          : (b.center - a.center).distance.compareTo(
              (c.center - a.center).distance,
            );
    });
    for (final b in candidates) {
      final delta = switch (side) {
        'left' => Offset(b.left - a.left, 0),
        'right' => Offset(b.right - a.right, 0),
        'sill' => Offset(0, b.top - a.top),
        'head' => Offset(0, b.bottom - a.bottom),
        _ => throw ArgumentError('Unknown alignment'),
      };
      try {
        return move(p, id, delta, right, elevation: true);
      } on ArgumentError {
        // Continue to the next visible reference that fits the real host.
      }
    }
    throw ArgumentError('No compatible alignment reference');
  }

  static void validateOpening(ArchitectProject p, String id) {
    final ref = find(p, id)!;
    final record = _record(p, ref), host = ref.host!;
    final width = (record['width'] as num).toDouble(),
        height = (record['height'] as num).toDouble();
    final sill = (record['sillHeight'] as num).toDouble(),
        along = (record['offsetRatio'] as num).toDouble() * host.length;
    if (width < .001 ||
        height < .001 ||
        sill < -1e-4 ||
        sill + height > host.effectiveHeight(ref.storey.height) + 1e-4 ||
        along - width / 2 < -1e-4 ||
        along + width / 2 > host.length + 1e-4) {
      throw ArgumentError('Opening outside host');
    }
    for (final other in [
      ...host.doors.map((e) => e.toJson()),
      ...host.windows.map((e) => e.toJson()),
    ]) {
      if (other['id'] == id) continue;
      final centre = (other['offsetRatio'] as num).toDouble() * host.length;
      final w = (other['width'] as num).toDouble();
      final bottom = (other['sillHeight'] as num).toDouble(),
          top = bottom + (other['height'] as num).toDouble();
      if (math.min(along + width / 2, centre + w / 2) -
                  math.max(along - width / 2, centre - w / 2) >
              1e-6 &&
          math.min(sill + height, top) - math.max(sill, bottom) > 1e-6) {
        throw ArgumentError('Overlapping openings');
      }
    }
  }

  static ArchitectProject move(
    ArchitectProject p,
    String id,
    Offset delta,
    Offset right, {
    required bool elevation,
  }) {
    if (!delta.dx.isFinite || !delta.dy.isFinite) {
      throw ArgumentError('Invalid displacement');
    }
    final ref = find(p, id);
    if (ref == null) throw ArgumentError('Unknown element');
    final s = ref.storey;
    final dx = elevation ? delta.dx : 0.0, dz = delta.dy;
    final horizontal = right * dx;
    ArchitectStorey result;
    if (ref.isOpening) {
      final host = ref.host!, data = _record(p, ref);
      final factor =
          host.unitVector.dx * right.dx + host.unitVector.dy * right.dy;
      if (dx.abs() > 1e-8 && factor.abs() < .1) {
        throw ArgumentError('Host edge-on');
      }
      final ratio =
          (data['offsetRatio'] as num).toDouble() +
          (dx.abs() < 1e-8 ? 0 : dx / factor / host.length);
      final sill = (data['sillHeight'] as num).toDouble() + dz;
      result = s.copyWith(
        walls: [
          for (final w in s.walls)
            if (w.id != host.id)
              w
            else
              w.copyWith(
                doors: [
                  for (final d in w.doors)
                    if (d.id == id)
                      d.copyWith(offsetRatio: ratio, sillHeight: sill)
                    else
                      d,
                ],
                windows: [
                  for (final d in w.windows)
                    if (d.id == id)
                      d.copyWith(offsetRatio: ratio, sillHeight: sill)
                    else
                      d,
                ],
              ),
        ],
      );
    } else {
      final group = s.roofs.where((r) => r.id == id).firstOrNull?.roofGroupId;
      result = s.copyWith(
        roofs: [
          for (final r in s.roofs)
            if (r.id == id || group != null && r.roofGroupId == group)
              r.copyWith(
                points: [for (final pt in r.points) pt + horizontal],
                baseElevationOffset: r.baseElevationOffset + dz,
                attachToWalls: false,
                placementResolved: true,
              )
            else
              r,
        ],
        walls: [
          for (final w in s.walls)
            if (w.id == id)
              w.copyWith(
                startPoint: w.startPoint + horizontal,
                endPoint: w.endPoint + horizontal,
                baseOffset: w.baseOffset + dz,
              )
            else
              w,
        ],
        columns: [
          for (final e in s.columns)
            if (e.id == id)
              e.copyWith(
                position: e.position + horizontal,
                baseOffset: e.baseOffset + dz,
              )
            else
              e,
        ],
        beams: [
          for (final e in s.beams)
            if (e.id == id)
              e.copyWith(
                startPoint: e.startPoint + horizontal,
                endPoint: e.endPoint + horizontal,
                baseOffset: e.baseOffset + dz,
              )
            else
              e,
        ],
        slabs: [
          for (final e in s.slabs)
            if (e.id == id)
              e.copyWith(
                polygon: [for (final pt in e.polygon) pt + horizontal],
                coreTopOffset: e.coreTopOffset + dz,
              )
            else
              e,
        ],
        stairs: [
          for (final e in s.stairs)
            if (e.id == id)
              e.copyWith(
                startPoint: e.startPoint + horizontal,
                endPoint: e.endPoint + horizontal,
                design: e.design?.copyWith(
                  startOffset: e.design!.startOffset + dz,
                ),
              )
            else
              e,
        ],
      );
    }
    final next = ArchitectModelCommand.replace(p, result);
    if (ref.isOpening) validateOpening(next, id);
    return next;
  }

  static List<ArchitectOpeningMeasure> measures(
    ArchitectProject p,
    String id,
    Offset origin,
    Offset right, {
    Set<String>? visible,
  }) {
    final ref = find(p, id);
    if (ref == null || !ref.isOpening) return [];
    final host = ref.host!, data = _record(p, ref);
    final factor =
        host.unitVector.dx * right.dx + host.unitVector.dy * right.dy;
    if (factor.abs() < .1) return [];
    double x(Offset pt) =>
        (pt.dx - origin.dx) * right.dx + (pt.dy - origin.dy) * right.dy;
    final centre =
        host.centerStart +
        host.unitVector *
            ((data['offsetRatio'] as num).toDouble() * host.length);
    final width = (data['width'] as num).toDouble() * factor.abs();
    final left = x(centre) - width / 2, rightEdge = x(centre) + width / 2;
    final bottom =
            ref.storey.elevation +
            host.baseOffset +
            (data['sillHeight'] as num).toDouble(),
        top = bottom + (data['height'] as num).toDouble();
    var leftX = math.min(x(host.centerStart), x(host.centerEnd)),
        rightX = math.max(x(host.centerStart), x(host.centerEnd));
    double? neighbourLeft, neighbourRight;
    for (final w in ref.storey.walls) {
      if ((w.unitVector.dx * host.unitVector.dx +
                  w.unitVector.dy * host.unitVector.dy)
              .abs() <
          .99) {
        continue;
      }
      if (((w.centerStart - host.centerStart).dx * host.normalVector.dx +
                  (w.centerStart - host.centerStart).dy * host.normalVector.dy)
              .abs() >
          .05) {
        continue;
      }
      for (final other in [
        ...w.doors.map((e) => e.toJson()),
        ...w.windows.map((e) => e.toJson()),
      ]) {
        if (other['id'] == id ||
            visible != null && !visible.contains(other['id'])) {
          continue;
        }
        final point =
            w.centerStart +
            w.unitVector *
                ((other['offsetRatio'] as num).toDouble() * w.length);
        final half =
            (other['width'] as num).toDouble() /
            2 *
            (w.unitVector.dx * right.dx + w.unitVector.dy * right.dy).abs();
        final a = x(point) - half, b = x(point) + half;
        if (b <= left + 1e-6 && (neighbourLeft == null || b > neighbourLeft)) {
          neighbourLeft = b;
        }
        if (a >= rightEdge - 1e-6 &&
            (neighbourRight == null || a < neighbourRight)) {
          neighbourRight = a;
        }
      }
    }
    leftX = neighbourLeft ?? leftX;
    rightX = neighbourRight ?? rightX;
    double? ceiling;
    for (final floor in p.storeys) {
      for (final slab in floor.slabs) {
        if (!ArchitectSlabGeometry.contains(floor, slab, centre)) continue;
        final underside = ArchitectSlabGeometry.surfaces(
          p,
          floor,
          slab,
        ).last.bottomAt(centre);
        if (underside >= bottom - 1e-7 &&
            (ceiling == null || underside < ceiling)) {
          ceiling = underside;
        }
      }
    }
    final distLeft = (left - leftX).abs() < 1e-4 ? 0.0 : left - leftX;
    final distRight = (rightX - rightEdge).abs() < 1e-4
        ? 0.0
        : rightX - rightEdge;
    final distSill = (bottom - ref.storey.elevation).abs() < 1e-4
        ? 0.0
        : bottom - ref.storey.elevation;
    return [
      ArchitectOpeningMeasure(
        ArchitectOpeningDistance.left,
        distLeft,
        Offset(leftX, bottom),
        Offset(left, bottom),
      ),
      ArchitectOpeningMeasure(
        ArchitectOpeningDistance.right,
        distRight,
        Offset(rightEdge, bottom),
        Offset(rightX, bottom),
      ),
      ArchitectOpeningMeasure(
        ArchitectOpeningDistance.sill,
        distSill,
        Offset(x(centre), ref.storey.elevation),
        Offset(x(centre), bottom),
      ),
      if (ceiling != null)
        ArchitectOpeningMeasure(
          ArchitectOpeningDistance.head,
          (ceiling - top).abs() < 1e-4 ? 0.0 : ceiling - top,
          Offset(x(centre), top),
          Offset(x(centre), ceiling),
        ),
    ];
  }

  static ArchitectProject distance(
    ArchitectProject p,
    String id,
    ArchitectOpeningMeasure measure,
    double value,
    Offset right,
  ) {
    if (!value.isFinite || value < 0) throw ArgumentError('Invalid clearance');
    final change = value - measure.value;
    return move(
      p,
      id,
      switch (measure.kind) {
        ArchitectOpeningDistance.left => Offset(change, 0),
        ArchitectOpeningDistance.right => Offset(-change, 0),
        ArchitectOpeningDistance.sill => Offset(0, change),
        ArchitectOpeningDistance.head => Offset(0, -change),
      },
      right,
      elevation: true,
    );
  }
}
