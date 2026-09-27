import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'literotica_api.dart';

enum StoryDownloadStatus { queued, downloading, failed }

class StoryDownload {
  const StoryDownload({required this.story, required this.status, this.error});

  final ListorItem story;
  final StoryDownloadStatus status;
  final String? error;

  StoryDownload copyWith({StoryDownloadStatus? status, String? error}) {
    return StoryDownload(
      story: story,
      status: status ?? this.status,
      error: error,
    );
  }
}

enum SaveRequestResult { queued, removed, alreadyQueued }

abstract interface class SavedStoriesRepository {
  Future<List<ListorItem>> readAll();

  Future<List<StoryDownload>> readDownloads();

  Future<bool> contains(int storyId);

  Future<StoryDocument?> readDocument(int storyId);

  Future<void> save(ListorItem story, StoryDocument document);

  Future<void> remove(int storyId);

  Future<void> enqueueDownload(ListorItem story);

  Future<void> updateDownload(
    int storyId,
    StoryDownloadStatus status, {
    String? error,
  });

  Future<void> removeDownload(int storyId);
}

class StoryDatabaseService {
  StoryDatabaseService({DatabaseFactory? databaseFactory, this.databasePath})
    : _databaseFactory = databaseFactory ?? databaseFactorySqflitePlugin;

  static const _databaseName = 'listor.db';
  static const _databaseVersion = 4;
  static const savedStoriesTable = 'saved_stories';
  static const storyPagesTable = 'story_pages';
  static const downloadsTable = 'downloads';

