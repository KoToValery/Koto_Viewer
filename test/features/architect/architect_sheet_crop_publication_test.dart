import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_layout.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_composer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const _drawing = ArchitectSavedDrawing(
  id: 'plan:storey',
  sourceId: 'storey',
  kind: ArchitectDrawingKind.plan,
);
const _crop = [
  Offset.zero,
  Offset(100, 0),
  Offset(100, 40),
  Offset(40, 40),
  Offset(40, 100),
  Offset(0, 100),
];
const _placement = ArchitectDrawingPlacement(
  id: 'view',
  drawingId: 'plan:storey',
  frame: Rect.fromLTWH(20, 20, 100, 100),
  anchor: Offset.zero,
  scale: 100,
  showTitle: false,
  crop: _crop,
);

ArchitectProject _project({ArchitectSavedDrawing drawing = _drawing}) =>
    ArchitectProject(
      id: 'crop-publication',
      name: 'Layout crop',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 'storey',
      storeys: const [
        ArchitectStorey(
          id: 'storey',
          name: '',
          cadPrimitives: [
            ArchitectCadPrimitive(
              id: 'hatch',
              type: CadPrimitiveType.hatch,
              startPoint: Offset.zero,
              endPoint: Offset(10, 10),
            ),
            ArchitectCadPrimitive(
              id: 'line',
              type: CadPrimitiveType.line,
              startPoint: Offset(0, 2),
              endPoint: Offset(10, 2),
            ),
          ],
          annotations: [
            ArchitectAnnotation(
              id: 'annotation',
              position: Offset(1, 1),
              text: 'Векторен текст / vector text',
            ),
          ],
        ),
      ],
      document: ArchitectDocument(drawings: [drawing]),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('bg'));
    await (FontLoader('ArchitectNoto')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
  });

  test('concave sheet crop clips lines, hatches and vector text together', () {
    final project = _project();
    const sheet = ArchitectSheet(id: 'sheet', placements: [_placement]);
    final scene = ArchitectSheetComposer.compose(project, sheet, l);
    for (final id in ['line', 'hatch', 'annotation']) {
      final operations = scene.operations.where(
        (op) => op.sources.contains(id),
      );
      expect(operations, isNotEmpty, reason: id);
      for (final op in operations) {
        expect(op.clip, isNotNull, reason: id);
        expect(op.clip!.contains(const Offset(40, 100)), isTrue, reason: id);
        expect(op.clip!.contains(const Offset(100, 40)), isTrue, reason: id);
        expect(op.clip!.contains(const Offset(100, 100)), isFalse, reason: id);
      }
    }
    expect(scene.operations.whereType<ArchitectVectorText>(), isNotEmpty);
  });

  test('editing content remains uncropped for live boundary expansion', () {
    final project = _project();
    final content = ArchitectSheetComposer.placementContent(
      project,
      _placement,
      l,
    );
    final line = content.operations.firstWhere(
      (op) => op.sources.contains('line'),
    );
    expect(line.clip, isNull);
    final paper = ArchitectSheetComposer.compose(
      project,
      const ArchitectSheet(id: 'sheet', placements: [_placement]),
      l,
    );
    final published = paper.operations.firstWhere(
      (op) => op.sources.contains('line'),
    );
    expect(
      (line as ArchitectVectorPath).path.getBounds(),
      (published as ArchitectVectorPath).path.getBounds(),
    );
    expect(published.clip!.contains(const Offset(100, 100)), isFalse);
  });

  test(
    'static preview excludes active geometry but keeps complete sheet metadata',
    () {
      final project = _project();
      final background = ArchitectSheetComposer.compose(
        project,
        const ArchitectSheet(id: 'sheet', placements: [_placement]),
        l,
        allowMissing: true,
        excludePlacements: {'view'},
      );
      expect(
        background.operations.where((op) => op.sources.contains('line')),
        isEmpty,
      );
      expect(
        background.operations.whereType<ArchitectVectorText>().any(
          (op) => op.text == '1:100',
        ),
        isTrue,
      );
    },
  );

  test('invalid persisted placement stays editable but cannot publish', () {
    final project = _project();
    final sheet = ArchitectSheet(
      id: 'sheet',
      placements: [
        _placement.copyWith(scale: 0),
        _placement.copyWith(id: 'bad', crop: const []),
      ],
    );
    final preview = ArchitectSheetComposer.compose(
      project,
      sheet,
      l,
      allowMissing: true,
    );
    expect(
      preview.operations.whereType<ArchitectVectorText>().where(
        (op) => op.text == l.architectSheetInvalid,
      ),
      hasLength(2),
    );
    expect(
      () => ArchitectSheetComposer.compose(project, sheet, l),
      throwsStateError,
    );
  });

  test(
    'source cache revision ignores paper edits and tracks annotation changes',
    () {
      final project = _project();
      final paperEdit = project.copyWith(
        document: project.document.copyWith(
          sheets: const [
            ArchitectSheet(id: 'sheet', placements: [_placement]),
          ],
        ),
      );
      expect(
        ArchitectDrawingPublisher.sourceRevision(paperEdit),
        ArchitectDrawingPublisher.sourceRevision(project),
      );
      final textEdit = paperEdit.copyWith(
        document: paperEdit.document.copyWith(
          profileMm: const {'100/ordinary': 3.2},
        ),
      );
      expect(
        ArchitectDrawingPublisher.sourceRevision(textEdit),
        isNot(ArchitectDrawingPublisher.sourceRevision(project)),
      );
    },
  );

  test(
    'placement visibility inherits and overrides without changing siblings',
    () {
      final project = _project(
        drawing: _drawing.copyWith(visibility: {'annotations': false}),
      );
      final sheet = ArchitectSheet(
        id: 'sheet',
        placements: [
          _placement,
          _placement.copyWith(
            id: 'other',
            frame: _placement.frame.shift(const Offset(130, 0)),
            visibilityOverrides: const {'annotations': true},
          ),
        ],
      );
      final cache = <Object, ArchitectVectorScene>{};
      final scene = ArchitectSheetComposer.compose(
        project,
        sheet,
        l,
        drawingScenes: cache,
      );
      final annotations = scene.operations
          .whereType<ArchitectVectorText>()
          .where((op) => op.sources.contains('annotation'));
      expect(annotations, hasLength(1));
      expect(annotations.single.position.dx, greaterThan(150));
      expect(cache, hasLength(2));
      expect(
        project.document.drawings.single.visibility['annotations'],
        isFalse,
      );
    },
  );

  test(
    'paper-transform previews reuse scenes and expose off-sheet staging',
    () {
      final project = _project();
      final offSheet = _placement.copyWith(
        frame: _placement.frame.shift(const Offset(-50, 0)),
      );
      final sheet = ArchitectSheet(id: 'sheet', placements: [offSheet]);
      final cache = <Object, ArchitectVectorScene>{};
      final editor = ArchitectSheetComposer.compose(
        project,
        sheet,
        l,
        allowMissing: true,
        previewOutsideSheet: true,
        drawingScenes: cache,
      );
      final paper = ArchitectSheetComposer.compose(
        project,
        sheet,
        l,
        allowMissing: true,
        drawingScenes: cache,
      );
      const outside = Offset(-10, 40);
      final editorLine = editor.operations.firstWhere(
        (op) => op.sources.contains('line'),
      );
      final paperLine = paper.operations.firstWhere(
        (op) => op.sources.contains('line'),
      );
      expect(editorLine.clip!.contains(outside), isTrue);
      expect(paperLine.clip!.contains(outside), isFalse);
      final cached = cache.values.single;
      ArchitectSheetComposer.compose(
        project,
        sheet.copyWith(
          placements: [
            offSheet.copyWith(
              crop: const [Offset.zero, Offset(100, 0), Offset(0, 100)],
            ),
          ],
        ),
        l,
        allowMissing: true,
        previewOutsideSheet: true,
        drawingScenes: cache,
      );
      expect(cache, hasLength(1));
      expect(identical(cache.values.single, cached), isTrue);
      expect(
        () => ArchitectSheetComposer.compose(project, sheet, l),
        throwsStateError,
      );
    },
  );

  test(
    'visibility cache is canonical and custom scales retain paper text sizes',
    () {
      final project = _project();
      final first = ArchitectDrawingPublisher.build(
        project,
        _drawing.copyWith(visibility: {'axes': false, 'zones': false}),
        75,
        l,
      );
      final reordered = ArchitectDrawingPublisher.build(
        project,
        _drawing.copyWith(visibility: {'zones': false, 'axes': false}),
        75,
        l,
      );
      expect(identical(first, reordered), isTrue);
      final at100 = ArchitectDrawingPublisher.build(project, _drawing, 100, l);
      final at75 = ArchitectDrawingPublisher.build(project, _drawing, 75, l);
      ArchitectVectorText text(ArchitectVectorScene scene) => scene.operations
          .whereType<ArchitectVectorText>()
          .firstWhere((op) => op.sources.contains('annotation'));
      expect(text(at75).size, closeTo(text(at100).size, 1e-8));
      expect(at75.denominator, 75);
    },
  );

  test('custom-scale dimension witness strokes remain two paper mm long', () {
    const dimension = ArchitectDimension(
      id: 'dimension',
      startPoint: Offset.zero,
      endPoint: Offset(3, 0),
    );
    const tiers = [
      DimensionTier(
        tierIndex: 1,
        points: [Offset(1, 0)],
        segments: [],
        line: (Offset.zero, Offset(3, 0)),
      ),
    ];
    final segments = const ArchitectTextScope(
      ArchitectDocument(),
      'plan:storey',
      75,
      8000 / 75,
      publication: true,
    ).run(() => ArchitectDimensionLayout.witnessSegments(dimension, tiers));
    expect(
      (segments.single.$2 - segments.single.$1).distance,
      closeTo(.15, 1e-10),
    );
  });

  test(
    'PDF preserves polygon vector clips and text from the screen scene',
    () async {
      final project = _project();
      const sheet = ArchitectSheet(id: 'sheet', placements: [_placement]);
      final bytes = await ArchitectPdfExport.export(project, [sheet], l);
      final document = PdfDocument(inputBytes: bytes);
      try {
        expect(document.pages.count, 1);
        expect(
          PdfTextExtractor(document).extractText(),
          contains('Векторен текст'),
        );
      } finally {
        document.dispose();
      }
      final streams = _pdfStreams(bytes);
      expect(streams, contains('W'));
      expect(streams, contains('BT'));
      final folder = Directory('build/architect_sheet_crop')
        ..createSync(recursive: true);
      File('${folder.path}/crop.pdf').writeAsBytesSync(bytes);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(3);
      ArchitectSheetComposer.compose(project, sheet, l).paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1260, 891);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${folder.path}/crop.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      final pixels = (await image.toByteData())!.buffer.asUint8List();
      final removedPixel = (300 * 1260 + 300) * 4;
      expect(pixels.sublist(removedPixel, removedPixel + 3), [255, 255, 255]);
      image.dispose();
      picture.dispose();
    },
  );
}

String _pdfStreams(List<int> bytes) {
  final source = latin1.decode(bytes);
  final streams = <String>[];
  for (final match in RegExp(
    r'stream\r?\n([\s\S]*?)\r?\nendstream',
  ).allMatches(source)) {
    final content = latin1.encode(match[1]!);
    try {
      streams.add(latin1.decode(zlib.decode(content)));
    } on FormatException {
      streams.add(match[1]!);
    }
  }
  return streams.join('\n');
}
