import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_line_style.dart';
import 'package:kotoview/src/features/architect/models/architect_line_symbol.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_line_pattern.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_line_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/widgets/architect_line_style_picker.dart';
import 'architect_line_style_test.dart' as styles;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

const own = ArchitectLineSymbol(
  shape: ArchitectLineSymbolShape.custom,
  sizeMm: 4,
  spacingMm: 14,
  strokes: [
    [Offset(-.5, -.5), Offset(0, .5), Offset(.5, -.5)],
    [Offset(-.3, 0), Offset(.3, 0)],
  ],
);
ArchitectLineStyle custom(
  ArchitectLineSymbol symbol, {
  List<double> dashes = const [],
}) => ArchitectLineStyle(
  id: 'own',
  name: 'Utility',
  segmentsMm: dashes,
  symbol: symbol,
);
Path straight([double length = 120]) => Path()
  ..moveTo(0, 0)
  ..lineTo(length, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Power-line preset is localized, persists by ID and retains lightning geometry',
    () {
      final power = ArchitectLineStyle.symbolPresets.single;
      power.validate();
      expect(power.symbol!.shape, ArchitectLineSymbolShape.lightning);
      expect(ArchitectLineStyle.fromJson(power.toJson()), power);
      final path = ArchitectLinePattern.path(straight(), power, 1);
      final symbols = path.computeMetrics().where((m) => m.isClosed).toList();
      expect(symbols, hasLength(10));
      expect(path.getBounds().top, closeTo(-1.5, 1e-5));
      expect(path.getBounds().bottom, closeTo(1.5, 1e-5));
      final baseline = path.computeMetrics().where((m) => !m.isClosed);
      expect(
        baseline.every((m) {
          final b = m.extractPath(0, m.length).getBounds();
          return !(b.left < 6 && b.right > 6);
        }),
        isTrue,
      );
    },
  );
  test(
    'Every predefined symbol creates finite nonempty strokes without fonts or images',
    () {
      for (final shape in ArchitectLineSymbolShape.values.where(
        (s) =>
            s != ArchitectLineSymbolShape.none &&
            s != ArchitectLineSymbolShape.custom,
      )) {
        final symbol = ArchitectLineSymbol(shape: shape);
        final path = ArchitectLinePattern.path(straight(), custom(symbol), 1);
        expect(path.computeMetrics().length, greaterThan(5));
        expect(path.getBounds().isFinite, isTrue);
        expect(path.getBounds().height, greaterThan(0));
      }
    },
  );
  test(
    'Symbols follow vertical direction or stay upright; explicit angle is preserved',
    () {
      final vertical = Path()
        ..moveTo(0, 0)
        ..lineTo(0, 60);
      const arrow = ArchitectLineSymbol(shape: ArchitectLineSymbolShape.arrow);
      final follow = ArchitectLinePattern.path(
        vertical,
        custom(arrow),
        1,
      ).computeMetrics().first;
      final fixed = ArchitectLinePattern.path(
        vertical,
        custom(arrow.copyWith(followLine: false)),
        1,
      ).computeMetrics().first;
      expect(follow.getTangentForOffset(0)!.vector.dy, closeTo(1, 1e-6));
      expect(fixed.getTangentForOffset(0)!.vector.dx, closeTo(1, 1e-6));
      final turned = ArchitectLinePattern.path(
        vertical,
        custom(arrow.copyWith(followLine: false, angleDeg: 90)),
        1,
      ).computeMetrics().first;
      expect(turned.getTangentForOffset(0)!.vector.dy, closeTo(1, 1e-6));
    },
  );
  test(
    'Turning off the gap retains the original baseline through the symbols',
    () {
      final path = ArchitectLinePattern.path(
        straight(),
        custom(const ArchitectLineSymbol(clearLine: false)),
        1,
      );
      expect(
        path.computeMetrics().where((m) => !m.isClosed).single.length,
        closeTo(120, 1e-5),
      );
    },
  );
  test('Symbol gaps preserve the original dash phase', () {
    final path = ArchitectLinePattern.path(
      straight(50),
      custom(
        const ArchitectLineSymbol(shape: ArchitectLineSymbolShape.circle),
        dashes: [3, 1.5],
      ),
      1,
    );
    final starts = path
        .computeMetrics()
        .where((m) => !m.isClosed)
        .map((m) => m.getTangentForOffset(0)!.position.dx);
    expect(starts, contains(closeTo(9, 1e-5)));
    expect(starts, contains(closeTo(22.5, 1e-5)));
  });
  test(
    'Symbols never protrude from short endpoints or straddle rectangle corners',
    () {
      final tiny = ArchitectLinePattern.path(
        straight(.2),
        ArchitectLineStyle.symbolPresets.single,
        1,
      );
      expect(tiny.computeMetrics().single.length, closeTo(.2, 1e-6));
      final corner = ArchitectLinePattern.path(
        Path()..addRect(const Rect.fromLTWH(0, 0, 6, 6)),
        ArchitectLineStyle.symbolPresets.single,
        1,
      );
      expect(
        corner.computeMetrics().fold<double>(0, (a, m) => a + m.length),
        closeTo(24, 1e-5),
      );
      expect(corner.getBounds(), const Rect.fromLTWH(0, 0, 6, 6));
    },
  );
  test(
    'Custom multi-stroke vector geometry and placement round-trip with one property Undo',
    () {
      final model = ArchitectCommandController(styles.fixture());
      addTearDown(model.dispose);
      final style = custom(own.copyWith(angleDeg: 25, followLine: false));
      model.execute(
        SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'l', 'r'},
          textValues: {'lineStyle': jsonEncode(style.toJson())},
        ),
      );
      final restored = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(model.project.toJson())) as Map<String, dynamic>,
      );
      expect(restored.lineStyles.single, style);
      expect(
        restored.activeStorey.cadPrimitives
            .take(2)
            .every((p) => p.lineStyle.symbol == style.symbol),
        isTrue,
      );
      model.undo();
      expect(model.project.lineStyles, isEmpty);
      model.redo();
      expect(model.project.lineStyles.single.symbol!.strokes, own.strokes);
    },
  );
  test(
    'Splitting a symbolic line preserves the style on both resulting segments',
    () {
      var p = styles.fixture();
      p = SetArchitectElementProperties(
        storeyId: 's',
        elementIds: {'l'},
        textValues: {'lineStyle': jsonEncode(custom(own).toJson())},
      ).apply(p);
      p = ArchitectLineEditing.adapt(
        p,
        const CutArchitectWalls(
          storeyId: 's',
          wallIds: {'l'},
          start: Offset(3, -1),
          end: Offset(3, 1),
        ),
      ).apply(p);
      final lines = p.activeStorey.cadPrimitives.where(
        (p) => p.type == CadPrimitiveType.line,
      );
      expect(lines, hasLength(2));
      expect(lines.every((p) => p.lineStyle.symbol == own), isTrue);
    },
  );
  test('Invalid symbols and malformed custom geometry are rejected', () {
    for (final symbol in [
      const ArchitectLineSymbol(shape: ArchitectLineSymbolShape.none),
      const ArchitectLineSymbol(sizeMm: 0),
      const ArchitectLineSymbol(spacingMm: 1),
      const ArchitectLineSymbol(angleDeg: double.nan),
      const ArchitectLineSymbol(shape: ArchitectLineSymbolShape.custom),
      const ArchitectLineSymbol(
        shape: ArchitectLineSymbolShape.custom,
        strokes: [
          [Offset(2, 0), Offset.zero],
        ],
      ),
      const ArchitectLineSymbol(
        shape: ArchitectLineSymbolShape.custom,
        strokes: [
          [Offset.zero, Offset.zero],
        ],
      ),
    ]) {
      expect(() => custom(symbol).validate(), throwsArgumentError);
    }
  });
  test(
    'Publication keeps symbols as vector geometry at an exact paper size',
    () async {
      final l = await AppLocalizations.delegate.load(const Locale('bg'));
      final p = styles.fixture().copyWith(
        storeys: [
          ArchitectStorey(
            id: 's',
            name: '',
            cadPrimitives: [
              styles.fixture().activeStorey.cadPrimitives.first.copyWith(
                lineStyle: ArchitectLineStyle.symbolPresets.single,
              ),
            ],
          ),
        ],
      );
      const drawing = ArchitectSavedDrawing(
        id: 'plan:s',
        sourceId: 's',
        kind: ArchitectDrawingKind.plan,
      );
      for (final scale in [50, 100, 200]) {
        final scene = ArchitectDrawingPublisher.build(p, drawing, scale, l);
        final path = scene.operations
            .whereType<ArchitectVectorPath>()
            .where((p) => p.sources.contains('l'))
            .single
            .path;
        final symbols = path.computeMetrics().where((m) => m.isClosed).toList();
        expect(symbols, isNotEmpty);
        expect(
          symbols.first.extractPath(0, symbols.first.length).getBounds().height,
          closeTo(3, 1e-4),
        );
        final first = symbols[0]
            .extractPath(0, symbols[0].length)
            .getBounds()
            .center;
        final second = symbols[1]
            .extractPath(0, symbols[1].length)
            .getBounds()
            .center;
        expect((second - first).distance, closeTo(12, 1e-4));
      }
    },
  );

  for (final locale in ['bg', 'en']) {
    testWidgets(
      'Phone editor draws a custom multi-stroke symbol and sets size ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ArchitectLineStyle? saved;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const ValueKey('open'),
                  onPressed: () async {
                    saved = await showDialog<ArchitectLineStyle>(
                      context: context,
                      builder: (_) => ArchitectLinePatternEditor(
                        initial: ArchitectLineStyle.presets[1],
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('line-pattern-name')),
          'Utility',
        );
        await tester.pump();
        final dropdown = find.byKey(const ValueKey('line-symbol-shape'));
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        final option = find
            .byWidgetPredicate(
              (w) =>
                  w is DropdownMenuItem<ArchitectLineSymbolShape> &&
                  w.value == ArchitectLineSymbolShape.custom,
            )
            .last;
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        final canvas = find.byKey(const ValueKey('line-symbol-canvas'));
        final center = tester.getCenter(canvas);
        for (final p in [
          const Offset(-50, -40),
          const Offset(0, 40),
          const Offset(50, -40),
        ]) {
          await tester.tapAt(center + p);
          await tester.pump();
        }
        await tester.tap(
          find.byKey(const ValueKey('line-symbol-close-stroke')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('line-symbol-freehand')));
        await tester.pump();
        final stroke = await tester.startGesture(center + const Offset(-30, 0));
        await stroke.moveTo(center + const Offset(-20, 0));
        await tester.pump();
        await stroke.moveTo(center + const Offset(30, 0));
        await tester.pump();
        await stroke.up();
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('line-symbol-shape-save')));
        await tester.pumpAndSettle();
        final size = find.byKey(const ValueKey('line-symbol-size'));
        await tester.ensureVisible(size);
        await tester.tap(size);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wall-key-4')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('wall-end')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('line-pattern-save')));
        await tester.pumpAndSettle();
        expect(saved!.symbol!.shape, ArchitectLineSymbolShape.custom);
        expect(saved!.symbol!.strokes, hasLength(2));
        expect(saved!.symbol!.strokes.last.length, greaterThanOrEqualTo(2));
        expect(
          saved!.symbol!.strokes.first.first,
          saved!.symbol!.strokes.first.last,
        );
        expect(saved!.symbol!.sizeMm, 4);
        saved!.validate();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Power line can be chosen directly from the compact drawing control',
    (tester) async {
      final model = workspace.commands();
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.choose(tester, Icons.timeline_rounded);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-draft-line-style')),
      );
      await tester.pumpAndSettle();
      final power = find.byKey(const ValueKey('line-style-powerLine'));
      await tester.ensureVisible(power);
      await tester.pumpAndSettle();
      await tester.tap(power);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, Offset.zero);
      await workspace.wallTap(tester, const Offset(3, 0));
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.single.lineStyle.symbol!.shape,
        ArchitectLineSymbolShape.lightning,
      );
      model.undo();
      expect(model.project.activeStorey.cadPrimitives, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
