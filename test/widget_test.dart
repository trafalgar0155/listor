import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listor/literotica_api.dart';
import 'package:listor/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeStoryRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeStoryRepository();
  });

  testWidgets('shows a filter action and all feed tabs', (tester) async {
    await tester.pumpWidget(ListorApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Listor'), findsOneWidget);
    expect(find.byKey(const Key('category-filter')), findsNothing);
    expect(find.byKey(const Key('filter-fab')), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Random'), findsOneWidget);
  });

  testWidgets('applies category, period, and multi-select tag filters', (
    tester,
  ) async {
    await tester.pumpWidget(ListorApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('A Quiet Harbour'), findsOneWidget);
    expect(
      repository.requests.first.filters.category,
      ListorCategory.nonErotic,
    );

    await tester.tap(find.byKey(const Key('filter-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Filter stories'), findsOneWidget);
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('Last 30 days'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);

    await tester.tap(find.byKey(const Key('category-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non-Erotic Poetry').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 30 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('mystery'));
    await tester.pump();
    await tester.tap(find.text('adventure'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('apply-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Quiet Verses'), findsOneWidget);
    expect(find.text('A Quiet Harbour'), findsNothing);
    final applied = repository.requests.last.filters;
    expect(applied.category, ListorCategory.nonEroticPoetry);
    expect(applied.period, StoryPeriod.month);
    expect(
      applied.tags.map((tag) => tag.label),
      containsAll(['mystery', 'adventure']),
    );
  });

  testWidgets('restores the last selected Literotica category', (tester) async {
    SharedPreferences.setMockInitialValues({'selected_category': 'romance'});
    await tester.pumpWidget(ListorApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Paper Moons'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Romance'), findsOneWidget);
  });

  testWidgets('feed tabs can be changed with a horizontal swipe', (
    tester,
  ) async {
    await tester.pumpWidget(ListorApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(TabBarView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    final controller = DefaultTabController.of(
      tester.element(find.byType(TabBarView)),
    );
    expect(controller.index, 1);
    expect(
      repository.requests.any((request) => request.feed == FeedType.popular),
      isTrue,
    );
  });

  testWidgets('loads and appends another story page near the bottom', (
    tester,
  ) async {
    await tester.pumpWidget(ListorApp(repository: repository));
    await tester.pumpAndSettle();

    expect(
      repository.requests.where(
        (request) => request.feed == FeedType.newest && request.page == 1,
      ),
      isEmpty,
    );

    final listFinder = find.byKey(const Key('feed-list-newest'));
    final initialExtent = tester
        .widget<ListView>(listFinder)
        .controller!
        .position
        .maxScrollExtent;
    await tester.fling(listFinder, const Offset(0, -1000), 1400);
    await tester.pumpAndSettle();

    expect(
      repository.requests.any(
        (request) => request.feed == FeedType.newest && request.page == 1,
      ),
      isTrue,
    );
    final appendedExtent = tester
        .widget<ListView>(listFinder)
        .controller!
        .position
        .maxScrollExtent;
    expect(appendedExtent, greaterThan(initialExtent));
  });

  testWidgets('opens a formatted story reader when a card is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(ListorApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A Quiet Harbour'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-reader')), findsOneWidget);
    expect(find.text('Story'), findsOneWidget);
    final html = tester.widget<Html>(find.byType(Html));
    expect(html.data, contains('<strong>Opening line</strong>'));
    expect(html.data, contains('<em>emphasis</em>'));
  });

  testWidgets('lays out without errors at phone width', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(ListorApp(repository: repository));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _Request {
  const _Request(this.filters, this.feed, this.page);
  final StoryFilters filters;
  final FeedType feed;
  final int page;
}

class _FakeStoryRepository implements StoryRepository {
  final requests = <_Request>[];

  @override
  Future<StoryFeedPage> fetchFeed(
    StoryFilters filters,
    FeedType feed, {
    int page = 0,
  }) async {
    requests.add(_Request(filters, feed, page));
    final category = filters.category;
    final baseTitle = switch (category) {
      ListorCategory.nonErotic => 'A Quiet Harbour',
      ListorCategory.nonEroticPoetry => 'Quiet Verses',
      ListorCategory.romance => 'Paper Moons',
      _ => '${category.label} Story',
    };
    return StoryFeedPage(
      hasMore: page == 0,
      items: [
        for (var index = 0; index < 8; index++)
          ListorItem(
            id: category.id * 1000 + feed.index * 100 + page * 10 + index,
            title: index == 0
                ? page == 0
                      ? baseTitle
                      : '$baseTitle · page ${page + 1}'
                : '$baseTitle ${page * 8 + index + 1}',
            description: 'A story supplied by the test repository.',
            category: category,
            author: 'Test Author',
            approvedAt: DateTime(2026, 9, 25),
            favoriteCount: feed.index + 1,
            rating: 4.5,
            url: Uri.parse('https://www.literotica.com/s/test-story'),
          ),
      ],
    );
  }

  @override
  Future<List<StoryTag>> fetchTags(
    ListorCategory category,
    StoryPeriod period,
  ) async => const [
    StoryTag(id: 1189, label: 'mystery'),
    StoryTag(id: 547, label: 'adventure'),
    StoryTag(id: 185, label: 'love'),
  ];

  @override
  Future<StoryDocument> fetchStory(ListorItem story) async {
    return const StoryDocument(
      pages: [
        '<p><strong>Opening line</strong></p>\n\n'
            'Second paragraph with <em>emphasis</em>.',
      ],
    );
  }
}
