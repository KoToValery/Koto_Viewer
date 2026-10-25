import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_section_visibility.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'architect_roof_drainage_test.dart' as fixture;

const gutters = ArchitectSectionCategory.gutters;
const pipes = ArchitectSectionCategory.downpipes;
const cutOnly = ArchitectSectionDisplay.cutOnly;
const full = ArchitectSectionDisplay.cutAndProjection;
const hidden = ArchitectSectionDisplay.hidden;
const front = ArchitectSection(
  id: 'front',
  start: Offset(-1, -1),
  end: Offset(7, -1),
);
const throughPipe = ArchitectSection(
  id: 'pipe-cut',
  start: Offset(2, -1),
  end: Offset(2, 5),
);

ArchitectSectionVisibility rules(ArchitectSectionDisplay mode) =>
    ArchitectSectionVisibility(categories: {gutters: mode, pipes: mode});

Iterable<ArchitectSectionRegion> drainage(ArchitectBuildingSection section) =>
    section.regions.where(
      (r) =>
          r.sourceId == 'roof' &&
          !r.roof &&
          r.customFillColor == const Color(0xffeeeeee),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unspecified rules show cut and visible projection; explicit rules persist',
    () {
      final legacy = fixture.drainageProject().toJson()
        ..remove('sectionVisibility');
      final old = ArchitectProject.fromJson(legacy);
      expect(old.sectionVisibility.modeFor(gutters), full);
      expect(old.sectionVisibility.modeFor(pipes), full);
      final p = old.copyWith(
        sectionVisibility: rules(full),
        sections: [
          front.copyWith(
            visibility: const ArchitectSectionVisibility().withMode(
              pipes,
              hidden,
            ),
          ),
        ],
      );
      final restored = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(p.toJson())),
      );
      final cut = restored.sections.single;
      expect(
        cut.visibility.modeFor(gutters, defaults: restored.sectionVisibility),
        full,
      );
      expect(
        cut.visibility.modeFor(pipes, defaults: restored.sectionVisibility),
        hidden,
      );
      expect(cut.reversed().visibility.categories, cut.visibility.categories);
      expect(
        cut.copyWith(name: 'A').visibility.categories,
        cut.visibility.categories,
      );
      final inherited = cut.visibility.withMode(pipes, null);
      expect(inherited.categories, isEmpty);
      expect(
        inherited.modeFor(pipes, defaults: restored.sectionVisibility),
        full,
      );
      final future = ArchitectSectionVisibility.fromJson({
        'gutters': 'futureMode',
        'futureCategory': 'hidden',
        'downpipes': 'hidden',
      });
      expect(future.modeFor(gutters), full);
      expect(future.modeFor(pipes), hidden);
    },
  );

  test(
    'cut only removes background drainage without leaving wall occlusion holes',
    () {
      final p = fixture.drainageProject().copyWith(
        sectionVisibility: rules(cutOnly),
      );
      final cut = ArchitectBuildingSection.build(p, front);
      expect(drainage(cut), isEmpty);
      final s = p.activeStorey, roof = s.roofs.single;
      final noDrainage = p.copyWith(
        storeys: [
          s.copyWith(
            roofs: [
              roof.copyWith(
                drainage: roof.drainage.copyWith(
                  showGutter: false,
                  showDownpipes: false,
                ),
              ),
            ],
          ),
        ],
      );
      final bare = ArchitectBuildingSection.build(noDrainage, front);
      final wall = cut.background!.elementPaths['facade']!;
      final bareWall = bare.background!.elementPaths['facade']!;
      // Sample the pipe's projected centre and the rest of the wall. Omitting
      // only its linework after hidden-surface removal would fail this check.
      for (final x in [1.5, 3.0, 4.5, 6.5]) {
        for (final z in [1.0, 2.0, 4.0, 6.0]) {
          expect(wall.contains(Offset(x, z)), bareWall.contains(Offset(x, z)));
        }
      }
      expect(wall.contains(const Offset(3, 2)), isTrue);
      final projected = ArchitectBuildingSection.build(
        p,
        front.copyWith(visibility: rules(full)),
      );
      expect(
        projected.background!.elementPaths['facade']!.contains(
          const Offset(3, 2),
        ),
        isFalse,
      );
    },
  );

  test('actual longitudinal pipe section stays intact, hidden removes it', () {
    final p = fixture.drainageProject();
    final normal = drainage(ArchitectBuildingSection.build(p, throughPipe));
    final projected = drainage(
      ArchitectBuildingSection.build(
        p,
        throughPipe.copyWith(visibility: rules(full)),
      ),
    );
    expect(normal, isNotEmpty);
    expect(normal.first.path.getBounds().height, greaterThan(6));
    expect(
      normal.map((r) => r.path.getBounds()),
      projected.map((r) => r.path.getBounds()),
    );
    final noPipes = drainage(
      ArchitectBuildingSection.build(
        p,
        throughPipe.copyWith(
          visibility: const ArchitectSectionVisibility().withMode(
            pipes,
            hidden,
          ),
        ),
      ),
    );
    expect(noPipes, isNotEmpty); // The intersected gutter is still drawn.
    expect(noPipes.first.path.getBounds().height, lessThan(.5));
    final noGutters = drainage(
      ArchitectBuildingSection.build(
        p,
        throughPipe.copyWith(
          visibility: const ArchitectSectionVisibility().withMode(
            gutters,
            hidden,
          ),
        ),
      ),
    );
    expect(noGutters.first.path.getBounds().height, greaterThan(6));
    final centre = fixture.route(p).points.last.y - throughPipe.start.dy;
    expect(noGutters.first.path.contains(Offset(centre, 2)), isFalse);
    expect(
      noGutters.first.path.contains(Offset(centre + .05 - .00075, 2)),
      isTrue,
    );
    expect(
      drainage(
        ArchitectBuildingSection.build(
          p,
          throughPipe.copyWith(visibility: rules(hidden)),
        ),
      ),
      isEmpty,
    );
  });

  test('project rules apply across sections; view overrides stay local', () {
    final p = fixture.drainageProject().copyWith(
      sectionVisibility: rules(hidden),
    );
    expect(drainage(ArchitectBuildingSection.build(p, throughPipe)), isEmpty);
    final override = throughPipe.copyWith(
      visibility: const ArchitectSectionVisibility().withMode(pipes, cutOnly),
    );
    expect(
      drainage(
        ArchitectBuildingSection.build(p, override),
      ).first.path.getBounds().height,
      greaterThan(6),
    );
    expect(drainage(ArchitectBuildingSection.build(p, throughPipe)), isEmpty);
  });

  test(
    'pipe-only cut and projection remain valid when the gutter is hidden',
    () {
      final model = ArchitectCommandController(
        fixture.drainageProject().copyWith(
          sectionVisibility: const ArchitectSectionVisibility(
            categories: {gutters: hidden},
          ),
        ),
      );
      addTearDown(model.dispose);
      final p = model.project;
      final section = ArchitectBuildingSection.build(
        p,
        throughPipe.copyWith(
          visibility: const ArchitectSectionVisibility(
            categories: {pipes: full},
          ),
        ),
      );
      expect(section.elementPaths, contains('roof'));
      expect(section.drawingRegions, isNotEmpty);
      expect(drainage(section).single.path.getBounds().height, greaterThan(6));
    },
  );

  test('stepped sections preserve category rules and far clipping', () {
    final p = fixture.drainageProject().copyWith(
      sectionVisibility: rules(cutOnly),
    );
    final cut = front.copyWith(steps: const [Offset(4, .1)], viewDepth: 10);
    final normal = ArchitectBuildingSection.build(p, cut);
    final projected = ArchitectBuildingSection.build(
      p,
      cut.copyWith(visibility: rules(full)),
    );
    expect(
      normal.background!.elementPaths['facade']!.contains(const Offset(3, 2)),
      isTrue,
    );
    expect(
      projected.background!.elementPaths['facade']!.contains(
        const Offset(3, 2),
      ),
      isFalse,
    );
    final shallow = ArchitectBuildingSection.build(
      p,
      cut.copyWith(viewDepth: .2, visibility: rules(full)),
    );
    expect(shallow.background!.elementPaths.containsKey('roof'), isFalse);
    expect(shallow.background!.elementPaths.containsKey('facade'), isFalse);
  });

  test('3D and facades ignore section-only visibility settings', () {
    final original = fixture.drainageProject();
    final p = original.copyWith(sectionVisibility: rules(hidden));
    expect(
      Architect3dBuilder.buildProjectMesh(p).triangles.length,
      Architect3dBuilder.buildProjectMesh(original).triangles.length,
    );
    const facade = ArchitectElevation(
      id: 'e',
      start: Offset(8, -1),
      end: Offset(8, 5),
    );
    final geometry = ArchitectBuildingElevation.build(p, facade);
    expect(geometry.elementPaths['roof']!.getBounds().height, greaterThan(6));
    expect(
      geometry.elementPaths['roof']!.getBounds(),
      ArchitectBuildingElevation.build(
        original,
        facade,
      ).elementPaths['roof']!.getBounds(),
    );
  });

  test(
    'published section uses the same cut rules and refreshes after a change',
    () {
      final p = fixture.drainageProject().copyWith(
        sections: const [throughPipe],
      );
      const drawing = ArchitectSavedDrawing(
        id: 'drawing',
        sourceId: 'pipe-cut',
        kind: ArchitectDrawingKind.section,
      );
      final l = lookupAppLocalizations(const Locale('en'));
      Iterable<ArchitectVectorPath> pipeContours(ArchitectProject project) =>
          ArchitectDrawingPublisher.build(
            project,
            drawing,
            100,
            l,
          ).operations.whereType<ArchitectVectorPath>().where(
            (op) =>
                op.role == 'sectionRegion' &&
                op.sources.contains('roof') &&
                op.path.getBounds().height > 60,
          );
      expect(pipeContours(p), isNotEmpty);
      final hiddenProject = p.copyWith(sectionVisibility: rules(hidden));
      expect(pipeContours(hiddenProject), isEmpty);
      final overridden = hiddenProject.copyWith(
        sections: [
          throughPipe.copyWith(
            visibility: const ArchitectSectionVisibility().withMode(
              pipes,
              cutOnly,
            ),
          ),
        ],
      );
      expect(pipeContours(overridden), isNotEmpty);
    },
  );
}
