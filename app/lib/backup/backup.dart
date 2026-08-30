import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../db/database.dart';
import 'backup_format.dart';

/// Construit une sauvegarde Nitrate.
///
/// Le fichier dit ce qu'il contient : sa version, l'app d'origine et le
/// fournisseur des identifiants. Sans ça, « 81797 » n'est qu'un nombre — et
/// c'est ainsi que d'anciens identifiants TMDB pouvaient se retrouver
/// restaurés dans une base TheTVDB.
Future<Map<String, dynamic>> buildBackup(AppDatabase db, {DateTime? now}) async {
  final shows = await db.allShows();
  final episodes = await db.allWatchedEpisodes();
  final movies = await db.allMovies();

  // Épisodes vus regroupés par série, sous la forme {S1E2: dateISO}.
  final watchedByShow = <int, Map<String, String>>{};
  for (final e in episodes) {
    (watchedByShow[e.showId] ??= {})['S${e.season}E${e.episode}'] =
        e.watchedAt.toIso8601String();
  }

  return {
    'schemaVersion': currentBackupSchemaVersion,
    'app': kBackupApp,
    'metadataProvider': kBackupProvider,
    'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'shows': [
      for (final s in shows)
        {
          'id': s.id,
          'provider': kBackupProvider,
          'name': s.name,
          'poster': s.poster,
          'totalEpisodes': s.totalEpisodes,
          'seasonCount': s.seasonCount,
          'runtime': s.runtime,
          'status': s.status,
          'genres': s.genres,
          'watched': watchedByShow[s.id] ?? const {},
        },
    ],
    'movies': [
      for (final m in movies)
        {
          'id': m.id,
          'provider': kBackupProvider,
          'title': m.title,
          'poster': m.poster,
          'runtime': m.runtime,
          'watchedAt': m.watchedAt?.toIso8601String(),
          'genres': m.genres,
          'releaseDate': m.releaseDate?.toIso8601String(),
        },
    ],
  };
}

/// Nom de fichier daté, ex. `nitrate-sauvegarde-2026-07-06.json`.
String backupFileName(DateTime now) {
  final d =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return 'nitrate-sauvegarde-$d.json';
}

/// Exporte les données via la feuille de partage native (iOS/Android) ou,
/// sur le web, un téléchargement de secours.
Future<void> exportBackup(AppDatabase db, {DateTime? now}) async {
  final backup = await buildBackup(db, now: now);
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
    subject: 'Sauvegarde Nitrate',
  ));
}
