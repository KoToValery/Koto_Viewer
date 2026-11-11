import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_decorative_element.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_decorative_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_dimension_chain.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_spline_geometry.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';

const _origin = Offset(3, -2);
const _direction = Offset(2, 1);

// Independent reflection matrix for an axis with direction (2, 1).
Offset _reflect(Offset point) {
  final d = point - _origin;
  return _origin + Offset(.6 * d.dx + .8 * d.dy, .8 * d.dx - .6 * d.dy);
}

ArchitectStorey _mirror(ArchitectStorey storey, String id) =>
    ArchitectElementTool()
        .mirrorElementById(storey, id, origin: _origin, direction: _direction)
        .$1;

void _near(Offset actual, Offset expected) =>
    expect((actual - expected).distance, lessThan(1e-7));

Set<String> _meshPoints(List<Triangle3D> mesh, {bool reflect = false}) => {
  for (final t in mesh)
    for (final p in [t.v0, t.v1, t.v2])
      () {
        final xy = reflect ? _reflect(Offset(p.x, p.y)) : Offset(p.x, p.y);
        return '${(xy.dx * 1e6).round()},${(xy.dy * 1e6).round()},${(p.z * 1e6).round()}';
      }(),
};

double _surfaceDistance(Vector3 point, Triangle3D t) {
  final ab = t.v1 - t.v0, ac = t.v2 - t.v0, ap = point - t.v0;
  final aa = ab.dot(ab), bb = ab.dot(ac), cc = ac.dot(ac);
  final denominator = aa * cc - bb * bb;
  if (denominator.abs() > 1e-20) {
    final u = (cc * ap.dot(ab) - bb * ap.dot(ac)) / denominator;
    final v = (aa * ap.dot(ac) - bb * ap.dot(ab)) / denominator;
    if (u >= 0 && v >= 0 && u + v <= 1) {
      return (point - t.v0 - ab * u - ac * v).length;
    }
  }
  return [(t.v0, t.v1), (t.v1, t.v2), (t.v2, t.v0)]
      .map((edge) {
        final d = edge.$2 - edge.$1;
        final ratio = d.lengthSquared < 1e-20
            ? 0.0
            : ((point - edge.$1).dot(d) / d.lengthSquared).clamp(0.0, 1.0);
        return (point - edge.$1 - d * ratio).length;
      })
      .reduce(math.min);
}

void _expectReflectedMesh(List<Triangle3D> actual, List<Triangle3D> source) {
  Vector3 reflect(Vector3 p) {
    final xy = _reflect(Offset(p.x, p.y));
    return Vector3(xy.dx, xy.dy, p.z);
  }

  final expected = [
    for (final t in source)
      Triangle3D(
        v0: reflect(t.v0),
        v1: reflect(t.v1),
        v2: reflect(t.v2),
        color: t.color,
      ),
  ];
  // Extrusion caps can use different triangulations, and eight-sided hinge
  // barrels approximate a circle. Compare the actual surfaces in both ways.
  for (final pair in [(actual, expected), (expected, actual)]) {
    for (final triangle in pair.$1) {
      for (final point in [triangle.v0, triangle.v1, triangle.v2]) {
        final distance = pair.$2
            .where((t) => t.color == triangle.color)
            .map((t) => _surfaceDistance(point, t))
            .reduce(math.min);
        expect(distance, lessThan(.0021));
      }
    }
  }
}

Offset _ellipsePoint(ArchitectCadPrimitive p, double t) {
  final angle = (p.rotationDeg ?? 0) * math.pi / 180;
  final local = Offset(p.radiusX! * math.cos(t), p.radiusY! * math.sin(t));
  return p.startPoint +
      Offset(
        math.cos(angle) * local.dx - math.sin(angle) * local.dy,
        math.sin(angle) * local.dx + math.cos(angle) * local.dy,
      );
}

ArchitectCommandController _controller(ArchitectStorey storey) =>
    ArchitectCommandController(
      ArchitectProject(
        id: 'p',
        name: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: storey.id,
        storeys: [storey],
      ),
    );

