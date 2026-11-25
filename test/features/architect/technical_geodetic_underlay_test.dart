import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_underlay_painter.dart';
import 'package:kotoview/src/features/architect/widgets/architect_underlay_bar.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';

DxfDocument _dxfLine(double x1, double y1, double x2, double y2) =>
    DxfParser.parseString('''
  0
SECTION
  2
ENTITIES
  0
LINE
  8
0
 10
$x1
 20
$y1
 11
$x2
 21
$y2
  0
ENDSEC
  0
EOF
''');

Widget _wrapApp(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('bg'),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('Geodetic vs technical underlay separation', () {
    test('models round-trip kind and discipline via JSON', () {
      const cad = ArchitectCadUnderlayConfig(
        id: 'cad_struct_1',
        storeyId: 'ground',
        fileName: 'konstrukcii.dwg',
        internalCopyPath: 'underlays/cad/konstrukcii.dwg',
        kind: ArchitectUnderlayKind.technical,
        discipline: ArchitectTechnicalUnderlayDiscipline.structural,
        shareToGroundStoreys: false,
      );
      final cadDecoded = ArchitectCadUnderlayConfig.fromJson(cad.toJson());
      expect(cadDecoded.effectiveId, 'cad_struct_1');
      expect(cadDecoded.kind, ArchitectUnderlayKind.technical);
      expect(
        cadDecoded.discipline,
        ArchitectTechnicalUnderlayDiscipline.structural,
      );

      final raster = ArchitectRasterUnderlay(
        id: 'rast_1',
        storeyId: 'site',
        fileName: 'skica.pdf',
        internalImagePath: 'underlays/raster/skica.png',
        imageWidthPx: 100,
        imageHeightPx: 100,
        position: Offset.zero,
        kind: ArchitectUnderlayKind.geodetic,
      );
      final rasterDecoded = ArchitectRasterUnderlay.fromJson(raster.toJson());
      expect(rasterDecoded.kind, ArchitectUnderlayKind.geodetic);
      expect(
        rasterDecoded.discipline,
        ArchitectTechnicalUnderlayDiscipline.general,
      );

      // Backward compatibility when kind & discipline are omitted
      final legacy = ArchitectCadUnderlayConfig.fromJson({
        'storeyId': 'ground',
        'fileName': 'legacy.dwg',
        'internalCopyPath': 'underlays/cad/legacy.dwg',
      });
      expect(legacy.effectiveId, 'ground');
      expect(legacy.kind, ArchitectUnderlayKind.technical);
      expect(legacy.discipline, ArchitectTechnicalUnderlayDiscipline.general);
    });

    test(
      'site plan geodetic underlay does not leak onto building storeys & technical plans support multiple underlays',
      () {
        const site = ArchitectStorey(
          id: 'site',
          name: 'Site Plan',
          elevation: 0,
          isSite: true,
        );
        const ground = ArchitectStorey(
          id: 'ground',
          name: 'Ground Floor',
          elevation: 0,
        );
        const level1 = ArchitectStorey(
          id: 'level1',
          name: 'Level +3.00',
          elevation: 3.0,
        );

        final now = DateTime(2026);
        var project = ArchitectProject(
          id: 'p1',
          name: 'Test',
          storeys: const [site, ground, level1],
          activeStoreyId: 'site',
          createdAt: now,
          updatedAt: now,
        );

        // Add geodetic survey underlay on Site Plan
        const geodeticCad = ArchitectCadUnderlayConfig(
          id: 'geo_1',
          storeyId: 'site',
          fileName: 'geodezia.dwg',
          internalCopyPath: 'underlays/cad/geo.dwg',
          kind: ArchitectUnderlayKind.geodetic,
          shareToGroundStoreys: false,
        );
        project = project.withCadUnderlayAdded(geodeticCad);

        expect(project.cadUnderlaysForStorey('site').length, 1);
        expect(
          project.cadUnderlaysForStorey('site').single.kind,
          ArchitectUnderlayKind.geodetic,
        );
        // Must NOT leak onto ±0.00 or +3.00!
        expect(project.effectiveCadUnderlaysForStorey('ground'), isEmpty);
        expect(project.effectiveCadUnderlaysForStorey('level1'), isEmpty);

        // Add 2 simultaneous technical CAD underlays on Ground Floor (Structural + Plumbing)
        const structCad = ArchitectCadUnderlayConfig(
          id: 'cad_struct',
          storeyId: 'ground',
          fileName: 'K-Plocha.dwg',
          internalCopyPath: 'underlays/cad/struct.dwg',
          kind: ArchitectUnderlayKind.technical,
          discipline: ArchitectTechnicalUnderlayDiscipline.structural,
          shareToGroundStoreys: false,
        );
        const plumbingCad = ArchitectCadUnderlayConfig(
          id: 'cad_vik',
          storeyId: 'ground',
          fileName: 'ViK-Plan.dwg',
          internalCopyPath: 'underlays/cad/vik.dwg',
          kind: ArchitectUnderlayKind.technical,
          discipline: ArchitectTechnicalUnderlayDiscipline.plumbing,
          shareToGroundStoreys: false,
        );

        project = project
            .withCadUnderlayAdded(structCad)
            .withCadUnderlayAdded(plumbingCad);

        final groundUnderlays = project.cadUnderlaysForStorey('ground');
        expect(groundUnderlays.length, 2);
        expect(
          groundUnderlays.map((c) => c.discipline).toList(),
          [
            ArchitectTechnicalUnderlayDiscipline.structural,
            ArchitectTechnicalUnderlayDiscipline.plumbing,
          ],
        );

        // Update plumbing opacity/visibility independently
        project = project.withCadUnderlayUpdated(
          plumbingCad.copyWith(visible: false, opacity: 0.7),
        );
        final updatedVik = project.cadUnderlayById('ground', 'cad_vik')!;
        expect(updatedVik.visible, isFalse);
        expect(updatedVik.opacity, 0.7);
        expect(project.cadUnderlayById('ground', 'cad_struct')!.visible, isTrue);

        // Remove primary Structural -> Plumbing is promoted cleanly
        project = project.withCadUnderlayRemoved('ground', 'cad_struct');
        expect(project.cadUnderlaysForStorey('ground').length, 1);
        expect(
          project.cadUnderlaysForStorey('ground').single.effectiveId,
          'cad_vik',
        );

        // JSON round-trip preserves technicalCadUnderlays
        final decoded = ArchitectProject.fromJson(
          project
              .withCadUnderlayAdded(structCad)
              .toJson(),
        );
        expect(decoded.cadUnderlaysForStorey('ground').length, 2);
        expect(decoded.cadUnderlaysForStorey('site').length, 1);
      },
    );

    test('ArchitectSnapHelper snaps across multiple extraUnderlays', () {
      const ground = ArchitectStorey(id: 'ground', name: 'Ground', elevation: 0);
      final now = DateTime(2026);
      final project = ArchitectProject(
        id: 'p1',
        name: 'SnapTest',
        storeys: const [ground],
        activeStoreyId: 'ground',
        createdAt: now,
        updatedAt: now,
      );
      final primaryDoc = _dxfLine(0, 0, 5, 0);
      final secondaryDoc = _dxfLine(10, 10, 15, 10);
      const frame = BimCoordinateFrame();

      final snap = ArchitectSnapHelper.snapFree(
        rawPoint: const Offset(10.05, 10.05),
        project: project,
        tolerance: 0.3,
        underlay: primaryDoc,
        frame: frame,
        extraUnderlays: [
          (
            document: secondaryDoc,
            frame: frame,
            visibility: const {},
            mask: null,
          ),
        ],
      );

      expect(snap.isSnapped, isTrue);
      expect(snap.point.dx, closeTo(10.0, 1e-6));
      expect(snap.point.dy, closeTo(10.0, 1e-6));
    });

    test('ArchitectUnderlayPainter renders extraCadUnderlays cleanly', () {
      final viewport = BimViewportController();
      final doc1 = _dxfLine(0, 0, 5, 5);
      final doc2 = _dxfLine(-3, 2, 4, 2);
      final painter = ArchitectUnderlayPainter(
        document: doc1,
        frame: const BimCoordinateFrame(),
        viewport: viewport,
        visibility: const {},
        extraCadUnderlays: [
          ArchitectCadRenderLayer(
            document: doc2,
            frame: const BimCoordinateFrame(),
          ),
        ],
        showGeodesyLayer: false,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording().dispose();
    });

    testWidgets(
      'ArchitectCadUnderlayBar displays role badge & switches between multiple technical underlays',
      (tester) async {
        const structCad = ArchitectCadUnderlayConfig(
          id: 'cad_struct',
          storeyId: 'ground',
          fileName: 'K-Plocha.dwg',
          internalCopyPath: 'underlays/cad/struct.dwg',
          kind: ArchitectUnderlayKind.technical,
          discipline: ArchitectTechnicalUnderlayDiscipline.structural,
        );
        const vikCad = ArchitectCadUnderlayConfig(
          id: 'cad_vik',
          storeyId: 'ground',
          fileName: 'ViK-Plan.dwg',
          internalCopyPath: 'underlays/cad/vik.dwg',
          kind: ArchitectUnderlayKind.technical,
          discipline: ArchitectTechnicalUnderlayDiscipline.plumbing,
        );

        String? selectedId;
        (String, bool)? toggled;

        await tester.pumpWidget(
          _wrapApp(
            ArchitectCadUnderlayBar(
              config: structCad,
              underlays: const [structCad, vikCad],
              isSitePlan: false,
              isBusy: false,
              onAddUnderlay: () {},
              onSelectUnderlay: (id) => selectedId = id,
              onToggleUnderlayVisibility: (pair) => toggled = pair,
              onMove: () {},
              onOpenScale: () {},
            ),
          ),
        );

        expect(find.text('Конструкции'), findsOneWidget);
        expect(find.text('K-Plocha.dwg'), findsOneWidget);

        // Open underlay selector dropdown
        await tester.tap(find.text('K-Plocha.dwg'));
        await tester.pumpAndSettle();

        expect(find.text('ВиК · ViK-Plan.dwg'), findsOneWidget);
        await tester.tap(find.text('ВиК · ViK-Plan.dwg'));
        await tester.pumpAndSettle();
        expect(selectedId, 'cad_vik');

        // Also toggle visibility directly from dropdown eye icon
        await tester.tap(find.text('K-Plocha.dwg'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.visibility_outlined).last);
        await tester.pumpAndSettle();
        expect(toggled, ('cad_vik', false));
      },
    );

    testWidgets(
      'showArchitectUnderlayEditDialog edits technical discipline and visibility',
      (tester) async {
        ArchitectTechnicalUnderlayDiscipline? changedDiscipline;
        bool? changedVisible;

        await tester.pumpWidget(
          _wrapApp(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showArchitectUnderlayEditDialog(
                  context: context,
                  title: 'Test CAD',
                  initialOpacity: 0.5,
                  onOpacityChanged: (_) {},
                  isVisible: true,
                  onVisibilityChanged: (v) => changedVisible = v,
                  discipline: ArchitectTechnicalUnderlayDiscipline.general,
                  onDisciplineChanged: (d) => changedDiscipline = d,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('architect-underlay-visibility')),
        );
        await tester.pumpAndSettle();
        expect(changedVisible, isFalse);

        await tester.tap(
          find.byKey(const ValueKey('architect-underlay-discipline')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Конструкции').last);
        await tester.pumpAndSettle();
        expect(
          changedDiscipline,
          ArchitectTechnicalUnderlayDiscipline.structural,
        );
      },
    );

    testWidgets(
      'showArchitectUnderlayContextMenu gates terrain & orientation to Site Plan',
      (tester) async {
        await tester.pumpWidget(
          _wrapApp(
            Builder(
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => showArchitectUnderlayContextMenu(
                      context: context,
                      globalPosition: const Offset(100, 100),
                      isCad: true,
                      visible: true,
                      isSitePlan: false,
                      hasSurvey: true,
                      canOrientBuilding: true,
                    ),
                    child: const Text('TechMenu'),
                  ),
                  ElevatedButton(
                    onPressed: () => showArchitectUnderlayContextMenu(
                      context: context,
                      globalPosition: const Offset(100, 100),
                      isCad: true,
                      visible: true,
                      isSitePlan: true,
                      hasSurvey: true,
                      canOrientBuilding: true,
                    ),
                    child: const Text('SiteMenu'),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.tap(find.text('TechMenu'));
        await tester.pumpAndSettle();
        expect(find.text('Към 3D терен'), findsNothing);

        // Dismiss popup menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await tester.tap(find.text('SiteMenu'));
        await tester.pumpAndSettle();
        expect(find.text('Към 3D терен'), findsOneWidget);
      },
    );
  });
}
