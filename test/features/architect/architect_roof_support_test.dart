import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';
import 'dart:convert';

import 'package:flutter/material.dart' show ColorScheme;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_bg.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_material_layer.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_placement.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';

const cut = ArchitectSection(
  id: 'cut',
  name: 'A',
  start: Offset(3, -3),
  end: Offset(3, 7),
);

ArchitectProject projectWithSupport({double wallY = 0, double eavesY = -1.5}) {
  final floor = ArchitectStorey(
    id: 'ground',
    name: 'Ground',
    height: 3,
    walls: [
      ArchitectWall(
        id: 'wall',
        startPoint: Offset(0, wallY),
        endPoint: Offset(6, wallY),
        thickness: .45,
        insulationThicknessOverride: .2,
        height: 3,
        layers: const [
          ArchitectMaterialLayer(
            id: 'eps',
            material: ArchitectMaterial.eps,
            role: ArchitectLayerRole.insulation,
            thickness: .2,
          ),
          ArchitectMaterialLayer(
            id: 'brick',
            material: ArchitectMaterial.brick,
            role: ArchitectLayerRole.core,
            thickness: .25,
          ),
        ],
      ),
    ],
  );
  final roofPlan = ArchitectStorey(
    id: 'roof_plan',
    name: 'Roof',
    elevation: 3,
    isRoof: true,
    roofs: [
      ArchitectRoofPlane(
        id: 'roof',
        storeyId: 'roof_plan',
        points: [
          Offset(-1, eavesY),
          Offset(7, eavesY),
          const Offset(7, 5),
          const Offset(-1, 5),
        ],
        eavesOverhang: .5,
        slopeDegrees: 25,
        baseElevationOffset: 0,
        placementResolved: true,
      ),
    ],
  );
  return ArchitectProject(
    id: 'p',
    name: 'P',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    // Plan menu order, including an empty level between roof and support.
    storeys: [
      roofPlan,
      const ArchitectStorey(id: 'empty', name: 'Empty', elevation: 2),
      floor,
    ],
    activeStoreyId: roofPlan.id,
  );
}

