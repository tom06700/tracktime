import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../db/database.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'universe.dart';

// ───────────────────────────── En-tête de section ──────────────────────────

/// Titre de section « cosmique » : petit libellé lumineux + sous-titre.
class UniverseSectionTitle extends StatelessWidget {
  const UniverseSectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: Colors.white,
              shadows: [
                Shadow(color: Color(0x99000000), blurRadius: 8),
              ],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Répartition par genre ─────────────────────────

/// Bande « aurore » : dégradé horizontal fondu, pondéré par le temps passé
/// dans chaque genre, avec halo. Signature visuelle du profil.
class GenreSpectrum extends StatelessWidget {
  const GenreSpectrum({super.key, required this.universe});

  final Universe universe;

  @override
  Widget build(BuildContext context) {
    final genres = universe.genres;
    final total = universe.totalGenreWeight;
    if (genres.isEmpty || total <= 0) {
      return const _EmptyHint(
        icon: Icons.auto_awesome,
        text: 'Ajoute des séries et des films pour révéler ton spectre.',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 26,
            width: double.infinity,
            child: CustomPaint(
              painter: _SpectrumPainter(genres: genres, total: total),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in genres.take(6))
                _GenreChip(
                  slice: g,
                  percent: g.weight / total,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({required this.genres, required this.total});

  final List<GenreSlice> genres;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(13));

    // Construit des arrêts de dégradé fondus au milieu de chaque segment.
    final colors = <Color>[];
    final stops = <double>[];
    var acc = 0.0;
    for (final g in genres) {
      final frac = g.weight / total;
      colors.add(g.color);
      stops.add((acc + frac / 2).clamp(0.0, 1.0));
      acc += frac;
    }
    if (colors.length == 1) {
      colors.add(colors.first);
      stops
        ..clear()
        ..addAll([0, 1]);
    }

    // Halo diffus sous la bande.
    final glow = Paint()
      ..shader = LinearGradient(colors: colors, stops: stops).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRRect(rrect, glow);

    // Bande nette.
    final band = Paint()
      ..shader = LinearGradient(colors: colors, stops: stops).createShader(rect);
    canvas.drawRRect(rrect, band);

    // Lustre en haut.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.5],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.genres != genres || old.total != total;
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.slice, required this.percent});

  final GenreSlice slice;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: slice.color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: slice.color, blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            slice.name,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text(
            '${(percent * 100).round()}%',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Constellation de séries ─────────────────────────

/// Affiches des séries en cours/regardées avec une barre de progression
/// posée dessus. Les séries terminées ont un liseré lumineux.
class SeriesConstellation extends StatelessWidget {
  const SeriesConstellation({super.key, required this.shows});

  final List<ShowWithProgress> shows;

  @override
  Widget build(BuildContext context) {
    final started = shows.where((s) => s.watchedCount > 0).toList()
      ..sort((a, b) {
        final byDone = (b.isDone ? 1 : 0).compareTo(a.isDone ? 1 : 0);
        if (byDone != 0) return byDone;
        return b.watchedCount.compareTo(a.watchedCount);
      });
    if (started.isEmpty) {
      return const _EmptyHint(
        icon: Icons.tv_off_outlined,
        text: 'Tes séries en cours apparaîtront ici, affiche et progression.',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: started.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 116,
          childAspectRatio: 0.62,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemBuilder: (context, i) => _ConstellationTile(item: started[i]),
      ),
    );
  }
}

class _ConstellationTile extends StatelessWidget {
  const _ConstellationTile({required this.item});

  final ShowWithProgress item;

  @override
  Widget build(BuildContext context) {
    final show = item.show;
    final done = item.isDone;
    final accent = done ? TtColors.teal : TtColors.amber;
    final path = show.poster;

    return GestureDetector(
      onTap: () => context.push('/show/${show.id}', extra: show.name),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done
                  ? TtColors.teal.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.08),
              width: done ? 1.5 : 1,
            ),
            boxShadow: done
                ? [BoxShadow(color: TtColors.teal.withValues(alpha: 0.35), blurRadius: 14)]
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (path != null && path.isNotEmpty)
                Image.network(
                  tmdbImageUrl(path, size: 'w342'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _poster(show.name),
                )
              else
                _poster(show.name),
              // Voile bas pour la barre.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(7, 14, 7, 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: item.progress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        done
                            ? 'Terminé'
                            : '${(item.progress * 100).round()}% · ${item.watchedCount} ép.',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: done ? TtColors.teal : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _poster(String name) {
    final hue =
        (name.codeUnits.fold<int>(0, (a, c) => a * 31 + c) % 360).toDouble();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.5, 0.4).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, 0.55, 0.24).toColor(),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.tv, color: Colors.white54, size: 26),
      ),
    );
  }
}

// ─────────────────────────── Heatmap d'activité ────────────────────────────

