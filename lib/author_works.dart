import 'package:flutter/material.dart';

import 'literotica_api.dart';
import 'local_story_store.dart';
import 'story_reader.dart';

class AuthorWorksViewModel extends ChangeNotifier {
  AuthorWorksViewModel({required this.author, required this.repository});

  final String author;
  final StoryRepository repository;

  AuthorWorks? _works;
  Object? _error;
  bool _isLoading = false;

  AuthorWorks? get works => _works;
  Object? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _works = await repository.fetchAuthorWorks(author);
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

class AuthorWorksPage extends StatefulWidget {
  const AuthorWorksPage({
    super.key,
    required this.author,
    required this.repository,
    required this.savedStories,
  });

  final String author;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;

  @override
  State<AuthorWorksPage> createState() => _AuthorWorksPageState();
}

class _AuthorWorksPageState extends State<AuthorWorksPage> {
  late final AuthorWorksViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthorWorksViewModel(
      author: widget.author,
      repository: widget.repository,
    );
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('author-works-page'),
      appBar: AppBar(title: Text(widget.author)),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading && _viewModel.works == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_viewModel.error != null && _viewModel.works == null) {
            return _AuthorWorksError(onRetry: _viewModel.load);
          }
          final works = _viewModel.works!;
          if (works.series.isEmpty && works.stories.isEmpty) {
            return Center(
              child: Text('${works.author} has no published works.'),
            );
          }
          return _AuthorWorksList(
            works: works,
            repository: widget.repository,
            savedStories: widget.savedStories,
          );
        },
      ),
    );
  }
}

class _AuthorWorksList extends StatelessWidget {
  const _AuthorWorksList({
    required this.works,
    required this.repository,
    required this.savedStories,
  });

  final AuthorWorks works;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('author-works-list'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: [
        if (works.series.isNotEmpty) ...[
          _SectionHeader(
            title: 'Series',
            count: works.series.length,
            icon: Icons.collections_bookmark_outlined,
          ),
          for (final series in works.series)
            _SeriesCard(
              series: series,
              repository: repository,
              savedStories: savedStories,
            ),
          const SizedBox(height: 14),
        ],
        if (works.stories.isNotEmpty) ...[
          _SectionHeader(
            title: 'Stories',
            count: works.stories.length,
            icon: Icons.auto_stories_outlined,
          ),
          for (final story in works.stories)
            _AuthorStoryCard(
              story: story,
              repository: repository,
              savedStories: savedStories,
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
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
          Text('$count', style: const TextStyle(color: Color(0xFF7C8794))),
        ],
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.series,
    required this.repository,
    required this.savedStories,
  });

  final AuthorSeries series;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('author-series-${series.id}'),
        leading: const Icon(Icons.library_books_outlined),
        title: Row(
          children: [
            Expanded(
              child: Text(
                series.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListenableBuilder(
              listenable: savedStories,
              builder: (context, _) {
                final isSaved = savedStories.isSeriesSaved(series);
                final isDownloading = savedStories.isSeriesDownloading(series);
                final hasFailed = savedStories.hasFailedSeriesDownload(series);
                return IconButton(
                  key: Key('download-series-${series.id}'),
                  visualDensity: VisualDensity.compact,
                  tooltip: isSaved
                      ? 'Series downloaded'
                      : isDownloading
                      ? 'Series download in progress'
                      : hasFailed
                      ? 'Retry series download'
                      : 'Download series',
                  onPressed: isSaved || isDownloading
                      ? null
                      : () => _downloadSeries(context),
                  icon: isDownloading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isSaved
                              ? Icons.download_done_rounded
                              : hasFailed
                              ? Icons.error_outline_rounded
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
          if (series.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  series.description,
                  style: const TextStyle(color: Color(0xFF98A3AF)),
                ),
              ),
            ),
          for (var index = 0; index < series.stories.length; index++)
            _SeriesStoryTile(
              index: index,
              story: series.stories[index],
              repository: repository,
              savedStories: savedStories,
            ),
        ],
      ),
    );
  }

  Future<void> _downloadSeries(BuildContext context) async {
    try {
      final count = await savedStories.downloadSeries(series);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            count == 0
                ? 'Series is already saved or queued'
                : '$count ${count == 1 ? 'story' : 'stories'} added to downloads',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t queue this series')),
      );
    }
  }
}

class _SeriesStoryTile extends StatelessWidget {
  const _SeriesStoryTile({
    required this.index,
    required this.story,
    required this.repository,
    required this.savedStories,
  });

  final int index;
  final ListorItem story;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('author-story-${story.id}'),
      dense: true,
      leading: SizedBox(
        width: 28,
        child: Text(
          '${index + 1}.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(story.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(story.category.label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _openStory(context, story, repository, savedStories),
    );
  }
}

class _AuthorStoryCard extends StatelessWidget {
  const _AuthorStoryCard({
    required this.story,
    required this.repository,
    required this.savedStories,
  });

  final ListorItem story;
  final StoryRepository repository;
  final SavedStoriesViewModel savedStories;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: Key('author-story-${story.id}'),
        title: Text(
          story.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          story.description.isEmpty ? story.category.label : story.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _openStory(context, story, repository, savedStories),
      ),
    );
  }
}

void _openStory(
  BuildContext context,
  ListorItem story,
  StoryRepository repository,
  SavedStoriesViewModel savedStories,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StoryReaderPage(
        story: story,
        repository: repository,
        onAuthorTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AuthorWorksPage(
                author: story.author,
                repository: repository,
                savedStories: savedStories,
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _AuthorWorksError extends StatelessWidget {
  const _AuthorWorksError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_search_rounded, size: 44),
            const SizedBox(height: 12),
            const Text('Couldn’t load this author’s works'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
