import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/ifc_parser.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';

void main() {
  test('Test composite outer shell construction', () async {
    final file = File(r'C:\Users\Creator\Dropbox\test_files\roof.ifc');
    final content = file.readAsStringSync();

    // Directly parse the unmodified roof.ifc file!
    final model = IfcParser.parseFromText(content);
    expect(model.elements.length, equals(1));
    final roof = model.elements.first;
    print('Roof element name: ${roof.name}, category: ${roof.category}, triangles: ${roof.triangles.length}');
    print('Roof bounds: Z[${roof.bounds.min.z.toStringAsFixed(1)} .. ${roof.bounds.max.z.toStringAsFixed(1)}]');
    print('Total Z span: ${(roof.bounds.max.z - roof.bounds.min.z).toStringAsFixed(1)} mm');

    // Count top, bottom, and side triangles
    final topCount = roof.triangles.where((t) => t.normal.z > 0.2).length;
    final bottomCount = roof.triangles.where((t) => t.normal.z < -0.2).length;
    final sideCount = roof.triangles.where((t) => t.normal.z.abs() <= 0.2).length;
    print('Roof structure: $topCount top faces, $bottomCount bottom faces, $sideCount side faces');
    print('Total triangles: ${roof.triangles.length}');

    final combinedMesh = Mesh3D(
      name: 'roof',
      triangles: roof.triangles,
      bounds: roof.bounds,
    );

    const artifactDir = r'C:\Users\Creator\.gemini\antigravity\brain\73cbe7df-984d-431d-be76-1e75f637ad67';

    // Render overview with light studio theme matching Archicad CAD view
    await _renderWithCadPainter(
      combinedMesh,
      yaw: 0.8,
      pitch: 0.45,
      zoom: 1.1,
      panOffset: Offset.zero,
      theme: Cad3DTheme.lightStudio,
      shadingMode: Cad3DShadingMode.smoothShaded,
      filePath: '$artifactDir\\roof_thick_light_studio.png',
    );

    // Render overview dark
    await _renderWithCadPainter(
      combinedMesh,
      yaw: 0.8,
      pitch: 0.5,
      zoom: 1.0,
      panOffset: Offset.zero,
      theme: Cad3DTheme.darkCad,
      shadingMode: Cad3DShadingMode.smoothShaded,
      filePath: '$artifactDir\\roof_thick_overview.png',
    );

    // Render close-up of edge (matching media_1789132783060.png)
    await _renderWithCadPainter(
      combinedMesh,
      yaw: 0.8,
      pitch: 0.2,
      zoom: 2.2,
      panOffset: const Offset(150, -50),
      theme: Cad3DTheme.darkCad,
      shadingMode: Cad3DShadingMode.smoothShaded,
      filePath: '$artifactDir\\roof_thick_edge_closeup.png',
    );
  });
}

Future<void> _renderWithCadPainter(
  Mesh3D mesh, {
  required double yaw,
  required double pitch,
  required double zoom,
  required Offset panOffset,
  required String filePath,
  Cad3DTheme theme = Cad3DTheme.lightStudio,
  Cad3DShadingMode shadingMode = Cad3DShadingMode.smoothShaded,
}) async {
  const size = Size(1000, 600);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final camera = Cad3DCamera(
    yaw: yaw,
    pitch: pitch,
    zoom: zoom,
    panOffset: panOffset,
  );

  final painter = Cad3DMeshPainter(
    mesh: mesh,
    camera: camera,
    shadingMode: shadingMode,
    theme: theme,
    showGrid: false,
  );

  canvas.drawRect(Offset.zero & size, Paint()..color = theme.background);
  painter.paint(canvas, size);

  final picture = recorder.endRecording();
  final imgUi = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await imgUi.toByteData(format: ui.ImageByteFormat.png);
  File(filePath).writeAsBytesSync(byteData!.buffer.asUint8List());
  print('Saved render: $filePath');
}
