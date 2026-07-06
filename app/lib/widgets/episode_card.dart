import 'package:flutter/material.dart';

import '../theme.dart';

/// Carte d'épisode du fil Séries (prochain à voir ou historique).
class EpisodeCard extends StatelessWidget {
  const EpisodeCard({
    super.key,
    required this.showName,
    required this.code,
    required this.stillPath,
    required this.seed,
    this.posterPath,
    this.episodeTitle,
    this.remaining,
    this.badge,
    this.onTap,
    this.onMarkWatched,
    this.history = false,
  });

  final String showName;
  final String code; // "S03 | E02"
  final String? stillPath;

  /// Affiche de la série, utilisée en repli quand l'image d'épisode manque.
  final String? posterPath;
  final String seed; // pour le dégradé de repli (stable par série)
  final String? episodeTitle;
  final int? remaining; // « +N »
  final String? badge; // ex. "PLUS RÉCENT"
  final VoidCallback? onTap;
  final VoidCallback? onMarkWatched;
  final bool history;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 98,
          child: Row(
            children: [
              _Still(path: stillPath, posterPath: posterPath, seed: seed),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ShowPill(name: showName),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2),
                            ),
                          ),
                          if (remaining != null && remaining! > 0) ...[
                            const SizedBox(width: 6),
                            Text('+$remaining',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: TtColors.dim)),
                          ],
                        ],
                      ),
                      if (episodeTitle != null && episodeTitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          episodeTitle!,
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
                child: _CheckButton(
                  history: history,
                  onTap: onMarkWatched,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return history ? Opacity(opacity: 0.55, child: card) : card;
  }
}

class _Still extends StatelessWidget {
  const _Still({required this.path, required this.posterPath, required this.seed});

  final String? path;
  final String? posterPath;
  final String seed;

  @override
  Widget build(BuildContext context) {
    const w = 128.0;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(gradient: _seedGradient(seed)),
      child: const Center(
        child: Icon(Icons.tv, color: Colors.white54, size: 22),
      ),
    );

    // Repli en cascade : still d'épisode → affiche de la série → dégradé.
    Widget imageOr(String url, Widget fallback) => Image.network(
          url,
          width: w,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );

    Widget posterOrPlaceholder() => (posterPath == null || posterPath!.isEmpty)
        ? placeholder
        : imageOr('https://image.tmdb.org/t/p/w300$posterPath', placeholder);

    final Widget child;
    if (path != null && path!.isNotEmpty) {
      child = imageOr(
          'https://image.tmdb.org/t/p/w300$path', posterOrPlaceholder());
    } else {
      child = posterOrPlaceholder();
    }
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

class _ShowPill extends StatelessWidget {
  const _ShowPill({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right, size: 15, color: TtColors.dim),
        ],
      ),
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

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.history, this.onTap});

  final bool history;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (history) {
      return Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
            color: Color(0xFF3E9B4F), shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.white, size: 22),
      );
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: const Icon(Icons.check, color: TtColors.text, size: 22),
      ),
    );
  }
}
