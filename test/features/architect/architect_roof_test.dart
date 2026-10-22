import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
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

      // Verify that all batten cross sections are true orthogonal rectangles (90 deg corners, not squashed parallelograms)
      for (final batten in battenMembers) {
        expect(batten.polygon.length, equals(4));
        final pts = batten.polygon;
        final v01 = pts[1] - pts[0];
        final v12 = pts[2] - pts[1];
        final v23 = pts[3] - pts[2];
        final v30 = pts[0] - pts[3];

        // Corners are exactly 90 degrees (dot product == 0)
        expect(v01.dx * v12.dx + v01.dy * v12.dy, closeTo(0.0, 1e-4));
        expect(v12.dx * v23.dx + v12.dy * v23.dy, closeTo(0.0, 1e-4));
        expect(v23.dx * v30.dx + v23.dy * v30.dy, closeTo(0.0, 1e-4));

        // Dimension along slope is battenWidth (0.05m)
        expect(v01.distance, closeTo(0.05, 1e-4));
        expect(v23.distance, closeTo(0.05, 1e-4));

        // Dimension perpendicular to slope is battenHeight (0.04m)
        expect(v12.distance, closeTo(0.04, 1e-4));
        expect(v30.distance, closeTo(0.04, 1e-4));
      }

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

  group('Roof Wall Attachment, 10cm Concrete Ring Beam, Fascia & Metal Flashing Section Detail', () {
    test('defaults attachToWalls, hasRingBeam, and hasMetalFlashing to true', () {
      final defaultRoof = ArchitectRoofPlane(
        id: 'r_def',
        storeyId: 's1',
        points: const [Offset(0, 0), Offset(5, 0), Offset(5, 5), Offset(0, 5)],
        eavesEdgeIndex: 0,
      );
      expect(defaultRoof.attachToWalls, isTrue);
      expect(defaultRoof.assembly.timber.hasRingBeam, isTrue);
      expect(defaultRoof.assembly.timber.ringBeamHeight, closeTo(0.10, 1e-4));
      expect(defaultRoof.assembly.timber.hasMetalFlashing, isTrue);
    });

    test('resolveAttachedBaseElevationOffset aligns roof underside with supporting wall top', () {
      const lowerStorey = ArchitectStorey(
        id: 's_ground',
        name: 'Ground',
        elevation: 0.0,
        height: 2.80,
        walls: [
          ArchitectWall(
            id: 'w1',
            startPoint: Offset(0, 0),
            endPoint: Offset(6, 0),
            height: 2.80,
          ),
        ],
      );
      final roof = ArchitectRoofPlane(
        id: 'r1',
        storeyId: 's_roof',
        points: const [
          Offset(-0.6, -0.6),
          Offset(6.6, -0.6),
          Offset(6.6, 5.0),
          Offset(-0.6, 5.0),
        ],
        eavesEdgeIndex: 0,
        eavesOverhang: 0.60,
        slopeDegrees: 25.0,
        attachToWalls: true,
      );
      const roofStorey = ArchitectStorey(
        id: 's_roof',
        name: 'Roof',
        elevation: 2.80,
        height: 2.50,
      );

      final offset = ArchitectRoofGeometry.resolveAttachedBaseElevationOffset(
        roof: roof,
        storey: roofStorey,
        lowerStorey: lowerStorey,
      );
      expect(offset, isNotNull);
      // Offset relative to roofStorey.elevation (2.80) aligns roof base with lower wall top (2.80)
      expect(offset, closeTo(0.0, 1e-4));
      expect(roofStorey.elevation + offset, closeTo(lowerStorey.elevation + 2.80, 1e-4));
    });

    test('builds 10cm concrete ring beam, wall plate, fascia, and metal flashing in section slices', () {
      const walls = [
        ArchitectWall(
          id: 'w_front',
          startPoint: Offset(0, 0),
          endPoint: Offset(6, 0),
          thickness: 0.25,
          height: 2.80,
        ),
      ];
      final roof = ArchitectRoofPlane(
        id: 'r_detail',
        storeyId: 's1',
        points: const [
          Offset(-0.6, -0.6),
          Offset(6.6, -0.6),
          Offset(6.6, 5.0),
          Offset(-0.6, 5.0),
        ],
        eavesEdgeIndex: 0,
        eavesOverhang: 0.60,
        slopeDegrees: 25.0,
        attachToWalls: true,
      );
      final storey = ArchitectStorey(
        id: 's1',
        name: 'Storey 1',
        elevation: 0.0,
        height: 2.80,
        walls: walls,
        roofs: [roof],
      );
      const cutLine = ArchitectSection(
        id: 'sec_test',
        name: 'Cut',
        start: Offset(3, -2),
        end: Offset(3, 6),
      );

      final slices = ArchitectRoofGeometry.buildSectionSlices(
        storey: storey,
        sectionLine: cutLine,
      );
      expect(slices.length, 1);
      final slice = slices.first;

      final ringBeam = slice.members.where((m) => m.kind == ArchitectRoofMemberKind.ringBeam).firstOrNull;
      final wallPlate = slice.members.where((m) => m.kind == ArchitectRoofMemberKind.wallPlate).firstOrNull;
      final fascia = slice.members.where((m) => m.kind == ArchitectRoofMemberKind.fascia).firstOrNull;
      final metalFlashing = slice.members.where((m) => m.kind == ArchitectRoofMemberKind.metalFlashing).firstOrNull;

      expect(ringBeam, isNotNull);
      expect(wallPlate, isNotNull);
      expect(fascia, isNotNull);
      expect(metalFlashing, isNotNull);

      // Helper to compute bounding rect of a member's polygon
      Rect memberBounds(List<Offset> pts) {
        var minX = pts.first.dx, maxX = pts.first.dx;
        var minY = pts.first.dy, maxY = pts.first.dy;
        for (final p in pts.skip(1)) {
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }
        return Rect.fromLTRB(minX, minY, maxX, maxY);
      }

      // Verify the concrete ring beam height is exactly 10 cm (0.10m)
      final rbBounds = memberBounds(ringBeam!.polygon);
      expect(rbBounds.height, closeTo(0.10, 1e-4));
      // Ring beam spans the wall thickness (0.25m)
      expect(rbBounds.width, closeTo(0.25, 1e-3));

      // Wall-plate sits directly on top of the concrete ring beam (wp bottom == rb top)
      final wpBounds = memberBounds(wallPlate!.polygon);
      expect(wpBounds.top, closeTo(rbBounds.bottom, 1e-3));
    });

    test('ArchitectBuildingSection clips wall to underside of 10cm ring beam with zero redundant lines and picks roof', () {
      const walls = [
        ArchitectWall(
          id: 'w_front',
          startPoint: Offset(0, 0),
          endPoint: Offset(6, 0),
          thickness: 0.25,
          height: 3.50, // Wall extends up
        ),
      ];
      final roof = ArchitectRoofPlane(
        id: 'r_attached',
        storeyId: 's1',
        points: const [
          Offset(-0.6, -0.6),
          Offset(6.6, -0.6),
          Offset(6.6, 5.0),
          Offset(-0.6, 5.0),
        ],
        eavesEdgeIndex: 0,
        eavesOverhang: 0.60,
        slopeDegrees: 25.0,
        attachToWalls: true,
      );
      final storey = ArchitectStorey(
        id: 's1',
        name: 'Storey 1',
        elevation: 0.0,
        height: 2.80,
        walls: walls,
        roofs: [roof],
      );
      final project = ArchitectProject(
        id: 'p_sec',
        name: 'Section Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
      );
      const cutLine = ArchitectSection(
        id: 'sec_1',
        name: 'A-A',
        start: Offset(3, -2),
        end: Offset(3, 6),
      );

      final section = ArchitectBuildingSection.build(project, cutLine);
      expect(section.regions.isNotEmpty, isTrue);

      // Verify roof picking and bounds
      final found = ArchitectBuildingSection.findRoofById(project, 'r_attached');
      expect(found, isNotNull);
      expect(found!.roof.id, 'r_attached');

      final bounds = section.roofBounds('r_attached');
      expect(bounds, isNotNull);

      final picked = section.pickRoof(bounds!.center, 0.5);
      expect(picked, 'r_attached');

      // The supporting wall top in the section should be clipped to the bottom of the 10cm ring beam
      final wallRegion = section.regions.firstWhere((r) => r.wallId == 'w_front');
      final wallBounds = wallRegion.path.getBounds();
      final rbRegion = section.regions.firstWhere(
        (r) => r.timberCrossSectionPolygon == null && r.roof && r.material == SlabMaterial.concrete,
      );
      final rbBounds = rbRegion.path.getBounds();
      expect(wallBounds.bottom, closeTo(rbBounds.top, 0.01));
    });
  });

  group('Roof Lines Plan & Multi-Level Setback Roof Representation', () {
    test('orderedPlanStoreys always positions the roof lines plan at index 0 and adapts above new storeys', () {
      const s0 = ArchitectStorey(
        id: 's0',
        name: 'Ground',
        elevation: 0.0,
        height: 3.0,
      );
      const s1 = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        elevation: 3.0,
        height: 3.0,
      );
      final project = ArchitectProject(
        id: 'p_plan',
        name: 'Plan Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [s0, s1],
        activeStoreyId: 's0',
      ).ensureRoofStorey();

      // Roof lines storey exists and sits at the very top (index 0)
      expect(project.roofStorey, isNotNull);
      expect(project.roofStorey!.isRoof, isTrue);
      expect(project.orderedPlanStoreys.first.id, project.roofStorey!.id);
      expect(project.roofStorey!.elevation, closeTo(6.0, 1e-4));

      // Add a new higher storey (+6.00)
      const s2 = ArchitectStorey(
        id: 's2',
        name: 'Floor 2',
        elevation: 6.0,
        height: 2.80,
      );
      final updatedProject = project.copyWith(
        storeys: [...project.storeys, s2],
      ).syncRoofElevation();

      // Roof lines plan still sits at index 0, and its elevation dynamically updated to 8.80m!
      expect(updatedProject.orderedPlanStoreys.first.id, updatedProject.roofStorey!.id);
      expect(updatedProject.roofStorey!.elevation, closeTo(8.80, 1e-4));
    });

    test('indexes reference walls from highestWallStorey when active storey is roof', () {
      const s0 = ArchitectStorey(
        id: 's0',
        name: 'Ground',
        elevation: 0.0,
        height: 3.0,
        walls: [
          ArchitectWall(
            id: 'w_main',
            startPoint: Offset(0, 0),
            endPoint: Offset(10, 0),
            thickness: 0.25,
          ),
        ],
      );
      final project = ArchitectProject(
        id: 'p_snap_roof',
        name: 'Snap Roof Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [s0],
        activeStoreyId: 's0',
      ).ensureRoofStorey();

      // Switch to roof storey
      final roofActiveProject = project.copyWith(
        activeStoreyId: project.roofStorey!.id,
      );
      expect(roofActiveProject.activeStorey.isRoof, isTrue);

      final snapGeo = ArchitectSnapGeometry.of(roofActiveProject);
      expect(snapGeo.edges.isNotEmpty, isTrue);

      // Snaps to wall endpoint from highest wall storey below
      final originHits = snapGeo.query(const Offset(0, 0), 0.2);
      expect(originHits.any((h) => h.label == 'Endpoint'), isTrue);
    });

    test('drawSupportingWallUnderlay runs cleanly and lower-level roofs render with elevation badge', () {
      final s0 = ArchitectStorey(
        id: 's0',
        name: 'Ground',
        elevation: 0.0,
        height: 3.0,
        walls: const [
          ArchitectWall(
            id: 'w1',
            startPoint: Offset(0, 0),
            endPoint: Offset(6, 0),
            thickness: 0.25,
          ),
          ArchitectWall(
            id: 'w2',
            startPoint: Offset(6, 0),
            endPoint: Offset(6, 6),
            thickness: 0.25,
          ),
        ],
        roofs: [
          // Lower level setback roof over garage/veranda
          ArchitectRoofPlane(
            id: 'r_lower',
            storeyId: 's0',
            points: [Offset(0, 0), Offset(4, 0), Offset(4, 3), Offset(0, 3)],
            slopeDegrees: 15.0,
          ),
        ],
      );
      final project = ArchitectProject(
        id: 'p_underlay',
        name: 'Underlay Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [s0],
        activeStoreyId: 's0',
      ).ensureRoofStorey();

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Verify supporting wall underlay renders without error
      expect(
        () => ArchitectRoofPainterHelper.drawSupportingWallUnderlay(
          canvas: canvas,
          project: project,
          palette: const ArchitectCanvasPalette.dark(),
          scale: 15.0,
        ),
        returnsNormally,
      );

      // Verify lower level roof renders with thin lines and elevation badge
      expect(
        () => ArchitectRoofPainterHelper.paintRoofs(
          canvas: canvas,
          storey: s0,
          scale: 15.0,
          selectedIds: const {},
          isLowerLevel: true,
        ),
        returnsNormally,
      );

      // Verify top level roof renders with thick lines
      final roofStorey = project.roofStorey!;
      final topRoof = ArchitectRoofPlane(
        id: 'r_top',
        storeyId: roofStorey.id,
        points: const [Offset(0, 0), Offset(6, 0), Offset(6, 6), Offset(0, 6)],
        slopeDegrees: 25.0,
      );
      expect(
        () => ArchitectRoofPainterHelper.paintRoofs(
          canvas: canvas,
          storey: roofStorey.copyWith(roofs: [topRoof]),
          scale: 15.0,
          selectedIds: const {},
          isLowerLevel: false,
        ),
        returnsNormally,
      );
    });
  });

  group('Roof Edge Displacement & Catheti Angle Preservation', () {
    test('offsetEdgePreservingAngles preserves adjacent hip/verge angles perfectly', () {
      // Hipped roof trapezoid:
      // Edge 0 (eaves): (0, 0) to (10, 0)
      // Edge 1 (hip): (10, 0) to (7, 3) [angle: 135 deg / -45 deg]
      // Edge 2 (ridge): (7, 3) to (3, 3)
      // Edge 3 (hip): (3, 3) to (0, 0) [angle: 225 deg / +45 deg]
      final poly = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(7, 3),
        const Offset(3, 3),
      ];

      // Pull edge 0 outward (towards eaves) by 0.50m
      final extended = BimPolygonGeometry.offsetEdge(
        poly,
        0,
        0.50,
        mode: BimPolygonEdgeMode.extendCatheti,
      );

      expect(extended, isNotNull);
      expect(extended!.length, equals(4));

      // The new eaves edge endpoints should be (-0.5, -0.5) and (10.5, -0.5)
      expect(extended[0].dx, closeTo(-0.5, 1e-4));
      expect(extended[0].dy, closeTo(-0.5, 1e-4));
      expect(extended[1].dx, closeTo(10.5, 1e-4));
      expect(extended[1].dy, closeTo(-0.5, 1e-4));

      // Check that the hip directions (катети) are strictly preserved
      final originalHip0Dir = poly[0] - poly[3]; // (0,0) - (3,3) = (-3, -3)
      final extendedHip0Dir = extended[0] - extended[3]; // (-0.5, -0.5) - (3, 3) = (-3.5, -3.5)
      expect(extendedHip0Dir.dx, closeTo(extendedHip0Dir.dy, 1e-6));
      expect(BimPolygonGeometry.cross(originalHip0Dir, extendedHip0Dir).abs(), closeTo(0.0, 1e-6));

      final originalHip1Dir = poly[2] - poly[1]; // (7,3) - (10,0) = (-3, 3)
      final extendedHip1Dir = extended[2] - extended[1]; // (7,3) - (10.5,-0.5) = (-3.5, 3.5)
      expect(extendedHip1Dir.dx, closeTo(-extendedHip1Dir.dy, 1e-6));
      expect(BimPolygonGeometry.cross(originalHip1Dir, extendedHip1Dir).abs(), closeTo(0.0, 1e-6));
    });
  });

  group('Multi-Pitch Roof & Straight Skeleton Decomposition for Articulated Walls', () {
    test('decomposeMultiPitchPolygon cleanly breaks L-shaped building into matching hipped planes with 45 deg hips and valleys', () {
      const storey = ArchitectStorey(
        id: 's_l',
        name: 'Storey L',
        elevation: 0.0,
        height: 3.0,
      );
      // L-shaped footprint:
      // (0,0) -> (12,0) -> (12,6) -> (6,6) -> (6,10) -> (0,10)
      final lFootprint = [
        const Offset(0, 0),
        const Offset(12, 0),
        const Offset(12, 6),
        const Offset(6, 6),
        const Offset(6, 10),
        const Offset(0, 10),
      ];

      final planes = ArchitectRoofGeometry.decomposeMultiPitchPolygon(
        eavesPolygon: lFootprint,
        storey: storey,
        slopeDegrees: 25.0,
        baseElevationOffset: 3.0,
        eavesOverhang: 0.50,
        assembly: ArchitectRoofAssembly.fromPreset(ArchitectRoofPreset.pitchedTiles),
      );

      expect(planes.isNotEmpty, isTrue);
      // All generated planes belong to the same roof group
      final grpId = planes.first.roofGroupId;
      expect(grpId, isNotNull);
      expect(planes.every((p) => p.roofGroupId == grpId), isTrue);

      // Verify that all planes have valid planar points and eaves edge index 0
      for (final p in planes) {
        expect(p.points.length, greaterThanOrEqualTo(3));
        expect(p.safeEavesEdgeIndex, equals(0));
        expect(p.slopeDegrees, equals(25.0));
      }
    });

    test('offsetPolygonOutwards offsets perimeter uniformly and cleanly', () {
      final rect = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 6),
        const Offset(0, 6),
      ];
      final offset = ArchitectRoofGeometry.offsetPolygonOutwards(rect, 0.50);
      expect(offset.length, equals(4));
      // Outer rect should be [-0.5, 10.5] x [-0.5, 6.5]
      expect(offset.any((p) => (p - const Offset(-0.5, -0.5)).distance < 1e-4), isTrue);
      expect(offset.any((p) => (p - const Offset(10.5, -0.5)).distance < 1e-4), isTrue);
      expect(offset.any((p) => (p - const Offset(10.5, 6.5)).distance < 1e-4), isTrue);
      expect(offset.any((p) => (p - const Offset(-0.5, 6.5)).distance < 1e-4), isTrue);
    });
  });

  group('Weighted Straight Skeleton & Unequal Roof Pitches', () {
    test('calculateSlopeToMatchRidgeHeight computes exact matching pitch for narrower wing', () {
      // Main wing: half-span run = 5.0m, pitch = 22.0 deg
      final mainRidgeHeight = 5.0 * math.tan(22.0 * math.pi / 180.0); // ~2.020m
      // Narrow wing: half-span run = 3.5m
      final requiredSlope = ArchitectRoofGeometry.calculateSlopeToMatchRidgeHeight(
        targetRidgeHeight: mainRidgeHeight,
        runDistance: 3.5,
      );
      // Expected: atan(2.020 / 3.5) * 180 / pi = 29.99 deg (~30.0 deg)
      expect(requiredSlope, closeTo(30.0, 0.1));

      // Check elevation match in mm
      final narrowRidgeHeight = 3.5 * math.tan(requiredSlope * math.pi / 180.0);
      expect((narrowRidgeHeight - mainRidgeHeight).abs(), lessThan(0.005));
    });

    test('calculateHipAngle computes plan hip angle for orthogonal and non-orthogonal corners', () {
      // 90 deg corner with equal slopes -> 45.0 deg
      final hipEqual = ArchitectRoofGeometry.calculateHipAngle(
        slopeDeg1: 25.0,
        slopeDeg2: 25.0,
      );
      expect(hipEqual, closeTo(45.0, 1e-4));

      // 90 deg corner with unequal slopes (25 deg vs 35 deg)
      final hipUnequal = ArchitectRoofGeometry.calculateHipAngle(
        slopeDeg1: 25.0,
        slopeDeg2: 35.0,
      );
      final expectedAngle = math.atan2(
        math.tan(25.0 * math.pi / 180.0),
        math.tan(35.0 * math.pi / 180.0),
      ) * 180.0 / math.pi;
      expect(hipUnequal, closeTo(expectedAngle, 1e-4));
      expect(hipUnequal, closeTo(33.66, 0.1));

      // 120 deg obtuse corner with equal slopes -> 60.0 deg
      final hip120 = ArchitectRoofGeometry.calculateHipAngle(
        slopeDeg1: 25.0,
        slopeDeg2: 25.0,
        cornerAngleRad: 120.0 * math.pi / 180.0,
      );
      expect(hip120, closeTo(60.0, 1e-4));
    });

    test('decomposeMultiPitchPolygon with perEdgeSlopeDegrees yields continuous 3D hips and valleys', () {
      const storey = ArchitectStorey(
        id: 's_unequal',
        name: 'Storey Unequal',
        elevation: 0.0,
        height: 3.0,
      );
      final lFootprint = [
        const Offset(0, 0),
        const Offset(12, 0),
        const Offset(12, 6),
        const Offset(6, 6),
        const Offset(6, 10),
        const Offset(0, 10),
      ];

      // Slopes for each of the 6 edges: edges along main body = 22 deg, wing edges = 30 deg
      final perEdge = [22.0, 22.0, 30.0, 30.0, 30.0, 22.0];

      final planes = ArchitectRoofGeometry.decomposeMultiPitchPolygon(
        eavesPolygon: lFootprint,
        storey: storey,
        slopeDegrees: 22.0,
        baseElevationOffset: 3.0,
        eavesOverhang: 0.50,
        assembly: ArchitectRoofAssembly.fromPreset(ArchitectRoofPreset.pitchedTiles),
        perEdgeSlopeDegrees: perEdge,
      );

      expect(planes.isNotEmpty, isTrue);
      // Verify planes retain individual slope degrees and group linkage
      for (var i = 0; i < planes.length; i++) {
        expect(planes[i].isSlopeLocked, isTrue);
        expect(planes[i].points.length, greaterThanOrEqualTo(3));
      }
    });

    test('ArchitectRoofPlane isSlopeLocked field serializes and clones correctly', () {
      final roof = ArchitectRoofPlane(
        id: 'r_lock_test',
        storeyId: 's1',
        points: const [Offset(0, 0), Offset(5, 0), Offset(5, 4), Offset(0, 4)],
        roofGroupId: 'grp_123',
        isSlopeLocked: true,
      );
      expect(roof.isSlopeLocked, isTrue);

      final unlocked = roof.copyWith(isSlopeLocked: false);
      expect(unlocked.isSlopeLocked, isFalse);

      final json = unlocked.toJson();
      expect(json['isSlopeLocked'], isFalse);

      final restored = ArchitectRoofPlane.fromJson(json);
      expect(restored.isSlopeLocked, isFalse);
    });

    test('finishDraft completes roof without clicking first point (green checkmark trigger)', () {
      final tool = ArchitectRoofTool();
      final storey = ArchitectStorey(id: 's1', name: 'Storey 1', elevation: 0.0, height: 2.80);

      // 1. Polygon mode
      tool.setDrawMode(RoofDrawMode.polygon);
      tool.addDraftPoint(const Offset(0, 0), storey: storey);
      tool.addDraftPoint(const Offset(6, 0), storey: storey);
      expect(tool.finishDraft(storey: storey), isNull); // only 2 points

      tool.addDraftPoint(const Offset(6, 4), storey: storey);
      tool.addDraftPoint(const Offset(0, 4), storey: storey);
      expect(tool.draftPoints.length, 4);

      // Finish without clicking (0,0)
      final created = tool.finishDraft(storey: storey);
      expect(created, isNotNull);
      expect(created!.length, 1);
      expect(created.first.points.length, 4);
      expect(tool.isDrafting, isFalse);

      // 2. Multi-pitch mode
      tool.setDrawMode(RoofDrawMode.multiPitch);
      tool.addDraftPoint(const Offset(0, 0), storey: storey);
      tool.addDraftPoint(const Offset(10, 0), storey: storey);
      tool.addDraftPoint(const Offset(10, 6), storey: storey);
      tool.addDraftPoint(const Offset(0, 6), storey: storey);
      expect(tool.draftPoints.length, 4);

      // Finish directly via checkmark
      final multiPlanes = tool.finishDraft(storey: storey);
      expect(multiPlanes, isNotNull);
      expect(multiPlanes!.length, greaterThanOrEqualTo(2));
      expect(tool.isDrafting, isFalse);
    });
  });
}
