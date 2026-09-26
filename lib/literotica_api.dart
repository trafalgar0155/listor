import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

enum FeedType { newest, popular, random }

enum StoryPeriod {
  week('week', 'Last 7 days'),
  month('month', 'Last 30 days'),
  all('all', 'All time');

  const StoryPeriod(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class StoryTag {
  const StoryTag({required this.id, required this.label});

  final int id;
  final String label;

  @override
  bool operator ==(Object other) => other is StoryTag && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class StoryFilters {
  const StoryFilters({
    this.category = ListorCategory.nonErotic,
    this.period = StoryPeriod.all,
    this.tags = const <StoryTag>{},
  });

  final ListorCategory category;
  final StoryPeriod period;
  final Set<StoryTag> tags;
}

enum ListorCategory {
  eroticCouplings(2, 'Erotic Couplings'),
  reviewsEssays(3, 'Reviews & Essays'),
  exhibitionistVoyeur(4, 'Exhibitionist & Voyeur'),
  fetish(5, 'Fetish'),
  gayMale(6, 'Gay Male'),
  groupSex(7, 'Group Sex'),
  howTo(8, 'How To'),
  tabooIncest(9, 'Taboo & Incest'),
  interracialLove(10, 'Interracial Love'),
  lesbianSex(11, 'Lesbian Sex'),
  lovingWives(12, 'Loving Wives'),
  reluctanceNonConsent(13, 'Reluctance / Non-Consent'),
  nonHuman(14, 'Non-Human'),
  romance(15, 'Romance'),
  toysMasturbation(16, 'Toys & Masturbation'),
  eroticPoetry(17, 'Erotic Poetry'),
  mature(26, 'Mature'),
  fanFictionCelebrities(27, 'Fan Fiction & Celebrities'),
  chainStories(28, 'Chain Stories'),
  mindControl(29, 'Mind Control'),
  bdsm(31, 'BDSM'),
  nonEnglish(32, 'Non-English'),
  novelsAndNovellas(33, 'Novels & Novellas'),
  humorSatire(34, 'Humor & Satire'),
  nonErotic(35, 'Non Erotic'),
  nonEroticPoetry(36, 'Non-Erotic Poetry'),
  anal(37, 'Anal'),
  sciFiFantasy(38, 'Sci-Fi & Fantasy'),
  audio(39, 'Audio'),
  firstTime(40, 'First Time'),
  illustrated(45, 'Illustrated'),
  poetryWithAudio(46, 'Poetry with Audio'),
  illustratedPoetry(47, 'Illustrated Poetry'),
  transgender(48, 'Transgender'),
  eroticHorror(51, 'Erotic Horror'),
  lettersTranscripts(53, 'Letters & Transcripts'),
  eroticArt(55, 'Erotic Art'),
  adultComics(56, 'Adult Comics'),
  crossdressing(58, 'Crossdressing');

  const ListorCategory(this.id, this.label);
  final int id;
  final String label;
}

class ListorItem {
  const ListorItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.author,
    required this.approvedAt,
    required this.favoriteCount,
    required this.rating,
    required this.url,
  });

  final int id;
  final String title;
  final String description;
  final ListorCategory category;
  final String author;
  final DateTime? approvedAt;
  final int favoriteCount;
  final double? rating;
  final Uri url;

  factory ListorItem.fromJson(
    Map<String, dynamic> json,
    ListorCategory category,
  ) {
    final rawAuthor = json['author'];
    final author = rawAuthor is Map<String, dynamic>
        ? rawAuthor['username']?.toString()
        : json['authorname']?.toString();
    final slug = json['url']?.toString() ?? '';
    return ListorItem(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? 'Untitled',
      description: json['description']?.toString() ?? '',
      category: category,
      author: author?.isNotEmpty == true ? author! : 'Unknown author',
      approvedAt: _parseUsDate(json['date_approve']?.toString()),
      favoriteCount: _asInt(json['favorite_count']),
      rating: _asDouble(json['rate_all']),
      url: Uri.https('www.literotica.com', '/s/$slug'),
    );
  }
}

class StoryDocument {
  const StoryDocument({required this.pages});

