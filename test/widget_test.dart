import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KotoViewApp());
    expect(find.byType(KotoViewApp), findsOneWidget);
  });
}
