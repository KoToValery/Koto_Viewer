import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_transform_navigation.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_viewport_controller.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_viewport_navigation.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_editing_viewport.dart';

void main() {
  test(
    'matrix camera retains its focal scene point and clamps without drift',
    () {
      final matrix = TransformationController();
      addTearDown(matrix.dispose);
      var size = const Size(800, 600);
      final camera = BimTransformNavigation(
        controller: matrix,
        readSize: () => size,
        onResize: (next) => size = next,
        minScale: .1,
        maxScale: 10,
      );
      camera.panBy(const Offset(34, -82));
      const previous = Offset(160, 240), focal = Offset(180, 260);
      final anchor = matrix.toScene(previous);
      camera.navigate(previousFocal: previous, focal: focal, scaleFactor: 3);
      expect((matrix.toScene(focal) - anchor).distance, lessThan(1e-9));
      camera.navigate(previousFocal: focal, focal: focal, scaleFactor: 10000);
      expect(matrix.value.getMaxScaleOnAxis(), 10);
      expect((matrix.toScene(focal) - anchor).distance, lessThan(1e-9));
      final before = matrix.value.clone();
      camera.navigate(
        previousFocal: focal,
        focal: focal,
        scaleFactor: double.nan,
      );
      expect(matrix.value, before);
      camera.resize(const Size(600, 800));
      expect(camera.size, const Size(600, 800));
    },
  );

  for (final useMatrix in [false, true]) {
    testWidgets(
      'one owner cancels a held edit on pinch (${useMatrix ? 'Construction' : 'Architect'} camera)',
      (tester) async {
        final modelCamera = BimViewportController();
        final matrix = TransformationController();
        addTearDown(modelCamera.dispose);
        addTearDown(matrix.dispose);
        var size = Size.zero;
        final BimViewportNavigation camera = useMatrix
            ? BimTransformNavigation(
                controller: matrix,
                readSize: () => size,
                onResize: (v) => size = v,
              )
            : modelCamera;
        var holds = 0, releases = 0, cancels = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: BimEditingViewport(
              controller: camera,
              singlePointerPan: true,
              touchHoldToPlace: true,
              isDraggingHandle: () => false,
              onToolDown: (_) {},
              onToolMove: (_) {},
              onToolHover: (_) {},
              onToolUp: (_) => releases++,
              onToolCancel: () => cancels++,
              onToolHoldStart: (_) => holds++,
              child: const SizedBox.expand(),
            ),
          ),
        );
        await tester.pump();
        final first = await tester.startGesture(
          const Offset(100, 200),
          pointer: 71,
        );
        await tester.pump(const Duration(milliseconds: 281));
        expect(holds, 1);
        final second = await tester.startGesture(
          const Offset(300, 200),
          pointer: 72,
        );
        await second.moveTo(const Offset(400, 250));
        await second.up();
        await first.up();
        expect(cancels, 1);
        expect(releases, 0);
        await tester.tapAt(const Offset(200, 300));
        expect(releases, 1);
      },
    );
  }
}
