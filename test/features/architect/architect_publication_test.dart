import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/rendering/architect_zone_painter_helper.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_composer.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_layout.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheets_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheet_viewport.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';

ArchitectProject fixture() => ArchitectProject(
  id: 'p',
  name: 'Проверка на печат',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [
    ArchitectStorey(
      id: 's',
      name: 'Етаж 1',
      walls: const [
        ArchitectWall(
          id: 'w1',
          startPoint: Offset.zero,
          endPoint: Offset(6, 0),
        ),
        ArchitectWall(
          id: 'w2',
          startPoint: Offset(6, 0),
          endPoint: Offset(6, 5),
        ),
        ArchitectWall(
          id: 'w3',
          startPoint: Offset(6, 5),
          endPoint: Offset(0, 5),
        ),
        ArchitectWall(
          id: 'w4',
          startPoint: Offset(0, 5),
          endPoint: Offset.zero,
        ),
      ],
      zones: const [
        ArchitectZone(
          id: 'z',
          number: '101',
          name: 'Дневна и трапезария',
          category: ArchitectZoneCategory.living,
          polygon: [
            Offset(.2, .2),
            Offset(5.8, .2),
            Offset(5.8, 4.8),
            Offset(.2, 4.8),
          ],
          floorFinish:
              'Дълго описание на настилка с фуги и допълнителни условия за изпълнение',
        ),
      ],
      zoneScheduleOrigin: const Offset(7, 0),
    ),
  ],
);
const drawing = ArchitectSavedDrawing(
  id: 'plan:s',
  sourceId: 's',
  kind: ArchitectDrawingKind.plan,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('bg'));
    final font = FontLoader('ArchitectNoto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await font.load();
  });
  test('paper conversion is independent of project input units', () {
    for (final unit in ArchitectUnit.values) {
      expect(
        const ArchitectDrawingScale(
          50,
        ).modelToPaper(unit.fromUnit(unit.toUnit(1))),
        closeTo(20, 1e-10),
      );
      expect(const ArchitectDrawingScale(100).modelToPaper(1), 10);
    }
    expect(const ArchitectDrawingScale(50).paperToModel(1.5), .075);
  });
  test('profiles and element overrides apply only at their scale', () {
    const d = ArchitectDocument(overrideMm: {'plan:s/z/area/50': 1.3});
    expect(d.textMm('plan:s', 'z', ArchitectAnnotationRole.area, 50), 1.3);
    expect(d.textMm('plan:s', 'z', ArchitectAnnotationRole.area, 100), 1.5);
    expect(
      d.textMm('plan:s', 'z', ArchitectAnnotationRole.roomName, 50),
      closeTo(1.6, 1e-10),
    );
  });
  test(
    'scenes retain vector text, sources, full table values and correct paper size',
    () {
      final p = fixture();
      final scene50 = ArchitectDrawingPublisher.build(p, drawing, 50, l);
      final scene100 = ArchitectDrawingPublisher.build(p, drawing, 100, l);
      final label50 = scene50.operations
          .whereType<ArchitectVectorText>()
          .where((e) => e.sources.contains('z'))
          .toList();
      final label100 = scene100.operations
          .whereType<ArchitectVectorText>()
          .where((e) => e.sources.contains('z'))
          .toList();
      expect(label50, isNotEmpty);
      expect(label50.any((e) => e.size > 0), isTrue);
      expect(label100, isNotEmpty);
      final stamp50 = label50.where((e) => e.role == 'roomName').toList();
      final stamp100 = label100.where((e) => e.role == 'roomName').toList();
      expect(label50.where((e) => e.role == 'area'), isEmpty);
      expect(stamp50.length, greaterThanOrEqualTo(2));
      expect(stamp100.length, greaterThanOrEqualTo(2));
      for (final t in stamp50) {
        expect(t.size * ArchitectDrawingScale.fontCapRatio, closeTo(1.6, 1e-8));
        expect(t.size, closeTo(stamp50.first.size, 1e-8));
      }
      for (final t in stamp100) {
        expect(
          t.size * ArchitectDrawingScale.fontCapRatio,
          inExclusiveRange(0, 1.5 + 1e-8),
        );
        expect(t.size, closeTo(stamp100.first.size, 1e-8));
      }
      expect(scene50.operations.whereType<ArchitectVectorPath>(), isNotEmpty);
      final text = scene50.operations
          .whereType<ArchitectVectorText>()
          .map((e) => e.text)
          .join(' ');
      expect(text, contains('допълнителни'));
      expect(text, isNot(contains('…')));
      final tableLines = label50
          .where(
            (e) =>
                e.role == 'table' &&
                e.text.contains(RegExp('Дълго|допълнителни|изпълнение')),
          )
          .toList();
      expect(
        tableLines.map((e) => e.position.dy).toSet().length,
        greaterThan(1),
      );
    },
  );
  test(
    'schedule resolves all default finishes in both languages and scales',
    () async {
      for (final language in ['bg', 'en']) {
        final locale = await AppLocalizations.delegate.load(Locale(language));
        for (final category in ArchitectZoneCategory.values) {
          final base = fixture();
          final zone = base.activeStorey.zones.single.copyWith(
            category: category,
            floorFinish: '',
            wallFinish: '',
            ceilingFinish: '',
          );
          // Defaults remain implicit through saving, just as newly created zones.
          final p = ArchitectProject.fromJson(
            base
                .copyWith(
                  storeys: [
                    base.activeStorey.copyWith(zones: [zone]),
                  ],
                )
                .toJson(),
          );
          for (final denominator in [50, 100]) {
            final tableText =
                ArchitectDrawingPublisher.build(p, drawing, denominator, locale)
                    .operations
                    .whereType<ArchitectVectorText>()
                    .where((t) => t.role == 'table')
                    .map((t) => t.text.trim())
                    .join(' ')
                    .replaceAll(RegExp(r'\s+'), ' ');
            for (final finish in [
              zone.resolvedFloorFinish(locale),
              zone.resolvedWallFinish(locale),
              zone.resolvedCeilingFinish(locale),
            ]) {
              expect(
                tableText,
                contains(finish),
                reason: '$language / ${category.name} / 1:$denominator',
              );
            }
            expect(tableText, isNot(contains('— — —')));
          }
        }
      }
    },
  );
  test(
    'compact schedule retains custom finishes and the paper text profile',
    () {
      final base = fixture();
      final p = base.copyWith(
        document: base.document.copyWith(viewScales: {'plan:s': 50}),
        storeys: [
          base.activeStorey.copyWith(
            zones: [
              base.activeStorey.zones.single.copyWith(
                floorFinish: 'Дъб',
                wallFinish: 'Вар',
                ceilingFinish: 'Дърво',
              ),
            ],
          ),
        ],
      );
      final table = ArchitectDrawingPublisher.build(p, drawing, 50, l)
          .operations
          .whereType<ArchitectVectorText>()
          .where((t) => t.role == 'table')
          .toList();
      for (final finish in ['Дъб', 'Вар', 'Дърво']) {
        expect(table.map((t) => t.text), contains(finish));
      }
      expect(
        table.every(
          (t) =>
              (t.size * ArchitectDrawingScale.fontCapRatio - 1.9).abs() < 1e-8,
        ),
        isTrue,
      );
      Rect bounds(double zoom) => ArchitectZonePainterHelper.getZoneTableBounds(
        storey: p.activeStorey,
        origin: Offset.zero,
        zoomScale: zoom,
        project: p,
        l10n: l,
      );
      expect(bounds(10), bounds(100));
      expect(
        const ArchitectDrawingScale(50).modelToPaper(bounds(10).width),
        allOf(greaterThan(40), lessThan(114)),
      );
      expect(
        const ArchitectDrawingScale(50).modelToPaper(bounds(10).height),
        lessThan(25),
      );
    },
  );
  test('legacy manual text retains its paper size at the inherited scale', () {
    final data = fixture().toJson()..remove('document');
    (data['storeys'] as List).first['annotations'] = [
      {
        'id': 'manual',
        'position': {'x': 1, 'y': 1},
        'text': 'Бележка',
        'fontSize': .3,
      },
    ];
    final p = ArchitectProject.fromJson(data);
    expect(
      p.document.textMm(
        'plan:s',
        'manual',
        ArchitectAnnotationRole.ordinary,
        100,
      ),
      3 * ArchitectDrawingScale.fontCapRatio,
    );
    expect(p.activeStorey.annotations.single.fontSize, .3);
  });
  test('scale navigation is retained through undo of document edits', () {
    final c = ArchitectCommandController(fixture());
    addTearDown(c.dispose);
    c.commit(
      c.project.copyWith(
        document: c.project.document.copyWith(profileMm: {'50/area': 1.3}),
      ),
    );
    c.replaceView(
      c.project.copyWith(
        document: c.project.document.copyWith(viewScales: {'plan:s': 50}),
      ),
    );
    c.undo();
    expect(c.project.document.viewScales['plan:s'], 50);
    expect(c.project.document.profileMm, isEmpty);
  });
  test(
    'publication formats metric and imperial areas using the project units',
    () {
      for (final unit in ArchitectUnit.values) {
        final scene = ArchitectDrawingPublisher.build(
          fixture().copyWith(units: unit),
          drawing,
          50,
          l,
        );
        expect(
          scene.operations.whereType<ArchitectVectorText>().any(
            (e) => e.text.contains(unit.isImperial ? 'ft²' : 'm²'),
          ),
          isTrue,
        );
      }
    },
  );
  test('sections and elevations publish through the same vector scene', () {
    final p = fixture().copyWith(
      sections: [
        const ArchitectSection(
          id: 'cut',
          start: Offset(-1, 2),
          end: Offset(7, 2),
        ),
      ],
      elevations: [
        const ArchitectElevation(
          id: 'facade',
          start: Offset(-1, -1),
          end: Offset(7, -1),
        ),
      ],
    );
    for (final d in [
      const ArchitectSavedDrawing(
        id: 'cut',
        sourceId: 'cut',
        kind: ArchitectDrawingKind.section,
      ),
      const ArchitectSavedDrawing(
        id: 'facade',
        sourceId: 'facade',
        kind: ArchitectDrawingKind.elevation,
      ),
    ]) {
      final scene = ArchitectDrawingPublisher.build(p, d, 50, l);
      expect(scene.operations.whereType<ArchitectVectorPath>(), isNotEmpty);
      expect(scene.bounds.width, greaterThan(0));
    }
  });
  test(
    'CAD publication preserves the saved rotation, source units and hidden layers',
    () {
      const origin = Offset(4250000, 4780000);
      const cadLength = 100.125;
      final cad = DxfDocument(
        layers: {},
        blocks: {},
        entities: [
          DxfLine(
            p1: origin,
            p2: origin + const Offset(cadLength, 0),
            layer: 'survey',
          ),
        ],
        headerVars: {},
        bounds: Rect.fromLTWH(origin.dx, origin.dy, cadLength, 1),
        entityStats: {},
      );
      final sources = ArchitectPublicationSources(
        underlays: {'s': cad},
        frame: const BimCoordinateFrame(
          origin: origin,
          unitsPerMeter: 100,
        ),
      );
      const angle = .22;
      final project = fixture().copyWith(cadUnderlays: {
        's': ArchitectCadUnderlayConfig(
          storeyId: 's',
          fileName: 'survey.dxf',
          internalCopyPath: 'survey.dxf',
          lockedCadOriginX: origin.dx,
          lockedCadOriginY: origin.dy,
          unitsPerMeter: 100,
          rotationRad: angle,
        ),
      });
      final visible = ArchitectDrawingPublisher.build(
        project,
        drawing,
        50,
        l,
        sources: sources,
      );
      final hidden = ArchitectDrawingPublisher.build(
        project,
        drawing.copyWith(visibility: {'cad:survey': false}),
        50,
        l,
        sources: sources,
      );
      expect(visible.operations.length, hidden.operations.length + 1);
      final line = visible.operations.whereType<ArchitectVectorPath>().first;
      expect(line.path.getBounds().left, closeTo(0, 1e-8));
      expect(line.path.getBounds().right, closeTo(cadLength / 5 * math.cos(angle), 1e-5));
      expect(line.path.getBounds().bottom, closeTo(cadLength / 5 * math.sin(angle), 1e-5));
    },
  );
  test(
    'sheets and templates round trip; document edits undo without changing geometry',
    () {
      final p = fixture();
      final c = ArchitectCommandController(p);
      addTearDown(c.dispose);
      final sheet = ArchitectSheet(
        id: 'sheet',
        placements: const [
          ArchitectDrawingPlacement(
            id: 'place',
            drawingId: 'plan:s',
            frame: Rect.fromLTWH(10, 10, 180, 220),
            anchor: Offset(-1, -1),
            scale: 50,
          ),
        ],
      );
      c.commit(
        c.project.copyWith(
          document: c.project.document.copyWith(
            drawings: [drawing],
            sheets: [sheet],
          ),
        ),
      );
      final restored = ArchitectProject.fromJson(c.project.toJson());
      expect(restored.document.sheets.single.toJson(), sheet.toJson());
      c.undo();
      expect(c.project.document.sheets, isEmpty);
      c.redo();
      expect(c.project.document.sheets.single.id, 'sheet');
      expect(c.project.activeStorey.walls.length, 4);
    },
  );
  test('missing source blocks publication and placement anchor is stable', () {
    final place = ArchitectDrawingPlacement(
      id: 'place',
      drawingId: 'plan:s',
      frame: const Rect.fromLTWH(10, 10, 150, 180),
      anchor: const Offset(-1, -1),
    );
    final sheet = ArchitectSheet(id: 'sheet', placements: [place]);
    final p = fixture().copyWith(
      document: ArchitectDocument(drawings: [drawing], sheets: [sheet]),
    );
    ArchitectSheetComposer.compose(p, sheet, l);
    expect(
      p.document.sheets.single.placements.single.anchor,
      const Offset(-1, -1),
    );
    expect(
      () => ArchitectSheetComposer.compose(p.copyWith(storeys: []), sheet, l),
      throwsStateError,
    );
  });
  test(
    'PDF has exact mixed page sizes, Cyrillic text and vector content',
    () async {
      final sheet = ArchitectSheet(
        id: 'sheet',
        name: 'Разпределение',
        placements: const [
          ArchitectDrawingPlacement(
            id: 'place',
            drawingId: 'plan:s',
            frame: Rect.fromLTWH(10, 10, 390, 230),
            anchor: Offset(-1, -1),
            scale: 50,
          ),
        ],
      );
      final p = fixture().copyWith(
        document: ArchitectDocument(drawings: [drawing], sheets: [sheet]),
      );
      final small = sheet.copyWith(widthMm: 297, heightMm: 210, placements: []);
      final fitted = ArchitectSheetLayout.fit(
        sheet.placements.single,
        ArchitectSheetLayout.drawingArea(p, small),
        (scale) => ArchitectDrawingPublisher.build(p, drawing, scale, l),
        title: (scale) => '1  ${l.architectSheetPlan}  1:$scale',
      );
      final bytes = await ArchitectPdfExport.export(p, [
        sheet,
        small.copyWith(placements: [fitted]),
      ], l);
      final pdf = PdfDocument(inputBytes: bytes);
      expect(pdf.pages.count, 2);
      expect(pdf.pages[0].size.width, closeTo(420 * 72 / 25.4, .01));
      expect(pdf.pages[1].size.width, closeTo(297 * 72 / 25.4, .01));
      expect(PdfTextExtractor(pdf).extractText(), contains('Проверка'));
      pdf.dispose();
      final folder = Directory('build/architect_publication')
        ..createSync(recursive: true);
      File('${folder.path}/sheets.pdf').writeAsBytesSync(bytes);
      final scene = ArchitectSheetComposer.compose(p, sheet, l);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec)..scale(3);
      scene.paint(canvas);
      final picture = rec.endRecording();
      final image = await picture.toImage(1260, 891);
      File('${folder.path}/screen.png').writeAsBytesSync(
        (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
      image.dispose();
      picture.dispose();
    },
  );
  test(
    'PDF export preserves exact sharp wall corners and miter joins without chamfering',
    () async {
      // Non-0.2mm-multiple vertices intentionally expose uniform arc resampling bugs.
      const vertices = <Offset>[
        Offset(10.13, 20.07),
        Offset(73.49, 20.07),
        Offset(73.49, 25.31),
        Offset(46.87, 25.31),
        Offset(46.87, 68.19),
        Offset(41.63, 68.19),
        Offset(41.63, 25.31),
        Offset(10.13, 25.31),
      ];
      final tWallPath = Path()..addPolygon(vertices, true);
      final contours = ArchitectPdfExport.extractPathContours(tWallPath);
      expect(contours, hasLength(1));
      expect(contours.single.closed, isTrue);
      expect(contours.single.points, hasLength(vertices.length));
      for (final expected in vertices) {
        final match = contours.single.points.any(
          (p) => (p - expected).distance < 1e-4,
        );
        expect(match, isTrue, reason: 'Missing exact corner $expected');
      }

      // Smooth arc/circle retains tight curve fidelity.
      final circle = Path()
        ..addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 18));
      final arcContours = ArchitectPdfExport.extractPathContours(circle);
      expect(arcContours, hasLength(1));
      expect(arcContours.single.closed, isTrue);
      for (final pt in arcContours.single.points) {
        expect((pt - const Offset(50, 50)).distance, closeTo(18, .01));
      }

      // Vector canvas preserves stroke join/cap/miterLimit separately from round strokes.
      final canvas = ArchitectVectorCanvas();
      canvas.drawPath(
        tWallPath,
        Paint()
          ..color = const Color(0xFF212121)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
      canvas.drawPath(
        Path()
          ..moveTo(15, 15)
          ..lineTo(35, 15)
          ..lineTo(35, 30),
        Paint()
          ..color = const Color(0xFF0000FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      expect(canvas.operations, hasLength(2));
      final firstOp = canvas.operations[0] as ArchitectVectorPath;
      final secondOp = canvas.operations[1] as ArchitectVectorPath;
      expect(firstOp.strokeJoin, StrokeJoin.miter);
      expect(firstOp.strokeCap, StrokeCap.butt);
      expect(secondOp.strokeJoin, StrokeJoin.round);
      expect(secondOp.strokeCap, StrokeCap.round);

      // Export a real T-wall plan to PDF and verify PDF graphics stream uses miter join (`0 j`)
      // and never rounds wall borders (`1 j`) unless explicitly requested.
      final wallProject = ArchitectProject(
        id: 't_walls',
        name: 'T Walls',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's',
        storeys: [
          ArchitectStorey(
            id: 's',
            name: 'Floor 1',
            walls: [
              ArchitectWall(
                id: 'w1',
                startPoint: const Offset(0, 0),
                endPoint: const Offset(4.37, 0),
                thickness: .25,
              ),
              ArchitectWall(
                id: 'w2',
                startPoint: const Offset(2.13, 0),
                endPoint: const Offset(2.13, 3.19),
                thickness: .25,
              ),
            ],
          ),
        ],
        document: ArchitectDocument(
          drawings: const [
            ArchitectSavedDrawing(
              id: 'plan:s',
              kind: ArchitectDrawingKind.plan,
              sourceId: 's',
            ),
          ],
          sheets: const [
            ArchitectSheet(
              id: 'sheet',
              name: 'Sheet',
              placements: [
                ArchitectDrawingPlacement(
                  id: 'place',
                  drawingId: 'plan:s',
                  frame: Rect.fromLTWH(10, 10, 200, 160),
                  anchor: Offset(-1, -1),
                  scale: 50,
                ),
              ],
            ),
          ],
        ),
      );
      final bytes = await ArchitectPdfExport.export(
        wallProject,
        wallProject.document.sheets,
        l,
      );
      final decodedStreams = StringBuffer();
      var searchOffset = 0;
      final rawLatin = latin1.decode(bytes);
      while (true) {
        final startToken = rawLatin.indexOf('stream', searchOffset);
        if (startToken < 0) break;
        var bodyStart = startToken + 'stream'.length;
        if (bodyStart < bytes.length && bytes[bodyStart] == 13) bodyStart++;
        if (bodyStart < bytes.length && bytes[bodyStart] == 10) bodyStart++;
        final endToken = rawLatin.indexOf('endstream', bodyStart);
        if (endToken < 0) break;
        var bodyEnd = endToken;
        if (bodyEnd > bodyStart && bytes[bodyEnd - 1] == 10) bodyEnd--;
        if (bodyEnd > bodyStart && bytes[bodyEnd - 1] == 13) bodyEnd--;
        final chunk = bytes.sublist(bodyStart, bodyEnd);
        try {
          decodedStreams.writeln(latin1.decode(zlib.decode(chunk)));
        } catch (_) {
          decodedStreams.writeln(latin1.decode(chunk));
        }
        searchOffset = endToken + 'endstream'.length;
      }
      final streamText = decodedStreams.toString();
      expect(streamText, contains('0 j'));
      expect(streamText, isNot(contains('1 j')));
    },
  );
  testWidgets('phone sheet editor creates a sheet and places a linked source', (
    tester,
  ) async {
    tester.view.resetPhysicalSize();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = ArchitectCommandController(fixture());
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectSheetsScreen(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(c.project.document.sheets, hasLength(1));
    await tester.tap(find.byTooltip('Place view'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Етаж 1').last);
    await tester.pumpAndSettle();
    expect(c.project.document.sheets.single.placements, isEmpty);
    final viewport = tester.state<ArchitectSheetViewportState>(
      find.byType(ArchitectSheetViewport),
    );
    await tester.tapAt(
      tester.getTopLeft(
            find.byKey(const ValueKey('architect-sheet-viewport-input')),
          ) +
          viewport.paperToScreen(const Offset(10, 10)),
    );
    await tester.pumpAndSettle();
    expect(c.project.document.sheets.single.placements, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'bg']) {
    testWidgets(
      'phone scale navigation retains zoom and opens sheets in $language',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ArchitectCommandController(fixture());
        addTearDown(controller.dispose);
        final labels = await AppLocalizations.delegate.load(Locale(language));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchitectWorkspaceScreen(commandController: controller),
          ),
        );
        await tester.pumpAndSettle();
        final modelPainter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<Architect2dPainter>()
            .firstWhere((p) => p.layer == ArchitectPaintLayer.interaction);
        final zoom = modelPainter.viewport!.scale;
        final picker = find.byWidgetPredicate(
          (w) =>
              w is DropdownButton<int> &&
              w.items?.length == ArchitectDrawingScale.presets.length,
        );
        // Normal modeling workspace keeps the top toolbar free of a permanent scale dropdown.
        expect(picker, findsNothing);
        await tester.tap(find.byTooltip(labels.architectSheets));
        await tester.pumpAndSettle();
        await tester.tap(find.text(labels.architectPrintPreview));
        await tester.pumpAndSettle();
        expect(picker, findsOneWidget);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('1:50').last);
        await tester.pumpAndSettle();
        expect(controller.project.document.viewScales['plan:s'], 50);
        expect(modelPainter.viewport!.scale, zoom);
        expect(controller.canUndo, isFalse);
        await tester.tap(find.byTooltip(labels.architectSheets));
        await tester.pumpAndSettle();
        await tester.tap(find.text(labels.architectSheets));
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectSheetsScreen), findsOneWidget);
        final sheetsFonts = find.byKey(const ValueKey('architect-sheets-fonts'));
        expect(sheetsFonts, findsOneWidget);
        await tester.tap(sheetsFonts);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-font-inc-100-axis')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-layout-fonts-save')),
        );
        await tester.pumpAndSettle();
        expect(controller.project.document.profileMm['100/axis'], closeTo(3.1, 1e-6));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
