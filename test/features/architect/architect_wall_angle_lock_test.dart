import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_endpoint_snap.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_angle_control.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_grid_axis.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

import 'architect_editing_test.dart' as editing;
import 'architect_selection_move_test.dart' as move_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectProject snapProject({
  List<ArchitectWall> walls = const [],
  List<ArchitectCadPrimitive> cad = const [],
  List<BimGridAxis> axes = const [],
}) {
  final model = editing.seeded(
    ArchitectStorey(id: 's', name: '', walls: walls, cadPrimitives: cad),
    axes: axes,
  );
  final project = model.project;
  model.dispose();
  return project;
}

void main() {
  for (final degrees in [0.0, 31.7, 44.8, 90.0, 181.3]) {
    for (final atStart in [false, true]) {
      test('Locked endpoint preserves $degrees degrees (start=$atStart)', () {
        final u = Offset(
          math.cos(degrees * math.pi / 180),
          math.sin(degrees * math.pi / 180),
        );
        final n = Offset(-u.dy, u.dx);
        final wall = editing.wall(
          'w',
          const Offset(1, 2),
          const Offset(1, 2) + u * 4,
        );
        final origin = atStart ? wall.startPoint : wall.endPoint;
        final target = origin + u * (atStart ? -1 : 1);
        final project = snapProject(
          cad: [
            ArchitectCadPrimitive(
              id: 'distractor',
              type: CadPrimitiveType.line,
              startPoint: target + n * .03,
              endPoint: target + n,
            ),
          ],
        );
        final result = ArchitectWallEndpointSnap.resolve(
          wall: wall,
          atStart: atStart,
          raw: target + n * .03,
          snapProject: project,
          scale: 100,
          angleLocked: true,
        );
        expect((result.point - target).distance, lessThan(1e-9));
        expect(result.magneticGuides, isNotEmpty);
      });
    }
  }

  for (final delta in [-.03, .03]) {
    test(
      'Unlock permits a $delta m sideways correction inside angular capture',
      () {
        final wall = editing.wall('w', Offset.zero, const Offset(4, 0));
        final result = ArchitectWallEndpointSnap.resolve(
          wall: wall,
          atStart: false,
          raw: Offset(4, delta),
          snapProject: snapProject(),
          scale: 100,
          angleLocked: false,
        );
        expect(result.point, Offset(4, delta));
        expect(result.isSnapped, isFalse);
      },
    );
  }

  test(
    'Locked endpoint snaps to an oblique crossing without changing direction',
    () {
      final wall = editing.wall('w', Offset.zero, const Offset(4, 0));
      final result = ArchitectWallEndpointSnap.resolve(
        wall: wall,
        atStart: false,
        raw: const Offset(5.94, .08),
        snapProject: snapProject(
          cad: const [
            ArchitectCadPrimitive(
              id: 'cross',
              type: CadPrimitiveType.line,
              startPoint: Offset(5, -1),
              endPoint: Offset(8, 2),
            ),
          ],
        ),
        scale: 100,
        angleLocked: true,
      );
      expect(result.point, const Offset(6, 0));
      expect(result.snapLabel, 'Intersection');
    },
  );

  test('Grid extensions and CAD underlay use true constrained crossings', () {
    final wall = editing.wall('w', Offset.zero, const Offset(4, 0));
    final axes = snapProject(
      axes: const [
        BimGridAxis(
          id: 'axis',
          name: 'A',
          start: Offset(6, 2),
          end: Offset(6, 3),
        ),
      ],
    );
    final axis = ArchitectWallEndpointSnap.resolve(
      wall: wall,
      atStart: false,
      raw: const Offset(6.08, .04),
      snapProject: axes,
      scale: 100,
      angleLocked: true,
    );
    expect(axis.point, const Offset(6, 0));
    expect(axis.snapLabel, 'Axis A');
    final doc = DxfDocument(
      entities: [
        DxfLine(layer: 'L', p1: const Offset(5, -1), p2: const Offset(7, 1)),
      ],
      layers: {},
      blocks: {},
      bounds: const Rect.fromLTWH(5, -1, 2, 2),
      entityStats: {},
      headerVars: {},
    );
    final cad = ArchitectWallEndpointSnap.resolve(
      wall: wall,
      atStart: false,
      raw: const Offset(6.08, .04),
      snapProject: snapProject(),
      scale: 100,
      angleLocked: true,
      underlay: doc,
    );
    expect(cad.point, const Offset(6, 0));
    final hidden = ArchitectWallEndpointSnap.resolve(
      wall: wall,
      atStart: false,
      raw: const Offset(6.08, .04),
      snapProject: snapProject(),
      scale: 100,
      angleLocked: true,
      underlay: doc,
      visibility: const {'L': false},
    );
    expect(hidden.point, const Offset(6.08, 0));
  });

  test('Angle constraint is independent of the global magnet', () {
    final wall = editing.wall('w', Offset.zero, const Offset(4, 0));
    for (final locked in [false, true]) {
      final result = ArchitectWallEndpointSnap.resolve(
        wall: wall,
        atStart: false,
        raw: const Offset(5, .03),
        snapProject: snapProject(),
        scale: 100,
        angleLocked: locked,
        magnetic: false,
      );
      expect(result.point, Offset(5, locked ? 0 : .03));
    }
  });

  for (final language in ['bg', 'en']) {
    testWidgets('Phone lock, fine correction and whole-wall move ($language)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final wall = editing.wall('w', const Offset(-2, 0), const Offset(2, 0));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [wall]),
      );
      addTearDown(model.dispose);
      if (const bool.fromEnvironment('CAPTURE_WALL_ANGLE')) {
        await tester.runAsync(() async {
          await (FontLoader('Roboto')..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
                  ),
                ),
              ))
              .load();
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('wall-angle-phone-preview'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await editing.hold(tester, Offset.zero);
      expect(tester.takeException(), isNull, reason: 'Initial wall selection');
      final lock = find.byKey(const ValueKey('architect-wall-angle-lock'));
      expect(lock, findsOneWidget);
      final rect = tester.getRect(lock);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.height, greaterThanOrEqualTo(44));
      if (const bool.fromEnvironment('CAPTURE_WALL_ANGLE')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('wall-angle-phone-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'scratch/architect_wall_angle_$language.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(
        tester
            .widget<ArchitectWallAngleControl>(
              find.byType(ArchitectWallAngleControl),
            )
            .locked,
        isTrue,
      );
      final oldScale = workspace.camera(tester).scale;
      final oldOffset = workspace.camera(tester).translation;
      final g = await tester.startGesture(
        workspace.screen(tester, wall.endPoint),
      );
      await tester.pump();
      await g.moveTo(workspace.screen(tester, const Offset(2.4, .06)));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      // Direct handle edits use the existing one-step commit path.
      expect(
        model.project.activeStorey.walls.single.endPoint.dx,
        closeTo(2.4, .002),
      );
      expect(model.project.activeStorey.walls.single.endPoint.dy, 0);
      expect(workspace.camera(tester).scale, oldScale);
      expect(workspace.camera(tester).translation, oldOffset);
      expect(model.undoCount, 1);
      expect(tester.takeException(), isNull, reason: 'Locked drag');
      await tester.tap(find.byKey(const ValueKey('architect-undo')));
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls.single.toJson(), wall.toJson());
      await editing.hold(tester, Offset.zero);
      await tester.tap(lock);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ArchitectWallAngleControl>(
              find.byType(ArchitectWallAngleControl),
            )
            .locked,
        isFalse,
      );
      expect(model.undoCount, 0);
      final fine = await tester.startGesture(
        workspace.screen(tester, wall.endPoint),
      );
      await tester.pump();
      // Explicit unlock permits a small nudge directly, with no wide excursion.
      await fine.moveTo(workspace.screen(tester, const Offset(2, .03)));
      await tester.pump();
      await fine.up();
      await tester.pumpAndSettle();
      final corrected = model.project.activeStorey.walls.single;
      expect(corrected.startPoint, wall.startPoint);
      expect(corrected.endPoint.dx, closeTo(2, .002));
      expect(corrected.endPoint.dy, closeTo(.03, .002));
      expect(model.undoCount, 1);
      expect(tester.takeException(), isNull, reason: 'Fine adjustment');
      // Relocking uses the corrected direction, never the original one.
      await tester.tap(lock);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ArchitectWallAngleControl>(
              find.byType(ArchitectWallAngleControl),
            )
            .locked,
        isTrue,
      );
      await move_ui.chooseMove(tester, 'offset');
      expect(tester.takeException(), isNull, reason: 'Move offset dialog');
      await tester.enterText(
        find.byKey(const ValueKey('architect-axis-value')),
        '.03',
      );
      await tester.tap(find.byKey(const ValueKey('architect-axis-value-save')));
      await tester.pumpAndSettle();
      await editing.acceptGeometryCommand(tester);
      final moved = model.project.activeStorey.walls.single;
      expect(
        (moved.startPoint - corrected.startPoint - corrected.normalVector * .03)
            .distance,
        lessThan(.002),
      );
      expect(
        (moved.endPoint - corrected.endPoint - corrected.normalVector * .03)
            .distance,
        lessThan(.002),
      );
      expect(model.undoCount, 2);
      await move_ui.chooseMove(tester, 'offset');
      await tester.enterText(
        find.byKey(const ValueKey('architect-axis-value')),
        '-.03',
      );
      await tester.tap(find.byKey(const ValueKey('architect-axis-value-save')));
      await tester.pumpAndSettle();
      await editing.acceptGeometryCommand(tester);
      final returned = model.project.activeStorey.walls.single;
      expect(
        (returned.startPoint - corrected.startPoint).distance,
        lessThan(.002),
      );
      expect((returned.endPoint - corrected.endPoint).distance, lessThan(.002));
      expect(model.undoCount, 3);
      expect(tester.takeException(), isNull);
    });
  }
}
