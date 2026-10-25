import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/services/architect_rotation.dart';
import 'package:kotoview/src/features/architect/widgets/architect_rotation_overlay.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_element_group_test.dart' as groups;
import 'architect_workspace_interaction_test.dart' as workspace;

void near(Offset actual, Offset expected) =>
    expect((actual - expected).distance, lessThan(1e-8));

void main() {
  test(
    'Rigid rotation preserves wall arcs, hosted doors and untouched elements',
    () {
      const wall = ArchitectWall(
        id: 'w',
        startPoint: Offset(1, 0),
        endPoint: Offset(5, 0),
        arcBulge: .3,
        doors: [ArchitectDoor(id: 'd', uuid: 'door-uuid', wallId: 'w', offsetRatio: .25)],
      );
      const other = ArchitectWall(
        id: 'other',
        startPoint: Offset(0, 8),
        endPoint: Offset(4, 8),
      );
      const source = ArchitectStorey(id: 's', name: '', walls: [wall, other]);
      final result = ArchitectRotation.apply(
        source,
        {'w'},
        const Offset(1, 0),
        math.pi / 2,
      );
      near(result.walls.first.startPoint, const Offset(1, 0));
      near(result.walls.first.endPoint, const Offset(1, 4));
      expect(result.walls.first.arcBulge, .3);
      expect(result.walls.first.doors.single, same(wall.doors.single));
      expect(result.walls.last, same(other));
    },
  );

  test(
    'Implicit CAD rectangles rotate their four corners, holes and hatch direction',
    () {
      const source = ArchitectStorey(
        id: 's',
        name: '',
        cadPrimitives: [
          ArchitectCadPrimitive(
            id: 'h',
            type: CadPrimitiveType.hatch,
            startPoint: Offset.zero,
            endPoint: Offset(4, 2),
            hatchAngle: 15,
            holes: [
              [Offset(1, .5), Offset(2, .5), Offset(2, 1), Offset(1, 1)],
            ],
          ),
        ],
      );
      final result = ArchitectRotation.apply(
        source,
        {'h'},
        Offset.zero,
        math.pi / 4,
      ).cadPrimitives.single;
      expect(result.polygon, hasLength(4));
      near(result.polygon![1], Offset(4 / math.sqrt(2), 4 / math.sqrt(2)));
      near(
        result.holes.first.first,
        Offset(.5 / math.sqrt(2), 1.5 / math.sqrt(2)),
      );
      expect(result.hatchAngle, closeTo(60, 1e-8));
      final restored = ArchitectRotation.apply(
        source.copyWith(cadPrimitives: [result]),
        {'h'},
        Offset.zero,
        -math.pi / 4,
      ).cadPrimitives.single;
      for (var i = 0; i < 4; i++) {
        near(
          restored.polygon![i],
          source.cadPrimitives.single.polygonCorners[i],
        );
      }
    },
  );

  test(
    'Angle snapping supports negative and positive 45/90 degrees with free angles between',
    () {
      for (final angle in [
        -math.pi,
        -math.pi / 2,
        -math.pi / 4,
        0.0,
        math.pi / 4,
        math.pi / 2,
      ]) {
        expect(ArchitectRotation.snapAngle(angle + .01), closeTo(angle, 1e-8));
      }
      expect(ArchitectRotation.snapAngle(.3), .3);
      expect(
        () => ArchitectRotation.apply(
          const ArchitectStorey(id: 's', name: ''),
          {'missing'},
          Offset.zero,
          1,
        ),
        throwsArgumentError,
      );
    },
  );

  for (final locale in ['bg', 'en']) {
    testWidgets(
      'Phone $locale rotation previews snap, accepts exact signed angle without IME',
      (tester) async {
        tester.view.physicalSize = const Size(390, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        double? preview, applied;
        Offset? centre;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ArchitectRotationOverlay(
                initialPivot: const Offset(180, 350),
                toModel: (p) => p,
                toScreen: (p) => p,
                snap: (p) => p,
                onPreview: (p, a) {
                  centre = p;
                  preview = a;
                },
                onApply: (p, a) {
                  applied = a;
                },
                onCancel: () {},
                onNavigate: (_, _, _) {},
              ),
            ),
          ),
        );
        await tester.tapAt(const Offset(180, 350));
        await tester.pump();
        await tester.tapAt(const Offset(260, 350));
        await tester.pump();
        final gesture = await tester.startGesture(const Offset(260, 350));
        await gesture.moveTo(const Offset(181, 430));
        await tester.pump();
        expect(preview, closeTo(math.pi / 2, 1e-8));
        expect(centre, const Offset(180, 350));
        expect(applied, isNull);
        await gesture.up();
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('architect-rotation-exact')),
        );
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('architect-rotation-angle')),
        );
        expect(field.readOnly, isTrue);
        for (final key in '22.5'.split('')) {
          await tester.tap(find.byKey(ValueKey('architect-rotation-key-$key')));
          await tester.pump();
        }
        await tester.tap(find.text('±'));
        await tester.pump();
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(
          find.byKey(const ValueKey('architect-rotation-angle-apply')),
        );
        await tester.pumpAndSettle();
        expect(preview, closeTo(-math.pi / 8, 1e-8));
        await tester.tap(
          find.byKey(const ValueKey('architect-rotation-apply')),
        );
        await tester.pump();
        expect(applied, closeTo(-math.pi / 8, 1e-8));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Selected line rotation cancels, then commits as one undo step', (
    tester,
  ) async {
    final model = editing.seeded(groups.fixture());
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    workspace.camera(tester).fit(const Rect.fromLTRB(-4, -4, 9, 8));
    await tester.pumpAndSettle();
    final before = model.project.activeStorey.toJson();
    await editing.contextHold(tester, const Offset(2, 0));
    await groups.action(tester, BimEditAction.rotate);
    await tester.tap(
      find.byKey(const ValueKey('architect-rotation-preset-45')),
    );
    await tester.pump();
    expect(model.project.activeStorey.toJson(), before);
    expect(
      workspace.overlay(tester).project.activeStorey.toJson(),
      isNot(before),
    );
    await tester.tap(find.byKey(const ValueKey('architect-rotation-cancel')));
    await tester.pumpAndSettle();
    expect(workspace.overlay(tester).project.activeStorey.toJson(), before);
    await editing.contextHold(tester, const Offset(2, 0));
    await groups.action(tester, BimEditAction.rotate);
    await tester.tap(
      find.byKey(const ValueKey('architect-rotation-preset-90')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('architect-rotation-apply')));
    await tester.pumpAndSettle();
    near(
      model.project.activeStorey.cadPrimitives.first.startPoint,
      const Offset(2, -2),
    );
    near(
      model.project.activeStorey.cadPrimitives.first.endPoint,
      const Offset(2, 2),
    );
    model.undo();
    await tester.pumpAndSettle();
    expect(model.project.activeStorey.toJson(), before);
    expect(tester.takeException(), isNull);
  });
}
