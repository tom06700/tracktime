import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/tmdb/tvdb.dart';

/// Serveur TheTVDB de test pour `/series/{id}/episodes/official[/{lang}]`.
///
/// Le vrai serveur répond à la variante traduite avec la même structure mais
/// des textes nuls quand la série n'a pas de traduction : c'est ce piège que
/// ces tests reproduisent.
class _Eps {
  _Eps({required this.original, this.french = const []});

  /// (saison, numéro, titre, résumé) servis sans langue.
  final List<(int, int, String?, String?)> original;

  /// Idem pour `/fra`. Vide = série non traduite.
  final List<(int, int, String?, String?)> french;

  final List<String> paths = [];

  TvdbClient client() => TvdbClient(
        'test-key',
        client: MockClient((req) async {
          if (req.url.path.endsWith('/login')) {
            return http.Response('{"data":{"token":"t"}}', 200);
          }
          paths.add(req.url.path);
          final fr = req.url.path.endsWith('/fra');
          // Série non traduite : structure complète, textes nuls.
          final rows = fr && french.isEmpty
              ? [
                  for (final (s, n, _, _) in original) (s, n, null, null),
                ]
              : (fr ? french : original);
          return http.Response(
            jsonEncode({
              'data': {
                'episodes': [
                  for (final (s, n, name, overview) in rows)
                    {
                      'seasonNumber': s,
                      'number': n,
                      'name': name,
                      'overview': overview,
                      'image': '/still-${s}x$n.jpg',
                      'aired': '2026-01-01',
                    },
                ],
              },
              'links': {'next': null},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

  int get frenchCalls => paths.where((p) => p.endsWith('/fra')).length;
  int get originalCalls => paths.where((p) => !p.endsWith('/fra')).length;
}

void main() {
  test('les stills relatifs de l\'API deviennent des URLs chargeables',
      () async {
    // `/series/{id}/episodes` renvoie `/banners/...`, pas une URL : passé tel
    // quel à Image.network, chaque carte d'accueil restait sur son dégradé.
    final api = _Eps(original: [(1, 7, 'Combat acharné', null)]);

    final eps = await api.client().seriesEpisodes(81797);

    expect(eps.single['image'], 'https://artworks.thetvdb.com/still-1x7.jpg');
  });

  test('les titres arrivent en français, pas dans la langue d\'origine',
      () async {
    // One Piece : sans langue, TheTVDB rend les titres japonais.
    final api = _Eps(
      original: [(1, 1, 'ONE PIECE 倒せ!海賊ギャンザック', 'Luffy sets sail.')],
      french: [
        (1, 1, 'Je suis Luffy !', 'Luffy prend la mer.'),
      ],
    );

    final eps = await api.client().seriesEpisodes(81797);

    expect(eps.single['name'], 'Je suis Luffy !');
    expect(eps.single['overview'], 'Luffy prend la mer.');
  });

  test('une série entièrement traduite ne coûte qu\'un aller', () async {
    final api = _Eps(
      original: [(1, 1, 'Pilot', 'A pilot.')],
      french: [(1, 1, 'Pilote', 'Un pilote.')],
    );

    await api.client().seriesEpisodes(1);

    expect(api.frenchCalls, 1);
    expect(api.originalCalls, 0, reason: 'rien à combler');
  });

  test('série non traduite : on retombe sur les textes d\'origine', () async {
    final api = _Eps(
      original: [
        (1, 1, 'Pilot', 'A pilot.'),
        (1, 2, 'Second', 'The second one.'),
      ],
    );

    final eps = await api.client().seriesEpisodes(1);

    expect(eps.map((e) => e['name']), ['Pilot', 'Second']);
    expect(eps.first['overview'], 'A pilot.');
    expect(api.originalCalls, 1);
  });

  test('traduction partielle : chaque trou est comblé isolément', () async {
    final api = _Eps(
      original: [
        (1, 1, 'Pilot', 'A pilot.'),
        (1, 2, 'Second', 'The second one.'),
      ],
      french: [
        (1, 1, 'Pilote', null), // titre traduit, résumé absent
        (1, 2, 'Deuxième', 'Le deuxième.'),
      ],
    );

    final eps = await api.client().seriesEpisodes(1);

    expect(eps.map((e) => e['name']), ['Pilote', 'Deuxième']);
    expect(eps.first['overview'], 'A pilot.', reason: 'comblé par l\'original');
    expect(eps.last['overview'], 'Le deuxième.');
    expect(api.originalCalls, 1);
  });

  test('les textes vides comptent comme absents', () async {
    final api = _Eps(
      original: [(1, 1, 'Pilot', 'A pilot.')],
      french: [(1, 1, '   ', '')],
    );

    final eps = await api.client().seriesEpisodes(1);

    expect(eps.single['name'], 'Pilot');
    expect(eps.single['overview'], 'A pilot.');
  });

  test('la liste est mise en cache, et force la relit', () async {
    final api = _Eps(
      original: [(1, 1, 'Pilot', 'A pilot.')],
      french: [(1, 1, 'Pilote', 'Un pilote.')],
    );
    final tvdb = api.client();

    await tvdb.seriesEpisodes(1);
    await tvdb.seriesEpisodes(1);
    expect(api.frenchCalls, 1, reason: 'deuxième lecture servie par le cache');

    await tvdb.seriesEpisodes(1, force: true);
    expect(api.frenchCalls, 2);
  });
}
