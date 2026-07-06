import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../db/database.dart';

/// Construit un backup au format de la version web de TrackTime
/// (`{shows, movies, key}`). Ce format fait l'aller-retour avec
/// `importWebBackup` et est aussi lisible par l'app web historique.
Future<Map<String, dynamic>> buildBackup(AppDatabase db,
    {String? tmdbKey}) async {
  final shows = await db.allShows();
  final episodes = await db.allWatchedEpisodes();
  final movies = await db.allMovies();

  // Regroupe les épisodes vus par série sous la forme {S1E2: dateISO}.
  final watchedByShow = <int, Map<String, String>>{};
  for (final e in episodes) {
    (watchedByShow[e.showId] ??= {})['S${e.season}E${e.episode}'] =
        e.watchedAt.toIso8601String();
  }

  return {
    'shows': [
      for (final s in shows)
        {
          'id': s.id,
          'name': s.name,
          'poster': s.poster,
          'total': s.totalEpisodes,
          'seasons': s.seasonCount,
          'runtime': s.runtime,
          'status': s.status,
          'watched': watchedByShow[s.id] ?? const {},
        },
    ],
    'movies': [
      for (final m in movies)
        {
          'id': m.id,
          'title': m.title,
          'poster': m.poster,
          'runtime': m.runtime,
          'watchedAt': m.watchedAt?.toIso8601String(),
        },
    ],
    if (tmdbKey != null && tmdbKey.isNotEmpty) 'key': tmdbKey,
  };
}

/// Nom de fichier daté, ex. `tracktime-backup-2026-07-06.json`.
String backupFileName(DateTime now) {
  final d =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return 'tracktime-backup-$d.json';
}

/// Exporte les données via la feuille de partage native (iOS/Android) ou,
/// sur le web, un téléchargement de secours.
Future<void> exportBackup(AppDatabase db,
    {String? tmdbKey, DateTime? now}) async {
  final backup = await buildBackup(db, tmdbKey: tmdbKey);
  final bytes =
      Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent(' ').convert(backup)));
  final name = backupFileName(now ?? DateTime.now());

  final file = XFile.fromData(
    bytes,
    name: name,
    mimeType: 'application/json',
  );
  await SharePlus.instance.share(ShareParams(
    files: [file],
    fileNameOverrides: [name],
    subject: 'Sauvegarde TrackTime',
  ));
}
