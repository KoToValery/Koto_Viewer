import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_structural_seed_sync.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/project_grid_axes.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/grid_axis_presentation.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/services/structural_persistence_service.dart';
import 'bim_seed_lifecycle_test.dart' as f;

DxfDocument drawing(List<double> xs) {
  final doc = f.drawing();
  final metadata = BimUnderlayMetadata.read(doc)!;
  metadata['axes'] = [
    for (var i = 0; i < xs.length; i++)
      StructuralGridAxis(
        id: 'v$i',
        name: '${i + 1}',
        start: Offset(xs[i], 0),
        end: Offset(xs[i], 10),
      ).toJson(),
    for (var i = 0; i < 2; i++)
      StructuralGridAxis(
        id: 'h$i',
        name: i == 0 ? 'A' : 'B',
        start: Offset(0, i * 6.0),
        end: Offset(10, i * 6.0),
      ).toJson(),
  ];
  doc.headerVars[BimUnderlayMetadata.key] = jsonEncode(metadata);
  return doc;
}

void unique(StructuralProject model) {
  final axes = model.effectiveGridAxes;
  expect(axes.map((a) => a.name).toSet(), hasLength(axes.length));
  expect(axes.map((a) => a.id).toSet(), hasLength(axes.length));
  for (final floor in model.storeys) {
    expect(
      floor.gridAxes.map((a) => a.toJson()).toList(),
      axes.map((a) => a.toJson()).toList(),
    );
  }
}

