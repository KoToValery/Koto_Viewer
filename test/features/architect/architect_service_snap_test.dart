import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/components/definitions/service_components.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_fenestration_style.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_stair_design.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_clearance_badge_layout.dart';
import 'package:kotoview/src/features/architect/rendering/architect_service_snap.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_numeric_keypad.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

void main() {
  group('ArchitectServiceSnap - Risers & Chimneys Snap Tests', () {
    const wall1 = ArchitectWall(
      id: 'w1',
      startPoint: Offset(0, 0),
      endPoint: Offset(6, 0),
      thickness: 0.25,
      height: 2.8,
    );

    const wall2 = ArchitectWall(
      id: 'w2',
      startPoint: Offset(6, 0),
      endPoint: Offset(6, 6),
      thickness: 0.25,
      height: 2.8,
    );

    final project = ArchitectProject(
      id: 'test_prj',
      name: 'Test Project',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      storeys: [
        ArchitectStorey(
          id: 's1',
          name: 'Ground Floor',
          walls: [wall1, wall2],
        ),
      ],
      activeStoreyId: 's1',
    );

    test('Snaps flush to interior face of horizontal wall and aligns angle', () {
      final snap = ArchitectServiceSnap.resolve(
        raw: const Offset(3.0, 0.2),
        project: project,
        width: 0.40,
        depth: 0.40,
        tolerance: 0.5,
      );

      expect(snap.point.dx, closeTo(3.0, 0.05));
      expect(snap.point.dy, closeTo(0.125, 0.01));
      expect(snap.angleDeg, isNotNull);
      expect(snap.angleDeg! % 180, closeTo(0.0, 1.0));
      expect(snap.snapLabel, contains('Wall face'));
    });

    test('Snaps flush to exterior face of horizontal wall', () {
      final snap = ArchitectServiceSnap.resolve(
        raw: const Offset(3.0, -0.2),
        project: project,
        width: 0.40,
        depth: 0.40,
        tolerance: 0.5,
      );

      expect(snap.point.dx, closeTo(3.0, 0.05));
      expect(snap.point.dy, closeTo(-0.125, 0.01));
      expect(snap.snapLabel, contains('Wall face'));
    });

    test('Snaps to internal wall corner where w1 and w2 meet', () {
      final snap = ArchitectServiceSnap.resolve(
        raw: const Offset(5.7, 0.3),
        project: project,
        width: 0.40,
        depth: 0.40,
        tolerance: 0.5,
      );

      expect(snap.point.dx, closeTo(5.675, 0.05));
      expect(snap.point.dy, closeTo(0.125, 0.05));
      expect(snap.snapLabel, contains('Wall corner'));
    });

    test('Snaps flush next to door opening jamb', () {
      final wallWithDoor = wall1.addDoor(
        const ArchitectDoor(
          id: 'd1',
          wallId: 'w1',
          uuid: 'door_uuid',
          offsetRatio: 0.5,
          width: 0.90,
        ),
      );

      final projectWithDoor = ArchitectProject(
        id: 'test_prj',
        name: 'Test Project',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        storeys: [
          ArchitectStorey(
            id: 's1',
            name: 'Ground Floor',
            walls: [wallWithDoor],
          ),
        ],
        activeStoreyId: 's1',
      );

      final snap = ArchitectServiceSnap.resolve(
        raw: const Offset(3.6, 0.25),
        project: projectWithDoor,
        width: 0.40,
        depth: 0.40,
        tolerance: 0.4,
      );

      expect(snap.point.dx, closeTo(3.65, 0.05));
      expect(snap.snapLabel, contains('Opening jamb'));
    });

    test('Footprint calculations on ServiceComponentDefinition return accurate metrics', () {
      final def = ServiceComponentDefinition(ServiceComponentKind.chimney);

      final (w, d) = def.footprint({'width': 0.50, 'depth': 0.50});
      expect(w, 0.50);
      expect(d, 0.50);

      final (dw, dd) = def.footprint();
      expect(dw, 0.36); // Default Schiedel chimney footprint is 0.36 x 0.36
      expect(dd, 0.36);
    });
  });

  group('Architect Development Tasks Verification', () {
    test('Task 1.1: Snapped service component sits flush on wall face with zero gap', () {
      const wall1 = ArchitectWall(
        id: 'w1',
        startPoint: Offset(0, 0),
        endPoint: Offset(6, 0),
        thickness: 0.25,
        height: 2.8,
      );
      final project = ArchitectProject(
        id: 'p_flush',
        name: 'Flush Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        storeys: const [
          ArchitectStorey(id: 's1', name: '0', walls: [wall1]),
        ],
        activeStoreyId: 's1',
      );
      final snap = ArchitectServiceSnap.resolve(
        raw: const Offset(3.0, 0.35),
        project: project,
        width: 0.40,
        depth: 0.40,
      );
      final instance = ArchitectComponentInstance(
        id: 'comp_1',
        definitionId: 'chimney_1flue',
        position: snap.point,
        rotation: (snap.angleDeg ?? 0.0) * math.pi / 180.0,
        parameters: const {'width': 0.40, 'depth': 0.40},
      );
      final corners = instance.worldPolygonCorners;
      final minY = corners.map((c) => c.dy).reduce(math.min);
      final maxY = corners.map((c) => c.dy).reduce(math.max);
      expect(minY, closeTo(0.125, 1e-6));
      expect(maxY, closeTo(0.525, 1e-6));
    });

    test('Task 2.1 & 2.2: Window sill defaults to 0.90m and keypad first-digit overwrites', () {
      final win = ArchitectWindow(
        id: 'w1',
        uuid: 'u1',
        wallId: 'wall1',
        offsetRatio: 0.5,
      );
      expect(win.sillHeight, closeTo(0.90, 1e-6));
      final style = ArchitectFenestrationStyle(
        id: 'st1',
        name: 'Default',
        rootSubdivision: const FenestrationSubdivision(
          id: 'root',
          pane: FenestrationPane(id: 'p1', paneType: PaneType.tiltAndTurn),
        ),
      );
      expect(style.defaultSillHeight, closeTo(0.90, 1e-6));
      expect(BimNumericKeypad.edit(null, '5', decimals: 2), '5');
      expect(BimNumericKeypad.edit('5', '2', decimals: 2), '52');
    });

    test('Task 2.3: Half-turn stair totalWidth controls wellGap and outer span', () {
      const design = ArchitectStairDesign(
        shape: StairShape.halfTurn,
        winderSteps: false,
        totalWidth: 2.20,
      );
      expect(design.wellGap(1.0), closeTo(0.20, 1e-6));
      expect(design.effectiveTotalWidth(1.0), closeTo(2.20, 1e-6));
      final plan = ArchitectStairPlan.build(
        start: Offset.zero,
        direction: const Offset(1, 0),
        width: 1.0,
        design: design,
      );
      expect(plan.bounds.height, closeTo(2.20, 1e-4));
    });

    test('Task 3.2: Interior plaster is stripped in planWall but preserved in sections/3D build', () {
      const composition = ArchitectWallType(
        id: 'comp_plaster',
        name: 'Plastered Brick',
        usage: WallUsage.interior,
        totalThickness: 0.28,
        location: ArchitectWallLocation.interior,
        layers: [
          ArchitectMaterialLayer(
            id: 'p1',
            material: ArchitectMaterial.plaster,
            role: ArchitectLayerRole.finish,
            thickness: 0.015,
          ),
          ArchitectMaterialLayer(
            id: 'b1',
            material: ArchitectMaterial.brick,
            role: ArchitectLayerRole.core,
            thickness: 0.25,
          ),
          ArchitectMaterialLayer(
            id: 'p2',
            material: ArchitectMaterial.plaster,
            role: ArchitectLayerRole.finish,
            thickness: 0.015,
          ),
        ],
      );
      final wallWithPlaster = ArchitectWall(
        id: 'w_p',
        startPoint: Offset.zero,
        endPoint: const Offset(4, 0),
        wallTypeId: composition.id,
        layers: composition.layers,
        thickness: composition.totalThickness,
        location: composition.resolvedLocation,
      );
      final planW = ArchitectWallGeometry.planWall(wallWithPlaster);
      expect(planW.thickness, closeTo(0.25, 1e-6));
      expect(planW.layers.length, 1);

      final modelLayers = ArchitectWallLayers.build(
        [wallWithPlaster],
        const [composition],
      );
      expect(
        modelLayers.materials.any(
          (r) => r.layer.material == ArchitectMaterial.plaster,
        ),
        isTrue,
      );
    });

    test('Task 3.3: Clearance badges keep constant screen scale and text caps on zoom', () {
      const rect = Rect.fromLTWH(0, 0, 1000, 1000);
      expect(
        ArchitectClearanceBadgeLayout.openingSize(500.0, rect),
        ArchitectClearanceBadgeLayout.openingSize(
          ArchitectClearanceBadgeLayout.openingReferenceScale,
          rect,
        ),
      );
      const canvasScope = ArchitectTextScope(
        ArchitectDocument(),
        'plan',
        100,
        500.0,
        publication: false,
      );
      const pubScope = ArchitectTextScope(
        ArchitectDocument(),
        'plan',
        100,
        500.0,
        publication: true,
      );
      expect(
        canvasScope.height('dim_1', ArchitectAnnotationRole.dimension),
        lessThan(pubScope.height('dim_1', ArchitectAnnotationRole.dimension)),
      );
    });

    test('Task 4.1 & 4.2: Publisher respects per-drawing layer and underlay toggles', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final dxf = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: const {},
        entities: const [
          DxfLine(layer: '0', p1: Offset.zero, p2: Offset(4, 2)),
        ],
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 4, 2),
        entityStats: const {},
      );
      final project = ArchitectProject(
        id: 'p_sheet',
        name: 'Sheet Project',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        storeys: const [
          ArchitectStorey(
            id: 's1',
            name: 'Ground',
            walls: [
              ArchitectWall(
                id: 'w1',
                startPoint: Offset.zero,
                endPoint: Offset(4, 0),
                thickness: 0.25,
              ),
            ],
          ),
        ],
        activeStoreyId: 's1',
      );
      const drawingAll = ArchitectSavedDrawing(
        id: 'd_all',
        sourceId: 's1',
        kind: ArchitectDrawingKind.plan,
        name: 'All Visible',
        visibility: {
          'layer:${ArchitectLayer.wallLayerId}': true,
          'underlay': true,
        },
      );
      const drawingNoWall = ArchitectSavedDrawing(
        id: 'd_no_wall',
        sourceId: 's1',
        kind: ArchitectDrawingKind.plan,
        name: 'Wall Hidden',
        visibility: {
          'layer:${ArchitectLayer.wallLayerId}': false,
          'underlay': true,
        },
      );
      const drawingNoUnderlay = ArchitectSavedDrawing(
        id: 'd_no_underlay',
        sourceId: 's1',
        kind: ArchitectDrawingKind.plan,
        name: 'Underlay Hidden',
        visibility: {
          'layer:${ArchitectLayer.wallLayerId}': true,
          'underlay': false,
        },
      );
      final sources = ArchitectPublicationSources(underlays: {'s1': dxf});
      final sceneAll = ArchitectDrawingPublisher.build(
        project,
        drawingAll,
        100,
        l10n,
        sources: sources,
      );
      final sceneNoWall = ArchitectDrawingPublisher.build(
        project,
        drawingNoWall,
        100,
        l10n,
        sources: sources,
      );
      final sceneNoUnderlay = ArchitectDrawingPublisher.build(
        project,
        drawingNoUnderlay,
        100,
        l10n,
        sources: sources,
      );
      expect(sceneAll.operations, isNotEmpty);
      expect(sceneNoWall.operations.length, lessThan(sceneAll.operations.length));
      expect(
        sceneNoUnderlay.operations.length,
        lessThan(sceneAll.operations.length),
      );
    });
  });
}