void main() {
  for (final type in [CadPrimitiveType.arc, CadPrimitiveType.line]) {
    test('$type reflects every point on a bulged arc', () {
      final arc = ArchitectCadPrimitive(
        id: 'arc',
        type: type,
        startPoint: const Offset(-1, 1),
        endPoint: const Offset(5, 3),
        arcBulge: .7,
      );
      final mirrored = _mirror(
        ArchitectStorey(id: 's', name: '', cadPrimitives: [arc]),
        'arc',
      ).cadPrimitives.single;
      for (var i = 0; i <= 20; i++) {
        _near(
          mirrored.arc!.pointAt(i / 20),
          _reflect(arc.arc!.pointAt(i / 20)),
        );
      }
    });
  }

  for (final closed in [false, true]) {
    test('curved polyline preserves segment order, closed=$closed', () {
      final poly = ArchitectCadPrimitive(
        id: 'poly',
        type: CadPrimitiveType.polyline,
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 3),
        polygon: const [Offset(0, 0), Offset(4, 0), Offset(5, 3)],
        bulges: const [.4, -.2, .3],
        closed: closed,
      );
      final result = _mirror(
        ArchitectStorey(id: 's', name: '', cadPrimitives: [poly]),
        'poly',
      ).cadPrimitives.single;
      expect(result.bulges, [-.4, .2, -.3]);
      for (var i = 0; i < poly.linePoints.length; i++) {
        _near(result.linePoints[i], _reflect(poly.linePoints[i]));
      }
    });
  }

  test('curved slab keeps each bulge attached to the reflected edge', () {
    const slab = ArchitectSlab(
      id: 'slab',
      polygon: [Offset(0, 0), Offset(5, 0), Offset(4, 4), Offset(0, 3)],
      bulges: [.5, -.25, 0, .2],
    );
    final result = _mirror(
      const ArchitectStorey(id: 's', name: '', slabs: [slab]),
      'slab',
    ).slabs.single;
    final expected = slab.tessellatedPolygon.map(_reflect).toList();
    final actual = result.tessellatedPolygon;
    expect(result.area, closeTo(slab.area, 1e-7));
    expect(actual.length, expected.length);
    for (final point in actual) {
      expect(expected.any((p) => (p - point).distance < 1e-7), isTrue);
    }
  });

  test('open spline retains fit-point order and identical reflected curve', () {
    const spline = ArchitectCadPrimitive(
      id: 'spline',
      type: CadPrimitiveType.spline,
      startPoint: Offset(0, 0),
      endPoint: Offset(5, 3),
      polygon: [Offset(0, 0), Offset(1, 3), Offset(3, 1), Offset(5, 3)],
    );
    final result = _mirror(
      const ArchitectStorey(id: 's', name: '', cadPrimitives: [spline]),
      'spline',
    ).cadPrimitives.single;
    final before = ArchitectSplineGeometry.samplePoints(spline.linePoints);
    final after = ArchitectSplineGeometry.samplePoints(result.linePoints);
    expect(after.length, before.length);
    for (var i = 0; i < before.length; i++) {
      _near(after[i], _reflect(before[i]));
    }
  });

  for (final rotation in [0.0, 37.0]) {
    test('ellipse and its partial sweep reflect at rotation $rotation', () {
      final ellipse = ArchitectCadPrimitive(
        id: 'ellipse',
        type: CadPrimitiveType.ellipse,
        startPoint: const Offset(-2, 3),
        endPoint: const Offset(1, 3),
        radiusX: 3,
        radiusY: 1,
        rotationDeg: rotation,
        isArc: true,
        startAngleDeg: 25,
        endAngleDeg: 220,
      );
      final result = _mirror(
        ArchitectStorey(id: 's', name: '', cadPrimitives: [ellipse]),
        'ellipse',
      ).cadPrimitives.single;
      for (var i = 0; i <= 20; i++) {
        final sourceT = (25 + 195 * i / 20) * math.pi / 180;
        final targetT =
            (result.endAngleDeg! +
                (result.startAngleDeg! - result.endAngleDeg!) * i / 20) *
            math.pi /
            180;
        _near(
          _ellipsePoint(result, targetT),
          _reflect(_ellipsePoint(ellipse, sourceT)),
        );
      }
    });
  }

  for (final shape in StairShape.values) {
    test(
      '$shape reflects plan surfaces and walk line, including handedness',
      () {
        final stair = ArchitectStair(
          id: 'stair',
          startPoint: const Offset(2, 4),
          endPoint: const Offset(5, 6),
          design: ArchitectStairDesign(
            shape: shape,
            code: StairCode.geometryOnly,
          ),
        );
        final result = _mirror(
          ArchitectStorey(id: 's', name: '', stairs: [stair]),
          'stair',
        ).stairs.single;
        final before = stair.plan.footprints.expand((p) => p).toList();
        final after = result.plan.footprints.expand((p) => p).toList();
        expect(after.length, before.length);
        for (var i = 0; i < before.length; i++) {
          _near(after[i], _reflect(before[i]));
        }
        for (var i = 0; i < stair.plan.walkingLine.length; i++) {
          _near(
            result.plan.walkingLine[i],
            _reflect(stair.plan.walkingLine[i]),
          );
        }
      },
    );
  }

  test('winder stair reflects every walking-line and nosing point', () {
    final stair = ArchitectStair(
      id: 'stair',
      startPoint: const Offset(2, 4),
      endPoint: const Offset(5, 6),
      design: const ArchitectStairDesign(
        shape: StairShape.quarterTurn,
        code: StairCode.geometryOnly,
        winderSteps: true,
      ),
    );
    final result = _mirror(
      ArchitectStorey(id: 's', name: '', stairs: [stair]),
      'stair',
    ).stairs.single;
    for (var i = 0; i < stair.plan.walkingLine.length; i++) {
      _near(result.plan.walkingLine[i], _reflect(stair.plan.walkingLine[i]));
    }
    for (var i = 0; i < stair.plan.nosings.length; i++) {
      _near(result.plan.nosings[i].$1, _reflect(stair.plan.nosings[i].$1));
      _near(result.plan.nosings[i].$2, _reflect(stair.plan.nosings[i].$2));
    }
  });

  test('two mirrors restore curves and pivot rotation remains exact', () {
    const curve = ArchitectCadPrimitive(
      id: 'curve',
      type: CadPrimitiveType.arc,
      startPoint: Offset(1, 2),
      endPoint: Offset(5, 3),
      arcBulge: -.4,
    );
    const storey = ArchitectStorey(id: 's', name: '', cadPrimitives: [curve]);
    final twice = _mirror(
      _mirror(storey, 'curve'),
      'curve',
    ).cadPrimitives.single;
    final rotated = ArchitectElementTool()
        .rotateElementsByIds(storey, {'curve'}, origin: _origin)
        .cadPrimitives
        .single;
    for (var i = 0; i <= 10; i++) {
      final original = curve.arc!.pointAt(i / 10);
      _near(twice.arc!.pointAt(i / 10), original);
      final d = original - _origin;
      _near(rotated.arc!.pointAt(i / 10), _origin + Offset(-d.dy, d.dx));
    }
  });

  for (final reference in WallReferenceLine.values) {
    test('wall $reference reflects physical faces and core axis', () {
      final wall = ArchitectWall(
        id: 'wall',
        startPoint: const Offset(1, 2),
        endPoint: const Offset(6, 4),
        thickness: .4,
        referenceLine: reference,
        arcBulge: .25,
      );
      final result = _mirror(
        ArchitectStorey(id: 's', name: '', walls: [wall]),
        'wall',
      ).walls.single;
      for (var i = 0; i <= 10; i++) {
        _near(
          result.centerPointAt(i / 10),
          _reflect(wall.centerPointAt(i / 10)),
        );
      }
      _near(result.coreCenterStart, _reflect(wall.coreCenterStart));
      _near(result.coreCenterEnd, _reflect(wall.coreCenterEnd));
    });
  }

  for (final hingeLeft in [false, true]) {
    for (final inward in [false, true]) {
      test('door mesh mirrors hinge=$hingeLeft inward=$inward', () {
        final wall = ArchitectWall(
          id: 'wall',
          startPoint: const Offset(1, 2),
          endPoint: const Offset(6, 4),
          doors: [
            ArchitectDoor(
              id: 'door',
              wallId: 'wall',
              uuid: 'door',
              offsetRatio: .35,
              isHingeLeft: hingeLeft,
              openInward: inward,
              openAngleDeg: 57,
            ),
          ],
        );
        final result = _mirror(
          ArchitectStorey(id: 's', name: '', walls: [wall]),
          'wall',
        ).walls.single;
        List<Triangle3D> mesh(ArchitectWall w) => w.doors.single.build3D(
          wallStart: w.centerStart,
          wallEnd: w.centerEnd,
          wallThickness: w.thickness,
          storeyElevation: 0,
        );
        _expectReflectedMesh(mesh(result), mesh(wall));
      });
    }
  }

  test('decorative asymmetric mesh reflects around an external axis', () {
    const decor = ArchitectDecorativeElement(
      id: 'decor',
      origin: Offset(2, 3),
      frontPolygon: [Offset(0, 0), Offset(2, 0), Offset(.7, 1.5), Offset(0, 1)],
      sidePolygon: [
        Offset(0, 0),
        Offset(.3, 0),
        Offset(.1, 1.5),
        Offset(0, 1.5),
      ],
      normalOffset: .2,
    );
    final result = _mirror(
      const ArchitectStorey(id: 's', name: '', decorativeElements: [decor]),
      'decor',
    ).decorativeElements.single;
    const storey = ArchitectStorey(id: 's', name: '');
    final project = ArchitectProject(
      id: 'p',
      name: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 's',
      storeys: [storey],
    );
    expect(
      _meshPoints(
        ArchitectDecorativeGeometry.buildWorldMesh(project, storey, result),
      ),
      _meshPoints(
        ArchitectDecorativeGeometry.buildWorldMesh(project, storey, decor),
        reflect: true,
      ),
    );
  });

  test(
    'dimension reflects its drawn line and explicit measurement direction',
    () {
      const dim = ArchitectDimension(
        id: 'dim',
        startPoint: Offset(1, 2),
        endPoint: Offset(6, 2),
        direction: Offset(1, 0),
        offsetDistance: .8,
      );
      final result = _mirror(
        const ArchitectStorey(id: 's', name: '', dimensions: [dim]),
        'dim',
      ).dimensions.single;
      _near(result.lineStart, _reflect(dim.lineStart));
      _near(result.lineEnd, _reflect(dim.lineEnd));
    },
  );

  for (final duplicate in [false, true]) {
    for (final includeHost in [false, true]) {
      test(
        'dimension references after mirror copy=$duplicate host=$includeHost',
        () {
          const wall = ArchitectWall(
            id: 'wall',
            startPoint: Offset(1, 2),
            endPoint: Offset(7, 2),
            connectStart: false,
            connectEnd: false,
          );
          final dim = ArchitectDimensionChain.build(
            id: 'dim',
            anchors: ArchitectDimensionChain.wallFaces(
              wall,
              const Offset(4, 2),
            ),
            direction: const Offset(0, 1),
            offset: .8,
          );
          final controller = _controller(
            ArchitectStorey(
              id: 's',
              name: '',
              walls: [wall],
              dimensions: [dim],
            ),
          );
          addTearDown(controller.dispose);
          controller.execute(
            MirrorArchitectElements(
              storeyId: 's',
              elementIds: {'dim', if (includeHost) 'wall'},
              origin: _origin,
              direction: _direction,
              isDuplicate: duplicate,
              idMap: const {'dim': 'dim-copy', 'wall': 'wall-copy'},
            ),
          );
          final result = controller.project.activeStorey.dimensions.last;
          _near(result.lineStart, _reflect(dim.lineStart));
          _near(result.lineEnd, _reflect(dim.lineEnd));
          for (var i = 0; i < dim.anchors.length; i++) {
            _near(result.anchors[i].point, _reflect(dim.anchors[i].point));
            expect(
              result.anchors[i].elementId,
              includeHost ? (duplicate ? 'wall-copy' : 'wall') : isNull,
            );
          }
          if (duplicate) {
            expect(
              controller.project.activeStorey.dimensions.first.toJson(),
              dim.toJson(),
            );
          }
        },
      );
    }
  }

  test(
    'copied dimension tracks the reflected polygon edge after later edits',
    () {
      const slab = ArchitectSlab(
        id: 'slab',
        polygon: [Offset(0, 0), Offset(5, 0), Offset(5, 4), Offset(0, 4)],
      );
      final dim = ArchitectDimensionChain.build(
        id: 'dim',
        anchors: const [
          ArchitectDimensionAnchor(
            point: Offset(1, 0),
            elementId: 'slab',
            feature: 'edgePoint',
            index: 0,
            ratio: .2,
          ),
          ArchitectDimensionAnchor(
            point: Offset(5, 4),
            elementId: 'slab',
            feature: 'vertex',
            index: 2,
          ),
        ],
        direction: const Offset(1, 0),
        offset: .8,
      );
      final controller = _controller(
        ArchitectStorey(id: 's', name: '', slabs: [slab], dimensions: [dim]),
      );
      addTearDown(controller.dispose);
      controller.execute(
        const MirrorArchitectElements(
          storeyId: 's',
          elementIds: {'dim', 'slab'},
          origin: _origin,
          direction: _direction,
          isDuplicate: true,
          idMap: {'dim': 'dim-copy', 'slab': 'slab-copy'},
        ),
      );
      final before = controller.project.activeStorey.dimensions.last;
      for (var i = 0; i < dim.anchors.length; i++) {
        _near(before.anchors[i].point, _reflect(dim.anchors[i].point));
      }
      expect(before.anchors.first.index, 2);
      expect(before.anchors.first.ratio, closeTo(.8, 1e-9));
      controller.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'slab-copy',
          delta: Offset(2, 1),
        ),
      );
      final after = controller.project.activeStorey.dimensions.last;
      for (var i = 0; i < before.anchors.length; i++) {
        _near(
          after.anchors[i].point,
          before.anchors[i].point + const Offset(2, 1),
        );
      }
    },
  );

  test('roof slope arrow and elevations reflect with the roof contour', () {
    final roof = ArchitectRoofPlane(
      id: 'roof',
      storeyId: 's',
      points: [
        const Offset(0, 0),
        const Offset(6, 0),
        const Offset(6, 4),
        const Offset(0, 4),
      ],
      attachToWalls: false,
      slopeArrows: const [
        ArchitectRoofSlopeArrow(
          id: 'arrow',
          roofPlaneId: 'roof',
          position: Offset(3, 2),
        ),
      ],
    );
    final (storey, _) = ArchitectElementTool().mirrorElementById(
      ArchitectStorey(id: 's', name: '', roofs: [roof]),
      'roof',
      origin: _origin,
      direction: _direction,
      isDuplicate: true,
      newId: 'roof-copy',
    );
    final result = storey.roofs.last;
    expect(result.slopeArrows.single.roofPlaneId, 'roof-copy');
    expect(result.slopeArrows.single.id, isNot('arrow'));
    _near(result.slopeArrows.single.position, _reflect(const Offset(3, 2)));
    for (final point in roof.points) {
      expect(
        result.topElevationAt(_reflect(point)),
        closeTo(roof.topElevationAt(point), 1e-9),
      );
    }
  });

  test(
    'mirror copy survives serialization and undo/redo with curved geometry',
    () {
      const arc = ArchitectCadPrimitive(
        id: 'arc',
        type: CadPrimitiveType.arc,
        startPoint: Offset(0, 1),
        endPoint: Offset(5, 3),
        arcBulge: -.6,
      );
      final project = ArchitectProject(
        id: 'p',
        name: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 's',
        storeys: [
          const ArchitectStorey(id: 's', name: '', cadPrimitives: [arc]),
        ],
      );
      final controller = ArchitectCommandController(project);
      addTearDown(controller.dispose);
      controller.execute(
        const MirrorArchitectElements(
          storeyId: 's',
          elementIds: {'arc'},
          origin: _origin,
          direction: _direction,
          isDuplicate: true,
          idMap: {'arc': 'copy'},
        ),
      );
      final after = controller.project.toJson();
      final roundtrip = ArchitectProject.fromJson(
        after,
      ).activeStorey.cadPrimitives.last;
      for (var i = 0; i <= 10; i++) {
        _near(
          roundtrip.arc!.pointAt(i / 10),
          _reflect(arc.arc!.pointAt(i / 10)),
        );
      }
      controller.undo();
      expect(controller.project.activeStorey.cadPrimitives, hasLength(1));
      controller.redo();
      expect(controller.project.toJson(), after);
    },
  );
}
