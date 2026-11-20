import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';

class _CountingDxfDocument extends DxfDocument {
  _CountingDxfDocument(List<DxfEntity> entities)
    : super(
        entities: entities,
        layers: {'0': DxfLayer(name: '0')},
        blocks: {},
        headerVars: {},
        textStyles: const {
          'Fixed12': DxfTextStyle(name: 'Fixed12', heightScale: 12),
          'Near2': DxfTextStyle(name: 'Near2', heightScale: 1.98),
          'Double': DxfTextStyle(name: 'Double', heightScale: 2),
        },
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

  int originReads = 0;

  @override
  bool get isArchicadOrigin {
    originReads++;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paint checks text document origin at most once and only as needed', () {
    const normalText = [
      DxfText(text: 'Unstyled', insertPoint: Offset(10, 60), height: 5),
      DxfText(
        text: 'Fixed-style',
        insertPoint: Offset(10, 45),
        height: 5,
        style: 'Fixed12',
      ),
      DxfText(
        text: 'Fixed height',
        insertPoint: Offset(10, 30),
        height: 0,
        style: 'Double',
      ),
    ];

    void paint(DxfPainter painter) {
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), const Size(400, 400));
      recorder.endRecording().dispose();
    }

    final ordinary = _CountingDxfDocument(normalText);
    paint(DxfPainter(document: ordinary, theme: DxfCanvasTheme.paperWhite));
    expect(ordinary.originReads, 0);

    final styled = _CountingDxfDocument(const [
      ...normalText,
      DxfText(
        text: 'Styled text',
        insertPoint: Offset(10, 90),
        height: 5,
        style: 'Near2',
      ),
      DxfMText(
        rawText: 'Styled paragraph',
        cleanText: 'Styled paragraph',
        insertPoint: Offset(10, 75),
        height: 5,
        style: 'Double',
      ),
    ]);
    final painter = DxfPainter(
      document: styled,
      theme: DxfCanvasTheme.paperWhite,
    );
    paint(painter);
    expect(styled.originReads, 1);
    paint(painter);
    expect(styled.originReads, 2);
  });

  group('DXF Text Fixed Height & Scaling Tests', () {
    test('AutoCAD file with fixed height style (12.0) does NOT scale text by 12x', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          r'$ACADVER': 'AC1018',
        },
        textStyles: {
          'Standard': const DxfTextStyle(name: 'Standard', heightScale: 12.0),
          'koti': const DxfTextStyle(name: 'koti', heightScale: 12.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isFalse);

      // Height 40.0 should remain 40.0, NOT become 480.0
      final h40 = DxfPainter.getEffectiveTextHeight(40.0, 'Standard', doc);
      expect(h40, equals(40.0));

      // Height 24.0 should remain 24.0, NOT become 288.0
      final h24 = DxfPainter.getEffectiveTextHeight(24.0, 'Standard', doc);
      expect(h24, equals(24.0));

      // Height 12.0 should remain 12.0, NOT become 144.0
      final h12 = DxfPainter.getEffectiveTextHeight(12.0, 'Standard', doc);
      expect(h12, equals(12.0));
    });

    test('Archicad-originated file with 2.0x style scale correctly applies 2.0x factor', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {
          r'$ACADVER': 'ARCHICAD_24',
        },
        textStyles: {
          'Standard': const DxfTextStyle(name: 'Standard', heightScale: 2.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        entityStats: {},
      );

      expect(doc.isArchicadOrigin, isTrue);

      // Height 3.5 should become 7.0 for Archicad
      final h = DxfPainter.getEffectiveTextHeight(3.5, 'Standard', doc);
      expect(h, equals(7.0));
    });

    test('Zero height entity falls back to style fixed height or 2.5 default', () {
      final doc = DxfDocument(
        layers: {},
        blocks: {},
        entities: [],
        headerVars: {},
        textStyles: {
          'Fixed12': const DxfTextStyle(name: 'Fixed12', heightScale: 12.0),
          'ZeroStyle': const DxfTextStyle(name: 'ZeroStyle', heightScale: 1.0),
        },
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        entityStats: {},
      );

      // Zero height with fixed style returns style height 12.0
      final hFixed = DxfPainter.getEffectiveTextHeight(0.0, 'Fixed12', doc);
      expect(hFixed, equals(12.0));

      // Zero height without fixed style returns default 2.5
      final hDefault = DxfPainter.getEffectiveTextHeight(0.0, 'ZeroStyle', doc);
      expect(hDefault, equals(2.5));
    });
  });
}
