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
