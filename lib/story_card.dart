import 'package:flutter/material.dart';

import 'favorites.dart';
import 'literotica_api.dart';
import 'local_story_store.dart';

class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.favorites,
    required this.savedStories,
    required this.onTap,
    this.onAuthorTap,
    this.showDownloadAction = false,
  });

  final ListorItem story;
  final FavoritesViewModel favorites;
  final SavedStoriesViewModel savedStories;
  final VoidCallback onTap;
  final VoidCallback? onAuthorTap;
  final bool showDownloadAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final rating = story.rating?.toStringAsFixed(1) ?? '—';
    final approvedAt = story.approvedAt;
    final dateLabel = approvedAt == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(approvedAt);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      story.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: favorites,
                    builder: (context, _) {
                      final isFavorite = favorites.isStoryFavorite(story.id);
                      return IconButton(
                        key: Key('favorite-story-${story.id}'),
                        onPressed: () => _toggleFavorite(context),
                        tooltip: isFavorite
                            ? 'Remove from favourites'
                            : 'Add to favourites',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 28,
                        ),
                        icon: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                        ),
                      );
                    },
                  ),
                  if (showDownloadAction)
                    StoryDownloadButton(
                      story: story,
                      savedStories: savedStories,
                    ),
                ],
              ),
              if (story.description.isNotEmpty || dateLabel != null) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (story.description.isNotEmpty)
                      Expanded(
                        child: Text(
                          story.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFA2ACB7),
                            height: 1.2,
                          ),
                        ),
                      ),
                    if (story.description.isNotEmpty && dateLabel != null)
                      const SizedBox(width: 10),
                    if (dateLabel != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: Color(0xFF8793A0),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            key: Key('story-date-${story.id}'),
                            dateLabel,
                            style: textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF8793A0),
                            ),
                          ),
                        ],
                      ),
                  ],
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
                  Flexible(
                    child: Text(
                      story.category.label.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        key: Key('author-${story.id}'),
                        onTap: onAuthorTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            story.author,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                  Flexible(
                    child: Text(
                      ' $rating  •  ${story.favoriteCount}',
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF8793A0),
                      ),
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

  Future<void> _toggleFavorite(BuildContext context) async {
    try {
      final added = await favorites.toggleStory(story);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(
            added ? 'Added to favourites' : 'Removed from favourites',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update favourites')),
      );
    }
  }
}

class StoryDownloadButton extends StatelessWidget {
  const StoryDownloadButton({
    super.key,
    required this.story,
    required this.savedStories,
  });

  final ListorItem story;
  final SavedStoriesViewModel savedStories;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: savedStories,
      builder: (context, _) {
        final isDownloaded = savedStories.isSaved(story.id);
        final download = savedStories.downloadFor(story.id);
        final isDownloading =
            download?.status == StoryDownloadStatus.downloading;
        final isQueued = download?.status == StoryDownloadStatus.queued;
        final hasFailed = download?.status == StoryDownloadStatus.failed;
        return IconButton(
          key: Key('download-story-${story.id}'),
          onPressed: isDownloading || isQueued
              ? null
              : isDownloaded
              ? () => savedStories.removeSavedStory(story.id)
              : () => _download(context),
          tooltip: isDownloaded
              ? 'Remove download'
              : isDownloading
              ? 'Downloading story'
              : isQueued
              ? 'Queued for download'
              : hasFailed
              ? 'Retry download'
              : 'Download for offline reading',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 28),
          icon: isDownloading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isDownloaded
                      ? Icons.download_done_rounded
                      : isQueued
                      ? Icons.schedule_rounded
                      : hasFailed
                      ? Icons.error_outline_rounded
                      : Icons.download_for_offline_outlined,
                  size: 18,
                ),
        );
      },
    );
  }

  Future<void> _download(BuildContext context) async {
    try {
      final result = await savedStories.downloadStory(story);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(switch (result) {
            DownloadRequestResult.queued => 'Added to download queue',
            DownloadRequestResult.alreadyQueued => 'Already in download queue',
            DownloadRequestResult.alreadyDownloaded => 'Already downloaded',
          }),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Couldn’t queue download')));
    }
  }
}
