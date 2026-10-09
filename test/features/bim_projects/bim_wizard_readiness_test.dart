import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_projects/widgets/bim_new_project_wizard.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';

void main() {
  testWidgets('Create requires completed KCAD for every selected storey', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory temp;
    await tester.runAsync(
      () async => temp = await Directory.systemTemp.createTemp('wizard_ready_'),
    );
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final pending = Completer<BimConversionResult>();
    late void Function(BimConversionStage) progress;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BimNewProjectWizard(
            underlayPicker: (_) async => File('${temp.path}/plan.dxf'),
            underlayConverter: (_, update, _) {
              progress = update;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    bool enabled() =>
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('create-bim-project')),
            )
            .onPressed !=
        null;
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Quick Setup'), findsNothing);
    expect(find.text('Sort by elevation'), findsNothing);
    expect(enabled(), false);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Underlay'));
    await tester.pump();
    expect(enabled(), false);
    progress(BimConversionStage.analysing);
    await tester.pump();
    expect(enabled(), false);
    progress(BimConversionStage.ready);
    await tester.pump();
    expect(enabled(), false);
    pending.complete(
      BimConversionResult(
        directory: temp,
        sourceFile: File('${temp.path}/plan.dxf'),
        pureKcadFile: File('${temp.path}/pure.kcad'),
        kcadFile: File('${temp.path}/working.kcad'),
        sourceFingerprint: 'test',
      ),
    );
    await tester.pumpAndSettle();
    expect(enabled(), true);
    await tester.tap(find.text('Add Storey'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(enabled(), false);
    await tester.tap(find.byTooltip('Delete Storey').last);
    await tester.pumpAndSettle();
    expect(enabled(), true);
    // Dispose owned conversion result outside the fake clock.
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    expect(tester.takeException(), isNull);
  });
}
