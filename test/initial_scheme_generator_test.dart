import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/wall_axis_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/initial_scheme_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_contact_geometry.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_polygon_distance.dart';
import 'package:kotoview/src/features/structural_designer/widgets/initial_scheme_dialog.dart';
import 'package:kotoview/src/features/structural_designer/services/structural_persistence_service.dart';

WallPairCandidate pair(Offset a, Offset b, double scale, {double width = .25}) {
  final u = (b - a) / (b - a).distance,
      n = Offset(-u.dy, u.dx) * width / 2 * scale;
  WallSegment segment(Offset a, Offset b) => WallSegment(
    start: a,
    end: b,
    angleRad: math.atan2(u.dy, u.dx),
    offsetFromOrigin: 0,
    length: (b - a).distance,
    sourceLayer: 'walls',
  );
  return WallPairCandidate(
    segmentA: segment(a + n, b + n),
    segmentB: segment(a - n, b - n),
    perpendicularDistance: width * scale,
    overlapLength: (b - a).distance,
    centerlineStart: a,
    centerlineEnd: b,
  );
}

(StructuralProject, List<WallPairCandidate>) fixture({
  double scale = 1,
  double angle = 0,
}) {
  Offset tr(double x, double y) =>
      Offset(
        x * math.cos(angle) - y * math.sin(angle),
        x * math.sin(angle) + y * math.cos(angle),
      ) *
      scale;
  final floor = StoreyLevel(
    id: 'f',
    name: 'f',
    height: 3,
    slabs: [
      StructuralSlab(
        id: 's',
        polygon: [tr(0, 0), tr(20, 0), tr(20, 16), tr(0, 16)],
        openings: [
          [tr(7, 6), tr(9, 6), tr(9, 10), tr(7, 10)],
        ],
        openingTypes: [SlabOpeningType.staircase],
      ),
    ],
    gridAxes: [
      StructuralGridAxis(id: 'x', name: '1', start: tr(2, 0), end: tr(2, 16)),
      StructuralGridAxis(id: 'y', name: 'A', start: tr(0, 8), end: tr(20, 8)),
    ],
  );
  return (
    StructuralProject(storeys: [floor]),
    [
      for (final x in [2.0, 10.0, 18.0]) pair(tr(x, 1), tr(x, 15), scale),
      for (final y in [2.0, 8.0, 14.0]) pair(tr(1, y), tr(19, y), scale),
    ],
  );
}

