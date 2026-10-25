import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_section_visibility_dialog.dart';
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_roof_drainage_test.dart' as fixture;
import 'architect_section_visibility_test.dart' as geometry;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_workspace_views_test.dart' as views;

Future<void> choose(WidgetTester tester, String key, String label) async {
  final dropdown = find.byKey(ValueKey(key));
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final locale in ['bg', 'en']) {
    testWidgets(
      'phone section rules save atomically, inherit, cancel and undo ($locale)',
      (tester) async {
        await qa.phone(tester);
        final controller = ArchitectCommandController(
          fixture.drainageProject().copyWith(
            sections: const [geometry.throughPipe, geometry.front],
          ),
        );
        addTearDown(controller.dispose);
        final l = lookupAppLocalizations(Locale(locale));
        final key = GlobalKey();
        await tester.pumpWidget(
          qa.host(
            ArchitectBuildingSectionsScreen(controller: controller),
            locale,
            key,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-section-visibility')),
        );
        await tester.pumpAndSettle();
        await choose(
          tester,
          'section-visibility-default-gutters',
          l.architectSectionHidden,
        );
        await choose(
          tester,
          'section-visibility-view-downpipes',
          l.architectSectionCutAndView,
        );
        expect(controller.undoCount, 0);
        expect(find.text(l.architectSectionVisibility), findsOneWidget);
        await qa.capturePhone(tester, key, 'section-visibility-$locale');
        await tester.tap(find.byKey(const ValueKey('section-visibility-save')));
        await tester.pumpAndSettle();
        expect(controller.undoCount, 1);
        expect(
          controller.project.sectionVisibility.modeFor(geometry.gutters),
          geometry.hidden,
        );
        expect(
          controller.project.sections.first.visibility.modeFor(geometry.pipes),
          geometry.full,
        );
        expect(controller.project.sections.last.visibility.categories, isEmpty);
        expect(tester.takeException(), isNull);
        controller.undo();
        await tester.pumpAndSettle();
        expect(
          controller.project.sectionVisibility.modeFor(geometry.gutters),
          geometry.full,
        );
        controller.redo();
        await tester.pumpAndSettle();

        // Cancel retains both project and view rules.
        final before = controller.project;
        final dialogContext = tester.element(find.byType(Scaffold).first);
        final canceled = showArchitectSectionVisibility(
          dialogContext,
          controller,
          sectionId: geometry.throughPipe.id,
        );
        await tester.pumpAndSettle();
        await choose(
          tester,
          'section-visibility-view-downpipes',
          l.architectSectionInherit,
        );
        await tester.tap(find.text(l.cancel));
        await tester.pumpAndSettle();
        await canceled;
        expect(identical(controller.project, before), isTrue);

        final inherited = showArchitectSectionVisibility(
          dialogContext,
          controller,
          sectionId: geometry.throughPipe.id,
        );
        await tester.pumpAndSettle();
        await choose(
          tester,
          'section-visibility-view-downpipes',
          l.architectSectionInherit,
        );
        await tester.tap(find.byKey(const ValueKey('section-visibility-save')));
        await tester.pumpAndSettle();
        await inherited;
        expect(
          controller.project.sections.first.visibility.categories.containsKey(
            geometry.pipes,
          ),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'workspace section menu opens rules without changing the active view',
    (tester) async {
      final controller = ArchitectCommandController(
        fixture.drainageProject().copyWith(sections: const [geometry.front]),
      );
      addTearDown(controller.dispose);
      await workspace.open(tester, controller);
      await tester.tap(find.byKey(const ValueKey('architect-view-section')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-section-visibility')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('section-visibility-default-gutters')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('section-visibility-view-gutters')),
        findsNothing,
      );
      expect(controller.undoCount, 0);
      expect(tester.takeException(), isNull);
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      await views.select(tester, 'section', geometry.front.id);
      await tester.tap(find.byKey(const ValueKey('architect-view-section')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-section-visibility')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('section-visibility-view-gutters')),
        findsOneWidget,
      );
      expect(controller.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
