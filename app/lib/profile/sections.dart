import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../db/database.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'universe.dart';

// ───────────────────────────── En-tête de section ──────────────────────────

/// Titre de section : petit libellé lumineux + sous-titre, avec action
/// optionnelle à droite (ex. « Tout voir »).
class UniverseSectionTitle extends StatelessWidget {
  const UniverseSectionTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 30, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
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
          ),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel ?? 'Tout voir',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: TtColors.amber,
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 17, color: TtColors.amber),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Répartition par genre ─────────────────────────

typedef _FilmSlice = ({String name, double weight, Color color});

/// Pellicule 35 mm : chaque photogramme est un genre, sa largeur est
/// proportionnelle au temps passé, et il est habillé de l'affiche de ta
/// série/ton film phare du genre (teintée). Perforations haut/bas.
class GenreFilmStrip extends StatelessWidget {
  const GenreFilmStrip({super.key, required this.universe});

  final Universe universe;

  @override
  Widget build(BuildContext context) {
    final genres = universe.genres;
    final total = universe.totalGenreWeight;
    if (genres.isEmpty || total <= 0) {
      return const _EmptyHint(
        icon: Icons.theaters_outlined,
        text: 'Ajoute des séries et des films pour impressionner ta pellicule.',
      );
    }

    final top = genres.take(6).toList();
    final rest = total - top.fold(0.0, (s, g) => s + g.weight);
    final slices = <_FilmSlice>[
      for (final g in top) (name: g.name, weight: g.weight, color: g.color),
      if (rest > total * 0.005)
        (name: 'Autres', weight: rest, color: const Color(0xFF454D5E)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 84,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _FilmBasePainter()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 17.5, 8, 17.5),
                  child: Row(
                    children: [
                      for (final s in slices)
                        Expanded(
                          flex: math.max(1, (s.weight / total * 1000).round()),
                          child: _FilmFrame(
                            slice: s,
                            poster: s.name == 'Autres'
                                ? null
                                : universe.posterByGenre[s.name],
                            percent: (s.weight / total * 100).round(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in top)
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

/// Corps de la pellicule : fond sombre + perforations haut/bas.
class _FilmBasePainter extends CustomPainter {
  const _FilmBasePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));

    canvas.drawRRect(base, Paint()..color = const Color(0xFF10141D));
    canvas.drawRRect(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    const holeW = 9.0, holeH = 6.5, step = 17.0;
    final holePaint = Paint()..color = const Color(0xFF060810);
    for (var x = 10.0; x + holeW < w - 10; x += step) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 6, holeW, holeH), const Radius.circular(2)),
        holePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, h - 6 - holeH, holeW, holeH),
            const Radius.circular(2)),
        holePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_FilmBasePainter old) => false;
}

/// Un photogramme : affiche du titre phare du genre (si connue) teintée par
/// la couleur du genre, sinon aplat coloré ; libellé si la place le permet.
class _FilmFrame extends StatelessWidget {
  const _FilmFrame({
    required this.slice,
    required this.poster,
    required this.percent,
  });