void main() {
  test(
    'requires typed staircase; axes alone cannot authorize columns in rooms',
    () {
      final (p, runs) = fixture();
      final axesOnly = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: [],
        scale: 1,
      );
      expect(axesOnly.columns, isEmpty);
      expect(axesOnly.walls, isEmpty);
      final noStairs = p.copyWith(
        storeys: [
          p.activeStorey.copyWith(
            slabs: [
              p.activeStorey.slabs.single.copyWith(
                openings: [],
                openingTypes: [],
              ),
            ],
          ),
        ],
      );
      expect(
        InitialSchemeGenerator.generate(
          project: noStairs,
          wallPairs: runs,
          scale: 1,
        ).isEmpty,
        isTrue,
      );
    },
  );
  test(
    'all sections fit the slab, avoid holes, use both directions and respect spacing',
    () {
      for (final angle in [0.0, .43]) {
        final (p, runs) = fixture(angle: angle);
        final result = InitialSchemeGenerator.generate(
          project: p,
          wallPairs: runs,
          scale: 1,
        );
        expect(result.columns, isNotEmpty);
        expect(result.walls.length, greaterThanOrEqualTo(2));
        final polys = [
          ...result.columns.map((c) => c.polygonVertices),
          ...result.walls.map((w) => w.polygonVertices),
        ];
        for (final poly in polys) {
          final contact = SlabContactGeometry.measure(
            poly,
            p.activeStorey.slabs,
            1,
          )!;
          expect(
            contact.areaM2,
            closeTo(StructuralSlab.calculateArea(poly), 1e-7),
          );
          expect(
            StructuralPolygonDistance.between(
              poly,
              p.activeStorey.slabs.single.openings.single,
            ),
            greaterThan(0),
          );
        }
        final centers = [
          ...result.columns.map((c) => c.center),
          ...result.walls.map((w) => w.center),
        ];
        for (var i = 0; i < centers.length; i++) {
          for (var j = 0; j < i; j++) {
            expect(
              (centers[i] - centers[j]).distance,
              greaterThanOrEqualTo(2 - 1e-8),
            );
          }
        }
      }
    },
  );
  test('deterministic under wall order and CAD unit changes', () {
    List<String> result(double scale, bool reverse) {
      final (p, runs) = fixture(scale: scale);
      final r = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: reverse ? runs.reversed.toList() : runs,
        scale: scale,
      );
      return [...r.columns.map((c) => c.id), ...r.walls.map((w) => w.id)];
    }

    expect(result(1, false), result(1, true));
    expect(result(1, false), result(100, false));
    expect(result(1, false), result(1000, false));
  });
  test('repeat is additive and cannot overwrite manual or accepted edits', () {
    final (p, runs) = fixture();
    final first = InitialSchemeGenerator.generate(
      project: p,
      wallPairs: runs,
      scale: 1,
    );
    final applied = first.apply(p.activeStorey);
    final next = InitialSchemeGenerator.generate(
      project: p.copyWith(storeys: [applied]),
      wallPairs: runs,
      scale: 1,
    );
    expect(next.isEmpty, isTrue);
    final edited = applied.columns.first.copyWith(
      width: .45,
      name: 'manual edit',
    );
    final manual = applied.copyWith(
      columns: [edited, ...applied.columns.skip(1)],
    );
    final r = InitialSchemeGenerator.generate(
      project: p.copyWith(storeys: [manual]),
      wallPairs: runs,
      scale: 1,
    );
    expect(r.apply(manual).columns.first, same(edited));
    expect(
      p.activeStorey.columns,
      isEmpty,
    ); // original snapshot is the Undo state
  });
  test('a gap between wall runs remains free even when an axis crosses it', () {
    final (p, _) = fixture();
    final runs = [
      pair(const Offset(2, 1), const Offset(2, 6), 1),
      pair(const Offset(2, 10), const Offset(2, 15), 1),
    ];
    final r = InitialSchemeGenerator.generate(
      project: p,
      wallPairs: runs,
      scale: 1,
    );
    for (final c in r.columns) {
      expect(
        StructuralPolygonDistance.between(c.polygonVertices, const [
          Offset(1.8, 6.01),
          Offset(2.2, 6.01),
          Offset(2.2, 9.99),
          Offset(1.8, 9.99),
        ]),
        greaterThan(0),
      );
    }
    for (final w in r.walls) {
      expect(w.polygonVertices.every((v) => v.dy <= 6 || v.dy >= 10), isTrue);
    }
  });
  test('lower supports continue at exact centers when architecture allows', () {
    final (p, runs) = fixture();
    const c = StructuralColumn(
      id: 'lower',
      center: Offset(2, 3),
      width: .3,
      height: .4,
    );
    final upper = p.activeStorey.copyWith(elevation: 3);
    final project = p.copyWith(
      storeys: [
        const StoreyLevel(id: 'lower', name: 'lower', columns: [c]),
        upper,
      ],
      activeStoreyIndex: 1,
    );
    final r = InitialSchemeGenerator.generate(
      project: project,
      wallPairs: runs
          .map((r) => pair(r.centerlineStart, r.centerlineEnd, 1, width: .5))
          .toList(),
      scale: 1,
    );
    expect(
      r.columns.any((v) => v.center == c.center && v.width == c.width),
      isTrue,
    );
  });
  test(
    'JSON persists provenance and generated objects export as native geometry',
    () async {
      final (p, runs) = fixture();
      final r = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: runs,
        scale: 1,
      );
      final restored = StructuralProject.fromJson(
        jsonDecode(
          jsonEncode(p.copyWith(storeys: [r.apply(p.activeStorey)]).toJson()),
        ),
      );
      expect(
        restored.activeStorey.columns.first.generatedBy,
        'initial-scheme-v1',
      );
      expect(
        restored.activeStorey.shearWalls.first.generatedBy,
        'initial-scheme-v1',
      );
      final dir = await Directory.systemTemp.createTemp('scheme_export_');
      addTearDown(() => dir.delete(recursive: true));
      final file = await StructuralPersistenceService.exportStoreyToDxfFile(
        storey: restored.activeStorey,
        baseName: 'scheme',
        outputDirectory: dir,
      );
      final data = await file.readAsString();
      expect(data, contains(restored.activeStorey.columns.first.name!));
    },
  );
  test('separate slab regions receive independent proposals', () {
    final (p, runs) = fixture();
    final second = p.activeStorey.slabs.single.copyWith(
      id: 'second',
      polygon: p.activeStorey.slabs.single.polygon
          .map((v) => v + const Offset(30, 0))
          .toList(),
      openings: [],
      openingTypes: [],
    );
    final expanded = p.copyWith(
      storeys: [
        p.activeStorey.copyWith(slabs: [...p.activeStorey.slabs, second]),
      ],
    );
    final more = [
      for (final r in runs)
        pair(
          r.centerlineStart + const Offset(30, 0),
          r.centerlineEnd + const Offset(30, 0),
          1,
        ),
    ];
    final result = InitialSchemeGenerator.generate(
      project: expanded,
      wallPairs: [...runs, ...more],
      scale: 1,
    );
    expect(result.columns.any((c) => c.center.dx > 30), isTrue);
    expect(result.columns.any((c) => c.center.dx < 20), isTrue);
    expect(result.walls.any((w) => w.center.dx > 30), isTrue);
  });
  test(
    'invalid settings and excessive input cannot produce unchecked objects',
    () {
      final (p, runs) = fixture();
      expect(
        InitialSchemeGenerator.generate(
          project: p,
          wallPairs: runs,
          scale: 1,
          options: const InitialSchemeOptions(
            minSpacingM: 6,
            targetSpacingM: 5,
          ),
        ).isEmpty,
        isTrue,
      );
      final limited = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: List.filled(801, runs.first),
        scale: 1,
      );
      expect(limited.limited, isTrue);
      expect(limited.isEmpty, isTrue);
    },
  );
  test(
    'selected section and idempotent acceptance preserve object identity',
    () {
      final (p, runs) = fixture();
      final r = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: runs
            .map((r) => pair(r.centerlineStart, r.centerlineEnd, 1, width: .5))
            .toList(),
        scale: 1,
        options: const InitialSchemeOptions(
          columnShape: ColumnShape.circular,
          columnWidthM: .4,
          columnDepthM: .4,
        ),
      );
      expect(r.columns, isNotEmpty);
      expect(
        r.columns.every(
          (c) => c.shape == ColumnShape.circular && c.width == .4,
        ),
        isTrue,
      );
      final first = r.apply(p.activeStorey);
      expect(r.apply(first).toJson(), first.toJson());
    },
  );
  test(
    'core walls cover all four sides rather than stopping at two directions',
    () {
      final (p, _) = fixture();
      final runs = [
        pair(const Offset(6.7, 5.5), const Offset(6.7, 10.5), 1),
        pair(const Offset(9.3, 5.5), const Offset(9.3, 10.5), 1),
        pair(const Offset(6.5, 5.7), const Offset(9.5, 5.7), 1),
        pair(const Offset(6.5, 10.3), const Offset(9.5, 10.3), 1),
      ];
      final r = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: runs,
        scale: 1,
      );
      expect(r.walls.length, 4);
      for (final w in r.walls) {
        expect(
          StructuralPolygonDistance.between(
            w.polygonVertices,
            p.activeStorey.slabs.single.openings.single,
          ),
          greaterThan(0),
        );
      }
    },
  );
  test('a blocked wall midpoint does not discard its usable core segments', () {
    final (p, _) = fixture();
    final r = InitialSchemeGenerator.generate(
      project: p,
      wallPairs: [pair(const Offset(8, 1), const Offset(8, 15), 1)],
      scale: 1,
    );
    expect(r.walls, isNotEmpty);
    expect(
      r.walls.every(
        (w) =>
            StructuralPolygonDistance.between(
              w.polygonVertices,
              p.activeStorey.slabs.single.openings.single,
            ) >
            0,
      ),
      isTrue,
    );
  });
  test(
    'a long wall with an axis gains intermediate supports and supports near edges',
    () {
      final (p, _) = fixture();
      final floor = p.activeStorey.copyWith(
        gridAxes: [
          const StructuralGridAxis(
            id: 'long',
            name: 'A',
            start: Offset(.2, 2),
            end: Offset(19.8, 2),
          ),
        ],
      );
      final r = InitialSchemeGenerator.generate(
        project: p.copyWith(storeys: [floor]),
        wallPairs: [pair(const Offset(.2, 2), const Offset(19.8, 2), 1)],
        scale: 1,
      );
      final x = [
        ...r.columns.map((c) => c.center.dx),
        ...r.walls.expand((w) => [w.start.dx, w.end.dx]),
      ]..sort();
      expect(x.length, greaterThanOrEqualTo(4));
      expect(x.first, lessThan(2));
      expect(x.last, greaterThan(18));
      for (var i = 1; i < x.length; i++) {
        expect(x[i] - x[i - 1], lessThanOrEqualTo(5));
      }
      // The rest of this broad slab has no axes: residual gaps must stay visible.
      expect(r.uncoveredSamples, greaterThan(0));
      expect(r.maxSupportDistanceM, greaterThan(5));
    },
  );
  test('more than two deterministic distinct layouts are available', () {
    final (p, runs) = fixture();
    final signatures = <String>{};
    for (var v = 0; v < 5; v++) {
      final r = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: runs,
        scale: 1,
        variant: v,
      );
      final ids = [...r.columns.map((c) => c.id), ...r.walls.map((w) => w.id)]
        ..sort();
      signatures.add(ids.join('|'));
      final reverse = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: runs.reversed.toList(),
        scale: 1,
        variant: v,
      );
      expect(reverse.columns.map((c) => c.id), r.columns.map((c) => c.id));
    }
    expect(signatures.length, greaterThan(2));
  });
  testWidgets('no distinct layout and invalid settings keep the preview safe', (
    tester,
  ) async {
    final (p, _) = fixture();
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InitialSchemeDialog(
          project: p.copyWith(storeys: [p.activeStorey.copyWith(gridAxes: [])]),
          pairs: const [],
          scale: 1,
          options: const InitialSchemeOptions(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('next-scheme')));
    await tester.pumpAndSettle();
    expect(find.text(l.schemeNoAlternative), findsOneWidget);
    expect(find.text('${l.schemeVariant}: 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'NaN');
    await tester.tap(find.byKey(const ValueKey('next-scheme')));
    await tester.pumpAndSettle();
    expect(find.text(l.schemeInvalidOptions), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('accept-scheme')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
  for (final lang in ['bg', 'en']) {
    testWidgets(
      'preview requires confirmation and returns native objects: $lang',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (p, runs) = fixture();
        InitialSchemeProposal? accepted;
        final l = await AppLocalizations.delegate.load(Locale(lang));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('open'),
                  onPressed: () async {
                    accepted = await showDialog<InitialSchemeProposal>(
                      context: context,
                      builder: (_) => InitialSchemeDialog(
                        project: p,
                        pairs: runs,
                        scale: 1,
                        options: const InitialSchemeOptions(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('accept-scheme')))
              .onPressed,
          isNull,
        );
        expect(find.text('${l.schemeVariant}: 1'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('next-scheme')));
        await tester.pumpAndSettle();
        expect(find.text('${l.schemeVariant}: 2'), findsOneWidget);
        expect(find.text(l.schemeVariantCore), findsNothing);
        expect(find.text(l.schemeVariantLong), findsNothing);
        // Upstream switches remain functional with the single-preview flow.
        expect(find.byType(SwitchListTile), findsNWidgets(3));
        await tester.ensureVisible(find.text(l.schemeGenerousDensity));
        await tester.tap(find.text(l.schemeGenerousDensity));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile).last).value,
          isTrue,
        );
        expect(find.text('${l.schemeVariant}: 1'), findsOneWidget);
        await tester.ensureVisible(find.text(l.schemePairedWalls));
        await tester.tap(find.text(l.schemePairedWalls));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SwitchListTile>(find.byType(SwitchListTile).first)
              .value,
          isFalse,
        );

        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('accept-scheme')))
              .onPressed,
          isNull,
        );
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l.schemeAccept));
        await tester.tap(find.text(l.schemeAccept));
        await tester.pumpAndSettle();
        expect(accepted, isNotNull);
        expect(accepted!.isEmpty, isFalse);
        expect(p.activeStorey.columns, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'guarantees at least 2x2 paired shear walls (minimum 4 walls) across orthogonal directions',
    () {
      final (p, runs) = fixture();
      final result = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: runs,
        scale: 1,
        options: const InitialSchemeOptions(
          enforcePairedWalls: true,
          generousDensity: true,
        ),
      );

      // Total shear walls must be at least 4 (2 in X and 2 in Y)
      expect(result.walls.length, greaterThanOrEqualTo(4));

      // Direction breakdown
      final primary = runs.first.centerlineEnd - runs.first.centerlineStart;
      final primaryDir = primary / primary.distance;
      int dirCount0 = 0;
      int dirCount1 = 0;
      for (final w in result.walls) {
        final u = (w.end - w.start) / w.length;
        final dotVal = (u.dx * primaryDir.dx + u.dy * primaryDir.dy).abs();
        if (dotVal >= 0.9239) {
          dirCount0++;
        } else {
          dirCount1++;
        }
      }

      // Both directions must have at least 2 walls (no isolated single wall)
      expect(dirCount0, greaterThanOrEqualTo(2));
      expect(dirCount1, greaterThanOrEqualTo(2));
    },
  );

  test(
    'generous layout provides denser candidate set for engineer pruning',
    () {
      final (p, runs) = fixture();
      final generous = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: runs,
        scale: 1,
        options: const InitialSchemeOptions(
          generousDensity: true,
          adaptiveSizes: false,
          targetSpacingM: 5.0,
        ),
      );

      final sparse = InitialSchemeGenerator.generate(
        project: p,
        wallPairs: runs,
        scale: 1,
        options: const InitialSchemeOptions(
          generousDensity: false,
          adaptiveSizes: false,
          targetSpacingM: 5.0,
        ),
      );

      // Generous layout provides more columns and walls for engineer pruning
      expect(generous.columns.length, greaterThan(sparse.columns.length));
      expect(generous.walls.length, greaterThanOrEqualTo(sparse.walls.length));
      final totalGenerous = generous.columns.length + generous.walls.length;
      final totalSparse = sparse.columns.length + sparse.walls.length;
      expect(totalGenerous, greaterThan(totalSparse));
    },
  );
}
