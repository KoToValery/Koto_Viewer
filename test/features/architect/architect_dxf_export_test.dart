import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_dxf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_dxf_writer.dart';
import 'package:kotoview/src/features/architect/services/architect_export_job.dart';
import 'package:kotoview/src/features/architect/services/architect_pdf_export.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_composer.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_geometry.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

const _drawing = ArchitectSavedDrawing(
  id: 'plan:s',
  sourceId: 's',
  kind: ArchitectDrawingKind.plan,
);

ArchitectProject _fixture() => ArchitectProject(
  id: 'dxf-test',
  name: 'Къща',
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
          name: 'Дневна',
          category: ArchitectZoneCategory.living,
          polygon: [
            Offset(.2, .2),
            Offset(5.8, .2),
            Offset(5.8, 4.8),
            Offset(.2, 4.8),
          ],
        ),
      ],
    ),
  ],
  sections: const [
    ArchitectSection(id: 'cut', start: Offset(-1, 2), end: Offset(7, 2)),
  ],
  elevations: const [
    ArchitectElevation(id: 'elev', start: Offset(-1, -1), end: Offset(7, -1)),
  ],
  document: const ArchitectDocument(drawings: [_drawing]),
);

List<List<(int, String)>> _records(List<int> bytes) {
  final lines = utf8.decode(bytes).split(RegExp(r'\r?\n'));
  final result = <List<(int, String)>>[];
  var current = <(int, String)>[];
  for (var i = 0; i + 1 < lines.length; i += 2) {
    final code = int.parse(lines[i].trim()), value = lines[i + 1];
    if (code == 0 && current.isNotEmpty) {
      result.add(current);
      current = [];
    }
    current.add((code, value));
  }
  if (current.isNotEmpty) result.add(current);
  return result;
}

String? _tag(List<(int, String)> record, int code) =>
    record.where((e) => e.$1 == code).firstOrNull?.$2;
List<List<(int, String)>> _entities(List<int> bytes, String kind) =>
    _records(bytes).where((e) => _tag(e, 0) == kind).toList();
