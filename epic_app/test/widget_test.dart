import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epic_app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EpicApp());

    // Very basic test since EpicApp requires GetMaterialApp and lots of bindings.
    expect(find.byType(EpicApp), findsOneWidget);

    // Let startup timers complete, then dispose the full app tree so the test
    // does not leak splash/session timers into the next test process.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
