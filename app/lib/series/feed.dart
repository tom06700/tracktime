import '../db/database.dart';

/// Prochain épisode à voir d'une série (carte du fil « À voir »).
class NextUp {
  const NextUp({
    required this.show,
    required this.season,
    required this.episode,
    this.episodeName,
    this.still,
    this.remaining,
    required this.precise,
    this.lastActivity,
  });

  final Show show;
  final int season;
  final int episode;
  final String? episodeName;
  final String? still;

  /// Nombre d'épisodes diffusés restants APRÈS celui-ci (le « +N »).
  /// null si inconnu (métadonnées d'épisodes pas encore synchronisées).
  final int? remaining;

  /// true si calculé à partir des métadonnées TMDB (titre/still fiables),
  /// false si estimé à partir des seules coches (fallback sans réseau).
  final bool precise;

  /// Dernier visionnage sur cette série, ou son ajout si rien n'a été vu.
  /// Sert au libellé « ça fait un moment » de la section « À reprendre ».
  final DateTime? lastActivity;

  String get code =>
      'S${season.toString().padLeft(2, '0')} | E${episode.toString().padLeft(2, '0')}';
}

/// Entrée d'historique (dernier épisode vu d'une série), carte grisée.
class HistoryEntry {
  const HistoryEntry({
    required this.show,
    required this.season,
    required this.episode,
    this.episodeName,
    this.still,
    required this.watchedAt,
  });

  final Show show;
  final int season;
  final int episode;
  final String? episodeName;
  final String? still;
  final DateTime watchedAt;

  String get code =>
      'S${season.toString().padLeft(2, '0')} | E${episode.toString().padLeft(2, '0')}';
}

/// Fil de la page Séries, à la TV Time : historique en haut, « à voir » au
/// milieu (activité récente), séries délaissées en bas.
class SeriesFeed {
  const SeriesFeed({
    required this.history,
    required this.toWatch,
    required this.stale,
  });

  final List<HistoryEntry> history;
  final List<NextUp> toWatch;
  final List<NextUp> stale;

  bool get isEmpty => history.isEmpty && toWatch.isEmpty && stale.isEmpty;
}

int _compareEpisodes(Episode a, Episode b) {
  final s = a.season.compareTo(b.season);
  return s != 0 ? s : a.episode.compareTo(b.episode);
}

/// Prochain épisode à sortir d'une série (onglet « À venir »).
class UpcomingEpisode {
  const UpcomingEpisode({
    required this.show,
    required this.season,
    required this.episode,
    required this.airDate,
    this.name,
    this.still,
  });

  final Show show;
  final int season;
  final int episode;
  final DateTime airDate;
  final String? name;
  final String? still;

  String get code =>
      'S${season.toString().padLeft(2, '0')} | E${episode.toString().padLeft(2, '0')}';

  /// Nombre de jours (calendaires) avant diffusion.
  int daysFrom(DateTime now) =>
      calendarDay(airDate).difference(calendarDay(now)).inDays;
}

/// Jour calendaire d'un instant, heure remise à zéro.
///
/// Toutes les comparaisons de diffusion passent par là : TheTVDB date ses
/// épisodes à la journée (minuit), donc comparer des instants ferait
/// disparaître l'épisode du jour dès 00 h 01 — il serait « passé » alors qu'il
/// n'est pas encore diffusé.
DateTime calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Un épisode est considéré diffusé dès que son jour de diffusion est atteint.
/// Hier → oui, aujourd'hui → oui, demain → non. Une date inconnue est traitée
/// comme diffusée, pour ne pas bloquer le fil « à voir ».
bool hasAiredByDay(DateTime? airDate, DateTime now) =>
    airDate == null || !calendarDay(airDate).isAfter(calendarDay(now));

/// Fenêtre par défaut de l'onglet « À venir ». Au-delà, les dates annoncées par
/// TheTVDB sont trop mouvantes pour être affichées comme un rendez-vous.
const kUpcomingWindow = Duration(days: 90);