/// Calendrier d'activité type « contributions » : dernières ~18 semaines,
/// intensité teintée par la couleur dominante de l'univers.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.activityByDay,
    required this.accent,
    required this.now,
  });

  final Map<DateTime, int> activityByDay;
  final Color accent;
  final DateTime now;

  static const _weeks = 18;

  @override
  Widget build(BuildContext context) {
    if (activityByDay.isEmpty) {
      return const _EmptyHint(
        icon: Icons.calendar_today_outlined,
        text: 'Ton calendrier se remplit à chaque épisode coché.',
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 4.0;
          final cell = ((c.maxWidth - gap * (_weeks - 1)) / _weeks)
              .clamp(8.0, 18.0);
          final height = cell * 7 + gap * 6;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _HeatmapPainter(
                    activityByDay: activityByDay,
                    accent: accent,
                    now: now,
                    weeks: _weeks,
                    cell: cell,
                    gap: gap,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Moins',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5))),
                  const SizedBox(width: 6),
                  for (final level in const [0, 1, 2, 3])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: _levelColor(accent, level),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text('Plus',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

Color _levelColor(Color accent, int level) {
  switch (level) {
    case 0:
      return Colors.white.withValues(alpha: 0.06);
    case 1:
      return accent.withValues(alpha: 0.35);
    case 2:
      return accent.withValues(alpha: 0.65);
    default:
      return accent;
  }
}

int _level(int count) {
  if (count <= 0) return 0;
  if (count == 1) return 1;
  if (count <= 3) return 2;
  return 3;
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.activityByDay,
    required this.accent,
    required this.now,
    required this.weeks,
    required this.cell,
    required this.gap,
  });

  final Map<DateTime, int> activityByDay;
  final Color accent;
  final DateTime now;
  final int weeks;
  final double cell;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final today = DateTime(now.year, now.month, now.day);
    // Lundi de la semaine courante, puis recul de (weeks-1) semaines.
    final mondayThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday = mondayThisWeek.subtract(Duration(days: (weeks - 1) * 7));
    final radius = Radius.circular(cell * 0.28);

    for (var w = 0; w < weeks; w++) {
      for (var d = 0; d < 7; d++) {
        final date = firstMonday.add(Duration(days: w * 7 + d));
        if (date.isAfter(today)) continue;
        final count = activityByDay[date] ?? 0;
        final color = _levelColor(accent, _level(count));
        final x = w * (cell + gap);
        final y = d * (cell + gap);
        final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, cell, cell), radius);
        canvas.drawRRect(r, Paint()..color = color);
        if (count > 3) {
          canvas.drawRRect(
            r,
            Paint()
              ..color = accent.withValues(alpha: 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.activityByDay != activityByDay ||
      old.accent != accent ||
      old.now != now ||
      old.cell != cell;
}

// ──────────────────────────────── Records ──────────────────────────────────

class RecordsBand extends StatelessWidget {
  const RecordsBand({super.key, required this.records});

  final List<UniverseRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final r in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Text(r.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            r.value,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────── Badges ───────────────────────────────────

class BadgeWall extends StatelessWidget {
  const BadgeWall({super.key, required this.badges});

  final List<UniverseBadge> badges;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: badges.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.82,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, i) => _BadgeTile(badge: badges[i]),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final UniverseBadge badge;

  @override
  Widget build(BuildContext context) {
    final on = badge.unlocked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: on
            ? TtColors.amber.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: on
              ? TtColors.amber.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: on
            ? [BoxShadow(color: TtColors.amber.withValues(alpha: 0.25), blurRadius: 16)]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: on ? 1 : 0.35,
            child: Text(badge.emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: 8),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: on ? Colors.white : Colors.white.withValues(alpha: 0.55),
            ),
          ),
          if (!on && badge.progressLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              badge.progressLabel!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: TtColors.amber.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Liste de lecture ──────────────────────────────

/// « Liste de lecture » : films non vus + séries pas encore commencées,
/// en bande horizontale d'affiches.
class WatchlistStrip extends StatelessWidget {
  const WatchlistStrip({
    super.key,
    required this.movies,
    required this.shows,
  });

  final List<Movie> movies;
  final List<ShowWithProgress> shows;

  @override
  Widget build(BuildContext context) {
    final items = <_WatchItem>[
      for (final m in movies)
        if (m.watchedAt == null)
          _WatchItem(
            id: m.id,
            title: m.title,
            poster: m.poster,
            isMovie: true,
          ),
      for (final s in shows)
        if (s.watchedCount == 0)
          _WatchItem(
            id: s.show.id,
            title: s.show.name,
            poster: s.show.poster,
            isMovie: false,
          ),
    ];
    if (items.isEmpty) {
      return const _EmptyHint(
        icon: Icons.playlist_add_check,
        text: 'Ta liste de lecture est vide — ajoute des titres à voir.',
      );
    }

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _WatchTile(item: items[i]),
      ),
    );
  }
}

class _WatchItem {
  const _WatchItem({
    required this.id,
    required this.title,
    required this.poster,
    required this.isMovie,
  });
  final int id;
  final String title;
  final String? poster;
  final bool isMovie;
}

class _WatchTile extends StatelessWidget {
  const _WatchTile({required this.item});

  final _WatchItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.isMovie
          ? null
          : () => context.push('/show/${item.id}', extra: item.title),
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 104,
                  child: PosterBox(
                    posterPath: item.poster,
                    fallbackIcon:
                        item.isMovie ? Icons.movie_outlined : Icons.tv,
                    label: item.title,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              item.isMovie ? 'Film' : 'Série',
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Divers ────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tagline poétique dérivée des genres dominants.
String universeTagline(Universe u) {
  if (!u.hasGenres) {
    return 'Ton univers attend sa première étoile.';
  }
  final names = u.genres.take(3).map((g) => g.name).toList();
  final joined = names.length == 1
      ? names.first
      : '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
  return 'Un cosmos tissé de $joined.';
}
