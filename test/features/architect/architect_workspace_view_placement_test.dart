import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  testWidgets(
    'workspace elevation supports opposite direction, jogs and unlimited depth',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final source = workspace.commands();
      addTearDown(source.dispose);
      await workspace.open(tester, source);
      Future<void> command(String action) async {
        await tester.tap(
          find.byKey(const ValueKey('architect-view-elevation')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is PopupMenuItem<String> && w.value == action,
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(workspace.screen(tester, p));
        await tester.pumpAndSettle();
      }

      await command('new');
      await tap(const Offset(-1, 2));
      await tap(const Offset(5, 2));
      expect(source.project.elevations, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('architect-view-direction-negative')),
      );
      await tester.pumpAndSettle();
      expect(source.project.elevations.single.viewSide, -1);
      expect(source.project.elevations.single.viewDepth, isNull);
      await command('depth');
      await tap(const Offset(0, -1));
      expect(source.project.elevations.single.viewDepth, closeTo(3, .01));
      await command('step');
      await tap(const Offset(1, 1));
      expect(source.project.elevations.single.steps.single.dy, closeTo(1, .01));
      await command('depth');
      await tester.tap(find.byTooltip('View depth'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('architect-view-depth-input')),
        '.5',
      );
      await tester.tap(find.byKey(const ValueKey('architect-view-depth-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('Place the far boundary beyond every segment.'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('architect-view-depth-unlimited')),
      );
      await tester.tap(find.byKey(const ValueKey('architect-view-depth-save')));
      await tester.pumpAndSettle();
      expect(source.project.elevations.single.viewDepth, isNull);
      expect(source.project.elevations.single.steps, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'workspace places a section, edits depth and adds and returns jogs',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final source = workspace.commands();
      addTearDown(source.dispose);
      await workspace.open(tester, source);
      Future<void> command(String action) async {
        await tester.tap(find.byKey(const ValueKey('architect-view-section')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is PopupMenuItem<String> && w.value == action,
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(workspace.screen(tester, p));
        await tester.pumpAndSettle();
      }

      await command('new');
      await tap(const Offset(-1, 0));
      await tap(const Offset(5, 0));
      expect(source.project.sections, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('architect-view-direction-positive')),
      );
      await tester.pumpAndSettle();
      expect(source.project.sections, hasLength(1));
      expect(source.project.sections.single.viewDepth, isNull);
      await command('depth');
      await tap(const Offset(0, 4));
      expect(source.project.sections.single.viewDepth, closeTo(4, .01));
      await command('step');
      await tap(const Offset(1, 1));
      expect(source.project.sections.single.steps, hasLength(1));
      expect(source.project.sections.single.pointAt(3).dy, closeTo(1, .01));
      await command('step');
      await tap(const Offset(3, 0));
      expect(source.project.sections.single.steps, hasLength(2));
      expect(source.project.sections.single.pointAt(5).dy, closeTo(0, .01));
      source.undo();
      await tester.pumpAndSettle();
      expect(source.project.sections.single.steps, hasLength(1));
      source.redo();
      await tester.pumpAndSettle();
      expect(source.project.sections.single.steps, hasLength(2));
      await command('edit');
      final start = workspace.screen(tester, const Offset(1, 1));
      final gesture = await tester.startGesture(start);
      await gesture.moveTo(workspace.screen(tester, const Offset(1, 1.5)));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(source.project.sections.single.steps.first.dy, closeTo(1, .01));
      await tester.tap(find.byTooltip('Apply'));
      await tester.pumpAndSettle();
      expect(source.project.sections.single.steps.first.dy, closeTo(1.5, .01));
      await command('straight');
      expect(source.project.sections.single.steps, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
