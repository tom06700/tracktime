import 'package:flutter/material.dart';

import '../db/database.dart';

/// Couleur associée à un genre (mots-clés FR/EN), pour teinter tout l'univers.
Color genreColor(String genre) {
  final g = genre.toLowerCase();
  bool has(String s) => g.contains(s);
  if (has('action')) return const Color(0xFFE5484D);
  if (has('aventure') || has('adventure')) return const Color(0xFFF5A524);
  if (has('anim')) return const Color(0xFF35C4C4);
  if (has('coméd') || has('comed')) return const Color(0xFFF5D020);
  if (has('crime') || has('policier')) return const Color(0xFF5B6B8C);
  if (has('docu')) return const Color(0xFF3FB871);
  if (has('dram')) return const Color(0xFF4C82F5);
  if (has('familial') || has('enfant') || has('family') || has('kids')) {
    return const Color(0xFF8BD44F);
  }
  if (has('fantas') || has('fantasy')) return const Color(0xFF9B5CF6);
  if (has('histoire') || has('history')) return const Color(0xFFB98A44);
  if (has('horreur') || has('horror')) return const Color(0xFF8E1F2C);
  if (has('musi') || has('music')) return const Color(0xFFEC5FA6);
  if (has('mystère') || has('mystere') || has('mystery')) {
    return const Color(0xFF7A5CF6);
  }
  if (has('romance')) return const Color(0xFFF06B9A);
  if (has('science') || has('sci-fi') || has('fiction')) {
    return const Color(0xFF6C4CE0);
  }
  if (has('thriller') || has('suspense')) return const Color(0xFFE0673C);
  if (has('guerre') || has('war') || has('politi')) {
    return const Color(0xFF7C7A3C);
  }
  if (has('western')) return const Color(0xFFC98A5B);
  if (has('réalité') || has('realite') || has('reality')) {
    return const Color(0xFFD44FC4);
  }
  if (has('actual') || has('news')) return const Color(0xFF5C8CB8);
  if (has('feuilleton') || has('soap')) return const Color(0xFFEC7FB0);
  // Repli : teinte stable dérivée du nom.
  final hue = (genre.codeUnits.fold<int>(7, (a, c) => a * 31 + c) % 360)
      .toDouble()
      .abs();
  return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
}

class GenreSlice {
  const GenreSlice(this.name, this.weight);
  final String name;
  final double weight;
  Color get color => genreColor(name);
}

class UniverseBadge {
  const UniverseBadge({
    required this.label,
    required this.emoji,
    required this.unlocked,
    this.progressLabel,
  });
  final String label;
  final String emoji;
  final bool unlocked;
  final String? progressLabel;
}

class UniverseRecord {
  const UniverseRecord(this.emoji, this.label, this.value);
  final String emoji;
  final String label;
  final String value;
}

class Universe {
  const Universe({
    required this.genres,
    required this.palette,
    required this.seed,
    required this.activityByDay,
    required this.labelsByDay,
    required this.lastActivityByShow,
    required this.posterByGenre,
    required this.currentStreak,
    required this.bestStreak,
    required this.badges,
    required this.records,
    required this.hasGenres,
  });

  final List<GenreSlice> genres; // triés décroissant
  final List<Color> palette; // couleurs dominantes (>=1)
  final int seed;
  final Map<DateTime, int> activityByDay;

  /// Ce qui a été vu chaque jour (« Dark · S1E3 », « Inception · film »),
  /// pour le détail au tap sur la heatmap.
  final Map<DateTime, List<String>> labelsByDay;

  /// Dernière coche par série, pour trier « à l'affiche » et « Mes séries ».
  final Map<int, DateTime> lastActivityByShow;

  /// Affiche de la série/du film phare de chaque genre (pellicule).
  final Map<String, String> posterByGenre;

  /// Jours d'affilée avec au moins un visionnage (grâce d'un jour), et record.
  final int currentStreak;
  final int bestStreak;

  final List<UniverseBadge> badges;
  final List<UniverseRecord> records;
  final bool hasGenres;

