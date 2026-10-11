import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_zone_grouping.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_boundary_geometry.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_topology_analyzer.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_seed_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_envelope_detector.dart';
import 'package:kotoview/src/features/structural_designer/analysis/vertical_capacity_calculator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_analysis_calculator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/cantilever_detector.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

const primary = StructuralSlab(
  id: 'primary',
  polygon: [Offset(0, 0), Offset(4, 0), Offset(4, 4), Offset(0, 4)],
  thickness: .20,
);
const balcony = StructuralSlab(
  id: 'bim_slab_s_projection_balcony_0',
  polygon: [Offset(4, 0), Offset(6, 0), Offset(6, 4), Offset(4, 4)],
  thickness: .12,
);
void mainTests() {
  for (final scale in [1.0, 100.0, 1000.0]) {
    test(
      'zone links by shared edge and retains thickness and openings, units=$scale',
      () {
        final plates = [primary, balcony]
            .map(
              (s) =>
                  s.copyWith(polygon: s.polygon.map((p) => p * scale).toList()),
            )
            .toList();
        final linked = SlabZoneGrouping.attach(plates, scale);
        expect(linked.last.parentSlabId, 'primary');
        expect(linked.last.effectiveZoneKind, SlabZoneKind.balcony);
        final edit = linked.last.copyWith(
          thickness: .15,
          openings: [
            [
              Offset(4.5, 1) * scale,
              Offset(5, 1) * scale,
              Offset(5, 2) * scale,
              Offset(4.5, 2) * scale,
            ],
          ],
        );
        final saved = StructuralSlab.fromJson(
          jsonDecode(jsonEncode(edit.toJson())),
        );
        expect(saved.parentSlabId, 'primary');
        expect(saved.thickness, .15);
        expect(saved.openings, edit.openings);
        expect(SlabTopologyAnalyzer.analyze(linked, scale).regionCount, 1);
        final edges = SlabBoundaryGeometry.exposedEdges(linked, scale);
        expect(
          edges.any(
            (e) =>
                (e.a.dx - 4 * scale).abs() < 1e-6 &&
                (e.b.dx - 4 * scale).abs() < 1e-6,
          ),
          isFalse,
        );
        final detached = SlabZoneGrouping.attach([
          linked.first,
          linked.last.copyWith(
            polygon: linked.last.polygon
                .map((p) => p + Offset(.01 * scale, 0))
                .toList(),
          ),
        ], scale);
        expect(detached.last.parentSlabId, isNull);
      },
    );
  }
  test(
    'point contact, different elevation and a deleted parent do not link',
    () {
      final point = balcony.copyWith(
        polygon: const [Offset(4, 4), Offset(6, 4), Offset(6, 6), Offset(4, 6)],
      );
      expect(
        SlabZoneGrouping.attach([primary, point], 1).last.parentSlabId,
        isNull,
      );
      expect(
        SlabZoneGrouping.attach([
          primary,
          balcony.copyWith(topElevation: .5),
        ], 1).last.parentSlabId,
        isNull,
      );
      final linked = SlabZoneGrouping.attach([primary, balcony], 1);
      expect(
        SlabZoneGrouping.attach([linked.last], 1).single.parentSlabId,
        isNull,
      );
    },
  );
  test('seed generation attaches a balcony and a cornice automatically', () {
    final result = SlabSeedGenerator.generate(
      metadata: {
        'slabEnvelope': {
          'version': SlabEnvelopeResult.version,
          'contours': [
            primary.polygon.map((p) => [p.dx, p.dy]).toList(),
          ],
        },
        'slabProjections': [
          {
            'kind': 'balcony',
            'contour': balcony.polygon.map((p) => [p.dx, p.dy]).toList(),
          },
          {
            'kind': 'cornice',
            'contour': [
              [0, 0],
              [0, -.3],
              [4, -.3],
              [4, 0],
            ],
          },
        ],
      },
      document: DxfDocument.empty(),
      storeyId: 's',
      existing: [],
      unitsPerMeter: 1,
      thickness: .2,
    );
    expect(result, hasLength(3));
    expect(
      result.skip(1).map((s) => s.parentSlabId),
      everyElement(result.first.id),
    );
    expect(result.last.zoneKind, SlabZoneKind.cornice);
  });
  test(
    'column tributary boundary uses the whole plate rather than the zone seam',
    () {
      const col = StructuralColumn(id: 'c', center: Offset(3, 2));
      final regions = StoreyLevel(
        id: 'f',
        name: 'F',
        slabs: SlabZoneGrouping.attach([primary, balcony], 1),
        columns: const [col],
      );
      const unified = StoreyLevel(
        id: 'f',
        name: 'F',
        slabs: [
          StructuralSlab(
            id: 'u',
            polygon: [Offset(0, 0), Offset(6, 0), Offset(6, 4), Offset(0, 4)],
          ),
        ],
        columns: [col],
      );
      double area(StoreyLevel s) =>
          VerticalCapacityCalculator.calculateColumnTributaryAreaM2(
            col: col,
            storey: s,
            scale: 1,
            totalFloorAreaM2: 24,
          );
      expect(area(regions), closeTo(area(unified), 1e-8));
      expect(area(regions), 24);
    },
  );
  test(
    'gravity and seismic mass count both regions once using local thicknesses',
    () {
      final regions = SlabZoneGrouping.attach([primary, balcony], 1);
      final model = StructuralProject(
        storeys: [StoreyLevel(id: 'f', name: 'F', slabs: regions)],
        deadLoadSuperimposed: 0,
        liveLoad: 0,
      );
      final vertical = VerticalCapacityCalculator.analyzeProject(model);
      expect(
        vertical.totalVerticalLoadBaseKn,
        closeTo(1.35 * 25 * (16 * .2 + 8 * .12), 1e-8),
      );
      final seismic = SeismicAnalysisCalculator.analyzeProject(
        model,
      ).storeyChecks.single;
      final expectedX = (80 * 2 + 24 * 5) / 104;
      expect(seismic.centerOfMassCad!.dx, closeTo(expectedX, 1e-8));
      expect(seismic.slabTopology.regionCount, 1);
    },
  );
  test(
    'cantilever tips use exterior contour and balcony thickness, excluding seam vertices',
    () {
      final storey = StoreyLevel(
        id: 'f',
        name: 'F',
        slabs: SlabZoneGrouping.attach([primary, balcony], 1),
        columns: const [
          StructuralColumn(id: 'a', center: Offset(1, 1)),
          StructuralColumn(id: 'b', center: Offset(1, 3)),
        ],
      );
      final checks = CantileverDetector.analyzeStorey(storey: storey);
      expect(
        checks.any(
          (c) =>
              c.overhangTip == const Offset(4, 0) ||
              c.overhangTip == const Offset(4, 4),
        ),
        isFalse,
      );
      final tips = checks.where((c) => c.overhangTip.dx == 6);
      expect(tips, isNotEmpty);
      expect(tips.map((c) => c.slabThickness), everyElement(.12));
    },
  );
}

void main() => mainTests();
