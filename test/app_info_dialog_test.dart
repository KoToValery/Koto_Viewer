import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/home/widgets/app_info_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppInfoDialog Tests', () {
    testWidgets('AppInfoDialog renders KotoView title, capabilities and license', (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'KotoView',
        packageName: 'com.koto.pdfviewer',
        version: '1.2.0',
        buildNumber: '2',
        buildSignature: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: AppInfoDialog(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Title and Dynamic Version
      expect(find.text('KotoView'), findsOneWidget);
      expect(find.text('v1.2.0 (Build 2)'), findsOneWidget);

      // Verify Capabilities
      expect(find.text('2D CAD & Engineering Drawings'), findsOneWidget);
      expect(find.text('3D CAD Models & BIM'), findsOneWidget);
      expect(find.text('PCB Electronics & Manufacturing'), findsOneWidget);
      expect(find.text('Vector Graphics'), findsOneWidget);
      expect(find.text('Office & Text Documents'), findsOneWidget);

      // Verify License & Open Source
      expect(find.text('Open Source & Licensing'), findsOneWidget);
      expect(find.text('Licenses'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });
  });
}
