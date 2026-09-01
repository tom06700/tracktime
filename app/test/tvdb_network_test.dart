import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/tmdb/tvdb.dart';

/// Serveur TheTVDB scriptable : on décrit ce que renvoie chaque appel, et on
/// relit ce qui a été demandé.
class _Server {
  _Server(this.responses);

  /// Une réponse par appel non-login ; la dernière est répétée ensuite.
  final List<http.Response> responses;

  final List<String> calls = [];
  int logins = 0;

  /// Retard appliqué à chaque réponse — pour éprouver le délai d'abandon.
  Duration? latency;

  int get requests => calls.length;

  http.Client get client => MockClient((req) async {
    if (req.url.path.endsWith('/login')) {
      logins++;
      return http.Response('{"data":{"token":"t"}}', 200);
    }
    calls.add('${req.url.path}?${req.url.query}');
    if (latency != null) await Future<void>.delayed(latency!);
    final i = calls.length - 1;
    return responses[i < responses.length ? i : responses.length - 1];
  });
}

http.Response _ok(Object? data) => http.Response(
  jsonEncode({'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _status(int code, {Map<String, String>? headers}) =>
    http.Response('nope', code, headers: headers ?? const {});

/// Horloge que le test avance à la main.
class _Clock {
  DateTime value = DateTime(2026, 8, 30, 12);
  DateTime call() => value;
  void advance(Duration d) => value = value.add(d);
}

void main() {
  group('images de découverte', () {
    test('le filtre films rend ses affiches relatives chargeables', () async {
      // `/movies/filter` renvoie `/banners/...` là où `/series/filter` renvoie
      // des URLs complètes : « Films populaires » et « Sorties annoncées »
      // n'affichaient que des dégradés sur l'app réelle.
      final server = _Server([
        _ok([
          {'id': 63, 'name': 'Harry Potter', 'image': '/banners/movies/63/p.jpg'},
          {'id': 1, 'name': 'Sans affiche', 'image': ''},
          {'id': 2, 'name': 'Sans affiche non plus'},
        ]),
      ]);
      final tvdb = TvdbClient('k', client: server.client);

      final list = await tvdb.mostPopular(movies: true);

      expect(list.map((e) => e['name']), ['Harry Potter']);
      expect(
        list.single['image'],
        'https://artworks.thetvdb.com/banners/movies/63/p.jpg',
      );
    });

    test('une URL complète du filtre séries reste telle quelle', () async {
      const u = 'https://artworks.thetvdb.com/banners/posters/305288-4.jpg';
      final server = _Server([
        _ok([
          {'id': 305288, 'name': 'Stranger Things', 'image': u},
        ]),
      ]);
      final tvdb = TvdbClient('k', client: server.client);

      final list = await tvdb.mostPopular(movies: false);

      expect(list.single['image'], u);
    });
  });

  group('erreurs typées', () {
    Future<TvdbException> failureFor(http.Response r) async {
      final server = _Server([r]);
      final tvdb = TvdbClient(
        'k',
        client: server.client,
        maxAttempts: 1,
        sleep: (_) async {},
      );
      try {
        await tvdb.seriesExtended(1);
        fail('aurait dû lever');
      } on TvdbException catch (e) {
        return e;
      }
    }

    test('404 : introuvable, et rien à réessayer', () async {
      final e = await failureFor(_status(404));
      expect(e.kind, TvdbErrorKind.notFound);
      expect(e.isTransient, isFalse);
      expect(e.message, 'Introuvable sur TheTVDB.');
    });

    test('429 : limite de débit, passager', () async {
      final e = await failureFor(_status(429));
      expect(e.kind, TvdbErrorKind.rateLimited);
      expect(e.isTransient, isTrue);
      expect(e.message, contains('Réessaie'));
    });

    test('500 : indisponible, passager', () async {
      final e = await failureFor(_status(500));
      expect(e.kind, TvdbErrorKind.server);
      expect(e.isTransient, isTrue);
    });

    test('réponse illisible', () async {
      final e = await failureFor(http.Response('pas du json', 200));
      expect(e.kind, TvdbErrorKind.malformed);
    });

    test('coupure réseau', () async {
      final tvdb = TvdbClient(
        'k',
        maxAttempts: 1,
        sleep: (_) async {},
        client: MockClient((req) async {
          if (req.url.path.endsWith('/login')) {
            return http.Response('{"data":{"token":"t"}}', 200);
          }
          throw const SocketExceptionStub();
        }),
      );
      try {
        await tvdb.seriesExtended(1);
        fail('aurait dû lever');
      } on TvdbException catch (e) {
        expect(e.kind, TvdbErrorKind.network);
        expect(e.message, 'Pas de connexion. Vérifie ton réseau.');
        expect(e.detail, isNotNull, reason: 'le détail va dans les traces');
      }
    });

    test('sans clé, aucune requête n\'est tentée', () async {
      final server = _Server([_ok({})]);
      final tvdb = TvdbClient('', client: server.client);
      await expectLater(tvdb.seriesExtended(1), throwsA(isA<TvdbException>()));
      expect(server.requests, 0);
      expect(server.logins, 0);
    });
  });

  group('délai et réessais', () {
    test('une requête qui traîne est abandonnée', () async {
      final server = _Server([_ok({})])..latency = const Duration(seconds: 2);
      final tvdb = TvdbClient(
        'k',
        client: server.client,
        timeout: const Duration(milliseconds: 50),
        maxAttempts: 1,
        sleep: (_) async {},
      );

      try {
        await tvdb.seriesExtended(1);
        fail('aurait dû lever');
      } on TvdbException catch (e) {
        expect(e.kind, TvdbErrorKind.timeout);
      }
    });

    test('un échec passager est réessayé, un nombre fini de fois', () async {
      final server = _Server([_status(500)]);
      final waits = <Duration>[];
      final tvdb = TvdbClient(
        'k',
        client: server.client,
        maxAttempts: 3,
        sleep: (d) async => waits.add(d),
      );

      await expectLater(tvdb.seriesExtended(1), throwsA(isA<TvdbException>()));
      expect(server.requests, 3, reason: 'trois tentatives, pas plus');
      expect(waits, hasLength(2));
      expect(waits.first < waits.last, isTrue, reason: 'attente croissante');
    });

    test('un réessai qui aboutit rend la réponse', () async {
      final server = _Server([
        _status(500),
        _ok({'name': 'Dark'}),
      ]);
      final tvdb = TvdbClient('k', client: server.client, sleep: (_) async {});

      expect((await tvdb.seriesExtended(1))['name'], 'Dark');
      expect(server.requests, 2);
    });

    test('une erreur définitive n\'est jamais réessayée', () async {
      final server = _Server([_status(404)]);
      final tvdb = TvdbClient('k', client: server.client, sleep: (_) async {});

      await expectLater(tvdb.seriesExtended(1), throwsA(isA<TvdbException>()));
      expect(server.requests, 1);
    });

    test('429 : l\'attente suit l\'en-tête Retry-After', () async {
      final server = _Server([
        _status(429, headers: {'retry-after': '4'}),
        _ok({'name': 'Dark'}),
      ]);
      final waits = <Duration>[];
      final tvdb = TvdbClient(
        'k',
        client: server.client,
        sleep: (d) async => waits.add(d),
      );

      await tvdb.seriesExtended(1);
      expect(waits.single, const Duration(seconds: 4));
    });
  });

  group('authentification', () {
    test('un 401 déclenche un re-login, une seule fois', () async {
      final server = _Server([
        _status(401),
        _ok({'name': 'Dark'}),
      ]);
      final tvdb = TvdbClient('k', client: server.client, sleep: (_) async {});

      expect((await tvdb.seriesExtended(1))['name'], 'Dark');
      expect(server.logins, 2, reason: 'login initial puis re-login');
    });

    test(
      'un 401 persistant devient une erreur d\'accès, sans boucler',
      () async {
        final server = _Server([_status(401)]);
        final tvdb = TvdbClient(
          'k',
          client: server.client,
          sleep: (_) async {},
        );

        try {
          await tvdb.seriesExtended(1);
          fail('aurait dû lever');
        } on TvdbException catch (e) {
          expect(e.kind, TvdbErrorKind.auth);
          expect(e.isTransient, isFalse);
        }
        expect(server.requests, 2, reason: 'la tentative, puis celle d\'après');
      },
    );
  });

  group('cache', () {
    test('deux lectures rapprochées ne font qu\'une requête', () async {
      final server = _Server([
        _ok({'name': 'Dark'}),
      ]);
      final tvdb = TvdbClient('k', client: server.client);

      await tvdb.seriesExtended(1);
      await tvdb.seriesExtended(1);

      expect(server.requests, 1);
    });

    test('passé la durée de vie, la ressource est relue', () async {
      final clock = _Clock();
      final server = _Server([
        _ok({'name': 'Dark'}),
      ]);
      final tvdb = TvdbClient('k', client: server.client, now: clock.call);

      await tvdb.seriesExtended(1);
      clock.advance(const Duration(hours: 25));
      await tvdb.seriesExtended(1);

      expect(server.requests, 2);
    });

    test('force ignore la durée de vie', () async {
      final server = _Server([
        _ok({'name': 'Dark'}),
      ]);
      final tvdb = TvdbClient('k', client: server.client);

      await tvdb.seriesExtended(1);
      await tvdb.seriesExtended(1, force: true);

      expect(server.requests, 2);
    });

    test('deux appels simultanés partagent la même requête', () async {
      final server = _Server([
        _ok({'name': 'Dark'}),
      ])..latency = const Duration(milliseconds: 30);
      final tvdb = TvdbClient('k', client: server.client);

      final results = await Future.wait([
        tvdb.seriesExtended(1),
        tvdb.seriesExtended(1),
      ]);

      expect(server.requests, 1);
      expect(results[0]['name'], 'Dark');
      expect(results[1]['name'], 'Dark');
    });

    test('des ressources différentes ne se confondent pas', () async {
      final server = _Server([
        _ok({'name': 'Dark'}),
        _ok({'name': 'Arcane'}),
      ]);
      final tvdb = TvdbClient('k', client: server.client);

      expect((await tvdb.seriesExtended(1))['name'], 'Dark');
      expect((await tvdb.seriesExtended(2))['name'], 'Arcane');
      expect(server.requests, 2);
    });

    test('la recherche est mémorisée par requête et par type', () async {
      final server = _Server([
        _ok([
          {'tvdb_id': '1', 'name': 'Dark', 'type': 'series'},
        ]),
      ]);
      final tvdb = TvdbClient('k', client: server.client);

      await tvdb.search('dark', type: 'series');
      await tvdb.search('dark', type: 'series');
      await tvdb.search('dark', type: 'movie');

      expect(server.requests, 2);
    });

    test('la découverte est mémorisée', () async {
      final server = _Server([
        _ok([
          {'name': 'Dark', 'image': '/d.jpg'},
        ]),
      ]);
      final tvdb = TvdbClient('k', client: server.client);

      await tvdb.mostPopular(movies: false);
      await tvdb.mostPopular(movies: false);
      // Films et séries sont deux ressources distinctes.
      await tvdb.mostPopular(movies: true);

      expect(server.requests, 2);
    });
  });

  group('conservation des données en cas d\'échec', () {
    test('un rafraîchissement raté rend la version précédente', () async {
      final clock = _Clock();
      final server = _Server([
        _ok({'name': 'Dark'}),
        _status(500),
      ]);
      final tvdb = TvdbClient(
        'k',
        client: server.client,
        maxAttempts: 1,
        sleep: (_) async {},
        now: clock.call,
      );

      expect((await tvdb.seriesExtended(1))['name'], 'Dark');
      clock.advance(const Duration(hours: 25));

      // TheTVDB est tombé : mieux vaut la fiche d'hier qu'un écran d'erreur.
      expect((await tvdb.seriesExtended(1))['name'], 'Dark');
      expect(server.requests, 2);
    });

    test('un rafraîchissement forcé qui échoue le dit', () async {
      final server = _Server([
        _ok({'name': 'Dark'}),
        _status(500),
      ]);
      final tvdb = TvdbClient(
        'k',
        client: server.client,
        maxAttempts: 1,
        sleep: (_) async {},
      );

      await tvdb.seriesExtended(1);

      // Sinon un « tirer pour rafraîchir » se croirait réussi sur du vieux.
      await expectLater(
        tvdb.seriesExtended(1, force: true),
        throwsA(isA<TvdbException>()),
      );
    });

    test('un échec forcé ne détruit pas ce qui était connu', () async {
      final server = _Server([
        _ok({'name': 'Dark'}),
        _status(500),
        _status(500),
      ]);
      final tvdb = TvdbClient(
        'k',
        client: server.client,
        maxAttempts: 1,
        sleep: (_) async {},
      );

      await tvdb.seriesExtended(1);
      await expectLater(
        tvdb.seriesExtended(1, force: true),
        throwsA(isA<TvdbException>()),
      );

      // La lecture normale suivante retrouve la fiche.
      expect((await tvdb.seriesExtended(1))['name'], 'Dark');
    });

    test('sans version précédente, l\'échec remonte', () async {
      final server = _Server([_status(500)]);
      final tvdb = TvdbClient(
        'k',
        client: server.client,
        maxAttempts: 1,
        sleep: (_) async {},
      );

      await expectLater(tvdb.seriesExtended(1), throwsA(isA<TvdbException>()));
    });
  });

  group('traductions', () {
    test(
      'une traduction absente rend {} sans faire échouer la fiche',
      () async {
        final server = _Server([_status(404)]);
        final tvdb = TvdbClient(
          'k',
          client: server.client,
          sleep: (_) async {},
        );

        expect(await tvdb.seriesTranslation(1, 'fra'), isEmpty);
      },
    );

    test('un échec de traduction n\'est pas mémorisé', () async {
      final server = _Server([
        _status(500),
        _ok({'name': 'One Piece'}),
      ]);
      final tvdb = TvdbClient(
        'k',
        client: server.client,
        maxAttempts: 1,
        sleep: (_) async {},
      );

      expect(await tvdb.seriesTranslation(1, 'fra'), isEmpty);
      // Sinon une coupure passagère priverait la fiche de son titre français
      // pendant toute la durée de vie du cache.
      expect((await tvdb.seriesTranslation(1, 'fra'))['name'], 'One Piece');
    });

    test('une traduction obtenue est mémorisée', () async {
      final server = _Server([
        _ok({'name': 'One Piece'}),
      ]);
      final tvdb = TvdbClient('k', client: server.client);

      await tvdb.seriesTranslation(1, 'fra');
      await tvdb.seriesTranslation(1, 'fra');

      expect(server.requests, 1);
    });
  });
}

/// Panne de transport, telle que la voit `package:http`.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketException: connexion refusée';
}
