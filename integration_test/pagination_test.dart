import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:listor/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('paginates and saves a Non Erotic story locally', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    app.main();

    final listFinder = find.byKey(const Key('feed-list-newest'));
    await _pumpUntil(tester, () => listFinder.evaluate().isNotEmpty);

    final scrollableFinder = find.descendant(
      of: listFinder,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollableFinder).position;
    final initialExtent = position.maxScrollExtent;
    expect(initialExtent, greaterThan(0));
    await binding.takeScreenshot('non-erotic-first-page');

    await tester.fling(listFinder, const Offset(0, -900), 1400);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('bottom-navigation-shell'))).height,
      0,
    );
    await binding.takeScreenshot('non-erotic-collapsed-chrome');

    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await _pumpUntil(tester, () => position.maxScrollExtent > initialExtent);

    expect(position.maxScrollExtent, greaterThan(initialExtent));
    await binding.takeScreenshot('non-erotic-next-page');

    final favoriteButton = find
        .byTooltip('Add to favourites')
        .hitTestable()
        .first;
    expect(favoriteButton, findsOneWidget);
    await tester.tap(favoriteButton);
    await _pumpUntil(
      tester,
      () => find.byTooltip('Remove from favourites').evaluate().isNotEmpty,
    );

    await tester.fling(listFinder, const Offset(0, 500), 1200);
    await tester.pumpAndSettle();
    final favoritesDestination = find
        .byKey(const Key('favorites-destination'))
        .hitTestable();
    expect(favoritesDestination, findsOneWidget);
    await tester.tap(favoritesDestination);
    await _pumpUntil(
      tester,
      () =>
          find.byKey(const Key('favorite-stories-list')).evaluate().isNotEmpty,
    );
    final downloadButton = find
        .byTooltip('Download for offline reading')
        .hitTestable()
        .first;
    await tester.tap(downloadButton);
    await _pumpUntil(
      tester,
      () => find.byTooltip('Remove download').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 45),
    );
    await binding.takeScreenshot('favourite-downloaded-sqlite');
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
