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
  });
}

class _FailingStoryRepository implements StoryRepository {
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
);

const _document = StoryDocument(
  pages: [
    '<p><strong>Opening line</strong></p>',
    '<p>Second page with <em>formatting</em>.</p>',
  ],
);
