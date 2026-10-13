import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_fenestration_style.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/fenestration_3d_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/services/fenestration_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArchitectFenestrationStyle tests', () {
    test('Standard catalog contains expected starter models', () {
      final catalog = ArchitectFenestrationStyle.standardCatalog();
      expect(catalog.isNotEmpty, isTrue);

      final doubleWin = catalog.firstWhere((s) => s.id == 'win_double_casement');
      expect(doubleWin.kind, equals(FenestrationKind.window));
      expect(doubleWin.frameDepth, closeTo(0.07, 1e-4)); // 70 mm 5-chamber
      expect(doubleWin.glazingThickness, closeTo(0.024, 1e-4)); // 24 mm double glazing
      expect(doubleWin.defaultWidth, closeTo(1.40, 1e-4));
      expect(doubleWin.defaultHeight, closeTo(1.40, 1e-4));

      final casingWin = catalog.firstWhere((s) => s.id == 'win_double_with_casing');
      expect(casingWin.hasCasing, isTrue);
      expect(casingWin.casingWidth, closeTo(0.10, 1e-4)); // 10 cm width
      expect(casingWin.casingProjection, closeTo(0.03, 1e-4)); // 3 cm projection
    });

    test('JSON serialization & deserialization roundtrip', () {
      final original = ArchitectFenestrationStyle(
        id: 'test_custom_win_01',
        name: 'Потребителски прозорец',
        kind: FenestrationKind.window,
        defaultWidth: 1.60,
        defaultHeight: 1.50,
        defaultSillHeight: 0.90,
        hasCasing: true,
        casingWidth: 0.12,
        casingProjection: 0.04,
        rootSubdivision: const FenestrationSubdivision(
          id: 'root',
          isSplit: true,
          isVertical: true,
          ratios: [0.5, 0.5],
          children: [
            FenestrationSubdivision(
              id: 'c1',
              pane: FenestrationPane(
                id: 'p1',
                paneType: PaneType.casementLeft,
              ),
            ),
            FenestrationSubdivision(
              id: 'c2',
              pane: FenestrationPane(
                id: 'p2',
                paneType: PaneType.tiltAndTurn,
              ),
            ),
          ],
        ),
      );

      final json = original.toJson();
      final restored = ArchitectFenestrationStyle.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.defaultWidth, equals(original.defaultWidth));
      expect(restored.hasCasing, isTrue);
      expect(restored.casingWidth, equals(0.12));
      expect(restored.casingProjection, equals(0.04));
      expect(restored.rootSubdivision.isSplit, isTrue);
      expect(restored.rootSubdivision.children.length, equals(2));
      expect(restored.rootSubdivision.children[0].pane?.paneType,
          equals(PaneType.casementLeft));
    });

    test('Subdivision tree split, updatePane, and collapse operations', () {
      var root = const FenestrationSubdivision(
        id: 'root',
        pane: FenestrationPane(id: 'single_pane', paneType: PaneType.fixedGlazing),
      );

      expect(root.isSplit, isFalse);
      expect(root.collectPanes().length, equals(1));

      // Split vertically into 2
      root = root.split(vertical: true, count: 2);
      expect(root.isSplit, isTrue);
      expect(root.children.length, equals(2));
      expect(root.collectPanes().length, equals(2));

      // Update pane 0 to casementLeft
      final p0 = root.children[0].pane!;
      root = root.updatePane(p0.copyWith(paneType: PaneType.casementLeft));
      expect(root.findPane(p0.id)?.paneType, equals(PaneType.casementLeft));

      // Collapse back to 1
      root = root.collapse();
      expect(root.isSplit, isFalse);
      expect(root.collectPanes().length, equals(1));
    });
  });

  group('Fenestration3dBuilder 3D geometry tests', () {
    test('Builds 3D mesh with 5-chamber frame, double glass, and exterior casing', () {
      final style = ArchitectFenestrationStyle.standardCatalog().firstWhere(
        (s) => s.id == 'win_double_with_casing',
      );

      const wallStart = Offset(0, 0);
      const wallEnd = Offset(4.0, 0); // Along X axis
      const wallThickness = 0.37;     // 25cm brick + 12cm EPS
      const coreThickness = 0.25;
      const insulationThickness = 0.12;
      const exteriorSign = 1.0; // Normal is (0, 1), so exterior face is at Y = +0.185
      const offsetRatio = 0.5; // Center at X = 2.0
      const width = 1.40;
      const height = 1.40;
      const sillHeight = 0.85;
      const storeyElevation = 0.0;

      final tris = Fenestration3dBuilder.buildOpening3D(
        style: style,
        wallStart: wallStart,
        wallEnd: wallEnd,
        wallThickness: wallThickness,
        coreThickness: coreThickness,
        insulationThickness: insulationThickness,
        exteriorSign: exteriorSign,
        offsetRatio: offsetRatio,
        width: width,
        height: height,
        sillHeight: sillHeight,
        storeyElevation: storeyElevation,
      );

      expect(tris.isNotEmpty, isTrue);

      // Verify Casing Geometry:
      // Exterior face is at Y = +0.185 (core center 0 + wallThickness/2 0.185).
      // Casing projection is 0.03 m.
      // Therefore casing front triangles must reach Y = 0.185 + 0.03 = 0.215!
      final casingFrontTris = tris.where((t) =>
          (t.v0.y - 0.215).abs() < 1e-3 ||
          (t.v1.y - 0.215).abs() < 1e-3 ||
          (t.v2.y - 0.215).abs() < 1e-3).toList();
      expect(casingFrontTris.isNotEmpty, isTrue,
          reason: 'Casing must project in front of exterior wall insulation by 3 cm');

      // Crucial requirement: casing does NOT cut inside wall masonry core (Y < 0.125)
      // The casing back surface is at the exterior face plane Y = 0.185.
      // Frame is in the core center at Y in [-0.035, +0.035].
      final casingTris = tris.where((t) => t.color == style.casingColor).toList();
      expect(casingTris.isNotEmpty, isTrue);
      for (final t in casingTris) {
        expect(t.v0.y, greaterThanOrEqualTo(0.184),
            reason: 'Casing must sit on exterior wall surface without intersecting core');
        expect(t.v1.y, greaterThanOrEqualTo(0.184));
        expect(t.v2.y, greaterThanOrEqualTo(0.184));
      }

      // Verify Frame is centered in masonry core:
      // Wall core center is at coreCenterShift = -0.06 m.
      // 5-chamber frame depth = 70 mm (halfFDepth = 0.035 m) -> Y range [-0.095, -0.025]
      final frameTris = tris.where((t) => t.color == Fenestration3dBuilder.frameColor).toList();
      expect(frameTris.isNotEmpty, isTrue);
      final minFrameY = frameTris
          .map((t) => [t.v0.y, t.v1.y, t.v2.y])
          .expand((y) => y)
          .reduce((a, b) => a < b ? a : b);
      final maxFrameY = frameTris
          .map((t) => [t.v0.y, t.v1.y, t.v2.y])
          .expand((y) => y)
          .reduce((a, b) => a > b ? a : b);
      expect(minFrameY, closeTo(-0.095, 1e-3));
      expect(maxFrameY, closeTo(-0.025, 1e-3));
    });
  });

  group('2D Plan & Wall Integration tests', () {
    test('ArchitectWindow and ArchitectDoor paintPlan2D executes without exception', () {
      final style = ArchitectFenestrationStyle.standardCatalog().first;
      final window = ArchitectWindow(
        id: 'win_test',
        wallId: 'wall_01',
        offsetRatio: 0.5,
        width: 1.20,
        height: 1.40,
        uuid: 'UUID_WIN_TEST',
        styleId: style.id,
        style: style,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Verify paint2D with style
      window.paint2D(
        canvas: canvas,
        wallStart: const Offset(0, 0),
        wallEnd: const Offset(4.0, 0),
        wallThickness: 0.37,
        coreThickness: 0.25,
        insulationThickness: 0.12,
        exteriorSign: 1.0,
        zoomScale: 50.0,
        isSelected: true,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('ArchitectWall.build3D seamlessly delegates to hosted opening styles', () {
      final style = ArchitectFenestrationStyle.standardCatalog().firstWhere(
        (s) => s.id == 'win_double_with_casing',
      );

      final wall = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5.0, 0),
        thickness: 0.37,
        height: 2.80,
        windows: [
          ArchitectWindow(
            id: 'w_win',
            wallId: 'w1',
            offsetRatio: 0.5,
            width: 1.40,
            height: 1.40,
            sillHeight: 0.85,
            uuid: 'UUID_W1',
            styleId: style.id,
            style: style,
          ),
        ],
      );

      final tris = wall.build3D(storeyElevation: 0.0);
      expect(tris.isNotEmpty, isTrue);

      // Verify that casing triangles exist in the combined wall mesh
      final casingTris = tris.where((t) => t.color == style.casingColor).toList();
      expect(casingTris.isNotEmpty, isTrue);
    });
  });

  group('FenestrationLibraryService tests', () {
    test('Library service retrieves default catalog and manages active selections', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FenestrationLibraryService.instance;
      await service.init();

      final allStyles = service.getAllStyles();
      expect(allStyles.length, greaterThanOrEqualTo(7));

      final windows = service.getWindowStyles();
      final doors = service.getDoorStyles();
      expect(windows.isNotEmpty, isTrue);
      expect(doors.isNotEmpty, isTrue);

      expect(service.activeWindowStyle.kind, equals(FenestrationKind.window));
      expect(service.activeDoorStyle.kind, equals(FenestrationKind.door));

      // Save custom style
      final custom = ArchitectFenestrationStyle(
        id: 'user_created_style_99',
        name: 'Моят прозорец 99',
        kind: FenestrationKind.window,
        defaultWidth: 1.50,
        defaultHeight: 1.50,
        rootSubdivision: const FenestrationSubdivision(id: 'root'),
      );

      await service.saveStyle(custom);
      expect(service.getStyleById('user_created_style_99'), isNotNull);
      expect(service.activeWindowStyle.id, equals('user_created_style_99'));

      // Clean up
      await service.deleteStyle('user_created_style_99');
      expect(service.getStyleById('user_created_style_99'), isNull);
    });
  });
}
