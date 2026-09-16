import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  test('VP contour polylines have no parasitic lines and correct centering', () async {
    final dwgFile = File(r'C:\Users\Creator\Dropbox\test_files\VP.dwg');
    if (!dwgFile.existsSync()) return;

    final dxfPath = await DwgConverterService.convertDwgToDxf(dwgFile.path, forceReconvert: true);
    final file = File(dxfPath);
    expect(file.existsSync(), isTrue);

    final doc = await DxfParser.parseFromFile(file);

    // 1. Verify Topographic contour lines (C-TOPO-MAJR and C-TOPO-MINR)
    final topoPolylines = doc.entities
        .whereType<DxfPolyline>()
        .where((p) => p.layer.startsWith('C-TOPO'))
        .toList();

    expect(topoPolylines.isNotEmpty, isTrue);
    expect(topoPolylines.length, equals(10));

    for (final poly in topoPolylines) {
      // Must not contain any spline frame-control points (flags & 16 != 0)
      final frameVertices = poly.vertices.where((v) => (v.flags & 16) != 0).toList();
      expect(frameVertices, isEmpty, reason: 'Polyline on ${poly.layer} contains frame control points!');

      // All vertices must be spline curve points (flags & 8 != 0)
      final splineVertices = poly.vertices.where((v) => (v.flags & 8) != 0).toList();
      expect(splineVertices.length, equals(poly.vertices.length));
    }

    // Polyline 0 should have exactly 81 vertices (not 81 + 13 frame = 94)
    expect(topoPolylines[0].vertices.length, equals(81));

    // Polyline 5 (closed loop around 1132.67) should have 40 vertices and isClosed = true
    expect(topoPolylines[5].isClosed, isTrue);
    expect(topoPolylines[5].vertices.length, equals(40));

    // 2. Verify Document bounds and centering
    // Width should be around 75m (the outer frame), NOT ~789m!
    expect(doc.width, lessThan(100.0));
    expect(doc.width, greaterThan(70.0));

    // Height should be around 96.7m
    expect(doc.height, lessThan(120.0));
    expect(doc.height, greaterThan(80.0));

    // Center X should be near 322900, NOT 323257!
    expect(doc.bounds.center.dx, inInclusiveRange(322895.0, 322905.0));
    expect(doc.bounds.center.dy, inInclusiveRange(4640625.0, 4640638.0));

    // 3. Verify MTEXT bounding box calculation
    final titleMText = doc.entities
        .whereType<DxfMText>()
        .firstWhere((m) => m.cleanText.contains('61813'));
    final titleBox = titleMText.getBoundingBox(doc.blocks);
    expect(titleBox.width, lessThan(100.0), reason: 'Title width should not stretch to refWidth 782m');
  });
}
