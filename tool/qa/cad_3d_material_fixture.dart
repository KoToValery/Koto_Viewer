import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';

/// No network assets: distinct quadrants make missing/flipped UVs conspicuous.
Mesh3D materialFixture() {
  final image = img.Image(width: 32, height: 32, numChannels: 4);
  for (var y = 0; y < 32; y++) {
    for (var x = 0; x < 32; x++) {
      final color = x < 16
          ? (y < 16 ? [240, 30, 30, 255] : [30, 40, 240, 255])
          : (y < 16 ? [30, 220, 30, 255] : [240, 210, 30, 0]);
      image.setPixelRgba(x, y, color[0], color[1], color[2], color[3]);
    }
  }
  final texture = MeshTexture(
    bytes: Uint8List.fromList(img.encodePng(image)),
    mimeType: 'image/png',
    magFilter: 9728,
    minFilter: 9728,
  );
  final material = MeshMaterial(
    baseColorTexture: MeshTextureBinding(texture: texture),
    metallicFactor: 0,
    roughnessFactor: .8,
    unlit: true,
    doubleSided: true,
    alphaMode: 'MASK',
  );
  const p = [
    Vector3(0, 0, 0),
    Vector3(2, 0, 0),
    Vector3(2, 2, 0),
    Vector3(0, 2, 0),
    Vector3(0, 0, 2),
    Vector3(2, 0, 2),
    Vector3(2, 2, 2),
    Vector3(0, 2, 2),
  ];
  const faces = [
    [0, 3, 2, 1],
    [4, 5, 6, 7],
    [0, 1, 5, 4],
    [1, 2, 6, 5],
    [2, 3, 7, 6],
    [3, 0, 4, 7],
  ];
  const uv = [Offset(0, 1), Offset(1, 1), Offset(1, 0), Offset(0, 0)];
  final triangles = <Triangle3D>[];
  for (final face in faces) {
    for (final corners in [
      [0, 1, 2],
      [0, 2, 3],
    ]) {
      triangles.add(
        Triangle3D(
          v0: p[face[corners[0]]],
          v1: p[face[corners[1]]],
          v2: p[face[corners[2]]],
          color: const Color(0xffffffff),
          material: material,
          isDoubleSided: true,
          textureCoordinates: {
            0: [for (final k in corners) uv[k]],
          },
        ),
      );
    }
  }
  return Mesh3D(name: 'material-fixture', triangles: triangles);
}
