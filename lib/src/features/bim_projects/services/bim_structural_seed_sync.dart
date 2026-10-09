import 'dart:convert';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../structural_designer/analysis/slab_seed_generator.dart';
import '../../structural_designer/analysis/slab_topology_analyzer.dart';
import '../../structural_designer/models/slab_topology.dart';
import '../../structural_designer/models/structural_element.dart';
import '../../structural_designer/rendering/structural_2d_painter.dart';
import '../models/bim_work_project.dart';
import 'bim_underlay_conversion_service.dart';
import 'bim_underlay_loader.dart';

/// Source revisions and alignment are independent from manual structural edits.
/// Store the last generated geometry to distinguish untouched seeds from edits.
class BimStructuralSeedSync {
  static (BimWorkProject, StructuralProject) refresh(
    BimWorkProject project,
    StructuralProject structural,
    Map<String, DxfDocument> documents,
  ) {
    final updated = <StoreyLevel>[];
    final underlays = <BimStoreyUnderlay>[];
    var axes = structural.effectiveGridAxes
        .where(
          (a) =>
              !a.id.startsWith('bim_axis_') ||
              project.storeys.any(
                (s) => a.id.startsWith('bim_axis_${s.storeyId}_'),
              ),
        )
        .toList();
    bool equal(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);
    for (final source in project.sortedStoreysByElevation) {
      final floor =
          structural.storeys
              .where((s) => s.id == source.storeyId)
              .firstOrNull ??
          StoreyLevel(
            id: source.storeyId,
            name: source.elevationLabel,
            elevation: source.elevation,
            height: source.height,
          );
      final doc = documents[source.storeyId];
      final meta = doc == null ? null : BimUnderlayMetadata.read(doc);
      if (doc == null || meta == null) {
        updated.add(floor);
        underlays.add(source);
        continue;
      }
      final nextLevel = project.sortedStoreysByElevation
          .where((s) => s.elevation > source.elevation)
          .firstOrNull;
      // An empty intermediate floor cannot be bypassed to create a ceiling
      // at a different level from StructuralProject.resolveCeilingStorey.
      final higher =
          nextLevel != null && documents.containsKey(nextLevel.storeyId)
          ? nextLevel
          : null;
      final old = source.processing['structuralSeeds'] as Map?;
      final key = jsonEncode([
        source.underlayFileName,
        source.processing['fingerprint'],
        meta['sourceToProject'],
        meta['axes'],
        meta['slabEnvelope'],
        meta['slabProjections'],
        higher?.storeyId,
        project.sortedStoreysByElevation
            .map(
              (s) => [
                s.storeyId,
                s.elevation,
                documents.containsKey(s.storeyId),
              ],
            )
            .toList(),
      ]);
      if (old?['key'] == key) {
        updated.add(floor);
        underlays.add(source);
        continue;
      }
      var review =
          source.processing['structuralReviewRequired'] == true ||
          ((old != null || project.axisSeedsConsumed) &&
              (floor.columns.isNotEmpty ||
                  floor.shearWalls.isNotEmpty ||
                  floor.beams.isNotEmpty));
      final scale =
          project.structuralUnitsPerMeter ??
          BimUnderlayLoader.computeUnitsPerMeter(doc, doc.bounds);
      final generated = SlabSeedGenerator.generate(
        metadata: meta,
        document: doc,
        storeyId: floor.id,
        existing: [],
        unitsPerMeter: scale,
        thickness: .20,
      );
      final colored = [
        for (var i = 0; i < generated.length; i++)
          generated[i].copyWith(
            colorValue: Structural2dPainter
                .slabPalette[i % Structural2dPainter.slabPalette.length]
                .toARGB32(),
          ),
      ];
      final oldSlabs = {
        for (final raw in (old?['slabs'] as List? ?? []))
          (raw as Map)['id'] as String: Map<String, dynamic>.from(raw),
      };
      final pending = List<StructuralSlab>.of(floor.slabs);
      final snapshots = <Map<String, dynamic>>[];
      final automatic = SlabSeedGenerator.prefix(floor.id);
      for (final slab in floor.slabs.where((s) => s.id.startsWith(automatic))) {
        final snapshot = oldSlabs[slab.id];
        final next = colored.where((s) => s.id == slab.id).firstOrNull;
        final untouched = snapshot != null
            ? equal(slab.toJson(), snapshot)
            : next != null && equal(slab.toJson(), next.toJson());
        if (higher == null) {
          if (untouched) {
            pending.removeWhere((s) => s.id == slab.id);
          } else {
            review = true;
            snapshots.add(snapshot ?? slab.toJson());
          }
          continue;
        }
        if (snapshot != null &&
            next != null &&
            equal(slab.toJson()['polygon'], snapshot['polygon'])) {
          // Keep user thickness, level and typed openings; update only the outline.
          final trial = slab.copyWith(polygon: next.polygon);
          final after = [for (final s in pending) s.id == slab.id ? trial : s];
          final topology = SlabTopologyAnalyzer.analyze(after, scale);
          if (topology.issue == SlabTopologyIssue.none ||
              topology.issue == SlabTopologyIssue.separateRegions) {
            final idx = pending.indexWhere((s) => s.id == slab.id);
            pending[idx] = trial;
            snapshots.add(next.toJson());
            continue;
          }
          review = true;
          snapshots.add(snapshot);
          continue;
        }
        if (untouched) {
          pending.removeWhere((s) => s.id == slab.id);
          if (next != null) {
            pending.add(next);
            snapshots.add(next.toJson());
          }
        } else {
          review = review || old != null;
          snapshots.add(snapshot ?? slab.toJson());
        }
      }
      if (higher != null) {
        for (final seed in colored) {
          // An intentional deletion on the same ceiling is retained on revision.
          if (pending.any((s) => s.id == seed.id) ||
              (oldSlabs.containsKey(seed.id) &&
                  old?['higher'] == higher.storeyId)) {
            continue;
          }
          if (floor.slabs.any((s) => !s.id.startsWith(automatic))) {
            review = true;
            continue;
          }
          final topology = SlabTopologyAnalyzer.analyze([
            ...pending,
            seed,
          ], scale);
          if (topology.issue == SlabTopologyIssue.none ||
              topology.issue == SlabTopologyIssue.separateRegions) {
            pending.add(seed);
            snapshots.add(seed.toJson());
          } else {
            review = true;
          }
        }
      }
      // Keep deletion tombstones across later source revisions.
      if (old?['higher'] == higher?.storeyId) {
        for (final entry in oldSlabs.entries) {
          if (!floor.slabs.any((s) => s.id == entry.key) &&
              !snapshots.any((s) => s['id'] == entry.key)) {
            snapshots.add(entry.value);
          }
        }
      }
      final oldAxes = {
        for (final raw in (old?['axes'] as List? ?? []))
          (raw as Map)['id'] as String: Map<String, dynamic>.from(raw),
      };
      final oldOwners = Map<String, dynamic>.from(
        old?['axisOwners'] as Map? ?? {},
      );
      final desired = BimUnderlayMetadata.axes(doc)
          .map((a) => a.copyWith(id: 'bim_axis_${source.storeyId}_${a.id}'))
          .toList();
      if (!project.axisSeedsConsumed ||
          old != null ||
          source.processing['seedImportPending'] == true) {
        for (final entry in oldAxes.entries) {
          final current = axes.where((a) => a.id == entry.key).firstOrNull;
          if (current != null && equal(current.toJson(), entry.value)) {
            axes.removeWhere((a) => a.id == entry.key);
          }
        }
        for (final seed in desired) {
          final current = axes.where((a) => a.id == seed.id).firstOrNull;
          if (current != null) {
            if (oldAxes.containsKey(seed.id)) review = true;
            continue;
          }
          final original = structural.effectiveGridAxes
              .where((a) => a.id == seed.id)
              .firstOrNull;
          final ownerId = oldOwners[seed.id] as String? ?? seed.id;
          final ownerFloorExists = project.storeys.any(
            (s) => ownerId.startsWith('bim_axis_${s.storeyId}_'),
          );
          final ownerExists = structural.effectiveGridAxes.any(
            (a) => a.id == ownerId,
          );
          if (oldAxes.containsKey(seed.id) &&
              original == null &&
              ownerFloorExists &&
              !ownerExists) {
            continue;
          }
          if (axes.any(
            (a) =>
                a.isParallelTo(seed, toleranceRad: .05) &&
                a.distanceToSegment((seed.start + seed.end) / 2) <= .15 * scale,
          )) {
            continue;
          }
          axes.add(seed);
        }
      }
      final processing = Map<String, dynamic>.of(source.processing)
        ..remove('seedImportPending');
      processing['structuralSeeds'] = {
        'key': key,
        'higher': higher?.storeyId,
        'slabs': snapshots,
        'axes': desired.map((a) => a.toJson()).toList(),
        'axisOwners': {
          for (final seed in desired)
            seed.id:
                axes
                    .where(
                      (a) =>
                          a.id == seed.id ||
                          (a.isParallelTo(seed, toleranceRad: .05) &&
                              a.distanceToSegment(
                                    (seed.start + seed.end) / 2,
                                  ) <=
                                  .15 * scale),
                    )
                    .firstOrNull
                    ?.id ??
                oldOwners[seed.id] ??
                seed.id,
        },
      };
      processing['structuralReviewRequired'] = review;
      underlays.add(source.copyWith(processing: processing));
      updated.add(floor.copyWith(slabs: pending));
    }
    // Drop only axes whose owning floor was removed; manual/master axes remain.
    final validIds = project.storeys.map((s) => s.storeyId).toSet();
    for (final removed in structural.storeys.where(
      (s) => !validIds.contains(s.id),
    )) {
      axes.removeWhere((a) => a.id.startsWith('bim_axis_${removed.id}_'));
    }
    final active = updated.indexWhere(
      (s) => s.id == structural.activeStorey.id,
    );
    structural = structural
        .copyWith(storeys: updated, activeStoreyIndex: active < 0 ? 0 : active)
        .copyWithGridAxes(axes);
    return (
      project.copyWith(storeys: underlays, axisSeedsConsumed: true),
      structural,
    );
  }
}
