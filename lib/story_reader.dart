import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import 'literotica_api.dart';

class StoryReaderPage extends StatefulWidget {
  const StoryReaderPage({
    super.key,
    required this.story,
    required this.repository,
    this.onAuthorTap,
  });

  final ListorItem story;
  final StoryRepository repository;
  final VoidCallback? onAuthorTap;

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  late Future<StoryDocument> _document;

  @override
  void initState() {
    super.initState();
    _document = widget.repository.fetchStory(widget.story);
  }

  void _retry() {
    setState(() => _document = widget.repository.fetchStory(widget.story));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.story.title,
          key: const Key('story-app-bar-title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<StoryDocument>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReaderError(onRetry: _retry);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _StoryBody(
            story: widget.story,
            document: snapshot.data!,
            onAuthorTap: widget.onAuthorTap,
          );
        },
      ),
    );
  }
}

class _StoryBody extends StatelessWidget {
  const _StoryBody({
    required this.story,
    required this.document,
    required this.onAuthorTap,
  });

  final ListorItem story;
  final StoryDocument document;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final html = formatStoryHtml(document);
    final seriesTitle = story.seriesTitle?.trim();
    final approvedAt = story.approvedAt;
    final dateLabel = approvedAt == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(approvedAt);
    return SelectionArea(
      child: ListView(
        key: const Key('story-reader'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        children: [
          Text(
            story.title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.12,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                key: const Key('story-author-link'),
                onPressed: onAuthorTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(story.author),
              ),
              if (seriesTitle != null && seriesTitle.isNotEmpty)
                _ReaderMetadata(
                  key: const Key('story-series'),
                  icon: Icons.library_books_outlined,
                  label: story.seriesPosition == null
                      ? seriesTitle
                      : '$seriesTitle · Part ${story.seriesPosition! + 1}',
                ),
              if (dateLabel != null)
                _ReaderMetadata(
                  key: const Key('story-reader-date'),
                  icon: Icons.calendar_today_outlined,
                  label: dateLabel,
                ),
              _ReaderMetadata(
                key: const Key('story-reader-category'),
                icon: Icons.category_outlined,
                label: story.category.label,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(),
          Html(
            data: html,
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                color: const Color(0xFFD8DEE6),
                fontSize: FontSize(textTheme.bodyLarge?.fontSize ?? 16),
                lineHeight: const LineHeight(1.65),
              ),
              'p': Style(margin: Margins.only(bottom: 18)),
              'strong': Style(color: Colors.white, fontWeight: FontWeight.w700),
              'em': Style(fontStyle: FontStyle.italic),
              '.page-marker': Style(
                color: const Color(0xFF6F7C89),
                fontSize: FontSize(textTheme.labelMedium?.fontSize ?? 12),
                fontWeight: FontWeight.w700,
                textAlign: TextAlign.center,
                margin: Margins.only(top: 28, bottom: 28),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _ReaderMetadata extends StatelessWidget {
  const _ReaderMetadata({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w600);
    final iconSize = style?.fontSize ?? 14;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(icon, size: iconSize, color: color),
          ),
          const TextSpan(text: '  '),
          TextSpan(text: label),
        ],
      ),
      style: style,
    );
  }
}

String formatStoryHtml(StoryDocument document) {
  final pages = <String>[];
  for (var index = 0; index < document.pages.length; index++) {
    if (index > 0) {
      pages.add(
        '<div class="page-marker">Page ${index + 1} of ${document.pages.length}</div>',
      );
    }
    pages.add(_wrapPlainParagraphs(document.pages[index]));
  }
  return pages.join('\n');
}

String _wrapPlainParagraphs(String source) {
  final blocks = source
      .replaceAll('\r\n', '\n')
      .trim()
      .split(RegExp(r'\n\s*\n'));
  final blockTag = RegExp(
    r'^\s*<(?:p|div|h[1-6]|blockquote|ul|ol|li|hr)\b',
    caseSensitive: false,
  );
  return blocks
      .map((block) {
        final value = block.trim();
        if (value.isEmpty || blockTag.hasMatch(value)) return value;
        return '<p>${value.replaceAll('\n', '<br>')}</p>';
      })
      .join('\n');
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.onRetry});

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
              Icons.menu_book_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Couldn’t load this story',
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