  final List<String> pages;
}

class StoryFeedPage {
  const StoryFeedPage({required this.items, required this.hasMore});

  final List<ListorItem> items;
  final bool hasMore;
}

class AuthorSeries {
  const AuthorSeries({
    required this.id,
    required this.title,
    required this.description,
    required this.stories,
  });

  final int id;
  final String title;
  final String description;
  final List<ListorItem> stories;
}

class AuthorWorks {
  const AuthorWorks({
    required this.author,
    required this.series,
    required this.stories,
  });

  final String author;
  final List<AuthorSeries> series;
  final List<ListorItem> stories;
}

abstract interface class StoryRepository {
  Future<StoryFeedPage> fetchFeed(
    StoryFilters filters,
    FeedType feed, {
    int page = 0,
  });

  Future<List<StoryTag>> fetchTags(ListorCategory category, StoryPeriod period);

  Future<StoryDocument> fetchStory(ListorItem story);

  Future<AuthorWorks> fetchAuthorWorks(String author);
}

/// Dart implementation of the HTTP contract wrapped by LiteroticaApi 2.1.0.
class LiteroticaApiClient implements StoryRepository {
  LiteroticaApiClient({http.Client? client, Random? random})
    : _client = client ?? http.Client(),
      _random = random ?? Random();

  final http.Client _client;
  final Random _random;
  final Map<String, int> _randomStartPages = {};

  @override
  Future<AuthorWorks> fetchAuthorWorks(String author) async {
    final works = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final uri = Uri.https(
        'literotica.com',
        '/api/3/users/$author/series_and_works',
        {
          'params': jsonEncode({
            'page': page,
            'pageSize': 500,
            'listType': 'expanded',
            'sort': 'title',
          }),
        },
      );
      final decoded = await _getJson(uri);
      final data = decoded['data'];
      if (data is! List) {
        throw const FormatException('Author works response is missing data.');
      }
      works.addAll(data.whereType<Map<String, dynamic>>());
      lastPage = max(1, _asInt(decoded['last_page']));
      page++;
    } while (page <= lastPage);

    final series = <AuthorSeries>[];
    final stories = <ListorItem>[];
    for (final work in works) {
      final parts = work['parts'];
      if (parts is List && parts.isNotEmpty) {
        series.add(
          AuthorSeries(
            id: _asInt(work['id']),
            title: work['title']?.toString() ?? 'Untitled series',
            description: work['description']?.toString() ?? '',
            stories: parts
                .whereType<Map<String, dynamic>>()
                .map((part) => _authorWorkItem(part, author))
                .toList(),
          ),
        );
      } else {
        stories.add(_authorWorkItem(work, author));
      }
    }
    return AuthorWorks(author: author, series: series, stories: stories);
  }

  @override
  Future<StoryDocument> fetchStory(ListorItem story) async {
    final slug = story.url.pathSegments.isEmpty
        ? null
        : story.url.pathSegments.last;
    if (slug == null || slug.isEmpty) {
      throw const FormatException('The story URL does not contain a slug.');
    }

    final first = await _storyPage(slug, 1);
    final pages = <String>[first.text];
    for (var page = 2; page <= first.pageCount; page++) {
      pages.add((await _storyPage(slug, page)).text);
    }
    return StoryDocument(pages: pages);
  }

