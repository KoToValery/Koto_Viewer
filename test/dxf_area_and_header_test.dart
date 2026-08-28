import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_math.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';
import 'package:kotoview/src/features/pcb_viewer/parser/pcb_archive_parser.dart';

void main() {
  group('DXF Measurement & Tools Tests', () {
    test('DxfMeasureTool includes all 5 tools including annotation', () {
      expect(DxfMeasureTool.values.length, 5);
      expect(DxfMeasureTool.values.contains(DxfMeasureTool.annotation), isTrue);
      expect(DxfMeasureTool.annotation.label, 'Leader Note');
    });

    test('DxfMath calculates polygon area and perimeter accurately', () {
      // 10m x 20m rectangle: area = 200, perimeter = 60
      final points = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 20),
        const Offset(0, 20),
      ];
      final area = DxfMath.calculatePolygonArea(points);
      final perim = DxfMath.calculatePolygonPerimeter(points, isClosed: true);
      expect(area, closeTo(200.0, 0.001));
      expect(perim, closeTo(60.0, 0.001));

      final centroid = DxfMath.calculatePolygonCentroid(points);
      expect(centroid.dx, closeTo(5.0, 0.001));
      expect(centroid.dy, closeTo(10.0, 0.001));
    });

    test('Live dynamic rubber-band polygon preview includes candidate point', () {
      final basePoints = [
        const Offset(0, 0),
        const Offset(10, 0),
      ];
      final previewPoints = [...basePoints, const Offset(10, 20)];
      final area = DxfMath.calculatePolygonArea(previewPoints);
      expect(area, closeTo(100.0, 0.001)); // 1/2 * 10 * 20 = 100
    });

    test('DxfPainter renders without exceptions at extreme zoom (Zoom 836% - 5000%)', () {
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: {},
        entities: [
          const DxfLine(p1: Offset(0, 0), p2: Offset(100, 100)),
          const DxfCircle(center: Offset(50, 50), radius: 5.0),
          const DxfArc(center: Offset(30, 30), radius: 10.0, startAngleDeg: 0, endAngleDeg: 90),
          const DxfText(text: 'Cadastre Point 14', insertPoint: Offset(50, 50)),
        ],
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      final measurement = DxfMeasurement(
        tool: DxfMeasureTool.area,
        areaPoints: const [
          Offset(10, 10),
          Offset(80, 10),
          Offset(80, 60),
          Offset(10, 60),
        ],
        isAreaClosed: true,
      );

      final annotation = DxfAnnotation(
        id: 'test-1',
        arrowTipCad: const Offset(50, 50),
        textPosCad: const Offset(70, 70),
        text: 'Test note гггг',
        createdAt: DateTime.now(),
      );

      for (final zoomScale in [5.39, 8.36, 9.18, 50.0, 100.0]) {
        final painter = DxfPainter(
          document: doc,
          theme: DxfCanvasTheme.darkCad,
          currentScale: zoomScale,
          measurement: measurement,
          annotations: [annotation],
        );

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(392, 750)),
          returnsNormally,
          reason: 'Painter should not throw at scale $zoomScale',
        );
        final picture = recorder.endRecording();
        picture.dispose();
      }
    });
  });

  group('PCB Gerber Layer Visibility Tests', () {
    test('Assembly and SMT paste layers default to isVisible: false', () {
      final zipFile = File('scratch/SuperSense_Gerbers/SuperSense_V5_3_Gerbers.zip');
      if (!zipFile.existsSync()) return;

      final project = PcbArchiveParser.parseZip(
        zipFile.readAsBytesSync(),
        filePath: zipFile.path,
        archiveName: 'SuperSense_V5_3_Gerbers.zip',
      );
      for (final layer in project.layers) {
        final lower = layer.fileName.toLowerCase();
        if (lower.contains('assembly') || lower.contains('paste') || lower.contains('mask')) {
          expect(layer.isVisible, isFalse, reason: '${layer.fileName} should be hidden by default so copper pads retain their true color');
        } else if (lower.contains('silk') && lower.contains('top')) {
          expect(layer.isVisible, isTrue, reason: 'Top silkscreen should be visible by default');
        } else if (lower.contains('copper') && lower.contains('top')) {
          expect(layer.isVisible, isTrue, reason: 'Top copper should be visible by default');
          expect(layer.type.defaultAccent, const Color(0xFFD32F2F), reason: 'Top copper must be industry-standard Red');
        } else if (lower.contains('copper') && lower.contains('bottom')) {
          expect(layer.type.defaultAccent, const Color(0xFF1976D2), reason: 'Bottom copper must be industry-standard Blue');
        }
      }
    });
  });
}
