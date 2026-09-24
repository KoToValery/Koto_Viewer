import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('InteractiveViewer with boundaryMargin 1000 locks horizontal pan at scale 0.42',
      (WidgetTester tester) async {
    final tc = TransformationController();
    const viewportSize = Size(1920, 1080);

    await tester.binding.setSurfaceSize(viewportSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: InteractiveViewer(
                transformationController: tc,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.001,
                maxScale: 1000.0,
                boundaryMargin: const EdgeInsets.all(1000.0),
                child: SizedBox(
                  width: viewportSize.width,
                  height: viewportSize.height,
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Zoom out to 0.42 (same as reported in user logs)
    tc.value = Matrix4.identity()..scale(0.42);
    await tester.pump();

    // Drag horizontally to the right by 100px
    final gesture = await tester.startGesture(const Offset(960, 540));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();

    final txWith1000 = tc.value.getTranslation().x;
    print('Translation X with boundaryMargin 1000: $txWith1000');

    // Drag vertically downwards by 100px
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();

    final tyWith1000 = tc.value.getTranslation().y;
    print('Translation Y with boundaryMargin 1000: $tyWith1000');
    expect(txWith1000, equals(0.0)); // Proves horizontal pan was locked!

    await gesture.up();
  });

  testWidgets('InteractiveViewer with boundaryMargin infinity allows free pan at scale 0.42',
      (WidgetTester tester) async {
    final tc = TransformationController();
    const viewportSize = Size(1920, 1080);

    await tester.binding.setSurfaceSize(viewportSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: InteractiveViewer(
                transformationController: tc,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.001,
                maxScale: 1000.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: SizedBox(
                  width: viewportSize.width,
                  height: viewportSize.height,
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Zoom out to 0.42 (same as reported in user logs)
    tc.value = Matrix4.identity()..scale(0.42);
    await tester.pump();

    // Drag horizontally to the right by 100px
    final gesture = await tester.startGesture(const Offset(960, 540));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();

    final txWithInfinity = tc.value.getTranslation().x;
    print('Translation X with boundaryMargin infinity: $txWithInfinity');

    // Drag vertically downwards by 100px
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();

    final tyWithInfinity = tc.value.getTranslation().y;
    print('Translation Y with boundaryMargin infinity: $tyWithInfinity');

    expect(txWithInfinity, greaterThan(0.0));
    expect(tyWithInfinity, greaterThan(0.0));

    await gesture.up();
  });
}

