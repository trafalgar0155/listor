import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'literotica_api.dart';
import 'local_story_store.dart';

class ReadingHistoryEntry {
  const ReadingHistoryEntry({
    required this.story,
    required this.pageIndex,
    required this.pageCount,
    required this.lastReadAt,
  });

  final ListorItem story;
  final int pageIndex;
  final int pageCount;
  final DateTime lastReadAt;

  ReadingHistoryEntry copyWith({
    int? pageIndex,
    int? pageCount,
    DateTime? lastReadAt,
  }) {
    return ReadingHistoryEntry(
      story: story,
      pageIndex: pageIndex ?? this.pageIndex,
      pageCount: pageCount ?? this.pageCount,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}

abstract interface class ReadingHistoryRepository {
  Future<List<ReadingHistoryEntry>> readAll();
  Future<void> save(ReadingHistoryEntry entry);
  Future<void> remove(int storyId);
  Future<void> clear();
}

class SqliteReadingHistoryRepository implements ReadingHistoryRepository {
  SqliteReadingHistoryRepository({StoryDatabaseService? database})
    : _database = database ?? StoryDatabaseService();

  final StoryDatabaseService _database;

  @override
  Future<List<ReadingHistoryEntry>> readAll() async {
    final database = await _database.database;
    final rows = await database.query(
      StoryDatabaseService.readingHistoryTable,
      orderBy: 'last_read_at DESC',
    );
    return rows
        .map(
          (row) => ReadingHistoryEntry(
            story: storyFromRow(row),
            pageIndex: row['page_index']! as int,
            pageCount: row['page_count']! as int,
            lastReadAt: DateTime.fromMillisecondsSinceEpoch(
              row['last_read_at']! as int,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> save(ReadingHistoryEntry entry) async {
    final database = await _database.database;
    await database.insert(
      StoryDatabaseService.readingHistoryTable,
      {
        ...storyValues(entry.story),
        'page_index': entry.pageIndex,
        'page_count': entry.pageCount,
        'last_read_at': entry.lastReadAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(int storyId) async {
    final database = await _database.database;
    await database.delete(
      StoryDatabaseService.readingHistoryTable,
      where: 'id = ?',
      whereArgs: [storyId],
    );
  }

  @override
  Future<void> clear() async {
    final database = await _database.database;
    await database.delete(StoryDatabaseService.readingHistoryTable);
  }
}

class ReadingHistoryViewModel extends ChangeNotifier {
  ReadingHistoryViewModel(this._repository);

  final ReadingHistoryRepository _repository;
  final List<ReadingHistoryEntry> _entries = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _loadError;
  Future<void>? _loadOperation;
  Future<void> _writeQueue = Future.value();

  List<ReadingHistoryEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;

  ReadingHistoryEntry? entryFor(int storyId) {
    for (final entry in _entries) {
      if (entry.story.id == storyId) return entry;
    }
    return null;
  }

  Future<void> load() {
    if (_hasLoaded) return Future.value();
    final existing = _loadOperation;
    if (existing != null) return existing;
    return _loadOperation = _load();
  }

  Future<void> _load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _entries
        ..clear()
        ..addAll(await _repository.readAll());
      _hasLoaded = true;
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoading = false;
      _loadOperation = null;
      notifyListeners();
    }
  }

  Future<int> resumePage(int storyId, int pageCount) async {
    await load();
    final saved = entryFor(storyId)?.pageIndex ?? 0;
    if (pageCount <= 0) return 0;
    return saved.clamp(0, pageCount - 1).toInt();
  }

  Future<void> record(
    ListorItem story, {
    required int pageIndex,
    required int pageCount,
    DateTime? readAt,
  }) async {
    await load();
    final safeCount = pageCount < 1 ? 1 : pageCount;
    final safePage = pageIndex.clamp(0, safeCount - 1).toInt();
    final entry = ReadingHistoryEntry(
      story: story,
      pageIndex: safePage,
      pageCount: safeCount,
      lastReadAt: readAt ?? DateTime.now(),
    );
    _entries.removeWhere((item) => item.story.id == story.id);
    _entries.insert(0, entry);
    notifyListeners();
    await _enqueueWrite(() => _repository.save(entry));
  }

  Future<ReadingHistoryEntry?> remove(int storyId) async {
    await load();
    final index = _entries.indexWhere((entry) => entry.story.id == storyId);
    if (index < 0) return null;
    final removed = _entries.removeAt(index);
    notifyListeners();
    await _enqueueWrite(() => _repository.remove(storyId));
    return removed;
  }

  Future<void> restore(ReadingHistoryEntry entry) async {
    await load();
    _entries.removeWhere((item) => item.story.id == entry.story.id);
    _entries.add(entry);
    _entries.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    notifyListeners();
    await _enqueueWrite(() => _repository.save(entry));
  }

  Future<void> clear() async {
    await load();
    _entries.clear();
    notifyListeners();
    await _enqueueWrite(_repository.clear);
  }

  Future<void> _enqueueWrite(Future<void> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.catchError((_) {});
    return result;
  }
}
