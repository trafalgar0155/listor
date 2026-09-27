import 'package:flutter/foundation.dart';

import 'literotica_api.dart';

class StorySearchViewModel extends ChangeNotifier {
  StorySearchViewModel({
    required this.repository,
    this.category = ListorCategory.nonErotic,
  });

  final StoryRepository repository;

  final List<ListorItem> _stories = [];
  String _query = '';
  ListorCategory category;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  Object? _error;
  int _nextPage = 0;
  int _generation = 0;

  List<ListorItem> get stories => List.unmodifiable(_stories);
  String get query => _query;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  Object? get error => _error;

  Future<void> search(String query, {ListorCategory? inCategory}) async {
    final normalized = query.trim();
    final requestGeneration = ++_generation;
    _query = normalized;
    category = inCategory ?? category;
    _stories.clear();
    _error = null;
    _hasMore = false;
    _nextPage = 0;
    _isLoadingMore = false;
    if (normalized.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final result = await repository.searchStories(normalized, category);
      if (requestGeneration != _generation) return;
      _stories.addAll(result.items);
      _hasMore = result.hasMore;
      _nextPage = 1;
    } catch (error) {
      if (requestGeneration != _generation) return;
      _error = error;
    } finally {
      if (requestGeneration == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_query.isEmpty || !_hasMore || _isLoading || _isLoadingMore) return;
    final requestGeneration = _generation;
    final page = _nextPage;
    _isLoadingMore = true;
    _error = null;
    notifyListeners();
    try {
      final result = await repository.searchStories(
        _query,
        category,
        page: page,
      );
      if (requestGeneration != _generation) return;
      final existingIds = _stories.map((story) => story.id).toSet();
      _stories.addAll(result.items.where((story) => existingIds.add(story.id)));
      _hasMore = result.hasMore;
      _nextPage = page + 1;
    } catch (error) {
      if (requestGeneration != _generation) return;
      _error = error;
    } finally {
      if (requestGeneration == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() => search(_query, inCategory: category);

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
