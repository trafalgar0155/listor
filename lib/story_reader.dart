import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import 'favorites.dart';
import 'literotica_api.dart';
import 'reading_history.dart';

class StoryReaderPage extends StatefulWidget {
  const StoryReaderPage({
    super.key,
    required this.story,
    required this.repository,
    required this.favorites,
    required this.history,
    this.onAuthorTap,
  });

  final ListorItem story;
  final StoryRepository repository;
  final FavoritesViewModel favorites;
  final ReadingHistoryViewModel history;
  final VoidCallback? onAuthorTap;

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  late Future<_ReaderContent> _content;

  @override
  void initState() {
    super.initState();
    _content = _loadContent();
  }

  void _retry() {
    setState(() => _content = _loadContent());
  }

  Future<_ReaderContent> _loadContent() async {
    final document = await widget.repository.fetchStory(widget.story);
    final pageCount = document.pages.isEmpty ? 1 : document.pages.length;
    final initialPage = await widget.history.resumePage(
      widget.story.id,
      pageCount,
    );
    await widget.history.record(
      widget.story,
      pageIndex: initialPage,
      pageCount: pageCount,
    );
    return _ReaderContent(document: document, initialPage: initialPage);
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
        actions: [
          ListenableBuilder(
            listenable: widget.favorites,
            builder: (context, _) {
              final isFavorite = widget.favorites.isStoryFavorite(
                widget.story.id,
              );
              return IconButton(
                key: const Key('story-reader-favorite'),
                onPressed: _toggleFavorite,
                tooltip: isFavorite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<_ReaderContent>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReaderError(onRetry: _retry);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _StoryBody(
            story: widget.story,
            document: snapshot.data!.document,
            initialPage: snapshot.data!.initialPage,
            history: widget.history,
            onAuthorTap: widget.onAuthorTap,
          );
        },
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    try {
      final added = await widget.favorites.toggleStory(widget.story);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(
            added ? 'Added to favourites' : 'Removed from favourites',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update favourites')),
      );
    }
  }
}

class _ReaderContent {
  const _ReaderContent({required this.document, required this.initialPage});

  final StoryDocument document;
  final int initialPage;
}

class _StoryBody extends StatefulWidget {
  const _StoryBody({
    required this.story,
    required this.document,
    required this.initialPage,
    required this.history,
    required this.onAuthorTap,
  });

  final ListorItem story;
  final StoryDocument document;
  final int initialPage;
  final ReadingHistoryViewModel history;
  final VoidCallback? onAuthorTap;

  @override
  State<_StoryBody> createState() => _StoryBodyState();
}

class _StoryBodyState extends State<_StoryBody> {
  late final ScrollController _scrollController;
  late final List<GlobalKey> _pageKeys;
  late int _currentPage;
  bool _hasRestoredPosition = false;

  List<String> get _pages =>
      widget.document.pages.isEmpty ? const [''] : widget.document.pages;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageKeys = List.generate(_pages.length, (_) => GlobalKey());
    _scrollController = ScrollController()..addListener(_trackCurrentPage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_trackCurrentPage)
      ..dispose();
    super.dispose();
  }

  void _restorePosition() {
    if (!mounted) return;
    final page = widget.initialPage.clamp(0, _pageKeys.length - 1).toInt();
    if (page > 0) {
      final pageContext = _pageKeys[page].currentContext;
      if (pageContext != null) {
        unawaited(Scrollable.ensureVisible(pageContext, alignment: 0));
      }
    }
    _hasRestoredPosition = true;
  }

  void _trackCurrentPage() {
    if (!_hasRestoredPosition || !mounted) return;
    final mediaQuery = MediaQuery.of(context);
    final viewportTop = mediaQuery.padding.top + kToolbarHeight;
    final viewportBottom = mediaQuery.size.height - mediaQuery.padding.bottom;
    final readingLine = viewportTop + (viewportBottom - viewportTop) * 0.9;
    var page = 0;
    for (var index = 1; index < _pageKeys.length; index++) {
      final pageContext = _pageKeys[index].currentContext;
      final box = pageContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= readingLine) {
        page = index;
      } else {
        break;
      }
    }
    if (page == _currentPage) return;
    _currentPage = page;
    unawaited(
      widget.history.record(
        widget.story,
        pageIndex: page,
        pageCount: _pages.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final seriesTitle = widget.story.seriesTitle?.trim();
    final approvedAt = widget.story.approvedAt;
    final dateLabel = approvedAt == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(approvedAt);
    final readerViewportHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).top -
        kToolbarHeight;
    return SelectionArea(
      child: SingleChildScrollView(
        key: const Key('story-reader'),
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.story.title,
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
                    onPressed: widget.onAuthorTap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(widget.story.author),
                  ),
                  if (seriesTitle != null && seriesTitle.isNotEmpty)
                    _ReaderMetadata(
                      key: const Key('story-series'),
                      icon: Icons.library_books_outlined,
                      label: widget.story.seriesPosition == null
                          ? seriesTitle
                          : '$seriesTitle · Part ${widget.story.seriesPosition! + 1}',
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
                    label: widget.story.category.label,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Divider(),
              for (var index = 0; index < _pages.length; index++)
                ConstrainedBox(
                  key: _pageKeys[index],
                  constraints: BoxConstraints(minHeight: readerViewportHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (index > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            'Page ${index + 1} of ${_pages.length}',
                            key: Key('story-page-marker-$index'),
                            textAlign: TextAlign.center,
                            style: textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF6F7C89),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Html(
                        key: Key('story-page-$index'),
                        data: _wrapPlainParagraphs(_pages[index]),
                        style: {
                          'body': Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            color: const Color(0xFFD8DEE6),
                            fontSize: FontSize(
                              textTheme.bodyLarge?.fontSize ?? 16,
                            ),
                            lineHeight: const LineHeight(1.65),
                          ),
                          'p': Style(margin: Margins.only(bottom: 18)),
                          'strong': Style(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          'em': Style(fontStyle: FontStyle.italic),
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
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
