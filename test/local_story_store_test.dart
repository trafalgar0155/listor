import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:listor/literotica_api.dart';
import 'package:listor/local_story_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('SQLite saved story repository', () {
    late Directory temporaryDirectory;
    late String databasePath;
    late StoryDatabaseService database;
    late SqliteSavedStoriesRepository repository;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'listor-store-test-',
      );
      databasePath = p.join(temporaryDirectory.path, 'listor-test.db');
      database = StoryDatabaseService(
        databaseFactory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      repository = SqliteSavedStoriesRepository(database: database);
    });

    tearDown(() async {
      await database.close();
      await temporaryDirectory.delete(recursive: true);
    });

    test('persists and restores every story field', () async {
      await repository.save(_story, _document);
      await database.close();

      database = StoryDatabaseService(
        databaseFactory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      repository = SqliteSavedStoriesRepository(database: database);
      final restored = (await repository.readAll()).single;

      expect(restored.id, _story.id);
      expect(restored.title, _story.title);
      expect(restored.description, _story.description);
      expect(restored.category, _story.category);
      expect(restored.author, _story.author);
      expect(restored.approvedAt, _story.approvedAt);
      expect(restored.favoriteCount, _story.favoriteCount);
      expect(restored.rating, _story.rating);
      expect(restored.url, _story.url);
      expect(restored.seriesId, _story.seriesId);
      expect(restored.seriesTitle, _story.seriesTitle);
      expect(restored.seriesPosition, _story.seriesPosition);
      expect(
        (await repository.readDocument(_story.id))?.pages,
        _document.pages,
      );
    });

    test('updates an existing story instead of duplicating it', () async {
      await repository.save(_story, _document);
      await repository.save(
        ListorItem(
          id: _story.id,
          title: 'Updated title',
          description: _story.description,
          category: _story.category,
          author: _story.author,
          approvedAt: _story.approvedAt,
          favoriteCount: _story.favoriteCount,
          rating: _story.rating,
          url: _story.url,
        ),
        const StoryDocument(pages: ['<p>Updated story text.</p>']),
      );

      final stories = await repository.readAll();
      expect(stories, hasLength(1));
      expect(stories.single.title, 'Updated title');
      expect((await repository.readDocument(_story.id))?.pages, [
        '<p>Updated story text.</p>',
      ]);
    });

    test('removes a saved story', () async {
      await repository.save(_story, _document);
      await repository.remove(_story.id);
      expect(await repository.readAll(), isEmpty);
      expect(await repository.readDocument(_story.id), isNull);
    });

    test('reads a saved story without touching the network', () async {
      await repository.save(_story, _document);
      final offline = OfflineFirstStoryRepository(
        _FailingStoryRepository(),
        repository,
      );

      expect((await offline.fetchStory(_story)).pages, _document.pages);
    });

    test('persists the download queue and resumes interrupted work', () async {
      await repository.enqueueDownload(_story);
      await repository.updateDownload(
        _story.id,
        StoryDownloadStatus.downloading,
      );
      await database.close();

      database = StoryDatabaseService(
        databaseFactory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      repository = SqliteSavedStoriesRepository(database: database);
      final restored = (await repository.readDownloads()).single;

      expect(restored.story.title, _story.title);
      expect(restored.status, StoryDownloadStatus.queued);

      await repository.removeDownload(_story.id);
      expect(await repository.readDownloads(), isEmpty);
    });

    test('preserves series story order in the persistent queue', () async {
      final first = _storyWith(id: 100, title: 'Series Part 01');
      final second = _storyWith(id: 50, title: 'Series Part 02');
      await repository.enqueueDownload(first);
      await repository.enqueueDownload(second);
      await database.close();

      database = StoryDatabaseService(
        databaseFactory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      repository = SqliteSavedStoriesRepository(database: database);

      expect((await repository.readDownloads()).map((item) => item.story.id), [
        100,
        50,
      ]);
    });

    test('migrates version 3 data and adds series metadata columns', () async {
      await database.close();
      final legacy = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE saved_stories (
                id INTEGER PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                category_id INTEGER NOT NULL,
                author TEXT NOT NULL,
                approved_at INTEGER,
                favorite_count INTEGER NOT NULL,
                rating REAL,
                url TEXT NOT NULL,
                saved_at INTEGER NOT NULL
              )
            ''');
            await database.execute('''
              CREATE TABLE downloads (
                id INTEGER PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                category_id INTEGER NOT NULL,
                author TEXT NOT NULL,
                approved_at INTEGER,
                favorite_count INTEGER NOT NULL,
                rating REAL,
                url TEXT NOT NULL,
                status TEXT NOT NULL,
                error TEXT,
                queued_at INTEGER NOT NULL
              )
            ''');
            await database.insert('saved_stories', {
              'id': 5,
              'title': 'Legacy Story',
              'description': 'Saved before series support.',
              'category_id': ListorCategory.nonErotic.id,
              'author': 'Legacy Author',
              'approved_at': null,
              'favorite_count': 0,
              'rating': null,
              'url': 'https://www.literotica.com/s/legacy-story',
              'saved_at': 1,
            });
          },
        ),
      );
      await legacy.close();

      database = StoryDatabaseService(
        databaseFactory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      repository = SqliteSavedStoriesRepository(database: database);
      final legacyStory = (await repository.readAll()).single;
      expect(legacyStory.title, 'Legacy Story');
      expect(legacyStory.seriesId, isNull);

      await repository.enqueueDownload(_story);
      final queued = (await repository.readDownloads()).single.story;
      expect(queued.seriesId, _story.seriesId);
      expect(queued.seriesTitle, _story.seriesTitle);
      expect(queued.seriesPosition, _story.seriesPosition);
    });
  });
}

ListorItem _storyWith({required int id, required String title}) => ListorItem(
  id: id,
  title: title,
  description: _story.description,
  category: _story.category,
  author: _story.author,
  approvedAt: _story.approvedAt,
  favoriteCount: _story.favoriteCount,
  rating: _story.rating,
  url: Uri.parse('https://www.literotica.com/s/series-part-$id'),
);

class _FailingStoryRepository implements StoryRepository {
  @override
  Future<AuthorWorks> fetchAuthorWorks(String author) =>
      throw StateError('Network should not be used.');

  @override
  Future<StoryFeedPage> fetchFeed(
    StoryFilters filters,
    FeedType feed, {
    int page = 0,
  }) => throw StateError('Network should not be used.');

  @override
  Future<StoryDocument> fetchStory(ListorItem story) =>
      throw StateError('Network should not be used.');

  @override
  Future<List<StoryTag>> fetchTags(
    ListorCategory category,
    StoryPeriod period,
  ) => throw StateError('Network should not be used.');

  @override
  Future<StoryFeedPage> searchStories(
    String query,
    ListorCategory category, {
    int page = 0,
  }) => throw StateError('Network should not be used.');
}

final _story = ListorItem(
  id: 42,
  title: 'A Quiet Harbour',
  description: 'A test story.',
  category: ListorCategory.nonErotic,
  author: 'Test Author',
  approvedAt: DateTime(2026, 9, 25, 10, 30),
  favoriteCount: 12,
  rating: 4.75,
  url: Uri.parse('https://www.literotica.com/s/a-quiet-harbour'),
  seriesId: 7,
  seriesTitle: 'Harbour Stories',
  seriesPosition: 1,
);

const _document = StoryDocument(
  pages: [
    '<p><strong>Opening line</strong></p>',
    '<p>Second page with <em>formatting</em>.</p>',
  ],
);
