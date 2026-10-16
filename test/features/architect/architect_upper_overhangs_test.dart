import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_overhang.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_overhang_painter_helper.dart';
import 'package:kotoview/src/features/architect/services/architect_overhang_detector.dart';

void main() {
  group('ArchitectOverhang Model Tests', () {
    test('ArchitectOverhang properties, centroid, and serialization', () {
      final poly = [
        const Offset(0, 0),
        const Offset(4, 0),
        const Offset(4, 1.2),
        const Offset(0, 1.2),
      ];

      final overhang = ArchitectOverhang(
        id: 'erker_1',
        kind: ArchitectOverhangKind.erker,
        polygon: poly,
        area: 4.8,
        overhangDepth: 1.2,
        sourceStoreyId: 'fl2',
        sourceStoreyName: '+2.80',
        sourceStoreyElevation: 2.80,
      );

      expect(overhang.id, 'erker_1');
      expect(overhang.kind, ArchitectOverhangKind.erker);
      expect(overhang.area, 4.8);
      expect(overhang.overhangDepth, 1.2);
      expect(overhang.sourceStoreyElevation, 2.80);
      expect(overhang.centroid, const Offset(2.0, 0.6));

      // JSON roundtrip
      final json = overhang.toJson();
      final fromJson = ArchitectOverhang.fromJson(json);

      expect(fromJson.id, overhang.id);
      expect(fromJson.kind, overhang.kind);
      expect(fromJson.area, overhang.area);
      expect(fromJson.overhangDepth, overhang.overhangDepth);
      expect(fromJson.polygon.length, overhang.polygon.length);
      expect(fromJson.sourceStoreyElevation, overhang.sourceStoreyElevation);
    });

    test('ArchitectOverhang copyWith preserves and overrides values', () {
      const overhang = ArchitectOverhang(
        id: 'b1',
        kind: ArchitectOverhangKind.balcony,
        polygon: [Offset.zero, Offset(2, 0), Offset(2, 2)],
        sourceStoreyId: 's2',
        sourceStoreyName: 'Storey 2',
        sourceStoreyElevation: 3.0,
      );

      final copy = overhang.copyWith(
        kind: ArchitectOverhangKind.erker,
        overhangDepth: 1.5,
      );

      expect(copy.id, 'b1');
      expect(copy.kind, ArchitectOverhangKind.erker);
      expect(copy.overhangDepth, 1.5);
      expect(copy.sourceStoreyElevation, 3.0);
    });
  });

  group('ArchitectOverhangDetector Tests', () {
    test('Single storey project returns no upper storey and no overhangs', () {
      final project = ArchitectProject(
        id: 'proj1',
        name: 'Single Storey',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeStoreyId: 'ground',
        storeys: const [
          ArchitectStorey(
            id: 'ground',
            name: '±0.00',
            elevation: 0.0,
          ),
        ],
      );

      final upper = ArchitectOverhangDetector.findUpperStorey(project);
      expect(upper, isNull);

      final detected = ArchitectOverhangDetector.detectOverhangs(project);
      expect(detected, isEmpty);
    });

    test('Detects upper floor erker projecting 1.20m beyond lower floor facade', () {
      // Lower storey: 10m x 8m house [0, 10] x [0, 8]
      const lowerStorey = ArchitectStorey(
        id: 'fl1',
        name: '±0.00',
        elevation: 0.0,
        walls: [
          ArchitectWall(id: 'w1', startPoint: Offset(0, 0), endPoint: Offset(10, 0)),
          ArchitectWall(id: 'w2', startPoint: Offset(10, 0), endPoint: Offset(10, 8)),
          ArchitectWall(id: 'w3', startPoint: Offset(10, 8), endPoint: Offset(0, 8)),
          ArchitectWall(id: 'w4', startPoint: Offset(0, 8), endPoint: Offset(0, 0)),
        ],
        zones: [
          ArchitectZone(
            id: 'z_lower',
            name: 'Living',
            category: ArchitectZoneCategory.living,
            polygon: [Offset(0, 0), Offset(10, 0), Offset(10, 8), Offset(0, 8)],
          ),
        ],
      );

      // Upper storey: living room has an erker extending from y=0 to y=-1.20m (4m wide, between x=3 and x=7)
      const upperStorey = ArchitectStorey(
        id: 'fl2',
        name: '+2.80',
        elevation: 2.80,
        zones: [
          ArchitectZone(
            id: 'z_upper_erker',
            name: 'Bedroom with Erker',
            category: ArchitectZoneCategory.bedroom,
            polygon: [
              Offset(3, 4),
              Offset(7, 4),
              Offset(7, -1.20),
              Offset(3, -1.20),
            ],
          ),
        ],
      );

      final project = ArchitectProject(
        id: 'p2',
        name: 'Erker House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeStoreyId: 'fl1',
        storeys: const [lowerStorey, upperStorey],
      );

      final upper = ArchitectOverhangDetector.findUpperStorey(project);
      expect(upper, isNotNull);
      expect(upper!.id, 'fl2');

      final overhangs = ArchitectOverhangDetector.detectOverhangs(project);
      expect(overhangs, isNotEmpty);

      final erker = overhangs.firstWhere((o) => o.kind == ArchitectOverhangKind.erker);
      expect(erker.kind, ArchitectOverhangKind.erker);
      expect(erker.sourceStoreyElevation, 2.80);
      expect(erker.overhangDepth, closeTo(1.20, 0.15));
      expect(erker.area, closeTo(4.3, 0.5)); // ~4m x 1.075m beyond lower wall body
    });

    test('Detects upper floor terrace as balcony with correct geometry', () {
      const lowerStorey = ArchitectStorey(
        id: 'fl1',
        name: '±0.00',
        elevation: 0.0,
        slabs: [
          ArchitectSlab(
            id: 'slab1',
            polygon: [Offset(0, 0), Offset(8, 0), Offset(8, 8), Offset(0, 8)],
          ),
        ],
      );

      // Upper floor has a terrace/balcony projecting 1.50m from x=8 to x=9.50m
      const upperStorey = ArchitectStorey(
        id: 'fl2',
        name: '+2.80',
        elevation: 2.80,
        zones: [
          ArchitectZone(
            id: 'terrace1',
            name: 'Terrace',
            category: ArchitectZoneCategory.terrace,
            polygon: [
              Offset(8, 2),
              Offset(9.5, 2),
              Offset(9.5, 6),
              Offset(8, 6),
            ],
          ),
        ],
      );

      final project = ArchitectProject(
        id: 'p3',
        name: 'Balcony House',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeStoreyId: 'fl1',
        storeys: const [lowerStorey, upperStorey],
      );

      final overhangs = ArchitectOverhangDetector.detectOverhangs(project);
      expect(overhangs, isNotEmpty);

      final balcony = overhangs.firstWhere((o) => o.kind == ArchitectOverhangKind.balcony);
      expect(balcony.kind, ArchitectOverhangKind.balcony);
      expect(balcony.area, closeTo(6.0, 0.01)); // 1.5m x 4m = 6m²
    });

    test('Detects cantilevered upper slab as erker or balcony', () {
      const lowerStorey = ArchitectStorey(
        id: 'fl1',
        name: '±0.00',
        elevation: 0.0,
        slabs: [
          ArchitectSlab(
            id: 'slab_low',
            polygon: [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)],
          ),
        ],
      );

      // Upper floor has slab extending 1.0m to x=11
      const upperStorey = ArchitectStorey(
        id: 'fl2',
        name: '+3.00',
        elevation: 3.00,
        slabs: [
          ArchitectSlab(
            id: 'slab_up',
            label: 'Cantilever Slab',
            polygon: [Offset(0, 0), Offset(11, 0), Offset(11, 10), Offset(0, 10)],
          ),
        ],
      );

      final project = ArchitectProject(
        id: 'p4',
        name: 'Slab Overhang',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeStoreyId: 'fl1',
        storeys: const [lowerStorey, upperStorey],
      );

      final overhangs = ArchitectOverhangDetector.detectOverhangs(project);
      expect(overhangs, isNotEmpty);
      expect(overhangs.any((o) => o.overhangDepth >= 0.8), isTrue);
    });

    test('Upper parapet walls form balcony enclosure when no zones present', () {
      const lowerStorey = ArchitectStorey(
        id: 'fl1',
        name: '±0.00',
        elevation: 0.0,
        walls: [
          ArchitectWall(id: 'w1', startPoint: Offset(0, 0), endPoint: Offset(10, 0)),
          ArchitectWall(id: 'w2', startPoint: Offset(10, 0), endPoint: Offset(10, 8)),
          ArchitectWall(id: 'w3', startPoint: Offset(10, 8), endPoint: Offset(0, 8)),
          ArchitectWall(id: 'w4', startPoint: Offset(0, 8), endPoint: Offset(0, 0)),
        ],
      );

      // Upper floor has parapet walls defining a balcony
      const upperStorey = ArchitectStorey(
        id: 'fl2',
        name: '+2.80',
        elevation: 2.80,
        walls: [
          ArchitectWall(
            id: 'pw1',
            startPoint: Offset(10, 2),
            endPoint: Offset(11.5, 2),
            height: 1.05,
            wallTypeId: 'parapet_12',
          ),
          ArchitectWall(
            id: 'pw2',
            startPoint: Offset(11.5, 2),
            endPoint: Offset(11.5, 6),
            height: 1.05,
            wallTypeId: 'parapet_12',
          ),
          ArchitectWall(
            id: 'pw3',
            startPoint: Offset(11.5, 6),
            endPoint: Offset(10, 6),
            height: 1.05,
            wallTypeId: 'parapet_12',
          ),
          ArchitectWall(
            id: 'pw4',
            startPoint: Offset(10, 6),
            endPoint: Offset(10, 2),
            height: 1.05,
            wallTypeId: 'parapet_12',
          ),
        ],
      );

      final project = ArchitectProject(
        id: 'p5',
        name: 'Parapet Balcony',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeStoreyId: 'fl1',
        storeys: const [lowerStorey, upperStorey],
        wallTypes: const [
          ArchitectWallType(
            id: 'parapet_12',
            name: 'Parapet 12',
            usage: WallUsage.parapet,
            totalThickness: 0.12,
            customHeight: 1.05,
          ),
        ],
      );

      final overhangs = ArchitectOverhangDetector.detectOverhangs(project);
      expect(overhangs, isNotEmpty);
      expect(overhangs.any((o) => o.kind == ArchitectOverhangKind.balcony), isTrue);
    });
  });

  group('ArchitectOverhangPainterHelper & Painter Rendering', () {
    test('ArchitectOverhangPainterHelper draws thin dashed paths without exception', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final overhangs = [
        ArchitectOverhang(
          id: 'e1',
          kind: ArchitectOverhangKind.erker,
          polygon: const [
            Offset(0, 0),
            Offset(4, 0),
            Offset(4, 1.2),
            Offset(0, 1.2),
          ],
          area: 4.8,
          overhangDepth: 1.2,
          sourceStoreyId: 's2',
          sourceStoreyName: '+2.80',
          sourceStoreyElevation: 2.80,
        ),
        ArchitectOverhang(
          id: 'b1',
          kind: ArchitectOverhangKind.balcony,
          polygon: const [
            Offset(6, 0),
            Offset(9, 0),
            Offset(9, 1.5),
            Offset(6, 1.5),
          ],
          area: 4.5,
          overhangDepth: 1.5,
          sourceStoreyId: 's2',
          sourceStoreyName: '+2.80',
          sourceStoreyElevation: 2.80,
        ),
      ];

      expect(
        () => ArchitectOverhangPainterHelper.drawOverhangs(
          canvas: canvas,
          palette: const ArchitectCanvasPalette.light(),
          overhangs: overhangs,
          zoomScale: 20.0,
          l10n: null,
        ),
        returnsNormally,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('Architect2dPainter integrates upper overhangs and repaints on preference change', () {
      final project = ArchitectProject(
        id: 'p_paint',
        name: 'Painter Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeStoreyId: 'fl1',
        storeys: const [
          ArchitectStorey(
            id: 'fl1',
            name: '±0.00',
            elevation: 0.0,
            slabs: [
              ArchitectSlab(
                id: 'sl1',
                polygon: [Offset(0, 0), Offset(8, 0), Offset(8, 8), Offset(0, 8)],
              ),
            ],
          ),
          ArchitectStorey(
            id: 'fl2',
            name: '+2.80',
            elevation: 2.80,
            zones: [
              ArchitectZone(
                id: 'terrace',
                name: 'Terrace',
                category: ArchitectZoneCategory.terrace,
                polygon: [Offset(8, 2), Offset(10, 2), Offset(10, 6), Offset(8, 6)],
              ),
            ],
          ),
        ],
      );

      final painter1 = Architect2dPainter(
        project: project,
        activeTool: ArchitectTool.select,
        showUpperOverhangs: true,
      );

      final painter2 = Architect2dPainter(
        project: project,
        activeTool: ArchitectTool.select,
        showUpperOverhangs: false,
      );

      expect(painter1.showUpperOverhangs, isTrue);
      expect(painter2.showUpperOverhangs, isFalse);
      expect(painter2.shouldRepaint(painter1), isTrue);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter1.paint(canvas, const Size(800, 600)), returnsNormally);
      recorder.endRecording();
    });
  });
}
