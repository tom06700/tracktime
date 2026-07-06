import 'dart:convert';

import 'package:http/http.dart' as http;

class TmdbException implements Exception {
  const TmdbException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client minimal de l'API TMDB v3 (clé API simple, réponses en français).
class TmdbClient {
  TmdbClient(this.apiKey, {http.Client? client})
      : _http = client ?? http.Client();

  final String apiKey;
  final http.Client _http;

  static String? imageUrl(String? path, {String size = 'w185'}) =>
      (path == null || path.isEmpty)
          ? null
          : 'https://image.tmdb.org/t/p/$size$path';

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String> params = const {}]) async {
    if (apiKey.isEmpty) {
      throw const TmdbException('Ajoute ta clé API TMDB dans ⚙️ Réglages.');
    }
    final uri = Uri.https('api.themoviedb.org', '/3$path', {
      'api_key': apiKey,
      'language': 'fr-FR',
      ...params,
    });
    final http.Response r;
    try {
      r = await _http.get(uri);
    } catch (e) {
      throw TmdbException('Réseau indisponible ($e)');
    }
    if (r.statusCode != 200) {
      throw TmdbException('TMDB ${r.statusCode} — vérifie ta clé API.');
    }
    return json.decode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> _search(String path, String query) async {
    final j = await _get(path, {'query': query});
    return ((j['results'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchTv(String query) =>
      _search('/search/tv', query);

  Future<List<Map<String, dynamic>>> searchMovie(String query) =>
      _search('/search/movie', query);

  Future<List<Map<String, dynamic>>> searchMulti(String query) =>
      _search('/search/multi', query);

  Future<Map<String, dynamic>> tvDetails(int id) => _get('/tv/$id');

  Future<Map<String, dynamic>> movieDetails(int id) => _get('/movie/$id');

  Future<Map<String, dynamic>> season(int tvId, int seasonNumber) =>
      _get('/tv/$tvId/season/$seasonNumber');
}
