import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_mesh_painter.dart';

const _bounds = BoundingBox3D(min: Vector3(-1, -1, -1), max: Vector3(1, 1, 1));

Triangle3D _face({MeshMaterial? material, List<Offset>? uvs}) => Triangle3D(
  v0: const Vector3(-1, 0, -1),
  v1: const Vector3(1, 0, -1),
  v2: const Vector3(0, 0, 1),
  color: Colors.red,
  material: material,
  textureCoordinates: {0: ?uvs},
);

Mesh3D _mesh(List<Triangle3D> triangles, {bool grouped = false}) => Mesh3D(
  name: 'validation',
  triangles: triangles,
  bounds: _bounds,
  groups: grouped
      ? [ElementMeshGroup(id: 'group', triangles: triangles, bounds: _bounds)]
      : null,
);

Future<Uint8List> _render(Cad3DMeshPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(200, 200));
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 200);
  picture.dispose();
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final grouped in [false, true]) {
    for (final mode in Cad3DShadingMode.values) {
      test(
        'invalid faces preserve valid rendering: $mode, grouped=$grouped',
        () async {
          final valid = _face();
          final camera = Cad3DCamera()..setPreset(Cad3DViewPreset.front);
          Cad3DMeshPainter painter(List<Triangle3D> triangles) =>
              Cad3DMeshPainter(
                mesh: _mesh(triangles, grouped: grouped),
                camera: camera,
                shadingMode: mode,
              );
          final expected = await _render(painter([valid]));
          final actual = await _render(
            painter([
              valid,
              for (final bad in [double.nan, double.infinity, -double.infinity])
                Triangle3D(
                  v0: Vector3(bad, 0, 0),
                  v1: const Vector3(1, 0, 0),
                  v2: const Vector3(0, 0, 1),
                ),
            ]),
          );
          expect(actual, orderedEquals(expected));
          // The valid red face (or red wireframe) must still be present.
          expect([
            for (var i = 0; i < expected.length; i += 4)
              if (expected[i] > 150 && expected[i + 1] < 100) i,
          ], isNotEmpty);
        },
      );
    }
  }

  test(
    'invalid camera and bounds do not submit invalid canvas points',
    () async {
      final mesh = _mesh([_face()]);
      for (final camera in [
        Cad3DCamera(yaw: double.nan),
        Cad3DCamera(pitch: double.infinity),
        Cad3DCamera(zoom: double.nan),
        Cad3DCamera(panOffset: const Offset(double.nan, 0)),
        Cad3DCamera(
          mode: Cad3DInteractionMode.fly,
          eyePosition: const Vector3(0, double.infinity, 0),
        ),
      ]) {
        final pixels = await _render(
          Cad3DMeshPainter(mesh: mesh, camera: camera),
        );
        expect(pixels.every((v) => v == 0), isTrue);
      }
      final invalidBounds = Mesh3D(
        name: 'invalid bounds',
        triangles: [_face()],
        bounds: const BoundingBox3D(
          min: Vector3(double.nan, 0, 0),
          max: Vector3(1, 1, 1),
        ),
      );
      final pixels = await _render(
        Cad3DMeshPainter(mesh: invalidBounds, camera: Cad3DCamera()),
      );
      expect(pixels.every((v) => v == 0), isTrue);
    },
  );

  test('invalid texture coordinates fall back to the face color', () async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    picture.dispose();
    addTearDown(image.dispose);
    final texture = MeshTexture(bytes: Uint8List(0));
    for (final binding in [
      MeshTextureBinding(texture: texture),
      MeshTextureBinding(texture: texture, rotation: double.nan),
      MeshTextureBinding(texture: texture, scale: const Offset(1e300, 1)),
    ]) {
      final triangle = _face(
        material: MeshMaterial(baseColorTexture: binding, unlit: true),
        uvs: binding.rotation.isNaN || binding.scale.dx > 1
            ? const [Offset.zero, Offset(1, 0), Offset(0, 1)]
            : const [Offset(double.nan, 0), Offset(1, 0), Offset(0, 1)],
      );
      Cad3DMeshPainter painter(bool textured) => Cad3DMeshPainter(
        mesh: _mesh([triangle], grouped: true),
        camera: Cad3DCamera()..setPreset(Cad3DViewPreset.front),
        shadingMode: Cad3DShadingMode.cadShadedEdges,
        showGrid: false,
        textureImages: {if (textured) texture: image},
      );
      expect(
        await _render(painter(true)),
        orderedEquals(await _render(painter(false))),
      );
    }
  });
}
