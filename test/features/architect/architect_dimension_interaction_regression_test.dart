import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_layout.dart';
import 'package:kotoview/src/features/architect/services/architect_dimension_chain.dart';
import 'architect_dimension_chain_test.dart' as dimensions;
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Exterior row geometry stays fixed through zoom on either side', () {
    for (final offset in [-1.0, 1.0]) {
      final dimension = ArchitectDimensionChain.build(
        id: 'd',
        direction: const Offset(1, 0),
        offset: offset,
        anchors: const [
          ArchitectDimensionAnchor(point: Offset(0, 0)),
          ArchitectDimensionAnchor(point: Offset(3, 0)),
          ArchitectDimensionAnchor(point: Offset(6, 0)),
          ArchitectDimensionAnchor(point: Offset(1, 0), feature: 'opening'),
          ArchitectDimensionAnchor(point: Offset(2, 0), feature: 'opening'),
        ],
      );
      final reference = ArchitectDimensionLayout.layoutTiers(
        dimension: dimension,
        scale: 100,
      );
      expect(reference, hasLength(3));
      for (final zoom in [10.0, 25.0, 50.0, 100.0, 300.0]) {
        final tiers = ArchitectDimensionLayout.layoutTiers(
          dimension: dimension,
          scale: zoom,
        );
        expect(tiers.map((t) => t.line), reference.map((t) => t.line));
        expect(
          ArchitectDimensionChain.dot(
            tiers[1].line.$1 - tiers[0].line.$1,
            dimension.normal,
          ).abs(),
          closeTo(.45, 1e-9),
        );
      }
    }
  });

  test('Opposite vertical pick directions have the same text orientation', () {
    expect(
      ArchitectDimensionLayout.textAngle(const Offset(0, 1)),
      closeTo(-math.pi / 2, 1e-9),
    );
    expect(
      ArchitectDimensionLayout.textAngle(const Offset(0, -1)),
      closeTo(-math.pi / 2, 1e-9),
    );
    expect(ArchitectDimensionLayout.textAngle(const Offset(-1, 0)), 0);
  });

  for (final style in ['chain', 'interior']) {
    testWidgets('$style snaps the second and third picks to edges', (
      tester,
    ) async {
      final storey = ArchitectStorey(
        id: 's',
        name: 'Floor',
        cadPrimitives: [
          for (var i = 0; i < 3; i++)
            ArchitectCadPrimitive(
              id: 'edge$i',
              type: CadPrimitiveType.line,
              startPoint: Offset(0, i * 2.0),
              endPoint: Offset(8, i * 2.0),
            ),
        ],
      );
      final model = editing.seeded(storey);
      addTearDown(model.dispose);
      await dimensions.startChain(tester, model);
      if (style == 'interior') {
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-interior')),
        );
        await tester.pump();
      }
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: workspace.screen(tester, const Offset(1.3, .01)),
      );
      for (var i = 0; i < 3; i++) {
        final target = Offset(1.3 + i * 2.2, i * 2.0 + .01);
        await mouse.moveTo(workspace.screen(tester, target));
        await tester.pump();
        expect(
          workspace.overlay(tester).activeSnapLabel,
          anyOf('Edge', 'Nearest'),
        );
        await workspace.wallTap(tester, target);
      }
      await mouse.removePointer();
      final anchors = dimensions.preview(tester)!.anchors;
      expect(anchors, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(anchors[i].point.dy, closeTo(i * 2.0, 1e-9));
        expect(anchors[i].elementId, 'edge$i');
      }
    });

    for (final useMoveAction in [false, true]) {
      testWidgets(
        '$style drags with dimension tool active (move=$useMoveAction)',
        (tester) async {
          final storey = dimensions.scene();
          final original = dimensions
              .chain(storey)
              .copyWith(
                style: style == 'interior'
                    ? ArchitectDimensionStyle.interior
                    : ArchitectDimensionStyle.exterior,
              );
          final model = editing.seeded(storey.copyWith(dimensions: [original]));
          addTearDown(model.dispose);
          await dimensions.startChain(tester, model);
          // A hold selects an existing dimension without starting a new chain.
          final start =
              (original.lineStart + original.lineEnd) / 2 + const Offset(.6, 0);
          await tester.longPressAt(workspace.screen(tester, start));
          await tester.pumpAndSettle();
          expect(workspace.overlay(tester).selectedElementIds, {original.id});
          if (useMoveAction) {
            await tester.tap(
              find.byKey(const ValueKey('architect-selection-move')),
            );
            await tester.pump();
          }
          final drag = await tester.startGesture(
            workspace.screen(tester, start),
          );
          await drag.moveTo(
            workspace.screen(tester, start + const Offset(.3, -.7)),
          );
          await tester.pump();
          await drag.up();
          await tester.pump();
          final moved = model.project.activeStorey.dimensions.single;
          expect(moved.lineStart.dy, closeTo(original.lineStart.dy - .7, .03));
          expect(
            moved.anchors.map((a) => a.toJson()),
            original.anchors.map((a) => a.toJson()),
          );
          expect(model.undoCount, 1);
          model.undo();
          expect(
            model.project.activeStorey.dimensions.single.lineStart,
            original.lineStart,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test(
    'Polygon edge references retain their position through save and geometry edits',
    () {
      const rectangle = ArchitectCadPrimitive(
        id: 'rect',
        type: CadPrimitiveType.rect,
        startPoint: Offset(0, 0),
        endPoint: Offset(6, 4),
      );
      final project = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 'Floor',
          cadPrimitives: [rectangle],
        ),
      );
      addTearDown(project.dispose);
      final anchor = ArchitectDimensionChain.pickElement(
        project.project,
        'rect',
        const Offset(2, 0),
      )!;
      expect(anchor.feature, 'edgePoint');
      expect(anchor.point, const Offset(2, 0));
      final loaded = ArchitectDimensionAnchor.fromJson(anchor.toJson());
      final changed = rectangle.copyWith(endPoint: const Offset(12, 4));
      expect(
        ArchitectDimensionChain.resolveAnchor(
          loaded,
          project.project.activeStorey,
          {'rect': changed.toJson()},
        ),
        const Offset(4, 0),
      );
    },
  );
}
