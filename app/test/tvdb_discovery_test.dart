import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/tmdb/tvdb.dart';
import 'package:tracktime/tmdb/search_result.dart';

void main() {
  test(
    'nouveautés : années vérifiées, futurs exclus, récents en tête, dédoublonnage',
    () async {
      final queries = <Map<String, String>>[];
      final client = TvdbClient(
        'test',
        now: () => DateTime(2026, 9, 14),
        client: MockClient((req) async {
          if (req.url.path.endsWith('/login')) {
            return http.Response('{"data":{"token":"t"}}', 200);
          }
          queries.add(req.url.queryParameters);
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 1,
                  'name': 'Ancien',
                  'year': '2006',
                  'image': '/old.jpg',
                  'status': {'name': 'Released'},
                },
                {
                  'id': 2,
                  'name': 'Annoncé',
                  'year': '2026',
                  'image': '/future.jpg',
                  'status': {'name': 'Filming / Post-Production'},
                },
                {
                  'id': 3,
                  'name': 'Récent 2025',
                  'year': '2025',
                  'image': '/recent.jpg',
                  'status': {'name': 'Released'},
                },
                {
                  'id': 4,
                  'name': 'Nouveau 2026',
                  'year': '2026',
                  'image': '/new.jpg',
                  'status': {'name': 'Released'},
                },
                {
                  'id': 5,
                  'name': 'Sans statut',
                  'year': '2026',
                  'image': '/unknown.jpg',
                },
              ],
            }),
            200,
          );
        }),
      );
      final rows = await client.recentReleases(movies: true);
      expect(rows.map((r) => r['id']), [4, 3]);
      expect(queries.map((q) => q['year']).toSet(), {'2026', '2025'});
    },
  );

  test(
    'une série future ne devient pas une nouveauté, même avec une année passée',
    () async {
      final client = TvdbClient(
        'test',
        now: () => DateTime(2026, 9, 14),
        client: MockClient((req) async {
          if (req.url.path.endsWith('/login')) {
            return http.Response('{"data":{"token":"t"}}', 200);
          }
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 1,
                  'name': 'Future',
                  'year': '2026',
                  'firstAired': '2026-12-25',
                  'image': '/a.jpg',
                  'status': {'name': 'Upcoming'},
                },
                {
                  'id': 2,
                  'name': 'Récente',
                  'year': '2026',
                  'firstAired': '2026-05-12',
                  'image': '/b.jpg',
                  'status': {'name': 'Continuing'},
                },
                {
                  'id': 3,
                  'name': 'Mal datée',
                  'year': '2026',
                  'firstAired': '2011-01-01',
                  'image': '/c.jpg',
                  'status': {'name': 'Continuing'},
                },
              ],
            }),
            200,
          );
        }),
      );
      expect((await client.recentReleases(movies: false)).map((r) => r['id']), [
        2,
      ]);
    },
  );

  test(
    'animés : genres manquants enrichis, live action japonais et occidental exclus',
    () async {
      final details = <String>[];
      final client = TvdbClient(
        'test',
        client: MockClient((req) async {
          Object data;
          if (req.url.path.endsWith('/login')) {
            data = {'token': 't'};
          } else if (req.url.path.endsWith('/search')) {
            data = [
              {
                'type': 'series',
                'tvdb_id': '81797',
                'name': 'One Piece',
                'country': 'jpn',
              },
              {
                'type': 'series',
                'tvdb_id': '392276',
                'name': 'ONE PIECE (2023)',
                'country': 'usa',
              },
              {
                'type': 'movie',
                'tvdb_id': '10',
                'name': 'One Piece Film',
                'genres': ['Anime'],
              },
              {
                'type': 'series',
                'tvdb_id': '11',
                'name': 'Un drama japonais',
                'country': 'jpn',
              },
            ];
          } else {
            details.add(req.url.path);
            data = {
              'genres': [
                {'name': req.url.path.contains('81797') ? 'Anime' : 'Drama'},
              ],
            };
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      final rows = parseSearchResults(await client.searchAnime('one piece'));
      expect(rows.map((r) => r.tvdbId), [81797, 10]);
      expect(rows.every((r) => r.isAnime), isTrue);
      expect(details.length, 2);
      await client.searchAnime('one piece');
      expect(
        details.length,
        2,
        reason: 'les fiches de classification sont mises en cache',
      );
    },
  );
}
