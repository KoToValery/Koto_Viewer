import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_grid_axis_tool.dart';

void main() {
  group('Architect Dynamic Grid Axes Engine Tests', () {
    test('Starter project initializes with default grid axes', () {
      final project = ArchitectProject.starter(
        name: 'Test Project',
        axesX: 4,
        axesY: 3,
        spacingX: 4.0,
        spacingY: 5.0,
      );

      expect(project.gridAxes.length, equals(7)); // 4 vertical + 3 horizontal
      expect(project.gridAxes.any((a) => a.name == '1'), isTrue);
      expect(project.gridAxes.any((a) => a.name == 'A'), isTrue);
    });

    test('Auto-naming vertical axes as numbers and horizontal as letters', () {
      final axes = <StructuralGridAxis>[];

      // Vertical axis (start (0,0) -> end (0,10))
      final nameV1 = ArchitectGridAxisTool.getSuggestedAxisName(
        const Offset(0, 0),
        const Offset(0, 10),
        axes,
        true, // Bulgarian
      );
      expect(nameV1, equals('1'));

      // Add axis 1
      axes.add(StructuralGridAxis(
        id: 'ax1',
        name: nameV1,
        start: const Offset(0, 0),
        end: const Offset(0, 10),
      ));

      // Next vertical axis (at x=4)
      final nameV2 = ArchitectGridAxisTool.getSuggestedAxisName(
        const Offset(4, 0),
        const Offset(4, 10),
        axes,
        true,
      );
      expect(nameV2, equals('2'));

      // Horizontal axis (start (0,0) -> end (10,0))
      final nameH1 = ArchitectGridAxisTool.getSuggestedAxisName(
        const Offset(0, 0),
        const Offset(10, 0),
        axes,
        true, // Bulgarian: 'А'
      );
      expect(nameH1, equals('А'));

      // Horizontal axis in English: 'A'
      final nameH1En = ArchitectGridAxisTool.getSuggestedAxisName(
        const Offset(0, 0),
        const Offset(10, 0),
        axes,
        false, // English: 'A'
      );
      expect(nameH1En, equals('A'));
    });

    test('Resequence auto-numbers and renumbers parallel axes sequentially', () {
      final unorganizedAxes = [
        const StructuralGridAxis(
          id: 'v_far',
          name: '99',
          start: Offset(8, 0),
          end: Offset(8, 12),
        ),
        const StructuralGridAxis(
          id: 'v_near',
          name: '5',
          start: Offset(2, 0),
          end: Offset(2, 12),
        ),
        const StructuralGridAxis(
          id: 'h_top',
          name: 'Z',
          start: Offset(0, 6),
          end: Offset(10, 6),
        ),
        const StructuralGridAxis(
          id: 'h_bot',
          name: 'Q',
          start: Offset(0, 1),
          end: Offset(10, 1),
        ),
      ];

      final resequenced = ArchitectGridAxisTool.resequenceAxes(unorganizedAxes, true);

      final vNear = resequenced.firstWhere((a) => a.id == 'v_near');
      final vFar = resequenced.firstWhere((a) => a.id == 'v_far');
      final hBot = resequenced.firstWhere((a) => a.id == 'h_bot');
      final hTop = resequenced.firstWhere((a) => a.id == 'h_top');

      expect(vNear.name, equals('1'));
      expect(vFar.name, equals('2'));
      expect(hBot.name, equals('А'));
      expect(hTop.name, equals('Б'));
    });

    test('Auto-align extents aligns parallel axes start and end coordinates', () {
      final a1 = const StructuralGridAxis(
        id: 'a1',
        name: '1',
        start: Offset(0, -2),
        end: Offset(0, 15),
      );
      final a2 = const StructuralGridAxis(
        id: 'a2',
        name: '2',
        start: Offset(4, 0), // Shorter
        end: Offset(4, 10), // Shorter
      );

      final alignedA2 = a2.alignWith(a1);

      expect(alignedA2.start.dy, closeTo(-2.0, 1e-4));
      expect(alignedA2.end.dy, closeTo(15.0, 1e-4));
      expect(alignedA2.start.dx, closeTo(4.0, 1e-4));
      expect(alignedA2.end.dx, closeTo(4.0, 1e-4));
    });

    test('Offset duplication creates new axis with correct offset vector', () {
      final tool = ArchitectGridAxisTool();
      final project = ArchitectProject.starter(name: 'Offset Test', axesX: 2, axesY: 2);

      final origAxis = project.gridAxes.firstWhere((a) => a.name == '1');
      expect(origAxis.isVertical, isTrue);

      // Duplicate 3 meters to the right (+1.0)
      final (updatedProj, newAxis) = tool.applyOffset(
        project: project,
        originalAxis: origAxis,
        distanceMeters: 3.0,
        directionSign: 1.0,
        isBulgarian: true,
      );

      expect(updatedProj.gridAxes.length, equals(project.gridAxes.length + 1));
      expect(newAxis.start.dx, closeTo(origAxis.start.dx + 3.0, 1e-4));
      expect(newAxis.end.dx, closeTo(origAxis.end.dx + 3.0, 1e-4));
      expect(tool.selectedAxisId, equals(newAxis.id));
    });

    test('Moving an axis translates coordinates and re-sequences correctly', () {
      final tool = ArchitectGridAxisTool();
      final project = ArchitectProject.starter(name: 'Move Test', axesX: 2, axesY: 2);

      final axisToMove = project.gridAxes.firstWhere((a) => a.name == '1');
      tool.startMoving(axisToMove, axisToMove.start);
      tool.updateMoving(axisToMove.start + const Offset(1.5, 0), project.gridAxes, 40.0);

      final updatedProj = tool.commitMoving(project, true);
      expect(updatedProj, isNotNull);

      final moved = updatedProj!.gridAxes.firstWhere((a) => a.id == axisToMove.id);
      expect(moved.start.dx, closeTo(axisToMove.start.dx + 1.5, 1e-4));
      expect(moved.end.dx, closeTo(axisToMove.end.dx + 1.5, 1e-4));
    });

    test('Drafting and committing a new axis in the workspace', () {
      final tool = ArchitectGridAxisTool();
      var project = ArchitectProject.starter(name: 'Draft Test', axesX: 0, axesY: 0);

      expect(project.gridAxes.isEmpty, isTrue);

      // Start drafting from (5, -1) to (5, 12)
      tool.startDrafting(const Offset(5, -1));
      tool.updateDrafting(const Offset(5, 12), project, 40.0);

      final result = tool.commitDrafting(project: project, isBulgarian: true);
      expect(result, isNotNull);

      final (updatedProj, axis) = result!;
      expect(updatedProj.gridAxes.length, equals(1));
      expect(axis.name, equals('1'));
      expect(axis.isVertical, isTrue);
    });
  });
}