  @override
  Future<StoryFeedPage> fetchFeed(
    StoryFilters filters,
    FeedType feed, {
    int page = 0,
  }) async {
    if (filters.tags.isNotEmpty) {
      final first = await _searchByTags(filters: filters, page: 1);
      final targetPage = feed == FeedType.random
          ? _randomPage(filters, first.lastPage, page)
          : page + 1;
      if (targetPage > first.lastPage) {
        return const StoryFeedPage(items: [], hasMore: false);
      }
      final result = targetPage == 1
          ? first
          : await _searchByTags(filters: filters, page: targetPage);
      return StoryFeedPage(
        items: _sortItems(result.items, feed),
        hasMore: page + 1 < first.lastPage,
      );
    }

    final first = await _search(
      category: filters.category,
      page: 1,
      popular: feed == FeedType.popular,
    );
    final targetPage = switch (feed) {
      FeedType.newest => first.lastPage - page,
      FeedType.popular => page + 1,
      FeedType.random => _randomPage(filters, first.lastPage, page),
    };
    if (targetPage < 1 || targetPage > first.lastPage) {
      return const StoryFeedPage(items: [], hasMore: false);
    }
    final result = targetPage == 1
        ? first
        : await _search(
            category: filters.category,
            page: targetPage,
            popular: feed == FeedType.popular,
          );
    final items = result.items
        .where((item) => _isInPeriod(item.approvedAt, filters.period))
        .toList();
    return StoryFeedPage(
      items: _sortItems(items, feed),
      hasMore: page + 1 < first.lastPage,
    );
  }

  int _randomPage(StoryFilters filters, int pageCount, int offset) {
    final tagIds = filters.tags.map((tag) => tag.id).toList()..sort();
    final key = '${filters.category.id}:${filters.period.name}:$tagIds';
    final start = _randomStartPages.putIfAbsent(
      key,
      () => _random.nextInt(pageCount),
    );
    return ((start + offset) % pageCount) + 1;
  }

  @override
  Future<List<StoryTag>> fetchTags(
    ListorCategory category,
    StoryPeriod period,
  ) async {
    final uri = Uri.https('literotica.com', '/api/3/tagsportal/top', {
      'params': jsonEncode({
        'limit': 20,
        'periodCheck': true,
        'category': category.id,
        'period': period.apiValue,
        'language': 1,
      }),
    });
    final decoded = await _getJson(uri);
    final tags = decoded['tags'];
    if (tags is! List) {
      throw const FormatException('Tag response is missing tags.');
    }
    return tags
        .whereType<Map<String, dynamic>>()
        .map(
          (tag) => StoryTag(
            id: _asInt(tag['tagid'] ?? tag['id']),
            label: tag['tag']?.toString() ?? '',
          ),
        )
        .where((tag) => tag.id > 0 && tag.label.isNotEmpty)
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  List<ListorItem> _sortItems(List<ListorItem> items, FeedType feed) {
    switch (feed) {
      case FeedType.newest:
        return items..sort((a, b) => _dateValue(b).compareTo(_dateValue(a)));
      case FeedType.popular:
        return items..sort((a, b) {
          final favorites = b.favoriteCount.compareTo(a.favoriteCount);
          return favorites != 0
              ? favorites
              : (b.rating ?? 0).compareTo(a.rating ?? 0);
        });
      case FeedType.random:
        return items..shuffle(_random);
    }
  }

  Future<_SearchPage> _searchByTags({
    required StoryFilters filters,
    required int page,
  }) async {
    const pageSize = 100;
    final uri = Uri.https('literotica.com', '/api/3/tagsportal/stories', {
      'params': jsonEncode({
        'tags': filters.tags.map((tag) => tag.id).toList(),
        'page': page,
        'pageSize': pageSize,
        'period': filters.period.apiValue,
        'periodCheck': true,
      }),
    });
    final decoded = await _getJson(uri);
    final submissions = decoded['submissions'];
    final meta = decoded['meta'];
    if (submissions is! List || meta is! Map<String, dynamic>) {
      throw const FormatException('Tag search response is missing stories.');
    }
    final items = submissions
        .whereType<Map<String, dynamic>>()
        .where((story) => _asInt(story['category']) == filters.category.id)
        .map((story) => ListorItem.fromJson(story, filters.category))
        .toList();
    return _SearchPage(
      items: items,
      pageSize: pageSize,
      total: _asInt(meta['submissions_count']),
    );
  }

  Future<_SearchPage> _search({
    required ListorCategory category,
    required int page,
    bool popular = false,
  }) async {
    // Version 2.1.0 serializes all arguments as JSON in one `params` value.
    final params = jsonEncode({
      'q': '',
      'page': page,
      'categories': [category.id],
      'editorsChoice': false,
      'popular': popular,
      'winner': false,
      'languages': [1],
      'type': 'story',
    });
    final uri = Uri.https('literotica.com', '/api/3/search/stories', {
      'params': params,
    });
    final decoded = await _getJson(uri);
    final data = decoded['data'];
    final meta = decoded['meta'];
    if (data is! List || meta is! Map<String, dynamic>) {
      throw const FormatException('Story search response is missing data.');
    }
    final items = data
        .whereType<Map<String, dynamic>>()
        .where((story) => _asInt(story['category']) == category.id)
        .map((story) => ListorItem.fromJson(story, category))
        .toList();
    return _SearchPage(
      items: items,
      pageSize: max(1, _asInt(meta['pageSize'])),
      total: _asInt(meta['total']),
    );
  }

  Future<_StoryPage> _storyPage(String slug, int page) async {
    final uri = Uri.https('literotica.com', '/api/3/stories/$slug', {
      'params': jsonEncode({'contentPage': page}),
    });
    final decoded = await _getJson(uri);
    final meta = decoded['meta'];
    final text = decoded['pageText'];
    if (meta is! Map<String, dynamic> || text is! String) {
      throw const FormatException('Story response is missing page content.');
    }
    return _StoryPage(
      text: text,
      pageCount: max(1, _asInt(meta['pages_count'])),
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Listor Flutter (LiteroticaApi/2.1.0 compatible)',
      },
    );
    if (response.statusCode != 200) {
      throw LiteroticaApiException(
        'The story service returned HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected a JSON object from the story service.',
      );
    }
    return decoded;
  }
}