  final DatabaseFactory _databaseFactory;
  final String? databasePath;
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final path =
        databasePath ?? p.join(await getDatabasesPath(), _databaseName);
    return _database = await _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await _createSavedStoriesTable(database);
          await _createStoryPagesTable(database);
          await _createDownloadsTable(database);
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createStoryPagesTable(database);
          if (oldVersion < 3) await _createDownloadsTable(database);
          if (oldVersion < 4) {
            await _addSeriesColumns(
              database,
              includeDownloads: oldVersion >= 3,
            );
          }
        },
      ),
    );
  }

  static Future<void> _createSavedStoriesTable(Database database) {
    return database.execute('''
      CREATE TABLE $savedStoriesTable (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        author TEXT NOT NULL,
        approved_at INTEGER,
        favorite_count INTEGER NOT NULL,
        rating REAL,
        url TEXT NOT NULL,
        series_id INTEGER,
        series_title TEXT,
        series_position INTEGER,
        saved_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createStoryPagesTable(Database database) {
    return database.execute('''
      CREATE TABLE $storyPagesTable (
        story_id INTEGER NOT NULL,
        page_index INTEGER NOT NULL,
        html TEXT NOT NULL,
        PRIMARY KEY (story_id, page_index),
        FOREIGN KEY (story_id) REFERENCES $savedStoriesTable(id)
          ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createDownloadsTable(Database database) {
    return database.execute('''
      CREATE TABLE $downloadsTable (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        author TEXT NOT NULL,
        approved_at INTEGER,
        favorite_count INTEGER NOT NULL,
        rating REAL,
        url TEXT NOT NULL,
        series_id INTEGER,
        series_title TEXT,
        series_position INTEGER,
        status TEXT NOT NULL,
        error TEXT,
        queued_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _addSeriesColumns(
    Database database, {
    required bool includeDownloads,
  }) async {
    await database.execute(
      'ALTER TABLE $savedStoriesTable ADD COLUMN series_id INTEGER',
    );
    await database.execute(
      'ALTER TABLE $savedStoriesTable ADD COLUMN series_title TEXT',
    );
    await database.execute(
      'ALTER TABLE $savedStoriesTable ADD COLUMN series_position INTEGER',
    );
    if (includeDownloads) {
      await database.execute(
        'ALTER TABLE $downloadsTable ADD COLUMN series_id INTEGER',
      );
      await database.execute(
        'ALTER TABLE $downloadsTable ADD COLUMN series_title TEXT',
      );
      await database.execute(
        'ALTER TABLE $downloadsTable ADD COLUMN series_position INTEGER',
      );
    }
  }

  Future<List<Map<String, Object?>>> readSavedStories() async {
    final db = await database;
    return db.query(savedStoriesTable, orderBy: 'saved_at DESC');
  }

  Future<List<Map<String, Object?>>> readDownloads() async {
    final db = await database;
    return db.query(downloadsTable, orderBy: 'queued_at ASC');
  }

  Future<bool> containsSavedStory(int storyId) async {
    final db = await database;
    final rows = await db.query(
      savedStoriesTable,
      columns: const ['id'],
      where: 'id = ?',
      whereArgs: [storyId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<String>> readStoryPages(int storyId) async {
    final db = await database;
    final rows = await db.query(
      storyPagesTable,
      columns: const ['html'],
      where: 'story_id = ?',
      whereArgs: [storyId],
      orderBy: 'page_index ASC',
    );
    return rows.map((row) => row['html']! as String).toList(growable: false);
  }

  Future<void> upsertSavedStory(
    Map<String, Object?> values,
    List<String> pages,
  ) async {
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.insert(
        savedStoriesTable,
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.delete(
        storyPagesTable,
        where: 'story_id = ?',
        whereArgs: [values['id']],
      );
      final batch = transaction.batch();
      for (var index = 0; index < pages.length; index++) {
        batch.insert(storyPagesTable, {
          'story_id': values['id'],
          'page_index': index,
          'html': pages[index],
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteSavedStory(int storyId) async {
    final db = await database;
    await db.delete(savedStoriesTable, where: 'id = ?', whereArgs: [storyId]);
  }

  Future<void> insertDownload(Map<String, Object?> values) async {
    final db = await database;
    await db.insert(
      downloadsTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> updateDownload(
    int storyId,
    StoryDownloadStatus status, {
    String? error,
  }) async {
    final db = await database;
    await db.update(
      downloadsTable,
      {'status': status.name, 'error': error},
      where: 'id = ?',
      whereArgs: [storyId],
    );
  }

  Future<void> deleteDownload(int storyId) async {
    final db = await database;
    await db.delete(downloadsTable, where: 'id = ?', whereArgs: [storyId]);
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}

class SqliteSavedStoriesRepository implements SavedStoriesRepository {
  SqliteSavedStoriesRepository({StoryDatabaseService? database})
    : _database = database ?? StoryDatabaseService();

  final StoryDatabaseService _database;
  int _lastQueuedAt = 0;

  @override
  Future<List<ListorItem>> readAll() async {
    final rows = await _database.readSavedStories();
    return rows.map(_storyFromRow).toList(growable: false);
  }

  @override
  Future<List<StoryDownload>> readDownloads() async {
    final rows = await _database.readDownloads();
    return rows
        .map((row) {
          final storedStatus = StoryDownloadStatus.values.firstWhere(
            (status) => status.name == row['status'],
            orElse: () => StoryDownloadStatus.queued,
          );
          return StoryDownload(
            story: _storyFromRow(row),
            status: storedStatus == StoryDownloadStatus.downloading
                ? StoryDownloadStatus.queued
                : storedStatus,
            error: row['error'] as String?,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<bool> contains(int storyId) => _database.containsSavedStory(storyId);

  @override
  Future<StoryDocument?> readDocument(int storyId) async {
    final pages = await _database.readStoryPages(storyId);
    return pages.isEmpty ? null : StoryDocument(pages: pages);
  }

  @override
  Future<void> save(ListorItem story, StoryDocument document) {
    return _database.upsertSavedStory({
      ..._storyValues(story),
      'saved_at': DateTime.now().millisecondsSinceEpoch,
    }, document.pages);
  }

  @override
  Future<void> remove(int storyId) => _database.deleteSavedStory(storyId);

  @override
  Future<void> enqueueDownload(ListorItem story) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final queuedAt = now > _lastQueuedAt ? now : _lastQueuedAt + 1;
    _lastQueuedAt = queuedAt;
    return _database.insertDownload({
      ..._storyValues(story),
      'status': StoryDownloadStatus.queued.name,
      'error': null,
      'queued_at': queuedAt,
    });
  }

  @override
  Future<void> updateDownload(
    int storyId,
    StoryDownloadStatus status, {
    String? error,
  }) => _database.updateDownload(storyId, status, error: error);

  @override
  Future<void> removeDownload(int storyId) => _database.deleteDownload(storyId);
}

class OfflineFirstStoryRepository implements StoryRepository {
  OfflineFirstStoryRepository(this._remote, this._local);

  final StoryRepository _remote;
  final SavedStoriesRepository _local;

  @override
  Future<AuthorWorks> fetchAuthorWorks(String author) =>
      _remote.fetchAuthorWorks(author);

  @override
  Future<StoryFeedPage> fetchFeed(
    StoryFilters filters,
    FeedType feed, {
    int page = 0,
  }) => _remote.fetchFeed(filters, feed, page: page);

  @override
  Future<List<StoryTag>> fetchTags(
    ListorCategory category,
    StoryPeriod period,
  ) => _remote.fetchTags(category, period);

  @override
  Future<StoryDocument> fetchStory(ListorItem story) async {
    final cached = await _local.readDocument(story.id);
    if (cached != null) return cached;

    final document = await _remote.fetchStory(story);
    if (await _local.contains(story.id)) {
      await _local.save(story, document);
    }
    return document;
  }
}

class SavedStoriesViewModel extends ChangeNotifier {
  SavedStoriesViewModel(this._repository, this._storyRepository);

  final SavedStoriesRepository _repository;
  final StoryRepository _storyRepository;
  final List<ListorItem> _stories = [];
  final List<StoryDownload> _downloads = [];
  final Set<int> _savedStoryIds = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isProcessingDownloads = false;
  Object? _loadError;
  Future<void>? _loadOperation;

  List<ListorItem> get stories => List.unmodifiable(_stories);
  List<AuthorSeries> get savedSeries {
    final grouped = <int, List<ListorItem>>{};
    for (final story in _stories) {
      final seriesId = story.seriesId;
      if (seriesId == null || story.seriesTitle?.isNotEmpty != true) continue;
      grouped.putIfAbsent(seriesId, () => []).add(story);
    }
    return [
      for (final entry in grouped.entries)
        AuthorSeries(
          id: entry.key,
          title: entry.value.first.seriesTitle!,
          description: '',
          stories: entry.value
            ..sort(
              (a, b) =>
                  (a.seriesPosition ?? 0).compareTo(b.seriesPosition ?? 0),
            ),
        ),
    ];
  }

  List<ListorItem> get standaloneStories => List.unmodifiable(
    _stories.where(
      (story) =>
          story.seriesId == null || story.seriesTitle?.isNotEmpty != true,
    ),
  );
  List<StoryDownload> get downloads => List.unmodifiable(_downloads);
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;
  bool isSaved(int storyId) => _savedStoryIds.contains(storyId);
  bool isSeriesSaved(AuthorSeries series) =>
      series.stories.isNotEmpty &&
      series.stories.every((story) => isSaved(story.id));
  bool isSeriesDownloading(AuthorSeries series) => series.stories.any((story) {
    final status = downloadFor(story.id)?.status;
    return status == StoryDownloadStatus.queued ||
        status == StoryDownloadStatus.downloading;
  });
  bool hasFailedSeriesDownload(AuthorSeries series) => series.stories.any(
    (story) => downloadFor(story.id)?.status == StoryDownloadStatus.failed,
  );
  StoryDownload? downloadFor(int storyId) {
    for (final download in _downloads) {
      if (download.story.id == storyId) return download;
    }
    return null;
  }

  Future<void> load() {
    if (_hasLoaded) return Future.value();
    final existing = _loadOperation;
    if (existing != null) return existing;
    final operation = _load();
    _loadOperation = operation;
    return operation;
  }

  Future<void> _load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.readAll(),
        _repository.readDownloads(),
      ]);
      final stories = results[0] as List<ListorItem>;
      final downloads = results[1] as List<StoryDownload>;
      _stories
        ..clear()
        ..addAll(stories);
      _downloads
        ..clear()
        ..addAll(downloads);
      _savedStoryIds
        ..clear()
        ..addAll(stories.map((story) => story.id));
      _hasLoaded = true;
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoading = false;
      _loadOperation = null;
      notifyListeners();
      if (_hasLoaded) _startDownloadProcessor();
    }
  }

  Future<SaveRequestResult> toggle(ListorItem story) async {
    await load();
    if (!_hasLoaded) throw StateError('Saved stories could not be loaded.');
    final existingIndex = _stories.indexWhere((item) => item.id == story.id);
    if (existingIndex >= 0) {
      await _repository.remove(story.id);
      _stories.removeAt(existingIndex);
      _savedStoryIds.remove(story.id);
      notifyListeners();
      return SaveRequestResult.removed;
    }

    final existingDownload = downloadFor(story.id);
    if (existingDownload != null) {
      if (existingDownload.status == StoryDownloadStatus.failed) {
        await retryDownload(story.id);
        return SaveRequestResult.queued;
      }
      return SaveRequestResult.alreadyQueued;
    }

    await _repository.enqueueDownload(story);
    _downloads.add(
      StoryDownload(story: story, status: StoryDownloadStatus.queued),
    );
    notifyListeners();
    _startDownloadProcessor();
    return SaveRequestResult.queued;
  }

  Future<int> downloadSeries(AuthorSeries series) async {
    await load();
    if (!_hasLoaded) throw StateError('Saved stories could not be loaded.');

    var queuedCount = 0;
    for (final story in series.stories) {
      if (_savedStoryIds.contains(story.id)) continue;
      final existing = downloadFor(story.id);
      if (existing == null) {
        await _repository.enqueueDownload(story);
        _downloads.add(
          StoryDownload(story: story, status: StoryDownloadStatus.queued),
        );
        queuedCount++;
      } else if (existing.status == StoryDownloadStatus.failed) {
        await _repository.updateDownload(story.id, StoryDownloadStatus.queued);
        final index = _downloads.indexWhere(
          (download) => download.story.id == story.id,
        );
        _downloads[index] = existing.copyWith(
          status: StoryDownloadStatus.queued,
        );
        queuedCount++;
      }
    }
    if (queuedCount > 0) {
      notifyListeners();
      _startDownloadProcessor();
    }
    return queuedCount;
  }

  Future<void> retryDownload(int storyId) async {
    final index = _downloads.indexWhere(
      (download) => download.story.id == storyId,
    );
    if (index < 0) return;
    await _repository.updateDownload(storyId, StoryDownloadStatus.queued);
    _downloads[index] = _downloads[index].copyWith(
      status: StoryDownloadStatus.queued,
    );
    notifyListeners();
    _startDownloadProcessor();
  }

  Future<void> removeDownload(int storyId) async {
    final index = _downloads.indexWhere(
      (download) => download.story.id == storyId,
    );
    if (index < 0 ||
        _downloads[index].status == StoryDownloadStatus.downloading) {
      return;
    }
    await _repository.removeDownload(storyId);
    _downloads.removeAt(index);
    notifyListeners();
  }

  void _startDownloadProcessor() {
    if (_isProcessingDownloads) return;
    _isProcessingDownloads = true;
    unawaited(_processDownloads());
  }

  Future<void> _processDownloads() async {
    try {
      while (true) {
        final index = _downloads.indexWhere(
          (download) => download.status == StoryDownloadStatus.queued,
        );
        if (index < 0) return;
        final story = _downloads[index].story;
        await _repository.updateDownload(
          story.id,
          StoryDownloadStatus.downloading,
        );
        final currentIndex = _downloads.indexWhere(
          (download) => download.story.id == story.id,
        );
        if (currentIndex < 0) continue;
        _downloads[currentIndex] = _downloads[currentIndex].copyWith(
          status: StoryDownloadStatus.downloading,
        );
        notifyListeners();

        try {
          final document = await _storyRepository.fetchStory(story);
          await _repository.save(story, document);
          await _repository.removeDownload(story.id);
          _downloads.removeWhere((download) => download.story.id == story.id);
          if (_savedStoryIds.add(story.id)) _stories.insert(0, story);
        } catch (error) {
          final currentIndex = _downloads.indexWhere(
            (download) => download.story.id == story.id,
          );
          if (currentIndex >= 0) {
            final message = error.toString();
            await _repository.updateDownload(
              story.id,
              StoryDownloadStatus.failed,
              error: message,
            );
            _downloads[currentIndex] = _downloads[currentIndex].copyWith(
              status: StoryDownloadStatus.failed,
              error: message,
            );
          }
        }
        notifyListeners();
      }
    } finally {
      _isProcessingDownloads = false;
      if (_downloads.any(
        (download) => download.status == StoryDownloadStatus.queued,
      )) {
        _startDownloadProcessor();
      }
    }
  }
}

Map<String, Object?> _storyValues(ListorItem story) {
  return {
    'id': story.id,
    'title': story.title,
    'description': story.description,
    'category_id': story.category.id,
    'author': story.author,
    'approved_at': story.approvedAt?.millisecondsSinceEpoch,
    'favorite_count': story.favoriteCount,
    'rating': story.rating,
    'url': story.url.toString(),
    'series_id': story.seriesId,
    'series_title': story.seriesTitle,
    'series_position': story.seriesPosition,
  };
}

ListorItem _storyFromRow(Map<String, Object?> row) {
  final categoryId = row['category_id']! as int;
  final category = ListorCategory.values.firstWhere(
    (candidate) => candidate.id == categoryId,
  );
  final approvedAt = row['approved_at'] as int?;
  return ListorItem(
    id: row['id']! as int,
    title: row['title']! as String,
    description: row['description']! as String,
    category: category,
    author: row['author']! as String,
    approvedAt: approvedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(approvedAt),
    favoriteCount: row['favorite_count']! as int,
    rating: (row['rating'] as num?)?.toDouble(),
    url: Uri.parse(row['url']! as String),
    seriesId: row['series_id'] as int?,
    seriesTitle: row['series_title'] as String?,
    seriesPosition: row['series_position'] as int?,
  );
}
