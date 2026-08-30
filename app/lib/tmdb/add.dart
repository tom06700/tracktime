import 'package:drift/drift.dart';

import '../db/database.dart';
import 'tvdb.dart';

String? _clean(Object? v) {
  final s = v is String ? v.trim() : '';
  return s.isEmpty ? null : s;
}

/// Titre à retenir pour une œuvre TheTVDB, du plus lisible au moins lisible.
///
/// [preferred] vient de la recherche, qui expose déjà toutes les traductions ;
/// sinon on interroge le français, puis l'anglais. Beaucoup d'animés n'ont pas
/// de fiche française mais ont un titre anglais lisible : mieux vaut
/// « One Piece » que « ワンピース », qu'un francophone ne reconnaît pas.
Future<String> _bestTitle(
  String? preferred,
  Object? original,
  Future<Map<String, dynamic>> Function(String lang) translation,
) async {
  final wanted = _clean(preferred);
  if (wanted != null) return wanted;
  for (final lang in const ['fra', 'eng']) {
    final t = _clean((await translation(lang))['name']);
    if (t != null) return t;
  }
  return _clean(original) ?? '';
}

/// Nombre de saisons « officielles » (> 0) d'une série TheTVDB étendue.
int? _officialSeasonCount(Map<String, dynamic> d) {
  final nums = <int>{};
  for (final s in ((d['seasons'] as List?) ?? const []).whereType<Map>()) {
    if ((s['type'] as Map?)?['type'] == 'official') {
      final n = (s['number'] as num?)?.toInt();
      if (n != null && n > 0) nums.add(n);
    }
  }
  return nums.isEmpty ? null : nums.length;
}

/// Ajoute une série depuis TheTVDB si absente. Renvoie son nom (FR si dispo).
///
/// [preferredName] court-circuite l'appel de traduction quand l'appelant a
/// déjà un titre lisible sous la main — typiquement un résultat de recherche,
/// qui porte toutes les traductions.
Future<String> addShowFromTvdb(
  AppDatabase db,
  TvdbClient tvdb,
  int id, {
  String? preferredName,
}) async {
  final existing = await db.showById(id);
  if (existing != null) return existing.name;
  final d = await tvdb.seriesExtended(id);
  final name = await _bestTitle(
    preferredName,
    d['name'],
    (lang) => tvdb.seriesTranslation(id, lang),
  );
  await db.upsertShow(ShowsCompanion.insert(
    id: Value(id),
    name: name,
    poster: Value(TvdbClient.posterOf(d)),
    seasonCount: Value(_officialSeasonCount(d)),
    runtime: Value((d['averageRuntime'] as num?)?.toInt() ?? 42),
    status: Value(TvdbClient.statusOf(d)),
    genres: Value(TvdbClient.genresOf(d)),
  ));
  return name;
}

/// Ajoute un film depuis TheTVDB si absent (dans la watchlist). Renvoie son titre.
Future<String> addMovieFromTvdb(
  AppDatabase db,
  TvdbClient tvdb,
  int id, {
  String? preferredTitle,
}) async {
  final existing = await db.movieById(id);
  if (existing != null) return existing.title;
  final d = await tvdb.movieExtended(id);
  final title = await _bestTitle(
    preferredTitle,
    d['name'],
    (lang) => tvdb.movieTranslation(id, lang),
  );
  await db.upsertMovie(MoviesCompanion.insert(
    id: Value(id),
    title: title,
    poster: Value(TvdbClient.posterOf(d)),
    runtime: Value((d['runtime'] as num?)?.toInt() ?? 110),
    watchedAt: const Value(null),
    genres: Value(TvdbClient.genresOf(d)),
    releaseDate: Value(TvdbClient.releaseDateOf(d)),
  ));
  return title;
}
