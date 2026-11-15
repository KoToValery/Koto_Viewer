import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_landscape_models.dart';
import 'package:kotoview/src/features/architect/models/architect_overhang.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_layout.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_chain_preview.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_landscape_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_overhang_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_dimension_chain.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'architect_dimension_chain_test.dart' as dimensions;
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectDimension dimension() => ArchitectDimensionChain.build(
  id: 'dim',
  direction: const Offset(1, 0),
  offset: -2,
  anchors: const [
    ArchitectDimensionAnchor(point: Offset(0, 0)),
    ArchitectDimensionAnchor(point: Offset(5, 0)),
    ArchitectDimensionAnchor(point: Offset(10, 0)),
    ArchitectDimensionAnchor(point: Offset(3, 0), feature: 'opening'),
    ArchitectDimensionAnchor(point: Offset(4, 0), feature: 'opening'),
  ],
);
ArchitectProject project({
  ArchitectDocument document = const ArchitectDocument(),
}) => ArchitectProject(
  id: 'p',
  name: 'Scale test',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  document: document,
  storeys: [
    ArchitectStorey(
      id: 's',
      name: 'Floor',
      dimensions: [dimension()],
      walls: const [
        ArchitectWall(
          id: 'wall',
          startPoint: Offset(0, 0),
          endPoint: Offset(10, 0),
          windows: [
            ArchitectWindow(
              id: 'window',
              wallId: 'wall',
              offsetRatio: .35,
              width: 1,
              uuid: 'window',
            ),
          ],
          doors: [
            ArchitectDoor(
              id: 'door',
              wallId: 'wall',
              offsetRatio: .7,
              width: 1,
              uuid: 'door',
            ),
          ],
        ),
      ],
      columns: const [
        ArchitectColumn(
          id: 'col',
          position: Offset(9, 4),
          label: 'C1234',
          width: .3,
          depth: .3,
        ),
      ],
      zones: const [
        ArchitectZone(
          id: 'zone',
          number: '1',
          name: 'Living',
          category: ArchitectZoneCategory.living,
          polygon: [Offset(1, 1), Offset(8, 1), Offset(8, 5), Offset(1, 5)],
        ),
      ],
      zoneScheduleOrigin: const Offset(12, 0),
      slabs: const [
        ArchitectSlab(
          id: 'slab',
          label: 'Slab',
          polygon: [Offset(20, 0), Offset(25, 0), Offset(25, 5), Offset(20, 5)],
        ),
      ],
    ),
  ],
  gridAxes: const [
    StructuralGridAxis(
      id: 'axis',
      name: 'A',
      start: Offset(-1, -2),
      end: Offset(-1, 8),
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
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
    final font = FontLoader('ArchitectNoto')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await font.load();
  });

  test('Render scale examples for visual review', () async {
    if (Platform.environment['UPDATE_ARCHITECT_SCALE_PREVIEW'] != 'true') {
      return;
    }
    for (final denominator in [50, 100, 500]) {
      ArchitectProject p;
      if (denominator == 500) {
        // A situation drawing uses a site-sized subject with terrain contours
        // and spot elevations under ArchitectAnnotationRole.site.
        p = ArchitectProject(
          id: 'p500',
          name: 'Site preview',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          activeStoreyId: 's',
          document: const ArchitectDocument(viewScales: {'plan:s': 500}),
          existingTerrain: const ArchitectTerrainSurface(
            id: 'ter-ex',
            state: ArchitectTerrainState.existing,
            datumElevation: 100.0,
            contours: [
              ArchitectTerrainContour(
                id: 'c1',
                elevation: 1.0,
                isMajor: true,
                points: [Offset(2, 10), Offset(40, 14), Offset(96, 8)],
              ),
              ArchitectTerrainContour(
                id: 'c2',
                elevation: 2.0,
                isMajor: true,
                points: [Offset(4, 48), Offset(48, 52), Offset(95, 44)],
              ),
            ],
            spots: [
              ArchitectTerrainSpot(
                id: 'sp1',
                position: Offset(15, 30),
                elevation: 1.5,
              ),
              ArchitectTerrainSpot(
                id: 'sp2',
                position: Offset(78, 28),
                elevation: 1.8,
              ),
            ],
          ),
          proposedTerrain: const ArchitectTerrainSurface(
            id: 'ter-pr',
            state: ArchitectTerrainState.proposed,
            datumElevation: 100.0,
            boundaries: [
              ArchitectTerrainBoundary(
                id: 'pad1',
                isFlatPad: true,
                elevation: 1.6,
                polygon: [
                  Offset(24, 18),
                  Offset(58, 18),
                  Offset(58, 36),
                  Offset(24, 36),
                ],
              ),
            ],
          ),
          storeys: [
            ArchitectStorey(
              id: 's',
              name: 'Site',
              walls: const [
                ArchitectWall(
                  id: 'w1',
                  startPoint: Offset(28, 20),
                  endPoint: Offset(53, 20),
                ),
                ArchitectWall(
                  id: 'w2',
                  startPoint: Offset(53, 20),
                  endPoint: Offset(53, 32),
                ),
                ArchitectWall(
                  id: 'w3',
                  startPoint: Offset(53, 32),
                  endPoint: Offset(28, 32),
                ),
                ArchitectWall(
                  id: 'w4',
                  startPoint: Offset(28, 32),
                  endPoint: Offset(28, 20),
                ),
              ],
              zones: const [
                ArchitectZone(
                  id: 'site',
                  name: 'УПИ XII-45',
                  number: '1',
                  category: ArchitectZoneCategory.living,
                  polygon: [
                    Offset(0, 0),
                    Offset(100, 0),
                    Offset(100, 60),
                    Offset(0, 60),
                  ],
                ),
              ],
              dimensions: [
                ArchitectDimensionChain.build(
                  id: 'site-dim',
                  direction: const Offset(1, 0),
                  offset: -7,
                  anchors: const [
                    ArchitectDimensionAnchor(point: Offset(0, 0)),
                    ArchitectDimensionAnchor(point: Offset(28, 0)),
                    ArchitectDimensionAnchor(point: Offset(53, 0)),
                    ArchitectDimensionAnchor(point: Offset(100, 0)),
                  ],
                ),
              ],
            ),
          ],
          gridAxes: const [
            StructuralGridAxis(
              id: 'axA',
              name: 'A',
              start: Offset(28, 12),
              end: Offset(28, 40),
            ),
            StructuralGridAxis(
              id: 'ax1',
              name: '1',
              start: Offset(20, 20),
              end: Offset(62, 20),
            ),
          ],
        );
      } else {
        p = ArchitectProject(
          id: 'p$denominator',
          name: 'Plan preview',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          activeStoreyId: 's',
          document: ArchitectDocument(viewScales: {'plan:s': denominator}),
          sections: const [
            ArchitectSection(
              id: 'secA',
              name: 'A',
              start: Offset(-1.2, 2.5),
              end: Offset(9.2, 2.5),
            ),
          ],
          gridAxes: const [
            StructuralGridAxis(
              id: 'axA',
              name: 'A',
              start: Offset(0, -1.2),
              end: Offset(0, 6.2),
            ),
            StructuralGridAxis(
              id: 'axB',
              name: 'B',
              start: Offset(8, -1.2),
              end: Offset(8, 6.2),
            ),
            StructuralGridAxis(
              id: 'ax1',
              name: '1',
              start: Offset(-1.8, 0),
              end: Offset(9.4, 0),
            ),
            StructuralGridAxis(
              id: 'ax2',
              name: '2',
              start: Offset(-1.8, 5),
              end: Offset(9.4, 5),
            ),
          ],
          storeys: [
            ArchitectStorey(
              id: 's',
              name: 'Floor 1',
              dimensions: [ArchitectDimensionChain.build(
                id: 'dim',
                direction: const Offset(1, 0),
                offset: -3.2,
                anchors: const [
                ArchitectDimensionAnchor(point: Offset(0, 0)),
                ArchitectDimensionAnchor(point: Offset(8, 0)),
                ArchitectDimensionAnchor(point: Offset(2.3, 0), feature: 'opening'),
                ArchitectDimensionAnchor(point: Offset(3.5, 0), feature: 'opening'),
              ])],
              walls: const [
                ArchitectWall(
                  id: 'w_bot',
                  startPoint: Offset(0, 0),
                  endPoint: Offset(8, 0),
                  windows: [
                    ArchitectWindow(
                      id: 'win1',
                      wallId: 'w_bot',
                      offsetRatio: .36,
                      width: 1.2,
                      specId: 'П1',
                      uuid: 'win1',
                    ),
                  ],
                  doors: [
                    ArchitectDoor(
                      id: 'door1',
                      wallId: 'w_bot',
                      offsetRatio: .72,
                      width: .9,
                      specId: 'В1',
                      uuid: 'door1',
                    ),
                  ],
                ),
                ArchitectWall(
                  id: 'w_right',
                  startPoint: Offset(8, 0),
                  endPoint: Offset(8, 5),
                ),
                ArchitectWall(
                  id: 'w_top',
                  startPoint: Offset(8, 5),
                  endPoint: Offset(0, 5),
                ),
                ArchitectWall(
                  id: 'w_left',
                  startPoint: Offset(0, 5),
                  endPoint: Offset(0, 0),
                ),
              ],
              columns: const [
                ArchitectColumn(
                  id: 'col1',
                  position: Offset(8, 0),
                  label: 'К1',
                  width: .3,
                  depth: .3,
                ),
              ],
              zones: const [
                ArchitectZone(
                  id: 'z1',
                  number: '1',
                  name: 'Дневна',
                  category: ArchitectZoneCategory.living,
                  floorFinish: 'Паркет',
                  wallFinish: 'Латекс',
                  ceilingFinish: 'Гипскартон',
                  polygon: [
                    Offset(0, 0),
                    Offset(8, 0),
                    Offset(8, 5),
                    Offset(0, 5),
                  ],
                ),
              ],
              zoneScheduleOrigin: const Offset(10.5, 0),
              slabs: const [
                ArchitectSlab(
                  id: 'slab1',
                  label: 'Плоча к.+0.00',
                  polygon: [
                    Offset(10.5, 3.6),
                    Offset(14.0, 3.6),
                    Offset(14.0, 5.2),
                    Offset(10.5, 5.2),
                  ],
                ),
              ],
              elevationMarkers: const [
                ArchitectElevationMarker(
                  id: 'elv1',
                  position: Offset(6.2, 4.1),
                  elevation: 0.0,
                ),
              ],
            ),
            const ArchitectStorey(
              id: 's2',
              name: 'Floor 2',
              elevation: 3.0,
              slabs: [
                ArchitectSlab(
                  id: 'balcony2',
                  label: 'Балкон',
                  polygon: [
                    Offset(1.0, 5.0),
                    Offset(5.5, 5.0),
                    Offset(5.5, 6.4),
                    Offset(1.0, 6.4),
                  ],
                ),
              ],
            ),
          ],
        );
      }
      final scene = ArchitectDrawingPublisher.build(p, drawing, denominator, l);
      final bounds = scene.bounds.inflate(3);
      final scale = math.min(1120 / bounds.width, 650 / bounds.height);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      final title = TextPainter(
        text: TextSpan(
          text: '1:$denominator',
          style: const TextStyle(
            fontFamily: 'ArchitectNoto',
            fontSize: 28,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      title.paint(canvas, const Offset(24, 12));
      canvas.translate(40 - bounds.left * scale, 60 - bounds.top * scale);
      canvas.scale(scale);
      scene.paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1200, 740);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'scratch/architect_annotation_scale_$denominator.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });

  test(
    'Roof and stair symbols retain their publication layout at distant zoom',
    () {
      final source = project();
      final p = source.updateActiveStorey(
        source.activeStorey.copyWith(
          walls: [],
          zones: [],
          columns: [],
          dimensions: [],
          slabs: [],
          clearZoneScheduleOrigin: true,
          roofs: [
            ArchitectRoofPlane(
              id: 'roof',
              storeyId: 's',
              points: const [
                Offset(20, 0),
                Offset(25, 0),
                Offset(25, 5),
                Offset(20, 5),
              ],
            ),
          ],
          stairs: const [
            ArchitectStair(
              id: 'stair',
              startPoint: Offset(0, 0),
              endPoint: Offset(1, 0),
              design: ArchitectStairDesign(showRailing: false),
            ),
          ],
        ),
      );
      for (final denominator in [50, 100, 500]) {
        final published = ArchitectDrawingPublisher.build(
          p,
          drawing,
          denominator,
          l,
        ).operations.whereType<ArchitectVectorText>().toList();
        expect(published.any((t) => t.sources.contains('roof')), isTrue);
        expect(published.any((t) => t.sources.contains('stair')), isTrue);
        for (final publication in [false, true]) {
          for (final zoom in [5.0, 80.0, 320.0]) {
            final canvas = ArchitectVectorCanvas()..scale(zoom);
            ArchitectTextScope(
              p.document,
              'plan:s',
              denominator,
              zoom,
              publication: publication,
            ).run(() {
              Architect2dPainter(
                project: p,
                activeTool: ArchitectTool.select,
                zoomScale: zoom,
                l10n: l,
                layer: ArchitectPaintLayer.model,
                paintGrid: false,
              ).paint(canvas, const Size(2000, 2000));
            });
            final texts = canvas.operations
                .whereType<ArchitectVectorText>()
                .toList();
            expect(texts.length, published.length);
            for (var i = 0; i < texts.length; i++) {
              expect(texts[i].text, published[i].text);
              final pubModelHeight = published[i].size * denominator / 1000;
              if (publication || zoom <= 5.5 * 1000 / denominator - 1e-6) {
                expect(texts[i].size / zoom, closeTo(pubModelHeight, 1e-7));
                expect(
                  (texts[i].position / zoom -
                          published[i].position * (denominator / 1000))
                      .distance,
                  lessThan(ArchitectDrawingScale(denominator).paperToModel(.1)),
                  reason: texts[i].text,
                );
              } else {
                // Working viewport caps oversized lettering when zoomed in.
                expect(texts[i].size / zoom, lessThanOrEqualTo(pubModelHeight + 1e-7));
              }
            }
          }
        }
      }
    },
  );

  test(
    'Default exterior row gaps follow drawing scale, independently of zoom',
    () {
      for (final (scale, gap) in [
        (ArchitectDimensionScale.scale50, .3),
        (ArchitectDimensionScale.scale100, .4),
        (ArchitectDimensionScale.scale500, 3.0),
      ]) {
        for (final zoom in [10.0, 80.0, 320.0]) {
          final tiers = ArchitectDimensionLayout.layoutTiers(
            dimension: dimension(),
            scale: zoom,
            dimensionScale: scale,
          );
          expect(tiers, hasLength(3));
          for (var i = 1; i < tiers.length; i++) {
            expect(
              (tiers[i].line.$1.dy - tiers[i - 1].line.$1.dy).abs(),
              closeTo(gap, 1e-9),
            );
          }
        }
      }
    },
  );

  test(
    'Profiles, per-element overrides and saved view scales control the actual row gap',
    () {
      const document = ArchitectDocument(
        viewScales: {'plan:s': 50},
        profileMm: {'100/dimension': 3.3},
        overrideMm: {
          'plan:s/dim/dimension/100': 4.4,
          'plan:s/dim/dimension/50': 4.6,
        },
      );
      expect(
        ArchitectDimensionLayout.rowSpacingFor(
          dimension(),
          document: document,
          viewKey: 'plan:s',
          dimensionScale: ArchitectDimensionScale.scale100,
        ),
        closeTo(.6, 1e-9),
      );
      final noViewScale = document.copyWith(viewScales: {});
      expect(
        ArchitectDimensionLayout.rowSpacingFor(
          dimension(),
          document: noViewScale,
          viewKey: 'plan:s',
        ),
        closeTo(1.1, 1e-9),
      );
      expect(
        ArchitectDimensionLayout.rowSpacingFor(
          dimension().copyWith(id: 'other'),
          document: noViewScale,
          viewKey: 'plan:s',
        ),
        closeTo(.825, 1e-9),
      );
      // A sheet placement can use another scale from the saved working view.
      ArchitectTextScope(document, 'plan:s', 100, 30, publication: true).run(
        () {
          expect(
            ArchitectDimensionLayout.rowSpacingFor(dimension()),
            closeTo(1.1, 1e-9),
          );
        },
      );
    },
  );

  test(
    'Optimal scale defaults keep plan text compact while axes and sections stand out',
    () {
      const document = ArchitectDocument();
      // 1:50 working plan: crisp dimensions & openings, compact room stamps.
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.dimension, 50),
        2.3,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.opening, 50),
        2.0,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.roomName, 50),
        1.6,
      );
      // 1:100 floor plan defaults preserved.
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.dimension, 100),
        1.6,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.opening, 100),
        1.5,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.roomName, 100),
        1.5,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.axis, 100),
        3.0,
      );
      // 1:500 situation & defaults across 1:5..1:1000.
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.dimension, 500),
        2.4,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.ordinary, 500),
        2.2,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.roomName, 500),
        2.2,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.title, 500),
        3.6,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.axis, 500),
        3.5,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.section, 500),
        3.5,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.site, 500),
        2.3,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.opening, 500),
        1.8,
      );
      expect(
        document.textMm('plan:s', '', ArchitectAnnotationRole.table, 500),
        2.1,
      );
      expect(ArchitectDrawingScale.presets, containsAll([5, 20, 50, 100, 200, 500, 1000]));
      for (final denom in ArchitectDrawingScale.presets) {
        expect(
          document.textMm('plan:s', '', ArchitectAnnotationRole.axis, denom),
          greaterThan(
            document.textMm('plan:s', '', ArchitectAnnotationRole.roomName, denom),
          ),
        );
        expect(
          document.textMm('plan:s', '', ArchitectAnnotationRole.section, denom),
          greaterThan(
            document.textMm('plan:s', '', ArchitectAnnotationRole.opening, denom),
          ),
        );
      }
      expect(
        ArchitectDimensionScale.scale500.textHeightMm,
        const ArchitectDrawingScale(500).defaultTextMm,
      );
    },
  );

  test('Slab omits area label, overhang omits text, terrain uses site role', () {
    final p = project();
    final scene = ArchitectDrawingPublisher.build(p, drawing, 50, l);
    final texts = scene.operations.whereType<ArchitectVectorText>().toList();
    expect(texts.any((t) => t.sources.contains('slab') && t.text == 'Slab'), isTrue);
    expect(
      texts.any((t) => t.sources.contains('slab') && t.text.contains('m²')),
      isFalse,
    );

    final overhangCanvas = ArchitectVectorCanvas();
    ArchitectOverhangPainterHelper.drawOverhangs(
      canvas: overhangCanvas,
      palette: const ArchitectCanvasPalette.light(),
      overhangs: const [
        ArchitectOverhang(
          id: 'ov1',
          kind: ArchitectOverhangKind.balcony,
          polygon: [Offset(0, 0), Offset(3, 0), Offset(3, 1.2), Offset(0, 1.2)],
          sourceStoreyId: 's2',
          sourceStoreyName: 'Floor 2',
          sourceStoreyElevation: 3.0,
        ),
      ],
      zoomScale: 20,
      l10n: l,
    );
    expect(overhangCanvas.operations.whereType<ArchitectVectorPath>(), isNotEmpty);
    expect(overhangCanvas.operations.whereType<ArchitectVectorText>(), isEmpty);

    final siteProject = p.copyWith(
      existingTerrain: const ArchitectTerrainSurface(
        id: 't1',
        state: ArchitectTerrainState.existing,
        spots: [
          ArchitectTerrainSpot(id: 'sp', position: Offset(2, 2), elevation: 1.5),
        ],
      ),
    );
    final siteCanvas = ArchitectVectorCanvas()..scale(5);
    ArchitectTextScope(siteProject.document, 'plan:s', 500, 5, publication: true)
        .run(() {
      ArchitectLandscapePainterHelper.drawTerrain(
        canvas: siteCanvas,
        project: siteProject,
        zoomScale: 5,
        selectedIds: const {},
      );
    });
    final siteTexts = siteCanvas.operations.whereType<ArchitectVectorText>().toList();
    expect(siteTexts, isNotEmpty);
    expect(siteTexts.every((t) => t.role == 'site'), isTrue);
    expect(
      siteTexts.first.size / 5 * 2 * ArchitectDrawingScale.fontCapRatio,
      closeTo(2.3, 1e-7),
    );
  });

  for (final denominator in [50, 100, 500]) {
    test(
      '1:$denominator working text, zones, symbols and dimensions match publication at readable zoom',
      () {
        final p = project(
          document: ArchitectDocument(viewScales: {'plan:s': denominator}),
        );
        final published = ArchitectDrawingPublisher.build(
          p,
          drawing,
          denominator,
          l,
        ).operations.whereType<ArchitectVectorText>().toList();
        expect(published, isNotEmpty);
        final uncappedZoom = denominator >= 500
            ? 5.0
            : denominator >= 100
                ? 20.0
                : 80.0;
        for (final zoom in [5.0, uncappedZoom, 320.0]) {
          final canvas = ArchitectVectorCanvas()..scale(zoom);
          Architect2dPainter(
            activeTool: ArchitectTool.select,
            project: p,
            zoomScale: zoom,
            l10n: l,
            layer: ArchitectPaintLayer.model,
            paintGrid: false,
          ).paint(canvas, const Size(2000, 2000));
          final texts = canvas.operations
              .whereType<ArchitectVectorText>()
              .toList();
          expect(texts.length, published.length);
          for (var i = 0; i < texts.length; i++) {
            final actual = texts[i], expected = published[i];
            expect(actual.text, expected.text);
            expect(actual.role, expected.role);
            expect(actual.sources, expected.sources);
            final pubModelSize = expected.size * denominator / 1000;
            if (zoom <= uncappedZoom) {
              expect(actual.size / zoom, closeTo(pubModelSize, 1e-7));
              expect(
                (actual.position / zoom -
                        expected.position * (denominator / 1000))
                    .distance,
                lessThan(.001),
                reason: '${actual.role}: ${actual.text}',
              );
            } else {
              // At deep zoom, dynamic working-view cap keeps labels from covering walls/rooms.
              expect(actual.size / zoom, lessThanOrEqualTo(pubModelSize + 1e-7));
            }
          }
        }
      },
    );
  }

  test(
    'Large dimension overrides move the text and separate the painted rows',
    () {
      const doc = ArchitectDocument(
        overrideMm: {'plan:s/dim/dimension/100': 4.4},
      );
      final canvas = ArchitectVectorCanvas();
      ArchitectTextScope(doc, 'plan:s', 100, 20).run(() {
        ArchitectElementsPainterHelper.drawDimensions(
          canvas: canvas,
          storey: project().activeStorey,
          zoomScale: 20,
        );
      });
      final text = canvas.operations.whereType<ArchitectVectorText>().toList();
      expect(text, isNotEmpty);
      expect(
        text.every(
          (t) =>
              (t.size * ArchitectDrawingScale.fontCapRatio - .44).abs() < 1e-8,
        ),
        isTrue,
      );
      final rows = ArchitectDimensionLayout.layoutTiers(
        dimension: dimension(),
        scale: 20,
        document: doc,
        viewKey: 'plan:s',
      );
      final lines = canvas.operations
          .whereType<ArchitectVectorPath>()
          .where(
            (p) =>
                p.sources.contains('dim') &&
                (p.bounds.width - 10.0125).abs() < 1e-5,
          )
          .toList();
      expect(lines.length, greaterThanOrEqualTo(3));
      expect(
        (rows[1].line.$1.dy - rows[0].line.$1.dy).abs(),
        closeTo(1.1, 1e-9),
      );
    },
  );

  test(
    'Picking and preview use the same saved profile as the model and print',
    () {
      const document = ArchitectDocument(
        viewScales: {'plan:s': 50},
        overrideMm: {'plan:s/dim/dimension/50': 3},
      );
      final p = project(document: document);
      final tool = ArchitectElementTool();
      addTearDown(tool.dispose);
      final rows = ArchitectDimensionLayout.layoutTiers(
        dimension: dimension(),
        scale: 200,
        document: document,
        viewKey: 'plan:s',
      );
      final target = (rows.last.line.$1 + rows.last.line.$2) / 2;
      expect(
        tool.hitTestForTool(
          p.activeStorey,
          target,
          200,
          ArchitectTool.dimension,
          annotationProject: p,
          drawingViewKey: 'plan:s',
        ),
        'dim',
      );
      final viewport = BimViewportController();
      addTearDown(viewport.dispose);
      final canvas = ArchitectVectorCanvas();
      ArchitectDimensionChainPreview(
        dimension: dimension(),
        viewport: viewport,
        units: p.units,
        palette: const ArchitectCanvasPalette.light(),
        storey: p.activeStorey,
        document: document,
        viewKey: 'plan:s',
      ).paint(canvas, const Size(1000, 1000));
      final labels = canvas.operations
          .whereType<ArchitectVectorText>()
          .toList();
      expect(labels, isNotEmpty);
      expect(
        labels.first.size / viewport.scale * ArchitectDrawingScale.fontCapRatio,
        closeTo(.15, 1e-8),
      );
    },
  );

  testWidgets(
    'Editing a placed dimension retains its individual text profile in the draft',
    (tester) async {
      const document = ArchitectDocument(
        overrideMm: {'plan:s/dim/dimension/100': 4.4},
      );
      final model = editing.seeded(project().activeStorey);
      addTearDown(model.dispose);
      model.replaceView(model.project.copyWith(document: document));
      await workspace.open(tester, model);
      await tool_ui.choose(tester, Icons.near_me_outlined);
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(5, -2));
      await tester.tap(
        find.byKey(const ValueKey('architect-dimension-add-walls')),
      );
      await tester.pump();
      expect(dimensions.preview(tester)!.id, 'dim');
      final preview =
          tester
                  .widget<CustomPaint>(
                    find.byKey(
                      const ValueKey('architect-dimension-chain-preview'),
                    ),
                  )
                  .painter!
              as ArchitectDimensionChainPreview;
      expect(preview.document, same(document));
      expect(preview.viewKey, 'plan:s');
      expect(
        ArchitectDimensionLayout.rowSpacingFor(
          preview.dimension!,
          document: preview.document,
          viewKey: preview.viewKey,
        ),
        closeTo(1.1, 1e-9),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
