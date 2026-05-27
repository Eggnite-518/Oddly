import 'package:flutter_test/flutter_test.dart';
import 'package:oddly/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OddlyApp());
    expect(find.byType(OddlyApp), findsOneWidget);
  });
}
