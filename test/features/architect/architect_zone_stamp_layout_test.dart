import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/rendering/architect_zone_painter_helper.dart';

ArchitectZone room(String name, List<Offset> polygon) => ArchitectZone(
  id: 'room',
  name: name,
  number: '12',
  category: ArchitectZoneCategory.corridor,
  polygon: polygon,
);

ArchitectProject project(ArchitectZone zone) => ArchitectProject(
  id: 'p',
  name: 'Stamp layout',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [
    ArchitectStorey(id: 's', name: 'Floor', zones: [zone]),
  ],
);

void draw(
  Canvas canvas,
  ArchitectZone zone, {
  double zoom = 80,
  int scale = 100,
}) {
  final p = project(zone);
  ArchitectTextScope(p.document, 'plan:s', scale, zoom).run(() {
    ArchitectZonePainterHelper.drawZones(
      canvas: canvas,
      project: p,
      zoomScale: zoom,
    );
  });
}

Rect textBounds(List<ArchitectVectorText> labels) =>
    labels.map((label) => label.bounds).reduce((a, b) => a.expandToInclude(b));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('ArchitectNoto')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
  });

  final rooms = [
    room('Дневна', const [
      Offset.zero,
      Offset(6, 0),
      Offset(6, 5),
      Offset(0, 5),
    ]),
    room('Corridor / Hall', const [
      Offset.zero,
      Offset(4, 0),
      Offset(4, 3),
      Offset(0, 3),
    ]),
    room('Баня', const [
      Offset.zero,
      Offset(1.5, 0),
      Offset(1.5, 2),
      Offset(0, 2),
    ]),
    room('Коридор', const [
      Offset.zero,
      Offset(1.1, 0),
      Offset(1.1, 6),
      Offset(0, 6),
    ]),
    room('Дневна с кухня и трапезария', const [
      Offset.zero,
      Offset(4, 0),
      Offset(4, 3),
      Offset(0, 3),
    ]),
    // Its geometric centroid is outside the room, in the missing corner.
    room('L-shaped room', const [
      Offset.zero,
      Offset(6, 0),
      Offset(6, 1.2),
      Offset(1.2, 1.2),
      Offset(1.2, 6),
      Offset(0, 6),
    ]),
  ];

  for (final zone in rooms) {
    for (final scale in [50, 100]) {
      test('${zone.name} stays compact and inside its contour at 1:$scale', () {
        final canvas = ArchitectVectorCanvas();
        draw(canvas, zone, scale: scale);
        final labels = canvas.operations
            .whereType<ArchitectVectorText>()
            .toList();
        final bounds = textBounds(labels);
        expect(bounds.height, greaterThan(.08));
        expect(
          bounds.width * bounds.height,
          lessThanOrEqualTo(zone.area * .061),
        );
        final outside = Path.combine(
          PathOperation.difference,
          Path()..addRect(bounds),
          Path()..addPolygon(zone.polygon, true),
        );
        expect(outside.computeMetrics(), isEmpty);
        expect(
          labels.map((e) => e.text).join().replaceAll(RegExp(r'\s'), ''),
          contains(zone.name.replaceAll(RegExp(r'\s'), '')),
        );
        final number = labels.singleWhere((e) => e.role == 'ordinary');
        final area = labels.singleWhere((e) => e.role == 'area');
        expect(number.position.dy, closeTo(area.position.dy, 1e-6));
        expect(number.bounds.right, lessThan(area.bounds.left));
        expect(labels.every((e) => e.weight == FontWeight.w500), isTrue);
        expect(
          canvas.operations.whereType<ArchitectVectorPath>().where(
            (e) => e.fill,
          ),
          isEmpty,
        );
      });
    }
  }

  test('camera zoom does not change stamp dimensions in the model', () {
    final near = ArchitectVectorCanvas(), far = ArchitectVectorCanvas();
    draw(near, rooms[1], zoom: 160);
    draw(far, rooms[1], zoom: 40);
    expect(
      textBounds(near.operations.whereType<ArchitectVectorText>().toList()),
      textBounds(far.operations.whereType<ArchitectVectorText>().toList()),
    );
  });
}
