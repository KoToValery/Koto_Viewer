import '../../dxf_viewer/models/dxf_models.dart';
import '../../structural_designer/analysis/project_grid_axes.dart';
import '../../structural_designer/models/structural_element.dart';
import '../models/bim_work_project.dart';
import 'bim_underlay_conversion_service.dart';

class BimGridAxisSync {
  static List<StructuralGridAxis> refresh(
    BimWorkProject project,
    StructuralProject structural,
    Map<String, DxfDocument> documents,
    double unitsPerMeter,
  ) {
    final floors = project.sortedStoreysByElevation;
    final valid = floors.map((s) => s.storeyId).toSet();
    String? owner(String id) => floors
        .where((s) => id.startsWith('bim_axis_${s.storeyId}_'))
        .firstOrNull
        ?.storeyId;
    final snapshots = _snapshots(project);
    final original = <StructuralGridAxis>[];
    final seen = <String>{};
    for (final a
        in structural.gridAxes.isNotEmpty
            ? structural.gridAxes
            : structural.storeys.expand((s) => s.gridAxes)) {
      if (!seen.add(a.id)) continue;
      final sources = a.sourceStoreyIds.isEmpty && owner(a.id) != null
          ? [owner(a.id)!]
          : a.sourceStoreyIds;
      final remaining = sources.where(valid.contains).toList();
      if (a.id.startsWith('bim_axis_') && owner(a.id) == null) continue;
      if (sources.isNotEmpty && remaining.isEmpty) continue;
      original.add(a.copyWith(sourceStoreyIds: remaining));
    }
    bool edited(StructuralGridAxis a) {
      final old = snapshots[a.id];
      if (old == null) {
        final source = owner(a.id), doc = documents[owner(a.id)];
        if (source == null || doc == null) return true;
        final seed = BimUnderlayMetadata.axes(
          doc,
        ).where((s) => 'bim_axis_${source}_${s.id}' == a.id).firstOrNull;
        return seed == null || _geometryChanged(a, seed, unitsPerMeter);
      }
      return _geometryChanged(a, old, unitsPerMeter);
    }

    bool canRefresh(BimStoreyUnderlay s) =>
        !project.axisSeedsConsumed ||
        s.processing['structuralSeeds'] != null ||
        s.processing['seedImportPending'] == true;
    final candidates = <StructuralGridAxis>[];
    for (final a in original) {
      if (!a.id.startsWith('bim_axis_') ||
          edited(a) ||
          a.sourceStoreyIds.any((id) {
            final floor = floors.firstWhere((s) => s.storeyId == id);
            return !canRefresh(floor) ||
                documents[id] == null ||
                BimUnderlayMetadata.read(documents[id]!) == null;
          })) {
        candidates.add(a);
      }
    }
    for (final floor in floors) {
      final doc = documents[floor.storeyId];
      if (doc == null ||
          BimUnderlayMetadata.read(doc) == null ||
          !canRefresh(floor)) {
        continue;
      }
      final old = floor.processing['structuralSeeds'] as Map?;
      final oldAxes = [
        for (final raw in old?['axes'] as List? ?? [])
          StructuralGridAxis.fromJson(Map<String, dynamic>.from(raw as Map)),
      ];
      final owners = old?['axisOwners'] as Map? ?? {};
      for (final raw in BimUnderlayMetadata.axes(doc)) {
        final seed = raw.copyWith(
          id: 'bim_axis_${floor.storeyId}_${raw.id}',
          sourceStoreyIds: [floor.storeyId],
        );
        final history =
            oldAxes.where((a) => a.id == seed.id).firstOrNull ??
            oldAxes
                .where(
                  (a) => ProjectGridAxes.sameAlignment(a, seed, unitsPerMeter),
                )
                .firstOrNull;
        final ownerId =
            owners[history?.id ?? seed.id] as String? ?? history?.id ?? seed.id;
        final prior = original
            .where((a) => a.id == ownerId || a.id == seed.id)
            .firstOrNull;
        final ownerStillExists =
            !ownerId.startsWith('bim_axis_') || owner(ownerId) != null;
        // Absence of a previously imported shared alignment is an intentional
        // deletion; rebuilding another floor must not resurrect its number.
        if (history != null && prior == null && ownerStillExists) {
          continue;
        }
        if (prior != null && edited(prior)) continue;
        final existing = original
            .where((a) => ProjectGridAxes.sameAlignment(a, seed, unitsPerMeter))
            .firstOrNull;
        var candidate = existing != null && existing.id.startsWith('bim_axis_')
            ? existing.copyWith(
                sourceStoreyIds: [floor.storeyId],
                start: existing.projectPoint(seed.start),
                end: existing.projectPoint(seed.end),
              )
            : seed;
        if (existing == null &&
            original.any(
              (a) =>
                  a.id == seed.id &&
                  !ProjectGridAxes.sameAlignment(a, seed, unitsPerMeter),
            )) {
          // A revised source can move away from an alignment still used by
          // another floor. It becomes a new master axis with a distinct ID.
          String point(double v) =>
              (v / unitsPerMeter * 1e6).round().toString();
          candidate = seed.copyWith(
            id: '${seed.id}:alignment:${point(seed.start.dx)},${point(seed.start.dy)},${point(seed.end.dx)},${point(seed.end.dy)}',
          );
        }
        candidates.add(candidate);
      }
    }
    final bg = original.any((a) => RegExp(r'[А-Яа-я]').hasMatch(a.name));
    return ProjectGridAxes.merge(candidates, unitsPerMeter, isBulgarian: bg);
  }

  static Map<String, StructuralGridAxis> _snapshots(BimWorkProject project) {
    final snapshots = <String, StructuralGridAxis>{};
    for (final source in project.sortedStoreysByElevation) {
      final old = source.processing['structuralSeeds'] as Map?;
      for (final raw in old?['axes'] as List? ?? []) {
        final axis = StructuralGridAxis.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        snapshots[axis.id] = axis;
      }
    }
    for (final source in project.sortedStoreysByElevation) {
      final old = source.processing['structuralSeeds'] as Map?;
      for (final raw in old?['axisMasterSnapshots'] as List? ?? []) {
        final axis = StructuralGridAxis.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        snapshots[axis.id] = axis;
      }
    }
    return snapshots;
  }

  static bool _geometryChanged(
    StructuralGridAxis axis,
    StructuralGridAxis old,
    double units,
  ) {
    final tolerance = .005 * units;
    return (axis.start - old.start).distance > tolerance ||
        (axis.end - old.end).distance > tolerance ||
        axis.bubbleAtStart != old.bubbleAtStart ||
        axis.bubbleAtEnd != old.bubbleAtEnd;
  }

  static List<StructuralGridAxis> masterSnapshots(
    BimWorkProject project,
    StructuralProject structural,
    List<StructuralGridAxis> axes,
    double units,
  ) {
    final old = _snapshots(project);
    final previous = {for (final a in structural.effectiveGridAxes) a.id: a};
    return [
      for (final axis in axes)
        old.containsKey(axis.id) &&
                previous.containsKey(axis.id) &&
                _geometryChanged(previous[axis.id]!, old[axis.id]!, units)
            ? old[axis.id]!.copyWith(
                name: axis.name,
                sourceStoreyIds: axis.sourceStoreyIds,
              )
            : axis,
    ];
  }
}
