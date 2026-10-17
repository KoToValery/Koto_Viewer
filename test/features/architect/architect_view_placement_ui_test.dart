import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_elevations_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_view_plan.dart';
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_stair_detail_test.dart' as stairs;
import 'architect_elevation_test.dart' as elevations;

ArchitectViewPlanPainter painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (w) =>
                    w is CustomPaint && w.painter is ArchitectViewPlanPainter,
              ),
            )
            .painter!
        as ArchitectViewPlanPainter;
Offset screen(WidgetTester tester, String key, Offset p) {
  final paint = painter(tester);
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  return rect.center + (p - paint.bounds.center) * paint.scale;
}

Future<void> tap(WidgetTester tester, String key, Offset p) async {
  await tester.tapAt(screen(tester, key, p));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final locale in ['bg', 'en']) {
    testWidgets(
      'phone section shows stair treads, live draft and requested direction ($locale)',
      (tester) async {
        await qa.phone(tester);
        final controller = ArchitectCommandController(
          stairs.project(walls: [stairs.wall]),
        );
        addTearDown(controller.dispose);
        final capture = GlobalKey();
        await tester.pumpWidget(
          qa.host(
            ArchitectBuildingSectionsScreen(controller: controller),
            locale,
            capture,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          painter(tester).project.activeStorey.stairs.single.plan.nosings,
          isNotEmpty,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('building-section-plan')))
              .height,
          greaterThan(500),
        );
        await tap(tester, 'building-section-plan', const Offset(-.5, 0));
        expect(painter(tester).draft, isNotNull);
        expect(controller.canUndo, isFalse);
        await qa.capturePhone(tester, capture, 'section-first-$locale');
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: screen(
            tester,
            'building-section-plan',
            const Offset(3.3, .06),
          ),
        );
        await mouse.moveTo(
          screen(tester, 'building-section-plan', const Offset(3.3, .1)),
        );
        await tester.pumpAndSettle();
        expect(painter(tester).draft!.end.dy, closeTo(0, 1e-6));
        await tap(tester, 'building-section-plan', const Offset(3.3, .1));
        expect(controller.project.sections, isEmpty);
        await mouse.moveTo(
          screen(tester, 'building-section-plan', const Offset(1, -.9)),
        );
        await tester.pumpAndSettle();
        expect(painter(tester).draft!.direction.dy, lessThan(0));
        await qa.capturePhone(tester, capture, 'section-direction-$locale');
        await tap(tester, 'building-section-plan', const Offset(1, -.9));
        expect(
          controller.project.sections.single.viewDirection.dy,
          lessThan(0),
        );
        expect(
          find.byKey(const ValueKey('building-section-view')),
          findsOneWidget,
        );
        await mouse.removePointer();
        final selected = controller.project.sections.single;
        final l = AppLocalizations.of(
          tester.element(find.byType(ArchitectBuildingSectionsScreen)),
        )!;
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.architectFacadeReverse));
        await tester.pumpAndSettle();
        expect(
          controller.project.sections.single.viewDirection,
          -selected.viewDirection,
        );
        controller.undo();
        await tester.pumpAndSettle();
        expect(
          controller.project.sections.single.viewDirection,
          selected.viewDirection,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'phone elevation previews touch drag and perpendicular target before commit ($locale)',
      (tester) async {
        await qa.phone(tester);
        final source = elevations.elevationProject(markers: false);
        final project = source.copyWith(
          storeys: [
            source.activeStorey.copyWith(stairs: [stairs.stair()]),
          ],
        );
        final controller = ArchitectCommandController(project);
        addTearDown(controller.dispose);
        final capture = GlobalKey();
        await tester.pumpWidget(
          qa.host(
            ArchitectElevationsScreen(controller: controller),
            locale,
            capture,
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, 'architect-facade-plan', const Offset(-1, -2));
        final anchor = screen(
          tester,
          'architect-facade-plan',
          const Offset(7, -1.95),
        );
        final gesture = await tester.startGesture(anchor - const Offset(45, 0));
        await gesture.moveTo(anchor);
        await tester.pumpAndSettle();
        expect(painter(tester).draft!.end.dy, closeTo(-2, 1e-6));
        expect(controller.project.elevations, isEmpty);
        expect(controller.canUndo, isFalse);
        await qa.capturePhone(tester, capture, 'facade-drag-$locale');
        await gesture.up();
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: screen(tester, 'architect-facade-plan', const Offset(4, 1)),
        );
        await mouse.moveTo(
          screen(tester, 'architect-facade-plan', const Offset(4, 1.1)),
        );
        await tester.pumpAndSettle();
        final draft = painter(tester).draft!;
        expect(draft.target!.dy, closeTo(0, 1e-6));
        expect(draft.wall!.id, 'front0');
        expect(
          (draft.axis.dx * draft.direction.dx +
                  draft.axis.dy * draft.direction.dy)
              .abs(),
          lessThan(1e-6),
        );
        await qa.capturePhone(tester, capture, 'facade-direction-$locale');
        await tap(tester, 'architect-facade-plan', const Offset(4, 1.1));
        expect(
          controller.project.elevations.single.viewDirection.dy,
          greaterThan(0),
        );
        expect(controller.project.elevations.single.length, closeTo(8, .01));
        await mouse.removePointer();
        expect(
          find.byKey(const ValueKey('architect-facade-drawing')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
