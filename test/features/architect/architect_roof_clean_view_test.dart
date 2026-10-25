import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_path_solid.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_drainage_mesh.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_drainage_geometry.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_construction_preview.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_layers_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_number_field.dart';
import 'architect_roof_drainage_test.dart' as fixture;
import 'architect_section_cc_package_test.dart' as cases;

void checkFascia(ArchitectProject p) {
  for (final floor in p.storeys) {
    for (final roof in floor.roofs.where(
      (r) => r.drainage.downpipes.isNotEmpty,
    )) {
      final (a, b) = ArchitectRoofDrainageGeometry.eaves(roof);
      final along = (b - a) / (b - a).distance, n = roof.slopeDirection;
      final bottom = floor.elevation + roof.undersideElevationAt(a);
      final top = floor.elevation + roof.topElevationAt(a);
      for (final r in ArchitectRoofDrainageGeometry.build(
        p,
        floor,
        roof,
      ).routes) {
        final duplicate = roof.drainage.downpipes.any(
          (other) =>
              other.id != r.pipe.id &&
              other.visible &&
              (other.offset - r.pipe.offset).abs() <
                  (other.diameter + r.pipe.diameter) / 2 + .02,
        );
        if (duplicate) {
          expect(r.status, ArchitectDownpipeStatus.blocked);
          continue;
        }
        expect(
          r.status,
          ArchitectDownpipeStatus.ready,
          reason:
              '${roof.assembly.timber.rafterHeight}, fascia ${roof.assembly.timber.fasciaThickness}, pitch ${roof.slopeDegrees}, roof ${roof.id}',
        );
        expect(
          r.points[1].z,
          lessThanOrEqualTo(
            bottom -
                r.pipe.diameter / 2 -
                ArchitectRoofDrainageGeometry.maximumFittingExtraRadius -
                ArchitectRoofDrainageGeometry.roofClearance +
                1e-8,
          ),
        );
      }
      final mesh = ArchitectRoofDrainageMesh.build(
        p,
        floor,
        roof,
        includeGutters: false,
      );
      for (final t in mesh) {
        for (final v in [t.v0, t.v1, t.v2, (t.v0 + t.v1 + t.v2) * (1 / 3)]) {
          final delta = Offset(v.x, v.y) - a;
          final s = delta.dx * along.dx + delta.dy * along.dy;
          final d = delta.dx * n.dx + delta.dy * n.dy;
          if (s < 0 || s > (b - a).distance) continue;
          final inside =
              d > -roof.assembly.timber.fasciaThickness + 1e-6 &&
              d < -1e-6 &&
              v.z > bottom + 1e-6 &&
              v.z < top - 1e-6;
          expect(
            inside,
            isFalse,
            reason: 'Pipe or fitting cuts the actual fascia',
          );
        }
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'physical fittings clear the roof and fascia at different depths/pitches',
    () {
      for (final spec in [
        (0.12, .02, 22.0),
        (.6, .12, 22.0),
        (.3, .05, 60.0),
      ]) {
        final p = fixture.drainageProject(),
            floor = p.activeStorey,
            roof = floor.roofs.single;
        final assembly = roof.assembly.copyWith(
          timber: roof.assembly.timber.copyWith(
            rafterHeight: spec.$1,
            fasciaThickness: spec.$2,
          ),
          layers: [
            for (final l in roof.assembly.layers)
              l.role == ArchitectRoofLayerRole.rafters
                  ? l.copyWith(thickness: spec.$1)
                  : l,
          ],
        );
        checkFascia(
          p.copyWith(
            storeys: [
              floor.copyWith(
                roofs: [
                  roof.copyWith(assembly: assembly, slopeDegrees: spec.$3),
                ],
              ),
            ],
          ),
        );
      }
      checkFascia(cases.ccProject(both: true));
    },
  );

  test(
    'facade has no tube facets inside the pipe silhouette; 3D keeps fittings',
    () {
      final p = fixture.drainageProject(),
          s = p.activeStorey,
          roof = s.roofs.single;
      final full = ArchitectRoofDrainageMesh.build(p, s, roof);
      final clean = ArchitectRoofDrainageMesh.build(p, s, roof, details: false);
      expect(full.length, greaterThan(clean.length));
      const view = ArchitectElevation(
        id: 'e',
        start: Offset(-1, -1),
        end: Offset(7, -1),
      );
      final drawing = ArchitectBuildingElevation.build(p, view);
      final center = fixture.pipe.offset - view.centre.dx;
      final internal = <double>[];
      for (final face in drawing.faces) {
        for (final polygon in ArchitectPathSolid.contours(face)) {
          for (var i = 0; i < polygon.length; i++) {
            final a = polygon[i], b = polygon[(i + 1) % polygon.length];
            if ((a.dy > 1) == (b.dy > 1)) continue;
            final x = a.dx + (b.dx - a.dx) * (1 - a.dy) / (b.dy - a.dy);
            if ((x - center).abs() < fixture.pipe.diameter / 2 - .002) {
              internal.add(x);
            }
          }
        }
      }
      expect(
        internal,
        isEmpty,
        reason: 'A 2D view must not publish longitudinal mesh facets',
      );
      expect(drawing.elementPaths['roof']!.contains(Offset(center, 1)), isTrue);
    },
  );

  for (final locale in ['bg', 'en']) {
    testWidgets(
      'live construction follows pitch/timber, all tabs and fullscreen ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ArchitectRoofLayersDialog(
                initialAssembly: ArchitectRoofAssembly.fromPreset(
                  ArchitectRoofPreset.pitchedTiles,
                ),
                initialSlopeDegrees: 22,
                initialEavesOverhang: .5,
                initialEavesCut: ArchitectRoofEavesCut.plumb,
                onApply: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        ArchitectRoofConstructionPainter painter() =>
            tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('roof-construction-preview')),
                    )
                    .painter!
                as ArchitectRoofConstructionPainter;
        expect(
          painter().members.any(
            (m) => m.role == ArchitectRoofLayerRole.rafters,
          ),
          isTrue,
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('roof-slope-input')),
            matching: find.byType(TextFormField),
          ),
          '35',
        );
        await tester.pumpAndSettle();
        final cover = painter().members.firstWhere(
          (m) => m.role == ArchitectRoofLayerRole.covering,
        );
        final v = cover.polygon[1] - cover.polygon[0];
        expect(math.atan2(v.dy, v.dx) * 180 / math.pi, closeTo(35, 1e-7));
        final l = AppLocalizations.of(
          tester.element(find.byType(ArchitectRoofLayersDialog)),
        )!;
        await tester.tap(find.text(l.roofUiDetails));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l.architectRoofRaftersLabel));
        await tester.tap(find.text(l.architectRoofRaftersLabel));
        await tester.pumpAndSettle();
        final height = find.byWidgetPredicate(
          (w) =>
              w is ArchitectRoofNumberField &&
              w.label == l.architectPropertyHeight,
        );
        await tester.ensureVisible(height);
        await tester.enterText(
          find.descendant(of: height, matching: find.byType(TextFormField)),
          '30',
        );
        await tester.pumpAndSettle();
        final timber = painter().members.firstWhere(
          (m) => m.role == ArchitectRoofLayerRole.rafters,
        );
        expect(
          (timber.polygon[2].dy - timber.polygon[1].dy).abs(),
          closeTo(.3 / math.cos(35 * math.pi / 180), 1e-7),
        );
        await tester.tap(
          find.byKey(const ValueKey('roof-construction-preview')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('roof-preview-close')));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(740, 320);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('roof-preview')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
