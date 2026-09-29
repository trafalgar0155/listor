import 'package:flutter/material.dart';

import 'author_works.dart';
import 'favorites.dart';
import 'literotica_api.dart';
import 'local_story_store.dart';
import 'reading_history.dart';
import 'story_card.dart';
import 'story_reader.dart';

class ReadingHistoryDestination extends StatelessWidget {
  const ReadingHistoryDestination({
    super.key,
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
    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            ListenableBuilder(
              listenable: history,
              builder: (context, _) => IconButton(
                key: const Key('clear-history'),
                onPressed: history.entries.isEmpty
                    ? null
                    : () => _confirmClear(context),
                tooltip: 'Clear history',
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: history,
          builder: (context, _) {
            if (history.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (history.loadError != null) {
              return Center(
                child: FilledButton.tonalIcon(
                  onPressed: history.load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry loading history'),
                ),
              );
            }
            if (history.entries.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 44),
                    SizedBox(height: 12),
                    Text('No reading history yet'),
                  ],
                ),
              );
            }
            return ListView.separated(
              key: const Key('history-list'),
              padding: const EdgeInsets.all(10),
              itemCount: history.entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final entry = history.entries[index];
                return StoryCard(
                  key: Key('history-${entry.story.id}'),
                  story: entry.story,
                  favorites: favorites,
                  savedStories: savedStories,
                  onTap: () => _openStory(context, entry.story),
                  onAuthorTap: () => _openAuthor(context, entry.story),
                  footer: _HistoryProgress(
                    entry: entry,
                    onRemove: () => _remove(context, entry),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, ReadingHistoryEntry entry) async {
    await history.remove(entry.story.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Removed from history'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => history.restore(entry),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear reading history?'),
        content: const Text('This removes all saved reading progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await history.clear();
  }

  void _openStory(BuildContext context, ListorItem story) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryReaderPage(
          story: story,
          repository: repository,
          favorites: favorites,
          history: history,
          onAuthorTap: () => _openAuthor(context, story),
        ),
      ),
    );
  }

  void _openAuthor(BuildContext context, ListorItem story) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthorWorksPage(
          author: story.author,
          repository: repository,
          savedStories: savedStories,
          favorites: favorites,
          history: history,
        ),
      ),
    );
  }
}

class _HistoryProgress extends StatelessWidget {
  const _HistoryProgress({required this.entry, required this.onRemove});

  final ReadingHistoryEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(entry.lastReadAt);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(entry.lastReadAt),
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            'Page ${entry.pageIndex + 1} of ${entry.pageCount}  •  $date, $time',
            key: Key('history-progress-${entry.story.id}'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          key: Key('remove-history-${entry.story.id}'),
          onPressed: onRemove,
          tooltip: 'Remove from history',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 28),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
        ),
      ],
    );
  }
}
