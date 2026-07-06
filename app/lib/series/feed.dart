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

/// Construit le fil à partir de l'état local (séries, épisodes cachés, coches).
/// Pur et déterministe — `now` est injecté pour la testabilité.
SeriesFeed buildSeriesFeed({
  required List<ShowWithProgress> shows,
  required List<Episode> episodes,
  required List<WatchedEpisode> watched,
  required DateTime now,
  Duration staleAfter = const Duration(days: 21),
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

  bool aired(Episode e) => e.airDate == null || !e.airDate!.isAfter(now);
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
      final watchable = eps.where(aired).toList()..sort(_compareEpisodes);
      final unwatched =
          watchable.where((e) => !wk.contains(key(e.season, e.episode))).toList();
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
    (s.activity.isBefore(threshold) ? stale : toWatch).add(s.next);
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
  return NextUp(
      show: show, season: maxS, episode: maxE + 1, precise: false);
}
