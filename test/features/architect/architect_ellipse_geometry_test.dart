import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_view_drawing.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_scene_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_ellipse_draft.dart';
import 'package:kotoview/src/features/architect/services/architect_ellipse_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_marquee_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_rotation.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';

const _ellipse = ArchitectCadPrimitive(
  id: 'ellipse',
  type: CadPrimitiveType.ellipse,
  startPoint: Offset(10, 20),
  endPoint: Offset(14, 20),
  radiusX: 4,
  radiusY: 1,
  rotationDeg: 30,
);

ArchitectProject _project([ArchitectCadPrimitive primitive = _ellipse]) =>
    ArchitectProject(
      id: 'project',
      name: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      storeys: [
        ArchitectStorey(id: 'floor', name: '', cadPrimitives: [primitive]),
      ],
      activeStoreyId: 'floor',
    );

void _near(Offset actual, Offset expected) =>
    expect((actual - expected).distance, lessThan(1e-6));

void main() {
  test(
    'three picks use independent perpendicular semi-axes and freeze review',
    () {
      final draft = ArchitectEllipseDraft();
      expect(draft.pick(const Offset(10, 20)), isFalse);
      expect(draft.pick(const Offset(13, 24)), isFalse);
      // First axis is (3,4). Third pick includes an arbitrary component along
      // that axis; only its perpendicular component determines the second axis.
      draft.aim(const Offset(12.6, 26.8));
      expect(draft.radiusX, 5);
      expect(draft.radiusY, closeTo(2, 1e-10));
      expect(draft.ready, isFalse);
      expect(draft.pick(const Offset(12.6, 26.8)), isTrue);
      final preview = draft.preview!;
      expect(preview.startPoint, const Offset(10, 20));
      expect(preview.endPoint, const Offset(13, 24));
      expect(preview.radiusX, 5);
      expect(preview.radiusY, closeTo(2, 1e-10));
      expect(
        preview.rotationDeg,
        closeTo(math.atan2(4, 3) * 180 / math.pi, 1e-10),
      );
      draft.aim(const Offset(100, 200));
      draft.pick(const Offset(100, 200));
      expect(draft.preview!.toJson(), preview.toJson());
    },
  );

  test(
    'exact edits change one semi-axis while preserving centre and rotation',
    () {
      final draft = ArchitectEllipseDraft()
        ..pick(const Offset(2, 3))
        ..pick(const Offset(5, 7))
        ..pick(const Offset(-2, 6));
      final original = draft.preview!;
      draft.setRadius(0, 10);
      expect(draft.radiusX, closeTo(10, 1e-10));
      expect(draft.radiusY, original.radiusY);
      expect(draft.preview!.rotationDeg, closeTo(original.rotationDeg!, 1e-10));
      draft.setRadius(1, 7);
      expect(draft.radiusX, closeTo(10, 1e-10));
      expect(draft.radiusY, 7);
      expect(draft.preview!.startPoint, original.startPoint);
      draft.setRadius(0, double.nan);
      draft.setRadius(1, 0);
      expect(draft.radiusX, closeTo(10, 1e-10));
      expect(draft.radiusY, 7);
    },
  );

  test('invalid picks do not complete and cancellation resets the ellipse', () {
    final draft = ArchitectEllipseDraft();
    draft.aim(const Offset(12, 14));
    expect(draft.radiusX, 0);
    expect(draft.direction, const Offset(1, 0));
    draft.pick(const Offset(double.nan, 0));
    expect(draft.center, isNull);
    draft.pick(Offset.zero);
    draft.pick(const Offset(.0001, 0));
    expect(draft.axisEnd, isNull);
    draft.pick(const Offset(5, 0));
    expect(draft.pick(const Offset(8, 0)), isFalse);
    expect(draft.preview, isNull);
    expect(draft.pick(const Offset(8, .001)), isTrue);
    draft.cancel();
    expect(draft.center, isNull);
    expect(draft.axisEnd, isNull);
    expect(draft.cursor, isNull);
    expect(draft.ready, isFalse);
    expect(draft.preview, isNull);
    draft.pick(const Offset(1, 2));
    expect(draft.center, const Offset(1, 2));
  });

  test('legacy JSON keeps the previously visible start-point centre', () {
    final legacy = _ellipse.copyWith(endPoint: const Offset(18, 22));
    final revived = ArchitectCadPrimitive.fromJson(legacy.toJson());
    final geometry = ArchitectEllipseGeometry.fromPrimitive(revived);
    expect(geometry.center, const Offset(10, 20));
    expect(geometry.radiusX, 4);
    expect(geometry.radiusY, 1);
    _near(
      geometry.pointAt(0),
      const Offset(10, 20) + Offset(4 * math.cos(math.pi / 6), 2),
    );
    final fallback = ArchitectCadPrimitive(
      id: 'fallback',
      type: CadPrimitiveType.ellipse,
      startPoint: const Offset(2, 3),
      endPoint: const Offset(5, 7),
    );
    final old = ArchitectEllipseGeometry.fromPrimitive(fallback);
    expect(old.radiusX, 5);
    expect(old.radiusY, 3);
  });

  test('rotated render, bounds, selection, snapping and hit test agree', () {
    final p = _project();
    final geometry = ArchitectEllipseGeometry.fromPrimitive(_ellipse);
    final outline = ArchitectSelection.outline(p, 'ellipse');
    expect(ArchitectSelection.bounds(p, 'ellipse'), geometry.bounds);
    expect(ArchitectSceneGeometry.projectBounds(p), geometry.bounds);
    for (var i = 0; i < 20; i++) {
      final point = geometry.pointAt(i * math.pi / 10);
      expect(geometry.distanceTo(point), lessThan(1e-6));
      expect(
        ArchitectElementTool().hitTestElements(p.activeStorey, point, 1000),
        contains('ellipse'),
      );
      expect(outline.getBounds().inflate(.002).contains(point), isTrue);
    }
    final snaps = ArchitectSnapGeometry.of(p);
    for (final point in [geometry.center, ...geometry.axisPoints]) {
      expect(
        snaps
            .query(point, .001)
            .any(
              (e) => e.owner == 'ellipse' && (e.point - point).distance < .001,
            ),
        isTrue,
      );
    }
    final canvas = ArchitectVectorCanvas();
    ArchitectElementsPainterHelper.drawCadPrimitives(
      canvas: canvas,
      storey: p.activeStorey,
      zoomScale: 100,
    );
    final path = canvas.operations.whereType<ArchitectVectorPath>().single.path;
    _near(path.getBounds().center, geometry.center);
    expect(path.getBounds(), outline.getBounds());
  });

  test(
    'culling and marquee include the curved part outside start/end bounds',
    () {
      final primitive = _ellipse.copyWith(rotationDeg: 0);
      final p = _project(primitive);
      const view = Rect.fromLTRB(5.9, 19.9, 6.1, 20.1);
      expect(
        ArchitectSceneGeometry.visible(
          p,
          view,
          10000,
        ).activeStorey.cadPrimitives,
        hasLength(1),
      );
      final hits = ArchitectMarqueeTool.evaluateSelection(
        storey: p.activeStorey,
        project: p,
        polygon: [
          view.topLeft,
          view.topRight,
          view.bottomRight,
          view.bottomLeft,
        ],
      );
      expect(hits, contains('ellipse'));
      final bounds = ArchitectEllipseGeometry.fromPrimitive(
        primitive,
      ).bounds.inflate(.1);
      expect(
        ArchitectMarqueeTool.evaluateSelection(
          storey: p.activeStorey,
          project: p,
          polygon: [
            bounds.topLeft,
            bounds.topRight,
            bounds.bottomRight,
            bounds.bottomLeft,
          ],
          relation: ArchitectSelectionRelation.contained,
        ),
        contains('ellipse'),
      );
    },
  );

  test(
    'rotation and view reflection preserve independent axes and partial sweep',
    () {
      final source = _ellipse.copyWith(
        isArc: true,
        startAngleDeg: 20,
        endAngleDeg: 150,
      );
      final geometry = ArchitectEllipseGeometry.fromPrimitive(source);
      final rotated = ArchitectRotation.apply(
        _project(source).activeStorey,
        {'ellipse'},
        Offset.zero,
        math.pi / 2,
      ).cadPrimitives.single;
      final rotatedGeometry = ArchitectEllipseGeometry.fromPrimitive(rotated);
      expect(rotated.radiusX, 4);
      expect(rotated.radiusY, 1);
      expect(rotated.rotationDeg, closeTo(120, 1e-8));
      final reflected = ArchitectViewDrawing(
        cadPrimitives: [source],
      ).reflectedHorizontally(30).cadPrimitives.single;
      final reflection = ArchitectEllipseGeometry.fromPrimitive(reflected);
      for (var i = 0; i <= 10; i++) {
        final t = geometry.startAngle + geometry.sweepAngle * i / 10;
        final point = geometry.pointAt(t);
        _near(rotatedGeometry.pointAt(t), Offset(-point.dy, point.dx));
        final reverseT =
            reflection.startAngle + reflection.sweepAngle * (1 - i / 10);
        _near(reflection.pointAt(reverseT), Offset(30 - point.dx, point.dy));
      }
      expect(
        geometry.distanceTo(geometry.pointAt(math.pi * 1.5)),
        greaterThan(.5),
      );
      expect(
        ArchitectElementTool().hitTestElements(
          _project(source).activeStorey,
          geometry.pointAt(math.pi * 1.5),
          1000,
        ),
        isNot(contains('ellipse')),
      );
    },
  );

  test('placement rejects invalid axes and supports undo and save/load', () {
    final empty = _project().updateActiveStorey(
      const ArchitectStorey(id: 'floor', name: ''),
    );
    final controller = ArchitectCommandController(empty);
    for (final invalid in [
      _ellipse.copyWith(radiusX: 0),
      _ellipse.copyWith(radiusY: -1),
      _ellipse.copyWith(radiusX: double.infinity),
      _ellipse.copyWith(rotationDeg: double.nan),
    ]) {
      expect(
        () => controller.execute(
          PlaceArchitectCadPrimitive(storeyId: 'floor', primitive: invalid),
        ),
        throwsArgumentError,
      );
    }
    controller.execute(
      const PlaceArchitectCadPrimitive(storeyId: 'floor', primitive: _ellipse),
    );
    expect(controller.project.activeStorey.cadPrimitives, hasLength(1));
    controller.undo();
    expect(controller.project.activeStorey.cadPrimitives, isEmpty);
    controller.redo();
    final revived = ArchitectProject.fromJson(controller.project.toJson());
    expect(
      revived.activeStorey.cadPrimitives.single.toJson(),
      _ellipse.toJson(),
    );
  });
}
