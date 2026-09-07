import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/docx_viewer/docx_viewer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocxSinglePageItem 3-Zone Navigation & Smooth Zoom Tests', () {
    testWidgets('3-Zone Tap Navigation detects Left (25%), Center (50%), and Right (25%) zones', (tester) async {
      int leftTaps = 0;
      int centerTaps = 0;
      int rightTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: DocxSinglePageItem(
                onLeftTap: () => leftTaps++,
                onCenterTap: () => centerTaps++,
                onRightTap: () => rightTaps++,
                child: Container(
                  width: 800,
                  height: 600,
                  color: Colors.white,
                  child: const Text('Page 1 Content'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Left zone (x = 100, which is 12.5% of 800 width, < 25%)
      await tester.tapAt(const Offset(100, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(leftTaps, equals(1));
      expect(centerTaps, equals(0));
      expect(rightTaps, equals(0));

      // Tap on Right zone (x = 700, which is 87.5% of 800 width, > 75%)
      await tester.tapAt(const Offset(700, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(leftTaps, equals(1));
      expect(centerTaps, equals(0));
      expect(rightTaps, equals(1));

      // Tap on Center zone (x = 400, which is 50% of 800 width)
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(leftTaps, equals(1));
      expect(centerTaps, equals(1));
      expect(rightTaps, equals(1));
    });

    testWidgets('Double-tap zooms in smoothly and notifies onZoomChanged', (tester) async {
      double currentZoom = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: DocxSinglePageItem(
                onZoomChanged: (z) => currentZoom = z,
                child: Container(
                  width: 800,
                  height: 600,
                  color: Colors.white,
                  child: const Text('Zoom Test Document'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(currentZoom, equals(1.0));

      // Double-tap at (400, 300)
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();

      // Zoom should animate to target scale (2.5)
      expect(currentZoom, closeTo(2.5, 0.01));

      // Second double-tap resets zoom back to 1.0
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();

      expect(currentZoom, closeTo(1.0, 0.01));
    });

    testWidgets('Scale Guard prevents edge taps from triggering page navigation while zoomed in', (tester) async {
      int leftTaps = 0;
      int rightTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: DocxSinglePageItem(
                onLeftTap: () => leftTaps++,
                onRightTap: () => rightTaps++,
                child: Container(
                  width: 800,
                  height: 600,
                  color: Colors.white,
                  child: const Text('Scale Guard Test Page'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on left before zoom -> should trigger
      await tester.tapAt(const Offset(100, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(leftTaps, equals(1));

      // Double-tap to zoom in
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();

      // Tap on left/right edges while zoomed -> should NOT trigger page flips!
      await tester.tapAt(const Offset(100, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(leftTaps, equals(1)); // Unchanged!

      await tester.tapAt(const Offset(700, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(rightTaps, equals(0)); // Ignored!
    });
  });
}
