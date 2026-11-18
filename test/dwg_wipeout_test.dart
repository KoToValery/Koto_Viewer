import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_projects/services/dxf_document_transformer.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_reader.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_writer.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dwg_document_adapter.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_quadtree.dart';

const mask = DxfHatch(
  isWipeout: true,
  boundaryPaths: [
    [Offset(20, 20), Offset(40, 20), Offset(40, 40), Offset(20, 40)],
  ],
);
const behind = DxfLine(
  p1: Offset(0, 30),
  p2: Offset(100, 30),
  trueColor: 0xffff0000,
);
const inFront = DxfLine(
  p1: Offset(0, 35),
  p2: Offset(100, 35),
  trueColor: 0xff00ff00,
);

DxfDocument document(
  List<DxfEntity> entities, {
  Map<String, DxfBlock> blocks = const {},
}) => DxfDocument(
  entities: entities,
  layers: {'0': DxfLayer(name: '0')},
  blocks: blocks,
  bounds: const Rect.fromLTWH(0, 0, 100, 100),
  headerVars: {},
  entityStats: {},
);

Future<Uint8List> render(DxfDocument doc, DxfCanvasTheme theme) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(theme.bgColor, BlendMode.src);
  DxfPainter(
    document: doc,
    theme: theme,
    showGrid: false,
    visibleCadRect: const Rect.fromLTWH(0, 0, 100, 100),
  ).paint(canvas, const Size(264, 264));
  final picture = recorder.endRecording();
  final image = await picture.toImage(264, 264);
  try {
    final data = await image.toByteData(format: ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

List<int> pixel(Uint8List image, int x, int y) {
  final index = ((32 + (100 - y) * 2) * 264 + 32 + x * 2) * 4;
  return image.sublist(index, index + 3);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native WIPEOUT pixel boundary maps to WCS with inverted image V', () {
    final doc = DwgDocumentAdapter.decode({
      'protocol': 1,
      'source': 'DWG',
      'header': {},
      'blocks': [
        {
          'name': '*Model_Space',
          'entities': [
            {
              'Wipeout': {
                'insertion_point': {'x': 100, 'y': 200},
                'u_vector': {'x': 0, 'y': 10},
                'v_vector': {'x': -20, 'y': 0},
                'size': {'x': 1, 'y': 1},
                'clipping_enabled': true,
                'clip_type': 'Rectangular',
                'clip_boundary_vertices': [
                  {'x': -.5, 'y': -.5},
                  {'x': .5, 'y': .5},
                ],
              },
            },
          ],
        },
      ],
    });
    final wipeout = doc.entities.single as DxfHatch;
    expect(wipeout.typeName, 'WIPEOUT');
    expect(wipeout.isWipeout, isTrue);
    expect(wipeout.boundaryPaths.single.length, 4);
    expect(wipeout.getBoundingBox({}), const Rect.fromLTRB(80, 200, 100, 210));
  });

  for (final theme in DxfCanvasTheme.values) {
    for (final block in [false, true]) {
      test(
        'mask preserves draw order and background: ${theme.name}, block=$block',
        () async {
          final doc = block
              ? document(
                  const [DxfInsert(blockName: 'B', insertPoint: Offset.zero)],
                  blocks: {
                    'B': DxfBlock(
                      name: 'B',
                      entities: const [behind, mask, inFront],
                    ),
                  },
                )
              : document(const [behind, mask, inFront]);
          doc.spatialIndex = DxfQuadTree.build(
            doc.entities,
            doc.blocks,
            doc.bounds,
            maxItemsPerNode: 1,
          );
          final pixels = await render(doc, theme);
          final bg = theme.bgColor;
          expect(pixel(pixels, 30, 30), [
            (bg.r * 255).round(),
            (bg.g * 255).round(),
            (bg.b * 255).round(),
          ]);
          expect(pixel(pixels, 10, 30), [255, 0, 0]);
          expect(pixel(pixels, 30, 35), [0, 255, 0]);
        },
      );
    }
  }

  test(
    'explicit KCAD export and project transforms preserve mask semantics',
    () {
      final doc = document(const [mask]);
      for (final compress in [false, true]) {
        final restored = KcadReader.read(
          KcadWriter.write(doc, compress: compress),
        );
        expect((restored.entities.single as DxfHatch).isWipeout, isTrue);
        expect(restored.entities.single.typeName, 'WIPEOUT');
      }
      final transformed = DxfDocumentTransformer.transform(
        doc,
        translation: const Offset(10, 20),
        scale: 2,
      );
      final result = transformed.entities.single as DxfHatch;
      expect(result.isWipeout, isTrue);
      expect(result.boundaryPaths.first.first, const Offset(50, 60));
    },
  );
}
