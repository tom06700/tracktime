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
  Future<List<Map<String, dynamic>>> search(String query, {String? type}) async {
    final j = await _get('/search', {
      'query': query,
      'limit': '20',
      'type': ?type,
    });
    return ((j['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Détails étendus d'une série (saisons, épisodes, artworks).
  Future<Map<String, dynamic>> seriesExtended(int id) async {
    final j = await _get('/series/$id/extended');
    return (j['data'] as Map<String, dynamic>?) ?? const {};
  }

  /// Détails étendus d'un film.
  Future<Map<String, dynamic>> movieExtended(int id) async {
    final j = await _get('/movies/$id/extended');
    return (j['data'] as Map<String, dynamic>?) ?? const {};
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
