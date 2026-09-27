import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:listor/literotica_api.dart';

void main() {
  test(
    'sends Non Erotic category 35 using the 2.1.0 params contract',
    () async {
      late Uri requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(_response(total: 1), 200);
      });

      final stories = await LiteroticaApiClient(
        client: client,
        random: Random(1),
      ).fetchFeed(const StoryFilters(), FeedType.popular);

      final params = jsonDecode(requestedUri.queryParameters['params']!);
      expect(requestedUri.path, '/api/3/search/stories');
      expect(params['categories'], [35]);
      expect(params['popular'], isTrue);
      expect(params['languages'], [1]);
      expect(stories.items.single.title, 'Non Erotic Sample');
      expect(stories.items.single.category, ListorCategory.nonErotic);
      expect(stories.hasMore, isFalse);
    },
  );

  test('new feed requests and sorts the newest category page', () async {
    final pages = <int>[];
    final client = MockClient((request) async {
      final params = jsonDecode(request.url.queryParameters['params']!);
      final page = params['page'] as int;
      pages.add(page);
      return http.Response(
        page == 1
            ? _response(total: 51)
            : _response(
                total: 51,
                stories: [
                  _story(id: 2, title: 'Older', date: '09/20/2026'),
                  _story(id: 3, title: 'Newest', date: '09/25/2026'),
                ],
              ),
        200,
      );
    });

    final stories = await LiteroticaApiClient(
      client: client,
    ).fetchFeed(const StoryFilters(), FeedType.newest);
    expect(pages, [1, 2]);
    expect(stories.items.map((story) => story.title), ['Newest', 'Older']);
    expect(stories.hasMore, isTrue);
  });

  test('requests the next API page for a subsequent feed batch', () async {
    final pages = <int>[];
    final client = MockClient((request) async {
      final params = jsonDecode(request.url.queryParameters['params']!);
      final page = params['page'] as int;
      pages.add(page);
      return http.Response(
        _response(
          total: 101,
          stories: [_story(id: page, title: 'Page $page')],
        ),
        200,
      );
    });

    final batch = await LiteroticaApiClient(
      client: client,
    ).fetchFeed(const StoryFilters(), FeedType.popular, page: 1);

    expect(pages, [1, 2]);
    expect(batch.items.single.title, 'Page 2');
    expect(batch.hasMore, isTrue);
  });

  test('throws a readable error for a failed response', () async {
    final client = MockClient((_) async => http.Response('unavailable', 503));
    final api = LiteroticaApiClient(client: client);
    expect(
      api.fetchFeed(const StoryFilters(), FeedType.newest),
      throwsA(
        isA<LiteroticaApiException>().having(
          (error) => error.message,
          'message',
          contains('503'),
        ),
      ),
    );
  });

  test('loads top tags for the selected category and period', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'tags': [
            {'tagid': 1189, 'tag': 'mystery'},
            {'tagid': 547, 'tag': 'adventure'},
          ],
        }),
        200,
      );
    });

    final tags = await LiteroticaApiClient(
      client: client,
    ).fetchTags(ListorCategory.nonErotic, StoryPeriod.month);
    final params = jsonDecode(requestedUri.queryParameters['params']!);

    expect(requestedUri.path, '/api/3/tagsportal/top');
    expect(params['category'], 35);
    expect(params['period'], 'month');
    expect(tags.map((tag) => tag.label), ['adventure', 'mystery']);
  });

  test('sends selected tags and period, then keeps the category', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'meta': {'submissions_count': 2},
          'submissions': [
            _story(),
            {..._story(id: 2, title: 'Different category'), 'category': 15},
          ],
        }),
        200,
      );
    });
    final filters = StoryFilters(
      period: StoryPeriod.week,
      tags: {
        const StoryTag(id: 1189, label: 'mystery'),
        const StoryTag(id: 547, label: 'adventure'),
      },
    );

    final stories = await LiteroticaApiClient(
      client: client,
    ).fetchFeed(filters, FeedType.newest);
    final params = jsonDecode(requestedUri.queryParameters['params']!);

    expect(requestedUri.path, '/api/3/tagsportal/stories');
    expect(params['tags'], containsAll([1189, 547]));
    expect(params['period'], 'week');
    expect(stories.items.single.category, ListorCategory.nonErotic);
  });

  test('loads every story page without flattening its HTML', () async {
    final requestedPages = <int>[];
    final client = MockClient((request) async {
      final params = jsonDecode(request.url.queryParameters['params']!);
      final page = params['contentPage'] as int;
      requestedPages.add(page);
      return http.Response(
        jsonEncode({
          'meta': {'pages_count': 2},
          'pageText': page == 1
              ? '<p align="center"><strong>Title</strong></p>'
              : 'Text with <em>emphasis</em>.',
        }),
        200,
      );
    });

    final document = await LiteroticaApiClient(
      client: client,
    ).fetchStory(_item());

    expect(requestedPages, [1, 2]);
    expect(document.pages.first, contains('<strong>Title</strong>'));
    expect(document.pages.last, contains('<em>emphasis</em>'));
  });

  test('loads an author’s series and standalone stories', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'current_page': 1,
          'last_page': 1,
          'data': [
            {
              'id': 90,
              'title': 'Harbour Lights',
              'description': 'A connected series.',
              'parts': [
                {
                  'id': 91,
                  'title': 'Harbour Lights Ch. 01',
                  'description': 'The beginning.',
                  'category': 35,
                  'authorname': 'Sample Author',
                  'date_approve': '09/20/2026',
                  'favorite_count': 8,
                  'rate_all': 4.6,
                  'url': 'harbour-lights-1',
                },
                {
                  'id': 92,
                  'title': 'Harbour Lights Ch. 02',
                  'description': 'The continuation.',
                  'category': 35,
                  'authorname': 'Sample Author',
                  'url': 'harbour-lights-2',
                },
              ],
            },
            {
              ..._story(id: 93, title: 'Standalone Story'),
              'parts': null,
              'url': 'standalone-story',
            },
          ],
        }),
        200,
      );
    });

    final works = await LiteroticaApiClient(
      client: client,
    ).fetchAuthorWorks('Sample Author');
    final params = jsonDecode(requestedUri.queryParameters['params']!);

    expect(requestedUri.path, '/api/3/users/Sample%20Author/series_and_works');
    expect(params['pageSize'], 500);
    expect(params['listType'], 'expanded');
    expect(params['sort'], 'title');
    expect(works.series.single.title, 'Harbour Lights');
    expect(works.series.single.stories.map((story) => story.title), [
      'Harbour Lights Ch. 01',
      'Harbour Lights Ch. 02',
    ]);
    expect(works.series.single.stories.first.seriesId, 90);
    expect(works.series.single.stories.first.seriesTitle, 'Harbour Lights');
    expect(works.series.single.stories.first.seriesPosition, 0);
    expect(works.series.single.stories.last.seriesPosition, 1);
    expect(works.stories.single.title, 'Standalone Story');
  });
}

String _response({int total = 1, List<Map<String, Object?>>? stories}) =>
    jsonEncode({
      'data': stories ?? [_story()],
      'meta': {'pageSize': 50, 'total': total},
    });

Map<String, Object?> _story({
  int id = 1,
  String title = 'Non Erotic Sample',
  String date = '09/25/2026',
}) => {
  'id': id,
  'title': title,
  'description': 'Sample description',
  'category': 35,
  'author': {'username': 'Sample Author'},
  'date_approve': date,
  'favorite_count': 12,
  'rate_all': 4.75,
  'url': 'non-erotic-sample',
};

ListorItem _item() => ListorItem(
  id: 1,
  title: 'Sample',
  description: 'Sample description',
  category: ListorCategory.nonErotic,
  author: 'Sample Author',
  approvedAt: DateTime(2026, 9, 25),
  favoriteCount: 12,
  rating: 4.75,
  url: Uri.parse('https://www.literotica.com/s/non-erotic-sample'),
);
