import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_painter_helper.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_tool.dart';

void main() {
  group('Mansard Roof (Gambrel / Пречупен скат)', () {
    late ArchitectRoofPlane standardMansard;

    setUp(() {
      // 6m x 10m rectangular roof plane
      // Eaves at y=0, ridge at y=6, slope upward along +Y
      standardMansard = ArchitectRoofPlane(
        id: 'roof_mansard_1',
        storeyId: 'storey_0',
        points: const [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 6),
          Offset(0, 6),
        ],
        eavesEdgeIndex: 0,
        slopeDegrees: 60.0,
        upperSlopeDegrees: 25.0,
        isMansard: true,
        breakDistance: 2.0,
        eavesOverhang: 0.50,
        baseElevationOffset: 2.80,
      );
    });

    test('models Mansard properties and serializes to/from JSON cleanly', () {
      expect(standardMansard.isMansard, isTrue);
      expect(standardMansard.slopeDegrees, 60.0);
      expect(standardMansard.upperSlopeDegrees, 25.0);
      expect(standardMansard.breakDistance, 2.0);
      expect(standardMansard.effectiveBreakDistance, 2.0);

      final json = standardMansard.toJson();
      expect(json['isMansard'], isTrue);
      expect(json['upperSlopeDegrees'], 25.0);
      expect(json['breakDistance'], 2.0);

      final restored = ArchitectRoofPlane.fromJson(json);
      expect(restored.isMansard, isTrue);
      expect(restored.slopeDegrees, 60.0);
      expect(restored.upperSlopeDegrees, 25.0);
      expect(restored.breakDistance, 2.0);
      expect(restored.effectiveBreakDistance, 2.0);
    });

    test('computes piecewise elevation with C0 continuity at knuckle', () {
      final k = standardMansard.effectiveBreakDistance; // 2.0m
      expect(k, 2.0);

      // Support wall is at eavesOverhang = 0.5m.
      // At y = 0.5m (wall line), underside elevation = baseElevationOffset = 2.80m.
      final zWall = standardMansard.undersideElevationAt(const Offset(5, 0.5));
      expect(zWall, closeTo(2.80, 1e-4));

      // At eaves outer edge y = 0.0m:
      // dFromWall = 0.0 - 0.5 = -0.5m.
      // z = 2.80 - 0.5 * tan(60 deg) = 2.80 - 0.5 * sqrt(3) ~ 1.934m.
      final zEaves = standardMansard.undersideElevationAt(const Offset(5, 0.0));
      expect(zEaves, closeTo(2.80 - 0.5 * math.tan(60 * math.pi / 180), 1e-4));

      // At knuckle y = 2.0m (just below vs just above):
      final zKnuckleBelow =
          standardMansard.undersideElevationAt(const Offset(5, 1.9999));
      final zKnuckleExact =
          standardMansard.undersideElevationAt(const Offset(5, 2.0));
      final zKnuckleAbove =
          standardMansard.undersideElevationAt(const Offset(5, 2.0001));

      expect(zKnuckleBelow, closeTo(zKnuckleExact, 1e-3));
      expect(zKnuckleAbove, closeTo(zKnuckleExact, 1e-3));

      // Expected knuckle elevation:
      // zKnuckle = 2.80 + (2.0 - 0.5) * tan(60 deg) = 2.80 + 1.5 * 1.73205 = 5.398m
      final expectedKnuckleZ = 2.80 + 1.5 * math.tan(60 * math.pi / 180);
      expect(zKnuckleExact, closeTo(expectedKnuckleZ, 1e-4));

      // At ridge y = 6.0m:
      // In upper section, d = 6.0m, runs 4.0m beyond knuckle at 25 deg slope:
      // z = zKnuckle + 4.0 * tan(25 deg)
      final zRidge = standardMansard.undersideElevationAt(const Offset(5, 6.0));
      final expectedRidgeZ =
          expectedKnuckleZ + 4.0 * math.tan(25 * math.pi / 180);
      expect(zRidge, closeTo(expectedRidgeZ, 1e-4));

      // Top surface elevation adds vertical layer thickness:
      final topEaves = standardMansard.topElevationAt(const Offset(5, 0.0));
      expect(topEaves, greaterThan(zEaves));

      final topRidge = standardMansard.topElevationAt(const Offset(5, 6.0));
      expect(topRidge, greaterThan(zRidge));
    });

    test('calculates knuckle line segment and midpoint handle in 2D', () {
      final seg = standardMansard.knuckleSegment;
      expect(seg, isNotNull);
      final (p1, p2) = seg!;
      // Knuckle line crosses between x=0 and x=10 at y=2.0
      expect(p1.dy, closeTo(2.0, 1e-3));
      expect(p2.dy, closeTo(2.0, 1e-3));
      expect(math.min(p1.dx, p2.dx), closeTo(0.0, 1e-3));
      expect(math.max(p1.dx, p2.dx), closeTo(10.0, 1e-3));

      final mid = standardMansard.knuckleMidpoint;
      expect(mid, isNotNull);
      expect(mid!.dx, closeTo(5.0, 1e-3));
      expect(mid.dy, closeTo(2.0, 1e-3));

      // Hit-testing near midpoint
      expect(
        ArchitectRoofPainterHelper.hitTestKnuckleHandle(
          standardMansard,
          const Offset(5.1, 2.05),
          scale: 50.0,
        ),
        isTrue,
      );

      // Hit-testing away from handle
      expect(
        ArchitectRoofPainterHelper.hitTestKnuckleHandle(
          standardMansard,
          const Offset(1.0, 1.0),
          scale: 50.0,
        ),
        isFalse,
      );
    });

    test('RoofDrawMode.mansard creates a Mansard roof plane', () {
      final tool = ArchitectRoofTool();
      tool.setDrawMode(RoofDrawMode.mansard);

      expect(tool.drawMode, RoofDrawMode.mansard);
      expect(tool.slopeDegrees, 60.0);
      expect(tool.upperSlopeDegrees, 25.0);

      final storey = ArchitectStorey(
        id: 'storey_0',
        name: 'Floor 1',
        height: 2.80,
      );

      // Pick 2 diagonal corners for rectangle draft
      final result1 = tool.addDraftPoint(const Offset(0, 0), storey: storey);
      expect(result1, isNull);

      final result2 = tool.addDraftPoint(const Offset(8, 5), storey: storey);
      expect(result2, isNotNull);
      expect(result2!.length, 1);

      final created = result2.first;
      expect(created.isMansard, isTrue);
      expect(created.slopeDegrees, 60.0);
      expect(created.upperSlopeDegrees, 25.0);
      expect(created.effectiveBreakDistance, greaterThan(0.5));
    });

    test('generates intermediate Mansard purlin and split rafters in 3D', () {
      final storey = ArchitectStorey(
        id: 'storey_0',
        name: 'Roof Storey',
        elevation: 2.80,
        height: 2.80,
        roofs: [standardMansard],
      );

      final project = ArchitectProject(
        id: 'proj_1',
        name: 'Test Project',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 'storey_0',
      );

      final mesh = Architect3dBuilder.buildProjectMesh(
        project,
        previewGeometry: true,
      );
      expect(mesh.triangles, isNotEmpty);

      // Intermediate purlin has purlinColor (0xFFB8864B)
      const purlinColor = Color(0xFFB8864B);
      final purlinTris =
          mesh.triangles.where((t) => t.color == purlinColor).toList();
      expect(
        purlinTris,
        isNotEmpty,
        reason: '3D mesh must contain intermediate Mansard purlin',
      );

      // The purlin is located under the knuckle around y = 2.0
      final purlinYValues = [
        for (final t in purlinTris) ...[t.v0.y, t.v1.y, t.v2.y],
      ];
      final minPurlinY = purlinYValues.reduce((a, b) => a < b ? a : b);
      final maxPurlinY = purlinYValues.reduce((a, b) => a > b ? a : b);
      expect(minPurlinY, lessThanOrEqualTo(2.1));
      expect(maxPurlinY, greaterThanOrEqualTo(1.9));

      // Finished covering has topColor (0xFFC85A32 for clay tiles)
      const topColor = Color(0xFFC85A32);
      final coverTris =
          mesh.triangles.where((t) => t.color == topColor).toList();
      expect(coverTris, isNotEmpty);
    });

    test('generates intermediate purlin with timber diagonals in section cut', () {
      final storey = ArchitectStorey(
        id: 'storey_0',
        name: 'Roof Storey',
        elevation: 2.80,
        height: 2.80,
        roofs: [standardMansard],
      );

      // Cross section perpendicular to eaves cutting along Y from y=-0.5 to y=6.5 at x=5.0
      final sectionLine = ArchitectSection(
        id: 'sec_1',
        name: 'A-A',
        start: const Offset(5, -0.5),
        end: const Offset(5, 6.5),
      );

      final slices = ArchitectRoofGeometry.buildSectionSlices(
        storey: storey,
        sectionLine: sectionLine,
      );

      expect(
        slices.length,
        greaterThanOrEqualTo(2),
        reason: 'Mansard cut across knuckle must split into lower and upper slices',
      );

      // Check for intermediate purlin member
      final allMembers = [
        for (final sl in slices) ...sl.members,
      ];
      final purlins = allMembers
          .where((m) => m.kind == ArchitectRoofMemberKind.intermediatePurlin)
          .toList();

      expect(
        purlins,
        isNotEmpty,
        reason: 'Section cut must contain intermediate Mansard purlin',
      );
      final purlin = purlins.first;
      expect(purlin.drawTimberDiagonals, isTrue);
      expect(purlin.material, ArchitectRoofMaterial.timberBoarding);
    });
  });
}
