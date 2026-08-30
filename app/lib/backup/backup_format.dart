/// Format de sauvegarde Nitrate, versionné et explicite sur l'origine des
/// identifiants.
///
/// Un identifiant média n'a de sens qu'avec son fournisseur : « 81797 » ne
/// veut rien dire tant qu'on ne sait pas qu'il vient de TheTVDB. L'ancien
/// format de TrackTime ne le disait pas, et ses identifiants venaient de TMDB
/// — les injecter tels quels dans une base TheTVDB rattache l'historique à la
/// mauvaise œuvre.
library;

/// Version écrite par cette build. Un fichier plus récent est refusé plutôt
/// que deviné.
const currentBackupSchemaVersion = 2;

const kBackupApp = 'nitrate';
const kBackupProvider = 'thetvdb';

/// Fournisseur historique de TrackTime. Reconnu pour être re-apparié, jamais
/// pour être copié tel quel.
const _legacyProvider = 'tmdb';

/// Une série dans un fichier de sauvegarde.
class BackupShow {
  const BackupShow({
    required this.name,
    this.id,
    this.poster,
    this.totalEpisodes,
    this.seasonCount,
    this.runtime,
    this.status,
    this.genres,
    this.year,
    this.watched = const [],
  });

  /// Identifiant tel qu'écrit dans le fichier. N'est exploitable que si le
  /// fichier déclare TheTVDB comme fournisseur.
  final int? id;
  final String name;
  final String? poster;
  final int? totalEpisodes;
  final int? seasonCount;
  final int? runtime;
  final String? status;
  final String? genres;

  /// Année de première diffusion, quand la source la connaît : sert à
  /// départager deux séries homonymes.
  final String? year;

  final List<BackupWatch> watched;
}

/// Un épisode vu : saison, numéro, et date si elle est connue.
class BackupWatch {
  const BackupWatch(this.season, this.episode, this.at);

  final int season;
  final int episode;
  final DateTime? at;
}

class BackupMovie {
  const BackupMovie({
    required this.title,
    this.id,
    this.poster,
    this.runtime,
    this.watchedAt,
    this.genres,
    this.releaseDate,
    this.year,
  });

  final int? id;
  final String title;
  final String? poster;
  final int? runtime;

  /// Null = dans la liste à voir.
  final DateTime? watchedAt;
  final String? genres;
  final DateTime? releaseDate;
  final String? year;
}

/// Ce qu'on a reconnu dans un fichier JSON.
sealed class BackupFile {
  const BackupFile();
}

/// Sauvegarde Nitrate : les identifiants sont des identifiants TheTVDB,
/// restaurables directement.
class NitrateBackup extends BackupFile {
  const NitrateBackup({
    required this.shows,
    required this.movies,
    required this.schemaVersion,
    this.exportedAt,
  });

  final List<BackupShow> shows;
  final List<BackupMovie> movies;
  final int schemaVersion;
  final DateTime? exportedAt;
}

/// Sauvegarde de l'ancien TrackTime : fournisseur inconnu ou TMDB. Les œuvres
/// devront être retrouvées sur TheTVDB par leur titre.
class LegacyBackup extends BackupFile {
  const LegacyBackup({required this.shows, required this.movies});

  final List<BackupShow> shows;
  final List<BackupMovie> movies;
}

/// Fichier reconnu comme sauvegarde mais impossible à traiter. [message] est
/// destiné à l'utilisateur.
class UnsupportedBackup extends BackupFile {
  const UnsupportedBackup(this.message);

  final String message;
}

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

