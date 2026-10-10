import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';

StructuralPointerPainter pointer(Offset touch, {bool enabled = true}) =>
    StructuralPointerPainter(
      touchPos: touch,
      targetPos: touch,
      placementPos: touch,
      activeTool: StructuralDrawTool.column,
      showDetailLoupe: enabled,
      loupeHasScene: true,
      previewElementPolygon: [
        touch + const Offset(-10, -9),
        touch + const Offset(10, -9),
        touch + const Offset(10, 9),
        touch + const Offset(-10, 9),
      ],
      snappedPos: touch + const Offset(10, 9),
      snapType: DxfSnapType.endpoint,
    );

void main() {
  test(
    'focus follows a touched edge instead of the center of a large object',
    () {
      final p = StructuralPointerPainter(
        touchPos: const Offset(292, 250),
        targetPos: const Offset(200, 250),
        placementPos: const Offset(200, 250),
        activeTool: StructuralDrawTool.column,
        showDetailLoupe: true,
        previewElementPolygon: const [
          Offset(100, 150),
          Offset(300, 150),
          Offset(300, 350),
          Offset(100, 350),
        ],
      );
      expect(p.detailFocusPosition, const Offset(300, 250));
      expect(p.detailLoupeRect(const Size(400, 400)), isNotNull);
      expect(p.effectivePlacementPosition, const Offset(200, 250));
    },
  );
  test('loupe stays in view and away from a finger near viewport edges', () {
    const size = Size(400, 400);
    for (final touch in [
      const Offset(200, 200),
      const Offset(200, 10),
      const Offset(200, 390),
      const Offset(10, 10),
      const Offset(390, 390),
    ]) {
      final rect = pointer(touch).detailLoupeRect(size)!;
      expect(rect.left, greaterThanOrEqualTo(8));
      expect(rect.top, greaterThanOrEqualTo(8));
      expect(rect.right, lessThanOrEqualTo(392));
      expect(rect.bottom, lessThanOrEqualTo(392));
      expect(
        (rect.center - touch).distance,
        greaterThanOrEqualTo(rect.width / 2 + 38),
      );
    }
    expect(
      pointer(const Offset(200, 240), enabled: false).detailLoupeRect(size),
      isNull,
    );
  });

  for (final light in [false, true]) {
    testWidgets(
      'loupe magnifies the real drawing with a legible outline: light=$light',
      (tester) async {
        tester.view.physicalSize = const Size(400, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const touch = Offset(200, 240);
        final overlay = pointer(touch);
        final key = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              key: key,
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _Drawing(light))),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: StructuralPointerOverlay(painter: overlay),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        final magnifier = tester.widget<RawMagnifier>(
          find.byType(RawMagnifier),
        );
        final bounds = overlay.detailLoupeRect(const Size(400, 400))!;
        expect(
          magnifier.focalPointOffset + bounds.center,
          overlay.detailFocusPosition,
        );
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final data = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final bytes = data!.buffer.asUint8List();
        List<int> pixel(int x, int y) =>
            bytes.sublist((y * 400 + x) * 4, (y * 400 + x) * 4 + 3);
        // The wall exists only near the finger in the original drawing. Its
        // enlarged pixels must appear in the loupe, outside the moving polygon.
        final wallPos =
            bounds.center +
            (const Offset(221, 240) - overlay.detailFocusPosition) * 2.5;
        final wall = pixel(wallPos.dx.round(), wallPos.dy.round());
        expect(
          wall.every((c) => light ? c < 60 : c > 200),
          isTrue,
          reason: '$wall',
        );
        // Both backgrounds retain the same warm, clearly delineated edge.
        final edgePos =
            bounds.center +
            (const Offset(200, 249) - overlay.detailFocusPosition) * 2.5;
        final edge = pixel(edgePos.dx.round(), edgePos.dy.round());
        expect(edge[0], greaterThan(220));
        expect(edge[1], greaterThan(150));
        expect(edge[2], lessThan(130));
        if (const bool.fromEnvironment('BIM_LOUPE_VISUAL')) {
          final png = await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.png),
          );
          final dir = Directory('.dart_tool/loupe_visual')
            ..createSync(recursive: true);
          File(
            '${dir.path}/${light ? 'light' : 'dark'}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        image.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Drawing extends CustomPainter {
  final bool light;
  const _Drawing(this.light);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = light ? const Color(0xFFF5F4EF) : const Color(0xFF1B1D20),
    );
    final wall = Paint()
      ..color = light ? const Color(0xFF222222) : const Color(0xFFEAEAEA);
    canvas.drawRect(const Rect.fromLTWH(220, 225, 3, 30), wall);
    canvas.drawRect(const Rect.fromLTWH(174, 217, 49, 3), wall);
    canvas.drawLine(
      const Offset(160, 254),
      const Offset(238, 254),
      Paint()
        ..color = const Color(0xFF888888)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _Drawing oldDelegate) =>
      light != oldDelegate.light;
}
