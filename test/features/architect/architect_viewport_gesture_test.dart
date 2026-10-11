import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/widgets/architect_viewport.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';

void main() {
  testWidgets('Pending placement hold cannot activate after switching tools', (
    tester,
  ) async {
    final camera = BimViewportController();
    addTearDown(camera.dispose);
    var key = 1, holds = 0, releases = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ArchitectViewport(
              controller: camera,
              interactionKey: key,
              singlePointerPan: true,
              touchHoldToPlace: true,
              isDraggingHandle: () => false,
              onToolHoldStart: (_) => holds++,
              onToolDown: (_) {},
              onToolMove: (_) {},
              onToolHover: (_) {},
              onToolUp: (_) => releases++,
              onToolCancel: () {},
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final old = await tester.startGesture(const Offset(100, 200));
    await tester.pump(const Duration(milliseconds: 100));
    rebuild(() => key++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await old.up();
    expect(holds, 0);
    expect(releases, 0);
    final fresh = await tester.startGesture(const Offset(100, 200));
    await tester.pump(const Duration(milliseconds: 281));
    await fresh.up();
    expect(holds, 1);
    expect(releases, 1);
  });

  testWidgets(
    'A second finger cancels a pending hold before its timer activates',
    (tester) async {
      final camera = BimViewportController();
      addTearDown(camera.dispose);
      var holds = 0, releases = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ArchitectViewport(
            controller: camera,
            singlePointerPan: true,
            touchHoldToPlace: true,
            isDraggingHandle: () => false,
            onToolHoldStart: (_) => holds++,
            onToolDown: (_) {},
            onToolMove: (_) {},
            onToolHover: (_) {},
            onToolUp: (_) => releases++,
            onToolCancel: () {},
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      final first = await tester.startGesture(
        const Offset(100, 200),
        pointer: 51,
      );
      await tester.pump(const Duration(milliseconds: 100));
      final second = await tester.startGesture(
        const Offset(300, 200),
        pointer: 52,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await second.up();
      await first.up();
      expect(holds, 0);
      expect(releases, 0);
      await tester.tapAt(const Offset(100, 200));
      expect(releases, 1);
    },
  );
  testWidgets(
    'Single-pointer drafting never pans and commits its final position',
    (tester) async {
      final camera = BimViewportController();
      addTearDown(camera.dispose);
      var moves = 0;
      Offset? release;
      await tester.pumpWidget(
        MaterialApp(
          home: ArchitectViewport(
            controller: camera,
            singlePointerPan: false,
            isDraggingHandle: () => false,
            onToolDown: (_) {},
            onToolMove: (_) => moves++,
            onToolHover: (_) {},
            onToolUp: (e) => release = e.localPosition,
            onToolCancel: () {},
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      );
      await tester.pump();
      final translation = camera.translation;
      final gesture = await tester.startGesture(const Offset(100, 200));
      await gesture.moveTo(const Offset(200, 250));
      await gesture.up();
      expect(moves, 1);
      expect(release, const Offset(200, 250));
      expect(camera.translation, translation);
    },
  );

  testWidgets('A pan that returns to its starting point cannot become a tap', (
    tester,
  ) async {
    final camera = BimViewportController();
    addTearDown(camera.dispose);
    var releases = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ArchitectViewport(
          controller: camera,
          singlePointerPan: true,
          isDraggingHandle: () => false,
          onToolDown: (_) {},
          onToolMove: (_) {},
          onToolHover: (_) {},
          onToolUp: (_) => releases++,
          onToolCancel: () {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(100, 200));
    await gesture.moveTo(const Offset(200, 200));
    await gesture.moveTo(const Offset(100, 200));
    await gesture.up();
    expect(releases, 0);
  });

  testWidgets(
    'Pinch cancels a handle and suppresses every release until all fingers lift',
    (tester) async {
      final camera = BimViewportController();
      addTearDown(camera.dispose);
      var cancellations = 0;
      var releases = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ArchitectViewport(
            controller: camera,
            singlePointerPan: false,
            isDraggingHandle: () => true,
            onToolDown: (_) {},
            onToolMove: (_) {},
            onToolHover: (_) {},
            onToolUp: (_) => releases++,
            onToolCancel: () => cancellations++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      final first = await tester.startGesture(
        const Offset(100, 200),
        pointer: 11,
      );
      final second = await tester.startGesture(
        const Offset(300, 200),
        pointer: 12,
      );
      final scale = camera.scale;
      await second.moveTo(const Offset(340, 200));
      expect(camera.scale, greaterThan(scale));
      await second.up();
      await first.moveTo(const Offset(130, 200));
      await first.up();
      expect(cancellations, 1);
      expect(releases, 0);
      await tester.tapAt(const Offset(100, 200));
      expect(releases, 1);
    },
  );

  testWidgets('Mouse middle-button drag navigates without entering a tool', (
    tester,
  ) async {
    final camera = BimViewportController();
    addTearDown(camera.dispose);
    var downs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ArchitectViewport(
          controller: camera,
          singlePointerPan: false,
          isDraggingHandle: () => false,
          onToolDown: (_) => downs++,
          onToolMove: (_) {},
          onToolHover: (_) {},
          onToolUp: (_) {},
          onToolCancel: () {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    final original = camera.translation;
    final gesture = await tester.startGesture(
      const Offset(100, 200),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await gesture.moveBy(const Offset(30, 20));
    await gesture.up();
    expect(camera.translation, original + const Offset(30, 20));
    expect(downs, 0);
  });

  testWidgets('Trackpad cumulative scaling does not compound previous scale', (
    tester,
  ) async {
    final camera = BimViewportController();
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ArchitectViewport(
          controller: camera,
          singlePointerPan: false,
          isDraggingHandle: () => false,
          onToolDown: (_) {},
          onToolMove: (_) {},
          onToolHover: (_) {},
          onToolUp: (_) {},
          onToolCancel: () {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    const position = Offset(200, 200);
    final scale = camera.scale;
    await tester.sendEventToBinding(
      const PointerPanZoomStartEvent(pointer: 99, position: position),
    );
    await tester.sendEventToBinding(
      const PointerPanZoomUpdateEvent(
        pointer: 99,
        position: position,
        scale: 2,
      ),
    );
    await tester.sendEventToBinding(
      const PointerPanZoomUpdateEvent(
        pointer: 99,
        position: position,
        scale: 3,
      ),
    );
    await tester.sendEventToBinding(
      const PointerPanZoomEndEvent(pointer: 99, position: position),
    );
    expect(camera.scale, closeTo(scale * 3, 1e-9));
  });
}
