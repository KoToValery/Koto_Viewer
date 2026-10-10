import 'dart:convert';
import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../structural_designer/models/structural_element.dart';
import '../models/bim_work_project.dart';
import 'bim_underlay_conversion_service.dart';

/// Rebase stored geometry through its previous source frame, once per alignment.
/// Baselines move with their edited objects, so rebasing is not a manual edit.
class BimStructuralAlignmentSync {
  static ({
    BimWorkProject project,
    StructuralProject structural,
    Set<String> moved,
  })
  rebase(
    BimWorkProject project,
    StructuralProject structural,
    Map<String, DxfDocument> documents,
  ) {
    final transforms = <String, _Delta>{};
    final currentFrames = <String, Map<String, dynamic>>{};
    for (final source in project.storeys) {
      final doc = documents[source.storeyId];
      if (doc == null) continue;
      final metadata = BimUnderlayMetadata.read(doc);
      if (metadata == null) continue;
      final next = _Frame.read(metadata['sourceToProject']);
      if (next == null) continue;
      currentFrames[source.storeyId] = next.toJson();
      var previous = _Frame.read(source.processing['structuralTransform']);
      final seeds = source.processing['structuralSeeds'] as Map?;
      if (previous == null && seeds?['key'] is String) {
        try {
          final values = jsonDecode(seeds!['key'] as String);
          if (values is List) {
            previous = values
                .whereType<Map>()
                .map(_Frame.read)
                .whereType<_Frame>()
                .firstOrNull;
            // Old unaligned seed keys had a null transform.
            previous ??= const _Frame(1, Offset.zero);
          }
        } catch (_) {
          /* Unknown histories are not guessed from object positions. */
        }
      }
      if (previous == null) continue;
      final delta = _Delta(
        next.scale / previous.scale,
        next.translation - previous.translation * (next.scale / previous.scale),
      );
      if ((delta.scale - 1).abs() > 1e-10 ||
          delta.translation.distance > 1e-6) {
        transforms[source.storeyId] = delta;
      }
    }
    final floors = project.sortedStoreysByElevation;
    _Delta? axisDelta(StructuralGridAxis axis) {
      final owner = floors
          .where(
            (s) =>
                axis.sourceStoreyIds.contains(s.storeyId) ||
                axis.id.startsWith('bim_axis_${s.storeyId}_'),
          )
          .firstOrNull;
      return transforms[owner?.storeyId ??
          project.referenceStorey?.storeyId ??
          floors.firstOrNull?.storeyId];
    }

    StructuralGridAxis axisMap(StructuralGridAxis axis) {
      final delta = axisDelta(axis);
      return delta == null
          ? axis
          : axis.copyWith(
              start: delta.point(axis.start),
              end: delta.point(axis.end),
            );
    }

    final model = structural.copyWith(
      storeys: [
        for (final floor in structural.storeys)
          transforms[floor.id]?.storey(floor) ?? floor,
      ],
    );
    final axes = structural.effectiveGridAxes.map(axisMap).toList();
    final sources = <BimStoreyUnderlay>[];
    for (final source in project.storeys) {
      final processing = Map<String, dynamic>.from(source.processing);
      final delta = transforms[source.storeyId];
      final old = processing['structuralSeeds'];
      if (old is Map) {
        final seeds = Map<String, dynamic>.from(old);
        if (delta != null) {
          seeds['slabs'] = [
            for (final raw in seeds['slabs'] as List? ?? [])
              delta
                  .slab(
                    StructuralSlab.fromJson(
                      Map<String, dynamic>.from(raw as Map),
                    ),
                  )
                  .toJson(),
          ];
          seeds['axes'] = [
            for (final raw in seeds['axes'] as List? ?? [])
              delta
                  .axis(
                    StructuralGridAxis.fromJson(
                      Map<String, dynamic>.from(raw as Map),
                    ),
                  )
                  .toJson(),
          ];
        }
        seeds['axisMasterSnapshots'] = [
          for (final raw in seeds['axisMasterSnapshots'] as List? ?? [])
            axisMap(
              StructuralGridAxis.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ),
            ).toJson(),
        ];
        processing['structuralSeeds'] = seeds;
      }
      if (currentFrames[source.storeyId] != null) {
        processing['structuralTransform'] = currentFrames[source.storeyId];
      }
      sources.add(source.copyWith(processing: processing));
    }
    return (
      project: project.copyWith(storeys: sources),
      structural: model.copyWithGridAxes(axes),
      moved: transforms.keys.toSet(),
    );
  }
}

class _Frame {
  final double scale;
  final Offset translation;
  const _Frame(this.scale, this.translation);
  static _Frame? read(dynamic raw) {
    if (raw is! Map || raw['scale'] is! num || raw['translation'] is! List) {
      return null;
    }
    final scale = (raw['scale'] as num).toDouble(),
        shift = raw['translation'] as List;
    if (!scale.isFinite ||
        scale <= 0 ||
        shift.length != 2 ||
        shift.any((v) => v is! num || !v.isFinite)) {
      return null;
    }
    return _Frame(
      scale,
      Offset((shift[0] as num).toDouble(), (shift[1] as num).toDouble()),
    );
  }

  Map<String, dynamic> toJson() => {
    'scale': scale,
    'translation': [translation.dx, translation.dy],
  };
}

class _Delta {
  final double scale;
  final Offset translation;
  const _Delta(this.scale, this.translation);
  Offset point(Offset p) => p * scale + translation;
  StructuralGridAxis axis(StructuralGridAxis a) =>
      a.copyWith(start: point(a.start), end: point(a.end));
  StructuralSlab slab(StructuralSlab s) => s.copyWith(
    polygon: s.polygon.map(point).toList(),
    openings: [for (final hole in s.openings) hole.map(point).toList()],
  );
  StoreyLevel storey(StoreyLevel s) => s.copyWith(
    columns: [
      for (final c in s.columns)
        c.copyWith(
          center: point(c.center),
          width: c.width * scale,
          height: c.height * scale,
          thickness: c.thickness * scale,
        ),
    ],
    shearWalls: [
      for (final w in s.shearWalls)
        w.copyWith(
          start: point(w.start),
          end: point(w.end),
          thickness: w.thickness * scale,
        ),
    ],
    beams: [
      for (final b in s.beams)
        b.copyWith(
          start: point(b.start),
          end: point(b.end),
          width: b.width * scale,
          depth: b.depth * scale,
        ),
    ],
    slabs: s.slabs.map(slab).toList(),
  );
}
