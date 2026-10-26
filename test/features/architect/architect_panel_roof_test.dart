import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_roof_settings.dart';
import 'package:kotoview/src/features/architect/rendering/architect_panel_roof_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_drainage_mesh.dart';
import 'package:kotoview/src/features/architect/rendering/architect_special_wall_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_drainage_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_settings_commands.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'architect_special_wall_systems_test.dart' as walls;

ArchitectProject panelRoofProject({
  bool membrane = false,
  bool internal = false,
  double overhang = .5,
  bool hole = false,
}) {
  final spec = ArchitectRoofPanelSpec(
    membrane: membrane,
    minimumSlope: membrane ? 1.2 : 4,
    columnIds: const ['c1', 'c2', 'c3', 'c4'],
  );
  final roof = ArchitectRoofPlane(
    id: 'roof',
    storeyId: 's',
    points: [
      Offset(-overhang, -overhang),
      Offset(6 + overhang, -overhang),
      Offset(6 + overhang, 4 + overhang),
      Offset(-overhang, 4 + overhang),
    ],
    holes: hole
        ? const [
            [Offset(2, 1), Offset(3, 1), Offset(3, 2), Offset(2, 2)],
          ]
        : const [],
    slopeDegrees: membrane ? 2 : 6,
    eavesOverhang: overhang,
    baseElevationOffset: 3,
    attachToWalls: false,
    assembly: ArchitectRoofAssembly.panelRoof(spec),
    drainage: ArchitectRoofDrainage(
      showGutter: true,
      gutterWidth: internal ? .3 : .15,
      gutterDepth: .12,
      position: internal
          ? ArchitectGutterPosition.internal
          : ArchitectGutterPosition.external,
      profile: internal
          ? ArchitectGutterProfile.box
          : ArchitectGutterProfile.halfRound,
      downpipes: const [ArchitectDownpipe(id: 'pipe', offset: 2.5)],
    ),
  );
  final panel = walls
      .special(
        'w',
        ArchitectWallSystemKind.sandwichPanels,
        Offset.zero,
        const Offset(6, 0),
        height: 3,
      )
      .copyWith(followStoreyHeight: true);
  return ArchitectProject(
    id: 'p',
    name: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    activeStoreyId: 's',
    storeys: [
      ArchitectStorey(
        id: 's',
        name: '',
        height: 3,
        roofs: [roof],
        walls: [panel],
        columns: const [
          ArchitectColumn(
            id: 'c1',
            position: Offset.zero,
            width: .3,
            depth: .3,
          ),
          ArchitectColumn(
            id: 'c2',
            position: Offset(6, 0),
            width: .3,
            depth: .3,
          ),
          ArchitectColumn(
            id: 'c3',
            position: Offset(0, 4),
            width: .3,
            depth: .3,
          ),
          ArchitectColumn(
            id: 'c4',
            position: Offset(6, 4),
            width: .3,
            depth: .3,
          ),
        ],
      ),
    ],
  );
}

List<ArchitectPanelRoofComponent> components(ArchitectProject p) =>
    ArchitectPanelRoofGeometry.build(
      p.activeStorey,
      p.activeStorey.roofs.single,
      project: p,
    );
Vector3 at(ArchitectRoofPlane roof, Offset point, double normalDepth) =>
    Vector3(
      point.dx,
      point.dy,
      roof.undersideElevationAt(point) +
          normalDepth / math.cos(roof.slopeRadians),
    );

double? topAt(List<Triangle3D> mesh, Offset p) {
  double? top;
  for (final t in mesh) {
    if ((t.v1 - t.v0).cross(t.v2 - t.v0).z <= 1e-10) continue;
    final a = Offset(t.v0.x, t.v0.y),
        b = Offset(t.v1.x, t.v1.y) - a,
        c = Offset(t.v2.x, t.v2.y) - a,
        d = p - a;
    final det = b.dx * c.dy - b.dy * c.dx;
    if (det.abs() < 1e-12) continue;
    final u = (d.dx * c.dy - d.dy * c.dx) / det,
        v = (b.dx * d.dy - b.dy * d.dx) / det;
    if (u < -1e-7 || v < -1e-7 || u + v > 1.0000001) continue;
    final z = t.v0.z + u * (t.v1.z - t.v0.z) + v * (t.v2.z - t.v0.z);
    top = top == null ? z : math.max(top, z);
  }
  return top;
}