String? _text(Object? v) {
  final s = v == null ? '' : '$v'.trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(Object? v) {
  final s = _text(v);
  return s == null ? null : DateTime.tryParse(s);
}

/// Année seule, à partir d'une année ou d'une date ISO.
String? _year(Object? v) {
  final s = _text(v);
  if (s == null) return null;
  return s.length >= 4 ? s.substring(0, 4) : null;
}

/// Épisodes vus, écrits `{"S1E2": "date ISO"}`.
///
/// Les clés illisibles et les numéros nuls ou négatifs sont ignorés : une
/// ligne fautive ne doit jamais faire échouer toute une restauration.
List<BackupWatch> _watched(Object? raw) {
  if (raw is! Map) return const [];
  final out = <BackupWatch>[];
  final key = RegExp(r'^S(\d+)E(\d+)$');
  for (final e in raw.entries) {
    final m = key.firstMatch('${e.key}'.trim());
    if (m == null) continue;
    final season = int.parse(m.group(1)!);
    final episode = int.parse(m.group(2)!);
    if (season < 1 || episode < 1) continue;
    out.add(BackupWatch(season, episode, _date(e.value)));
  }
  return out;
}

BackupShow? _show(Object? raw) {
  if (raw is! Map) return null;
  final name = _text(raw['name']);
  if (name == null) return null;
  return BackupShow(
    id: _int(raw['id']),
    name: name,
    poster: _text(raw['poster']),
    // `total` / `seasons` : noms de l'ancien format, encore lus.
    totalEpisodes: _int(raw['totalEpisodes'] ?? raw['total']),
    seasonCount: _int(raw['seasonCount'] ?? raw['seasons']),
    runtime: _int(raw['runtime']),
    status: _text(raw['status']),
    genres: _text(raw['genres']),
    year: _year(raw['year'] ?? raw['firstAired']),
    watched: _watched(raw['watched']),
  );
}

BackupMovie? _movie(Object? raw) {
  if (raw is! Map) return null;
  final title = _text(raw['title'] ?? raw['name']);
  if (title == null) return null;
  final release = _date(raw['releaseDate']);
  return BackupMovie(
    id: _int(raw['id']),
    title: title,
    poster: _text(raw['poster']),
    runtime: _int(raw['runtime']),
    watchedAt: _date(raw['watchedAt']),
    genres: _text(raw['genres']),
    releaseDate: release,
    year: _year(raw['year']) ?? (release == null ? null : '${release.year}'),
  );
}

List<T> _list<T>(Object? raw, T? Function(Object?) parse) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (parse(e) case final T v) v,
  ];
}

/// Reconnaît un fichier de sauvegarde. Rend null si ce n'en est pas une —
/// l'appelant peut alors tenter les autres formats (export TV Time).
///
/// Ne lève jamais : un fichier abîmé donne un [UnsupportedBackup] ou null.
BackupFile? parseBackupFile(Object? decoded) {
  if (decoded is! Map) return null;
  final map = decoded.cast<Object?, Object?>();
  // Une sauvegarde a au moins l'un des deux tableaux. Un tableau présent mais
  // du mauvais type disqualifie le fichier.
  final hasShows = map.containsKey('shows');
  final hasMovies = map.containsKey('movies');
  if (!hasShows && !hasMovies) return null;
  if ((hasShows && map['shows'] is! List) ||
      (hasMovies && map['movies'] is! List)) {
    return const UnsupportedBackup(
      'Ce fichier n\'est pas une sauvegarde Nitrate reconnue.',
    );
  }

  final rawVersion = map['schemaVersion'];
  if (rawVersion != null) {
    final version = _int(rawVersion);
    if (version == null) {
      return const UnsupportedBackup(
        'Ce fichier n\'est pas une sauvegarde Nitrate reconnue.',
      );
    }
    if (version > currentBackupSchemaVersion) {
      return const UnsupportedBackup(
        'Cette sauvegarde vient d\'une version plus récente de Nitrate. '
        'Mets l\'application à jour avant de la restaurer.',
      );
    }
  }

  final shows = _list(map['shows'], _show);
  final movies = _list(map['movies'], _movie);
  final provider = _text(map['metadataProvider'])?.toLowerCase();

  // Restaurer des identifiants tels quels exige que le fichier déclare d'où
  // ils viennent. Tout le reste passe par une nouvelle mise en correspondance.
  if (provider == kBackupProvider) {
    return NitrateBackup(
      shows: shows,
      movies: movies,
      schemaVersion: _int(rawVersion) ?? currentBackupSchemaVersion,
      exportedAt: _date(map['exportedAt']),
    );
  }
  if (provider == null || provider == _legacyProvider) {
    return LegacyBackup(shows: shows, movies: movies);
  }
  return UnsupportedBackup(
    'Cette sauvegarde vient d\'une application inconnue ($provider). '
    'Nitrate ne sait pas d\'où viennent ses identifiants.',
  );
}
