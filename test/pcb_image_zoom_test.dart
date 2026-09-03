import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/pcb_viewer/models/pcb_models.dart';
import 'package:kotoview/src/features/pcb_viewer/widgets/pcb_image_zoom_dialog.dart';

void main() {
  final testPngBytes = Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
    0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
    0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5,
    0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
  ]);

  group('PCB Image Zoom Dialog Tests', () {
    testWidgets('Renders image zoom dialog with controls and navigation', (tester) async {
      final images = [
        PcbImageItem(fileName: 'render_top.png', bytes: testPngBytes),
        PcbImageItem(fileName: 'render_bottom.png', bytes: testPngBytes),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PcbImageZoomDialog(images: images, initialIndex: 0),
        ),
      );
      await tester.pump();

      // Check current filename and count indicator
      expect(find.text('render_top.png'), findsOneWidget);
      expect(find.textContaining('1 of 2'), findsOneWidget);

      // Check zoom control buttons exist
      expect(find.byTooltip('Zoom In (+)'), findsOneWidget);
      expect(find.byTooltip('Zoom Out (-)'), findsOneWidget);
      expect(find.byTooltip('Fit to View'), findsOneWidget);
      expect(find.byTooltip('Reset Zoom (100%)'), findsOneWidget);

      // Tap Zoom In button
      await tester.tap(find.byTooltip('Zoom In (+)'));
      await tester.pump();

      // Tap Next Image button
      expect(find.byTooltip('Next Image (Right Arrow)'), findsOneWidget);
      await tester.tap(find.byTooltip('Next Image (Right Arrow)'));
      await tester.pump();

      // Verify navigated to second image
      expect(find.text('render_bottom.png'), findsOneWidget);
      expect(find.textContaining('2 of 2'), findsOneWidget);
    });

    testWidgets('PcbImageZoomDialog.show opens and closes properly', (tester) async {
      final images = [
        PcbImageItem(fileName: 'pcb_3d_view.jpg', bytes: testPngBytes),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PcbImageZoomDialog.show(context, images: images),
                child: const Text('Open Zoom'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Zoom'));
      await tester.pumpAndSettle();

      expect(find.text('pcb_3d_view.jpg'), findsOneWidget);
      expect(find.byTooltip('Close (Esc)'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byTooltip('Close (Esc)'));
      await tester.pumpAndSettle();

      expect(find.text('pcb_3d_view.jpg'), findsNothing);
    });
  });
}