/// Tous les épisodes à diffuser des séries suivies, du plus proche au plus
/// loin. Pur et déterministe.
///
/// Contrairement à la version précédente, on ne garde pas qu'un seul épisode
/// par série : une série qui diffuse deux fois par semaine doit montrer ses
/// deux rendez-vous. L'épisode du jour est inclus (« Aujourd'hui »), celui
/// d'hier non.
List<UpcomingEpisode> buildUpcoming({
  required List<ShowWithProgress> shows,
  required List<Episode> episodes,
  required DateTime now,
  Duration window = kUpcomingWindow,
}) {
  final showById = {for (final s in shows) s.show.id: s.show};
  final today = calendarDay(now);
  final last = today.add(window);

  final list = <UpcomingEpisode>[];
  for (final e in episodes) {
    final air = e.airDate;
    if (air == null) continue;
    final show = showById[e.showId];
    if (show == null) continue;
    final day = calendarDay(air);
    if (day.isBefore(today) || day.isAfter(last)) continue;
    list.add(UpcomingEpisode(
      show: show,
      season: e.season,
      episode: e.episode,
      airDate: air,
      name: e.name,
      still: e.still,
    ));
  }

  // Ordre total : deux épisodes du même jour ne doivent pas changer de place
  // d'un rebuild à l'autre.
  list.sort((a, b) {
    final d = a.airDate.compareTo(b.airDate);
    if (d != 0) return d;
    final n = a.show.name.compareTo(b.show.name);
    if (n != 0) return n;
    final s = a.season.compareTo(b.season);
    return s != 0 ? s : a.episode.compareTo(b.episode);
  });
  return list;
}

/// Construit le fil à partir de l'état local (séries, épisodes cachés, coches).
/// Pur et déterministe — `now` est injecté pour la testabilité.
SeriesFeed buildSeriesFeed({
  required List<ShowWithProgress> shows,
  required List<Episode> episodes,
  required List<WatchedEpisode> watched,
  required DateTime now,
  Duration staleAfter = const Duration(days: 18),
  int historyLimit = 8,
}) {
  final episodesByShow = <int, List<Episode>>{};
  for (final e in episodes) {
    (episodesByShow[e.showId] ??= []).add(e);
  }

  final watchedByShow = <int, Set<String>>{};
  final lastWatchedByShow = <int, WatchedEpisode>{};
  for (final w in watched) {
    (watchedByShow[w.showId] ??= {}).add('S${w.season}E${w.episode}');
    final cur = lastWatchedByShow[w.showId];
    if (cur == null || w.watchedAt.isAfter(cur.watchedAt)) {
      lastWatchedByShow[w.showId] = w;
    }
  }

  final showById = {for (final s in shows) s.show.id: s.show};

  bool aired(Episode e) => hasAiredByDay(e.airDate, now);
  String key(int s, int e) => 'S${s}E$e';

  // ---- Historique : derniers épisodes vus, plus récents d'abord ----
  final history = <HistoryEntry>[];
  final lastWatchedList = lastWatchedByShow.values.toList()
    ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  for (final w in lastWatchedList.take(historyLimit)) {
    final show = showById[w.showId];
    if (show == null) continue;
    Episode? meta;
    for (final e in episodesByShow[w.showId] ?? const <Episode>[]) {
      if (e.season == w.season && e.episode == w.episode) {
        meta = e;
        break;
      }
    }
    history.add(HistoryEntry(
      show: show,
      season: w.season,
      episode: w.episode,
      episodeName: meta?.name,
      still: meta?.still,
      watchedAt: w.watchedAt,
    ));
  }

  // ---- À voir : prochain épisode par série en cours ----
  final scored = <({NextUp next, DateTime activity})>[];
  for (final sw in shows) {
    final show = sw.show;
    final wk = watchedByShow[show.id] ?? const {};
    final eps = episodesByShow[show.id];
    final activity = lastWatchedByShow[show.id]?.watchedAt ?? show.addedAt;

    NextUp? next;
    if (eps != null && eps.isNotEmpty) {
      // Précis : premier épisode diffusé non vu, dans l'ordre.
      final watchable = eps.where((e) => e.season > 0 && aired(e)).toList()
        ..sort(_compareEpisodes);
      final unwatched = watchable
          .where((e) => !wk.contains(key(e.season, e.episode)))
          .toList();
      if (unwatched.isEmpty) continue; // à jour → pas dans « à voir »
      final e = unwatched.first;
      next = NextUp(
        show: show,
        season: e.season,
        episode: e.episode,
        episodeName: e.name,
        still: e.still,
        remaining: unwatched.length - 1,
        precise: true,
      );
    } else {
      // Fallback sans métadonnées : pointeur « continuer » depuis les coches.
      next = _fallbackNext(show, wk);
    }

    scored.add((next: next, activity: activity));
  }

  scored.sort((a, b) => b.activity.compareTo(a.activity));
  final threshold = now.subtract(staleAfter);
  final toWatch = <NextUp>[];
  final stale = <NextUp>[];
  for (final s in scored) {
    final next = NextUp(
      show: s.next.show,
      season: s.next.season,
      episode: s.next.episode,
      episodeName: s.next.episodeName,
      still: s.next.still,
      remaining: s.next.remaining,
      precise: s.next.precise,
      lastActivity: s.activity,
    );
    (s.activity.isBefore(threshold) ? stale : toWatch).add(next);
  }

  return SeriesFeed(history: history, toWatch: toWatch, stale: stale);
}

