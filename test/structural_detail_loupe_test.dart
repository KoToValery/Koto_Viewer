import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';

void main() {
  testWidgets('placement overlay keeps its pointer without a magnifier', (
    tester,
  ) async {
    const painter = StructuralPointerPainter(
      touchPos: Offset(200, 240),
      targetPos: Offset(200, 180),
      placementPos: Offset(210, 190),
      activeTool: StructuralDrawTool.column,
      previewElementPolygon: [
        Offset(200, 180),
        Offset(220, 180),
        Offset(220, 200),
        Offset(200, 200),
      ],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: StructuralPointerOverlay(painter: painter),
        ),
      ),
    );
    expect(find.byType(RawMagnifier), findsNothing);
    expect(
      tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter,
      same(painter),
    );
    expect(painter.effectivePlacementPosition, const Offset(210, 190));
    expect(tester.takeException(), isNull);
  });
}
