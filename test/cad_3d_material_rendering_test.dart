import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/cad_3d/cad_3d_controller.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_gltf_encoder.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_mesh_painter.dart';
import 'package:kotoview/src/features/cad_3d/widgets/cad_3d_viewport.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/glb_gltf_parser.dart';
import '../tool/qa/cad_3d_material_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'viewport decodes fallback textures and clears them on scene replacement',
    (tester) async {
      final controller = Cad3DController();
      addTearDown(controller.dispose);
      Widget host(Mesh3D mesh) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Cad3DViewport(
          mesh: mesh,
          controller: controller,
          showControls: false,
          showGrid: false,
        ),
      );
      Cad3DMeshPainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<Cad3DMeshPainter>()
          .single;
      await tester.pumpWidget(host(materialFixture()));
      for (var i = 0; i < 20 && painter().textureImages.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(painter().textureImages, hasLength(1));
      await tester.pumpWidget(host(Mesh3D(name: 'empty', triangles: [])));
      expect(painter().textureImages, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  test('GPU render asset preserves UVs and shares its embedded texture', () {
    final source = materialFixture();
    final decoded = GlbGltfParser.parseFromBytes(
      Cad3DGltfEncoder.encode(source),
    );
    expect(decoded.triangleCount, 12);
    expect(decoded.bounds.min.x, -10);
    expect(decoded.bounds.max.z, 10);
    final texture = decoded.triangles.first.material!.baseColorTexture!.texture;
    expect(
      texture.bytes,
      source.triangles.first.material!.baseColorTexture!.texture.bytes,
    );
    expect(texture.magFilter, 9728);
    for (var i = 0; i < 12; i++) {
      final t = decoded.triangles[i];
      expect(
        t.textureCoordinates[0],
        source.triangles[i].textureCoordinates[0],
      );
      expect(t.material!.baseColorTexture!.texture, same(texture));
      expect(t.material!.alphaMode, 'MASK');
      expect(t.material!.unlit, isTrue);
      expect(t.isDoubleSided, isTrue);
    }
  });

  test('GPU material factors are applied once and raw mask alpha survives', () {
    const m = MeshMaterial(
      baseColorFactor: [.25, .5, 1, .8],
      alphaMode: 'MASK',
    );
    final mesh = Mesh3D(
      name: 'alpha',
      triangles: [
        Triangle3D(
          v0: Vector3.zero,
          v1: const Vector3(1, 0, 0),
          v2: const Vector3(0, 1, 0),
          material: m,
          color: Colors.red,
          linearVertexColors: const [
            [1, 0, 0, .6],
            [1, 0, 0, .6],
            [1, 0, 0, .6],
          ],
        ),
      ],
    );
    final t = GlbGltfParser.parseFromBytes(
      Cad3DGltfEncoder.encode(mesh),
    ).triangles.single;
    expect(t.material!.baseColorFactor, m.baseColorFactor);
    expect(t.linearVertexColors!.first[3], closeTo(.6, 1e-6));
    expect(t.vertexColors!.first.r, closeTo(.537099, 1e-5));
    expect(t.vertexColors!.first.a, 0); // .8 * .6 is below the cutoff.
  });

  test(
    'GPU path preserves all PBR maps and switches authored/flat normals',
    () {
      final image =
          materialFixture().triangles.first.material!.baseColorTexture!.texture;
      final binding = MeshTextureBinding(
        texture: image,
        texCoord: 1,
        offset: const Offset(.25, .5),
        scale: const Offset(2, 3),
        rotation: .75,
      );
      final m = MeshMaterial(
        baseColorTexture: binding,
        metallicRoughnessTexture: binding,
        normalTexture: binding,
        occlusionTexture: binding,
        emissiveTexture: binding,
        normalScale: .6,
        occlusionStrength: .7,
        metallicFactor: .4,
        roughnessFactor: .3,
        emissiveFactor: const [.1, .2, .3],
      );
      final normal = const Vector3(1, 0, 1).normalized();
      final mesh = Mesh3D(
        name: 'PBR',
        triangles: [
          Triangle3D(
            v0: Vector3.zero,
            v1: const Vector3(1, 0, 0),
            v2: const Vector3(0, 1, 0),
            material: m,
            vertexNormals: [normal, normal, normal],
            textureCoordinates: const {
              1: [Offset.zero, Offset(1, 0), Offset(0, 1)],
            },
          ),
        ],
      );
      for (final flat in [false, true]) {
        final t = GlbGltfParser.parseFromBytes(
          Cad3DGltfEncoder.encode(mesh, flatShaded: flat),
        ).triangles.single;
        expect(t.normal.z, closeTo(flat ? 1 : normal.z, 1e-6));
        final decoded = t.material!;
        expect(decoded.metallicFactor, .4);
        expect(decoded.roughnessFactor, .3);
        expect(decoded.emissiveFactor, [.1, .2, .3]);
        expect(decoded.normalScale, .6);
        expect(decoded.occlusionStrength, .7);
        for (final info in [
          decoded.baseColorTexture,
          decoded.metallicRoughnessTexture,
          decoded.normalTexture,
          decoded.occlusionTexture,
          decoded.emissiveTexture,
        ]) {
          expect(info!.texCoord, 1);
          expect(info.offset, binding.offset);
          expect(info.scale, binding.scale);
          expect(info.rotation, .75);
        }
      }
    },
  );

  test(
    'untextured colors and transparency survive alongside imported materials',
    () {
      final source = materialFixture();
      final plain = Triangle3D(
        v0: Vector3.zero,
        v1: const Vector3(1, 0, 0),
        v2: const Vector3(0, 1, 0),
        color: const Color.fromRGBO(50, 100, 150, .25),
      );
      final mesh = Mesh3D(
        name: 'mixed',
        triangles: [...source.triangles, plain],
      );
      final decoded = GlbGltfParser.parseFromBytes(
        Cad3DGltfEncoder.encode(mesh),
      );
      final t = decoded.triangles.last;
      expect(t.color!.r, closeTo(plain.color!.r, 1e-6));
      expect(t.color!.g, closeTo(plain.color!.g, 1e-6));
      expect(t.color!.a, closeTo(.25, 1e-6));
      expect(t.material!.alphaMode, 'BLEND');
      expect(t.material!.metallicFactor, 0);
    },
  );

  test(
    'Canvas fallback paints texture quadrants after triangle subdivision',
    () async {
      final mesh = materialFixture();
      final texture = mesh.triangles.first.material!.baseColorTexture!.texture;
      final codec = await ui.instantiateImageCodec(texture.bytes);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      addTearDown(image.dispose);
      final camera = Cad3DCamera()..setPreset(Cad3DViewPreset.top);
      Future<List<int>> colors({required bool textured}) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        Cad3DMeshPainter(
          mesh: mesh,
          camera: camera,
          showGrid: false,
          textureImages: {if (textured) texture: image},
        ).paint(canvas, const Size(400, 400));
        final picture = recorder.endRecording();
        final rendered = await picture.toImage(400, 400);
        picture.dispose();
        final data = (await rendered.toByteData())!.buffer.asUint8List();
        rendered.dispose();
        var red = 0, green = 0, blue = 0;
        for (var i = 0; i < data.length; i += 4) {
          if (data[i + 3] < 128) continue;
          final r = data[i], g = data[i + 1], b = data[i + 2];
          if (r > g * 1.5 && r > b * 1.5) red++;
          if (g > r * 1.5 && g > b * 1.5) green++;
          if (b > r * 1.5 && b > g * 1.5) blue++;
        }
        return [red, green, blue];
      }

      final textured = await colors(textured: true);
      final plain = await colors(textured: false);
      for (var i = 0; i < 3; i++) {
        expect(textured[i], greaterThan(1000));
        expect(textured[i], greaterThan(plain[i] * 5));
      }
    },
  );
}
