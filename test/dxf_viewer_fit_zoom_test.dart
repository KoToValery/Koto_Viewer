import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/l10n_extensions.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_writer.dart';
import 'package:kotoview/src/features/dxf_viewer/dxf_viewer_screen.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_viewport_picture_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Model stops at fit while pan and Paper zoom still work', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final temp = Directory.systemTemp.createTempSync('dxf_viewer_zoom_');
    final drawing = File('${temp.path}/test.kcad');
    addTearDown(() {
      drawing.deleteSync();
      temp.deleteSync();
    });
    drawing.writeAsBytesSync(
      KcadWriter.write(
        DxfDocument(
          layers: {'0': DxfLayer(name: '0')},
          blocks: {},
          entities: [
            for (
              var i = 0;
              i < DxfViewportPictureCache.minOverviewEntities;
              i++
            )
              DxfLine(p1: Offset(0, i % 100.0), p2: Offset(100, i % 100.0)),
            const DxfLine(
              p1: Offset.zero,
              p2: Offset(100, 100),
              isPaperSpace: true,
              layoutName: 'Sheet A',
            ),
          ],
          headerVars: {},
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          entityStats: {},
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DxfViewerScreen(filePath: drawing.path, addToRecent: false),
      ),
    );
    final viewer = find.byType(InteractiveViewer);
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && viewer.evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        await tester.pump();
      }
    });
    expect(viewer, findsOneWidget);
    await tester.pump();
    final controller = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    final center = tester.getCenter(viewer);
    DxfPainter drawingPainter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<DxfPainter>()
        .firstWhere((painter) => painter.viewportPictures != null);
    Future<void> wheel(double dy) => tester.sendEventToBinding(
      PointerScrollEvent(
        position: center,
        scrollDelta: Offset(0, dy),
        kind: PointerDeviceKind.mouse,
      ),
    );

    final atFit = drawingPainter();
    await wheel(100);
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.value, Matrix4.identity());
    expect(drawingPainter(), same(atFit));
    expect(atFit.motionPreview!.value, DxfViewportMotion.idle);

    await wheel(-140);
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));
    await tester.pump(const Duration(milliseconds: 150));

    final leftFinger = await tester.startGesture(center - const Offset(85, 0));
    final rightFinger = await tester.startGesture(center + const Offset(85, 0));
    await leftFinger.moveTo(center - const Offset(45, 0));
    await rightFinger.moveTo(center + const Offset(45, 0));
    await leftFinger.moveTo(center - const Offset(15, 0));
    await rightFinger.moveTo(center + const Offset(15, 0));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 1e-10));
    await leftFinger.up();
    await rightFinger.up();
    await tester.pumpAndSettle();

    final beforePan = controller.value.clone();
    await tester.drag(viewer, const Offset(70, 0));
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 1e-10));
    expect(
      controller.value.getTranslation().x,
      isNot(beforePan.getTranslation().x),
    );

    await tester.tap(find.text('Sheet A'));
    await tester.pumpAndSettle();
    await wheel(100);
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), lessThan(1));
  });
}