  final _FilmSlice slice;
  final String? poster;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final colorBox = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(slice.color, Colors.white, 0.16)!,
            Color.lerp(slice.color, Colors.black, 0.28)!,
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            fit: StackFit.expand,
            children: [
              if (poster != null)
                Image.network(
                  imageUrl(poster!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => colorBox,
                )
              else
                colorBox,
              // Teinte du genre par-dessus l'affiche.
              if (poster != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: slice.color.withValues(alpha: 0.38),
                  ),
                ),
              // Lustre + assise sombre pour le libellé.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.38),
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
              if (c.maxWidth > 58)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slice.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Color(0xAA000000), blurRadius: 4)
                          ],
                        ),
                      ),
                      Text(
                        '$percent %',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85),
                          shadows: const [
                            Shadow(color: Color(0xAA000000), blurRadius: 4)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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

// ─────────────────────────────── À l'affiche ───────────────────────────────

/// Carrousel « hall de cinéma » : une grande affiche centrale avec sa
/// progression, les voisines en retrait sur les côtés. Aperçu limité —
/// la page « Mes séries » montre tout.
class MarqueeCarousel extends StatefulWidget {
  const MarqueeCarousel({
    super.key,
    required this.shows,
    required this.lastActivity,
  });

  final List<ShowWithProgress> shows;
  final Map<int, DateTime> lastActivity;

  static const maxItems = 8;

  @override
  State<MarqueeCarousel> createState() => _MarqueeCarouselState();
}

class _MarqueeCarouselState extends State<MarqueeCarousel> {
  late final PageController _controller =
      PageController(viewportFraction: 0.58);
  int _current = 0;

  /// Séries en cours d'abord (les plus récemment regardées en tête),
  /// puis les terminées.
  List<ShowWithProgress> get _items {
    final started = widget.shows.where((s) => s.watchedCount > 0).toList()
      ..sort((a, b) {
        final byOngoing = (a.isDone ? 1 : 0).compareTo(b.isDone ? 1 : 0);
        if (byOngoing != 0) return byOngoing;
        final da = widget.lastActivity[a.show.id];
        final db = widget.lastActivity[b.show.id];
        if (da != null && db != null) return db.compareTo(da);
        if (da != null) return -1;
        if (db != null) return 1;
        return b.watchedCount.compareTo(a.watchedCount);
      });
    return started.take(MarqueeCarousel.maxItems).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) {
      return const _EmptyHint(
        icon: Icons.theaters_outlined,
        text: 'Commence une série pour la voir à l\'affiche.',
      );
    }
    final current = items[_current.clamp(0, items.length - 1)];

    return Column(
      children: [
        SizedBox(
          height: 306,
          child: PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) => AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                double delta;
                if (_controller.position.haveDimensions) {
                  delta = ((_controller.page ?? 0) - i).clamp(-1.0, 1.0);
                } else {
                  delta = (_current - i).clamp(-1, 1).toDouble();
                }
                final f = 1 - delta.abs();
                return Center(
                  child: Transform.scale(
                    scale: 0.84 + 0.16 * f,
                    child: Opacity(opacity: 0.42 + 0.58 * f, child: child),
                  ),
                );
              },
              child: _MarqueePoster(item: items[i]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Légende de l'affiche courante.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(
            key: ValueKey(current.show.id),
            children: [
              Text(
                current.show.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [Shadow(color: Color(0xAA000000), blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                current.isDone
                    ? 'Terminée · ${current.watchedCount} ép.'
                    : '${(current.progress * 100).round()} % · '
                        '${current.watchedCount} ép. vus',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: current.isDone
                      ? TtColors.teal
                      : Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MarqueePoster extends StatelessWidget {
  const _MarqueePoster({required this.item});

  final ShowWithProgress item;

  @override
  Widget build(BuildContext context) {
    final show = item.show;
    final done = item.isDone;
    final accent = done ? TtColors.teal : TtColors.amber;
    final path = show.poster;

    return GestureDetector(
      onTap: () => context.push('/show/${show.id}', extra: show.name),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 34,
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (path != null && path.isNotEmpty)
                  Image.network(
                    imageUrl(path, size: 'w500'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _posterFallback(show.name, iconSize: 34),
                  )
                else
                  _posterFallback(show.name, iconSize: 34),
                // Liseré.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: done
                              ? TtColors.teal.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.10),
                          width: done ? 1.4 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
                // Voile bas + progression.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.80),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.progress,
                            minHeight: 6,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.22),
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          done
                              ? 'Terminé'
                              : '${(item.progress * 100).round()} %',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

// ───────────────────────── Tuile d'affiche (grilles) ───────────────────────

/// Affiche compacte avec barre de progression posée dessus — utilisée par la
/// page « Mes séries ». Les séries terminées ont un liseré lumineux.
class SeriesPosterTile extends StatelessWidget {
  const SeriesPosterTile({super.key, required this.item});

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
                ? [
                    BoxShadow(
                        color: TtColors.teal.withValues(alpha: 0.35),
                        blurRadius: 14)
                  ]
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (path != null && path.isNotEmpty)
                Image.network(
                  imageUrl(path, size: 'w342'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _posterFallback(show.name),
                )
              else
                _posterFallback(show.name),
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
}

/// Dégradé de repli (stable par titre) quand il n'y a pas d'affiche.
Widget _posterFallback(String name, {double iconSize = 26}) {
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
    child: Center(
      child: Icon(Icons.tv, color: Colors.white54, size: iconSize),
    ),
  );
}

// ─────────────────────────── Heatmap d'activité ────────────────────────────

/// Bandeau streaks : jours d'affilée en cours + record.
class StreakRow extends StatelessWidget {
  const StreakRow({
    super.key,
    required this.current,
    required this.best,
    required this.accent,
  });

  final int current;
  final int best;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    Widget chip(String emoji, String label, String value, bool lit) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: lit
                ? accent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: lit
                  ? accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          chip('🔥', 'En ce moment',
              current > 0 ? '$current jour${current > 1 ? 's' : ''} d\'affilée' : '—',
              current > 0),
          const SizedBox(width: 10),
          chip('🏆', 'Record',
              best > 0 ? '$best jour${best > 1 ? 's' : ''}' : '—', false),
        ],
      ),
    );
  }
}

/// Calendrier d'activité type « contributions » : dernières ~18 semaines,
/// intensité teintée par la couleur dominante. Tap sur un jour → détail de
/// ce qui a été regardé.
class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({
    super.key,
    required this.activityByDay,
    required this.labelsByDay,
    required this.accent,
    required this.now,
  });

  final Map<DateTime, int> activityByDay;
  final Map<DateTime, List<String>> labelsByDay;
  final Color accent;
  final DateTime now;

  static const weeks = 18;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  DateTime? _selected;

  DateTime get _today =>
      DateTime(widget.now.year, widget.now.month, widget.now.day);

  DateTime get _firstMonday {
    final mondayThisWeek =
        _today.subtract(Duration(days: _today.weekday - 1));
    return mondayThisWeek
        .subtract(Duration(days: (ActivityHeatmap.weeks - 1) * 7));
  }

  void _onTap(Offset pos, double cell, double gap) {
    final w = pos.dx ~/ (cell + gap);
    final d = pos.dy ~/ (cell + gap);
    if (w < 0 || w >= ActivityHeatmap.weeks || d < 0 || d > 6) return;
    final date = _firstMonday.add(Duration(days: w * 7 + d));
    if (date.isAfter(_today)) return;
    final has = (widget.activityByDay[date] ?? 0) > 0;
    setState(() {
      _selected = (_selected == date || !has) ? null : date;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activityByDay.isEmpty) {
      return const _EmptyHint(
        icon: Icons.calendar_today_outlined,
        text: 'Ton calendrier se remplit à chaque épisode coché.',
      );
    }
    final accent = widget.accent;
    final sel = _selected;
    final selLabels = sel == null
        ? const <String>[]
        : (widget.labelsByDay[sel] ?? const <String>[]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 4.0;
          final cell =
              ((c.maxWidth - gap * (ActivityHeatmap.weeks - 1)) /
                      ActivityHeatmap.weeks)
                  .clamp(8.0, 18.0);
          final height = cell * 7 + gap * 6;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTapUp: (d) => _onTap(d.localPosition, cell, gap),
                child: SizedBox(
                  height: height,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _HeatmapPainter(
                      activityByDay: widget.activityByDay,
                      accent: accent,
                      now: widget.now,
                      weeks: ActivityHeatmap.weeks,
                      cell: cell,
                      gap: gap,
                      selected: sel,
                    ),
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
              // Détail du jour sélectionné.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: sel == null
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.45)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${frenchDate(sel)} · ${selLabels.length} visionnage${selLabels.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final l in selLabels.take(6))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  l,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color:
                                        Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            if (selLabels.length > 6)
                              Text(
                                '+ ${selLabels.length - 6} autres',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                          ],
                        ),
                      ),
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
    this.selected,
  });

  final Map<DateTime, int> activityByDay;
  final Color accent;
  final DateTime now;
  final int weeks;
  final double cell;
  final double gap;
  final DateTime? selected;

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
        if (date == selected) {
          canvas.drawRRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8
              ..color = Colors.white.withValues(alpha: 0.95),
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
      old.cell != cell ||
      old.selected != selected;
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

/// Élément de la liste de lecture (film non vu ou série pas commencée).
class WatchItem {
  const WatchItem({
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

/// Construit la liste de lecture : films non vus + séries pas commencées.
List<WatchItem> watchlistItems(
    List<Movie> movies, List<ShowWithProgress> shows) {
  return [
    for (final m in movies)
      if (m.watchedAt == null)
        WatchItem(id: m.id, title: m.title, poster: m.poster, isMovie: true),
    for (final s in shows)
      if (s.watchedCount == 0)
        WatchItem(
            id: s.show.id,
            title: s.show.name,
            poster: s.show.poster,
            isMovie: false),
  ];
}

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
    final items = watchlistItems(movies, shows);
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

class _WatchTile extends StatelessWidget {
  const _WatchTile({required this.item});

  final WatchItem item;

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
    return 'Ta salle attend sa première séance.';
  }
  final names = u.genres.take(3).map((g) => g.name).toList();
  final joined = names.length == 1
      ? names.first
      : '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
  return 'Un cinéma tissé de $joined.';
}
