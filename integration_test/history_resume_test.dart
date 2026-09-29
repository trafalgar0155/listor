import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:listor/favorites.dart';
import 'package:listor/literotica_api.dart';
import 'package:listor/reading_history.dart';
import 'package:listor/story_reader.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('continues a story at the last read page', (tester) async {
    final storyRepository = _StoryRepository();
    final favorites = FavoritesViewModel(_FavoritesRepository());
    final history = ReadingHistoryViewModel(_HistoryRepository());
    addTearDown(favorites.dispose);
    addTearDown(history.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: _HistoryHarness(
          storyRepository: storyRepository,
          favorites: favorites,
          history: history,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-history-story')));
    await tester.pumpAndSettle();
    final reader = find.byKey(const Key('story-reader'));
    final scrollable = find.descendant(
      of: reader,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    await tester.drag(reader, Offset(0, -position.maxScrollExtent));
    await tester.pumpAndSettle();
    expect(history.entryFor(42)?.pageIndex, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-history-story')));
    await tester.pumpAndSettle();

    final resumedScrollable = find.descendant(
      of: find.byKey(const Key('story-reader')),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(resumedScrollable).position.pixels,
      greaterThan(0),
    );
    expect(find.byKey(const Key('story-page-marker-1')), findsOneWidget);
    await binding.takeScreenshot('history-resumed-page-two');
  });
}

class _HistoryHarness extends StatelessWidget {
  const _HistoryHarness({
    required this.storyRepository,
    required this.favorites,
    required this.history,
  });

  final StoryRepository storyRepository;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-history-story'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StoryReaderPage(
                  story: _story,
                  repository: storyRepository,
                  favorites: favorites,
                  history: history,
                ),
              ),
            );
          },
          child: const Text('Open story'),
        ),
      ),
    );
  }
}

class _StoryRepository implements StoryRepository {
  @override
  Future<StoryDocument> fetchStory(ListorItem story) async => StoryDocument(
    pages: [
      List.filled(28, '<p>Long first page for simulator testing.</p>').join(),
      '<p>This is the resumed second page.</p>',
    ],
  );

  @override
  Future<AuthorWorks> fetchAuthorWorks(String author) async =>
      AuthorWorks(author: author, series: const [], stories: const []);

  @override
  Future<StoryFeedPage> fetchFeed(
    StoryFilters filters,
    FeedType feed, {
    int page = 0,
  }) async => const StoryFeedPage(items: [], hasMore: false);

  @override
  Future<List<StoryTag>> fetchTags(
    ListorCategory category,
    StoryPeriod period,
  ) async => const [];

  @override
  Future<StoryFeedPage> searchStories(
    String query,
    ListorCategory category, {
    int page = 0,
  }) async => const StoryFeedPage(items: [], hasMore: false);
}

class _HistoryRepository implements ReadingHistoryRepository {
  final entries = <ReadingHistoryEntry>[];

  @override
  Future<void> clear() async => entries.clear();

  @override
  Future<List<ReadingHistoryEntry>> readAll() async => List.of(entries);

  @override
  Future<void> remove(int storyId) async {
    entries.removeWhere((entry) => entry.story.id == storyId);
  }

  @override
  Future<void> save(ReadingHistoryEntry entry) async {
    entries.removeWhere((item) => item.story.id == entry.story.id);
    entries.insert(0, entry);
  }
}

class _FavoritesRepository implements FavoritesRepository {
  @override
  Future<List<String>> readAuthors() async => const [];

  @override
  Future<List<AuthorSeries>> readSeries() async => const [];

  @override
  Future<List<ListorItem>> readStories() async => const [];

  @override
  Future<void> removeAuthor(String author) async {}

  @override
  Future<void> removeSeries(int seriesId) async {}

  @override
  Future<void> removeStory(int storyId) async {}

  @override
  Future<void> saveAuthor(String author) async {}

  @override
  Future<void> saveSeries(AuthorSeries series) async {}

  @override
  Future<void> saveStory(ListorItem story) async {}
}

final _story = ListorItem(
  id: 42,
  title: 'A Two Page Story',
  description: 'A deterministic simulator story.',
  category: ListorCategory.nonErotic,
  author: 'Test Author',
  approvedAt: DateTime(2026, 9, 29),
  favoriteCount: 0,
  rating: 4.5,
  url: Uri.parse('https://www.literotica.com/s/two-page-story'),
);