List<ArchitectRoofSectionMember> members(
  ArchitectProject project,
  ArchitectSection section,
) {
  final floor = project.roofStorey!;
  return ArchitectRoofGeometry.buildSectionSlices(
    storey: floor,
    sectionLine: section,
    lowerStorey: ArchitectRoofGeometry.supportingWallStorey(project, floor),
  ).expand((s) => s.members).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'manual distance overrides walls, persists, and unchecking restores automatic support',
    () {
      final original = projectWithSupport();
      final floor = original.roofStorey!;
      final roof = floor.roofs.single;
      ArchitectProject withRoof(ArchitectRoofPlane value) => original.copyWith(
        storeys: [
          floor.copyWith(roofs: [value]),
          ...original.storeys.skip(1),
        ],
      );
      final manual = roof.copyWith(manualSupportDistance: .65);
      final saved = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(withRoof(manual).toJson())),
      );
      final rb = members(
        saved,
        cut,
      ).singleWhere((m) => m.kind == ArchitectRoofMemberKind.ringBeam);
      final wp = members(
        saved,
        cut,
      ).singleWhere((m) => m.kind == ArchitectRoofMemberKind.wallPlate);
      // Low eaves are y=-1.5, independent of the actual wall at y=0.
      expect(rb.path.getBounds().center.dx, closeTo(3 - 1.5 + .65, 1e-5));
      expect(
        wp.path.getBounds().center.dx,
        closeTo(rb.path.getBounds().center.dx, 1e-5),
      );
      expect(saved.roofStorey!.roofs.single.manualSupportDistance, .65);
      expect(manual.eavesOverhang, roof.eavesOverhang);
      expect(manual.points, roof.points);
      expect(
        manual.undersideElevationAt(Offset.zero),
        roof.undersideElevationAt(Offset.zero),
      );
      final automatic = manual.copyWith(clearManualSupportDistance: true);
      final restoredRb = members(
        withRoof(automatic),
        cut,
      ).singleWhere((m) => m.kind == ArchitectRoofMemberKind.ringBeam);
      expect(restoredRb.path.getBounds().center.dx, closeTo(3, 1e-5));
      expect(automatic.toJson().containsKey('manualSupportDistance'), isFalse);
    },
  );

  test(
    'manual support measures from the low eaves after reversing the slope',
    () {
      final original = projectWithSupport();
      final floor = original.roofStorey!;
      for (final distance in [0.0, .8]) {
        final project = original.copyWith(
          storeys: [
            floor.copyWith(
              roofs: [
                floor.roofs.single.copyWith(
                  reverseSlope: true,
                  manualSupportDistance: distance,
                ),
              ],
            ),
            ...original.storeys.skip(1),
          ],
        );
        final rb = members(
          project,
          cut,
        ).singleWhere((m) => m.kind == ArchitectRoofMemberKind.ringBeam);
        expect(rb.path.getBounds().center.dx, closeTo(3 + 5 - distance, 1e-5));
      }
    },
  );

  test(
    'support follows the wall core after moving wall and extending eaves',
    () async {
      for (final wallY in [0.0, .8]) {
        for (final eavesY in [-.6, -1.8]) {
          final project = projectWithSupport(wallY: wallY, eavesY: eavesY);
          final details = members(project, cut);
          final rb = details.singleWhere(
            (m) => m.kind == ArchitectRoofMemberKind.ringBeam,
          );
          final wp = details.singleWhere(
            (m) => m.kind == ArchitectRoofMemberKind.wallPlate,
          );
          final rbBounds = rb.path.getBounds(), wpBounds = wp.path.getBounds();
          final wall = project.storeys.last.walls.single;
          final coreBounds = (Path()..addPolygon(wall.coreCorners, true))
              .getBounds();
          expect(rbBounds.left, closeTo(coreBounds.top - cut.start.dy, 1e-5));
          expect(
            rbBounds.right,
            closeTo(coreBounds.bottom - cut.start.dy, 1e-5),
          );
          expect(rbBounds.width, closeTo(.25, 1e-5));
          expect(wpBounds.center.dx, closeTo(rbBounds.center.dx, 1e-5));
          expect(wpBounds.top, closeTo(rbBounds.bottom, 1e-5));
          expect(rbBounds.height, closeTo(.1, 1e-5));
          final section = ArchitectBuildingSection.build(project, cut);
          final wallRegions = section.regions.where(
            (r) => r.sourceId == 'wall',
          );
          expect(wallRegions, isNotEmpty);
          final insideCore = Offset(rbBounds.center.dx, rbBounds.top - .01);
          expect(
            wallRegions.any((r) => r.path.contains(insideCore)),
            isTrue,
            reason:
                'wallY=$wallY eavesY=$eavesY beam=$rbBounds wall=${wallRegions.map((r) => r.path.getBounds()).toList()}',
          );
          for (final region in wallRegions) {
            expect(
              Path.combine(
                PathOperation.intersect,
                region.path,
                rb.path,
              ).getBounds().isEmpty,
              isTrue,
            );
          }
          if (const bool.fromEnvironment('ROOF_SUPPORT_QA_CAPTURE')) {
            final recorder = PictureRecorder();
            final canvas = Canvas(recorder);
            canvas.drawColor(const Color(0xFFF5F6F8), BlendMode.src);
            final drawing = ArchitectSectionDrawing(
              project,
              cut,
              section,
              AppLocalizationsBg(),
              const ColorScheme.light(),
              null,
              null,
            );
            ArchitectBuildingSectionPainter(
              drawing,
              Offset(2.7, rbBounds.top + .3),
              360,
            ).paint(canvas, const Size(960, 960));
            final picture = recorder.endRecording();
            final image = await picture.toImage(960, 960);
            final png = (await image.toByteData(format: ImageByteFormat.png))!;
            final directory = Directory('build/architect-roof-support-qa');
            await directory.create(recursive: true);
            await File(
              '${directory.path}/support_${wallY}_$eavesY.png',
            ).writeAsBytes(png.buffer.asUint8List());
            image.dispose();
            picture.dispose();
          }
        }
      }
    },
  );

  test(
    'wall placement resolves through empty levels independently of storey order',
    () {
      final original = projectWithSupport();
      final roofPlan = original.roofStorey!;
      final unresolved = original.copyWith(
        storeys: [
          roofPlan.copyWith(
            roofs: [
              roofPlan.roofs.single.copyWith(
                baseElevationOffset: 2.8,
                placementResolved: false,
              ),
            ],
          ),
          ...original.storeys.skip(1),
        ],
      );
      final resolved = ArchitectRoofPlacement.resolve(unresolved);
      expect(
        resolved.roofStorey!.roofs.single.baseElevationOffset,
        closeTo(0, 1e-6),
      );
    },
  );

  test('does not invent a bearing in a cut that misses existing walls', () {
    final project = projectWithSupport();
    const missingWallCut = ArchitectSection(
      id: 'outside',
      name: 'B',
      start: Offset(6.5, -3),
      end: Offset(6.5, 7),
    );
    final details = members(project, missingWallCut);
    expect(details, isNotEmpty);
    expect(
      details.where(
        (m) =>
            m.kind == ArchitectRoofMemberKind.ringBeam ||
            m.kind == ArchitectRoofMemberKind.wallPlate,
      ),
      isEmpty,
    );
  });

  test(
    'thick obliquely cut wall remains a support beyond the old 85cm limit',
    () {
      final original = projectWithSupport();
      final floor = original.storeys.last;
      final project = original.copyWith(
        storeys: [
          original.roofStorey!,
          floor.copyWith(
            walls: [
              floor.walls.single.copyWith(thickness: .9, layers: const []),
            ],
          ),
        ],
      );
      const oblique = ArchitectSection(
        id: 'oblique',
        name: 'C',
        start: Offset(0, -2),
        end: Offset(6, 2),
      );
      final details = members(project, oblique);
      final rb = details.singleWhere(
        (m) => m.kind == ArchitectRoofMemberKind.ringBeam,
      );
      final wp = details.singleWhere(
        (m) => m.kind == ArchitectRoofMemberKind.wallPlate,
      );
      expect(rb.path.getBounds().width, closeTo(.7 * math.sqrt(52) / 4, 1e-5));
      expect(wp.path.getBounds().width, closeTo(.14 * math.sqrt(52) / 4, 1e-5));
    },
  );
}
