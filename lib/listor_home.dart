import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'literotica_api.dart';
import 'story_reader.dart';

class ListorHomePage extends StatefulWidget {
  const ListorHomePage({super.key, this.repository});

  final StoryRepository? repository;

  @override
  State<ListorHomePage> createState() => _ListorHomePageState();
}

class _ListorHomePageState extends State<ListorHomePage> {
  static const _categoryPreferenceKey = 'selected_category';

  late final StoryRepository _repository;
  StoryFilters _filters = const StoryFilters();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LiteroticaApiClient();
    unawaited(_restoreCategory());
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: FeedType.values.length,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 64,
          titleSpacing: 16,
          title: Text(
            'Listor',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(55),
            child: _FeedTabs(),
          ),
        ),
        body: TabBarView(
          children: [
            for (final feed in FeedType.values)
              _FeedPage(
                key: ValueKey('${feed.name}:${_filterFingerprint(_filters)}'),
                feed: feed,
                filters: _filters,
                repository: _repository,
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('filter-fab'),
          onPressed: _showFilters,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Filter'),
        ),
      ),
    );
  }
}

String _filterFingerprint(StoryFilters filters) {
  final tagIds = filters.tags.map((tag) => tag.id).toList()..sort();
  return '${filters.category.name}:${filters.period.name}:$tagIds';
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
                    style: TextStyle(color: Color(0xFF7D8996), fontSize: 12),
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
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
  });

  final FeedType feed;
  final StoryFilters filters;
  final StoryRepository repository;

  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage> {
  final ScrollController _scrollController = ScrollController();
  final List<ListorItem> _items = [];
  final Set<int> _storyIds = {};

  int _nextPage = 0;
  int _generation = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    unawaited(_loadMore());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 320) {
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
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
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
    return ListView.separated(
      key: Key('feed-list-${widget.feed.name}'),
      controller: _scrollController,
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
        return _StoryCard(item: _items[index], repository: widget.repository);
      },
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
  const _StoryCard({required this.item, required this.repository});

  final ListorItem item;
  final StoryRepository repository;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rating = item.rating?.toStringAsFixed(1) ?? '—';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  StoryReaderPage(story: item, repository: repository),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    tooltip: 'Save',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 28,
                    ),
                    icon: const Icon(Icons.bookmark_border_rounded, size: 18),
                  ),
                ],
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFA2ACB7),
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
              ],
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.category.label.toUpperCase(),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.55,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.author,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8D98A5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                  Text(
                    ' $rating  •  ${item.favoriteCount}',
                    style: const TextStyle(
                      color: Color(0xFF6F7C89),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
