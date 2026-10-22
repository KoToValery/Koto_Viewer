import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('$kind: taps select/deselect, holds place, X exits', (
      tester,
    ) async {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 's',
          columns: [ArchitectColumn(id: 'c', position: Offset.zero)],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      workspace.camera(tester).fit(const Rect.fromLTRB(-5, -5, 5, 5));
      await tester.pumpAndSettle();
      await editing.selectTool(tester, 'column');
      await tester.tapAt(workspace.screen(tester, Offset.zero), kind: kind);
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, 'c');
      expect(model.project.activeStorey.columns, hasLength(1));

      final empty =
          workspace.screen(tester, Offset.zero) + const Offset(150, 120);
      await tester.tapAt(empty, kind: kind);
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, isNull);
      expect(model.project.activeStorey.columns, hasLength(1));
      await tester.tapAt(empty, kind: kind);
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.columns, hasLength(1));

      final held = await tester.startGesture(empty, kind: kind);
      await tester.pump(const Duration(milliseconds: 281));
      await held.up();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.columns, hasLength(2));
      final placed = model.project.activeStorey.columns.last;
      expect(workspace.overlay(tester).columnPreview, isNull);
      final cancel = find.byKey(const ValueKey('architect-draft-cancel'));
      expect(cancel, findsOneWidget);
      expect(
        tester.getRect(cancel).bottom,
        lessThan(
          workspace.screen(tester, placed.position).dy -
              placed.depth / 2 * workspace.camera(tester).scale,
        ),
      );
      final icon = tester.widget<Icon>(
        find.descendant(of: cancel, matching: find.byIcon(Icons.close)),
      );
      expect(icon.color, Colors.red);

      // Repeated taps on the just-created column never place another one.
      await tester.tapAt(workspace.screen(tester, placed.position), kind: kind);
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, placed.id);
      expect(model.project.activeStorey.columns, hasLength(2));
      await tester.tapAt(empty + const Offset(150, 0), kind: kind);
      await tester.pumpAndSettle();
      expect(cancel, findsOneWidget);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).activeTool, ArchitectTool.select);
      expect(cancel, findsNothing);
      expect(model.project.activeStorey.columns, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }

  for (final shape in ColumnShape.values) {
    test(
      '$shape: designation fits inside; dimension outside at equal size',
      () {
        for (final size in [.12, .25, .8]) {
          for (final zoom in [5.0, 40.0, 200.0]) {
            final canvas = ArchitectVectorCanvas();
            final column = ArchitectColumn(
              id: 'c',
              position: Offset.zero,
              shape: shape,
              width: size,
              depth: size * .6,
              label: 'C123456',
            );
            ArchitectTextScope(
              const ArchitectDocument(),
              'plan:s',
              50,
              zoom,
            ).run(() => column.paint2D(canvas: canvas, zoomScale: zoom));
            final texts = canvas.operations
                .whereType<ArchitectVectorText>()
                .toList();
            expect(texts, hasLength(2));
            final name = texts.firstWhere((t) => t.text == column.label);
            final dimension = texts.firstWhere((t) => t.role == 'dimension');
            final box = Rect.fromCenter(
              center: Offset.zero,
              width: size,
              height: shape == ColumnShape.circular ? size : size * .6,
            );
            expect(box.contains(name.bounds.topLeft), isTrue);
            expect(box.contains(name.bounds.bottomRight), isTrue);
            if (shape == ColumnShape.circular) {
              for (final corner in [
                name.bounds.topLeft,
                name.bounds.topRight,
                name.bounds.bottomLeft,
                name.bounds.bottomRight,
              ]) {
                expect(corner.distance, lessThan(size / 2));
              }
            }
            expect(dimension.bounds.left, greaterThan(box.right));
            expect(dimension.size, closeTo(name.size, 1e-10));
            // Both labels have transparent backgrounds, including inside the
            // column: no fills, hatch, crosshair, or dimension masks.
            final paths = canvas.operations
                .whereType<ArchitectVectorPath>()
                .toList();
            expect(paths.where((p) => !p.fill), hasLength(1));
            expect(paths.where((p) => p.fill), isEmpty);
          }
        }
      },
    );
  }
}
