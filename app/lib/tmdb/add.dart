import 'package:drift/drift.dart';

import '../db/database.dart';
import 'tmdb.dart';

/// Ajoute une série depuis TMDB si absente. Renvoie son nom.
Future<String> addShowFromTmdb(AppDatabase db, TmdbClient tmdb, int id) async {
  final existing = await db.showById(id);
  if (existing != null) return existing.name;
  final d = await tmdb.tvDetails(id);
  final name = '${d['name'] ?? ''}';
  await db.upsertShow(ShowsCompanion.insert(
    id: Value(id),
    name: name,
    poster: Value(d['poster_path'] as String?),
    totalEpisodes: Value((d['number_of_episodes'] as num?)?.toInt()),
    seasonCount: Value((d['number_of_seasons'] as num?)?.toInt()),
    runtime: Value(
        ((d['episode_run_time'] as List?)?.firstOrNull as num?)?.toInt() ?? 42),
    status: Value(d['status'] as String?),
  ));
  return name;
}

/// Ajoute un film depuis TMDB si absent (dans la watchlist). Renvoie son titre.
Future<String> addMovieFromTmdb(AppDatabase db, TmdbClient tmdb, int id) async {
  final existing = await db.movieById(id);
  if (existing != null) return existing.title;
  final d = await tmdb.movieDetails(id);
  final title = '${d['title'] ?? ''}';
  await db.upsertMovie(MoviesCompanion.insert(
    id: Value(id),
    title: title,
    poster: Value(d['poster_path'] as String?),
    runtime: Value((d['runtime'] as num?)?.toInt() ?? 110),
    watchedAt: const Value(null),
  ));
  return title;
}
