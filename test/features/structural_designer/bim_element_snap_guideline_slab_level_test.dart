import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BIM Structural Element Snapping & Guide Line Tests', () {
    test('StructuralColumn polygonVertices calculate corners from center', () {
      const col = StructuralColumn(
        id: 'col1',
        center: Offset(10.0, 10.0),
        width: 0.30,
        height: 0.40,
        rotationRad: 0.0,
      );

      final corners = col.polygonVertices;
      expect(corners.length, equals(4));
      // Top-Left corner: (10 - 0.15, 10 + 0.20) = (9.85, 10.20) in CAD coordinates
      expect(corners[0].dx, closeTo(9.85, 1e-4));
      expect(corners[0].dy, closeTo(10.20, 1e-4));

      // Top-Right corner: (10 + 0.15, 10 + 0.20) = (10.15, 10.20)
      expect(corners[1].dx, closeTo(10.15, 1e-4));
      expect(corners[1].dy, closeTo(10.20, 1e-4));

      // Bottom-Right corner: (10 + 0.15, 10 - 0.20) = (10.15, 9.80)
      expect(corners[2].dx, closeTo(10.15, 1e-4));
      expect(corners[2].dy, closeTo(9.80, 1e-4));

      // Bottom-Left corner: (10 - 0.15, 10 - 0.20) = (9.85, 9.80)
      expect(corners[3].dx, closeTo(9.85, 1e-4));
      expect(corners[3].dy, closeTo(9.80, 1e-4));
    });

    test('StructuralShearWall start, end, and 4 box corners represent its endpoints and corners', () {
      const wall = StructuralShearWall(
        id: 'w1',
        start: Offset(2.0, 5.0),
        end: Offset(6.0, 5.0),
        thickness: 0.25,
      );

      expect(wall.start, equals(const Offset(2.0, 5.0)));
      expect(wall.end, equals(const Offset(6.0, 5.0)));
      expect(wall.polygonVertices.length, equals(4));
    });

    test('StructuralPointerPainter paints the column insertion reference and pointer', () {
      const column = StructuralColumn(
        id: 'col_preview',
        center: Offset(100.0, 200.0),
        width: 30.0,
        height: 40.0,
      );

      final painter = StructuralPointerPainter(
        touchPos: const Offset(100.0, 300.0), // User finger at bottom
        targetPos: const Offset(100.0, 200.0), // Element center above finger
        activeTool: StructuralDrawTool.column,
        previewColumn: column,
        scale: 1.0,
      );

      // Verify painter compiles and paints without errors
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(500, 500));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('StructuralPointerPainter paints the wall insertion reference and pointer', () {
      final painter = StructuralPointerPainter(
        touchPos: const Offset(100.0, 300.0),
        targetPos: const Offset(100.0, 200.0),
        activeTool: StructuralDrawTool.shearWall,
        previewWallLengthScreen: 100.0,
        previewWallThicknessScreen: 20.0,
        previewWallRotationRad: 0.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(500, 500));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('Storey Ceiling Slab Level and Visibility Tests', () {
    test('Slab structural elevation at level 0.00 is above level 0.00 at ceiling level 2.80', () {
      const storey0 = StoreyLevel(
        id: 'st_0',
        name: 'Партер (Кота ±0.00)',
        elevation: 0.0,
        height: 2.80,
        floorFinishThickness: 0.05,
      );

      const slab = StructuralSlab(
        id: 'slab_ground',
        polygon: [
          Offset(0, 0),
          Offset(5, 0),
          Offset(5, 5),
          Offset(0, 5),
        ],
        thickness: 0.20,
      );

      // Ceiling of storey 0: concrete top is 0.00 + 2.80 - 0.05 = 2.75
      final elev = storey0.structuralElevationFor(slab);
      expect(elev, closeTo(2.75, 1e-4));

      final soffit = storey0.slabSoffitElevationFor(slab);
      expect(soffit, closeTo(2.55, 1e-4));
    });

    test('Slab structural elevation at level 2.80 is above level 2.80 at ceiling level 5.60', () {
      const storey1 = StoreyLevel(
        id: 'st_1',
        name: 'Етаж 1 (Кота +2.80)',
        elevation: 2.80,
        height: 2.80,
        floorFinishThickness: 0.05,
      );

      const slab = StructuralSlab(
        id: 'slab_1',
        polygon: [
          Offset(0, 0),
          Offset(5, 0),
          Offset(5, 5),
          Offset(0, 5),
        ],
        thickness: 0.20,
      );

      final elev = storey1.structuralElevationFor(slab);
      expect(elev, closeTo(5.55, 1e-4));
    });

    test('Structural2dPainter paints the active ceiling slab cleanly', () {
      const slabFloor2 = StructuralSlab(
        id: 'slab_lvl2',
        polygon: [
          Offset(0, 0),
          Offset(6, 0),
          Offset(6, 6),
          Offset(0, 6),
        ],
        thickness: 0.20,
      );

      const storey1 = StoreyLevel(
        id: 'lvl1',
        name: 'Floor 1',
        elevation: 0.0,
        height: 2.80,
        slabs: [slabFloor2],
      );

      const storey2 = StoreyLevel(
        id: 'lvl2',
        name: 'Floor 2',
        elevation: 2.80,
        height: 2.80,
        slabs: [slabFloor2],
      );

      expect(storey2.structuralElevationFor(slabFloor2), closeTo(5.55, 1e-4));
      final painter = Structural2dPainter(
        currentStorey: storey1,
        cadToScene: (pt) => pt * 20.0,
        cadScale: 1.0,
        zoomScale: 1.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(800, 600));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
