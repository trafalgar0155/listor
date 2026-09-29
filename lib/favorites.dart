import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'literotica_api.dart';
import 'local_story_store.dart';

abstract interface class FavoritesRepository {
  Future<List<ListorItem>> readStories();
  Future<List<AuthorSeries>> readSeries();
  Future<List<String>> readAuthors();
  Future<void> saveStory(ListorItem story);
  Future<void> removeStory(int storyId);
  Future<void> saveSeries(AuthorSeries series);
  Future<void> removeSeries(int seriesId);
  Future<void> saveAuthor(String author);
  Future<void> removeAuthor(String author);
}

class SqliteFavoritesRepository implements FavoritesRepository {
  SqliteFavoritesRepository({StoryDatabaseService? database})
    : _database = database ?? StoryDatabaseService();

  final StoryDatabaseService _database;

  @override
  Future<List<ListorItem>> readStories() async {
    final database = await _database.database;
    final rows = await database.query(
      StoryDatabaseService.favoriteStoriesTable,
      orderBy: 'favorited_at DESC',
    );
    return rows.map(storyFromRow).toList(growable: false);
  }

  @override
  Future<List<AuthorSeries>> readSeries() async {
    final database = await _database.database;
    final seriesRows = await database.query(
      StoryDatabaseService.favoriteSeriesTable,
      orderBy: 'favorited_at DESC',
    );
    final result = <AuthorSeries>[];
    for (final row in seriesRows) {
      final id = row['id']! as int;
      final storyRows = await database.query(
        StoryDatabaseService.favoriteSeriesStoriesTable,
        where: 'favorite_series_id = ?',
        whereArgs: [id],
        orderBy: 'series_position ASC, id ASC',
      );
      result.add(
        AuthorSeries(
          id: id,
          title: row['title']! as String,
          description: row['description']! as String,
          stories: storyRows.map(storyFromRow).toList(growable: false),
        ),
      );
    }
    return result;
  }

  @override
  Future<List<String>> readAuthors() async {
    final database = await _database.database;
    final rows = await database.query(
      StoryDatabaseService.favoriteAuthorsTable,
      orderBy: 'favorited_at DESC',
    );
    return rows.map((row) => row['author']! as String).toList(growable: false);
  }

  @override
  Future<void> saveStory(ListorItem story) async {
    final database = await _database.database;
    await database.insert(
      StoryDatabaseService.favoriteStoriesTable,
      {
        ...storyValues(story),
        'favorited_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeStory(int storyId) async {
    final database = await _database.database;
    await database.delete(
      StoryDatabaseService.favoriteStoriesTable,
      where: 'id = ?',
      whereArgs: [storyId],
    );
  }

  @override
  Future<void> saveSeries(AuthorSeries series) async {
    final database = await _database.database;
    await database.transaction((transaction) async {
      await transaction.insert(
        StoryDatabaseService.favoriteSeriesTable,
        {
          'id': series.id,
          'title': series.title,
          'description': series.description,
          'author': series.stories.firstOrNull?.author ?? '',
          'favorited_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.delete(
        StoryDatabaseService.favoriteSeriesStoriesTable,
        where: 'favorite_series_id = ?',
        whereArgs: [series.id],
      );
      final batch = transaction.batch();
      for (final story in series.stories) {
        batch.insert(StoryDatabaseService.favoriteSeriesStoriesTable, {
          'favorite_series_id': series.id,
          ...storyValues(story),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> removeSeries(int seriesId) async {
    final database = await _database.database;
    await database.delete(
      StoryDatabaseService.favoriteSeriesTable,
      where: 'id = ?',
      whereArgs: [seriesId],
    );
  }

  @override
  Future<void> saveAuthor(String author) async {
    final database = await _database.database;
    await database.insert(
      StoryDatabaseService.favoriteAuthorsTable,
      {'author': author, 'favorited_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeAuthor(String author) async {
    final database = await _database.database;
    await database.delete(
      StoryDatabaseService.favoriteAuthorsTable,
      where: 'author = ?',
      whereArgs: [author],
    );
  }
}

class FavoritesViewModel extends ChangeNotifier {
  FavoritesViewModel(this._repository);

  final FavoritesRepository _repository;
  final List<ListorItem> _stories = [];
  final List<AuthorSeries> _series = [];
  final List<String> _authors = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _loadError;
  Future<void>? _loadOperation;

  List<ListorItem> get stories => List.unmodifiable(_stories);
  List<AuthorSeries> get series => List.unmodifiable(_series);
  List<String> get authors => List.unmodifiable(_authors);
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;
  bool isStoryFavorite(int id) => _stories.any((story) => story.id == id);
  bool isSeriesFavorite(int id) => _series.any((series) => series.id == id);
  bool isAuthorFavorite(String author) => _authors.contains(author);

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
      final values = await Future.wait([
        _repository.readStories(),
        _repository.readSeries(),
        _repository.readAuthors(),
      ]);
      _stories
        ..clear()
        ..addAll(values[0] as List<ListorItem>);
      _series
        ..clear()
        ..addAll(values[1] as List<AuthorSeries>);
      _authors
        ..clear()
        ..addAll(values[2] as List<String>);
      _hasLoaded = true;
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoading = false;
      _loadOperation = null;
      notifyListeners();
    }
  }

  Future<bool> toggleStory(ListorItem story) async {
    await load();
    final index = _stories.indexWhere((item) => item.id == story.id);
    if (index >= 0) {
      await _repository.removeStory(story.id);
      _stories.removeAt(index);
      notifyListeners();
      return false;
    }
    await _repository.saveStory(story);
    _stories.insert(0, story);
    notifyListeners();
    return true;
  }

  Future<bool> toggleSeries(AuthorSeries series) async {
    await load();
    final index = _series.indexWhere((item) => item.id == series.id);
    if (index >= 0) {
      await _repository.removeSeries(series.id);
      _series.removeAt(index);
      notifyListeners();
      return false;
    }
    await _repository.saveSeries(series);
    _series.insert(0, series);
    notifyListeners();
    return true;
  }

  Future<bool> toggleAuthor(String author) async {
    await load();
    final index = _authors.indexOf(author);
    if (index >= 0) {
      await _repository.removeAuthor(author);
      _authors.removeAt(index);
      notifyListeners();
      return false;
    }
    await _repository.saveAuthor(author);
    _authors.insert(0, author);
    notifyListeners();
    return true;
  }
}
