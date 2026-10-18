import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_column_snap.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';

void main() {
  group('Architect Column Snapping to Openings Tests', () {
    const wallStart = Offset(0, 0);
    const wallEnd = Offset(10, 0);
    const wallThickness = 0.25;

    final door = ArchitectDoor(
      id: 'door_1',
      wallId: 'wall_1',
      offsetRatio: 0.5, // Center at (5.0, 0.0)
      width: 0.90, // Jambs at 4.55 and 5.45
      height: 2.0,
      uuid: 'UUID-D1',
    );

    final window = ArchitectWindow(
      id: 'win_1',
      wallId: 'wall_1',
      offsetRatio: 0.2, // Center at (2.0, 0.0)
      width: 1.20, // Jambs at 1.40 and 2.60
      height: 1.40,
      uuid: 'UUID-W1',
    );

    final wall = ArchitectWall(
      id: 'wall_1',
      startPoint: wallStart,
      endPoint: wallEnd,
      thickness: wallThickness,
      doors: [door],
      windows: [window],
    );

    final storey = ArchitectStorey(
      id: 'storey_1',
      name: 'Ground Floor',
      walls: [wall],
    );

    final project = ArchitectProject(
      id: 'proj_1',
      name: 'Test Project',
      storeys: [storey],
      activeStoreyId: 'storey_1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('ArchitectColumnSnap snaps column flush against door left & right jambs', () {
      // Column: 0.25 x 0.25 m. Half-width = 0.125 m.
      // Left jamb of door = 5.0 - 0.45 = 4.55.
      // Flush left position = 4.55 - 0.125 = 4.425 m.
      final snapLeft = ArchitectColumnSnap.resolve(
        raw: const Offset(4.40, 0.02),
        project: project,
        columnWidth: 0.25,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.20,
      );

      expect(snapLeft.isSnapped, isTrue);
      expect(snapLeft.snapLabel, equals('Door jamb'));
      expect((snapLeft.point.dx - 4.425).abs() < 1e-4, isTrue);
      expect(snapLeft.point.dy.abs() < 1e-4, isTrue);
      expect(snapLeft.angleDeg, closeTo(0.0, 1e-4));
      expect(snapLeft.magneticGuides.length, equals(2));

      // Right jamb of door = 5.0 + 0.45 = 5.45.
      // Flush right position = 5.45 + 0.125 = 5.575 m.
      final snapRight = ArchitectColumnSnap.resolve(
        raw: const Offset(5.60, -0.01),
        project: project,
        columnWidth: 0.25,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.20,
      );

      expect(snapRight.isSnapped, isTrue);
      expect(snapRight.snapLabel, equals('Door jamb'));
      expect((snapRight.point.dx - 5.575).abs() < 1e-4, isTrue);
      expect(snapRight.point.dy.abs() < 1e-4, isTrue);
      expect(snapRight.angleDeg, closeTo(0.0, 1e-4));
    });

    test('ArchitectColumnSnap snaps column flush against window left & right jambs', () {
      // Window: center at 2.0, width 1.20 m.
      // Left jamb = 2.0 - 0.60 = 1.40 m.
      // Flush left position = 1.40 - 0.125 = 1.275 m.
      final snapLeft = ArchitectColumnSnap.resolve(
        raw: const Offset(1.30, 0.03),
        project: project,
        columnWidth: 0.25,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.20,
      );

      expect(snapLeft.isSnapped, isTrue);
      expect(snapLeft.snapLabel, equals('Window jamb'));
      expect((snapLeft.point.dx - 1.275).abs() < 1e-4, isTrue);
      expect(snapLeft.point.dy.abs() < 1e-4, isTrue);

      // Right jamb = 2.0 + 0.60 = 2.60 m.
      // Flush right position = 2.60 + 0.125 = 2.725 m.
      final snapRight = ArchitectColumnSnap.resolve(
        raw: const Offset(2.70, 0.0),
        project: project,
        columnWidth: 0.25,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.20,
      );

      expect(snapRight.isSnapped, isTrue);
      expect(snapRight.snapLabel, equals('Window jamb'));
      expect((snapRight.point.dx - 2.725).abs() < 1e-4, isTrue);
      expect(snapRight.point.dy.abs() < 1e-4, isTrue);
    });

    test('ArchitectSnapGeometry indexes door & window jamb points and edges', () {
      final snapGeom = ArchitectSnapGeometry.of(project);
      final points = snapGeom.query(const Offset(4.55, 0.0), 0.05).toList();
      expect(points.any((p) => p.label == 'Door jamb'), isTrue);

      final winPoints = snapGeom.query(const Offset(1.40, 0.0), 0.05).toList();
      expect(winPoints.any((p) => p.label == 'Window jamb'), isTrue);
    });
  });

  group('Architect Column Label & Auto-numbering Tests', () {
    test('ArchitectElementTool.nextColumnLabel generates sequential labels', () {
      expect(ArchitectElementTool.nextColumnLabel([]), equals('C1'));

      final col1 = const ArchitectColumn(id: 'c1', position: Offset.zero, label: 'C1');
      expect(ArchitectElementTool.nextColumnLabel([col1]), equals('C2'));

      final col2 = const ArchitectColumn(id: 'c2', position: Offset.zero, label: 'C2');
      expect(ArchitectElementTool.nextColumnLabel([col1, col2]), equals('C3'));

      // Preserves custom / localized prefix like 'К'
      final colK1 = const ArchitectColumn(id: 'k1', position: Offset.zero, label: 'К1');
      final colK2 = const ArchitectColumn(id: 'k2', position: Offset.zero, label: 'К2');
      expect(ArchitectElementTool.nextColumnLabel([colK1, colK2]), equals('К3'));
    });

    test('ArchitectColumn paint2D executes cleanly at various zoom scales without error', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      const col = ArchitectColumn(
        id: 'col_test',
        position: Offset(10, 10),
        width: 0.25,
        depth: 0.25,
        label: 'C1',
      );

      // Normal zoom
      col.paint2D(canvas: canvas, zoomScale: 100.0);

      // Zoomed out (distant view)
      col.paint2D(canvas: canvas, zoomScale: 15.0);

      // Very far zoom out
      col.paint2D(canvas: canvas, zoomScale: 5.0);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
