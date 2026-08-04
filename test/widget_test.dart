import 'package:flutter_test/flutter_test.dart';
import 'package:koto_pdf_viewer/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KotoPdfViewerApp());
    expect(find.text('Koto PDF Viewer'), findsWidgets);
  });
}
