import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('ArchitectElementPropertiesDialog renders door properties without RenderFlex overflow in narrow viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));

    final door = ArchitectDoor(
      id: 'door-1',
      wallId: 'wall-1',
      offsetRatio: 0.5,
      width: 0.9,
      height: 2.0,
      sillHeight: 0.0,
      isHingeLeft: true,
      openInward: true,
      specId: '3',
      uuid: 'UUID-DOOR-1',
    );

    final wall = ArchitectWall(
      id: 'wall-1',
      startPoint: const Offset(0, 0),
      endPoint: const Offset(5, 0),
      thickness: 0.25,
      doors: [door],
    );

    final now = DateTime.now();
    final project = ArchitectProject(
      id: 'proj-1',
      name: 'Test Project',
      createdAt: now,
      updatedAt: now,
      storeys: [
        ArchitectStorey(
          id: 'storey-1',
          name: 'Storey 1',
          walls: [wall],
        ),
      ],
      activeStoreyId: 'storey-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ArchitectElementPropertiesDialog(
            project: project,
            elementIds: {'door-1'},
            onApply: (_, _) => true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ArchitectElementPropertiesDialog), findsOneWidget);
  });
}