void main() {
  test('three floors share numbering, origins and reference colours', () {
    var manifest = f.project([0, 2.8, 5.6]);
    var model = f.model(manifest);
    (manifest, model) = BimStructuralSeedSync.refresh(manifest, model, {
      's0': drawing([0, 4, 8]),
      's1': drawing([0, 2, 4, 8, 10]),
      's2': drawing([0, 2, 4, 5, 8, 10]),
    });
    unique(model);
    expect(model.gridAxes, hasLength(8));
    final common = model.gridAxes.firstWhere(
      (a) => a.start.dx == 0 && a.end.dx == 0,
    );
    expect(common.sourceStoreyIds, ['s0', 's1', 's2']);
    final upper = model.gridAxes.firstWhere(
      (a) => a.start.dx == 2 && a.end.dx == 2,
    );
    final roof = model.gridAxes.firstWhere(
      (a) => a.start.dx == 5 && a.end.dx == 5,
    );
    final ground = model.storeys.first;
    final p = GridAxisPresentation.forStorey(upper, ground, model.storeys);
    expect(p.reference, isTrue);
    expect(p.levels, contains('+2.80'));
    expect(
      GridAxisPresentation.forStorey(
        upper,
        model.storeys[1],
        model.storeys,
      ).reference,
      isFalse,
    );
    expect(
      GridAxisPresentation.forStorey(common, ground, model.storeys).reference,
      isFalse,
    );
    expect(
      GridAxisPresentation.forStorey(roof, ground, model.storeys).color,
      isNot(p.color),
    );
    expect(
      GridAxisPresentation.forStorey(
        roof,
        model.storeys[1],
        model.storeys,
      ).color,
      GridAxisPresentation.forStorey(roof, ground, model.storeys).color,
    );
    final restored = StructuralProject.fromJson(model.toJson());
    expect(
      restored.gridAxes.firstWhere((a) => a.id == upper.id).sourceStoreyIds,
      upper.sourceStoreyIds,
    );
    final again = BimStructuralSeedSync.refresh(manifest, restored, {
      's0': drawing([0, 4, 8]),
      's1': drawing([0, 2, 4, 8, 10]),
      's2': drawing([0, 2, 4, 5, 8, 10]),
    }).$2;
    expect(again.toJson(), model.toJson());
  });
  test(
    'adding an upper-floor axis between existing axes renumbers every floor',
    () {
      final original = f.project([0, 2.8]);
      var (manifest, model) = BimStructuralSeedSync.refresh(
        original,
        f.model(original),
        {
          's0': drawing([0, 4, 8]),
          's1': drawing([0, 4, 8]),
        },
      );
      final old = model.gridAxes.firstWhere(
        (a) => a.start.dx == 4 && a.end.dx == 4,
      );
      (manifest, model) = BimStructuralSeedSync.refresh(manifest, model, {
        's0': drawing([0, 4, 8]),
        's1': drawing([0, 2, 4, 8]),
      });
      unique(model);
      final existing = model.gridAxes.firstWhere(
        (a) => a.start.dx == 4 && a.end.dx == 4,
      );
      expect(existing.id, old.id);
      expect(existing.name, '3');
      expect(
        model.gridAxes
            .firstWhere((a) => a.start.dx == 2 && a.end.dx == 2)
            .sourceStoreyIds,
        ['s1'],
      );
    },
  );
  test(
    'a revised source splits a shared alignment without losing the other floor',
    () {
      final original = f.project([0, 2.8]);
      var (manifest, model) = BimStructuralSeedSync.refresh(
        original,
        f.model(original),
        {
          's0': drawing([0, 4, 8]),
          's1': drawing([0, 4, 8]),
        },
      );
      (manifest, model) = BimStructuralSeedSync.refresh(manifest, model, {
        's0': drawing([0, 4.5, 8]),
        's1': drawing([0, 4, 8]),
      });
      unique(model);
      expect(
        model.gridAxes
            .firstWhere((a) => a.start.dx == 4 && a.end.dx == 4)
            .sourceStoreyIds,
        ['s1'],
      );
      expect(
        model.gridAxes
            .firstWhere((a) => a.start.dx == 4.5 && a.end.dx == 4.5)
            .sourceStoreyIds,
        ['s0'],
      );
      final again = BimStructuralSeedSync.refresh(manifest, model, {
        's0': drawing([0, 4.5, 8]),
        's1': drawing([0, 4, 8]),
      }).$2;
      expect(again.toJson(), model.toJson());
    },
  );
  test(
    'manual movement of a shared axis survives repeated source revisions',
    () {
      final original = f.project([0, 2.8]);
      var (manifest, model) = BimStructuralSeedSync.refresh(
        original,
        f.model(original),
        {
          's0': drawing([0, 4, 8]),
          's1': drawing([0, 4, 8]),
        },
      );
      final old = model.gridAxes.firstWhere(
        (a) => a.start.dx == 4 && a.end.dx == 4,
      );
      model = model.copyWithGridAxes([
        for (final a in model.gridAxes)
          a.id == old.id
              ? a.copyWith(
                  start: a.start + const Offset(.3, 0),
                  end: a.end + const Offset(.3, 0),
                )
              : a,
      ]);
      for (final x in [4.2, 4.4, 4.6]) {
        (manifest, model) = BimStructuralSeedSync.refresh(manifest, model, {
          's0': drawing([0, x, 8]),
          's1': drawing([0, 4, 8]),
        });
        expect(
          model.gridAxes.where((a) => a.start.dx == 4.3 && a.end.dx == 4.3),
          hasLength(1),
        );
        expect(model.gridAxes, hasLength(5));
        unique(model);
      }
    },
  );
  test(
    'nearby distinct and slightly converging axes are not merged in any CAD units',
    () {
      for (final units in [1.0, 100.0, 1000.0]) {
        for (final angle in [0.0, .43]) {
          Offset p(double x, double y) =>
              Offset(
                x * math.cos(angle) - y * math.sin(angle),
                x * math.sin(angle) + y * math.cos(angle),
              ) *
              units;
          StructuralGridAxis axis(String id, double x) => StructuralGridAxis(
            id: id,
            name: '1',
            start: p(x, 0),
            end: p(x, 20),
            sourceStoreyIds: [id],
          );
          final a = axis('s0', 0), b = axis('s1', .05);
          final same = a.copyWith(
            id: 's2',
            start: p(.00001, 25),
            end: p(.00001, -5),
            sourceStoreyIds: ['s2'],
          );
          final merged = ProjectGridAxes.merge(
            [a, b, same],
            units,
            isBulgarian: false,
          );
          expect(merged, hasLength(2));
          expect(merged.first.sourceStoreyIds, ['s0', 's2']);
          expect(
            ProjectGridAxes.sameAlignment(
              a,
              a.copyWith(start: p(.001, 0), end: p(.018, 20)),
              units,
            ),
            isFalse,
          );
        }
      }
    },
  );
  test(
    'different parallel families cannot restart the same numbering series',
    () {
      final axes = [
        for (var i = 0; i < 4; i++)
          StructuralGridAxis(
            id: '$i',
            name: '1',
            start: Offset(i * 2.0, 0),
            end: Offset(i * 2.0 + (i < 2 ? 0 : 3), 10),
          ),
        const StructuralGridAxis(
          id: 'h1',
          name: 'A',
          start: Offset(0, 0),
          end: Offset(10, 0),
        ),
        const StructuralGridAxis(
          id: 'h2',
          name: 'A',
          start: Offset(0, 2),
          end: Offset(10, 5),
        ),
      ];
      final numbered = resequenceGridAxes(axes, isBulgarian: false);
      expect(numbered.map((a) => a.name).toSet(), hasLength(6));
    },
  );
  test(
    'DXF keeps one shared numbering and separate pale reference layers',
    () async {
      final original = f.project([0, 2.8, 5.6]);
      final (_, model) = BimStructuralSeedSync.refresh(
        original,
        f.model(original),
        {
          's0': drawing([0, 4, 8]),
          's1': drawing([0, 2, 4, 8, 10]),
          's2': drawing([0, 2, 4, 5, 8, 10]),
        },
      );
      final dir = await Directory.systemTemp.createTemp('bim_grid_export_');
      try {
        final file = await StructuralPersistenceService.exportStoreyToDxfFile(
          storey: model.storeys.first,
          baseName: 'grid',
          outputDirectory: dir,
          gridAxisStoreys: model.storeys,
        );
        final text = await file.readAsString();
        expect(text, contains('S-AXIS_REF_s1'));
        expect(text, contains('S-AXIS_REF_s2'));
        expect(text, contains('420\n'));
        expect(text, contains('BIM axis dash-dot\n72\n65\n73\n4'));
        expect(text, contains('49\n0.0\n74\n0'));
        expect(text, contains('370\n9'));
        expect(text, contains('370\n15'));
        expect(text, contains('+2.80'));
        expect(text, contains('+5.60'));
        final entities = text.split('2\nENTITIES')[1].split('0\nENDSEC')[0];
        expect(
          RegExp(r'0\nLINE\n8\nS-AXIS').allMatches(entities),
          hasLength(model.gridAxes.length),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
  test('trace reference does not draw shared axes a second time', () async {
    final original = f.project([0, 2.8]);
    final (_, model) = BimStructuralSeedSync.refresh(
      original,
      f.model(original),
      {
        's0': drawing([0, 4, 8]),
        's1': drawing([0, 2, 4, 8, 10]),
      },
    );
    final current = model.storeys.first.copyWith(slabs: []),
        ghost = model.storeys.last.copyWith(slabs: []);
    Future<List<int>> pixels(StoreyLevel? trace) async {
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      Structural2dPainter(
        currentStorey: current,
        ghostStorey: trace,
        gridAxisStoreys: model.storeys,
        cadToScene: (p) => p * 30 + const Offset(80, 80),
        cadScale: 30,
        showCantileverHeatmap: false,
        showSlabSpanOverlay: false,
      ).paint(canvas, const ui.Size(500, 500));
      final picture = recorder.endRecording(),
          image = await picture.toImage(500, 500);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final result = data!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return result;
    }

    final plain = await pixels(null), traced = await pixels(ghost);
    expect(plain.any((v) => v > 0), isTrue);
    expect(traced, plain);
  });
  test(
    'automatic shared extents grow across revisions without becoming a manual edit',
    () {
      DxfDocument extended(double length) {
        final doc = drawing([0, 4, 8]),
            meta = BimUnderlayMetadata.read(drawing([0, 4, 8]))!;
        final axes = BimUnderlayMetadata.axes(doc)
            .map(
              (a) => a.start.dx == 4 && a.end.dx == 4
                  ? a.copyWith(end: Offset(4, length))
                  : a,
            )
            .toList();
        meta['axes'] = axes.map((a) => a.toJson()).toList();
        doc.headerVars[BimUnderlayMetadata.key] = jsonEncode(meta);
        return doc;
      }

      final original = f.project([0, 2.8]);
      var (manifest, model) = BimStructuralSeedSync.refresh(
        original,
        f.model(original),
        {
          's0': drawing([0, 4, 8]),
          's1': extended(10),
        },
      );
      final id = model.gridAxes
          .firstWhere((a) => a.start.dx == 4 && a.end.dx == 4)
          .id;
      for (final length in [12.0, 14.0]) {
        (manifest, model) = BimStructuralSeedSync.refresh(manifest, model, {
          's0': drawing([0, 4, 8]),
          's1': extended(length),
        });
        final shared = model.gridAxes.singleWhere((a) => a.id == id);
        expect(shared.length, length);
        expect(shared.sourceStoreyIds, ['s0', 's1']);
        unique(model);
      }
    },
  );
  test(
    'source reprocessing with new seed IDs cannot resurrect deleted alignments',
    () {
      final original = f.project([0, 2.8]);
      var (manifest, model) = BimStructuralSeedSync.refresh(
        original,
        f.model(original),
        {
          's0': drawing([0, 4, 8]),
          's1': drawing([0, 4, 8]),
        },
      );
      model = model.copyWithGridAxes([]);
      DxfDocument revision() {
        final doc = drawing([0, 4, 8]), meta = BimUnderlayMetadata.read(doc)!;
        meta['axes'] = BimUnderlayMetadata.axes(
          doc,
        ).map((a) => a.copyWith(id: '${a.id}_new').toJson()).toList();
        doc.headerVars[BimUnderlayMetadata.key] = jsonEncode(meta);
        return doc;
      }

      (manifest, model) = BimStructuralSeedSync.refresh(manifest, model, {
        's0': revision(),
        's1': revision(),
      });
      expect(model.gridAxes, isEmpty);
    },
  );
}
