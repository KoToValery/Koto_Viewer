import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_view_placement.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'architect_stair_detail_test.dart' as stairs;
import 'architect_elevation_test.dart' as elevations;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('third point sets a perpendicular distance and a viewing side', () {
    final view = ArchitectViewPlacement.resolve(
      const Offset(0, 0),
      const Offset(3, 4),
      const Offset(-6.5, 8),
    )!;
    expect(view.side, 1);
    expect(view.depth, closeTo(10, 1e-9));
    final tilted = stairs.project(
      walls: [
        const ArchitectWall(
          id: 'tilted',
          startPoint: Offset.zero,
          endPoint: Offset(3, 4),
        ),
      ],
    );
    final snapped = ArchitectViewPlacement.snapEnd(
      tilted,
      Offset.zero,
      const Offset(-4.04, 3.02),
    );
    expect(snapped.dx * 3 + snapped.dy * 4, closeTo(0, 1e-9));
    expect(
      ArchitectViewPlacement.resolve(
        Offset.zero,
        const Offset(4, 0),
        const Offset(2, 0),
      ),
      isNull,
    );
    expect(
      ArchitectViewPlacement.resolve(
        Offset.zero,
        Offset.zero,
        const Offset(2, 4),
      ),
      isNull,
    );
  });

  test(
    'depth survives serialization, reversal and clearing; legacy is unlimited',
    () {
      const section = ArchitectSection(
        id: 's',
        start: Offset.zero,
        end: Offset(4, 0),
        viewDepth: 7.5,
      );
      expect(
        ArchitectSection.fromJson(section.reversed().toJson()).viewDepth,
        7.5,
      );
      expect(section.copyWith(clearViewDepth: true).viewDepth, isNull);
      expect(
        ArchitectSection.fromJson(
          section.toJson()..remove('viewDepth'),
        ).viewDepth,
        isNull,
      );
      const facade = ArchitectElevation(
        id: 'e',
        start: Offset.zero,
        end: Offset(4, 0),
        viewDepth: 3.5,
      );
      expect(ArchitectElevation.fromJson(facade.toJson()).viewDepth, 3.5);
      expect(facade.copyWith(viewSide: -1).viewDepth, 3.5);
      expect(facade.copyWith(clearViewDepth: true).viewDepth, isNull);
      for (final invalid in [-1, 0, double.infinity, double.nan]) {
        expect(
          ArchitectElevation.fromJson(
            facade.toJson()..['viewDepth'] = invalid,
          ).viewDepth,
          isNull,
        );
      }
    },
  );

  test(
    'facade clips intersecting triangles at the far plane and omits geometry beyond it',
    () {
      const view = ArchitectElevation(
        id: 'e',
        start: Offset(-5, 0),
        end: Offset(5, 0),
        viewDepth: 2,
      );
      final crossing = Triangle3D(
        v0: Vector3(0, 1, 0),
        v1: Vector3(4, 5, 0),
        v2: Vector3(0, 1, 4),
      );
      final beyond = elevations.panel(-4, -2, 4, 0, 3);
      final behind = elevations.panel(-4, -2, -1, 0, 3);
      final data = ArchitectBuildingElevation.fromTriangles(
        [crossing, ...beyond, ...behind],
        view,
        sources: {
          crossing: 'crossing',
          for (final t in beyond) t: 'beyond',
          for (final t in behind) t: 'behind',
        },
      );
      expect(data.elementPaths.keys, ['crossing']);
      expect(
        data.elementPaths['crossing']!.getBounds().right,
        closeTo(1, 1e-6),
      );
      final unlimited = ArchitectBuildingElevation.fromTriangles(
        [crossing, ...beyond],
        view.copyWith(clearViewDepth: true),
        sources: {for (final t in beyond) t: 'beyond'},
      );
      expect(unlimited.elementPaths, contains('beyond'));
    },
  );

  test(
    'return stair flight is visible beyond the cut and respects depth and direction',
    () {
      final stair = stairs.stair(
        stairs.design.copyWith(
          shape: StairShape.halfTurn,
          rise: 3,
          manualRisers: 18,
          manualGoing: .28,
          showRailing: false,
        ),
      );
      final base = stairs.project();
      final project = base.copyWith(
        storeys: [
          base.activeStorey.copyWith(stairs: [stair]),
        ],
      );
      const cut = ArchitectSection(
        id: 'cut',
        start: Offset(-.5, 0),
        end: Offset(4, 0),
        viewDepth: 3,
      );
      final deep = ArchitectBuildingSection.build(project, cut);
      final shallow = ArchitectBuildingSection.build(
        project,
        cut.copyWith(viewDepth: .65),
      );
      final reverse = ArchitectBuildingSection.build(project, cut.reversed());
      expect(deep.regions, isNotEmpty);
      expect(deep.background!.elementPaths, contains(stair.id));
      expect(deep.background!.bounds.bottom, greaterThan(2.9));
      expect(shallow.background!.bounds.bottom, lessThan(1.8));
      expect(reverse.background!.bounds.bottom, lessThan(1.8));
      // Cut material must hide projected geometry and must not change with depth.
      for (final face in deep.background!.faces) {
        for (final region in deep.regions) {
          final overlap = Path.combine(
            PathOperation.intersect,
            face,
            region.path,
          );
          expect(overlap.getBounds().isEmpty, isTrue);
        }
      }
      for (var x = .1; x < cut.length; x += .3) {
        for (var z = .1; z < 3; z += .3) {
          final p = Offset(x, z);
          expect(
            deep.regions.any((r) => r.path.contains(p)),
            shallow.regions.any((r) => r.path.contains(p)),
          );
        }
      }
    },
  );
}
