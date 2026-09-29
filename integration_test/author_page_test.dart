import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:listor/main.dart' as app;
import 'package:listor/story_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('author page favourites separately from downloads', (
    tester,
  ) async {
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
    final existingFavorite = find
        .byTooltip('Remove from favourites')
        .hitTestable();
    if (existingFavorite.evaluate().isNotEmpty) {
      await tester.tap(existingFavorite.first);
      await _pumpUntil(
        tester,
        () => find.byTooltip('Add to favourites').evaluate().isNotEmpty,
      );
    }
    expect(find.byTooltip('Add to favourites'), findsWidgets);
    await binding.takeScreenshot('author-story-cards');

    final favoriteButton = find
        .byTooltip('Add to favourites')
        .hitTestable()
        .first;
    await tester.tap(favoriteButton);
    await _pumpUntil(
      tester,
      () => find.byTooltip('Remove from favourites').evaluate().isNotEmpty,
    );
    expect(find.byTooltip('Remove from favourites'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorites-destination')));
    await _pumpUntil(
      tester,
      () =>
          find.byKey(const Key('favorite-stories-list')).evaluate().isNotEmpty,
    );

    final downloadButton = find
        .byTooltip('Download for offline reading')
        .hitTestable();
    if (downloadButton.evaluate().isNotEmpty) {
      await tester.tap(downloadButton.first);
      await _pumpUntil(
        tester,
        () => find.byTooltip('Remove download').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 45),
      );
    }

    expect(find.byTooltip('Remove download'), findsWidgets);
    await binding.takeScreenshot('favourite-story-downloaded');
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
