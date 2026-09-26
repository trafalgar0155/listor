import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:listor/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads another Non Erotic page after scrolling', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    app.main();

    final listFinder = find.byKey(const Key('feed-list-newest'));
    await _pumpUntil(tester, () => listFinder.evaluate().isNotEmpty);

    final list = tester.widget<ListView>(listFinder);
    final controller = list.controller!;
    final initialExtent = controller.position.maxScrollExtent;
    expect(initialExtent, greaterThan(0));
    await binding.takeScreenshot('non-erotic-first-page');

    controller.jumpTo(initialExtent);
    await tester.pump();
    await _pumpUntil(
      tester,
      () => controller.position.maxScrollExtent > initialExtent,
    );

    expect(controller.position.maxScrollExtent, greaterThan(initialExtent));
    await binding.takeScreenshot('non-erotic-next-page');
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the pagination state to change.');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
