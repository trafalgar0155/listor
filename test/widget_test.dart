import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listor/favorites.dart';
import 'package:listor/literotica_api.dart';
import 'package:listor/local_story_store.dart';
import 'package:listor/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeStoryRepository repository;
  late _FakeSavedStoriesRepository savedStoriesRepository;
  late _FakeFavoritesRepository favoritesRepository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeStoryRepository();
    savedStoriesRepository = _FakeSavedStoriesRepository();
    favoritesRepository = _FakeFavoritesRepository();
  });

  ListorApp buildApp() => ListorApp(
    repository: repository,
    savedStoriesRepository: savedStoriesRepository,
    favoritesRepository: favoritesRepository,
  );

  testWidgets('shows a filter action and all feed tabs', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('Listor'), findsOneWidget);
    expect(find.byKey(const Key('category-filter')), findsNothing);
    expect(find.byKey(const Key('filter-fab')), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Random'), findsOneWidget);
    final storyDate = find.byKey(const Key('story-date-35000'));
    expect(storyDate, findsOneWidget);
    final dateText = tester.widget<Text>(storyDate);
    final localizations = MaterialLocalizations.of(tester.element(storyDate));
    expect(
      dateText.data,
      localizations.formatMediumDate(DateTime(2026, 9, 25)),
    );
    expect(find.byKey(const Key('explore-destination')), findsOneWidget);
    expect(find.byKey(const Key('search-destination')), findsOneWidget);
    expect(find.byKey(const Key('favorites-destination')), findsOneWidget);
  });

  testWidgets('searches stories and filters by category', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-destination')));
    await tester.pumpAndSettle();
    expect(find.text('Find a story'), findsOneWidget);
    expect(find.byKey(const Key('story-search-field')), findsOneWidget);
    expect(find.byKey(const Key('search-category-filter')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('story-search-field')),
      'Harbour',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repository.searchRequests.last.query, 'Harbour');
    expect(repository.searchRequests.last.category, ListorCategory.nonErotic);
    expect(find.text('Harbour Search Result'), findsOneWidget);
    expect(find.byKey(const Key('story-search-results')), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non-Erotic Poetry').last);
    await tester.pumpAndSettle();

    expect(repository.searchRequests.last.query, 'Harbour');
    expect(
      repository.searchRequests.last.category,
      ListorCategory.nonEroticPoetry,
    );
    expect(find.text('NON-EROTIC POETRY'), findsOneWidget);

    await tester.tap(find.text('Harbour Search Result'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story-reader')), findsOneWidget);
  });

  testWidgets('applies category, period, and multi-select tag filters', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
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
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('Paper Moons'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Romance'), findsOneWidget);
  });

  testWidgets('feed tabs can be changed with a horizontal swipe', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
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
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(
      repository.requests.where(
        (request) => request.feed == FeedType.newest && request.page == 1,
      ),
      isEmpty,
    );

    final listFinder = find.byKey(const Key('feed-list-newest'));
    final scrollableFinder = find.descendant(
      of: listFinder,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollableFinder).position;
    final initialExtent = position.maxScrollExtent;
    await tester.fling(listFinder, const Offset(0, -1000), 1400);
    await tester.pumpAndSettle();

    expect(
      repository.requests.any(
        (request) => request.feed == FeedType.newest && request.page == 1,
      ),
      isTrue,
    );
    final appendedExtent = position.maxScrollExtent;
    expect(appendedExtent, greaterThan(initialExtent));
  });

  testWidgets('hides navigation chrome while scrolling down', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final listFinder = find.byKey(const Key('feed-list-newest'));
    final navigation = find.byKey(const Key('bottom-navigation-shell'));
    expect(tester.getSize(navigation).height, greaterThan(0));

    await tester.fling(listFinder, const Offset(0, -700), 1200);
    await tester.pumpAndSettle();
    expect(tester.getSize(navigation).height, 0);
    expect(find.text('New'), findsOneWidget);

    await tester.fling(listFinder, const Offset(0, 350), 900);
    await tester.pumpAndSettle();
    expect(tester.getSize(navigation).height, greaterThan(0));
  });

  testWidgets('opens a formatted story reader when a card is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('A Quiet Harbour'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-reader')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('story-app-bar-title'))).data,
      'A Quiet Harbour',
    );
    final readerDate = find.byKey(const Key('story-reader-date'));
    expect(readerDate, findsOneWidget);
    final localizations = MaterialLocalizations.of(tester.element(readerDate));
    final readerDateText = find.descendant(
      of: readerDate,
      matching: find.byType(Text),
    );
    expect(
      tester.widget<Text>(readerDateText).textSpan?.toPlainText().trim(),
      contains(localizations.formatMediumDate(DateTime(2026, 9, 25))),
    );
    expect(find.byKey(const Key('story-series')), findsNothing);
    final readerCategory = find.descendant(
      of: find.byKey(const Key('story-reader-category')),
      matching: find.byType(Text),
    );
    expect(
      tester.widget<Text>(readerCategory).textSpan?.toPlainText(),
      contains('Non Erotic'),
    );
    final readerFavorite = find.byKey(const Key('story-reader-favorite'));
    expect(readerFavorite, findsOneWidget);
    expect(
      tester.widget<IconButton>(readerFavorite).tooltip,
      'Add to favourites',
    );
    await tester.tap(readerFavorite);
    await tester.pump();
    expect(favoritesRepository.stories.map((story) => story.id), [35000]);
    expect(
      tester.widget<IconButton>(readerFavorite).tooltip,
      'Remove from favourites',
    );
    final html = tester.widget<Html>(find.byType(Html));
    expect(html.data, contains('<strong>Opening line</strong>'));
    expect(html.data, contains('<em>emphasis</em>'));

    await tester.tap(find.byKey(const Key('story-author-link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('author-works-page')), findsOneWidget);
  });

  testWidgets('opens an author’s series and standalone stories', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('author-35000')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('author-works-page')), findsOneWidget);
    expect(find.text('Test Author'), findsWidgets);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('Stories'), findsOneWidget);
    expect(find.text('Harbour Lights'), findsOneWidget);
    expect(find.text('A Standalone Work'), findsOneWidget);
    expect(find.text('NON EROTIC'), findsOneWidget);
    expect(find.text(' 4.4  •  6'), findsOneWidget);
    expect(find.text('Harbour Lights Ch. 01'), findsNothing);

    await tester.tap(find.byKey(const Key('author-series-900')));
    await tester.pumpAndSettle();
    expect(find.text('Harbour Lights Ch. 01'), findsOneWidget);
    expect(find.text('Harbour Lights Ch. 02'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('author-story-902'))).dy -
          tester.getBottomLeft(find.byKey(const Key('author-story-901'))).dy,
      6,
    );

    await tester.tap(find.byKey(const Key('author-story-901')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story-reader')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('story-app-bar-title'))).data,
      'Harbour Lights Ch. 01',
    );
    expect(find.byKey(const Key('story-series')), findsOneWidget);
    expect(find.textContaining('Harbour Lights · Part 1'), findsOneWidget);
  });

  testWidgets('queues every story when downloading a series', (tester) async {
    final seriesDownload = Completer<StoryDocument>();
    repository.storyResponse = seriesDownload;
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('author-35000')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('download-series-900')));
    await tester.pump();

    expect(savedStoriesRepository.downloads, hasLength(2));
    expect(
      savedStoriesRepository.downloads.map((download) => download.story.id),
      [901, 902],
    );
    expect(find.byTooltip('Series download in progress'), findsOneWidget);

    seriesDownload.complete(
      const StoryDocument(pages: ['<p>Downloaded series story.</p>']),
    );
    await tester.pumpAndSettle();

    expect(savedStoriesRepository.downloads, isEmpty);
    expect(
      savedStoriesRepository.stories.map((story) => story.id),
      containsAll([901, 902]),
    );
    expect(find.byTooltip('Series downloaded'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorites-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('downloads-action')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('saved-series-900')), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('Harbour Lights'), findsOneWidget);
    expect(find.text('Harbour Lights Ch. 01'), findsNothing);
    await tester.tap(find.byKey(const Key('saved-series-900')));
    await tester.pumpAndSettle();
    expect(find.text('Harbour Lights Ch. 01'), findsOneWidget);
    expect(find.text('Harbour Lights Ch. 02'), findsOneWidget);
  });

  testWidgets('favourites stories, series, and author from an author page', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('author-35000')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('favorite-author')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('favorite-series-900')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('author-series-900')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite-story-901')));
    await tester.pump();
    expect(find.text('Added to favourites'), findsOneWidget);

    final standaloneSave = find.byKey(const Key('favorite-story-903'));
    final authorWorksScrollable = find.descendant(
      of: find.byKey(const Key('author-works-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      standaloneSave,
      200,
      scrollable: authorWorksScrollable,
    );
    await tester.tap(standaloneSave);
    await tester.pump();

    expect(favoritesRepository.stories.map((story) => story.id), [903, 901]);
    expect(favoritesRepository.series.single.id, 900);
    expect(favoritesRepository.authors, ['Test Author']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorites-destination')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('favorite-stories-list')), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Series'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('favorite-series-900')), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Author'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('favorite-author-Test Author')),
      findsOneWidget,
    );
  });

  testWidgets('lays out without errors at phone width', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses mobile typography and supports large system text', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('A Quiet Harbour'));
    final description = tester.widget<Text>(
      find.text('A story supplied by the test repository.').first,
    );
    final author = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('author-35000')),
        matching: find.text('Test Author'),
      ),
    );
    final textTheme = Theme.of(
      tester.element(find.text('A Quiet Harbour')),
    ).textTheme;

    expect(title.style?.fontSize, textTheme.titleMedium?.fontSize);
    expect(description.style?.fontSize, textTheme.bodyMedium?.fontSize);
    expect(author.style?.fontSize, textTheme.labelLarge?.fontSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('downloads a favourite separately for offline reading', (
    tester,
  ) async {
    final storyDownload = Completer<StoryDocument>();
    repository.storyResponse = storyDownload;
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('favorite-story-35000')));
    await tester.pump();
    expect(favoritesRepository.stories, hasLength(1));
    expect(savedStoriesRepository.downloads, isEmpty);

    await tester.tap(find.byKey(const Key('favorites-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('download-story-35000')));
    await tester.pump();
    expect(savedStoriesRepository.stories, isEmpty);
    expect(savedStoriesRepository.downloads, hasLength(1));
    expect(find.byTooltip('Downloading story'), findsOneWidget);

    await tester.tap(find.byKey(const Key('downloads-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Downloads'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Queue'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('downloads-list')), findsOneWidget);
    expect(find.text('A Quiet Harbour'), findsOneWidget);
    expect(find.text('Downloading for offline use…'), findsOneWidget);

    storyDownload.complete(
      const StoryDocument(
        pages: [
          '<p><strong>Opening line</strong></p>\n\n'
              'Second paragraph with <em>emphasis</em>.',
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No active downloads'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Downloaded'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved-stories-list')), findsOneWidget);
    expect(find.text('A Quiet Harbour'), findsOneWidget);

    await tester.tap(find.text('A Quiet Harbour'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story-reader')), findsOneWidget);
    expect(repository.storyFetchCount, 1);
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
  final searchRequests =
      <({String query, ListorCategory category, int page})>[];
  int storyFetchCount = 0;
  Completer<StoryDocument>? storyResponse;

  @override
  Future<AuthorWorks> fetchAuthorWorks(String author) async => AuthorWorks(
    author: author,
    series: [
      AuthorSeries(
        id: 900,
        title: 'Harbour Lights',
        description: 'A connected series.',
        stories: [
          ListorItem(
            id: 901,
            title: 'Harbour Lights Ch. 01',
            description: 'The first chapter.',
            category: ListorCategory.nonErotic,
            author: author,
            approvedAt: DateTime(2026, 9, 20),
            favoriteCount: 4,
            rating: 4.2,
            url: Uri.parse('https://www.literotica.com/s/harbour-lights-1'),
            seriesId: 900,
            seriesTitle: 'Harbour Lights',
            seriesPosition: 0,
          ),
          ListorItem(
            id: 902,
            title: 'Harbour Lights Ch. 02',
            description: 'The second chapter.',
            category: ListorCategory.nonErotic,
            author: author,
            approvedAt: DateTime(2026, 9, 21),
            favoriteCount: 5,
            rating: 4.3,
            url: Uri.parse('https://www.literotica.com/s/harbour-lights-2'),
            seriesId: 900,
            seriesTitle: 'Harbour Lights',
            seriesPosition: 1,
          ),
        ],
      ),
    ],
    stories: [
      ListorItem(
        id: 903,
        title: 'A Standalone Work',
        description: 'Not part of a series.',
        category: ListorCategory.nonErotic,
        author: author,
        approvedAt: DateTime(2026, 9, 22),
        favoriteCount: 6,
        rating: 4.4,
        url: Uri.parse('https://www.literotica.com/s/a-standalone-work'),
      ),
    ],
  );

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
  Future<StoryFeedPage> searchStories(
    String query,
    ListorCategory category, {
    int page = 0,
  }) async {
    searchRequests.add((query: query, category: category, page: page));
    return StoryFeedPage(
      hasMore: false,
      items: [
        ListorItem(
          id: 80000 + category.id + page,
          title: '$query Search Result',
          description: 'A matching story.',
          category: category,
          author: 'Search Author',
          approvedAt: DateTime(2026, 9, 25),
          favoriteCount: 9,
          rating: 4.7,
          url: Uri.parse('https://www.literotica.com/s/search-result'),
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
    storyFetchCount++;
    final response = storyResponse;
    if (response != null) return response.future;
    return const StoryDocument(
      pages: [
        '<p><strong>Opening line</strong></p>\n\n'
            'Second paragraph with <em>emphasis</em>.',
      ],
    );
  }
}

class _FakeFavoritesRepository implements FavoritesRepository {
  final stories = <ListorItem>[];
  final series = <AuthorSeries>[];
  final authors = <String>[];

  @override
  Future<List<String>> readAuthors() async => List.of(authors);

  @override
  Future<List<AuthorSeries>> readSeries() async => List.of(series);

  @override
  Future<List<ListorItem>> readStories() async => List.of(stories);

  @override
  Future<void> removeAuthor(String author) async => authors.remove(author);

  @override
  Future<void> removeSeries(int seriesId) async {
    series.removeWhere((item) => item.id == seriesId);
  }

  @override
  Future<void> removeStory(int storyId) async {
    stories.removeWhere((story) => story.id == storyId);
  }

  @override
  Future<void> saveAuthor(String author) async {
    authors.remove(author);
    authors.insert(0, author);
  }

  @override
  Future<void> saveSeries(AuthorSeries value) async {
    series.removeWhere((item) => item.id == value.id);
    series.insert(0, value);
  }

  @override
  Future<void> saveStory(ListorItem story) async {
    stories.removeWhere((item) => item.id == story.id);
    stories.insert(0, story);
  }
}

class _FakeSavedStoriesRepository implements SavedStoriesRepository {
  final stories = <ListorItem>[];
  final documents = <int, StoryDocument>{};
  final downloads = <StoryDownload>[];

  @override
  Future<bool> contains(int storyId) async {
    return stories.any((story) => story.id == storyId);
  }

  @override
  Future<List<ListorItem>> readAll() async => List.of(stories);

  @override
  Future<List<StoryDownload>> readDownloads() async => List.of(downloads);

  @override
  Future<StoryDocument?> readDocument(int storyId) async => documents[storyId];

  @override
  Future<void> remove(int storyId) async {
    stories.removeWhere((story) => story.id == storyId);
    documents.remove(storyId);
  }

  @override
  Future<void> enqueueDownload(ListorItem story) async {
    if (downloads.any((download) => download.story.id == story.id)) return;
    downloads.add(
      StoryDownload(story: story, status: StoryDownloadStatus.queued),
    );
  }

  @override
  Future<void> removeDownload(int storyId) async {
    downloads.removeWhere((download) => download.story.id == storyId);
  }

  @override
  Future<void> save(ListorItem story, StoryDocument document) async {
    stories.removeWhere((existing) => existing.id == story.id);
    stories.insert(0, story);
    documents[story.id] = document;
  }

  @override
  Future<void> updateDownload(
    int storyId,
    StoryDownloadStatus status, {
    String? error,
  }) async {
    final index = downloads.indexWhere(
      (download) => download.story.id == storyId,
    );
    if (index < 0) return;
    downloads[index] = downloads[index].copyWith(status: status, error: error);
  }
}
