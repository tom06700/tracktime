import 'package:drift/drift.dart';

import '../db/database.dart';
import 'tvdb.dart';

String? _pick(Object? a, Object? b) {
  if (a is String && a.trim().isNotEmpty) return a;
  if (b is String && b.trim().isNotEmpty) return b;
  return null;
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
Future<String> addShowFromTvdb(AppDatabase db, TvdbClient tvdb, int id) async {
  final existing = await db.showById(id);
  if (existing != null) return existing.name;
  final d = await tvdb.seriesExtended(id);
  final fr = await tvdb.seriesTranslation(id, 'fra');
  final name = _pick(fr['name'], d['name']) ?? '';
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
Future<String> addMovieFromTvdb(AppDatabase db, TvdbClient tvdb, int id) async {
  final existing = await db.movieById(id);
  if (existing != null) return existing.title;
  final d = await tvdb.movieExtended(id);
  final fr = await tvdb.movieTranslation(id, 'fra');
  final title = _pick(fr['name'], d['name']) ?? '';
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
