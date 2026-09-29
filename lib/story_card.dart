import 'package:flutter/material.dart';

import 'literotica_api.dart';
import 'local_story_store.dart';

class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.savedStories,
    required this.onTap,
    this.onAuthorTap,
  });

  final ListorItem story;
  final SavedStoriesViewModel savedStories;
  final VoidCallback onTap;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final rating = story.rating?.toStringAsFixed(1) ?? '—';
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
                    listenable: savedStories,
                    builder: (context, _) {
                      final isSaved = savedStories.isSaved(story.id);
                      final download = savedStories.downloadFor(story.id);
                      final isDownloading =
                          download?.status == StoryDownloadStatus.downloading;
                      final isQueued =
                          download?.status == StoryDownloadStatus.queued;
                      final hasFailed =
                          download?.status == StoryDownloadStatus.failed;
                      return IconButton(
                        key: Key('save-story-${story.id}'),
                        onPressed: isDownloading || isQueued
                            ? null
                            : () => _toggleSaved(context),
                        tooltip: isDownloading
                            ? 'Downloading story'
                            : isQueued
                            ? 'Queued for download'
                            : hasFailed
                            ? 'Retry download'
                            : isSaved
                            ? 'Remove from saved'
                            : 'Save story for offline reading',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 28,
                        ),
                        icon: isDownloading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : isQueued
                            ? const Icon(Icons.schedule_rounded, size: 18)
                            : hasFailed
                            ? const Icon(Icons.error_outline_rounded, size: 18)
                            : Icon(
                                isSaved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                size: 18,
                              ),
                      );
                    },
                  ),
                ],
              ),
              if (story.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  story.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFA2ACB7),
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

  Future<void> _toggleSaved(BuildContext context) async {
    try {
      final result = await savedStories.toggle(story);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(switch (result) {
            SaveRequestResult.queued => 'Added to download queue',
            SaveRequestResult.removed => 'Removed from saved',
            SaveRequestResult.alreadyQueued => 'Already in download queue',
          }),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update saved stories')),
      );
    }
  }
}
