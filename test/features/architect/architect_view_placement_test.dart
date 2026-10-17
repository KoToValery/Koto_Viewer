import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_view_placement.dart';
import 'architect_slab_assembly_test.dart' as fixture;
import 'architect_stair_detail_test.dart' as stairs;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const wall = ArchitectWall(
    id: 'w',
    startPoint: Offset.zero,
    endPoint: Offset(8, 0),
  );
  final project = fixture.slabProject(walls: [wall]);
  const bounds = Rect.fromLTRB(-3, -3, 11, 7);
  test(
    'first point immediately has a nonzero line and perpendicular target guide',
    () {
      final draft = ArchitectViewPlacement.preview(
        project,
        bounds,
        const Offset(-1, -2),
        null,
        null,
      );
      expect((draft.end - draft.start).distance, greaterThan(1));
      expect(draft.axis.dy, closeTo(0, 1e-8));
      expect(draft.wall?.id, 'w');
      expect(draft.target!.dy, closeTo(0, 1e-8));
      expect(
        draft.axis.dx * draft.direction.dx + draft.axis.dy * draft.direction.dy,
        closeTo(0, 1e-8),
      );
    },
  );
  test(
    'live end snaps to a wall axis and direction picks only a parallel wall ahead',
    () {
      final draft = ArchitectViewPlacement.preview(
        project,
        bounds,
        const Offset(-1, -2),
        null,
        const Offset(9, -1.9),
      );
      expect(draft.end.dy, -2);
      expect(draft.aligned, isTrue);
      final toward = ArchitectViewPlacement.preview(
        project,
        bounds,
        draft.start,
        draft.end,
        const Offset(4, 1),
      );
      expect(toward.direction, const Offset(0, 1));
      expect(toward.target, const Offset(4, 0));
      final away = ArchitectViewPlacement.preview(
        project,
        bounds,
        draft.start,
        draft.end,
        const Offset(4, -4),
      );
      expect(away.direction, const Offset(0, -1));
      expect(away.target, isNull);
    },
  );
  test('start point snaps to actual stair anchors', () {
    final project = stairs.project();
    final centre = project.activeStorey.stairs.single.displayBounds.center;
    expect(
      ArchitectViewPlacement.snapStart(
        project,
        centre + const Offset(.01, .01),
        .1,
      ),
      centre,
    );
  });
  test(
    'reversing a section mirrors geometry and preserves world detail associations and legacy JSON',
    () {
      final cut = fixture.cut.copyWith(
        details: [
          const ArchitectSlabDetail(
            id: 'd',
            slabId: 'slab',
            station: 2,
            textOffset: Offset(1, 1),
          ),
        ],
      );
      final reverse = cut.reversed();
      expect(reverse.viewDirection, -cut.viewDirection);
      expect(
        reverse.pointAt(reverse.details.single.station),
        cut.pointAt(cut.details.single.station),
      );
      expect(reverse.details.single.textOffset, const Offset(-1, 1));
      expect(reverse.reversed().toJson(), cut.toJson());
      final restored = ArchitectSection.fromJson(reverse.toJson());
      expect(restored.viewDirection, reverse.viewDirection);
      expect(
        ArchitectBuildingSection.source(
          fixture.slabProject(),
          reverse,
          reverse.details.single,
        )?.slab.id,
        'slab',
      );

      final stairProject = stairs.project();
      const stairCut = ArchitectSection(
        id: 'stair',
        start: Offset(-1, 0),
        end: Offset(4, 0),
      );
      final before = ArchitectBuildingSection.build(stairProject, stairCut);
      final after = ArchitectBuildingSection.build(
        stairProject,
        stairCut.reversed(),
      );
      expect(before.regions, isNotEmpty);
      for (var x = .1; x < stairCut.length; x += .2) {
        for (var z = .1; z < 1.6; z += .2) {
          final original = before.regions.any(
            (r) => r.path.contains(Offset(x, z)),
          );
          final mirrored = after.regions.any(
            (r) => r.path.contains(Offset(stairCut.length - x, z)),
          );
          expect(mirrored, original, reason: '$x, $z');
        }
      }
    },
  );
}
