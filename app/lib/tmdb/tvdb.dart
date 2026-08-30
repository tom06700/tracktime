import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Nature d'un échec TheTVDB.
///
/// Sert à deux décisions qu'on ne peut pas prendre sur un simple message :
/// faut-il réessayer, et que dire à l'utilisateur.
enum TvdbErrorKind {
  /// Pas de connexion, DNS injoignable, coupure en cours de transfert.
  network,

  /// Le serveur n'a pas répondu dans le délai imparti.
  timeout,

  /// Clé absente ou refusée.
  auth,

  /// 429 : trop de requêtes.
  rateLimited,

  /// 5xx.
  server,

  /// 404 : l'œuvre n'existe pas (ou plus) chez TheTVDB.
  notFound,

  /// Réponse reçue mais illisible.
  malformed,

  /// Autre code d'erreur HTTP.
  http,
}

class TvdbException implements Exception {
  const TvdbException(
    this.message, {
    this.kind = TvdbErrorKind.network,
    this.status,
    this.detail,
  });

  /// Phrase destinée à l'utilisateur. Jamais un code, jamais une trace.
  final String message;

  final TvdbErrorKind kind;
  final int? status;

  /// Détail technique, pour les traces uniquement.
  final String? detail;

  /// Un échec passager mérite une nouvelle tentative ; une clé refusée ou une
  /// fiche inexistante n'en méritent aucune.
  bool get isTransient =>
      kind == TvdbErrorKind.network ||
      kind == TvdbErrorKind.timeout ||
      kind == TvdbErrorKind.rateLimited ||
      kind == TvdbErrorKind.server;

  @override
  String toString() => message;
}

/// Entrée de cache : une valeur et l'instant où elle a été obtenue.
class _Cached {
  const _Cached(this.value, this.at);

  final Object? value;
  final DateTime at;
}

