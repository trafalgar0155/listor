import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:listor/main.dart' as app;
import 'package:listor/story_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('author page uses story cards and saves a story', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    app.main();

    final feed = find.byKey(const Key('feed-list-newest'));
    await _pumpUntil(tester, () => feed.evaluate().isNotEmpty);

    final authorLink = _keyStartsWith('author-').hitTestable().first;
    await _pumpUntil(tester, () => authorLink.evaluate().isNotEmpty);
    await tester.tap(authorLink);
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('author-works-page')).evaluate().isNotEmpty,
    );

    if (find.byType(StoryCard).evaluate().isEmpty) {
      final series = _keyStartsWith('author-series-').hitTestable().first;
      await _pumpUntil(tester, () => series.evaluate().isNotEmpty);
      await tester.tap(series);
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.byType(StoryCard), findsWidgets);
    expect(find.byTooltip('Save story for offline reading'), findsWidgets);
    await binding.takeScreenshot('author-story-cards');

    final saveButton = find
        .byTooltip('Save story for offline reading')
        .hitTestable()
        .first;
    await tester.tap(saveButton);
    await _pumpUntil(
      tester,
      () => find.byTooltip('Remove from saved').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 45),
    );

    expect(find.byTooltip('Remove from saved'), findsWidgets);
    await binding.takeScreenshot('author-story-saved');
  });
}

Finder _keyStartsWith(String prefix) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
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
      fail('Timed out waiting for the author-page state to change.');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
