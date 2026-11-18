import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';

const _size = Size(400, 400);
const _bounds = Rect.fromLTWH(0, 0, 1000, 1000);
const _zoom = 8.0;
const _fit = (400 - 64) / 1000;
final _visible = Rect.fromCenter(
  center: _bounds.center,
  width: 400 / (_fit * _zoom),
  height: 400 / (_fit * _zoom),
);

DxfHatch _hatch({double extent = 1000, bool hole = true}) => DxfHatch(
  isSolid: false,
  patternName: 'CUSTOM',
  boundaryPaths: [
    [Offset.zero, Offset(extent, 0), Offset(extent, extent), Offset(0, extent)],
    if (hole)
      const [
        Offset(485, 485),
        Offset(515, 485),
        Offset(515, 515),
        Offset(485, 515),
      ],
  ],
  patternLines: const [
    DxfHatchPatternLine(
      angle: 30,
      basePoint: Offset(13, 19),
      offset: Offset(-10, 17.320508),
      dashes: [8, -12],
    ),
    DxfHatchPatternLine(
      angle: 90,
      basePoint: Offset(7, 11),
      offset: Offset(-20, 3),
      dashes: [0, -12],
    ),
  ],
);

DxfDocument _document(
  List<DxfEntity> entities, {
  Map<String, DxfBlock> blocks = const {},
}) => DxfDocument(
  layers: {'0': DxfLayer(name: '0')},
  blocks: blocks,
  entities: entities,
  headerVars: {},
  bounds: _bounds,
  entityStats: {},
);

Picture _record(DxfDocument doc, {Rect? visible, String layout = 'Model'}) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)..clipRect(Offset.zero & _size);
  canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
  canvas.translate(200, 200);
  canvas.scale(_zoom);
  canvas.translate(-200, -200);
  DxfPainter(
    document: doc,
    theme: DxfCanvasTheme.paperWhite,
    currentScale: _zoom,
    visibleCadRect: visible,
    activeLayout: layout,
    showGrid: false,
  ).paint(canvas, _size);
  return recorder.endRecording();
}

Future<Uint8List> _pixels(Picture picture) async {
  try {
    final image = await picture.toImage(400, 400);
    try {
      final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
      return bytes!.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void _expectSameVisibleDrawing(Uint8List actual, Uint8List expected) {
  var changed = 0;
  var ink = 0;
  for (var i = 0; i < actual.length; i += 4) {
    if (expected[i] < 180) ink++;
    if ((actual[i] - expected[i]).abs() > 3 ||
        (actual[i + 1] - expected[i + 1]).abs() > 3 ||
        (actual[i + 2] - expected[i + 2]).abs() > 3) {
      changed++;
    }
  }
  expect(
    ink,
    greaterThan(300),
    reason: 'The reference must contain actual hatch detail',
  );
  // Permit only subpixel raster rounding at line ends, not missing families.
  expect(changed, lessThan(400 * 400 * .001));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'viewport hatch preserves dash phase, dots and boundary holes',
    () async {
      final doc = _document([_hatch()]);
      final full = await _pixels(_record(doc));
      final clipped = await _pixels(_record(doc, visible: _visible));
      _expectSameVisibleDrawing(clipped, full);
      final center = (200 * 400 + 200) * 4;
      expect(
        clipped[center],
        greaterThan(240),
        reason: 'The inner hole stays empty',
      );
    },
  );

  test(
    'translated rotated block hatches are clipped in scene coordinates',
    () async {
      final doc = _document(
        const [
          DxfInsert(
            blockName: 'B',
            insertPoint: Offset(1100, 100),
            rotationDeg: 90,
            scaleX: .8,
            scaleY: 1.2,
          ),
        ],
        blocks: {
          'B': DxfBlock(
            name: 'B',
            basePoint: Offset.zero,
            entities: [_hatch(hole: false)],
          ),
        },
      );
      _expectSameVisibleDrawing(
        await _pixels(_record(doc, visible: _visible)),
        await _pixels(_record(doc)),
      );
    },
  );

  test('paper viewport hatch keeps model detail after clipping', () async {
    final doc = _document([
      _hatch(),
      const DxfViewport(
        center: Offset(500, 500),
        width: 1000,
        height: 1000,
        viewCenter: Offset(500, 500),
        viewHeight: 1000,
        isPaperSpace: true,
        layoutName: 'Sheet',
        viewportId: 2,
      ),
    ]);
    doc.layoutBounds['Sheet'] = _bounds;
    _expectSameVisibleDrawing(
      await _pixels(_record(doc, visible: _visible, layout: 'Sheet')),
      await _pixels(_record(doc, layout: 'Sheet')),
    );
  });

  test('pattern work is bounded by the viewport instead of a large hatch', () {
    // Fixed document bounds and camera: expanding only the hatch must not
    // multiply recorded dash segments far outside the screen.
    int bytes(double extent) {
      final picture = _record(
        _document([_hatch(extent: extent, hole: false)]),
        visible: _visible,
      );
      try {
        return picture.approximateBytesUsed;
      } finally {
        picture.dispose();
      }
    }

    final small = bytes(1000);
    final large = bytes(1000000);
    expect(large, lessThan(math.max(small * 2, 10000)));
  });

  test('successive small pans refresh the layer before leaving its buffer', () {
    final doc = _document([_hatch()]);
    DxfPainter painter(Rect visible) => DxfPainter(
      document: doc,
      theme: DxfCanvasTheme.paperWhite,
      currentScale: _zoom,
      visibleCadRect: visible,
      showGrid: false,
    );
    void paint(DxfPainter painter) {
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), _size);
      recorder.endRecording().dispose();
    }

    var previous = painter(_visible);
    paint(previous);
    var refreshed = false;
    for (var step = 1; step <= 6; step++) {
      final next = painter(
        _visible.shift(Offset(_visible.longestSide * .04 * step, 0)),
      );
      final needsPaint = next.shouldRepaint(previous);
      if (step == 1) expect(needsPaint, isFalse);
      if (needsPaint) {
        refreshed = true;
        paint(next);
      }
      previous = next;
    }
    expect(
      refreshed,
      isTrue,
      reason: 'Small pans must not accumulate beyond the painted hatch buffer',
    );
  });
}