/// Client de l'API TheTVDB v4.
///
/// Authentification : `POST /login` avec la clé projet renvoie un token JWT
/// valable ~1 mois, mis en cache ici (re-login automatique s'il est périmé ou
/// sur un 401).
///
/// Chaque appel est borné par un délai, réessayé un nombre fini de fois sur
/// les échecs passagers, et mémorisé le temps d'une durée de vie propre à la
/// ressource. Deux appels identiques lancés en même temps partagent la même
/// requête, et un rafraîchissement raté ne fait jamais perdre ce qui était
/// déjà connu.
class TvdbClient {
  TvdbClient(
    this.apiKey, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 15),
    int maxAttempts = 3,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
  })  : _http = client ?? http.Client(),
        _timeout = timeout,
        _maxAttempts = maxAttempts < 1 ? 1 : maxAttempts,
        _sleep = sleep ?? Future<void>.delayed,
        _now = now ?? DateTime.now;

  /// Clé projet TheTVDB (v4).
  final String apiKey;
  final http.Client _http;

  /// Délai au-delà duquel une requête est abandonnée. Sans lui, une connexion
  /// qui n'aboutit jamais laisse un écran en chargement indéfiniment.
  final Duration _timeout;

  /// Nombre total de tentatives, réessais compris.
  final int _maxAttempts;

  /// Injectable : les tests ne doivent pas attendre réellement.
  final Future<void> Function(Duration) _sleep;

  /// Injectable : vérifier une durée de vie suppose de pouvoir avancer
  /// l'horloge sans attendre des heures.
  final DateTime Function() _now;

  static const _host = 'api4.thetvdb.com';

  String? _token;
  DateTime? _tokenAt;

  final Map<String, _Cached> _cache = {};
  final Map<String, Future<Object?>> _inFlight = {};

  /// Durées de vie par nature de ressource. Une fiche bouge moins souvent
  /// qu'une liste de découverte, une traduction encore moins.
  static const _ttlSearch = Duration(minutes: 10);
  static const _ttlDiscovery = Duration(hours: 6);
  static const _ttlDetails = Duration(hours: 24);
  static const _ttlEpisodes = Duration(hours: 6);
  static const _ttlTranslation = Duration(days: 7);

  /// Vide tout le cache mémoire. Le token reste valide.
  @visibleForTesting
  void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  bool get _tokenFresh =>
      _token != null &&
      _tokenAt != null &&
      _now().difference(_tokenAt!) < const Duration(days: 20);

  Future<String> _ensureToken() async {
    if (_tokenFresh) return _token!;
    if (apiKey.isEmpty) {
      throw const TvdbException(
        'Ajoute ta clé TheTVDB dans ⚙️ Réglages.',
        kind: TvdbErrorKind.auth,
      );
    }
    final r = await _send(
      () => _http.post(
        Uri.https(_host, '/v4/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'apikey': apiKey}),
      ),
    );
    if (r.statusCode != 200) {
      throw _errorFor(r, authMessage: 'Accès à TheTVDB refusé.');
    }
    final data = _decode(r)['data'];
    final token = (data is Map ? data['token'] : null) as String?;
    if (token == null || token.isEmpty) {
      throw const TvdbException(
        'Réponse inattendue de TheTVDB.',
        kind: TvdbErrorKind.malformed,
      );
    }
    _token = token;
    _tokenAt = _now();
    return token;
  }

  /// Envoie une requête, bornée dans le temps, et traduit les pannes de
  /// transport en erreurs typées.
  Future<http.Response> _send(Future<http.Response> Function() run) async {
    try {
      return await run().timeout(_timeout);
    } on TimeoutException {
      throw const TvdbException(
        'TheTVDB met trop de temps à répondre.',
        kind: TvdbErrorKind.timeout,
      );
    } on TvdbException {
      rethrow;
    } catch (e) {
      throw TvdbException(
        'Pas de connexion. Vérifie ton réseau.',
        kind: TvdbErrorKind.network,
        detail: '$e',
      );
    }
  }

  TvdbException _errorFor(http.Response r, {String? authMessage}) {
    final code = r.statusCode;
    if (code == 401 || code == 403) {
      return TvdbException(
        authMessage ?? 'Accès à TheTVDB refusé.',
        kind: TvdbErrorKind.auth,
        status: code,
      );
    }
    if (code == 404) {
      return TvdbException(
        'Introuvable sur TheTVDB.',
        kind: TvdbErrorKind.notFound,
        status: code,
      );
    }
    if (code == 429) {
      return TvdbException(
        'TheTVDB limite les requêtes. Réessaie dans un instant.',
        kind: TvdbErrorKind.rateLimited,
        status: code,
        detail: r.headers['retry-after'],
      );
    }
    if (code >= 500) {
      return TvdbException(
        'TheTVDB est indisponible pour le moment.',
        kind: TvdbErrorKind.server,
        status: code,
      );
    }
    return TvdbException(
      'TheTVDB a refusé la demande.',
      kind: TvdbErrorKind.http,
      status: code,
    );
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      return json.decode(r.body) as Map<String, dynamic>;
    } catch (e) {
      throw TvdbException(
        'Réponse inattendue de TheTVDB.',
        kind: TvdbErrorKind.malformed,
        detail: '$e',
      );
    }
  }

  /// Attente avant un nouvel essai : croissante, et respectant `Retry-After`
  /// quand TheTVDB le donne.
  Duration _backoff(int attempt, TvdbException e) {
    final header = int.tryParse(e.detail ?? '');
    if (e.kind == TvdbErrorKind.rateLimited && header != null) {
      return Duration(seconds: header.clamp(1, 30));
    }
    return Duration(milliseconds: 300 * (1 << (attempt - 1)));
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String> params = const {},
  ]) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _attempt(path, params);
      } on TvdbException catch (e) {
        if (!e.isTransient || attempt >= _maxAttempts) rethrow;
        debugPrint('TheTVDB $path : $e — nouvel essai ($attempt).');
        await _sleep(_backoff(attempt, e));
      }
    }
  }

  Future<Map<String, dynamic>> _attempt(
    String path,
    Map<String, String> params,
  ) async {
    var token = await _ensureToken();
    final uri = Uri.https(_host, '/v4$path', params.isEmpty ? null : params);
    var r = await _send(
      () => _http.get(uri, headers: {'Authorization': 'Bearer $token'}),
    );
    // Token périmé côté serveur → on relogue une fois avant d'abandonner.
    if (r.statusCode == 401) {
      _token = null;
      token = await _ensureToken();
      r = await _send(
        () => _http.get(uri, headers: {'Authorization': 'Bearer $token'}),
      );
    }
    if (r.statusCode != 200) throw _errorFor(r);
    return _decode(r);
  }

  /// Mémorise le résultat de [load] sous [key] pendant [ttl].
  ///
  /// Trois garanties :
  /// - deux appels identiques lancés en même temps partagent la même requête ;
  /// - [force] ignore la durée de vie, sans effacer ce qui est déjà là ;
  /// - un rafraîchissement raté rend la version précédente plutôt qu'une
  ///   erreur — sauf s'il était forcé, auquel cas l'appelant doit savoir que
  ///   sa demande n'a pas abouti.
  Future<T> _memo<T>(
    String key,
    Duration ttl,
    Future<T> Function() load, {
    bool force = false,
  }) {
    final hit = _cache[key];
    if (!force && hit != null && _now().difference(hit.at) < ttl) {
      return Future.value(hit.value as T);
    }

    var pending = _inFlight[key];
    if (pending == null) {
      pending = load().then((value) {
        _cache[key] = _Cached(value, _now());
        return value as Object?;
      });
      _inFlight[key] = pending;
      pending
          .whenComplete(() {
            if (identical(_inFlight[key], pending)) _inFlight.remove(key);
          })
          .ignore();
    }

    // La politique de repli est propre à chaque appelant : un rafraîchissement
    // forcé ne doit jamais réussir en silence sur d'anciennes données.
    return pending.then((v) => v as T).onError<TvdbException>((e, _) {
      final stale = _cache[key];
      if (!force && stale != null) {
        debugPrint('TheTVDB : « $key » non rafraîchi ($e), version conservée.');
        return stale.value as T;
      }
      throw e;
    });
  }

  /// Recherche séries + films. [type] : `'series'`, `'movie'` ou null (tous).
  ///
  /// La limite est volontairement haute : `/search` mélange aux médias des
  /// listes d'utilisateurs, des personnes et des sociétés, qui consomment des
  /// places. Sur « One Piece », six des vingt premiers résultats étaient des
  /// listes et l'anime original n'arrivait qu'en 38ᵉ position — donc jamais
  /// renvoyé. Le tri pertinent est fait ensuite, côté application.
  Future<List<Map<String, dynamic>>> search(
    String query, {
    String? type,
    bool force = false,
  }) {
    return _memo('search:${type ?? 'tout'}:$query', _ttlSearch, () async {
      final j = await _get('/search', {
        'query': query,
        'limit': '50',
        'type': ?type,
      });
      return ((j['data'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
    }, force: force);
  }

  /// Séries ou films les mieux notés, pour l'écran de découverte.
  ///
  /// TheTVDB v4 n'expose ni tendances ni nouveautés : `/{type}/filter` trié
  /// sur le score est le seul signal de popularité disponible. Le sens du tri
  /// doit être passé en minuscules — `sortType=DESC` est silencieusement
  /// ignoré et renvoie les fiches vides, sans image ni score.
  Future<List<Map<String, dynamic>>> mostPopular({
    required bool movies,
    bool force = false,
  }) => _filter(movies: movies, sort: 'score', force: force);

  /// Films dont la sortie est annoncée, du plus lointain au plus proche.
  Future<List<Map<String, dynamic>>> upcomingReleases({bool force = false}) =>
      _filter(movies: true, sort: 'firstAired', force: force);

  Future<List<Map<String, dynamic>>> _filter({
    required bool movies,
    required String sort,
    bool force = false,
  }) {
    final kind = movies ? 'movies' : 'series';
    return _memo('filter:$kind:$sort', _ttlDiscovery, () async {
      final j = await _get('/$kind/filter', {
        'sort': sort,
        'sortType': 'desc',
      });
      return ((j['data'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          // Sans affiche, une carte de découverte n'a aucun intérêt.
          .where((e) => (e['image'] as String?)?.isNotEmpty ?? false)
          .toList();
    }, force: force);
  }

  /// Détails étendus d'une série (saisons, genres, artworks, network…).
  Future<Map<String, dynamic>> seriesExtended(int id, {bool force = false}) {
    return _memo('series:$id', _ttlDetails, () async {
      final j = await _get('/series/$id/extended');
      return (j['data'] as Map<String, dynamic>?) ?? const {};
    }, force: force);
  }

  /// Détails étendus d'un film.
  Future<Map<String, dynamic>> movieExtended(int id, {bool force = false}) {
    return _memo('movie:$id', _ttlDetails, () async {
      final j = await _get('/movies/$id/extended');
      return (j['data'] as Map<String, dynamic>?) ?? const {};
    }, force: force);
  }

  /// Langue des textes demandés à TheTVDB. L'app est francophone.
  static const _lang = 'fra';

  /// Épisodes officiels d'une série, normalisés et paginés puis mis en cache
  /// (le client est un singleton). Champs : season, episode, name, overview,
  /// image (URL complète), aired, runtime.
  ///
  /// Les textes sont demandés en français : l'endpoint sans langue rend les
  /// titres d'origine, soit du japonais pour un animé — « ONE PIECE 倒せ!海賊
  /// ギャンザック » plutôt que « Je suis Luffy ! Celui qui deviendra Roi des
  /// pirates ! ».
  ///
  /// [force] ignore la durée de vie du cache : sans ça, un rafraîchissement
  /// manuel relirait la même liste en mémoire et ne verrait jamais les épisodes
  /// ajoutés depuis. Un force qui échoue lève, plutôt que de rendre en silence
  /// la liste précédente — l'appelant doit savoir que rien n'a été rafraîchi.
  Future<List<Map<String, dynamic>>> seriesEpisodes(
    int id, {
    bool force = false,
  }) {
    return _memo('episodes:$id', _ttlEpisodes, () => _loadEpisodes(id),
        force: force);
  }

  Future<List<Map<String, dynamic>>> _loadEpisodes(int id) async {
    var out = <Map<String, dynamic>>[];
    try {
      out = await _episodePages(id, lang: _lang);
    } on TvdbException {
      out = <Map<String, dynamic>>[];
    }

    // Toutes les séries ne sont pas traduites : l'endpoint répond alors avec
    // la bonne structure mais des textes nuls. On ne va chercher la liste
    // d'origine que dans ce cas, pour combler les trous — une série
    // entièrement traduite ne coûte qu'un seul aller.
    final incomplete = out.any(
      (e) => e['name'] == null || e['overview'] == null,
    );
    if (out.isEmpty || incomplete) {
      final original = await _episodePages(id);
      if (out.isEmpty) {
        out = original;
      } else {
        final byKey = {
          for (final e in original) '${e['season']}x${e['episode']}': e,
        };
        for (final e in out) {
          final o = byKey['${e['season']}x${e['episode']}'];
          if (o == null) continue;
          for (final k in const ['name', 'overview', 'image', 'aired']) {
            e[k] ??= o[k];
          }
          e['runtime'] ??= o['runtime'];
        }
      }
    }

    return out;
  }

  /// Parcourt les pages de `/series/{id}/episodes/official[/{lang}]` et
  /// normalise les épisodes. Les textes vides deviennent nuls, pour que la
  /// retombée sur la version d'origine soit un simple `??=`.
  Future<List<Map<String, dynamic>>> _episodePages(int id, {String? lang}) async {
    final path = lang == null
        ? '/series/$id/episodes/official'
        : '/series/$id/episodes/official/$lang';
    final out = <Map<String, dynamic>>[];
    for (var page = 0; page < 30; page++) {
      final j = await _get(path, {'page': '$page'});
      final data = j['data'];
      final eps = (data is Map ? data['episodes'] : null) as List?;
      if (eps == null || eps.isEmpty) break;
      for (final e in eps.whereType<Map<String, dynamic>>()) {
        final season = (e['seasonNumber'] as num?)?.toInt();
        final number = (e['number'] as num?)?.toInt();
        if (season == null || number == null) continue;
        out.add({
          'season': season,
          'episode': number,
          'name': _text(e['name']),
          'overview': _text(e['overview']),
          'image': _text(e['image']),
          'aired': _text(e['aired']),
          'runtime': (e['runtime'] as num?)?.toInt(),
        });
      }
      // `links.next` dit exactement s'il reste une page ; la taille de page
      // est un détail du serveur qu'on n'a pas à deviner.
      final links = j['links'];
      if (links is Map && links['next'] == null) break;
    }
    return out;
  }

  static String? _text(Object? v) {
    final s = v == null ? '' : '$v'.trim();
    return s.isEmpty ? null : s;
  }

  /// Traduction (nom + résumé) d'une série dans [lang] (ex. « fra »).
  /// Renvoie {} si absente.
  Future<Map<String, dynamic>> seriesTranslation(int id, String lang) =>
      _translation('series', id, lang);

  Future<Map<String, dynamic>> movieTranslation(int id, String lang) =>
      _translation('movies', id, lang);

  /// Une traduction absente est un cas normal, pas une panne : on rend {}.
  /// L'échec, lui, n'est pas mémorisé — sinon une coupure passagère priverait
  /// la fiche de son titre français pendant une semaine.
  Future<Map<String, dynamic>> _translation(
      String kind, int id, String lang) async {
    try {
      return await _memo('translation:$kind:$id:$lang', _ttlTranslation,
          () async {
        final j = await _get('/$kind/$id/translations/$lang');
        return (j['data'] as Map<String, dynamic>?) ?? const {};
      });
    } on TvdbException catch (e) {
      debugPrint('Traduction $kind/$id/$lang indisponible : $e');
      return const {};
    }
  }

  // ---- Extracteurs sur les réponses TheTVDB ----

  /// Genres joints par « | » (ex. "Drama|Crime").
  static String? genresOf(Map<String, dynamic> d) {
    final list = ((d['genres'] as List?) ?? const [])
        .whereType<Map>()
        .map((g) => '${g['name'] ?? ''}')
        .where((n) => n.isNotEmpty)
        .toList();
    return list.isEmpty ? null : list.join('|');
  }

  /// Affiche (URL complète) d'une série ou d'un film.
  static String? posterOf(Map<String, dynamic> d) {
    final img = d['image'];
    return (img is String && img.isNotEmpty) ? img : null;
  }

  /// Statut lisible ("Ended", "Continuing"…).
  static String? statusOf(Map<String, dynamic> d) {
    final s = d['status'];
    if (s is Map && s['name'] is String) return s['name'] as String;
    return null;
  }

  /// Date de sortie d'un film (first_release.date), ou null.
  static DateTime? releaseDateOf(Map<String, dynamic> movie) {
    final fr = movie['first_release'];
    final date = fr is Map ? fr['date'] : null;
    if (date is String && date.isNotEmpty) return DateTime.tryParse(date);
    return null;
  }

  /// Vérifie que la clé est valide (login + une recherche). Renvoie le nombre
  /// de résultats et un exemple de titre, pour le bouton « Tester ».
  Future<({int count, String sample})> ping() async {
    final res = await search('Breaking Bad', type: 'series');
    final sample = res.isNotEmpty ? '${res.first['name'] ?? ''}' : '';
    return (count: res.length, sample: sample);
  }

  /// Description française si disponible, sinon anglaise.
  static String? overviewFr(Map<String, dynamic> item) {
    final ovs = item['overviews'];
    if (ovs is Map &&
        ovs['fra'] is String &&
        (ovs['fra'] as String).isNotEmpty) {
      return ovs['fra'] as String;
    }
    final o = item['overview'];
    return (o is String && o.isNotEmpty) ? o : null;
  }

  /// Identifiant numérique TheTVDB depuis un résultat de recherche
  /// (`tvdb_id` sinon `objectID` de la forme « series-81189 »).
  static int? tvdbId(Map<String, dynamic> item) {
    final raw = item['tvdb_id'] ?? item['id'];
    if (raw is int) return raw;
    if (raw is String) {
      final digits = RegExp(r'(\d+)$').firstMatch(raw)?.group(1);
      return digits == null ? null : int.tryParse(digits);
    }
    return null;
  }
}
