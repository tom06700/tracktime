import 'dart:convert';

import 'package:http/http.dart' as http;

class TvdbException implements Exception {
  const TvdbException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client minimal de l'API TheTVDB v4.
///
/// Authentification : `POST /login` avec la clé projet renvoie un token JWT
/// valable ~1 mois, mis en cache ici (re-login automatique s'il est périmé
/// ou sur un 401). CORS ouvert côté TheTVDB → utilisable directement depuis
/// le web comme depuis le natif.
class TvdbClient {
  TvdbClient(this.apiKey, {http.Client? client})
      : _http = client ?? http.Client();

  /// Clé projet TheTVDB (v4).
  final String apiKey;
  final http.Client _http;

  static const _host = 'api4.thetvdb.com';

  String? _token;
  DateTime? _tokenAt;

  bool get _tokenFresh =>
      _token != null &&
      _tokenAt != null &&
      DateTime.now().difference(_tokenAt!) < const Duration(days: 20);

  Future<String> _ensureToken() async {
    if (_tokenFresh) return _token!;
    if (apiKey.isEmpty) {
      throw const TvdbException('Ajoute ta clé TheTVDB dans ⚙️ Réglages.');
    }
    final http.Response r;
    try {
      r = await _http.post(
        Uri.https(_host, '/v4/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'apikey': apiKey}),
      );
    } catch (e) {
      throw TvdbException('Réseau indisponible ($e)');
    }
    if (r.statusCode != 200) {
      throw TvdbException('TheTVDB ${r.statusCode} — vérifie ta clé.');
    }
    final data = (json.decode(r.body) as Map<String, dynamic>)['data'];
    final token = (data is Map ? data['token'] : null) as String?;
    if (token == null || token.isEmpty) {
      throw const TvdbException('TheTVDB : token introuvable dans la réponse.');
    }
    _token = token;
    _tokenAt = DateTime.now();
    return token;
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String> params = const {},
  ]) async {
    var token = await _ensureToken();
    final uri = Uri.https(_host, '/v4$path', params.isEmpty ? null : params);
    http.Response r;
    try {
      r = await _http.get(uri, headers: {'Authorization': 'Bearer $token'});
      // Token périmé côté serveur → on relogue une fois.
      if (r.statusCode == 401) {
        _token = null;
        token = await _ensureToken();
        r = await _http.get(uri, headers: {'Authorization': 'Bearer $token'});
      }
    } catch (e) {
      throw TvdbException('Réseau indisponible ($e)');
    }
    if (r.statusCode != 200) {
      throw TvdbException('TheTVDB ${r.statusCode}.');
    }
    return json.decode(r.body) as Map<String, dynamic>;
  }

  /// Recherche séries + films. [type] : `'series'`, `'movie'` ou null (tous).
  ///
  /// La limite est volontairement haute : `/search` mélange aux médias des
  /// listes d'utilisateurs, des personnes et des sociétés, qui consomment des
  /// places. Sur « One Piece », six des vingt premiers résultats étaient des
  /// listes et l'anime original n'arrivait qu'en 38ᵉ position — donc jamais
  /// renvoyé. Le tri pertinent est fait ensuite, côté application.
  Future<List<Map<String, dynamic>>> search(String query, {String? type}) async {
    final j = await _get('/search', {
      'query': query,
      'limit': '50',
      'type': ?type,
    });
    return ((j['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Séries ou films les mieux notés, pour l'écran de découverte.
  ///
  /// TheTVDB v4 n'expose ni tendances ni nouveautés : `/{type}/filter` trié
  /// sur le score est le seul signal de popularité disponible. Le sens du tri
  /// doit être passé en minuscules — `sortType=DESC` est silencieusement
  /// ignoré et renvoie les fiches vides, sans image ni score.
  Future<List<Map<String, dynamic>>> mostPopular({required bool movies}) =>
      _filter(movies: movies, sort: 'score');

  /// Films dont la sortie est annoncée, du plus lointain au plus proche.
  Future<List<Map<String, dynamic>>> upcomingReleases() =>
      _filter(movies: true, sort: 'firstAired');

  Future<List<Map<String, dynamic>>> _filter({
    required bool movies,
    required String sort,
  }) async {
    final j = await _get('/${movies ? 'movies' : 'series'}/filter', {
      'sort': sort,
      'sortType': 'desc',
    });
    return ((j['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        // Sans affiche, une carte de découverte n'a aucun intérêt.
        .where((e) => (e['image'] as String?)?.isNotEmpty ?? false)
        .toList();
  }

  /// Détails étendus d'une série (saisons, genres, artworks, network…).
  Future<Map<String, dynamic>> seriesExtended(int id) async {
    final j = await _get('/series/$id/extended');
    return (j['data'] as Map<String, dynamic>?) ?? const {};
  }

  /// Détails étendus d'un film.
  Future<Map<String, dynamic>> movieExtended(int id) async {
    final j = await _get('/movies/$id/extended');
    return (j['data'] as Map<String, dynamic>?) ?? const {};
  }

  final Map<int, List<Map<String, dynamic>>> _episodesCache = {};

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
  /// [force] vide l'entrée de cache avant l'appel : sans ça, un rafraîchissement
  /// manuel relirait la même liste en mémoire et ne verrait jamais les épisodes
  /// ajoutés depuis.
  Future<List<Map<String, dynamic>>> seriesEpisodes(
    int id, {
    bool force = false,
  }) async {
    if (force) _episodesCache.remove(id);
    final cached = _episodesCache[id];
    if (cached != null) return cached;

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

    _episodesCache[id] = out;
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

  Future<Map<String, dynamic>> _translation(
      String kind, int id, String lang) async {
    try {
      final j = await _get('/$kind/$id/translations/$lang');
      return (j['data'] as Map<String, dynamic>?) ?? const {};
    } catch (_) {
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
