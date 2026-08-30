import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../tmdb/match.dart';
import '../tmdb/search_result.dart';
import '../tmdb/tvdb.dart';
import 'backup_format.dart';

/// Ce que la restauration a fait, et ce qu'elle n'a pas pu faire.
class ImportReport {
  ImportReport();

  int importedShows = 0;
  int importedMovies = 0;
  int importedEpisodes = 0;
  int skippedShows = 0;
  int skippedMovies = 0;

  /// Œuvres écartées faute de correspondance sûre.
  final List<String> warnings = [];

  /// Échecs francs : aucune correspondance, réseau indisponible.
  final List<String> errors = [];

  /// Journal lisible, dans l'ordre du traitement.
  final List<String> lines = [];

  void _log(String line) => lines.add(line);

  void ok(String line) => _log(line);

  void warn(String line) {
    warnings.add(line);
    _log('⚠️ $line');
  }

  void fail(String line) {
    errors.add(line);
    _log('❌ $line');
  }

  String get summary =>
      '$importedShows séries, $importedMovies films, '
      '$importedEpisodes épisodes vus'
      '${skippedShows + skippedMovies > 0 ? ' · ${skippedShows + skippedMovies} non importés' : ''}';
}

/// Une série prête à être écrite, avec son identifiant TheTVDB confirmé.
class PlannedShow {
  const PlannedShow({
    required this.id,
    required this.name,
    this.poster,
    this.totalEpisodes,
    this.seasonCount,
    this.runtime,
    this.status,
    this.genres,
  });

  final int id;
  final String name;
  final String? poster;
  final int? totalEpisodes;
  final int? seasonCount;
  final int? runtime;
  final String? status;
  final String? genres;
}

class PlannedMovie {
  const PlannedMovie({
    required this.id,
    required this.title,
    this.poster,
    this.runtime,
    this.watchedAt,
    this.genres,
    this.releaseDate,
  });

  final int id;
  final String title;
  final String? poster;
  final int? runtime;
  final DateTime? watchedAt;
  final String? genres;
  final DateTime? releaseDate;
}

/// Un épisode vu, rattaché à une série par son identifiant TheTVDB — jamais
/// par un identifiant d'épisode, qui ne survit pas à un changement de source.
typedef PlannedWatch = ({int showId, int season, int episode, DateTime? at});

/// Plan d'écriture : tout est résolu, plus rien ne dépend du réseau.
class ImportPlan {
  const ImportPlan({
    this.shows = const [],
    this.movies = const [],
    this.watched = const [],
  });

  final List<PlannedShow> shows;
  final List<PlannedMovie> movies;
  final List<PlannedWatch> watched;

  bool get isEmpty => shows.isEmpty && movies.isEmpty && watched.isEmpty;
}

/// Écrit un plan en une seule transaction.
///
/// Fusion, jamais remplacement : une série déjà présente est mise à jour, ses
/// épisodes vus complétés. `insertOrIgnore` sur la progression préserve la
/// date d'un épisode déjà coché et évite les doublons.
///
/// En cas d'erreur d'écriture, drift annule la transaction : la base reste
/// telle qu'avant plutôt qu'à moitié restaurée.
Future<void> applyImportPlan(AppDatabase db, ImportPlan plan) {
  return db.transaction(() async {
    for (final s in plan.shows) {
      await db.upsertShow(
        ShowsCompanion(
          id: Value(s.id),
          name: Value(s.name),
          poster: Value(s.poster),
          totalEpisodes: Value(s.totalEpisodes),
          seasonCount: Value(s.seasonCount),
          runtime: s.runtime == null ? const Value.absent() : Value(s.runtime!),
          status: Value(s.status),
          genres: Value(s.genres),
        ),
      );
    }
    for (final m in plan.movies) {
      final existing = await db.movieById(m.id);
      await db.upsertMovie(
        MoviesCompanion(
          id: Value(m.id),
          title: Value(m.title),
          poster: Value(m.poster),
          runtime: m.runtime == null ? const Value.absent() : Value(m.runtime!),
          // Un film déjà vu localement garde sa date : la sauvegarde complète,
          // elle n'efface pas.
          watchedAt: Value(existing?.watchedAt ?? m.watchedAt),
          genres: Value(m.genres),
          releaseDate: Value(m.releaseDate),
        ),
      );
    }
    for (final w in plan.watched) {
      await db.setEpisodeWatched(w.showId, w.season, w.episode, at: w.at);
    }
  });
}

/// Plan d'une sauvegarde Nitrate : les identifiants sont déjà les bons, aucune
/// recherche réseau n'est nécessaire.
ImportPlan planNitrateBackup(NitrateBackup backup, ImportReport report) {
  final shows = <PlannedShow>[];
  final watched = <PlannedWatch>[];
  for (final s in backup.shows) {
    final id = s.id;
    if (id == null) {
      report.skippedShows++;
      report.warn('${s.name} — sauvegarde sans identifiant, non restaurée');
      continue;
    }
    shows.add(
      PlannedShow(
        id: id,
        name: s.name,
        poster: s.poster,
        totalEpisodes: s.totalEpisodes,
        seasonCount: s.seasonCount,
        runtime: s.runtime,
        status: s.status,
        genres: s.genres,
      ),
    );
    for (final w in s.watched) {
      watched.add((showId: id, season: w.season, episode: w.episode, at: w.at));
    }
    report.importedShows++;
    report.importedEpisodes += s.watched.length;
    report.ok('✅ ${s.name} · TheTVDB $id restauré');
  }

  final movies = <PlannedMovie>[];
  for (final m in backup.movies) {
    final id = m.id;
    if (id == null) {
      report.skippedMovies++;
      report.warn('${m.title} — sauvegarde sans identifiant, non restauré');
      continue;
    }
    movies.add(
      PlannedMovie(
        id: id,
        title: m.title,
        poster: m.poster,
        runtime: m.runtime,
        watchedAt: m.watchedAt,
        genres: m.genres,
        releaseDate: m.releaseDate,
      ),
    );
    report.importedMovies++;
    report.ok('✅ ${m.title} · TheTVDB $id restauré');
  }

  return ImportPlan(shows: shows, movies: movies, watched: watched);
}

