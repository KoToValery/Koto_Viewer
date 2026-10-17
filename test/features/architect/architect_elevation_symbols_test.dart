import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_fenestration_style.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_elevation_symbols.dart';
import 'architect_elevation_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ArchitectProject windowProject({
    ArchitectFenestrationStyle? style,
    int panes = 2,
  }) {
    final p = fixture.elevationProject();
    final wall = p.activeStorey.walls.first;
    return p.copyWith(
      storeys: [
        p.activeStorey.copyWith(
          walls: [
            wall.copyWith(
              doors: [],
              windows: [
                wall.windows.first.copyWith(style: style, panesCount: panes),
              ],
            ),
          ],
        ),
      ],
    );
  }

  test(
    'legacy fixed windows have no operation symbol; casements and doors do',
    () {
      expect(
        ArchitectElevationOperation.build(
          windowProject(panes: 1),
          fixture.facade,
        ),
        isEmpty,
      );
      final doubleSash = ArchitectElevationOperation.build(
        windowProject(),
        fixture.facade,
      ).single;
      expect(doubleSash.lines.computeMetrics().length, 2);
      final geometry = ArchitectBuildingElevation.build(
        fixture.elevationProject(),
        fixture.facade,
      );
      expect(geometry.operations.length, 6);
    },
  );
  test(
    'operation follows every pane type and recursive transom subdivisions',
    () {
      for (final type in PaneType.values) {
        final style = ArchitectFenestrationStyle(
          id: 'test',
          name: '',
          rootSubdivision: FenestrationSubdivision(
            id: 'root',
            pane: FenestrationPane(id: 'pane', paneType: type),
          ),
        );
        final symbols = ArchitectElevationOperation.build(
          windowProject(style: style),
          fixture.facade,
        );
        final count = switch (type) {
          PaneType.fixedGlazing || PaneType.solidPanel => 0,
          PaneType.tiltAndTurn => 2,
          _ => 1,
        };
        expect(
          symbols.isEmpty ? 0 : symbols.single.lines.computeMetrics().length,
          count,
          reason: type.name,
        );
      }
      const style = ArchitectFenestrationStyle(
        id: 'mixed',
        name: '',
        rootSubdivision: FenestrationSubdivision(
          id: 'root',
          isSplit: true,
          isVertical: false,
          ratios: [.7, .3],
          children: [
            FenestrationSubdivision(
              id: 'bottom',
              pane: FenestrationPane(id: 'fixed'),
            ),
            FenestrationSubdivision(
              id: 'top',
              pane: FenestrationPane(
                id: 'hopper',
                paneType: PaneType.topHopper,
              ),
            ),
          ],
        ),
      );
      final symbol = ArchitectElevationOperation.build(
        windowProject(style: style),
        fixture.facade,
      ).single;
      final points = symbol.lines.computeMetrics().single;
      expect(points.getTangentForOffset(0)!.position.dy, greaterThan(1.8));
      expect(
        points.getTangentForOffset(points.length / 2)!.position.dy,
        greaterThan(2.1),
      );
    },
  );
  test('hinge indication mirrors when viewing the opposite wall side', () {
    final p = fixture.elevationProject();
    final front = ArchitectElevationOperation.build(
      p,
      fixture.facade,
    ).singleWhere((s) => s.id == 'd');
    const back = ArchitectElevation(
      id: 'back',
      start: Offset(9, 7),
      end: Offset(-1, 7),
    );
    final rear = ArchitectElevationOperation.build(
      p,
      back,
    ).singleWhere((s) => s.id == 'd');
    final a = front.lines.computeMetrics().single,
        b = rear.lines.computeMetrics().single;
    expect(
      a.getTangentForOffset(0)!.position.dx,
      closeTo(-b.getTangentForOffset(0)!.position.dx, 1e-6),
    );
    expect(
      a.getTangentForOffset(a.length / 2)!.position.dx,
      closeTo(-b.getTangentForOffset(b.length / 2)!.position.dx, 1e-6),
    );
  });
  test(
    'foreground solids hide operation marks instead of drawing through them',
    () {
      final p = windowProject();
      final wall = p.activeStorey.walls.single;
      final blocked = p.updateActiveStorey(
        p.activeStorey.copyWith(
          walls: [
            wall,
            const ArchitectWall(
              id: 'screen',
              startPoint: Offset(0, -1),
              endPoint: Offset(3, -1),
              height: 3,
            ),
          ],
        ),
      );
      expect(
        ArchitectBuildingElevation.build(blocked, fixture.facade).operations,
        isEmpty,
      );
      final half = p.updateActiveStorey(
        p.activeStorey.copyWith(
          walls: [
            wall,
            const ArchitectWall(
              id: 'screen',
              startPoint: Offset(0, -1),
              endPoint: Offset(1.6, -1),
              height: 3,
            ),
          ],
        ),
      );
      final clip = ArchitectBuildingElevation.build(
        half,
        fixture.facade,
      ).operations.single.clip;
      expect(clip.contains(const Offset(-2.7, 1.5)), isFalse);
      expect(clip.contains(const Offset(-2.0, 1.5)), isTrue);
    },
  );
  test(
    'roof arrows carry actual slope, point downhill and omit hidden/flat roofs',
    () {
      final p = fixture.elevationProject();
      ArchitectRoofPlane roof(
        String id,
        double base, {
        double slope = 30,
        bool reverse = false,
      }) => ArchitectRoofPlane(
        id: id,
        storeyId: 's1',
        points: [
          const Offset(-.5, -.5),
          const Offset(8.5, -.5),
          const Offset(8.5, 5.5),
          const Offset(-.5, 5.5),
        ],
        slopeDegrees: slope,
        eavesEdgeIndex: 1,
        baseElevationOffset: base,
        attachToWalls: false,
        reverseSlope: reverse,
      );
      ArchitectBuildingElevation geometry(List<ArchitectRoofPlane> roofs) =>
          ArchitectBuildingElevation.build(
            p.copyWith(
              storeys: [
                p.storeys.first,
                p.storeys.last.copyWith(roofs: roofs),
              ],
            ),
            fixture.facade,
          );
      final a = geometry([roof('r', 3)]).slopes.single;
      expect(a.percent, closeTo(math.tan(math.pi / 6) * 100, 1e-6));
      expect(a.end.dy, lessThan(a.start.dy));
      final b = geometry([roof('r', 3, reverse: true)]).slopes.single;
      expect((a.end - a.start).dx * (b.end - b.start).dx, lessThan(0));
      expect(geometry([roof('r', 3, slope: 0)]).slopes, isEmpty);
      expect(
        geometry([
          roof('r', 3),
          roof('hidden', -1).copyWith(
            points: [
              const Offset(2, 2),
              const Offset(3, 2),
              const Offset(3, 3),
              const Offset(2, 3),
            ],
          ),
        ]).slopes.map((s) => s.id),
        ['r'],
      );
    },
  );
}
