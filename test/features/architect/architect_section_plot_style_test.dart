import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_section_hatch.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('section cuts retain their material roles and paper widths', () {
    const cut = ArchitectSection(
      id: 'section',
      start: Offset(-1, 0),
      end: Offset(8, 0),
    );
    final project = ArchitectProject(
      id: 'project',
      name: 'Section test',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 'storey',
      sections: const [cut],
      storeys: const [
        ArchitectStorey(
          id: 'storey',
          name: 'Ground floor',
          elevation: 0,
          height: 3,
          walls: [
            ArchitectWall(
              id: 'wall',
              startPoint: Offset(1, -2),
              endPoint: Offset(1, 2),
              thickness: .37,
              location: ArchitectWallLocation.exterior,
              layers: [
                ArchitectMaterialLayer(
                  id: 'eps',
                  material: ArchitectMaterial.eps,
                  role: ArchitectLayerRole.insulation,
                  thickness: .10,
                ),
                ArchitectMaterialLayer(
                  id: 'core',
                  material: ArchitectMaterial.brick,
                  role: ArchitectLayerRole.core,
                  thickness: .25,
                ),
                ArchitectMaterialLayer(
                  id: 'plaster',
                  material: ArchitectMaterial.plaster,
                  role: ArchitectLayerRole.finish,
                  thickness: .02,
                ),
              ],
              windows: [
                ArchitectWindow(
                  id: 'window',
                  uuid: 'test-window',
                  wallId: 'wall',
                  offsetRatio: .5,
                ),
              ],
            ),
            ArchitectWall(
              id: 'partition',
              startPoint: Offset(4, -2),
              endPoint: Offset(4, 2),
              wallTypeId: 'int_12_partition',
              thickness: .12,
            ),
            ArchitectWall(
              id: 'background-wall',
              startPoint: Offset(5, 1),
              endPoint: Offset(7, 1),
            ),
          ],
          slabs: [
            ArchitectSlab(
              id: 'slab',
              polygon: [
                Offset(1, -2),
                Offset(7, -2),
                Offset(7, 2),
                Offset(1, 2),
              ],
              thickness: .2,
            ),
          ],
        ),
      ],
    );
    final data = ArchitectBuildingSection.build(project, cut).forView(cut);
    Iterable<ArchitectSectionRegion> regionsFor(String id) =>
        data.regions.where((region) => region.sourceId == id);
    final wall = regionsFor('wall');
    expect(
      wall.any((r) => r.structural && r.effectiveHatch?.id == 'brick'),
      isTrue,
    );
    expect(
      wall.any((r) => !r.structural && r.effectiveHatch?.id == 'dots'),
      isTrue,
    );
    expect(wall.any((r) => !r.structural && r.effectiveHatch == null), isTrue);
    final partition = regionsFor('partition');
    expect(partition, isNotEmpty);
    expect(partition.every((region) => !region.structural), isTrue);
    final window = regionsFor('window');
    expect(window, isNotEmpty);
    expect(
      window.every(
        (region) => !region.structural && region.effectiveHatch == null,
      ),
      isTrue,
    );
    expect(
      regionsFor(
        'slab',
      ).any((r) => r.structural && r.material == SlabMaterial.concrete),
      isTrue,
    );

    const drawing = ArchitectSavedDrawing(
      id: 'drawing',
      sourceId: 'section',
      kind: ArchitectDrawingKind.section,
    );
    final l = lookupAppLocalizations(const Locale('en'));
    for (final denominator in [50, 100]) {
      final ops = ArchitectDrawingPublisher.build(
        project,
        drawing,
        denominator,
        l,
      ).operations.whereType<ArchitectVectorPath>().toList();
      Iterable<ArchitectVectorPath> role(String role) =>
          ops.where((op) => op.role == role);
      final cuts = role('sectionRegion');
      expect(cuts.map((op) => op.width), containsAll([.25, .5]));
      final windows = cuts.where((op) => op.sources.contains('window'));
      expect(windows, isNotEmpty);
      expect(windows.map((op) => op.width), everyElement(.25));
      final projections = role('sectionProjection');
      expect(projections, isNotEmpty);
      expect(
        projections.map((op) => op.width),
        everyElement(closeTo(.15, 1e-8)),
      );
      final hatches = role('sectionHatch');
      expect(hatches, isNotEmpty);
      expect(hatches.map((op) => op.width), everyElement(closeTo(.09, 1e-8)));
      expect(hatches.any((op) => op.sources.contains('window')), isFalse);
      expect(hatches.every((op) => !op.fill && op.clip != null), isTrue);
    }
  });

  test(
    'XPS, EPS and stone wool have distinct valid patterns in walls and slabs',
    () {
      final materials = {
        ArchitectMaterial.xps: SlabMaterial.xps,
        ArchitectMaterial.eps: SlabMaterial.floorInsulation,
        ArchitectMaterial.stoneWool: SlabMaterial.mineralWool,
      };
      final patterns = {
        for (final material in materials.entries)
          ArchitectSectionHatch.wall(material.key)!,
      };
      expect(patterns, hasLength(3));
      for (final material in materials.entries) {
        final pattern = ArchitectSectionHatch.wall(material.key)!;
        pattern.validate();
        expect(ArchitectSectionHatch.slab(material.value), pattern);
      }
      expect(ArchitectSectionHatch.slab(SlabMaterial.parquet), isNull);
      expect(ArchitectSectionHatch.slab(SlabMaterial.plasterboard), isNull);
      expect(ArchitectSectionHatch.slab(SlabMaterial.waterproofing), isNull);
    },
  );
}
