import 'package:flutter_test/flutter_test.dart';
import 'package:epic_app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EpicApp());

    // Very basic test since EpicApp requires GetMaterialApp and lots of bindings.
    expect(find.byType(EpicApp), findsOneWidget);
  });
}