  double get totalGenreWeight =>
      genres.fold(0.0, (s, g) => s + g.weight);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Palette par défaut (cosmos froid) quand aucun genre n'est encore connu.
const _defaultPalette = [
  Color(0xFF6C4CE0),
  Color(0xFF4C82F5),
  Color(0xFF35C4C4),
];

Universe buildUniverse({
  required List<ShowWithProgress> shows,
  required List<WatchedEpisode> watched,
  required List<Movie> movies,
  required String profileName,
  required DateTime now,
  required WatchStats stats,
}) {
  // ---- Poids par genre (proportionnel au temps passé) ----
  final weights = <String, double>{};
  void addGenres(String? raw, double weight) {
    final list =
        (raw ?? '').split('|').where((x) => x.trim().isNotEmpty).toList();
    if (list.isEmpty || weight <= 0) return;
    final per = weight / list.length;
    for (final name in list) {
      weights[name] = (weights[name] ?? 0) + per;
    }
  }

  for (final sw in shows) {
    addGenres(sw.show.genres, sw.watchedCount.toDouble());
  }
  for (final m in movies) {
    if (m.watchedAt != null) addGenres(m.genres, 2.5);
  }

  final genreList = weights.entries
      .map((e) => GenreSlice(e.key, e.value))
      .toList()
    ..sort((a, b) => b.weight.compareTo(a.weight));

  final palette = genreList.isEmpty
      ? _defaultPalette
      : genreList.take(4).map((g) => g.color).toList();

  // ---- Activité par jour + libellés + dernière coche par série ----
  final byDay = <DateTime, int>{};
  final labelsByDay = <DateTime, List<String>>{};
  final lastByShow = <int, DateTime>{};
  final nameById = {for (final s in shows) s.show.id: s.show.name};
  for (final w in watched) {
    final d = _day(w.watchedAt);
    byDay[d] = (byDay[d] ?? 0) + 1;
    labelsByDay
        .putIfAbsent(d, () => [])
        .add('${nameById[w.showId] ?? 'Série'} · S${w.season}E${w.episode}');
    final cur = lastByShow[w.showId];
    if (cur == null || w.watchedAt.isAfter(cur)) {
      lastByShow[w.showId] = w.watchedAt;
    }
  }
  for (final m in movies) {
    if (m.watchedAt != null) {
      final d = _day(m.watchedAt!);
      byDay[d] = (byDay[d] ?? 0) + 1;
      labelsByDay.putIfAbsent(d, () => []).add('${m.title} · film');
    }
  }

  // ---- Streaks (jours consécutifs avec visionnage) ----
  var bestStreak = 0;
  {
    final days = byDay.keys.toList()..sort();
    DateTime? prev;
    var run = 0;
    for (final d in days) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > bestStreak) bestStreak = run;
      prev = d;
    }
  }
  var currentStreak = 0;
  {
    // Grâce d'un jour : une série entamée hier n'est pas encore rompue.
    var probe = _day(now);
    if (!byDay.containsKey(probe)) {
      probe = probe.subtract(const Duration(days: 1));
    }
    while (byDay.containsKey(probe)) {
      currentStreak++;
      probe = probe.subtract(const Duration(days: 1));
    }
  }

  // ---- Affiche phare par genre (pour la pellicule) ----
  final posterByGenre = <String, String>{};
  final byWatched = [...shows]
    ..sort((a, b) => b.watchedCount.compareTo(a.watchedCount));
  for (final sw in byWatched) {
    final p = sw.show.poster;
    if (p == null || p.isEmpty || sw.watchedCount == 0) continue;
    for (final g in (sw.show.genres ?? '').split('|')) {
      final t = g.trim();
      if (t.isNotEmpty) posterByGenre.putIfAbsent(t, () => p);
    }
  }
  for (final m in movies) {
    final p = m.poster;
    if (m.watchedAt == null || p == null || p.isEmpty) continue;
    for (final g in (m.genres ?? '').split('|')) {
      final t = g.trim();
      if (t.isNotEmpty) posterByGenre.putIfAbsent(t, () => p);
    }
  }

  // ---- Records ----
  final records = <UniverseRecord>[];
  // Plus grosse journée.
  int maxDay = 0;
  DateTime? maxDayDate;
  byDay.forEach((d, c) {
    if (c > maxDay) {
      maxDay = c;
      maxDayDate = d;
    }
  });
  if (maxDay >= 2 && maxDayDate != null) {
    records.add(UniverseRecord('🔥', 'Plus gros marathon',
        '$maxDay épisodes en un jour'));
  }
  // Série la plus avancée en nombre d'épisodes vus.
  ShowWithProgress? mostWatched;
  for (final sw in shows) {
    if (mostWatched == null || sw.watchedCount > mostWatched.watchedCount) {
      mostWatched = sw;
    }
  }
  final top = mostWatched;
  if (top != null && top.watchedCount > 0) {
    records.add(UniverseRecord('📺', 'Série la plus regardée',
        '${top.show.name} · ${top.watchedCount} ép.'));
  }
  // Temps moyen par jour depuis la première activité.
  final dates = <DateTime>[
    for (final w in watched) w.watchedAt,
    for (final m in movies)
      if (m.watchedAt != null) m.watchedAt!,
  ];
  if (dates.isNotEmpty) {
    final first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final days = (now.difference(first).inDays).clamp(1, 100000);
    final perDay = stats.totalMinutes / days;
    if (perDay >= 1) {
      records.add(UniverseRecord(
          '⏱️', 'Moyenne par jour', '${perDay.round()} min'));
    }
  }

  // ---- Badges ----
  final badges = <UniverseBadge>[
    UniverseBadge(
        emoji: '🏁',
        label: '10 séries terminées',
        unlocked: stats.doneShowCount >= 10,
        progressLabel: '${stats.doneShowCount}/10'),
    UniverseBadge(
        emoji: '🕰️',
        label: '100 h de visionnage',
        unlocked: stats.totalMinutes >= 6000,
        progressLabel: '${(stats.totalMinutes / 60).round()}/100 h'),
    UniverseBadge(
        emoji: '🔥',
        label: 'Marathon (8 ép./jour)',
        unlocked: maxDay >= 8,
        progressLabel: '$maxDay/8'),
    UniverseBadge(
        emoji: '🎬',
        label: '50 films vus',
        unlocked: stats.moviesSeen >= 50,
        progressLabel: '${stats.moviesSeen}/50'),
    UniverseBadge(
        emoji: '🌌',
        label: '5 genres explorés',
        unlocked: genreList.length >= 5,
        progressLabel: '${genreList.length}/5'),
    UniverseBadge(
        emoji: '📚',
        label: '25 séries suivies',
        unlocked: stats.showCount >= 25,
        progressLabel: '${stats.showCount}/25'),
  ];

  final seed = profileName.codeUnits.fold<int>(2166136261, (h, c) => (h ^ c) * 16777619) ^
      (stats.showCount * 2654435761) ^
      (stats.episodeCount * 40503);

  return Universe(
    genres: genreList,
    palette: palette,
    seed: seed & 0x7fffffff,
    activityByDay: byDay,
    labelsByDay: labelsByDay,
    lastActivityByShow: lastByShow,
    posterByGenre: posterByGenre,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    badges: badges,
    records: records,
    hasGenres: genreList.isNotEmpty,
  );
}
