import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_roof.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_snap.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_pitch_editing.dart';
import 'package:kotoview/src/features/architect/widgets/architect_projection_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_pitch_editor.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'architect_projection_snap_test.dart' as fixture;

ArchitectRoofPitchPainter pitchPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('roof-pitch-preview')),
            )
            .painter!
        as ArchitectRoofPitchPainter;

Future<(ArchitectCommandController, BimViewportController)> open(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = ArchitectCommandController(
    fixture.roofSnapProject(group: 'gable'),
  );
  final camera = BimViewportController()
    ..resize(const Size(390, 844))
    ..fit(const Rect.fromLTRB(-1, -8, 11, 1));
  addTearDown(controller.dispose);
  addTearDown(camera.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AnimatedBuilder(
          animation: Listenable.merge([controller, camera]),
          builder: (_, _) {
            final geometry = ArchitectBuildingSection.build(
              controller.project,
              fixture.roofSnapCut,
            );
            return ArchitectProjectionEditor(
              controller: controller,
              paths: geometry.elementPaths,
              roofProfiles: geometry.roofProfiles,
              origin: fixture.roofSnapCut.start,
              right: fixture.roofSnapCut.axis,
              elevation: false,
              scale: camera.scale,
              toView: (p) {
                final m = camera.toModel(p);
                return Offset(m.dx, -m.dy);
              },
              toScreen: (p) => camera.toScreen(Offset(p.dx, -p.dy)),
              onNavigate: (delta, factor, focal) => camera.navigate(
                previousFocal: focal - delta,
                focal: focal,
                scaleFactor: factor,
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final geometry = ArchitectBuildingSection.build(
    controller.project,
    fixture.roofSnapCut,
  );
  final point = geometry.elementPaths['right']!.getBounds().center;
  await tester.tapAt(camera.toScreen(Offset(point.dx, -point.dy)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('projection-roof-pitch')));
  await tester.pumpAndSettle();
  return (controller, camera);
}

void main() {
  test(
    'Section pitch snap follows the true folded surface rather than its endpoint chord',
    () {
      final original = fixture.roofSnapProject();
      final roofs = original.activeStorey.roofs;
      final neighbour = roofs.first.copyWith(
        isMansard: true,
        slopeDegrees: 45,
        upperSlopeDegrees: 15,
        breakDistance: 2,
      );
      final project = original.updateActiveStorey(
        original.activeStorey.copyWith(roofs: [neighbour, roofs.last]),
      );
      final data = ArchitectBuildingSection.build(project, fixture.roofSnapCut);
      final snap = ArchitectProjectionSnap(
        project,
        data.elementPaths,
        'right',
        roofProfiles: data.roofProfiles,
        sectionOrigin: fixture.roofSnapCut.start,
        sectionRight: fixture.roofSnapCut.axis,
      );
      final z = neighbour.topElevationAt(const Offset(2, 2));
      final result = snap.resolvePitchPoint(Offset(3, z + .02), .05);
      expect(result.contact!.dy, closeTo(z, 1e-8));
      expect(snap.resolvePitchPoint(Offset(3, z + .08), .05).contact, isNull);
    },
  );
  test(
    'Pitch snap targets the exterior of a neighbouring plane in the same roof group',
    () {
      final project = fixture.roofSnapProject(group: 'gable');
      final data = ArchitectBuildingSection.build(project, fixture.roofSnapCut);
      final snap = ArchitectProjectionSnap(
        project,
        data.elementPaths,
        'right',
        roofProfiles: data.roofProfiles,
      );
      final top = project.activeStorey.roofs.first.topElevationAt(
        const Offset(4, 2),
      );
      final result = snap.resolvePitchPoint(Offset(5, top + .04), .1);
      expect(result.contact!.dx, closeTo(5, 1e-8));
      expect(result.contact!.dy, closeTo(top, 1e-5));
      expect(result.delta.dx, 0);
      expect(result.guide, isNotNull);
      expect(snap.resolvePitchPoint(Offset(5, top + .2), .01).contact, isNull);
    },
  );

  test(
    'Pitch snapping cannot select the moving roof or extrapolate past a neighbouring roof',
    () {
      final project = fixture.roofSnapProject();
      final data = ArchitectBuildingSection.build(project, fixture.roofSnapCut);
      final source = data.elementPaths['right']!;
      final snap = ArchitectProjectionSnap(
        project,
        {'right': source},
        'right',
        roofProfiles: data.roofProfiles,
      );
      expect(
        snap.resolvePitchPoint(source.getBounds().topCenter, .5).contact,
        isNull,
      );
      final all = ArchitectProjectionSnap(
        project,
        data.elementPaths,
        'right',
        roofProfiles: data.roofProfiles,
      );
      expect(all.resolvePitchPoint(const Offset(5.1, 5), .5).contact, isNull);
    },
  );

  test(
    'Folded roof pitch reaches the requested top surface while preserving its fixed axis',
    () {
      final roof = ArchitectRoofPlane(
        id: 'r',
        storeyId: 's',
        points: const [Offset(0, 0), Offset(4, 0), Offset(4, 5), Offset(0, 5)],
        slopeDegrees: 40,
        isMansard: true,
        upperSlopeDegrees: 20,
        breakDistance: 2,
      );
      for (final axis in [const Offset(2, 0), const Offset(2, 3)]) {
        const control = Offset(2, 5);
        final target = roof.topElevationAt(control) + .2;
        final edited = ArchitectRoofPitchEditing.rotate(
          roof,
          pivot: axis,
          control: control,
          targetTopElevation: target,
        );
        expect(
          edited.topElevationAt(axis),
          closeTo(roof.topElevationAt(axis), 1e-8),
        );
        expect(edited.topElevationAt(control), closeTo(target, 1e-8));
        expect(edited.points, roof.points);
      }
    },
  );

  testWidgets(
    'Pitch editing keeps mouse zoom and two-finger zoom without model edits',
    (tester) async {
      final (controller, camera) = await open(tester);
      final before = controller.project.toJson();
      final initial = camera.scale;
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(180, 400),
          scrollDelta: Offset(0, -100),
        ),
      );
      await tester.pumpAndSettle();
      expect(camera.scale, greaterThan(initial));
      final afterWheel = camera.scale;
      final left = await tester.startGesture(
        const Offset(120, 470),
        pointer: 21,
      );
      final right = await tester.startGesture(
        const Offset(260, 470),
        pointer: 22,
      );
      await left.moveTo(const Offset(80, 470));
      await right.moveTo(const Offset(300, 470));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      expect(camera.scale, greaterThan(afterWheel));
      expect(controller.project.toJson(), before);
      expect(controller.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A second finger cancels the tentative pitch drag and only navigates',
    (tester) async {
      final (controller, _) = await open(tester);
      final initial = pitchPainter(tester);
      final finger = await tester.startGesture(initial.control, pointer: 31);
      await finger.moveBy(const Offset(0, -35));
      await tester.pump();
      final other = await tester.startGesture(
        const Offset(320, 550),
        pointer: 32,
      );
      await finger.moveBy(const Offset(-20, 0));
      await other.moveBy(const Offset(20, 0));
      await tester.pump();
      await finger.up();
      await other.up();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('roof-pitch-confirm')));
      await tester.pumpAndSettle();
      expect(controller.project.activeStorey.roofs.last.slopeDegrees, 25);
      expect(tester.takeException(), isNull);
    },
  );

  for (final snapEnabled in [true, false]) {
    testWidgets(
      'Pitch control ${snapEnabled ? 'snaps' : 'moves freely'} and saves one exact edit with Undo',
      (tester) async {
        final (controller, camera) = await open(tester);
        final before = controller.project;
        final source = before.activeStorey.roofs.last;
        final target = before.activeStorey.roofs.first.topElevationAt(
          const Offset(4, 2),
        );
        if (!snapEnabled) {
          await tester.tap(find.byKey(const ValueKey('roof-pitch-snap')));
          await tester.pump();
        }
        final initial = pitchPainter(tester);
        final finger = await tester.startGesture(initial.control);
        await finger.moveBy(const Offset(0, -30));
        await tester.pump();
        await finger.moveTo(
          camera.toScreen(Offset(5, -(target + .04))) +
              ArchitectRoofPitchEditor.leaderOffset,
        );
        await tester.pump();
        expect(pitchPainter(tester).snapContact != null, snapEnabled);
        await finger.up();
        await tester.pumpAndSettle();
        expect(controller.project, same(before));
        await tester.tap(find.byKey(const ValueKey('roof-pitch-confirm')));
        await tester.pumpAndSettle();
        final edited = controller.project.activeStorey.roofs.last;
        expect(
          edited.topElevationAt(const Offset(4, 2)),
          closeTo(target + (snapEnabled ? 0 : .04), 1e-5),
        );
        expect(
          edited.topElevationAt(const Offset(8, 2)),
          closeTo(source.topElevationAt(const Offset(8, 2)), 1e-8),
        );
        expect(edited.points, source.points);
        expect(controller.undoCount, 1);
        controller.undo();
        await tester.pumpAndSettle();
        expect(
          controller.project.activeStorey.roofs.last.toJson(),
          source.toJson(),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
