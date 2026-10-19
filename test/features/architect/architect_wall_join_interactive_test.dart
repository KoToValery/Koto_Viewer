import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  testWidgets('Join wall: touch tap on second wall joins them', (tester) async {
    final a = editing.wall('a', const Offset(0, 0), const Offset(4, 0), exterior: true);
    final b = editing.wall('b', const Offset(5, 1), const Offset(5, 5), exterior: true);
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: 's', walls: [a, b]),
    );
    addTearDown(model.dispose);

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    );
    await tester.pumpAndSettle();

    await editing.selectTool(tester, 'wall');
    await tester.pumpAndSettle();

    await workspace.wallTap(tester, const Offset(2, 0));
    await tester.pumpAndSettle();

    final joinBtn = find.byKey(const ValueKey('architect-wall-join'));
    expect(joinBtn, findsOneWidget);

    await tester.tap(joinBtn);
    await tester.pumpAndSettle();

    expect(find.text('Изберете втора стена за съединяване'), findsOneWidget);

    await workspace.wallTap(tester, const Offset(5, 3));
    await tester.pumpAndSettle();

    final walls = model.project.activeStorey.walls;
    expect(walls[0].endPoint, const Offset(5, 0));
    expect(walls[1].startPoint, const Offset(5, 0));
    expect(find.text('Стените са съединени'), findsOneWidget);
  });

  testWidgets('Join wall: mouse click on second wall joins them', (tester) async {
    final a = editing.wall('a', const Offset(0, 0), const Offset(4, 0), exterior: true);
    final b = editing.wall('b', const Offset(5, 1), const Offset(5, 5), exterior: true);
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: 's', walls: [a, b]),
    );
    addTearDown(model.dispose);

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    );
    await tester.pumpAndSettle();

    await editing.selectTool(tester, 'wall');
    await tester.pumpAndSettle();

    await workspace.wallTap(tester, const Offset(2, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('architect-wall-join')));
    await tester.pumpAndSettle();

    final bScreen = workspace.screen(tester, const Offset(5, 3));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(bScreen);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final walls = model.project.activeStorey.walls;
    expect(walls[0].endPoint, const Offset(5, 0));
    expect(walls[1].startPoint, const Offset(5, 0));
    expect(find.text('Walls joined'), findsOneWidget);
  });

  testWidgets('Join wall: tapping on hosted opening in second wall still joins', (tester) async {
    final a = editing.wall('a', const Offset(0, 0), const Offset(4, 0), exterior: true);
    final b = editing.wall('b', const Offset(5, 1), const Offset(5, 5), exterior: true).addDoor(
      const ArchitectDoor(
        id: 'door1',
        wallId: 'b',
        offsetRatio: 0.5,
        uuid: 'door1',
      ),
    );
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: 's', walls: [a, b]),
    );
    addTearDown(model.dispose);

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    );
    await tester.pumpAndSettle();

    await editing.selectTool(tester, 'wall');
    await tester.pumpAndSettle();

    await workspace.wallTap(tester, const Offset(2, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('architect-wall-join')));
    await tester.pumpAndSettle();

    // Tap right where the door is on wall 'b' (at ratio 0.5 => y = 3)
    await workspace.wallTap(tester, const Offset(5, 3));
    await tester.pumpAndSettle();

    final walls = model.project.activeStorey.walls;
    expect(walls[0].endPoint, const Offset(5, 0));
    expect(walls[1].startPoint, const Offset(5, 0));
  });

  testWidgets('Join wall: tapping empty space cancels join mode gracefully', (tester) async {
    final a = editing.wall('a', const Offset(0, 0), const Offset(4, 0), exterior: true);
    final b = editing.wall('b', const Offset(5, 1), const Offset(5, 5), exterior: true);
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: 's', walls: [a, b]),
    );
    addTearDown(model.dispose);

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    );
    await tester.pumpAndSettle();

    await editing.selectTool(tester, 'wall');
    await tester.pumpAndSettle();

    await workspace.wallTap(tester, const Offset(2, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('architect-wall-join')));
    await tester.pumpAndSettle();

    expect(find.text('Изберете втора стена за съединяване'), findsOneWidget);

    // Tap empty space at (0, 3)
    await workspace.wallTap(tester, const Offset(0, 3));
    await tester.pumpAndSettle();

    // Join banner should be gone, no new walls created
    expect(find.text('Изберете втора стена за съединяване'), findsNothing);
    expect(model.project.activeStorey.walls, hasLength(2));
  });

  testWidgets('Join wall: incompatible parallel walls shows localized error', (tester) async {
    final a = editing.wall('a', const Offset(0, 0), const Offset(4, 0), exterior: true);
    final b = editing.wall('b', const Offset(0, 2), const Offset(4, 2), exterior: true);
    final model = editing.seeded(
      ArchitectStorey(id: 's', name: 's', walls: [a, b]),
    );
    addTearDown(model.dispose);

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    );
    await tester.pumpAndSettle();

    await editing.selectTool(tester, 'wall');
    await tester.pumpAndSettle();

    await workspace.wallTap(tester, const Offset(2, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('architect-wall-join')));
    await tester.pumpAndSettle();

    // Tap parallel wall 'b'
    await workspace.wallTap(tester, const Offset(2, 2));
    await tester.pumpAndSettle();

    expect(find.text('Стените не могат да се съединят'), findsOneWidget);
  });
}
