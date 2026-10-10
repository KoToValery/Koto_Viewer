import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/grid_axis_bubble_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final zoom in [.02, .1, 1.0, 5.0]) {
    test(
      'dense labels share two rows without changing axis geometry at zoom $zoom',
      () {
        final axes = [
          for (var i = 0; i < 9; i++)
            StructuralGridAxis(
              id: '$i',
              name: '${i + 1}',
              start: Offset(i * 4, i * 2),
              end: Offset(i * 4, 200 - i * 2),
            ),
        ];
        final before = jsonEncode(axes.map((a) => a.toJson()).toList());
        final packed = GridAxisBubbleLayout.build(
          axes: axes,
          project: (p) => p,
          zoom: zoom,
          levels: (_) => '+2.80',
        );
        for (final start in [true, false]) {
          final points = axes.map((a) => packed[(a.id, start)]!).toList();
          expect(points.map((p) => p.dy).toSet(), hasLength(1));
          for (var i = 1; i < points.length; i++) {
            expect(
              (points[i].dx - points[i - 1].dx).abs() * zoom,
              greaterThan(12),
            );
          }
        }
        expect(jsonEncode(axes.map((a) => a.toJson()).toList()), before);
        final screen = GridAxisBubbleLayout.build(
          axes: axes,
          project: (p) => p * zoom,
          zoom: 1,
          labelScale: GridAxisBubbleLayout.textScale(zoom),
          levels: (_) => '+2.80',
        );
        for (final key in packed.keys) {
          expect(
            (screen[key]! - packed[key]! * zoom).distance,
            lessThan(.0001),
          );
        }
      },
    );
  }
  test('reversed diagonal axes put each end on the correct common row', () {
    const axes = [
      StructuralGridAxis(
        id: 'a',
        name: 'A',
        start: Offset(0, 0),
        end: Offset(100, 100),
      ),
      StructuralGridAxis(
        id: 'b',
        name: 'B',
        start: Offset(98, 102),
        end: Offset(-2, 2),
      ),
    ];
    final p = GridAxisBubbleLayout.build(
      axes: axes,
      project: (p) => p,
      levels: (_) => '',
    );
    expect((p[('a', true)]!.dx + p[('a', true)]!.dy), closeTo(0, .0001));
    expect((p[('b', false)]!.dx + p[('b', false)]!.dy), closeTo(0, .0001));
    expect((p[('b', true)]!.dx + p[('b', true)]!.dy), closeTo(200, .0001));
  });
}
