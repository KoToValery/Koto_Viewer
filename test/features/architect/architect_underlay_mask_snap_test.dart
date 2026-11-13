import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'package:kotoview/src/features/architect/services/architect_drag_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_underlay_clip.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_endpoint_snap.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';

const _mask = [Offset(0, 0), Offset(5, 0), Offset(5, 6), Offset(0, 6)];

ArchitectProject _project({
  List<Offset> mask = _mask,
  List<ArchitectCadPrimitive> lines = const [],
}) => ArchitectProject(
  id: 'project',
  name: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [ArchitectStorey(id: 's', name: '', cadPrimitives: lines)],
  cadUnderlays: {
    's': ArchitectCadUnderlayConfig(
      storeyId: 's',
      fileName: 'plan.dxf',
      internalCopyPath: '',
      maskPolygon: mask,
    ),
  },
);

DxfDocument _document(List<DxfEntity> entities) => DxfDocument(
  layers: {},
  blocks: {},
  entities: entities,
  headerVars: {},
  bounds: const Rect.fromLTRB(-10, -10, 10, 10),
  entityStats: {},
);

void main() {
  test('concave crop keeps each visible piece and includes its boundary', () {
    const mask = [
      Offset(0, 0),
      Offset(6, 0),
      Offset(6, 6),
      Offset(4, 6),
      Offset(4, 2),
      Offset(2, 2),
      Offset(2, 6),
      Offset(0, 6),
    ];
    final pieces = ArchitectUnderlayClip.segments([
      (const Offset(-1, 3), const Offset(7, 3)),
    ], mask).toList();
    expect(pieces, [
      (const Offset(0, 3), const Offset(2, 3)),
      (const Offset(4, 3), const Offset(6, 3)),
    ]);
    expect(ArchitectUnderlayClip.contains(mask, const Offset(4, 3)), isTrue);
    expect(ArchitectUnderlayClip.contains(mask, const Offset(3, 3)), isFalse);
  });
  test(
    'shared and wall snaps use visible edge pieces and their crop endpoints',
    () {
      final p = _project();
      const frame = BimCoordinateFrame(
        origin: Offset(1000, 2000),
        unitsPerMeter: 1000,
      );
      final doc = _document([
        DxfLine(
          p1: frame.toCad(const Offset(-2, 2)),
          p2: frame.toCad(const Offset(8, 2)),
        ),
      ]);
      for (final raw in [const Offset(4.97, 2.02), const Offset(7, 2.02)]) {
        final snap = ArchitectSnapHelper.snapFree(
          rawPoint: raw,
          project: p,
          tolerance: .1,
          underlay: doc,
          frame: frame,
        );
        final wallSnap = ArchitectWallSnap.resolve(
          raw: raw,
          project: p,
          scale: 140,
          underlay: doc,
          frame: frame,
        );
        if (raw.dx < 5) {
          expect(snap.point, const Offset(5, 2));
          expect(wallSnap.point, const Offset(5, 2));
        } else {
          expect(snap.isSnapped, isFalse);
          expect(wallSnap.isSnapped, isFalse);
        }
      }
    },
  );

  test(
    'cropped underlay extensions cannot create an apparent crossing outside mask',
    () {
      final p = _project(
        lines: const [
          ArchitectCadPrimitive(
            id: 'native',
            type: CadPrimitiveType.line,
            startPoint: Offset(7, 0),
            endPoint: Offset(7, 4),
          ),
        ],
      );
      final doc = _document(const [
        DxfLine(p1: Offset(1, 5), p2: Offset(4, 5)),
      ]);
      final snap = ArchitectSnapHelper.snapFree(
        rawPoint: const Offset(7.01, 5.01),
        project: p,
        tolerance: .1,
        underlay: doc,
      );
      expect(snap.isSnapped, isFalse);
      final native = p.updateActiveStorey(
        p.activeStorey.copyWith(
          cadPrimitives: [
            ...p.activeStorey.cadPrimitives,
            const ArchitectCadPrimitive(
              id: 'native-horizontal',
              type: CadPrimitiveType.line,
              startPoint: Offset(1, 5),
              endPoint: Offset(4, 5),
            ),
          ],
        ),
      );
      final nativeSnap = ArchitectSnapHelper.snapFree(
        rawPoint: const Offset(7.01, 5.01),
        project: native,
        tolerance: .1,
      );
      expect(nativeSnap.isSnapped, isTrue);
      expect(nativeSnap.point, const Offset(7, 5));
    },
  );

  test(
    'angle-locked wall endpoints intersect visible underlay portions only',
    () {
      const wall = ArchitectWall(
        id: 'edited',
        startPoint: Offset(0, 2),
        endPoint: Offset(10, 2),
      );
      final doc = _document(const [
        DxfLine(p1: Offset(3, -2), p2: Offset(3, 8)),
        DxfLine(p1: Offset(7, -2), p2: Offset(7, 8)),
      ]);
      final p = _project();
      final visible = ArchitectWallEndpointSnap.resolve(
        wall: wall,
        atStart: false,
        raw: const Offset(3.02, 2.03),
        snapProject: p,
        scale: 140,
        angleLocked: true,
        underlay: doc,
      );
      expect(visible.point, const Offset(3, 2));
      expect(visible.snapLabel, 'Intersection');
      final hidden = ArchitectWallEndpointSnap.resolve(
        wall: wall,
        atStart: false,
        raw: const Offset(7.02, 2.03),
        snapProject: p,
        scale: 140,
        angleLocked: true,
        underlay: doc,
      );
      expect(hidden.snapLabel, isNot('Intersection'));
    },
  );

  test(
    'DXF filter removes hidden candidates before nearest intersection wins',
    () {
      final doc = _document(const [
        DxfLine(p1: Offset(-1, 0), p2: Offset(1, 0)),
        DxfLine(p1: Offset(-.1, -1), p2: Offset(-.1, 1)),
        DxfLine(p1: Offset(.1, -1), p2: Offset(.1, 1)),
      ]);
      final result = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(.08, 0),
        toleranceCad: .3,
        includeIntersections: true,
        pointFilter: (p) => p.dx <= 0,
      );
      expect((result!.point - const Offset(-.1, 0)).distance, lessThan(1e-9));
      expect(result.type, DxfSnapType.intersection);
    },
  );

  test('CAD base dragging ignores cropped origin and centre', () {
    final p = _project(
      mask: const [Offset(2, 2), Offset(4, 2), Offset(4, 4), Offset(2, 4)],
    );
    final drag = ArchitectDragController()
      ..startDrag(isUnderlay: true, isCadUnderlay: true);
    final doc = _document(const []);
    drag.updateBaseHover(Offset.zero, project: p, dxfDoc: doc, scale: 100);
    expect(drag.isSnapped, isFalse);
    drag.dispose();
  });

  test(
    'raster base dragging filters corners, centre and clipped edge pieces',
    () {
      const raster = ArchitectRasterUnderlay(
        id: 'raster',
        storeyId: 's',
        fileName: '',
        internalImagePath: '',
        imageWidthPx: 100,
        imageHeightPx: 100,
        metersPerPixel: .1,
        maskPolygon: [Offset(2, 0), Offset(4, 0), Offset(4, 2), Offset(2, 2)],
      );
      final drag = ArchitectDragController()
        ..startDrag(isUnderlay: true, rasterId: 'raster');
      final p = _project();
      drag.updateBaseHover(
        const Offset(.01, .01),
        project: p,
        raster: raster,
        scale: 100,
      );
      expect(drag.isSnapped, isFalse);
      drag.updateBaseHover(
        const Offset(3.01, .01),
        project: p,
        raster: raster,
        scale: 100,
      );
      expect(drag.isSnapped, isTrue);
      expect(drag.currentPointModel, const Offset(3, 0));
      drag.updateBaseHover(
        const Offset(5.01, 5.01),
        project: p,
        raster: raster,
        scale: 100,
      );
      expect(drag.isSnapped, isFalse);
      drag.dispose();
    },
  );
}