/// Restaure une sauvegarde Nitrate. Déterministe, sans réseau.
Future<ImportReport> restoreNitrateBackup(
  AppDatabase db,
  NitrateBackup backup,
) async {
  final report = ImportReport();
  await applyImportPlan(db, planNitrateBackup(backup, report));
  return report;
}

/// Résout une ancienne sauvegarde : chaque œuvre est retrouvée sur TheTVDB par
/// son titre, jamais par son ancien identifiant.
///
/// Phase de résolution seulement — aucune écriture, donc aucun appel réseau
/// enfermé dans une transaction SQLite.
///
/// Une correspondance douteuse n'est pas importée : mieux vaut une série
/// manquante qu'un historique de plusieurs années rattaché à la mauvaise.
Future<ImportPlan> planLegacyBackup(
  TvdbClient tvdb,
  LegacyBackup backup,
  ImportReport report, {
  void Function(double pct, String? line)? onProgress,
}) async {
  final shows = <PlannedShow>[];
  final movies = <PlannedMovie>[];
  final watched = <PlannedWatch>[];

  final total = backup.shows.length + backup.movies.length;
  var done = 0;
  void step(String? line) {
    done++;
    onProgress?.call(total == 0 ? 1 : done / total, line);
  }

  for (final s in backup.shows) {
    try {
      final match = await matchTitle(
        tvdb,
        s.name,
        SearchMediaType.series,
        year: s.year,
      );
      final id = match.result?.tvdbId;
      if (id == null) {
        report.skippedShows++;
        report.fail('${s.name} — aucune correspondance TheTVDB');
      } else if (!match.isReliable) {
        report.skippedShows++;
        report.warn(
          match.ambiguous
              ? '${s.name} — plusieurs correspondances possibles, non importée'
              : '${s.name} — correspondance incertaine, non importée',
        );
      } else {
        shows.add(
          PlannedShow(
            id: id,
            name: match.result!.name,
            poster: s.poster ?? match.result!.image,
            totalEpisodes: s.totalEpisodes,
            seasonCount: s.seasonCount,
            runtime: s.runtime,
            status: s.status,
          ),
        );
        for (final w in s.watched) {
          watched.add((
            showId: id,
            season: w.season,
            episode: w.episode,
            at: w.at,
          ));
        }
        report.importedShows++;
        report.importedEpisodes += s.watched.length;
        report.ok('✅ ${s.name} → ${match.result!.name} · TheTVDB $id');
      }
    } on TvdbException catch (e) {
      report.skippedShows++;
      report.fail('${s.name} — TheTVDB indisponible ($e)');
    } catch (e, st) {
      report.skippedShows++;
      report.fail('${s.name} — erreur inattendue');
      debugPrint('Restauration de « ${s.name} » : $e\n$st');
    }
    step(report.lines.isEmpty ? null : report.lines.last);
  }

  for (final m in backup.movies) {
    try {
      final match = await matchTitle(
        tvdb,
        m.title,
        SearchMediaType.movie,
        year: m.year,
      );
      final id = match.result?.tvdbId;
      if (id == null) {
        report.skippedMovies++;
        report.fail('${m.title} — aucune correspondance TheTVDB');
      } else if (!match.isReliable) {
        report.skippedMovies++;
        report.warn(
          match.ambiguous
              ? '${m.title} — plusieurs correspondances possibles, non importé'
              : '${m.title} — correspondance incertaine, non importé',
        );
      } else {
        movies.add(
          PlannedMovie(
            id: id,
            title: match.result!.name,
            poster: m.poster ?? match.result!.image,
            runtime: m.runtime,
            watchedAt: m.watchedAt,
            releaseDate: m.releaseDate,
          ),
        );
        report.importedMovies++;
        report.ok('✅ ${m.title} → ${match.result!.name} · TheTVDB $id');
      }
    } on TvdbException catch (e) {
      report.skippedMovies++;
      report.fail('${m.title} — TheTVDB indisponible ($e)');
    } catch (e, st) {
      report.skippedMovies++;
      report.fail('${m.title} — erreur inattendue');
      debugPrint('Restauration de « ${m.title} » : $e\n$st');
    }
    step(report.lines.isEmpty ? null : report.lines.last);
  }

  return ImportPlan(shows: shows, movies: movies, watched: watched);
}

/// Restaure une ancienne sauvegarde : résolution complète, puis écriture en
/// une transaction.
Future<ImportReport> restoreLegacyBackup(
  AppDatabase db,
  TvdbClient tvdb,
  LegacyBackup backup, {
  void Function(double pct, String? line)? onProgress,
}) async {
  final report = ImportReport();
  final plan = await planLegacyBackup(
    tvdb,
    backup,
    report,
    onProgress: onProgress,
  );
  await applyImportPlan(db, plan);
  return report;
}
