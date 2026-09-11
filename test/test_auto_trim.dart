import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/ifc_parser.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';

void main() {
  const artifactDir = r'C:\Users\Creator\.gemini\antigravity\brain\73cbe7df-984d-431d-be76-1e75f637ad67';

  test('Verify auto_trim_to_roof.ifc parsed cleanly by IfcParser', () async {
    final filePath = r'C:\Users\Creator\Dropbox\test_files\auto_trim_to_roof.ifc';
    final model = await IfcParser.parseFromFile(filePath);

    expect(model.elements.length, 5);
    final roof = model.elements.firstWhere((e) => e.category == 'Roof');
    final walls = model.elements.where((e) => e.category == 'Wall').toList();
    expect(walls.length, 4);

    print('Parsed auto_trim_to_roof.ifc:');
    print('Roof: ${roof.name}, triangles=${roof.triangles.length}, bounds=${roof.bounds.min} -> ${roof.bounds.max}');
    for (int i = 0; i < 10; i++) {
      final t = roof.triangles[i];
      final n = (t.v1 - t.v0).cross(t.v2 - t.v0);
      print('Roof tri $i: norm=$n, col=${t.color}');
    }
    for (final w in walls) {
      print('Wall ${w.id}: bounds=${w.bounds.min} -> ${w.bounds.max}, triangles=${w.triangles.length}');
    }

    final combinedTris = model.elements.expand((e) => e.triangles).toList();
    final fullMesh = Mesh3D(
      name: 'building',
      triangles: combinedTris,
      bounds: BoundingBox3D.fromPoints(combinedTris.expand((t) => [t.v0, t.v1, t.v2]).toList()),
    );

    final wall128 = walls.firstWhere((w) => w.id == 128);
    final camBelow = Cad3DCamera(yaw: 0.75, pitch: -0.5, zoom: 1.1, panOffset: Offset.zero);
    const size = Size(1000, 600);
    final maxDim = fullMesh.bounds.maxDimension;
    final modelScale = (600 * 0.55) / maxDim;

    int frontFacingCount = 0;
    int topCapFrontFacing = 0;
    for (final w in walls) {
      for (int i = 0; i < w.triangles.length; i++) {
        final tri = w.triangles[i];
        final tv0 = camBelow.transformPoint(tri.v0 - fullMesh.bounds.center);
        final tv1 = camBelow.transformPoint(tri.v1 - fullMesh.bounds.center);
        final tv2 = camBelow.transformPoint(tri.v2 - fullMesh.bounds.center);
        final p0 = camBelow.projectToScreen(tv0, size, modelScale);
        final p1 = camBelow.projectToScreen(tv1, size, modelScale);
        final p2 = camBelow.projectToScreen(tv2, size, modelScale);
        final cross2d = (p1.dx - p0.dx) * (p2.dy - p0.dy) - (p1.dy - p0.dy) * (p2.dx - p0.dx);
        if (cross2d < 0) {
          frontFacingCount++;
          if (tri.normal.z > 0.1 || (tri.v1 - tri.v0).cross(tri.v2 - tri.v0).z > 0.1) {
            topCapFrontFacing++;
            print('Top cap is FRONT-FACING from below! Wall ${w.id} tri $i');
          }
        }
      }
    }
    print('All walls from below: $frontFacingCount front-facing triangles, $topCapFrontFacing top cap front-facing');

    // 1. Render overview with official parsed model
    await _renderWithCadPainter(
      fullMesh,
      yaw: 0.75,
      pitch: 0.45,
      zoom: 1.0,
      panOffset: Offset.zero,
      theme: Cad3DTheme.darkCad,
      shadingMode: Cad3DShadingMode.smoothShaded,
      filePath: '$artifactDir\\trim_fixed_overview.png',
    );

    // 2. Render bottom (underside of roof & interior walls)
    await _renderWithCadPainter(
      fullMesh,
      yaw: 0.75,
      pitch: -0.5,
      zoom: 1.1,
      panOffset: Offset.zero,
      theme: Cad3DTheme.darkCad,
      shadingMode: Cad3DShadingMode.smoothShaded,
      filePath: '$artifactDir\\trim_fixed_bottom.png',
    );

    // 3. Render walls only (to inspect top bevels and miters)
    final wallTris = walls.expand((e) => e.triangles).toList();
    final wallsMesh = Mesh3D(
      name: 'walls',
      triangles: wallTris,
      bounds: BoundingBox3D.fromPoints(wallTris.expand((t) => [t.v0, t.v1, t.v2]).toList()),
    );
    await _renderWithCadPainter(
      wallsMesh,
      yaw: 0.75,
      pitch: 0.45,
      zoom: 1.0,
      panOffset: Offset.zero,
      theme: Cad3DTheme.darkCad,
      shadingMode: Cad3DShadingMode.smoothShaded,
      filePath: '$artifactDir\\trim_walls_only.png',
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
