import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KotoViewApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(KotoViewApp), findsOneWidget);
  });
}
