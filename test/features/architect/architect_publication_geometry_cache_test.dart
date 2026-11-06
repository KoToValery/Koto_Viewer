import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';

ArchitectProject _model() => ArchitectProject(
  id: 'physical-cache',
  name: 'Geometry cache',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [
    ArchitectStorey(
      id: 's',
      name: 'Storey',
      walls: const [
        ArchitectWall(
          id: 'wall',
          startPoint: Offset.zero,
          endPoint: Offset(6, 0),
        ),
        ArchitectWall(
          id: 'return',
          startPoint: Offset(6, 0),
          endPoint: Offset(6, 5),
        ),
      ],
    ),
  ],
  sections: const [
    ArchitectSection(id: 'cut', start: Offset(2, -1), end: Offset(2, 6)),
  ],
  elevations: const [
    ArchitectElevation(id: 'facade', start: Offset(-1, -2), end: Offset(7, -2)),
  ],
);

const _drawings = [
  ArchitectSavedDrawing(
    id: 'plan',
    sourceId: 's',
    kind: ArchitectDrawingKind.plan,
  ),
  ArchitectSavedDrawing(
    id: 'section',
    sourceId: 'cut',
    kind: ArchitectDrawingKind.section,
  ),
  ArchitectSavedDrawing(
    id: 'elevation',
    sourceId: 'facade',
    kind: ArchitectDrawingKind.elevation,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('ArchitectNoto')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
  });

  test(
    'plan, section and elevation reuse physical geometry between scales',
    () {
      final p = _model();
      final l = lookupAppLocalizations(const Locale('en'));
      for (final drawing in _drawings) {
        final first = ArchitectDrawingPublisher.build(p, drawing, 100, l);
        final geometry = ArchitectDrawingPublisher.debugPhysicalGeometry(
          p,
          drawing,
        );
        expect(geometry, isNotNull);
        final second = ArchitectDrawingPublisher.build(p, drawing, 200, l);
        expect(first.operations, isNotEmpty);
        expect(second.operations, isNotEmpty);
        expect(identical(first, second), isFalse);
        expect(
          identical(
            geometry,
            ArchitectDrawingPublisher.debugPhysicalGeometry(p, drawing),
          ),
          isTrue,
        );
      }
      expect(ArchitectDrawingPublisher.debugPhysicalGeometryBuilds(p), 3);
      ArchitectDrawingPublisher.build(
        p,
        _drawings.first.copyWith(visibility: {'axes': false, 'zones': false}),
        100,
        l,
      );
      expect(ArchitectDrawingPublisher.debugPhysicalGeometryBuilds(p), 3);
    },
  );

  test('physical edits produce new geometry instead of stale scale caches', () {
    final p = _model();
    final l = lookupAppLocalizations(const Locale('en'));
    final first = <Object?>[];
    for (final drawing in _drawings) {
      ArchitectDrawingPublisher.build(p, drawing, 100, l);
      first.add(ArchitectDrawingPublisher.debugPhysicalGeometry(p, drawing));
    }
    final storey = p.activeStorey;
    final edited = p.updateActiveStorey(
      storey.copyWith(
        walls: [
          storey.walls.first.copyWith(endPoint: const Offset(8, 0)),
          storey.walls.last,
        ],
      ),
    );
    for (var i = 0; i < _drawings.length; i++) {
      final drawing = _drawings[i];
      ArchitectDrawingPublisher.build(edited, drawing, 200, l);
      expect(
        identical(
          first[i],
          ArchitectDrawingPublisher.debugPhysicalGeometry(edited, drawing),
        ),
        isFalse,
      );
    }
    expect(ArchitectDrawingPublisher.debugPhysicalGeometryBuilds(p), 3);
    expect(ArchitectDrawingPublisher.debugPhysicalGeometryBuilds(edited), 3);
  });
}
