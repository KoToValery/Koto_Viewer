import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_layers_dialog.dart';
import 'architect_elevation_ui_test.dart' as qa;

void main() {
  setUpAll(qa.loadQaFonts);
  for (final language in ['bg', 'en']) {
    testWidgets(
      'phone manual support saves and returns to automatic ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        double? distance;
        var applied = 0;
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'TestReadable', useMaterial3: true),
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const ValueKey('open'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => ArchitectRoofLayersDialog(
                        initialAssembly: ArchitectRoofAssembly.fromPreset(
                          ArchitectRoofPreset.pitchedTiles,
                        ),
                        initialSlopeDegrees: 25,
                        initialEavesOverhang: .5,
                        initialEavesCut: ArchitectRoofEavesCut.plumb,
                        initialManualSupportDistance: distance,
                        maxSupportDistance: 5,
                        onApply: (result) {
                          distance = result.manualSupportDistance;
                          applied++;
                        },
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.byKey(const ValueKey('open')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('roof-manual-support')),
          );
          await tester.pumpAndSettle();
        }

        Future<void> toggle() async {
          await tester.tap(find.byKey(const ValueKey('roof-manual-support')));
          await tester.pumpAndSettle();
        }

        final apply = find.byKey(const ValueKey('roof-layers-apply'));
        await open();
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('roof-manual-support')),
              )
              .value,
          isFalse,
        );
        await toggle();
        final field = find.descendant(
          of: find.byKey(const ValueKey('roof-support-distance')),
          matching: find.byType(TextFormField),
        );
        expect(field, findsOneWidget);
        await tester.ensureVisible(field);
        await tester.enterText(field, '-5');
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(applied, 0);
        final l = AppLocalizations.of(tester.element(field))!;
        expect(
          find.text(l.architectRoofSupportDistanceInvalid),
          findsOneWidget,
        );
        await tester.enterText(field, '125,5');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.text(l.architectRoofSupportDistanceInvalid), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('roof-manual-support')),
        );
        await tester.pumpAndSettle();
        await qa.capturePhone(tester, capture, 'roof-manual-support-$language');
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(distance, closeTo(1.255, 1e-6));
        expect(applied, 1);
        await open();
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('roof-manual-support')),
              )
              .value,
          isTrue,
        );
        expect(tester.widget<TextFormField>(field).controller!.text, '125.5');
        await toggle();
        expect(field, findsNothing);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(distance, isNull);
        expect(applied, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