void main() {
  test(
    'a valley keeps an open panel strip with one lower metal trough instead of a ridge cap',
    () {
      final p = panelRoofProject(), r = p.activeStorey.roofs.single;
      final a = r.copyWith(
            id: 'a',
            eavesOverhang: 0,
            points: const [
              Offset(-.5, 0),
              Offset(6.5, 0),
              Offset(6.5, -2),
              Offset(-.5, -2),
            ],
          ),
          b = r.copyWith(
            id: 'b',
            eavesOverhang: 0,
            points: const [
              Offset(6.5, 0),
              Offset(-.5, 0),
              Offset(-.5, 2),
              Offset(6.5, 2),
            ],
          );
      final next = p.copyWith(
            storeys: [
              p.activeStorey.copyWith(roofs: [a, b]),
            ],
          ),
          floor = next.activeStorey;
      final parts = ArchitectPanelRoofGeometry.build(floor, a, project: next);
      expect(parts.where((c) => c.id.startsWith('valley_')), hasLength(4));
      expect(parts.where((c) => c.id.startsWith('joint_')), isEmpty);
      final footprint = ArchitectPanelRoofGeometry.panelFootprint(
        floor,
        a,
        project: next,
      );
      expect(footprint.contains(const Offset(2.5, -.05)), isFalse);
      expect(footprint.contains(const Offset(2.5, -.3)), isTrue);
      expect(
        ArchitectRoofDrainageGeometry.visibleEaves(next, floor, a),
        isEmpty,
      );
      expect(
        parts
            .where((c) => c.id.startsWith('weather_'))
            .any((c) => topAt(c.triangles, const Offset(2.5, -.05)) != null),
        isFalse,
      );
    },
  );
  test(
    'a dedicated roof level resolves selected columns on the lower floor and follows its height',
    () {
      final source = panelRoofProject(),
          base = source.activeStorey.copyWith(
            id: 'base',
            height: 3.5,
            roofs: [],
            walls: [],
          ),
          roof = source.activeStorey.roofs.single.copyWith(attachToWalls: true);
      final top = ArchitectStorey(
        id: 's',
        name: '',
        elevation: 3,
        roofs: [roof],
        columns: const [
          ArchitectColumn(id: 'unrelated', position: Offset(30, 30), height: 8),
        ],
      );
      final controller = ArchitectCommandController(
        source.copyWith(storeys: [base, top]),
      );
      addTearDown(controller.dispose);
      expect(
        controller.project.activeStorey.roofs.single.baseElevationOffset,
        closeTo(.5, 1e-9),
      );
      controller.commit(
        controller.project.copyWith(
          storeys: [base.copyWith(height: 4), controller.project.activeStorey],
        ),
      );
      expect(
        controller.project.activeStorey.roofs.single.baseElevationOffset,
        closeTo(1, 1e-9),
      );
    },
  );
  test(
    'two panel slopes share one folded ridge flashing and retain both weather fields',
    () {
      final p = panelRoofProject(), r = p.activeStorey.roofs.single;
      final a = r.copyWith(
            id: 'a',
            points: const [
              Offset(-.5, -.5),
              Offset(6.5, -.5),
              Offset(6.5, 2),
              Offset(-.5, 2),
            ],
          ),
          b = r.copyWith(
            id: 'b',
            points: const [
              Offset(6.5, 4.5),
              Offset(-.5, 4.5),
              Offset(-.5, 2),
              Offset(6.5, 2),
            ],
          );
      final next = p.copyWith(
            storeys: [
              p.activeStorey.copyWith(roofs: [a, b]),
            ],
          ),
          floor = next.activeStorey;
      final left = ArchitectPanelRoofGeometry.build(floor, a, project: next),
          right = ArchitectPanelRoofGeometry.build(floor, b, project: next);
      expect(left.where((c) => c.id.startsWith('joint_')), hasLength(2));
      expect(right.where((c) => c.id.startsWith('joint_')), isEmpty);
      final mesh = Architect3dBuilder.buildProjectMesh(next);
      for (final y in [1.6, 1.9, 2.1, 2.4]) {
        expect(topAt(mesh.triangles, Offset(2.7, y)), isNotNull);
      }
    },
  );
  test(
    'missing columns retain their IDs and the roof datum until repaired',
    () {
      final source = panelRoofProject(), r = source.activeStorey.roofs.single;
      final controller = ArchitectCommandController(
        source.copyWith(
          storeys: [
            source.activeStorey.copyWith(
              roofs: [r.copyWith(attachToWalls: true)],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final before =
          controller.project.activeStorey.roofs.single.baseElevationOffset;
      controller.commit(
        controller.project.copyWith(
          storeys: [controller.project.activeStorey.copyWith(columns: [])],
        ),
      );
      expect(
        controller.project.activeStorey.roofs.single.assembly.panels!.columnIds,
        hasLength(4),
      );
      expect(
        controller.project.activeStorey.roofs.single.baseElevationOffset,
        before,
      );
    },
  );
  test('flat auto roof chooses a membrane deck and keeps a drainage pitch', () {
    final p = panelRoofProject(),
        roofs = ArchitectRoofGeometry.generateAutoRoof(
          project: p,
          type: AutoRoofType.flat,
          preset: ArchitectRoofPreset.sandwichPitched,
        );
    expect(roofs.single.assembly.panels!.membrane, isTrue);
    expect(
      roofs.single.slopeDegrees,
      greaterThanOrEqualTo(roofs.single.assembly.panels!.minimumSlope),
    );
  });
  test(
    'every panel module retains a continuous outward weather surface in the actual display mesh',
    () {
      final p = panelRoofProject(),
          r = p.activeStorey.roofs.single,
          parts = components(p),
          mesh = Architect3dBuilder.buildProjectMesh(p);
      final weather = [
        for (final c in parts.where((c) => c.id.startsWith('weather_')))
          ...c.triangles,
      ];
      for (var x = -.3; x < 6.35; x += .071) {
        final point = Offset(x, 2.33), body = at(r, point, .55);
        expect(
          parts
              .where((c) => c.id.startsWith('core_'))
              .any((c) => walls.inside(c.triangles, body)),
          isTrue,
          reason: 'Core coverage at $x',
        );
        final expected = topAt(weather, point);
        expect(expected, isNotNull, reason: 'Weather solid coverage at $x');
        expect(
          topAt(mesh.triangles, point),
          closeTo(expected!, 1e-5),
          reason: 'Display coverage at $x',
        );
      }
    },
  );
  test(
    'legacy JSON stays layered and both panel systems round-trip with independent frame depth',
    () {
      final old = ArchitectRoofAssembly.fromPreset(
        ArchitectRoofPreset.warmPitched,
      );
      expect(ArchitectRoofAssembly.fromJson(old.toJson()).panels, isNull);
      expect(old.toJson().containsKey('panels'), isFalse);
      for (final membrane in [false, true]) {
        final p = panelRoofProject(membrane: membrane, internal: true),
            restored = ArchitectProject.fromJson(p.toJson());
        final roof = restored.activeStorey.roofs.single;
        expect(roof.assembly.panels!.thickness, .1);
        expect(roof.assembly.panels!.structureDepth, .5);
        expect(
          roof.assembly.totalThickness,
          closeTo(membrane ? .6015 : .635, 1e-9),
        );
        expect(roof.drainage.position, ArchitectGutterPosition.internal);
        expect(roof.assembly.timber.hasRafters, isFalse);
      }
    },
  );
  test(
    'profiled panels and membrane decks reject insufficient pitch and mansards',
    () {
      const spec = ArchitectRoofPanelSpec();
      expect(() => spec.validate(slope: 0), throwsArgumentError);
      expect(() => spec.validate(slope: 6, mansard: true), throwsArgumentError);
      expect(
        () =>
            spec.copyWith(membrane: true, minimumSlope: 1.2).validate(slope: 2),
        returnsNormally,
      );
      final p = panelRoofProject(),
          roof = p.activeStorey.roofs.single.copyWith(slopeDegrees: 0);
      expect(
        () => UpdateArchitectRoofPlane(storeyId: 's', roof: roof).apply(p),
        throwsArgumentError,
      );
    },
  );
  test(
    'steel I and Z profiles retain air around webs instead of filling the structural depth',
    () {
      final p = panelRoofProject(),
          roof = p.activeStorey.roofs.single,
          parts = components(p);
      final frame = parts.firstWhere((c) => c.id == 'frame_0.5');
      expect(
        walls.inside(frame.triangles, at(roof, const Offset(0, 2), .15)),
        isTrue,
      );
      expect(
        walls.inside(frame.triangles, at(roof, const Offset(.04, 2), .15)),
        isFalse,
      );
      final rail = parts.firstWhere((c) => c.id.startsWith('purlin_'));
      final normal = Vector3(
        -roof.slopeDirection.dx * math.sin(roof.slopeRadians),
        -roof.slopeDirection.dy * math.sin(roof.slopeRadians),
        math.cos(roof.slopeRadians),
      );
      for (final triangle in rail.triangles) {
        final cross = (triangle.v1 - triangle.v0).cross(
          triangle.v2 - triangle.v0,
        );
        if (cross.length < 1e-10) {
          continue;
        }
        final dot = (cross / cross.length).dot(normal).abs();
        expect(
          dot < 1e-4 || dot > 1 - 1e-4,
          isTrue,
          reason: 'The rotated Z section keeps perpendicular webs and flanges',
        );
      }
      final cut = rail.section(const Offset(2, -1), const Offset(0, 1));
      expect(
        cut.getBounds().height,
        closeTo(.2 / math.cos(roof.slopeRadians) + .015, .06),
      );
      expect(parts.any((c) => c.id.startsWith('column_head_')), isTrue);
      final volume = parts.map((c) => walls.volume(c.triangles));
      expect(volume.every((v) => v.isFinite && v > 0), isTrue);
    },
  );
  test('changing panel depth leaves the frame geometry fixed', () {
    final p = panelRoofProject(),
        r = p.activeStorey.roofs.single,
        old = components(p);
    final thick = r.copyWith(
      assembly: ArchitectRoofAssembly.panelRoof(
        r.assembly.panels!.copyWith(thickness: .16),
      ),
    );
    final next = p.copyWith(
          storeys: [
            p.activeStorey.copyWith(roofs: [thick]),
          ],
        ),
        parts = components(next);
    expect(
      thick.topElevationAt(const Offset(2, 2)) -
          r.topElevationAt(const Offset(2, 2)),
      closeTo(.06 / math.cos(r.slopeRadians), 1e-9),
    );
    expect(
      walls.volume(
        parts.firstWhere((c) => c.id.startsWith('frame_')).triangles,
      ),
      closeTo(
        walls.volume(
          old.firstWhere((c) => c.id.startsWith('frame_')).triangles,
        ),
        1e-7,
      ),
    );
  });
  test(
    'eaves cutback retains the outer weather skin while keeping core and liner back',
    () {
      for (final overhang in [0.0, .5]) {
        final p = panelRoofProject(overhang: overhang),
            r = p.activeStorey.roofs.single,
            parts = components(p);
        final point = Offset(1.5 - overhang, -overhang + .02);
        expect(
          parts
              .where((c) => c.id.startsWith('core_'))
              .any((c) => walls.inside(c.triangles, at(r, point, .55))),
          isFalse,
        );
        expect(
          parts
              .where((c) => c.id.startsWith('weather_'))
              .any((c) => walls.inside(c.triangles, at(r, point, .63475))),
          isTrue,
        );
      }
    },
  );
  test('roof openings cut the panel and each intersecting steel member', () {
    final p = panelRoofProject(hole: true),
        r = p.activeStorey.roofs.single,
        parts = components(p);
    for (final z in [.15, .35, .55, .63475]) {
      expect(
        parts.any(
          (c) => walls.inside(c.triangles, at(r, const Offset(2.5, 1.5), z)),
        ),
        isFalse,
      );
    }
    expect(Architect3dBuilder.buildProjectMesh(p).triangles, isNotEmpty);
  });
  test(
    'internal gutter has a real open reserve through panel and membrane',
    () {
      for (final membrane in [false, true]) {
        final p = panelRoofProject(
              membrane: membrane,
              internal: true,
              overhang: 0,
            ),
            r = p.activeStorey.roofs.single;
        final footprint = ArchitectPanelRoofGeometry.panelFootprint(
          p.activeStorey,
          r,
          project: p,
        );
        expect(footprint.contains(const Offset(2.5, .2)), isFalse);
        expect(footprint.contains(const Offset(2.5, 1)), isTrue);
        final parts = components(p);
        expect(
          parts
              .where((c) => !c.structural)
              .any(
                (c) => walls.inside(
                  c.triangles,
                  at(r, const Offset(2.5, .2), .55),
                ),
              ),
          isFalse,
        );
        final g = ArchitectRoofDrainageGeometry.build(p, p.activeStorey, r);
        expect(g.gutters.single.start.dy, closeTo(.2, 1e-9));
        expect(g.routes.single.status, ArchitectDownpipeStatus.ready);
        expect(g.routes.single.points.first.x, g.routes.single.points.last.x);
        expect(g.routes.single.points.first.y, g.routes.single.points.last.y);
        final mesh = ArchitectRoofDrainageMesh.build(
          p,
          p.activeStorey,
          r,
          details: false,
        );
        final cut = ArchitectMeshSection.vertical(
          mesh,
          const Offset(3, -1),
          const Offset(0, 1),
        );
        final top = g.gutters.single.elevation;
        expect(cut.contains(Offset(1.2, top - .04)), isFalse);
        expect(
          cut.contains(Offset(1.2, top - r.drainage.gutterDepth + .0007)),
          isTrue,
        );
      }
    },
  );
  test(
    'internal downpipe reports a column collision instead of passing through it',
    () {
      final p = panelRoofProject(internal: true, overhang: 0),
          floor = p.activeStorey;
      final blocked = floor.copyWith(
        columns: [
          ...floor.columns,
          const ArchitectColumn(
            id: 'blocked',
            position: Offset(2.5, .2),
            width: .2,
            depth: .2,
          ),
        ],
      );
      final next = p.copyWith(storeys: [blocked]);
      expect(
        ArchitectRoofDrainageGeometry.build(
          next,
          blocked,
          blocked.roofs.single,
        ).routes.single.status,
        ArchitectDownpipeStatus.blocked,
      );
    },
  );
  test(
    'wall panel reaches the roof liner and stays outside the steel frame volumes',
    () {
      final p = panelRoofProject(), r = p.activeStorey.roofs.single;
      final wallParts = ArchitectSpecialWallGeometry.build(
            p.activeStorey,
            project: p,
          ),
          roofParts = components(p);
      final xy = const Offset(2.4, .05),
          bottom = ArchitectPanelRoofGeometry.panelUnderside(r, xy);
      expect(
        wallParts.any(
          (c) => walls.inside(c.triangles, Vector3(xy.dx, xy.dy, bottom - .01)),
        ),
        isTrue,
      );
      expect(
        wallParts.any(
          (c) => walls.inside(c.triangles, Vector3(xy.dx, xy.dy, bottom + .01)),
        ),
        isFalse,
      );
      final contact = at(r, const Offset(0, 0), .15);
      expect(roofParts.any((c) => walls.inside(c.triangles, contact)), isTrue);
      expect(wallParts.any((c) => walls.inside(c.triangles, contact)), isFalse);
    },
  );
  test('published sections expose separate panel and steel cut contours', () {
    final p = panelRoofProject();
    final data = ArchitectBuildingSection.build(
      p,
      const ArchitectSection(
        id: 'cut',
        start: Offset(2, -1),
        end: Offset(2, 5),
      ),
    );
    expect(
      data.regions.where((r) => r.sourceId == 'roof').length,
      greaterThan(5),
    );
    final slices = ArchitectRoofGeometry.buildSectionSlices(
      storey: p.activeStorey,
      project: p,
      sectionLine: const ArchitectSection(
        id: 's',
        start: Offset(-1, 2),
        end: Offset(7, 2),
      ),
    );
    expect(
      slices.single.members.any((m) => m.material == ArchitectRoofMaterial.pir),
      isTrue,
    );
    expect(
      slices.single.members
          .where((m) => m.material == ArchitectRoofMaterial.steel)
          .length,
      greaterThan(4),
    );
  });
  test('column IDs and roof heights follow edits once with Undo and Redo', () {
    final source = panelRoofProject(), r = source.activeStorey.roofs.single;
    final p = source.copyWith(
      storeys: [
        source.activeStorey.copyWith(roofs: [r.copyWith(attachToWalls: true)]),
      ],
    );
    final controller = ArchitectCommandController(p);
    addTearDown(controller.dispose);
    final before =
        controller.project.activeStorey.roofs.single.baseElevationOffset;
    final changed = controller.project.copyWith(
      storeys: [
        controller.project.activeStorey.copyWith(
          columns: [
            for (final c in controller.project.activeStorey.columns)
              c.copyWith(height: 3.5),
          ],
        ),
      ],
    );
    controller.commit(changed);
    expect(
      controller.project.activeStorey.roofs.single.baseElevationOffset,
      before + .5,
    );
    controller.undo();
    expect(
      controller.project.activeStorey.roofs.single.baseElevationOffset,
      before,
    );
    controller.redo();
    expect(
      controller.project.activeStorey.roofs.single.baseElevationOffset,
      before + .5,
    );
    expect(
      controller.project.activeStorey.roofs.single.assembly.panels!.columnIds,
      hasLength(4),
    );
  });
  test(
    'roof settings apply gutter position atomically and undo restores the old detail',
    () {
      final p = panelRoofProject(), r = p.activeStorey.roofs.single;
      final controller = ArchitectCommandController(p);
      addTearDown(controller.dispose);
      controller.execute(
        ApplyArchitectRoofSettings(
          storeyId: 's',
          roofId: r.id,
          settings: ArchitectRoofLayersResult(
            assembly: r.assembly,
            slopeDegrees: r.slopeDegrees,
            eavesOverhang: r.eavesOverhang,
            eavesCut: r.eavesCut,
            drainage: r.drainage.copyWith(
              position: ArchitectGutterPosition.internal,
              profile: ArchitectGutterProfile.box,
            ),
            changes: {
              ArchitectRoofSetting.gutterPosition,
              ArchitectRoofSetting.gutterProfile,
            },
          ),
        ),
      );
      expect(
        controller.project.activeStorey.roofs.single.drainage.position,
        ArchitectGutterPosition.internal,
      );
      controller.undo();
      expect(
        controller.project.activeStorey.roofs.single.drainage.position,
        ArchitectGutterPosition.external,
      );
    },
  );
}
