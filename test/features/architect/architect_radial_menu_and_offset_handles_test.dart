import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';

void main() {
  group('ArchitectRadialMenu Widget & Actions', () {
    testWidgets('Renders fan items and triggers onActionSelected callback', (
      tester,
    ) async {
      ArchitectRadialAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                ArchitectRadialMenu(
                  center: const Offset(200, 300),
                  items: const [
                    ArchitectRadialMenuItem(
                      action: ArchitectRadialAction.edit,
                      icon: Icons.edit,
                      label: 'Edit',
                      color: Colors.cyan,
                    ),
                    ArchitectRadialMenuItem(
                      action: ArchitectRadialAction.move,
                      icon: Icons.open_with,
                      label: 'Move',
                      color: Colors.amber,
                    ),
                    ArchitectRadialMenuItem(
                      action: ArchitectRadialAction.delete,
                      icon: Icons.delete,
                      label: 'Delete',
                      color: Colors.red,
                    ),
                  ],
                  onActionSelected: (action) => selectedAction = action,
                  onDismiss: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ArchitectRadialMenu), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(selectedAction, ArchitectRadialAction.edit);
    });
  });

  group('ArchitectPolygonEditor Offset Leader Handles', () {
    test(
      'Calculates outward offset handles and generates live leader line on drag',
      () {
        final editor = ArchitectPolygonEditor();
        final rect = [
          const Offset(0, 0),
          const Offset(4, 0),
          const Offset(4, 3),
          const Offset(0, 3),
        ];

        // Verify offset handles are outside polygon bounds
        final hv0 = ArchitectPolygonEditor.offsetVertexHandle(rect, 0, 1.0);
        final he0 = ArchitectPolygonEditor.offsetEdgeHandle(rect, 0, 1.0);

        // Vertex 0 bisector points away (dx < 0 or dy < 0)
        expect(hv0.dx <= 0 || hv0.dy <= 0, isTrue);

        // Edge 0 (y=0) normal points down in canvas coordinates (dy < 0)
        expect(he0.dy < 0, isTrue);

        // Starting drag directly from the offset handle
        final started = editor.start('test-rect', rect, he0, 1.0);
        expect(started, isTrue);
        expect(editor.isOffsetHandle, isTrue);

        // Dragging offset handle
        editor.update(
          he0 + const Offset(0, -1.0),
          (pt) => ArchitectSnapResult(point: pt),
          0.1,
        );

        final leader = editor.leaderLine;
        expect(leader, isNotNull);
        // The leader line starts from the actual edge and points to the dragged position
        expect(leader!.$2.dy < leader.$1.dy, isTrue);

        editor.cancel();
        expect(editor.active, isFalse);
        expect(editor.leaderLine, isNull);
      },
    );
  });

  group('ArchitectElementTool Transforms (Duplicate, Rotate, Flip)', () {
    final tool = ArchitectElementTool();

    test('Duplicates column with offset', () {
      const initial = ArchitectStorey(
        id: 's1',
        name: 'Storey 1',
        columns: [ArchitectColumn(id: 'col_1', position: Offset(2, 2))],
      );

      final (updated, newId) = tool.duplicateElementById(
        initial,
        'col_1',
        offset: const Offset(1, 1),
      );

      expect(newId, isNotNull);
      expect(updated.columns, hasLength(2));
      expect(updated.columns.last.id, newId);
      expect(updated.columns.last.position, const Offset(3, 3));
    });

    test('Rotates rectangular column by 90 degrees', () {
      const initial = ArchitectStorey(
        id: 's1',
        name: 'Storey 1',
        columns: [
          ArchitectColumn(
            id: 'col_1',
            position: Offset(2, 2),
            width: 0.25,
            depth: 0.50,
            rotationDeg: 0,
          ),
        ],
      );

      final updated = tool.rotateElementById(initial, 'col_1');
      final rotated = updated.columns.first;
      expect(rotated.width, 0.25);
      expect(rotated.depth, 0.50);
      expect(rotated.rotationDeg, 90.0);
    });

    test('Flips door hinge side', () {
      const initial = ArchitectStorey(
        id: 's1',
        name: 'Storey 1',
        walls: [
          ArchitectWall(
            id: 'w1',
            startPoint: Offset(0, 0),
            endPoint: Offset(5, 0),
            doors: [
              ArchitectDoor(
                id: 'd1',
                uuid: 'uuid_d1',
                wallId: 'w1',
                offsetRatio: 0.5,
                isHingeLeft: true,
              ),
            ],
          ),
        ],
      );

      final updated = tool.flipElementById(initial, 'd1');
      final door = updated.walls.first.doors.first;
      expect(door.isHingeLeft, isFalse);
    });
  });
}
