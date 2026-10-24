import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_marquee_tool.dart';

void main() {
  group('ArchitectMarqueeTool', () {
    late ArchitectProject project;
    late ArchitectStorey storey;

    setUp(() {
      storey = ArchitectStorey(
        id: 'storey-1',
        name: 'Floor 1',
        elevation: 0.0,
        height: 2.8,
        walls: [
          // Inside rectangle [0,0] -> [5,5]
          const ArchitectWall(
            id: 'wall-inside',
            startPoint: Offset(1, 1),
            endPoint: Offset(4, 1),
          ),
          // Crossing rectangle boundary x=5
          const ArchitectWall(
            id: 'wall-crossing',
            startPoint: Offset(3, 3),
            endPoint: Offset(7, 3),
          ),
          // Completely outside rectangle
          const ArchitectWall(
            id: 'wall-outside',
            startPoint: Offset(10, 10),
            endPoint: Offset(15, 10),
          ),
        ],
        columns: [
          // Inside
          const ArchitectColumn(
            id: 'col-inside',
            position: Offset(2, 2),
            width: 0.3,
            depth: 0.3,
          ),
          // Outside
          const ArchitectColumn(
            id: 'col-outside',
            position: Offset(12, 12),
            width: 0.3,
            depth: 0.3,
          ),
        ],
        slabs: [
          // Partially inside
          const ArchitectSlab(
            id: 'slab-inside',
            polygon: [
              Offset(0.5, 0.5),
              Offset(2.5, 0.5),
              Offset(2.5, 2.5),
              Offset(0.5, 2.5),
            ],
          ),
        ],
      );

      project = ArchitectProject(
        id: 'proj-1',
        name: 'Test Project',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        storeys: [storey],
        activeStoreyId: 'storey-1',
      );
    });

    test('1. Rectangular marquee selection correctly selects contained and intersecting elements', () {
      final tool = ArchitectMarqueeTool()..setMode(ArchitectSelectMode.rectangle);

      expect(tool.isDrafting, isFalse);

      // Start rectangle at (0, 0)
      tool.addPoint(const Offset(0, 0));
      expect(tool.isDrafting, isTrue);

      // Live candidate at (5, 5)
      tool.updateCandidate(const Offset(5, 5));
      final poly = tool.previewPolygon;
      expect(poly.length, 4);
      expect(poly[0], const Offset(0, 0));
      expect(poly[2], const Offset(5, 5));

      final hits = ArchitectMarqueeTool.evaluateSelection(
        storey: storey,
        project: project,
        polygon: poly,
      );

      // wall-inside is completely inside [0,0] -> [5,5]
      expect(hits.contains('wall-inside'), isTrue);
      // wall-crossing crosses x=5 boundary
      expect(hits.contains('wall-crossing'), isTrue);
      // col-inside is at (2, 2)
      expect(hits.contains('col-inside'), isTrue);
      // slab-inside is at [0.5, 0.5] -> [2.5, 2.5]
      expect(hits.contains('slab-inside'), isTrue);

      // Elements outside must NOT be selected
      expect(hits.contains('wall-outside'), isFalse);
      expect(hits.contains('col-outside'), isFalse);
    });

    test('2. Polygonal marquee selection selects elements within custom contour', () {
      final tool = ArchitectMarqueeTool()..setMode(ArchitectSelectMode.polygon);

      tool.addPoint(const Offset(0, 0));
      tool.addPoint(const Offset(5, 0));
      tool.addPoint(const Offset(5, 5));
      tool.addPoint(const Offset(0, 5));

      final poly = tool.previewPolygon;
      expect(poly.length, 4);

      final hits = ArchitectMarqueeTool.evaluateSelection(
        storey: storey,
        project: project,
        polygon: poly,
      );

      expect(hits.contains('wall-inside'), isTrue);
      expect(hits.contains('col-inside'), isTrue);
      expect(hits.contains('wall-outside'), isFalse);

      tool.cancel();
      expect(tool.isDrafting, isFalse);
      expect(tool.points, isEmpty);
    });

    test('3. Mode switching resets active draft', () {
      final tool = ArchitectMarqueeTool()..setMode(ArchitectSelectMode.rectangle);
      tool.addPoint(const Offset(1, 1));
      expect(tool.isDrafting, isTrue);

      tool.setMode(ArchitectSelectMode.polygon);
      expect(tool.mode, ArchitectSelectMode.polygon);
      expect(tool.isDrafting, isFalse);
      expect(tool.points, isEmpty);
    });

    test('4. Architect2dPainter renders draft marker and marquee preview cleanly', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final painter = Architect2dPainter(
        project: project,
        activeTool: ArchitectTool.select,
        activeDraftStart: const Offset(2, 2),
        marqueePoints: const [Offset(0, 0), Offset(5, 5)],
        marqueePolygon: const [
          Offset(0, 0),
          Offset(5, 0),
          Offset(5, 5),
          Offset(0, 5),
        ],
      );

      expect(() => painter.paint(canvas, const Size(800, 600)), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