/// Prochain épisode estimé à partir des seules coches (max vu + 1), utilisé
/// tant que les métadonnées TMDB ne sont pas synchronisées.
NextUp _fallbackNext(Show show, Set<String> watchedKeys) {
  if (watchedKeys.isEmpty) {
    return NextUp(show: show, season: 1, episode: 1, precise: false);
  }
  var maxS = 1, maxE = 0;
  for (final k in watchedKeys) {
    final m = RegExp(r'^S(\d+)E(\d+)$').firstMatch(k);
    if (m == null) continue;
    final s = int.parse(m.group(1)!);
    final e = int.parse(m.group(2)!);
    if (s > maxS || (s == maxS && e > maxE)) {
      maxS = s;
      maxE = e;
    }
  }
  return NextUp(show: show, season: maxS, episode: maxE + 1, precise: false);
}

/// Un épisode vu, pour la page Historique. Contrairement à
/// [SeriesFeed.history] qui ne retient que le dernier épisode de chaque série,
/// on liste ici toutes les coches, du plus récent au plus ancien.
class WatchedEntry {
  const WatchedEntry({
    required this.show,
    required this.season,
    required this.episode,
    required this.watchedAt,
    this.episodeName,
    this.still,
  });

  final Show show;
  final int season;
  final int episode;
  final DateTime watchedAt;
  final String? episodeName;
  final String? still;

  String get code =>
      'S${season.toString().padLeft(2, '0')} | E${episode.toString().padLeft(2, '0')}';
}

/// Historique complet, du plus récent au plus ancien. Pur et déterministe.
List<WatchedEntry> buildWatchHistory({
  required List<ShowWithProgress> shows,
  required List<Episode> episodes,
  required List<WatchedEpisode> watched,
}) {
  final showById = {for (final s in shows) s.show.id: s.show};
  final metaByKey = <String, Episode>{
    for (final e in episodes) '${e.showId}|${e.season}|${e.episode}': e,
  };

  final entries = <WatchedEntry>[];
  for (final w in watched) {
    final show = showById[w.showId];
    if (show == null) continue;
    final meta = metaByKey['${w.showId}|${w.season}|${w.episode}'];
    entries.add(WatchedEntry(
      show: show,
      season: w.season,
      episode: w.episode,
      watchedAt: w.watchedAt,
      episodeName: meta?.name,
      still: meta?.still,
    ));
  }
  entries.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  return entries;
}

/// Tranches temporelles de l'onglet « À venir ».
enum UpcomingBucket { today, tomorrow, thisWeek, later }

extension UpcomingBucketLabel on UpcomingBucket {
  String get label => switch (this) {
        UpcomingBucket.today => "Aujourd'hui",
        UpcomingBucket.tomorrow => 'Demain',
        UpcomingBucket.thisWeek => 'Cette semaine',
        UpcomingBucket.later => 'Plus tard',
      };
}

/// Répartit les épisodes à venir par proximité, en conservant l'ordre
/// chronologique à l'intérieur de chaque tranche. Les tranches vides sont
/// omises. Pur et déterministe.
///
/// « Plus tard » couvre trois mois : une série quotidienne y déverserait des
/// dizaines de lignes et noierait les autres. On n'en garde donc que les
/// [laterPerShowLimit] premiers épisodes par série — les tranches proches, elles,
/// restent complètes.
List<({UpcomingBucket bucket, List<UpcomingEpisode> episodes})> groupUpcoming(
  List<UpcomingEpisode> list,
  DateTime now, {
  int laterPerShowLimit = 3,
}) {
  final byBucket = <UpcomingBucket, List<UpcomingEpisode>>{};
  final laterCount = <int, int>{};
  for (final u in list) {
    final days = u.daysFrom(now);
    final bucket = switch (days) {
      <= 0 => UpcomingBucket.today,
      1 => UpcomingBucket.tomorrow,
      <= 7 => UpcomingBucket.thisWeek,
      _ => UpcomingBucket.later,
    };
    if (bucket == UpcomingBucket.later) {
      final seen = laterCount[u.show.id] ?? 0;
      if (seen >= laterPerShowLimit) continue;
      laterCount[u.show.id] = seen + 1;
    }
    (byBucket[bucket] ??= []).add(u);
  }
  return [
    for (final b in UpcomingBucket.values)
      if (byBucket[b] != null) (bucket: b, episodes: byBucket[b]!),
  ];
}
