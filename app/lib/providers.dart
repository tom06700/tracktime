import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final showsProvider = StreamProvider<List<ShowWithProgress>>(
    (ref) => ref.watch(databaseProvider).watchShowsWithProgress());

final moviesProvider = StreamProvider<List<Movie>>(
    (ref) => ref.watch(databaseProvider).watchMovies());

final statsProvider = StreamProvider<WatchStats>(
    (ref) => ref.watch(databaseProvider).watchStats());

/// Ensemble réactif des clés "SxEy" vues, pour l'écran de détail d'une série.
final watchedKeysProvider = StreamProvider.family<Set<String>, int>(
    (ref, showId) => ref.watch(databaseProvider).watchWatchedKeys(showId));
