import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/project_grid_axes.dart';
import 'package:kotoview/src/features/structural_designer/analysis/staircase_inventory.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_bim_context.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/slab_plan_labels.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/structural_designer_screen.dart';
import 'package:kotoview/src/features/structural_designer/widgets/staircase_setup_dialog.dart';

const ring = [Offset(1, 1), Offset(9, 1), Offset(9, 9), Offset(1, 9)];
StructuralProject plates() => const StructuralProject(
  storeys: [
    StoreyLevel(
      id: 'g',
      name: 'Ground',
      slabs: [StructuralSlab(id: 'ground', polygon: ring, isFloorSlab: true)],
    ),
    StoreyLevel(
      id: 'f',
      name: 'First',
      elevation: 2.85,
      slabs: [
        StructuralSlab(
          id: 'upper',
          polygon: ring,
          isFloorSlab: true,
          openings: [
            [Offset(3, 3), Offset(4, 3), Offset(4, 5), Offset(3, 5)],
          ],
          openingTypes: [SlabOpeningType.staircase],
        ),
      ],
    ),
    StoreyLevel(
      id: 'r',
      name: 'Roof',
      elevation: 5.6,
      slabs: [StructuralSlab(id: 'roof', polygon: ring, isFloorSlab: true)],
    ),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('coincident plate badges never overlap, at several zooms', () {
    final p = plates();
    for (final zoom in [.2, 1.0, 5.0]) {
      final labels = SlabPlanLabels.layout(
        current: p.activeStorey,
        upper: p.ceilingSlabStoreyFor(p.activeStorey),
        project: (v) => v * 100,
        zoom: zoom,
      );
      expect(labels, hasLength(2));
      expect(labels[0].rect.overlaps(labels[1].rect), isFalse);
      expect(labels[0].owner.id, 'g');
      expect(labels[1].owner.id, 'f');
      expect(labels[1].slab.id, 'upper');
    }
  });
  test(
    'manual cut proposes a reviewed scope, reserves no inferred landing, never cuts a roof',
    () {
      final p = plates();
      final adopted = StaircaseInventory.adoptExisting(p, 1);
      expect(adopted.staircases, hasLength(1));
      expect(adopted.staircases.single.startStoreyId, 'g');
      expect(adopted.staircases.single.endStoreyId, 'f');
      expect(adopted.staircaseReviewComplete, isFalse);
      final inventory = StaircaseInventory.evaluate(
        adopted,
        1,
        requireReview: true,
      );
      expect(inventory.openings.single.ownerStoreyId, 'f');
      expect(
        inventory.gaps.where(
          (g) => g.requirement == StaircaseRequirement.opening,
        ),
        isEmpty,
      );
      expect(
        inventory.gaps
            .where((g) => g.requirement == StaircaseRequirement.circulation)
            .map((g) => g.storeyId),
        ['g', 'f'],
      );
      expect(adopted.storeys.last.slabs.single.openings, isEmpty);
      expect(adopted.storeys.every((s) => s.staircaseZones.isEmpty), isTrue);
    },
  );
  test('a new manual cut invalidates an earlier no-stairs review', () {
    final p = plates().copyWith(staircaseReviewComplete: true);
    final inv = StaircaseInventory.evaluate(p, 1, requireReview: true);
    expect(inv.ready, isFalse);
    expect(inv.openings.single.ownerStoreyId, 'f');
    expect(
      inv.gaps.any((g) => g.requirement == StaircaseRequirement.review),
      isTrue,
    );
    expect(
      inv.gaps.where((g) => g.requirement == StaircaseRequirement.opening),
      isEmpty,
    );
  });
  test(
    'manual cuts on two arrival levels remain one scope; independent stairs remain separate',
    () {
      final p = plates();
      final upper = p.storeys[1].slabs.single;
      final two = p.copyWith(
        storeys: [
          p.storeys[0],
          p.storeys[1],
          p.storeys[2].copyWith(
            slabs: [
              upper.copyWith(
                id: 'last',
                openings: [
                  ...upper.openings,
                  [
                    const Offset(6, 3),
                    const Offset(7, 3),
                    const Offset(7, 5),
                    const Offset(6, 5),
                  ],
                ],
                openingTypes: [
                  SlabOpeningType.staircase,
                  SlabOpeningType.staircase,
                ],
              ),
            ],
          ),
        ],
      );
      final adopted = StaircaseInventory.adoptExisting(two, 1);
      expect(adopted.staircases, hasLength(2));
      final inv = StaircaseInventory.evaluate(adopted, 1, requireReview: true);
      expect(inv.openings, hasLength(3));
      expect(
        inv.gaps.where((g) => g.requirement == StaircaseRequirement.opening),
        isEmpty,
      );
    },
  );
  test(
    'automatic axes use common rails, while explicit extents are preserved',
    () {
      final axes = [
        const StructuralGridAxis(
          id: 'bim_axis_g_a',
          name: '1',
          start: Offset(0, 2),
          end: Offset(0, 9),
        ),
        const StructuralGridAxis(
          id: 'bim_axis_f_b',
          name: '2',
          start: Offset(3, -2),
          end: Offset(3, 12),
        ),
        const StructuralGridAxis(
          id: 'axis_auto_c',
          name: '3',
          start: Offset(6, 10),
          end: Offset(6, 0),
        ),
        const StructuralGridAxis(
          id: 'bim_axis_edited',
          name: '4',
          start: Offset(9, 4),
          end: Offset(9, 6),
        ),
        const StructuralGridAxis(
          id: 'manual',
          name: '5',
          start: Offset(12, 4),
          end: Offset(12, 6),
        ),
      ];
      final aligned = ProjectGridAxes.merge(
        axes,
        1,
        isBulgarian: false,
        preserveExtents: {'bim_axis_edited'},
      );
      for (final a in aligned.take(3)) {
        expect([a.start.dy, a.end.dy]..sort(), [-2, 12]);
        final old = axes.firstWhere((old) => old.id == a.id);
        expect(a.start.dx, old.start.dx);
        expect(a.end.dx, old.end.dx);
      }
      expect(aligned[3].start, axes[3].start);
      expect(aligned[3].end, axes[3].end);
      expect(aligned[4].start, axes[4].start);
      expect(aligned[4].end, axes[4].end);
    },
  );
  testWidgets(
    'setup shows a found manual cut instead of claiming there are no stairs',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StaircaseSetupDialog(project: plates(), scale: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.staircaseNoStairs), findsNothing);
      expect(find.text(l.staircaseOpeningReady), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pressing an upper reference badge selects the actual upper slab and owner',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = DxfDocument(
        entities: [],
        layers: {},
        blocks: {},
        headerVars: {},
        entityStats: {},
        bounds: const Rect.fromLTRB(0, 0, 10, 10),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StructuralDesignerScreen(
            document: doc,
            title: 'Badges',
            initialProject: plates(),
            bimContext: StructuralBimContext(
              underlaysByStorey: {'g': doc, 'f': doc, 'r': doc},
              projectBounds: doc.bounds,
              cadUnitsPerMeter: 1,
              onProjectChanged: (_) {},
              onLayerVisibilityChanged: (_, _) {},
              onWallsDetected: (_) {},
              onExport: (_, _, _) async {},
              onManageStoreys: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slab'));
      await tester.pumpAndSettle();
      Finder paint() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is Structural2dPainter,
      );
      Structural2dPainter painter() =>
          tester.widget<CustomPaint>(paint()).painter as Structural2dPainter;
      final before = painter();
      final labels = SlabPlanLabels.layout(
        current: before.currentStorey,
        upper: before.ceilingSlabStorey,
        lower: before.floorSlabStorey,
        project: before.cadToScene,
        zoom: before.zoomScale,
      );
      final own = labels.firstWhere((l) => l.owner.id == 'g');
      await tester.tapAt(
        tester.renderObject<RenderBox>(paint()).localToGlobal(own.rect.center),
      );
      await tester.pumpAndSettle();
      expect(painter().currentStorey.id, 'g');
      expect(painter().selectedSlabId, 'ground');
      final upper = labels.firstWhere((l) => l.owner.id == 'f');
      await tester.tapAt(
        tester
            .renderObject<RenderBox>(paint())
            .localToGlobal(upper.rect.center),
      );
      await tester.pumpAndSettle();
      expect(painter().currentStorey.id, 'f');
      expect(painter().selectedSlabId, 'upper');
      expect(painter().currentStorey.slabs.single.isFloorSlab, isTrue);
      expect(find.textContaining('2.800 m'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
