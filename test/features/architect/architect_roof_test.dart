import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_dimensions.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_tool.dart';

void main() {
  group('ArchitectRoofPlane Model & Serialization', () {
    test('serializes and deserializes roof plane with assembly and timber spec', () {
      final original = ArchitectRoofPlane(
        id: 'roof_1',
        storeyId: 's1',
        points: const [
          Offset(0, 0),
          Offset(6, 0),
          Offset(6, 4),
          Offset(0, 4),
        ],
        eavesEdgeIndex: 0,
        reverseSlope: true,
        baseElevationOffset: 2.80,
        slopeDegrees: 30.0,
        eavesOverhang: 0.60,
        assembly: ArchitectRoofAssembly.fromPreset(
          ArchitectRoofPreset.warmPitched,
        ),
      );

      final json = original.toJson();
      final restored = ArchitectRoofPlane.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.storeyId, original.storeyId);
      expect(restored.points, original.points);
      expect(restored.eavesEdgeIndex, original.eavesEdgeIndex);
      expect(restored.reverseSlope, isTrue);
      expect(restored.baseElevationOffset, closeTo(2.80, 1e-6));
      expect(restored.slopeDegrees, closeTo(30.0, 1e-6));
      expect(restored.eavesOverhang, closeTo(0.60, 1e-6));
      expect(restored.assembly.preset, ArchitectRoofPreset.warmPitched);
      expect(restored.assembly.layers.length, original.assembly.layers.length);
      expect(
        restored.assembly.timber.rafterHeight,
        closeTo(original.assembly.timber.rafterHeight, 1e-6),
      );
    });

    test('computes underside and top elevations accurately along slope', () {
      final roof = ArchitectRoofPlane(
        id: 'roof_slope',
        storeyId: 's1',
        points: const [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 4),
          Offset(0, 4),
        ],
        eavesEdgeIndex: 0, // Edge (0,0)->(10,0), inward up-slope is +Y
        baseElevationOffset: 3.0,
        eavesOverhang: 0.0,
        slopeDegrees: 26.565051177, // atan(0.5), so tan(alpha) = 0.5
      );

      // At eaves line (y = 0), underside elevation is 3.0
      expect(roof.undersideElevationAt(const Offset(5, 0)), closeTo(3.0, 1e-4));
      // At y = 2.0m inward, rise = 2.0 * 0.5 = 1.0m -> 4.0m
      expect(roof.undersideElevationAt(const Offset(5, 2)), closeTo(4.0, 1e-4));
      // At ridge y = 4.0m, rise = 4.0 * 0.5 = 2.0m -> 5.0m
      expect(roof.undersideElevationAt(const Offset(5, 4)), closeTo(5.0, 1e-4));
      // Top elevation is greater than underside elevation by thickness / cos(alpha)
      expect(
        roof.topElevationAt(const Offset(5, 2)),
        greaterThan(roof.undersideElevationAt(const Offset(5, 2)) + 0.15),
      );
    });

    test('sets and changes slope direction via withEavesEdge, nextSlopeEdge, flippedSlope, and slope indicator hit-test', () {
      final roof = ArchitectRoofPlane(
        id: 'roof_dir',
        storeyId: 's1',
        points: const [
          Offset(0, 0),
          Offset(8, 0),
          Offset(8, 5),
          Offset(0, 5),
        ],
        eavesEdgeIndex: 0,
      );

      // Edge 0 is bottom (y=0), so slope points +Y (0, 1)
      expect(roof.slopeDirection.dx, closeTo(0.0, 1e-5));
      expect(roof.slopeDirection.dy, closeTo(1.0, 1e-5));

      // Rotate slope to next edge (Edge 1: right x=8 -> slope points -X (-1, 0))
      final rotated = roof.nextSlopeEdge();
      expect(rotated.safeEavesEdgeIndex, 1);
      expect(rotated.slopeDirection.dx, closeTo(-1.0, 1e-5));
      expect(rotated.slopeDirection.dy, closeTo(0.0, 1e-5));

      // Flip slope 180 degrees from Edge 0 -> selects opposite parallel Edge 2 (top y=5 -> slope points -Y (0, -1))
      final flipped = roof.flippedSlope();
      expect(flipped.safeEavesEdgeIndex, 2);
      expect(flipped.slopeDirection.dx, closeTo(0.0, 1e-5));
      expect(flipped.slopeDirection.dy, closeTo(-1.0, 1e-5));

      // Set arbitrary selected edge as eaves
      final leftEaves = roof.withEavesEdge(3);
      expect(leftEaves.safeEavesEdgeIndex, 3);
      expect(leftEaves.slopeDirection.dx, closeTo(1.0, 1e-5));
      expect(leftEaves.slopeDirection.dy, closeTo(0.0, 1e-5));

      // Hit-test central slope indicator arrow at centroid (4, 2.5)
      expect(
        ArchitectRoofPainterHelper.hitTestSlopeIndicator(
          roof,
          const Offset(4.0, 2.5),
          scale: 50.0,
        ),
        isTrue,
      );
    });
  });

  group('Auto-Roof Generator & Roof Tool', () {
    final walls = [
      const ArchitectWall(
        id: 'w1',
        startPoint: Offset(0, 0),
        endPoint: Offset(10, 0),
      ),
      const ArchitectWall(
        id: 'w2',
        startPoint: Offset(10, 0),
        endPoint: Offset(10, 6),
      ),
      const ArchitectWall(
        id: 'w3',
        startPoint: Offset(10, 6),
        endPoint: Offset(0, 6),
      ),
      const ArchitectWall(
        id: 'w4',
        startPoint: Offset(0, 6),
        endPoint: Offset(0, 0),
      ),
    ];

    test('generates 2 opposing planes for Gable roof and 4 planes for Hip roof', () {
      final storey = ArchitectStorey(
        id: 's1',
        name: 'Storey 1',
        elevation: 0,
        height: 3.0,
        walls: walls,
      );
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
      );

      final gableRoofs = ArchitectRoofGeometry.generateAutoRoof(
        project: project,
        type: AutoRoofType.gable,
        eavesOverhang: 0.50,
        slopeDegrees: 26.0,
        preset: ArchitectRoofPreset.warmPitched,
      );
      expect(gableRoofs.length, 2);

      final hipRoofs = ArchitectRoofGeometry.generateAutoRoof(
        project: project,
        type: AutoRoofType.hip,
        eavesOverhang: 0.50,
        slopeDegrees: 26.0,
        preset: ArchitectRoofPreset.warmPitched,
      );
      expect(hipRoofs.length, 4);
      final triangles = hipRoofs.where((r) => r.points.length == 3).length;
      final quads = hipRoofs.where((r) => r.points.length == 4).length;
      expect(triangles, 2);
      expect(quads, 2);
    });

    test('switches eaves edge with 1-tap hitTestEdgeIndex', () {
      final roof = ArchitectRoofPlane(
        id: 'r1',
        storeyId: 's1',
        points: const [
          Offset(0, 0),
          Offset(8, 0),
          Offset(8, 5),
          Offset(0, 5),
        ],
        eavesEdgeIndex: 0,
      );

      final hitRightEdge = ArchitectRoofTool.hitTestEdgeIndex(
        roof,
        const Offset(7.95, 2.5),
        tolerance: 0.30,
      );
      expect(hitRightEdge, 1);
    });
  });

  group('Dynamic Editable Roof Edge Distance to Lower-Storey Parallel Wall & 3D Constructive Detail', () {
    test('measures and edits eaves overhang distance to parallel wall on lower storey', () {
      const lowerStorey = ArchitectStorey(
        id: 's_ground',
        name: 'Ground Floor',
        elevation: 0.0,
        height: 3.0,
        walls: [
          // Wall along y = 0 with thickness 0.25m -> outer face is at y = -0.125m
          ArchitectWall(
            id: 'w_south',
            startPoint: Offset(0, 0),
            endPoint: Offset(8, 0),
            thickness: 0.25,
          ),
        ],
      );
      // Overhanging roof on upper storey whose eaves edge (Edge 0) is at y = -0.725m
      // (0.60m overhang beyond the outer wall face at y = -0.125m)
      final roof = ArchitectRoofPlane(
        id: 'r_upper',
        storeyId: 's_roof',
        points: const [
          Offset(-0.5, -0.725),
          Offset(8.5, -0.725),
          Offset(8.5, 3.0),
          Offset(-0.5, 3.0),
        ],
        eavesEdgeIndex: 0,
        eavesOverhang: 0.60,
      );
      final upperStorey = ArchitectStorey(
        id: 's_roof',
        name: 'Roof Level',
        elevation: 3.0,
        height: 2.8,
        roofs: [roof],
      );
      final project = ArchitectProject(
        id: 'p_overhang',
        name: 'Overhang Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [lowerStorey, upperStorey],
        activeStoreyId: 's_roof',
      );

      final dims = ArchitectPolygonDimensions.nearest(
        elementId: roof.id,
        polygon: roof.points,
        edge: 0,
        storey: upperStorey,
        project: project,
      );
      expect(dims, isNotEmpty);
      final dim = dims.firstWhere((d) => d.referenceId == 'w_south');
      expect(dim.distance, closeTo(0.60, 1e-4));

      // Edit the overhang distance to 0.85m
      final updatedPoints = dim.setDistance(
        roof.points,
        0.85,
        mode: ArchitectPolygonEdgeMode.move,
      );
      expect(updatedPoints, isNotNull);
      // New eaves Y should be -0.125 - 0.85 = -0.975
      expect(updatedPoints![0].dy, closeTo(-0.975, 1e-4));
      expect(updatedPoints[1].dy, closeTo(-0.975, 1e-4));
    });

    test('builds detailed constructive 3D roof mesh with rafters, battens, tiles, and standing-seam ribs', () {
      final tileRoof = ArchitectRoofPlane(
        id: 'r_tiles',
        storeyId: 's1',
        points: const [
          Offset(0, 0),
          Offset(6, 0),
          Offset(6, 4),
          Offset(0, 4),
        ],
        eavesEdgeIndex: 0,
        slopeDegrees: 28.0,
        eavesOverhang: 0.60,
        assembly: ArchitectRoofAssembly.fromPreset(
          ArchitectRoofPreset.warmPitched,
        ),
      );
      final metalRoof = tileRoof.copyWith(
        id: 'r_metal',
        assembly: ArchitectRoofAssembly.fromPreset(
          ArchitectRoofPreset.standingSeam,
        ),
      );

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        elevation: 0.0,
        height: 3.0,
        roofs: [tileRoof, metalRoof],
      );
      final project = ArchitectProject(
        id: 'p_3d',
        name: '3D Roof Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
      );

      final simpleMesh = Architect3dBuilder.buildProjectMesh(
        project,
        previewGeometry: false,
      );
      final detailedMesh = Architect3dBuilder.buildProjectMesh(
        project,
        previewGeometry: true,
      );

      // Detailed 3D mesh contains full constructive elements (rafters, counter-battens, battens, Mauerlat, tiles/seams)
      expect(
        detailedMesh.triangles.length,
        greaterThan(simpleMesh.triangles.length * 8),
      );
    });
  });

  group('Clean Architectural Section Cut (Carpentry, Battens & Wall Clipping)', () {
    test('produces clean section with rafters, battens, Mauerlat, ridge purlin, and clipped walls', () {
      final walls = [
        const ArchitectWall(
          id: 'w_south',
          startPoint: Offset(0, 0),
          endPoint: Offset(8, 0),
          thickness: 0.25,
          height: 3.0,
        ),
        const ArchitectWall(
          id: 'w_north',
          startPoint: Offset(8, 6),
          endPoint: Offset(0, 6),
          thickness: 0.25,
          height: 3.0,
        ),
      ];
      final storey = ArchitectStorey(
        id: 's1',
        name: 'Storey 1',
        elevation: 0.0,
        height: 3.0,
        walls: walls,
      );
      final baseProject = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
      );

      final gableRoofs = ArchitectRoofGeometry.generateAutoRoof(
        project: baseProject,
        type: AutoRoofType.gable,
        eavesOverhang: 0.60,
        slopeDegrees: 26.0,
        preset: ArchitectRoofPreset.warmPitched,
      );
      final roofStorey = storey.copyWith(roofs: gableRoofs);
      final project = baseProject.updateActiveStorey(roofStorey);

      const cutLine = ArchitectSection(
        id: 'sec_1',
        name: 'A-A',
        start: Offset(4, -2),
        end: Offset(4, 8),
      );

      final slices = ArchitectRoofGeometry.buildSectionSlices(
        storey: roofStorey,
        sectionLine: cutLine,
      );
      expect(slices.length, 2);

      // Verify discrete battens, rafters, Mauerlat, and ridge purlin exist in slices
      final allMembers = [for (final s in slices) ...s.members];
      final battenMembers = allMembers
          .where((m) => m.kind == ArchitectRoofMemberKind.batten)
          .toList();
      final mauerlatMembers = allMembers
          .where((m) => m.kind == ArchitectRoofMemberKind.wallPlate)
          .toList();
      final purlinMembers = allMembers
          .where((m) => m.kind == ArchitectRoofMemberKind.ridgePurlin)
          .toList();
      expect(battenMembers.length, greaterThan(10));
      expect(mauerlatMembers.length, 2);
      expect(purlinMembers.length, 1);

      // Verify the two roof slices meet cleanly at the ridge (t = 5.0 along cut line from y=-2 to y=8)
      final firstRoofMaxT = [
        for (final m in slices[0].members.where(
          (m) => m.kind == ArchitectRoofMemberKind.layer,
        ))
          for (final pt in m.polygon) pt.dx,
      ].reduce((a, b) => a > b ? a : b);
      final secondRoofMinT = [
        for (final m in slices[1].members.where(
          (m) => m.kind == ArchitectRoofMemberKind.layer,
        ))
          for (final pt in m.polygon) pt.dx,
      ].reduce((a, b) => a < b ? a : b);

      expect(firstRoofMaxT, closeTo(5.0, 0.02));
      expect(secondRoofMinT, closeTo(5.0, 0.02));

      // Also verify full ArchitectBuildingSection.build produces roof & timber cross-section regions
      final section = ArchitectBuildingSection.build(project, cutLine);
      final roofRegions = section.regions.where((r) => r.roof).toList();
      final timberCrossSections = section.regions
          .where((r) => r.timberCrossSectionPolygon != null)
          .toList();
      expect(roofRegions.isNotEmpty, isTrue);
      expect(timberCrossSections.length, greaterThanOrEqualTo(3));
    });
  });

  group('Snapping Improvements', () {
    test('omits false Midpoint snap on short wall end-caps and indexes reference walls from storey below', () {
      const lowerStorey = ArchitectStorey(
        id: 's_lower',
        name: 'Floor 1',
        elevation: 0,
        height: 3.0,
        walls: [
          ArchitectWall(
            id: 'w_lower',
            startPoint: Offset(0, 0),
            endPoint: Offset(6, 0),
            thickness: 0.25,
          ),
        ],
      );
      const roofStorey = ArchitectStorey(
        id: 's_roof',
        name: 'Roof',
        elevation: 3.0,
        height: 2.8,
      );
      final project = ArchitectProject(
        id: 'p_snap',
        name: 'Snap Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [lowerStorey, roofStorey],
        activeStoreyId: 's_roof',
      );

      // When active storey is s_roof (which has no walls), ArchitectSnapGeometry indexes reference walls from s_lower
      final snapGeo = ArchitectSnapGeometry.of(project);
      expect(snapGeo.edges.isNotEmpty, isTrue);

      // Short 25cm wall end-cap at (0, 0) should NOT produce a Midpoint point snap
      final nearOrigin = snapGeo.query(const Offset(0, 0), 0.25);
      final falseCapMidpoints = nearOrigin.where((p) => p.label == 'Midpoint');
      expect(falseCapMidpoints, isEmpty);
    });
  });
}
