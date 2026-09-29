import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'author_works.dart';
import 'favorites.dart';
import 'literotica_api.dart';
import 'local_story_store.dart';
import 'reading_history.dart';
import 'reading_history_view.dart';
import 'settings_page.dart';
import 'story_card.dart';
import 'story_reader.dart';
import 'story_search.dart';

class ListorHomePage extends StatefulWidget {
  const ListorHomePage({
    super.key,
    this.repository,
    this.savedStoriesRepository,
    this.favoritesRepository,
    this.historyRepository,
    required this.settings,
    required this.biometricAuthenticator,
  });

  final StoryRepository? repository;
  final SavedStoriesRepository? savedStoriesRepository;
  final FavoritesRepository? favoritesRepository;
  final ReadingHistoryRepository? historyRepository;
  final AppSettingsController settings;
  final BiometricAuthenticator biometricAuthenticator;

  @override
  State<ListorHomePage> createState() => _ListorHomePageState();
}

class _ListorHomePageState extends State<ListorHomePage> {
  static const _categoryPreferenceKey = 'selected_category';

  late final StoryRepository _repository;
  late final SavedStoriesViewModel _savedStories;
  late final FavoritesViewModel _favorites;
  late final ReadingHistoryViewModel _history;
  StoryFilters _filters = const StoryFilters();
  int _destinationIndex = 0;
  bool _showNavigation = true;

  @override
  void initState() {
    super.initState();
    final remoteRepository = widget.repository ?? LiteroticaApiClient();
    final database = StoryDatabaseService();
    final localRepository =
        widget.savedStoriesRepository ??
        SqliteSavedStoriesRepository(database: database);
    final favoritesRepository =
        widget.favoritesRepository ??
        SqliteFavoritesRepository(database: database);
    final historyRepository =
        widget.historyRepository ??
        SqliteReadingHistoryRepository(database: database);
    _repository = OfflineFirstStoryRepository(
      remoteRepository,
      localRepository,
    );
    _savedStories = SavedStoriesViewModel(localRepository, _repository);
    _favorites = FavoritesViewModel(favoritesRepository);
    _history = ReadingHistoryViewModel(
      historyRepository,
      enabled: widget.settings.historyEnabled,
    );
    unawaited(_savedStories.load());
    unawaited(_favorites.load());
    unawaited(_history.load());
    unawaited(_restoreCategory());
  }

  @override
  void dispose() {
    _savedStories.dispose();
    _favorites.dispose();
    _history.dispose();
    super.dispose();
  }

