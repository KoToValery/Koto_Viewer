import 'architect_tool_test_helper.dart' as tool_ui;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_dimension_chain.dart';
import 'architect_dimension_chain_test.dart' as dimensions;
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

Future<void> selectDimension(
  WidgetTester tester,
  ArchitectDimension dimension,
) async {
  await tool_ui.prepare(tester, Icons.near_me_outlined);
  await tester.tap(find.byIcon(Icons.near_me_outlined));
  await tester.pumpAndSettle();
  await workspace.wallTap(
    tester,
    (dimension.lineStart + dimension.lineEnd) / 2 + dimension.unitVector * .6,
  );
  await tester.tap(find.byKey(const ValueKey('architect-dimension-add-walls')));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final style in [
    ArchitectDimensionStyle.exterior,
    ArchitectDimensionStyle.interior,
  ]) {
    test(
      '$style removal merges spans, preserves the line and protects the final references',
      () {
        final storey = dimensions.scene();
        final original = ArchitectDimensionChain.build(
          id: 'd',
          style: style,
          direction: const Offset(1, 0),
          offset: -2,
          anchors: [
            for (var i = 0; i < storey.walls.length; i++)
              ...ArchitectDimensionChain.wallFaces(
                storey.walls[i],
                Offset(i * 3.0, .5 + i),
              ),
          ],
        ).copyWith(customText: 'custom', showOverall: false);
        final groups = ArchitectDimensionChain.editPoints(original);
        expect(groups, hasLength(3));
        final middle = groups.firstWhere((g) => g.id == 'wallFace:b');
        final merged = ArchitectDimensionChain.removeAnchors(
          original,
          middle.anchorIndices,
        )!;
        expect(merged.anchors.map((a) => a.elementId).toSet(), {'a', 'c'});
        expect(merged.anchors, hasLength(4));
        expect(merged.lineStart.dy, closeTo(original.lineStart.dy, 1e-9));
        expect(merged.length, closeTo(original.length, 1e-9));
        expect(merged.style, style);
        expect(merged.customText, 'custom');
        expect(merged.showOverall, false);
        expect(dimensions.lengths(merged), contains(closeTo(5.75, 1e-9)));
        final first = groups.firstWhere((g) => g.id == 'wallFace:a');
        final shorter = ArchitectDimensionChain.removeAnchors(
          original,
          first.anchorIndices,
        )!;
        expect(shorter.lineStart.dy, closeTo(original.lineStart.dy, 1e-9));
        expect(shorter.length, lessThan(original.length));
        if (style == ArchitectDimensionStyle.interior) {
          expect(
            ArchitectDimensionChain.removeAnchors(
              shorter,
              ArchitectDimensionChain.editPoints(shorter).first.anchorIndices,
            ),
            isNull,
          );
        }
      },
    );

    testWidgets(
      '$style replaces a wrong reference with a newly drawn wall, saves once and undoes',
      (tester) async {
        final storey = dimensions.scene();
        final original = dimensions.chain(storey).copyWith(style: style);
        final model = editing.seeded(storey.copyWith(dimensions: [original]));
        addTearDown(model.dispose);
        model.execute(
          const CreateArchitectWall(
            storeyId: 's',
            wall: ArchitectWall(
              id: 'new',
              startPoint: Offset(1.5, 0),
              endPoint: Offset(1.5, 3),
            ),
          ),
        );
        await workspace.open(tester, model);
        final before = model.project.activeStorey.dimensions.single;
        await selectDimension(tester, before);
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-remove-wallFace:b')),
        );
        await tester.pump();
        expect(dimensions.preview(tester)!.anchors, hasLength(4));
        expect(
          model.project.activeStorey.dimensions.single.anchors,
          hasLength(6),
        );
        await workspace.wallTap(tester, const Offset(1.5, 2.5));
        expect(
          dimensions.preview(tester)!.anchors.map((a) => a.elementId).toSet(),
          {'a', 'new', 'c'},
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-confirm')),
        );
        await tester.pumpAndSettle();
        final saved = model.project.activeStorey.dimensions.single;
        expect(saved.id, original.id);
        expect(saved.style, style);
        expect(saved.lineStart.dy, closeTo(before.lineStart.dy, 1e-9));
        expect(saved.anchors.map((a) => a.elementId).toSet(), {
          'a',
          'new',
          'c',
        });
        expect(model.project.activeStorey.walls.map((w) => w.id).toSet(), {
          'a',
          'b',
          'c',
          'new',
        });
        expect(model.undoCount, 2);
        model.undo();
        expect(
          model.project.activeStorey.dimensions.single.anchors
              .map((a) => a.elementId)
              .toSet(),
          {'a', 'b', 'c'},
        );
        expect(model.project.activeStorey.walls, hasLength(4));
        model.redo();
        expect(
          model.project.activeStorey.dimensions.single.anchors
              .map((a) => a.elementId)
              .toSet(),
          {'a', 'new', 'c'},
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'An opening removes both jambs without removing its wall or other references',
    () {
      const wall = ArchitectWall(
        id: 'host',
        startPoint: Offset.zero,
        endPoint: Offset(6, 0),
        windows: [
          ArchitectWindow(
            id: 'window',
            uuid: 'window-uuid',
            wallId: 'host',
            offsetRatio: .5,
            width: 1.2,
          ),
        ],
      );
      final d = ArchitectDimensionChain.build(
        id: 'd',
        direction: const Offset(1, 0),
        anchors: [
          const ArchitectDimensionAnchor(point: Offset.zero),
          ...ArchitectDimensionChain.openingAnchors(wall, 'window'),
          const ArchitectDimensionAnchor(point: Offset(6, 0)),
        ],
      );
      final opening = ArchitectDimensionChain.editPoints(
        d,
      ).firstWhere((g) => g.id == 'opening:window');
      final next = ArchitectDimensionChain.removeAnchors(
        d,
        opening.anchorIndices,
      )!;
      expect(next.anchors, hasLength(2));
      expect(next.length, 6);
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: [wall],
        ).copyWith(dimensions: [d]),
      );
      addTearDown(model.dispose);
      model.commit(
        model.project.updateActiveStorey(
          model.project.activeStorey.copyWith(dimensions: [next]),
        ),
      );
      expect(
        model.project.activeStorey.walls.single.windows.single.id,
        'window',
      );
      expect(
        model.project.activeStorey.dimensions.single.anchors,
        hasLength(2),
      );
      expect(ArchitectDimensionChain.removeAnchors(next, {0}), isNull);
    },
  );

  testWidgets(
    'Empty taps in the witness band and on magnetic alignments do not add points',
    (tester) async {
      final model = editing.seeded(dimensions.scene());
      addTearDown(model.dispose);
      await dimensions.startChain(tester, model);
      await workspace.wallTap(tester, const Offset(0, 1.5));
      await workspace.wallTap(tester, const Offset(3, 1.5));
      for (final gap in [const Offset(1.5, 1.25), const Offset(1.5, 3)]) {
        await workspace.wallTap(tester, gap);
        expect(
          find.byKey(const ValueKey('architect-dimension-finish-dialog')),
          findsOneWidget,
        );
        expect(dimensions.preview(tester)!.anchors, hasLength(4));
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-continue')),
        );
        await tester.pumpAndSettle();
        // Cancel the explicit free-point choice by confirming placement, then resume references.
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-place')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-add-walls')),
        );
        await tester.pump();
      }
      await tester.tap(
        find.byKey(const ValueKey('architect-dimension-confirm')),
      );
      await tester.pump();
      expect(
        model.project.activeStorey.dimensions.single.anchors,
        hasLength(4),
      );
      expect(model.undoCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Green confirm saves the displayed position without pointer hover moving it',
    (tester) async {
      final model = editing.seeded(dimensions.scene());
      addTearDown(model.dispose);
      await dimensions.startChain(tester, model);
      await workspace.wallTap(tester, const Offset(0, 1.5));
      await workspace.wallTap(tester, const Offset(3, 1.5));
      // Repeated rapid taps on a wall must stay in dimension drafting.
      await workspace.wallTap(tester, const Offset(3, 1.5));
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      await tester.tap(find.byKey(const ValueKey('architect-dimension-place')));
      await tester.pump();
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(
        location: workspace.screen(tester, const Offset(1, 2.4)),
      );
      await mouse.moveTo(workspace.screen(tester, const Offset(2, 2.4)));
      await tester.pump();
      final lineY = dimensions.preview(tester)!.lineStart.dy;
      await mouse.moveTo(
        tester.getCenter(
          find.byKey(const ValueKey('architect-dimension-confirm')),
        ),
      );
      await tester.pump();
      expect(dimensions.preview(tester)!.lineStart.dy, closeTo(lineY, 1e-9));
      await mouse.removePointer();
      await tester.tap(
        find.byKey(const ValueKey('architect-dimension-confirm')),
      );
      await tester.pump();
      expect(
        model.project.activeStorey.dimensions.single.lineStart.dy,
        closeTo(lineY, 1e-9),
      );
      expect(
        model.project.activeStorey.dimensions.single.anchors,
        hasLength(4),
      );
      expect(model.undoCount, 1);
      expect(
        find.byKey(const ValueKey('architect-dimension-confirm')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final legacy in [false, true]) {
    testWidgets(
      'Single dimension (legacy=$legacy) can add and remove references while keeping one row',
      (tester) async {
        final storey = dimensions.scene();
        final dimension = legacy
            ? const ArchitectDimension(
                id: 'single',
                startPoint: Offset(0, 1),
                endPoint: Offset(6, 1),
                offsetDistance: 2.5,
              )
            : ArchitectDimensionChain.build(
                id: 'single',
                style: ArchitectDimensionStyle.single,
                direction: const Offset(1, 0),
                offset: 2.5,
                anchors: const [
                  ArchitectDimensionAnchor(point: Offset(0, 1)),
                  ArchitectDimensionAnchor(point: Offset(6, 1)),
                ],
              );
        final model = editing.seeded(storey.copyWith(dimensions: [dimension]));
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await selectDimension(tester, dimension);
        await workspace.wallTap(tester, const Offset(3, 2.5));
        expect(dimensions.preview(tester)!.anchors, hasLength(4));
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-remove-anchor:0')),
        );
        await tester.pump();
        expect(dimensions.preview(tester)!.anchors, hasLength(3));
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-confirm')),
        );
        await tester.pump();
        final saved = model.project.activeStorey.dimensions.single;
        expect(saved.id, dimension.id);
        expect(saved.style, ArchitectDimensionStyle.single);
        expect(saved.lineStart.dy, closeTo(3.5, 1e-9));
        expect(model.project.activeStorey.walls, hasLength(3));
        expect(model.undoCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['bg', 'en']) {
    testWidgets(
      'Phone $language edit marks and confirm fit, and X discards removals',
      (tester) async {
        final storey = dimensions.scene();
        final model = editing.seeded(
          storey.copyWith(dimensions: [dimensions.chain(storey)]),
        );
        addTearDown(model.dispose);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        if (Platform.environment['UPDATE_ARCHITECT_CHAIN_PREVIEW'] == 'true') {
          await tester.runAsync(() async {
            await (FontLoader('Roboto')..addFont(
                  File(
                    'C:/Windows/Fonts/arial.ttf',
                  ).readAsBytes().then((b) => ByteData.sublistView(b)),
                ))
                .load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
        }
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(
              key: boundaryKey,
              child: ArchitectWorkspaceScreen(commandController: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await selectDimension(
          tester,
          model.project.activeStorey.dimensions.single,
        );
        if (language == 'bg') {
          await dimensions.captureDimensionPhone(
            tester,
            boundaryKey,
            'docs/images/architect_dimension_edit_phone.png',
          );
        }
        final keys = [
          'architect-draft-cancel',
          'architect-dimension-confirm',
          'architect-dimension-remove-wallFace:a',
          'architect-dimension-remove-wallFace:b',
          'architect-dimension-remove-wallFace:c',
        ];
        final rects = [
          for (final key in keys) tester.getRect(find.byKey(ValueKey(key))),
        ];
        for (final rect in rects) {
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(800));
        }
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(rects[i].overlaps(rects[j]), isFalse);
          }
        }
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-remove-wallFace:b')),
        );
        await tester.pump();
        expect(dimensions.preview(tester)!.anchors, hasLength(4));
        await tester.tap(find.byKey(const ValueKey('architect-draft-cancel')));
        await tester.pump();
        expect(
          model.project.activeStorey.dimensions.single.anchors,
          hasLength(6),
        );
        expect(model.undoCount, 0);
        expect(dimensions.preview(tester), isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
