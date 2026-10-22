import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  test(
    'all actions fit phones, landscape and desktop without intersecting circles',
    () {
      for (final size in [
        const Size(320, 420),
        const Size(360, 640),
        const Size(640, 250),
        const Size(1000, 760),
      ]) {
        for (final count in [1, 3, 6, 10, 16]) {
          for (final center in [
            Offset.zero,
            Offset(size.width, 0),
            Offset(0, size.height),
            Offset(size.width, size.height),
            size.center(Offset.zero),
          ]) {
            for (final title in [false, true]) {
              final layout = ArchitectRadialLayout.compute(
                size: size,
                center: center,
                count: count,
                hasTitle: title,
              );
              expect(
                layout.targets,
                hasLength(count),
                reason: '$size / $count / $center / $title',
              );
              expect(layout.buttonSize, greaterThanOrEqualTo(44));
              final available = Rect.fromLTWH(
                7.99,
                7.99,
                size.width - 15.98,
                layout.contentHeight - 15.98,
              );
              for (var i = 0; i < count; i++) {
                final rect = Rect.fromCenter(
                  center: layout.targets[i],
                  width: layout.buttonSize,
                  height: layout.buttonSize,
                );
                expect(
                  available.contains(rect.topLeft) &&
                      available.contains(rect.bottomRight),
                  isTrue,
                  reason: '$size / $count / $center / $title: $rect',
                );
                for (final other in layout.targets.skip(i + 1)) {
                  expect(
                    (other - layout.targets[i]).distance,
                    greaterThanOrEqualTo(layout.buttonSize + 5.99),
                  );
                }
                if (title) expect(rect.overlaps(layout.badge), isFalse);
              }
            }
          }
        }
      }
    },
  );
  test('ten actions occupy compact curved arcs with a clear center', () {
    const center = Offset(500, 400);
    final layout = ArchitectRadialLayout.compute(
      size: const Size(1000, 800),
      center: center,
      count: 10,
    );
    expect(
      layout.targets
          .map((p) => (p - center).distance.toStringAsFixed(3))
          .toSet(),
      allOf(hasLength(greaterThan(1)), hasLength(lessThanOrEqualTo(3))),
    );
    expect(
      layout.targets.map((p) => p.dy.toStringAsFixed(3)).toSet().length,
      greaterThan(2),
    );
    expect(layout.targets.every((p) => (p - center).distance > 60), isTrue);
    expect(layout.badge.width, 6);
    expect(layout.occupied, hasLength(11));
  });
  test(
    'fan avoids a selected wall or slab when surrounding space is available',
    () {
      for (final element in [
        const Rect.fromLTWH(440, 60, 20, 580),
        const Rect.fromLTWH(380, 260, 140, 180),
      ]) {
        final layout = ArchitectRadialLayout.compute(
          size: const Size(900, 700),
          center: const Offset(450, 350),
          count: 12,
          hasTitle: true,
          elementBounds: [element],
        );
        for (final target in layout.targets) {
          expect(
            Rect.fromCenter(
              center: target,
              width: layout.buttonSize,
              height: layout.buttonSize,
            ).overlaps(element),
            isFalse,
          );
        }
        expect(layout.badge.overlaps(element), isFalse);
      }
    },
  );
  test('short viewports scroll the fan instead of shrinking touch targets', () {
    final layout = ArchitectRadialLayout.compute(
      size: const Size(320, 140),
      center: const Offset(160, 70),
      count: 16,
      hasTitle: true,
    );
    expect(layout.targets, hasLength(16));
    expect(layout.contentHeight, greaterThan(140));
    expect(layout.buttonSize, greaterThanOrEqualTo(44));
  });

  testWidgets('all actions remain reachable in a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 140);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final l = await AppLocalizations.delegate.load(const Locale('bg'));
    BimEditAction? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchitectRadialMenu(
            center: const Offset(160, 70),
            title: l.architectToolWall,
            items: [
              for (final action in BimEditAction.values)
                ArchitectRadialMenuItem(
                  action: action,
                  icon: BimEditActions.icon(action),
                  label: BimEditActions.label(action, l),
                  color: Colors.cyan,
                ),
            ],
            onActionSelected: (action) => selected = action,
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('architect-radial-scroll')),
      findsOneWidget,
    );
    for (final action in BimEditAction.values) {
      final button = find.byKey(ValueKey('architect-radial-${action.name}'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      expect(selected, action);
    }
    expect(tester.takeException(), isNull);
  });

  for (final language in ['bg', 'en']) {
    for (final phone in [true, false]) {
      testWidgets(
        'localized fan is visible and all actions work ($language / $phone)',
        (tester) async {
          final size = phone ? const Size(360, 640) : const Size(900, 700);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final l = await AppLocalizations.delegate.load(Locale(language));
          final boundary = GlobalKey();
          final center = Offset(size.width / 2, size.height * .55);
          final selected = Rect.fromCenter(
            center: center,
            width: phone ? 150 : 180,
            height: 160,
          );
          final items = [
            for (final action in BimEditAction.values)
              ArchitectRadialMenuItem(
                action: action,
                icon: BimEditActions.icon(action),
                label: BimEditActions.label(action, l),
                color: action == BimEditAction.delete
                    ? Colors.redAccent
                    : Colors.cyan,
              ),
          ];
          BimEditAction? selectedAction;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: const Color(0xFFF5F6F8),
                        child: CustomPaint(painter: _SelectedSlab(selected)),
                      ),
                      ArchitectRadialMenu(
                        center: center,
                        items: items,
                        elementBounds: [selected],
                        title: phone ? null : l.architectToolSlab,
                        onActionSelected: (action) => selectedAction = action,
                        onDismiss: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final item in items) {
            final button = find.byKey(
              ValueKey('architect-radial-${item.action.name}'),
            );
            final rect = tester.getRect(button);
            expect(
              (Offset.zero & size).contains(rect.topLeft) &&
                  (Offset.zero & size).contains(rect.bottomRight),
              isTrue,
            );
            await tester.tap(button);
            await tester.pump();
            expect(selectedAction, item.action);
          }
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('build/architect_radial_fan')
              ..createSync(recursive: true);
            File(
              '${folder.path}/$language-${phone ? 'phone' : 'desktop'}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        },
      );
    }
  }
}

class _SelectedSlab extends CustomPainter {
  final Rect rect;
  _SelectedSlab(this.rect);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE1E4E8)
      ..strokeWidth = .5;
    for (var x = 0.0; x < size.width; x += 25) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 25) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawRect(rect, Paint()..color = const Color(0xFFE0F2F1));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF00796B)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_SelectedSlab oldDelegate) => oldDelegate.rect != rect;
}
