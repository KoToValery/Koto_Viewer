import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/initial_scheme_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/column_vertical_continuity.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_vertical_continuity.dart';
import 'package:kotoview/src/features/structural_designer/analysis/geometric_window_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_geometry_units.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_scheme_readiness.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_underlay_source.dart';
import 'package:kotoview/src/features/structural_designer/analysis/support_layout_evaluator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/support_layout_optimizer.dart';
import 'package:kotoview/src/features/structural_designer/analysis/support_placement_rules.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_placement_domain.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/wall_axis_models.dart';

void main() {
  test('BIM clones cannot duplicate walls or mutate source visibility', () {
    List<DxfEntity> faces(String layer) => [
      DxfLine(layer: layer, p1: const Offset(0, 0), p2: const Offset(500, 0)),
      DxfLine(layer: layer, p1: const Offset(0, 25), p2: const Offset(500, 25)),
    ];
    final source = DxfDocument(
      entities: faces('BIM user architecture'),
      layers: {
        'BIM user architecture': DxfLayer(name: 'BIM user architecture'),
      },
      blocks: {},
      headerVars: {},
      bounds: Rect.zero,
      entityStats: {},
    );
    final baked = DxfDocument(
      entities: [...source.entities, ...faces('generated')],
      layers: {
        'BIM user architecture': source.layers.values.single.copyWith(
          isVisible: false,
        ),
        'generated': DxfLayer(name: 'generated'),
      },
      blocks: {},
      entityStats: {},
      bounds: Rect.zero,
      headerVars: {
        r'$KOTO_BIM_UNDERLAY': jsonEncode({
          'version': 2,
          'complete': true,
          'layers': ['generated'],
          'blocks': [],
          'visibility': {'BIM user architecture': true},
        }),
      },
    );
    final expected = WallAxisDetector.detect(source, forceScaleFactor: .1);
    final actual = WallAxisDetector.detect(baked, forceScaleFactor: .1);
    expect(expected.selectedWallPairs, hasLength(1));
    expect(actual.selectedWallPairs, hasLength(1));
    expect(
      actual.selectedWallPairs.single.segmentA.sourceLayer,
      'BIM user architecture',
    );
    final original = StructuralUnderlaySource.original(baked);
    expect(original.layers.values.single.isVisible, isTrue);
    expect(baked.layers['BIM user architecture']!.isVisible, isFalse);
    expect(baked.entities, hasLength(4));
    baked.blocks['generatedBlock'] = DxfBlock(
      name: 'generatedBlock',
      entities: faces('BIM user architecture'),
    );
    baked.entities.add(
      const DxfInsert(
        blockName: 'generatedBlock',
        insertPoint: Offset.zero,
        layer: 'BIM user architecture',
      ),
    );
    final metadata = jsonDecode(baked.headerVars[r'$KOTO_BIM_UNDERLAY']!);
    metadata['blocks'] = ['generatedBlock'];
    baked.headerVars[r'$KOTO_BIM_UNDERLAY'] = jsonEncode(metadata);
    final noClones = StructuralUnderlaySource.original(baked);
    expect(noClones.entities, hasLength(2));
    expect(noClones.blocks, isEmpty);
    expect(baked.blocks, hasLength(1));
    baked.headerVars[r'$KOTO_BIM_UNDERLAY'] = '{broken';
    expect(StructuralUnderlaySource.original(baked), same(baked));
  });

  test(
    'package geometry improves with short walls and a bounded search',
    () async {
      final data = jsonDecode(
        await File(
          'test/fixtures/bim_package_support_layout.json',
        ).readAsString(),
      );
      const units = StructuralGeometryUnits(100, Offset.zero);
      Offset p(dynamic v) => units.toMetres(
        Offset((v[0] as num).toDouble(), (v[1] as num).toDouble()),
      );
      WallSegment segment(dynamic s) {
        final a = p(s['start']), b = p(s['end']), d = b - a;
        return WallSegment(
          start: a,
          end: b,
          angleRad: math.atan2(d.dy, d.dx),
          offsetFromOrigin: 0,
          length: d.distance,
          sourceLayer: 'preserved architecture',
        );
      }

      final pairs = [
        for (final r in data['pairs'])
          WallPairCandidate(
            segmentA: segment(r['segmentA']),
            segmentB: segment(r['segmentB']),
            perpendicularDistance: (r['width'] as num).toDouble() / 100,
            overlapLength: (p(r['end']) - p(r['start'])).distance,
            centerlineStart: p(r['start']),
            centerlineEnd: p(r['end']),
          ),
      ];
      final openings = [
        for (final o in data['openings'])
          GeometricWindowOpening(
            start: p(o['start']),
            end: p(o['end']),
            thickness: (o['thickness'] as num).toDouble() / 100,
            length: (o['length'] as num).toDouble() / 100,
            barrierPolygon: WallPlacementDomain.strip(
              p(o['start']),
              p(o['end']),
              (o['thickness'] as num).toDouble() / 100,
            ),
          ),
      ];
      final project = units.project(
        StructuralProject.fromJson(Map<String, dynamic>.from(data['project'])),
      );
      final fixed = project.activeStorey;
      final seed = units.floor(
        StoreyLevel.fromJson(Map<String, dynamic>.from(data['before'])),
      );
      final before = SupportLayoutEvaluator.evaluate(project, seed, 1);
      final domain = WallPlacementDomain.build(pairs, openings, 1);
      LayoutSearchResult search() => SupportLayoutOptimizer.optimize(
        project: project,
        fixedFloor: fixed,
        seeds: [seed],
        wallPairs: pairs,
        domain: domain,
        scale: 1,
        minSpacingM: 2,
        wallSpacingM: 2,
        maxWallLengthM: 2.5,
        maxEvaluations: 64,
      );
      final result = search();
      expect(result.assessment.compareTo(before), lessThan(0));
      expect(
        result.assessment.unavailableChecks,
        lessThan(before.unavailableChecks),
      );
      expect(
        result.assessment.topology.unresolvedAreaM2,
        closeTo(before.topology.unresolvedAreaM2, 1e-6),
      );
      expect(result.evaluations, lessThanOrEqualTo(64));
      expect(result.evaluationsByOperation['add-wall'], greaterThan(0));
      expect(result.floor.shearWalls.any((w) => w.length < 1.5 - 1e-6), isTrue);
      for (final c in result.floor.columns) {
        expect(
          SupportPlacementRules.reason(
            polygon: SupportPlacementRules.columnFootprint(c),
            center: c.center,
            isWall: false,
            floor: result.floor,
            domain: domain,
            scale: 1,
            columnSpacingM: 2,
            wallSpacingM: 2,
            skipId: c.id,
          ),
          isNull,
          reason: c.id,
        );
      }
      for (final w in result.floor.shearWalls) {
        expect(
          SupportPlacementRules.reason(
            polygon: w.polygonVertices,
            center: w.center,
            isWall: true,
            wallDirection: (w.end - w.start) / w.length,
            floor: result.floor,
            domain: domain,
            scale: 1,
            columnSpacingM: 2,
            wallSpacingM: 2,
            skipId: w.id,
          ),
          isNull,
          reason: w.id,
        );
      }
      expect(search().floor.toJson(), result.floor.toJson());
      // This fixture tests candidate placement on a conservative partial envelope;
      // it must not silently satisfy the application's missing staircase gate.
      expect(
        StructuralSchemeReadiness.evaluate(project, 1).issues,
        contains(SchemeReadinessIssue.missingStaircase),
      );
      final gated = InitialSchemeGenerator.generate(
        project: project,
        wallPairs: pairs,
        scale: 1,
      );
      expect(gated.columns, isEmpty);
      expect(gated.walls, isEmpty);
    },
  );
  test(
    'aligned upper package storey continues supports and reports blocked ones',
    () async {
      final fixture = jsonDecode(
        await File(
          'test/fixtures/bim_package_support_layout.json',
        ).readAsString(),
      );
      final data = fixture['upperInputs'];
      const units = StructuralGeometryUnits(100, Offset.zero);
      Offset p(dynamic v) => units.toMetres(
        Offset((v[0] as num).toDouble(), (v[1] as num).toDouble()),
      );
      WallSegment segment(dynamic s) {
        final a = p(s['start']), b = p(s['end']), d = b - a;
        return WallSegment(
          start: a,
          end: b,
          angleRad: math.atan2(d.dy, d.dx),
          offsetFromOrigin: 0,
          length: d.distance,
          sourceLayer: 'preserved architecture',
        );
      }

      final pairs = [
        for (final r in data['pairs'])
          WallPairCandidate(
            segmentA: segment(r['segmentA']),
            segmentB: segment(r['segmentB']),
            perpendicularDistance: (r['width'] as num).toDouble() / 100,
            overlapLength: (p(r['end']) - p(r['start'])).distance,
            centerlineStart: p(r['start']),
            centerlineEnd: p(r['end']),
          ),
      ];
      final openings = [
        for (final o in data['openings'])
          GeometricWindowOpening(
            start: p(o['start']),
            end: p(o['end']),
            thickness: (o['thickness'] as num).toDouble() / 100,
            length: (o['length'] as num).toDouble() / 100,
            barrierPolygon: WallPlacementDomain.strip(
              p(o['start']),
              p(o['end']),
              (o['thickness'] as num).toDouble() / 100,
            ),
          ),
      ];
      final project = units.project(
        StructuralProject.fromJson(Map<String, dynamic>.from(data['project'])),
      );
      final lower = project.storeys.first;
      final result = InitialSchemeGenerator.generate(
        project: project,
        wallPairs: pairs,
        wallOpenings: openings,
        scale: 1,
      );
      expect(result.isEmpty, isFalse);
      expect(result.continuationSource, lower.elevationLabel);
      expect(result.rejectionReasons['wall'], greaterThan(0));
      expect(result.uncoveredSamples, greaterThan(0));
      for (final c in result.columns) {
        expect(
          ColumnVerticalContinuity.evaluate(c, lower, 1).isContinuous,
          isTrue,
        );
      }
      for (final w in result.walls) {
        expect(
          WallVerticalContinuity.evaluate(w, lower.shearWalls, 1).isContinuous,
          isTrue,
        );
      }
    },
  );
}
