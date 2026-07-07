import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// Carte de film du fil Films (à voir · vu · à venir), calquée sur
/// [EpisodeCard] : affiche à gauche, titre + méta au centre, coche à droite
/// (ou compteur de jours pour un film à venir).
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.title,
    required this.poster,
    this.metaLine,
    this.badge,
    this.onTap,
    this.onToggleWatched,
    this.history = false,
    this.upcomingInDays,
  });

  final String title;
  final String? poster;

  /// Ligne secondaire : « 2021 · 2 h 35 · Science-Fiction ».
  final String? metaLine;
  final String? badge;
  final VoidCallback? onTap;
  final VoidCallback? onToggleWatched;

  /// Film déjà vu (carte grisée + coche verte pleine, retire du « vu » au tap).
  final bool history;

  /// Si défini : carte « à venir » — compteur de jours à droite, pas de coche.
  final int? upcomingInDays;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 120,
          child: Row(
            children: [
              _Poster(path: poster, seed: title),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            height: 1.2),
                      ),
                      if (metaLine != null && metaLine!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          metaLine!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: TtColors.dim),
                        ),
                      ],
                      if (badge != null) ...[
                        const SizedBox(height: 6),
                        _Badge(badge!),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12, left: 4),
                child: upcomingInDays != null
                    ? _DaysChip(days: upcomingInDays!)
                    : _CheckButton(watched: history, onTap: onToggleWatched),
              ),
            ],
          ),
        ),
      ),
    );
    return history ? Opacity(opacity: 0.55, child: card) : card;
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.path, required this.seed});

  final String? path;
  final String seed;

  @override
  Widget build(BuildContext context) {
    // Affiche 2:3 dans une boîte 2:3 (80×120) : remplit sans recadrer.
    const w = 80.0;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(gradient: _seedGradient(seed)),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white54, size: 22),
      ),
    );
    final child = (path != null && path!.isNotEmpty)
        ? Image.network(
            imageUrl(path!, size: 'w185'),
            width: w,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          )
        : placeholder;
    return SizedBox(width: w, height: double.infinity, child: child);
  }

  static Gradient _seedGradient(String seed) {
    final hue =
        (seed.codeUnits.fold<int>(0, (a, c) => a * 31 + c) % 360).toDouble();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSLColor.fromAHSL(1, hue, 0.5, 0.4).toColor(),
        HSLColor.fromAHSL(1, (hue + 40) % 360, 0.55, 0.24).toColor(),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Color(0xFF131313)),
      ),
    );
  }
}

class _DaysChip extends StatelessWidget {
  const _DaysChip({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final content = days <= 0
        ? const _ChipWord("AUJOURD'HUI")
        : days == 1
            ? const _ChipWord('DEMAIN')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$days',
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: TtColors.amber)),
                  const Text('JOURS',
                      style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: TtColors.dim)),
                ],
              );
    return Container(
      width: 56,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TtColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TtColors.amber.withValues(alpha: 0.28)),
      ),
      child: content,
    );
  }
}

class _ChipWord extends StatelessWidget {
  const _ChipWord(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: TtColors.amber),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.watched, this.onTap});

  final bool watched;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: watched
              ? const Color(0xFF3E9B4F)
              : Colors.white.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: watched
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Icon(Icons.check,
            color: watched ? Colors.white : TtColors.text, size: 22),
      ),
    );
  }
}
