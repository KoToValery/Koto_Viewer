import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_en.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart'
    show ArchitectTool;
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_ceiling_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_layout.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_catalog.dart';

void main() {
  group('ArchitectSuspendedCeiling model & catalog', () {
    test('tool belongs to build category and ceiling layer exists', () {
      expect(
        ArchitectToolCategory.of(ArchitectTool.ceiling),
        ArchitectToolCategory.build,
      );
      expect(
        ArchitectLayer.defaultLayers().any(
          (l) => l.id == ArchitectLayer.ceilingLayerId && l.id == 'A-CLNG',
        ),
        isTrue,
      );
    });

    test('JSON roundtrip preserves Armstrong and Gypsum properties', () {
      const armstrong = ArchitectSuspendedCeiling(
        id: 'ceil_1',
        type: SuspendedCeilingType.armstrong,
        polygon: [Offset(0, 0), Offset(4, 0), Offset(4, 3), Offset(0, 3)],
        holes: [
          [Offset(1, 1), Offset(2, 1), Offset(2, 2), Offset(1, 2)],
        ],
        dropFromUpperSlab: 0.30,
        tileWidth: 0.60,
        tileLength: 1.20,
        gridOrigin: Offset(0.5, 0.5),
        gridAngle: math.pi / 4,
        gridCentered: false,
        armstrongProfile: ArmstrongProfileType.t15,
        hasInsulation: true,
        insulationThickness: 0.06,
        label: 'Окачен таван 1',
      );
      final parsed = ArchitectSuspendedCeiling.fromJson(armstrong.toJson());
      expect(parsed.id, 'ceil_1');
      expect(parsed.type, SuspendedCeilingType.armstrong);
      expect(parsed.area, closeTo(11.0, 1e-6));
      expect(parsed.dropFromUpperSlab, closeTo(0.30, 1e-6));
      expect(parsed.tileWidth, closeTo(0.60, 1e-6));
      expect(parsed.tileLength, closeTo(1.20, 1e-6));
      expect(parsed.gridOrigin, const Offset(0.5, 0.5));
      expect(parsed.gridAngle, closeTo(math.pi / 4, 1e-6));
      expect(parsed.gridCentered, isFalse);
      expect(parsed.armstrongProfile, ArmstrongProfileType.t15);
      expect(parsed.hasInsulation, isTrue);
      expect(parsed.insulationThickness, closeTo(0.06, 1e-6));
      expect(parsed.label, 'Окачен таван 1');

      const gypsum = ArchitectSuspendedCeiling(
        id: 'ceil_2',
        type: SuspendedCeilingType.gypsumBoard,
        polygon: [Offset(0, 0), Offset(3, 0), Offset(3, 3), Offset(0, 3)],
        gypsumVariant: GypsumBoardVariant.moistureResistant,
        doubleBoard: true,
      );
      final parsedG = ArchitectSuspendedCeiling.fromJson(gypsum.toJson());
      expect(parsedG.type, SuspendedCeilingType.gypsumBoard);
      expect(parsedG.gypsumVariant, GypsumBoardVariant.moistureResistant);
      expect(parsedG.doubleBoard, isTrue);
      expect(parsedG.effectivePanelThickness, closeTo(0.025, 1e-6));
    });
  });

  group('ArchitectCeilingGeometry elevation & beam conflicts', () {
    ArchitectProject makeProject({
      List<ArchitectSlab> upperSlabs = const [],
      List<ArchitectBeam> groundBeams = const [],
    }) {
      final now = DateTime(2026, 11, 20);
      return ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: now,
        updatedAt: now,
        activeStoreyId: 's0',
        storeys: [
          ArchitectStorey(
            id: 's0',
            name: '±0.00',
            elevation: 0.0,
            height: 3.00,
            beams: groundBeams,
          ),
          ArchitectStorey(
            id: 's1',
            name: '+3.00',
            elevation: 3.00,
            height: 2.80,
            slabs: upperSlabs,
          ),
        ],
      );
    }

    test('computes elevation from actual upper slab underside', () {
      final project = makeProject(
        upperSlabs: const [
          ArchitectSlab(
            id: 'slab_1',
            polygon: [Offset(-1, -1), Offset(6, -1), Offset(6, 6), Offset(-1, 6)],
            thickness: 0.25,
            coreTopOffset: -0.05,
          ),
        ],
      );
      const ceiling = ArchitectSuspendedCeiling(
        id: 'c1',
        polygon: [Offset(0, 0), Offset(4, 0), Offset(4, 3), Offset(0, 3)],
        dropFromUpperSlab: 0.20,
      );
      final metrics = ArchitectCeilingGeometry.computeMetrics(
        project,
        project.storeys[0],
        ceiling,
      );
      // upper slab bottom = 3.00 + (-0.05) - 0.25 = 2.70
      expect(metrics.fromActualUpperSlab, isTrue);
      expect(metrics.upperSlabBottom, closeTo(2.70, 1e-6));
      expect(metrics.ceilingElevation, closeTo(2.50, 1e-6));
      expect(metrics.clearHeight, closeTo(2.50, 1e-6));
      // constructionThickness = 0.0125 + 0.04 = 0.0525 -> plenum = 0.1475
      expect(metrics.plenumDepth, closeTo(0.1475, 1e-6));
      expect(metrics.hasAnyConflict, isFalse);
    });

    test('falls back to upper storey minus default 20cm when no slab exists', () {
      final project = makeProject();
      const ceiling = ArchitectSuspendedCeiling(
        id: 'c1',
        polygon: [Offset(0, 0), Offset(4, 0), Offset(4, 3), Offset(0, 3)],
        dropFromUpperSlab: 0.25,
      );
      final metrics = ArchitectCeilingGeometry.computeMetrics(
        project,
        project.storeys[0],
        ceiling,
      );
      expect(metrics.fromActualUpperSlab, isFalse);
      expect(metrics.upperSlabBottom, closeTo(2.80, 1e-6));
      expect(metrics.ceilingElevation, closeTo(2.55, 1e-6));
      expect(metrics.clearHeight, closeTo(2.55, 1e-6));
    });

    test('detects beam collision and ignores beams inside ceiling hole', () {
      final project = makeProject(
        groundBeams: const [
          ArchitectBeam(
            id: 'b_hit',
            startPoint: Offset(0.5, 0),
            endPoint: Offset(0.5, 3),
            width: 0.25,
            depth: 0.50,
            baseOffset: 2.30, // bottom = 2.30, ceiling top = 2.55 + 0.0525 = 2.6025
          ),
          ArchitectBeam(
            id: 'b_hole',
            startPoint: Offset(2.5, 1.2),
            endPoint: Offset(2.5, 1.8),
            width: 0.20,
            depth: 0.50,
            baseOffset: 2.30,
          ),
        ],
      );
      const ceiling = ArchitectSuspendedCeiling(
        id: 'c1',
        polygon: [Offset(0, 0), Offset(4, 0), Offset(4, 3), Offset(0, 3)],
        holes: [
          [Offset(2.0, 1.0), Offset(3.0, 1.0), Offset(3.0, 2.0), Offset(2.0, 2.0)],
        ],
        dropFromUpperSlab: 0.25,
      );
      final metrics = ArchitectCeilingGeometry.computeMetrics(
        project,
        project.storeys[0],
        ceiling,
      );
      expect(metrics.hasBeamConflict, isTrue);
      expect(metrics.beamConflicts.map((c) => c.beamId), ['b_hit']);
      expect(metrics.beamConflicts.first.overlapDepth, greaterThan(0.25));
    });
  });

  group('ArchitectCeilingGeometry Armstrong grid', () {
    test('centers symmetric 60x60 grid and clips around holes', () {
      const ceiling = ArchitectSuspendedCeiling(
        id: 'arm_1',
        type: SuspendedCeilingType.armstrong,
        polygon: [Offset(0, 0), Offset(3.0, 0), Offset(3.0, 2.4), Offset(0, 2.4)],
        holes: [
          [Offset(1.0, 0.8), Offset(2.0, 0.8), Offset(2.0, 1.6), Offset(1.0, 1.6)],
        ],
        tileWidth: 0.60,
        tileLength: 0.60,
        gridCentered: true,
      );
      final lines = ArchitectCeilingGeometry.armstrongGridLines(ceiling);
      expect(lines, isNotEmpty);
      // Every generated segment midpoint must stay inside outer and outside hole.
      for (final (a, b) in lines) {
        final mid = (a + b) * 0.5;
        expect(ceiling.containsPoint(mid), isTrue);
      }
    });
  });

  group('Commands, undo/redo, editing & storey copy', () {
    test('Put, Update, ToggleCeilingPlan, Move, CutOpening, Delete & Copy', () {
      final now = DateTime(2026, 11, 20);
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: now,
        updatedAt: now,
        activeStoreyId: 's0',
        storeys: const [
          ArchitectStorey(id: 's0', name: '±0.00', elevation: 0.0, height: 3.0),
          ArchitectStorey(id: 's1', name: '+3.00', elevation: 3.0, height: 2.8),
        ],
      );
      final controller = ArchitectCommandController(project);
      const c1 = ArchitectSuspendedCeiling(
        id: 'ceil_1',
        type: SuspendedCeilingType.armstrong,
        polygon: [Offset(0, 0), Offset(4, 0), Offset(4, 4), Offset(0, 4)],
      );

      controller.execute(const PutArchitectCeiling(storeyId: 's0', ceiling: c1));
      expect(controller.project.storeys[0].ceilings.length, 1);
      expect(controller.project.storeys[0].hasCeilingPlan, isTrue);

      controller.execute(
        const CutArchitectContourOpening(
          storeyId: 's0',
          elementId: 'ceil_1',
          polygon: [Offset(1, 1), Offset(2, 1), Offset(2, 2), Offset(1, 2)],
        ),
      );
      expect(controller.project.storeys[0].ceilings.first.holes.length, 1);

      controller.execute(
        const MoveArchitectElements(
          storeyId: 's0',
          elementIds: {'ceil_1'},
          delta: Offset(1, 2),
        ),
      );
      expect(
        controller.project.storeys[0].ceilings.first.polygon.first,
        const Offset(1, 2),
      );

      controller.undo();
      expect(
        controller.project.storeys[0].ceilings.first.polygon.first,
        Offset.zero,
      );

      final (copiedProject, copyResult) = ArchitectStoreyCopyService.copyElements(
        controller.project,
        const StoreyCopyOptions(
          sourceStoreyId: 's0',
          targetStoreyIds: {'s1'},
          elementTypes: {ArchitectStoreyElementType.ceilings},
        ),
      );
      expect(copyResult.totalCopied, 1);
      expect(copiedProject.storeys[1].ceilings.length, 1);
      expect(copiedProject.storeys[1].ceilings.first.id, isNot('ceil_1'));

      final tool = ArchitectElementTool();
      final mirrored = tool
          .mirrorElementById(
            controller.project.storeys[0],
            'ceil_1',
            origin: Offset.zero,
            direction: const Offset(0, 1),
          )
          .$1;
      expect(mirrored.ceilings.first.polygon.any((p) => p.dx < -3.9), isTrue);

      controller.execute(
        const DeleteArchitectCeiling(storeyId: 's0', ceilingId: 'ceil_1'),
      );
      expect(controller.project.storeys[0].ceilings, isEmpty);
    });
  });

  group('Package 3: Section, 3D, and Publication', () {
    ArchitectProject makeFullProject() {
      final now = DateTime(2026, 11, 20);
      return ArchitectProject(
        id: 'p_sec',
        name: 'Section Ceiling',
        createdAt: now,
        updatedAt: now,
        activeStoreyId: 's0',
        storeys: const [
          ArchitectStorey(
            id: 's0',
            name: '±0.00',
            elevation: 0.0,
            height: 3.0,
            hasCeilingPlan: true,
            walls: [
              ArchitectWall(
                id: 'w_left',
                startPoint: Offset(0, -1),
                endPoint: Offset(0, 4),
                thickness: 0.25,
              ),
              ArchitectWall(
                id: 'w_right',
                startPoint: Offset(4, -1),
                endPoint: Offset(4, 4),
                thickness: 0.25,
              ),
            ],
            ceilings: [
              ArchitectSuspendedCeiling(
                id: 'ceil_sec',
                type: SuspendedCeilingType.armstrong,
                polygon: [
                  Offset(0, 0),
                  Offset(4, 0),
                  Offset(4, 3),
                  Offset(0, 3),
                ],
                holes: [
                  [
                    Offset(1.5, 1.0),
                    Offset(2.5, 1.0),
                    Offset(2.5, 2.0),
                    Offset(1.5, 2.0),
                  ],
                ],
                dropFromUpperSlab: 0.30,
                hasInsulation: true,
                insulationThickness: 0.05,
              ),
            ],
          ),
          ArchitectStorey(
            id: 's1',
            name: '+3.00',
            elevation: 3.0,
            height: 2.8,
            slabs: [
              ArchitectSlab(
                id: 'upper_slab',
                polygon: [
                  Offset(-0.5, -1),
                  Offset(4.5, -1),
                  Offset(4.5, 4),
                  Offset(-0.5, 4),
                ],
                thickness: 0.20,
              ),
            ],
          ),
        ],
        sections: const [
          ArchitectSection(
            id: 'sec_1',
            name: 'A-A',
            start: Offset(-1, 1.5),
            end: Offset(5, 1.5),
          ),
        ],
      );
    }

    test('section cuts ceiling at exact elevation, clips walls and skips hole', () {
      final project = makeFullProject();
      final section = ArchitectBuildingSection.build(
        project,
        project.sections.first,
        includeProjection: false,
      );
      final ceilRegions =
          section.regions.where((r) => r.sourceId == 'ceil_sec').toList();
      expect(ceilRegions, isNotEmpty);

      // Upper slab bottom = 3.0 - 0.20 = 2.80; drop = 0.30 => ceiling bottom = 2.50.
      final panel = ceilRegions.first;
      final bounds = panel.path.getBounds();
      expect(bounds.top, closeTo(2.50, 1e-4));
      // Clipped against 0.25 m thick walls centered at x=0 and x=4 (station x=1 and x=5).
      expect(bounds.left, greaterThan(1.10));
      expect(bounds.right, lessThan(4.90));
      // Hole at world x=[1.5, 2.5] -> station [2.5, 3.5] must not contain panel.
      expect(panel.path.contains(const Offset(3.0, 2.505)), isFalse);
      expect(panel.path.contains(const Offset(1.8, 2.505)), isTrue);
    });

    test('3D mesh generates ceiling triangles mapped to ceiling id', () {
      final project = makeFullProject();
      final sources = <dynamic, String>{};
      final mesh = Architect3dBuilder.buildProjectMesh(
        project,
        sources: sources.cast(),
      );
      final ceilTris = mesh.triangles
          .where((t) => sources[t] == 'ceil_sec')
          .toList();
      expect(ceilTris, isNotEmpty);
      final minZ = ceilTris
          .expand((t) => [t.v0.z, t.v1.z, t.v2.z])
          .reduce((a, b) => a < b ? a : b);
      expect(minZ, closeTo(2.50, 1e-4));
    });

    test('publication supports ceilingPlan saved drawing & sceneKey', () {
      final project = makeFullProject();
      final l = AppLocalizationsEn();
      const ceilingDrawing = ArchitectSavedDrawing(
        id: 'ceiling:s0',
        sourceId: 's0',
        kind: ArchitectDrawingKind.plan,
        ceilingPlan: true,
        scale: 100,
      );
      final roundtrip = ArchitectSavedDrawing.fromJson(ceilingDrawing.toJson());
      expect(roundtrip.ceilingPlan, isTrue);
      expect(roundtrip.sourceKey, 'ceiling:s0');
      expect(
        ArchitectSheetLayout.drawingName(roundtrip, l),
        l.architectCeilingPlan,
      );

      final ceilingScene = ArchitectDrawingPublisher.build(
        project,
        roundtrip,
        100,
        l,
      );
      const floorDrawing = ArchitectSavedDrawing(
        id: 'plan:s0',
        sourceId: 's0',
        kind: ArchitectDrawingKind.plan,
        ceilingPlan: false,
        scale: 100,
      );
      final floorScene = ArchitectDrawingPublisher.build(
        project,
        floorDrawing,
        100,
        l,
      );
      expect(
        ceilingScene.operations.any((op) => op.sources.contains('ceil_sec')),
        isTrue,
      );
      expect(
        floorScene.operations.any((op) => op.sources.contains('ceil_sec')),
        isFalse,
      );
    });
  });
}
