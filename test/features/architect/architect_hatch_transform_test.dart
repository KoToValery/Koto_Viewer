import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_hatch_pattern.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_hatch_transform_handle.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

const hatch = ArchitectCadPrimitive(
  id: 'h',
  type: CadPrimitiveType.hatch,
  startPoint: Offset.zero,
  endPoint: Offset(6, 4),
  holes: [
    [Offset(1, 1), Offset(2, 1), Offset(2, 2), Offset(1, 2)],
  ],
);
final handle = find.byKey(const ValueKey('hatch-transform-handle'));

void main() {
  for (final locale in ['en', 'bg']) {
    testWidgets('Scale snaps by 10%, direction at 45/90 ($locale)', (
      tester,
    ) async {
      (double, double)? preview, applied;
      var started = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArchitectHatchTransformHandle(
              hatch: hatch,
              toScreen: (p) => p * 30 + const Offset(200, 180),
              toModel: (p) => (p - const Offset(200, 180)) / 30,
              onStart: () => started++,
              onCancel: () {},
              onPreview: (a, s) => preview = (a, s),
              onApply: (a, s) => applied = (a, s),
            ),
          ),
        ),
      );
      final l = await AppLocalizations.delegate.load(Locale(locale));
      expect(find.byTooltip(l.architectHatchTransformHelp), findsOneWidget);
      final pivot =
          tester.getCenter(handle) - const Offset(1, 1) / math.sqrt(2) * 100;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveTo(pivot + const Offset(3, 134));
      await tester.pump();
      expect(started, 1);
      expect(preview!.$1, closeTo(45, 1e-8));
      expect(preview!.$2, 1.3);
      expect(applied, isNull);
      await gesture.moveTo(pivot + const Offset(1, 1) / math.sqrt(2) * 146);
      await tester.pump();
      expect(preview!.$1, closeTo(0, 1e-8));
      expect(preview!.$2, 1.5);
      await gesture.moveTo(
        pivot + Offset.fromDirection(23 * math.pi / 180, 174),
      );
      await tester.pump();
      expect(preview!.$1, closeTo(-22, 1e-8));
      expect(preview!.$2, 1.7);
      await gesture.up();
      await tester.pump();
      expect(applied, preview);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Existing scale stays absolute, respects bounds and cancels', (
    tester,
  ) async {
    (double, double)? preview, applied;
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ArchitectHatchTransformHandle(
            hatch: hatch.copyWith(hatchScale: 2),
            toScreen: (p) => p * 30 + const Offset(200, 180),
            toModel: (p) => (p - const Offset(200, 180)) / 30,
            onStart: () {},
            onCancel: () => cancelled = true,
            onPreview: (a, s) => preview = (a, s),
            onApply: (a, s) => applied = (a, s),
          ),
        ),
      ),
    );
    final pivot =
        tester.getCenter(handle) - const Offset(1, 1) / math.sqrt(2) * 100;
    final gesture = await tester.startGesture(
      tester.getCenter(handle),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(pivot + const Offset(-126, 0));
    await tester.pump();
    expect(preview!.$2, 2.5);
    expect(preview!.$1, closeTo(135, 1e-8));
    await gesture.moveTo(pivot + const Offset(2000, 0));
    await tester.pump();
    expect(preview!.$2, 20);
    await gesture.moveTo(pivot + const Offset(1, 0));
    await tester.pump();
    expect(preview!.$2, .1);
    await gesture.cancel();
    await tester.pump();
    expect(cancelled, isTrue);
    expect(applied, isNull);
    expect((tester.getCenter(handle) - pivot).distance, closeTo(100, 1e-8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Workspace edits only selected hatch and commits one Undo', (
    tester,
  ) async {
    final model = editing.seeded(
      ArchitectStorey(
        id: 's',
        name: '',
        cadPrimitives: [
          hatch,
          hatch.copyWith(
            id: 'other',
            startPoint: const Offset(8, 0),
            endPoint: const Offset(14, 4),
          ),
        ],
      ),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    expect(handle, findsNothing);
    await editing.hold(tester, const Offset(3, 2));
    expect(handle, findsOneWidget);
    final original = model.project;
    final pivot = workspace.screen(tester, const Offset(3, 2));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveTo(pivot + const Offset(2, 142));
    await tester.pump();
    expect(identical(model.project, original), isTrue);
    final visible = workspace
        .overlay(tester)
        .project
        .activeStorey
        .cadPrimitives
        .first;
    expect(visible.hatchAngle, closeTo(45, 1e-8));
    expect(visible.hatchScale, 1.4);
    expect(model.canUndo, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    final changed = model.project.activeStorey.cadPrimitives.first;
    expect(changed.hatchAngle, closeTo(45, 1e-8));
    expect(changed.hatchScale, 1.4);
    expect(changed.polygonCorners, hatch.polygonCorners);
    expect(changed.holes, hatch.holes);
    expect(changed.hatchPattern, hatch.hatchPattern);
    expect(
      model.project.activeStorey.cadPrimitives.last.toJson(),
      original.activeStorey.cadPrimitives.last.toJson(),
    );
    final nextGesture = await tester.startGesture(tester.getCenter(handle));
    await nextGesture.moveBy(const Offset(0, 10));
    await tester.pump();
    await nextGesture.cancel();
    await tester.pumpAndSettle();
    expect(
      model.project.activeStorey.cadPrimitives.first.toJson(),
      changed.toJson(),
    );
    model.undo();
    await tester.pump();
    expect(model.project.toJson(), original.toJson());
    expect(model.canUndo, isFalse);
    model.redo();
    await tester.pump();
    expect(
      model.project.activeStorey.cadPrimitives.first.toJson(),
      changed.toJson(),
    );
    await tester.tap(find.byKey(const ValueKey('architect-select-similar')));
    await tester.pumpAndSettle();
    expect(workspace.overlay(tester).selectedElementIds, {'h', 'other'});
    expect(handle, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Solid fill has no direction handle', (tester) async {
    final model = editing.seeded(
      ArchitectStorey(
        id: 's',
        name: '',
        cadPrimitives: [
          hatch.copyWith(hatchPattern: ArchitectHatchPattern.solid),
        ],
      ),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await editing.hold(tester, const Offset(3, 2));
    expect(workspace.overlay(tester).selectedElementId, 'h');
    expect(handle, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Phone handle remains reachable and guides preserve viewport navigation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (const bool.fromEnvironment(
        'UPDATE_ARCHITECT_HATCH_TRANSFORM_PREVIEW',
      )) {
        await tester.runAsync(() async {
          await (FontLoader('HatchPreview')
                ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', cadPrimitives: [hatch]),
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('phone-hatch-preview'),
          child: MaterialApp(
            locale: const Locale('bg'),
            theme: ThemeData(fontFamily: 'HatchPreview'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: model),
          ),
        ),
      );
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(0, 0, 6, 4), padding: 90);
      await tester.pumpAndSettle();
      await editing.hold(tester, const Offset(3, 2));
      final rect = tester.getRect(handle);
      expect(
        (Offset.zero & const Size(360, 800)).contains(rect.topLeft),
        isTrue,
      );
      expect(
        (Offset.zero & const Size(360, 800)).contains(rect.bottomRight),
        isTrue,
      );
      final pivot = workspace.screen(tester, const Offset(3, 2));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveTo(pivot + const Offset(2, 130));
      await tester.pump();
      if (const bool.fromEnvironment(
        'UPDATE_ARCHITECT_HATCH_TRANSFORM_PREVIEW',
      )) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('phone-hatch-preview')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '.dart_tool/architect_hatch_transform_phone.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.cadPrimitives.single.hatchScale, 1.3);
      await tester.tap(find.byKey(const ValueKey('architect-tool-pan')));
      await tester.pumpAndSettle();
      final camera = workspace.camera(tester);
      final before = camera.translation;
      // The hand owns one-pointer navigation.
      final pan = await tester.startGesture(
        tester.getTopLeft(
              find.byKey(const ValueKey('architect-viewport-input')),
            ) +
            const Offset(25, 110),
      );
      await pan.moveBy(const Offset(25, 15));
      await tester.pump();
      await pan.moveBy(const Offset(25, 15));
      await pan.up();
      await tester.pumpAndSettle();
      expect(camera.translation, isNot(before));
      expect(tester.takeException(), isNull);
    },
  );
}