ListorItem _authorWorkItem(Map<String, dynamic> json, String author) {
  final categoryId = _asInt(
    json['category'] ??
        (json['category_info'] is Map<String, dynamic>
            ? (json['category_info'] as Map<String, dynamic>)['id']
            : null),
  );
  final category = ListorCategory.values.firstWhere(
    (candidate) => candidate.id == categoryId,
    orElse: () => ListorCategory.nonErotic,
  );
  final rawAuthor = json['author'];
  final username = rawAuthor is Map<String, dynamic>
      ? rawAuthor['username']?.toString()
      : json['authorname']?.toString();
  return ListorItem(
    id: _asInt(json['id']),
    title: json['title']?.toString() ?? 'Untitled',
    description: json['description']?.toString() ?? '',
    category: category,
    author: username?.isNotEmpty == true ? username! : author,
    approvedAt: _parseApiDate(json['date_approve']?.toString()),
    favoriteCount: _asInt(json['favorite_count']),
    rating: _asDouble(json['rate_all']),
    url: _storyUri(json['url']),
  );
}

Uri _storyUri(Object? value) {
  final raw = value?.toString().trim() ?? '';
  final absolute = Uri.tryParse(raw);
  if (absolute?.hasScheme == true) return absolute!;
  final slug = raw.replaceFirst(RegExp(r'^/?s/'), '');
  return Uri.https('www.literotica.com', '/s/$slug');
}

class LiteroticaApiException implements Exception {
  const LiteroticaApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _SearchPage {
  const _SearchPage({
    required this.items,
    required this.pageSize,
    required this.total,
  });
  final List<ListorItem> items;
  final int pageSize;
  final int total;
  int get lastPage => max(1, (total / pageSize).ceil());
}

class _StoryPage {
  const _StoryPage({required this.text, required this.pageCount});

  final String text;
  final int pageCount;
}

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double? _asDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value');
DateTime? _parseUsDate(String? value) {
  final parts = value?.split('/');
  if (parts == null || parts.length != 3) return null;
  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  return month == null || day == null || year == null
      ? null
      : DateTime(year, month, day);
}

DateTime? _parseApiDate(String? value) =>
    _parseUsDate(value) ?? DateTime.tryParse(value ?? '');

int _dateValue(ListorItem item) => item.approvedAt?.millisecondsSinceEpoch ?? 0;

bool _isInPeriod(DateTime? date, StoryPeriod period) {
  if (period == StoryPeriod.all) return true;
  if (date == null) return false;
  final days = period == StoryPeriod.week ? 7 : 30;
  return !date.isBefore(DateTime.now().subtract(Duration(days: days)));
}
