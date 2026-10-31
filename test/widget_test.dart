import 'package:flutter_test/flutter_test.dart';
import 'package:taptap_go/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TaptapGoApp());
    expect(find.byType(TaptapGoApp), findsOneWidget);
  });
}
