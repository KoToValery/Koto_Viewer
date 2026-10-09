import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/screens/bim_alignment_screen.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';

void main() {
  testWidgets(
    'Visible alignment controls add, edit, automatically sort and remove floors',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory temp;
      late BimWorkProject project;
      late BimProjectLibraryService lib;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('alignment_controls_');
        lib = BimProjectLibraryService(customRootDir: temp);
        project = await lib.createProject(
          name: 'P',
          storeys: const [
            BimStoreyUnderlay(storeyId: 's0', name: 'S0', elevation: 0),
          ],
        );
      });
      addTearDown(() async => temp.delete(recursive: true));
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BimAlignmentScreen(project: project, libraryService: lib),
          ),
        );
        Future<void> finishIo() async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          await tester.pumpAndSettle();
        }

        await finishIo();
        final add = find.byKey(const ValueKey('bim-add-storey'));
        final remove = find.byKey(const ValueKey('bim-remove-storey'));
        expect(add, findsOneWidget);
        expect(tester.widget<TextButton>(remove).onPressed, isNull);
        expect(find.text(l.bimProjectSortStoreys), findsNothing);
        await tester.tap(add);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '-3,20');
        await tester.tap(find.widgetWithText(FilledButton, l.save));
        await finishIo();
        var current = (await lib.loadProject(project.id))!;
        expect(current.storeys.map((s) => s.elevation), [-3.2, 0]);
        await tester.tap(
          find.widgetWithText(TextButton, l.bimProjectEditElevation),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '2,85');
        await tester.tap(find.widgetWithText(FilledButton, l.save));
        await finishIo();
        current = (await lib.loadProject(project.id))!;
        expect(current.storeys.last.storeyId, 's0');
        expect(current.storeys.last.elevation, 2.85);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, l.delete));
        await finishIo();
        current = (await lib.loadProject(project.id))!;
        final structural = (await lib.loadStructuralProject(project.id))!;
        expect(
          structural.storeys.map((s) => s.id),
          current.storeys.map((s) => s.storeyId),
        );
        expect(current.storeys.length, 1);
        expect(current.storeys.single.elevation, -3.2);
        expect(tester.widget<TextButton>(remove).onPressed, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );
}