Future<void> _artifact(String name, List<int> bytes) async {
  final dir = Directory('build/architect_exports')..createSync(recursive: true);
  await File('${dir.path}/$name').writeAsBytes(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('bg'));
    final fonts = FontLoader('ArchitectNoto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await fonts.load();
  });

  test(
    'source views use real project units, editable native vectors and UTF-8',
    () async {
      const expected = {
        ArchitectUnit.meters: 6,
        ArchitectUnit.centimeters: 5,
        ArchitectUnit.millimeters: 4,
        ArchitectUnit.feet: 2,
        ArchitectUnit.inches: 1,
      };
      for (final unit in ArchitectUnit.values) {
        final files = await ArchitectDxfExport.exportViews(
          _fixture().copyWith(units: unit),
          [_drawing],
          l,
        );
        final bytes = files.values.single, records = _records(bytes);
        final text = utf8.decode(bytes);
        expect(text, contains('AC1027'));
        expect(text, contains('Дневна'));
        final headers = records.firstWhere((r) => _tag(r, 2) == 'HEADER');
        final index = headers.indexWhere((p) => p == (9, r'$INSUNITS'));
        expect(headers[index + 1], (70, '${expected[unit]}'));
        expect(_entities(bytes, 'MTEXT'), isNotEmpty);
        expect(_entities(bytes, 'HATCH'), isNotEmpty);
        expect(_entities(bytes, 'IMAGE'), isEmpty);
        final xs = _entities(bytes, 'LWPOLYLINE')
            .expand((r) => r)
            .where((t) => t.$1 == 10)
            .map((t) => double.parse(t.$2));
        expect(
          xs.any((x) => (x - unit.toUnit(6)).abs() < unit.toUnit(.16)),
          isTrue,
        );
        await _artifact('source_${unit.name}.dxf', bytes);
      }
    },
  );

  test(
    'plan exports holes and centered grid bubbles as CAD linework',
    () async {
      final project = _fixture()
          .copyWith(
            sections: const [],
            elevations: const [],
            gridAxes: const [
              StructuralGridAxis(
                id: 'axis',
                name: 'Б2',
                start: Offset(0, -2),
                end: Offset(6, -2),
              ),
            ],
          )
          .updateActiveStorey(
            const ArchitectStorey(
              id: 's',
              name: 'Етаж 1',
              walls: [
                ArchitectWall(
                  id: 'w',
                  startPoint: Offset.zero,
                  endPoint: Offset(6, 0),
                  doors: [
                    ArchitectDoor(
                      id: 'door',
                      wallId: 'w',
                      offsetRatio: .25,
                      uuid: 'd',
                    ),
                  ],
                  windows: [
                    ArchitectWindow(
                      id: 'window',
                      wallId: 'w',
                      offsetRatio: .75,
                      uuid: 'w',
                    ),
                  ],
                ),
              ],
              stairs: [
                ArchitectStair(
                  id: 'stair',
                  startPoint: Offset(8, 2),
                  endPoint: Offset(12, 2),
                  width: 1.2,
                  design: ArchitectStairDesign(
                    shape: StairShape.straight,
                    showLabel: false,
                  ),
                ),
              ],
            ),
          );
      final bytes = (await ArchitectDxfExport.exportViews(project, [
        _drawing,
      ], l)).values.single;
      final records = _records(bytes);
      final grid = records.where((r) => _tag(r, 8) == 'A-GRID');
      final circles = grid.where((r) => _tag(r, 0) == 'CIRCLE').toList();
      expect(circles, hasLength(2));
      final labels = grid.where((r) => _tag(r, 0) == 'MTEXT').toList();
      expect(labels, hasLength(2));
      for (var i = 0; i < circles.length; i++) {
        expect(_tag(labels[i], 1), 'Б2');
        expect(_tag(labels[i], 71), '5');
        expect(_tag(labels[i], 10), _tag(circles[i], 10));
        expect(_tag(labels[i], 20), _tag(circles[i], 20));
      }
      final hatches = _entities(bytes, 'HATCH');
      expect(hatches, isNotEmpty);
      expect(hatches.any((r) => _tag(r, 2) == 'SOLID'), isFalse);
      expect(
        _entities(bytes, 'LWPOLYLINE').where((r) => _tag(r, 8) == 'A-STAIR'),
        isNotEmpty,
      );
      final wallOutlines = _entities(
        bytes,
        'LWPOLYLINE',
      ).where((r) => _tag(r, 8) == 'A-WALL');
      expect(wallOutlines, isNotEmpty);
      for (final outline in wallOutlines) {
        expect(_tag(outline, 62), '7');
        expect(_tag(outline, 420), isNull);
        final xs = outline
            .where((p) => p.$1 == 10)
            .map((p) => double.parse(p.$2));
        for (final gap in [1.5, 4.5]) {
          expect(xs.any((x) => x < gap) && xs.any((x) => x > gap), isFalse);
        }
      }
      await _artifact('clean_plan.dxf', bytes);
    },
  );

  test('plans, sections and elevations all use publisher vectors', () async {
    final p = _fixture();
    final drawings = [
      _drawing,
      const ArchitectSavedDrawing(
        id: 'cut',
        sourceId: 'cut',
        kind: ArchitectDrawingKind.section,
      ),
      const ArchitectSavedDrawing(
        id: 'elev',
        sourceId: 'elev',
        kind: ArchitectDrawingKind.elevation,
      ),
    ];
    final files = await ArchitectDxfExport.exportViews(p, drawings, l);
    expect(files.length, 3);
    for (final entry in files.entries) {
      expect(_entities(entry.value, 'LWPOLYLINE'), isNotEmpty);
      await _artifact('view_${entry.key}', entry.value);
    }
  });

  test(
    'sheet has native CAD Layout and isolated rotated clipped viewports',
    () async {
      const a = ArchitectDrawingPlacement(
        id: 'a',
        drawingId: 'plan:s',
        frame: Rect.fromLTWH(20, 20, 130, 110),
        anchor: Offset(-1, -1),
        rotation: 27,
        crop: [
          Offset.zero,
          Offset(130, 0),
          Offset(130, 70),
          Offset(60, 70),
          Offset(60, 110),
          Offset(0, 110),
        ],
      );
      const b = ArchitectDrawingPlacement(
        id: 'b',
        drawingId: 'plan:s',
        number: '2',
        scale: 200,
        frame: Rect.fromLTWH(180, 20, 100, 100),
        anchor: Offset(-1, -1),
        visibilityOverrides: {'zones': false},
      );
      const sheet = ArchitectSheet(id: 'sheet', placements: [a, b]);
      final project = _fixture();
      expect(ArchitectSheetComposer.issues(project, sheet, l), isEmpty);
      final progress = <double>[];
      final files = await ArchitectDxfExport.exportSheets(
        project,
        [sheet],
        l,
        onProgress: progress.add,
      );
      final bytes = files.values.single;
      final ports = _entities(
        bytes,
        'VIEWPORT',
      ).where((v) => _tag(v, 69) != '1').toList();
      expect(ports.length, 2);
      expect(
        double.parse(_tag(ports[0], 41)!) / double.parse(_tag(ports[0], 45)!),
        closeTo(10, 1e-9),
      );
      expect(
        double.parse(_tag(ports[1], 41)!) / double.parse(_tag(ports[1], 45)!),
        closeTo(5, 1e-9),
      );
      expect(_tag(ports[0], 51), '-27.0');
      expect(_tag(ports[0], 340), isNotNull);
      expect(_tag(ports[1], 340), isNull);
      expect(ports.every((p) => _tag(p, 331) != null), isTrue);
      final boundary = _records(
        bytes,
      ).singleWhere((e) => _tag(e, 5) == _tag(ports[0], 340));
      expect(_tag(boundary, 0), 'LWPOLYLINE');
      expect(_tag(boundary, 90), '6');
      expect(_entities(bytes, 'LAYOUT').length, 2);
      expect(
        _entities(
          bytes,
          'BLOCK',
        ).where((b) => (_tag(b, 2) ?? '').startsWith('KOTO_DRAWING_')).length,
        2,
      );
      expect(progress.last, 1);
      expect([...progress]..sort(), progress);
      await _artifact('sheet_native.dxf', bytes);
      await _artifact(
        'sheet_native.pdf',
        await ArchitectPdfExport.export(project, [sheet], l),
      );
      final source = const Offset(3, 2),
          expected = ArchitectSheetGeometry.sourceToPaper(a, source);
      await File(
        'build/architect_exports/sheet_native.expected.json',
      ).writeAsString(
        jsonEncode({
          'paperWidth': sheet.widthMm,
          'paperHeight': sheet.heightMm,
          'units': 6,
          'viewportScales': [10, 5],
          'pointModel': [source.dx, -source.dy, 0],
          'pointPaper': [expected.dx, sheet.heightMm - expected.dy, 0],
        }),
      );
    },
  );

  test(
    'native source text clips and hatch holes survive worker serialization',
    () async {
      final bytes = ArchitectDxfWriter.write({
        'units': 4,
        'views': [
          {
            'entities': [
              {
                'type': 'text',
                'text': 'Кирилица {editable} \\ CAD',
                'at': [0.0, 10.0],
                'height': 2.2,
                'width': 40.0,
                'clipPolygons': [
                  [
                    [0.0, 0.0],
                    [20.0, 0.0],
                    [20.0, 10.0],
                    [0.0, 10.0],
                  ],
                ],
              },
              {
                'type': 'hatch',
                'loops': [
                  {
                    'outer': true,
                    'points': [
                      [0.0, 0.0],
                      [30.0, 0.0],
                      [30.0, 30.0],
                      [0.0, 30.0],
                    ],
                  },
                  {
                    'outer': false,
                    'points': [
                      [10.0, 10.0],
                      [20.0, 10.0],
                      [20.0, 20.0],
                      [10.0, 20.0],
                    ],
                  },
                ],
              },
              {
                'type': 'hatch',
                'loops': [
                  {
                    'outer': true,
                    'points': [
                      [0.0, 0.0],
                      [10.0, 0.0],
                      [10.0, 10.0],
                      [0.0, 10.0],
                    ],
                  },
                ],
                'pattern': [
                  [45.0, 0.0, 0.0, -10.0, 10.0, 5.0, -100.0],
                ],
              },
            ],
          },
        ],
      });
      expect(_entities(bytes, 'SPATIAL_FILTER').length, 1);
      expect(_entities(bytes, 'MTEXT').length, 1);
      expect(_entities(bytes, 'INSERT').length, 1);
      expect(_tag(_entities(bytes, 'HATCH').first, 91), '2');
      await _artifact('native_clips_hatches.dxf', bytes);
    },
  );

  test(
    'supplied phone project keeps full geometry at two publication scales',
    () async {
      var project = ArchitectProject.fromJson(
        jsonDecode(
          await File(
            'test/fixtures/architect_layout_two_views_2026_11_05.json',
          ).readAsString(),
        ),
      );
      final original = project.document.sheets.single;
      // The supplied frames overlap, which correctly blocks final publication.
      expect(ArchitectSheetComposer.issues(project, original, l), isNotEmpty);
      final sheet = original.copyWith(
        widthMm: 594,
        heightMm: 420,
        placements: [
          original.placements.first,
          original.placements[1].copyWith(
            frame: Rect.fromLTWH(
              320,
              25,
              original.placements[1].frame.width,
              original.placements[1].frame.height,
            ),
          ),
        ],
      );
      project = project.copyWith(
        document: project.document.copyWith(sheets: [sheet]),
      );
      expect(ArchitectSheetComposer.issues(project, sheet, l), isEmpty);
      final source = await ArchitectDxfExport.exportViews(
        project,
        project.document.drawings,
        l,
      );
      await _artifact('phone_source.dxf', source.values.single);
      final files = await ArchitectDxfExport.exportSheets(project, [sheet], l);
      final bytes = files.values.single;
      expect(_entities(bytes, 'VIEWPORT').length, 3);
      expect(_entities(bytes, 'MTEXT'), isNotEmpty);
      expect(_entities(bytes, 'HATCH'), isNotEmpty);
      await _artifact('phone_sheet.dxf', bytes);
      expect(
        _entities(bytes, 'HATCH').any((h) => _tag(h, 440) != null),
        isTrue,
        reason:
            'Semitransparent floor fills must preserve the room text below them.',
      );
      await _artifact(
        'phone_sheet.pdf',
        await ArchitectPdfExport.export(project, [sheet], l),
      );
    },
  );

  test(
    'publication blockers remain blockers and cancellation yields no output',
    () async {
      final p = _fixture();
      const sheet = ArchitectSheet(
        id: 'bad',
        placements: [
          ArchitectDrawingPlacement(
            id: 'outside',
            drawingId: 'plan:s',
            frame: Rect.fromLTWH(-20, 0, 50, 50),
            anchor: Offset.zero,
          ),
        ],
      );
      await expectLater(
        ArchitectDxfExport.exportSheets(p, [sheet], l),
        throwsStateError,
      );
      var cancelled = false;
      await expectLater(
        ArchitectDxfExport.exportViews(
          p,
          [_drawing],
          l,
          onProgress: (_) => cancelled = true,
          isCancelled: () => cancelled,
        ),
        throwsA(isA<ArchitectExportCancelled>()),
      );
    },
  );
  test('cancelling native serialization stops its worker promptly', () async {
    final entity = <String, Object?>{
      'type': 'polyline',
      'points': [
        [0.0, 0.0],
        [1.0, 1.0],
      ],
      'closed': false,
    };
    var cancelled = false;
    final timer = Timer(
      const Duration(milliseconds: 100),
      () => cancelled = true,
    );
    final watch = Stopwatch()..start();
    try {
      await expectLater(
        ArchitectDxfWriter.writeInWorker({
          'units': 6,
          'views': [
            {'entities': List.filled(200000, entity)},
          ],
        }, isCancelled: () => cancelled),
        throwsA(isA<ArchitectExportCancelled>()),
      );
      expect(
        watch.elapsedMilliseconds,
        lessThan(3000),
        reason:
            'Cancellation must stop the worker before it finishes the file.',
      );
    } finally {
      timer.cancel();
    }
  });

  test(
    'geodetic DXF export restores original survey CAD coordinates for moved underlay, rotated parcel, and sheet viewports',
    () async {
      expect(ArchitectDxfExport.supportsGeodeticExport(_fixture()), isFalse);

      const cadOrigin = Offset(8500000, 4720000);
      const originalFrame = BimCoordinateFrame(
        origin: cadOrigin,
        unitsPerMeter: 1.0,
        invertY: true,
        rotationRadians: math.pi / 6,
      );
      const cadP1 = Offset(8500000, 4720000);
      const cadP2 = Offset(8500010, 4720000);
      const cadP3 = Offset(8500010, 4720008);
      const cadP4 = Offset(8500000, 4720008);

      // Simulate moving underlay + parcel together by (+4, -2) m in workspace.
      const moveDelta = Offset(4, -2);
      final movedFrame = originalFrame.placing(cadOrigin, moveDelta);
      final movedParcel = ArchitectSiteParcel([
        for (final c in const [cadP1, cadP2, cadP3, cadP4])
          movedFrame.toModel(c),
      ]);

      final surveyDoc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: const {},
        entities: const [DxfLine(p1: cadP1, p2: cadP2)],
        headerVars: const {},
        bounds: const Rect.fromLTRB(8500000, 4720000, 8500010, 4720008),
        entityStats: const {},
      );

      final starter = ArchitectProject.starterWithCatalog(
        name: 'Geo',
        storeyCount: 1,
      ).copyWith(units: ArchitectUnit.centimeters);
      final site = starter.siteStorey!;
      final ground = starter.storeys.firstWhere((s) => !s.isSite);
      final siteDrawing = ArchitectSavedDrawing(
        id: 'plan:${site.id}',
        sourceId: site.id,
        kind: ArchitectDrawingKind.plan,
        sitePlan: true,
      );
      final groundDrawing = ArchitectSavedDrawing(
        id: 'plan:${ground.id}',
        sourceId: ground.id,
        kind: ArchitectDrawingKind.plan,
      );
      const siteSheet = ArchitectSheet(
        id: 'geo-sheet',
        number: 'A01',
        placements: [
          ArchitectDrawingPlacement(
            id: 'vp1',
            drawingId: 'plan:site',
            frame: Rect.fromLTWH(20, 20, 120, 90),
            anchor: Offset.zero,
            scale: 200,
          ),
        ],
      );

      final project = starter
          .copyWith(
            activeStoreyId: site.id,
            storeys: [
              for (final s in starter.storeys)
                if (s.id == site.id)
                  s.copyWith(siteParcel: movedParcel)
                else
                  s.copyWith(
                    walls: const [
                      ArchitectWall(
                        id: 'w',
                        startPoint: Offset.zero,
                        endPoint: Offset(5, 0),
                      ),
                    ],
                  ),
            ],
            document: ArchitectDocument(
              drawings: [siteDrawing, groundDrawing],
              sheets: [
                siteSheet.copyWith(
                  placements: [
                    siteSheet.placements.single.copyWith(
                      drawingId: siteDrawing.id,
                    ),
                  ],
                ),
              ],
            ),
          )
          .withCadUnderlayAdded(
            ArchitectCadUnderlayConfig(
              id: 'survey',
              storeyId: site.id,
              fileName: 'survey.dxf',
              internalCopyPath: '',
              unitsPerMeter: movedFrame.unitsPerMeter,
              lockedCadOriginX: movedFrame.origin.dx,
              lockedCadOriginY: movedFrame.origin.dy,
              cadOrientation: movedFrame.invertY,
              rotationRad: movedFrame.rotationRadians,
              lockOrigin: true,
              isGeodetic: true,
            ),
          );

      expect(ArchitectDxfExport.supportsGeodeticExport(project), isTrue);

      final sources = ArchitectPublicationSources(
        underlays: {site.id: surveyDoc},
      );

      // 1. Export Site Plan + Ground Floor views in geodetic coordinates.
      final files = await ArchitectDxfExport.exportViews(
        project,
        [siteDrawing, groundDrawing],
        l,
        sources: sources,
        geodeticCoordinates: true,
      );
      expect(files, hasLength(2));

      final siteDxf = utf8.decode(files.values.first);
      // INSUNITS follows geodetic unitsPerMeter = 1.0 (meters -> 6), not project cm (5).
      final siteHeader = _records(files.values.first)
          .firstWhere((r) => _tag(r, 0) == 'SECTION' && r.any((t) => t.$2 == 'HEADER'));
      expect(siteDxf, contains(r'$INSUNITS' '\r\n70\r\n6'));
      expect(siteHeader, isNotEmpty);

      // Verify parcel vertices restored to original survey coordinates (8500000, 4720000) & (8500010, 4720008).
      final polylines = _entities(files.values.first, 'LWPOLYLINE');
      final allPoints = <(double, double)>[];
      for (final poly in polylines) {
        final xs = [for (final t in poly) if (t.$1 == 10) double.parse(t.$2)];
        final ys = [for (final t in poly) if (t.$1 == 20) double.parse(t.$2)];
        for (var i = 0; i < xs.length && i < ys.length; i++) {
          allPoints.add((xs[i], ys[i]));
        }
      }
      expect(
        allPoints.any(
          (p) => (p.$1 - cadP1.dx).abs() < 1e-2 && (p.$2 - cadP1.dy).abs() < 1e-2,
        ),
        isTrue,
      );
      expect(
        allPoints.any(
          (p) => (p.$1 - cadP3.dx).abs() < 1e-2 && (p.$2 - cadP3.dy).abs() < 1e-2,
        ),
        isTrue,
      );

      // Ground floor wall endpoints also land in geodetic survey coordinates (~8.5e6, ~4.72e6).
      final groundPolys = _entities(files.values.last, 'LWPOLYLINE');
      final groundX = groundPolys
          .expand((poly) => poly.where((t) => t.$1 == 10).map((t) => double.parse(t.$2)))
          .toList();
      expect(groundX.any((x) => (x - 8500000).abs() < 20), isTrue);

      // 2. Export sheet in geodetic coordinates -> viewport target is at geodetic CAD origin & twist reflects rotation.
      final sheetFiles = await ArchitectDxfExport.exportSheets(
        project,
        project.document.sheets,
        l,
        sources: sources,
        geodeticCoordinates: true,
      );
      final sheetBytes = sheetFiles.values.single;
      final viewports = _entities(sheetBytes, 'VIEWPORT').skip(1).toList();
      expect(viewports, hasLength(1));
      final targetX = double.parse(_tag(viewports.single, 17)!);
      final targetY = double.parse(_tag(viewports.single, 27)!);
      expect((targetX - 8500000).abs() < 50, isTrue);
      expect((targetY - 4720000).abs() < 50, isTrue);
      expect(double.parse(_tag(viewports.single, 51)!), closeTo(-30.0, 1e-6));
    },
  );
}