  Future<void> _restoreCategory() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_categoryPreferenceKey);
    if (!mounted || saved == null) return;
    for (final category in ListorCategory.values) {
      if (category.name == saved && category != _filters.category) {
        setState(() {
          _filters = StoryFilters(category: category);
        });
        return;
      }
    }
  }

  void _applyFilters(StoryFilters filters) {
    setState(() => _filters = filters);
    unawaited(_saveCategory(filters.category));
  }

  Future<void> _showFilters() async {
    final filters = await showModalBottomSheet<StoryFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _FilterSheet(initialValue: _filters, repository: _repository),
    );
    if (filters != null && mounted) _applyFilters(filters);
  }

  Future<void> _saveCategory(ListorCategory category) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_categoryPreferenceKey, category.name);
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final delta = notification is ScrollUpdateNotification
        ? notification.scrollDelta
        : null;
    if (notification.metrics.pixels > 0 && delta == null) return false;
    final shouldShow = notification.metrics.pixels <= 0 || delta! < 0;
    if (shouldShow != _showNavigation) {
      setState(() => _showNavigation = shouldShow);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isExploring = _destinationIndex == 0;
    final navigationHeight = 60 + MediaQuery.paddingOf(context).bottom;
    return DefaultTabController(
      length: FeedType.values.length,
      child: Scaffold(
        body: IndexedStack(
          index: _destinationIndex,
          children: [
            _ExploreView(
              filters: _filters,
              repository: _repository,
              savedStories: _savedStories,
              favorites: _favorites,
              history: _history,
              onScroll: _handleScroll,
            ),
            _SearchDestination(
              repository: _repository,
              savedStories: _savedStories,
              favorites: _favorites,
              history: _history,
              onScroll: _handleScroll,
            ),
            ReadingHistoryDestination(
              repository: _repository,
              savedStories: _savedStories,
              favorites: _favorites,
              history: _history,
              onScroll: _handleScroll,
            ),
            _FavoritesDestination(
              repository: _repository,
              savedStories: _savedStories,
              favorites: _favorites,
              history: _history,
              onScroll: _handleScroll,
            ),
            SettingsDestination(
              settings: widget.settings,
              history: _history,
              authenticator: widget.biometricAuthenticator,
            ),
          ],
        ),
        floatingActionButton: isExploring
            ? AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: _showNavigation ? Offset.zero : const Offset(0, 2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: _showNavigation ? 1 : 0,
                  child: FloatingActionButton.extended(
                    key: const Key('filter-fab'),
                    onPressed: _showNavigation ? _showFilters : null,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Filter'),
                  ),
                ),
              )
            : null,
        bottomNavigationBar: AnimatedContainer(
          key: const Key('bottom-navigation-shell'),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: _showNavigation ? navigationHeight : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: NavigationBar(
            height: 60,
            selectedIndex: _destinationIndex,
            onDestinationSelected: (index) {
              setState(() {
                _destinationIndex = index;
                _showNavigation = true;
              });
            },
            destinations: const [
              NavigationDestination(
                key: Key('explore-destination'),
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Explore',
              ),
              NavigationDestination(
                key: Key('search-destination'),
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.manage_search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                key: Key('history-destination'),
                icon: Icon(Icons.history_rounded),
                selectedIcon: Icon(Icons.history_toggle_off_rounded),
                label: 'History',
              ),
              NavigationDestination(
                key: Key('favorites-destination'),
                icon: Icon(Icons.favorite_border_rounded),
                selectedIcon: Icon(Icons.favorite_rounded),
                label: 'Favourites',
              ),
              NavigationDestination(
                key: Key('settings-destination'),
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _filterFingerprint(StoryFilters filters) {
  final tagIds = filters.tags.map((tag) => tag.id).toList()..sort();
  return '${filters.category.name}:${filters.period.name}:$tagIds';
}

class _ExploreView extends StatelessWidget {
  const _ExploreView({
    required this.filters,
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
    required this.onScroll,
  });

  final StoryFilters filters;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;
  final NotificationListenerCallback<ScrollNotification> onScroll;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: true,
            toolbarHeight: 48,
            titleSpacing: 16,
            title: Text(
              'Listor',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(44),
              child: SizedBox(height: 44, child: _FeedTabs()),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            for (final feed in FeedType.values)
              _FeedPage(
                key: ValueKey('${feed.name}:${_filterFingerprint(filters)}'),
                feed: feed,
                filters: filters,
                repository: repository,
                savedStories: savedStories,
                favorites: favorites,
                history: history,
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchDestination extends StatefulWidget {
  const _SearchDestination({
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
    required this.onScroll,
  });

  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;
  final NotificationListenerCallback<ScrollNotification> onScroll;

  @override
  State<_SearchDestination> createState() => _SearchDestinationState();
}

class _SearchDestinationState extends State<_SearchDestination> {
  late final StorySearchViewModel _viewModel;
  final _queryController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _viewModel = StorySearchViewModel(repository: widget.repository);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _scheduleSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _viewModel.search(query),
    );
  }

  void _searchNow(String query) {
    _debounce?.cancel();
    _viewModel.search(query);
  }

  void _clearSearch() {
    _debounce?.cancel();
    _queryController.clear();
    _viewModel.search('');
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: widget.onScroll,
      child: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            toolbarHeight: 48,
            titleSpacing: 16,
            title: Text(
              'Search',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
        ],
        body: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  children: [
                    TextField(
                      key: const Key('story-search-field'),
                      controller: _queryController,
                      textInputAction: TextInputAction.search,
                      autofocus: false,
                      onChanged: _scheduleSearch,
                      onSubmitted: _searchNow,
                      decoration: InputDecoration(
                        hintText: 'Search stories',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _viewModel.query.isEmpty
                            ? null
                            : IconButton(
                                key: const Key('clear-story-search'),
                                tooltip: 'Clear search',
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: const Color(0xFF0D1117),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ListorCategory>(
                      key: const Key('search-category-filter'),
                      initialValue: _viewModel.category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                        filled: true,
                        fillColor: Color(0xFF0D1117),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                      items: [
                        for (final category in ListorCategory.values)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category.label),
                          ),
                      ],
                      onChanged: (category) {
                        if (category == null) return;
                        _debounce?.cancel();
                        _viewModel.search(
                          _queryController.text,
                          inCategory: category,
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _SearchResults(
                  viewModel: _viewModel,
                  repository: widget.repository,
                  savedStories: widget.savedStories,
                  favorites: widget.favorites,
                  history: widget.history,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.viewModel,
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
  });

  final StorySearchViewModel viewModel;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;

  @override
  Widget build(BuildContext context) {
    if (viewModel.query.isEmpty) {
      return const _SearchMessage(
        icon: Icons.manage_search_rounded,
        title: 'Find a story',
        message: 'Enter a title or keyword and choose a category.',
      );
    }
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.error != null && viewModel.stories.isEmpty) {
      return Center(
        child: FilledButton.tonalIcon(
          key: const Key('retry-story-search'),
          onPressed: viewModel.retry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry search'),
        ),
      );
    }
    if (viewModel.stories.isEmpty) {
      return const _SearchMessage(
        icon: Icons.search_off_rounded,
        title: 'No stories found',
        message: 'Try another search or category.',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.extentAfter < 320) {
          unawaited(viewModel.loadMore());
        }
        return false;
      },
      child: ListView.separated(
        key: const Key('story-search-results'),
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
        itemCount: viewModel.stories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          if (index == viewModel.stories.length) {
            return _SearchFooter(viewModel: viewModel);
          }
          return _StoryCard(
            item: viewModel.stories[index],
            repository: repository,
            savedStories: savedStories,
            favorites: favorites,
            history: history,
          );
        },
      ),
    );
  }
}

class _SearchFooter extends StatelessWidget {
  const _SearchFooter({required this.viewModel});

  final StorySearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (viewModel.error != null && viewModel.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: FilledButton.tonalIcon(
            key: const Key('retry-more-search-results'),
            onPressed: viewModel.loadMore,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry loading more'),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8D98A5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesDestination extends StatelessWidget {
  const _FavoritesDestination({
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
    required this.onScroll,
  });

  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;
  final NotificationListenerCallback<ScrollNotification> onScroll;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: NotificationListener<ScrollNotification>(
        onNotification: onScroll,
        child: NestedScrollView(
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: true,
              toolbarHeight: 48,
              titleSpacing: 16,
              title: Text(
                'Favourites',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              actions: [
                ListenableBuilder(
                  listenable: savedStories,
                  builder: (context, _) => Badge.count(
                    count: savedStories.downloads.length,
                    isLabelVisible: savedStories.downloads.isNotEmpty,
                    child: IconButton(
                      key: const Key('downloads-action'),
                      tooltip: 'Downloads',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _DownloadsPage(
                              repository: repository,
                              savedStories: savedStories,
                              favorites: favorites,
                              history: history,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(44),
                child: SizedBox(
                  height: 44,
                  child: TabBar(
                    tabs: [
                      Tab(text: 'Stories'),
                      Tab(text: 'Series'),
                      Tab(text: 'Author'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: ListenableBuilder(
            listenable: favorites,
            builder: (context, _) {
              if (favorites.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (favorites.loadError != null) {
                return Center(
                  child: FilledButton.tonalIcon(
                    onPressed: favorites.load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry loading favourites'),
                  ),
                );
              }
              return TabBarView(
                children: [
                  _FavoriteStoriesView(
                    stories: favorites.stories,
                    repository: repository,
                    savedStories: savedStories,
                    favorites: favorites,
                    history: history,
                  ),
                  _FavoriteSeriesView(
                    series: favorites.series,
                    repository: repository,
                    savedStories: savedStories,
                    favorites: favorites,
                    history: history,
                  ),
                  _FavoriteAuthorsView(
                    authors: favorites.authors,
                    repository: repository,
                    savedStories: savedStories,
                    favorites: favorites,
                    history: history,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FavoriteStoriesView extends StatelessWidget {
  const _FavoriteStoriesView({
    required this.stories,
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
  });

  final List<ListorItem> stories;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const _FavoritesEmptyState(
        icon: Icons.favorite_border_rounded,
        message: 'No favourite stories yet',
      );
    }
    return ListView.separated(
      key: const Key('favorite-stories-list'),
      padding: const EdgeInsets.all(10),
      itemCount: stories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _StoryCard(
        item: stories[index],
        repository: repository,
        savedStories: savedStories,
        favorites: favorites,
        history: history,
        showDownloadAction: true,
      ),
    );
  }
}

class _FavoriteSeriesView extends StatelessWidget {
  const _FavoriteSeriesView({
    required this.series,
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
  });

  final List<AuthorSeries> series;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const _FavoritesEmptyState(
        icon: Icons.collections_bookmark_outlined,
        message: 'No favourite series yet',
      );
    }
    return ListView.separated(
      key: const Key('favorite-series-list'),
      padding: const EdgeInsets.all(10),
      itemCount: series.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _FavoriteSeriesCard(
        series: series[index],
        repository: repository,
        savedStories: savedStories,
        favorites: favorites,
        history: history,
      ),
    );
  }
}

class _FavoriteAuthorsView extends StatelessWidget {
  const _FavoriteAuthorsView({
    required this.authors,
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
  });

  final List<String> authors;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;

  @override
  Widget build(BuildContext context) {
    if (authors.isEmpty) {
      return const _FavoritesEmptyState(
        icon: Icons.person_outline_rounded,
        message: 'No favourite authors yet',
      );
    }
    return ListView.separated(
      key: const Key('favorite-authors-list'),
      padding: const EdgeInsets.all(10),
      itemCount: authors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final author = authors[index];
        return Card(
          child: ListTile(
            key: Key('favorite-author-$author'),
            leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
            title: Text(
              author,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: IconButton(
              tooltip: 'Remove author from favourites',
              onPressed: () => favorites.toggleAuthor(author),
              icon: const Icon(Icons.favorite_rounded),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AuthorWorksPage(
                    author: author,
                    repository: repository,
                    savedStories: savedStories,
                    favorites: favorites,
                    history: history,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FavoritesEmptyState extends StatelessWidget {
  const _FavoritesEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initialValue, required this.repository});

  final StoryFilters initialValue;
  final StoryRepository repository;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ListorCategory _category;
  late StoryPeriod _period;
  late Set<StoryTag> _tags;
  late Future<List<StoryTag>> _availableTags;

  @override
  void initState() {
    super.initState();
    _category = widget.initialValue.category;
    _period = widget.initialValue.period;
    _tags = {...widget.initialValue.tags};
    _availableTags = widget.repository.fetchTags(_category, _period);
  }

  void _reloadTags() {
    _tags.clear();
    _availableTags = widget.repository.fetchTags(_category, _period);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF263343))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF465260),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text(
                  'Filter stories',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FilterLabel('Category'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ListorCategory>(
                    key: const Key('category-dropdown'),
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF111821),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                    items: [
                      for (final category in ListorCategory.values)
                        DropdownMenuItem(
                          value: category,
                          child: Text(category.label),
                        ),
                    ],
                    onChanged: (category) {
                      if (category == null || category == _category) return;
                      setState(() {
                        _category = category;
                        _reloadTags();
                      });
                    },
                  ),
                  const SizedBox(height: 22),
                  const _FilterLabel('Published'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<StoryPeriod>(
                      key: const Key('period-selector'),
                      showSelectedIcon: false,
                      segments: [
                        for (final period in StoryPeriod.values)
                          ButtonSegment(
                            value: period,
                            label: Text(period.label),
                          ),
                      ],
                      selected: {_period},
                      onSelectionChanged: (selection) {
                        final period = selection.single;
                        if (period == _period) return;
                        setState(() {
                          _period = period;
                          _reloadTags();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _FilterLabel('Tags'),
                  const SizedBox(height: 3),
                  const Text(
                    'Choose one or more',
                    style: TextStyle(color: Color(0xFF7D8996)),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<StoryTag>>(
                    future: _availableTags,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          'Couldn’t load tags.',
                          style: TextStyle(color: Color(0xFFA2ACB7)),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final tags = [...snapshot.data!]
                        ..sort(
                          (a, b) => a.label.toLowerCase().compareTo(
                            b.label.toLowerCase(),
                          ),
                        );
                      return Wrap(
                        spacing: 8,
                        runSpacing: 7,
                        children: [
                          for (final tag in tags)
                            FilterChip(
                              key: Key('tag-${tag.id}'),
                              label: Text(tag.label),
                              selected: _tags.contains(tag),
                              onSelected: (selected) {
                                setState(() {
                                  selected ? _tags.add(tag) : _tags.remove(tag);
                                });
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: const Key('apply-filters'),
                onPressed: () => Navigator.pop(
                  context,
                  StoryFilters(
                    category: _category,
                    period: _period,
                    tags: Set.unmodifiable(_tags),
                  ),
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Apply filters'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _FeedTabs extends StatelessWidget {
  const _FeedTabs();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF18212C))),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF7D8996),
        labelStyle: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'New'),
          Tab(text: 'Popular'),
          Tab(text: 'Random'),
        ],
      ),
    );
  }
}

class _FeedPage extends StatefulWidget {
  const _FeedPage({
    super.key,
    required this.feed,
    required this.filters,
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
  });

  final FeedType feed;
  final StoryFilters filters;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;

  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage> {
  final List<ListorItem> _items = [];
  final Set<int> _storyIds = {};
  ScrollMetrics? _lastMetrics;

  int _nextPage = 0;
  int _generation = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMore());
  }

  void _maybeLoadMore(ScrollMetrics metrics) {
    _lastMetrics = metrics;
    if (metrics.extentAfter < 320) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      StoryFeedPage result;
      do {
        result = await widget.repository.fetchFeed(
          widget.filters,
          widget.feed,
          page: _nextPage,
        );
        if (!mounted || generation != _generation) return;
        _nextPage++;
        for (final item in result.items) {
          if (_storyIds.add(item.id)) _items.add(item);
        }
        _hasMore = result.hasMore;
      } while (result.items.isEmpty && _hasMore);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      _error = error;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final metrics = _lastMetrics;
          if (metrics != null) _maybeLoadMore(metrics);
        });
      }
    }
  }

  void _retry() {
    if (_items.isEmpty) {
      _generation++;
      _nextPage = 0;
      _hasMore = true;
      _storyIds.clear();
    }
    setState(() => _error = null);
    unawaited(_loadMore());
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return _ErrorState(onRetry: _retry);
    }
    if (_items.isEmpty && !_hasMore) return const _EmptyState();

    final showFooter = _isLoading || _error != null || _hasMore;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _maybeLoadMore(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _maybeLoadMore(notification.metrics);
          return false;
        },
        child: ListView.separated(
          key: Key('feed-list-${widget.feed.name}'),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 96),
          itemCount: _items.length + (showFooter ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            if (index == _items.length) {
              return _FeedFooter(
                isLoading: _isLoading,
                hasError: _error != null,
                onRetry: _retry,
              );
            }
            return _StoryCard(
              item: _items[index],
              repository: widget.repository,
              savedStories: widget.savedStories,
              favorites: widget.favorites,
              history: widget.history,
            );
          },
        ),
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  const _FeedFooter({
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Center(
        child: hasError
            ? TextButton.icon(
                key: const Key('retry-more-stories'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry loading more'),
              )
            : isLoading
            ? const SizedBox.square(
                key: Key('loading-more-stories'),
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.item,
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
    this.showDownloadAction = false,
  });

  final ListorItem item;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;
  final bool showDownloadAction;

  @override
  Widget build(BuildContext context) {
    return StoryCard(
      story: item,
      favorites: favorites,
      savedStories: savedStories,
      showDownloadAction: showDownloadAction,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoryReaderPage(
              story: item,
              repository: repository,
              favorites: favorites,
              history: history,
              onAuthorTap: () => _openAuthor(context),
            ),
          ),
        );
      },
      onAuthorTap: () => _openAuthor(context),
    );
  }

  void _openAuthor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthorWorksPage(
          author: item.author,
          repository: repository,
          savedStories: savedStories,
          favorites: favorites,
          history: history,
        ),
      ),
    );
  }
}

class _FavoriteSeriesCard extends StatelessWidget {
  const _FavoriteSeriesCard({
    required this.series,
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
  });

  final AuthorSeries series;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('favorite-series-${series.id}'),
        leading: const Icon(Icons.library_books_outlined),
        title: Row(
          children: [
            Expanded(
              child: Text(
                series.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Remove series from favourites',
              onPressed: () => favorites.toggleSeries(series),
              icon: const Icon(Icons.favorite_rounded),
            ),
            ListenableBuilder(
              listenable: savedStories,
              builder: (context, _) {
                final isDownloaded = savedStories.isSeriesSaved(series);
                final isDownloading = savedStories.isSeriesDownloading(series);
                return IconButton(
                  key: Key('download-favorite-series-${series.id}'),
                  tooltip: isDownloaded
                      ? 'Series downloaded'
                      : isDownloading
                      ? 'Series download in progress'
                      : 'Download series',
                  onPressed: isDownloaded || isDownloading
                      ? null
                      : () => savedStories.downloadSeries(series),
                  icon: Icon(
                    isDownloaded
                        ? Icons.download_done_rounded
                        : Icons.download_for_offline_outlined,
                  ),
                );
              },
            ),
          ],
        ),
        subtitle: Text(
          '${series.stories.length} ${series.stories.length == 1 ? 'story' : 'stories'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: [
          for (final story in series.stories)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _StoryCard(
                item: story,
                repository: repository,
                savedStories: savedStories,
                favorites: favorites,
                history: history,
                showDownloadAction: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _SavedStoriesView extends StatelessWidget {
  const _SavedStoriesView({
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
  });

  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: savedStories,
      builder: (context, _) {
        final stories = savedStories.stories;
        final series = savedStories.savedSeries;
        final standaloneStories = savedStories.standaloneStories;
        if (savedStories.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (savedStories.loadError != null) {
          return Center(
            child: FilledButton.tonalIcon(
              onPressed: savedStories.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry loading saved stories'),
            ),
          );
        }
        if (stories.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmarks_outlined, size: 42),
                  SizedBox(height: 14),
                  Text('No downloaded stories yet'),
                  SizedBox(height: 6),
                  Text(
                    'Stories appear here after their download finishes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF7D8996)),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          key: const Key('saved-stories-list'),
          padding: const EdgeInsets.all(10),
          children: [
            if (series.isNotEmpty) ...[
              _SavedSectionHeader(
                title: 'Series',
                count: series.length,
                icon: Icons.collections_bookmark_outlined,
              ),
              for (final item in series)
                _SavedSeriesCard(
                  series: item,
                  repository: repository,
                  savedStories: savedStories,
                  favorites: favorites,
                  history: history,
                ),
              const SizedBox(height: 12),
            ],
            if (standaloneStories.isNotEmpty) ...[
              _SavedSectionHeader(
                title: 'Stories',
                count: standaloneStories.length,
                icon: Icons.auto_stories_outlined,
              ),
              for (final story in standaloneStories) ...[
                _StoryCard(
                  item: story,
                  repository: repository,
                  savedStories: savedStories,
                  favorites: favorites,
                  history: history,
                  showDownloadAction: true,
                ),
                const SizedBox(height: 6),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _SavedSectionHeader extends StatelessWidget {
  const _SavedSectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Text('$count', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SavedSeriesCard extends StatelessWidget {
  const _SavedSeriesCard({
    required this.series,
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
  });

  final AuthorSeries series;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('saved-series-${series.id}'),
        leading: const Icon(Icons.library_books_outlined),
        title: Text(
          series.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${series.stories.length} ${series.stories.length == 1 ? 'story' : 'stories'} downloaded',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: [
          for (final story in series.stories)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _StoryCard(
                item: story,
                repository: repository,
                savedStories: savedStories,
                favorites: favorites,
                history: history,
                showDownloadAction: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _DownloadsPage extends StatelessWidget {
  const _DownloadsPage({
    required this.repository,
    required this.savedStories,
    required this.favorites,
    required this.history,
  });

  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Downloads'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Downloaded'),
              Tab(text: 'Queue'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SavedStoriesView(
              repository: repository,
              savedStories: savedStories,
              favorites: favorites,
              history: history,
            ),
            _DownloadQueueView(savedStories: savedStories),
          ],
        ),
      ),
    );
  }
}

class _DownloadQueueView extends StatelessWidget {
  const _DownloadQueueView({required this.savedStories});

  final SavedStoriesViewModel savedStories;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: savedStories,
      builder: (context, _) {
        final downloads = savedStories.downloads;
        if (downloads.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_done_rounded, size: 42),
                  SizedBox(height: 14),
                  Text('No active downloads'),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          key: const Key('downloads-list'),
          padding: const EdgeInsets.all(10),
          itemCount: downloads.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) => _DownloadCard(
            download: downloads[index],
            savedStories: savedStories,
          ),
        );
      },
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.download, required this.savedStories});

  final StoryDownload download;
  final SavedStoriesViewModel savedStories;

  @override
  Widget build(BuildContext context) {
    final isDownloading = download.status == StoryDownloadStatus.downloading;
    final hasFailed = download.status == StoryDownloadStatus.failed;
    return Card(
      child: ListTile(
        key: Key('download-${download.story.id}'),
        leading: isDownloading
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(
                hasFailed
                    ? Icons.error_outline_rounded
                    : Icons.schedule_rounded,
                color: hasFailed
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
        title: Text(
          download.story.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          switch (download.status) {
            StoryDownloadStatus.queued => 'Waiting',
            StoryDownloadStatus.downloading => 'Downloading for offline use…',
            StoryDownloadStatus.failed => 'Download failed',
          },
          style: TextStyle(
            color: hasFailed
                ? Theme.of(context).colorScheme.error
                : const Color(0xFF8D98A5),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasFailed)
              IconButton(
                key: Key('retry-download-${download.story.id}'),
                tooltip: 'Retry',
                onPressed: () => savedStories.retryDownload(download.story.id),
                icon: const Icon(Icons.refresh_rounded),
              ),
            IconButton(
              key: Key('remove-download-${download.story.id}'),
              tooltip: 'Remove download',
              onPressed: isDownloading
                  ? null
                  : () => savedStories.removeDownload(download.story.id),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Couldn’t load stories',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Nothing here yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Try another category.',
              style: TextStyle(color: Color(0xFF7D8996)),
            ),
          ],
        ),
      ),
    );
  }
}
