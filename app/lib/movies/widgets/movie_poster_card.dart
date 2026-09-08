import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db/database.dart';
import '../../theme.dart';
import '../../widgets/media_image.dart';

import 'movie_actions_menu.dart';
export 'movie_actions_menu.dart' show MovieAction;

/// Affiche d'un film dans la grille. L'image porte la carte ; les actions
/// secondaires vivent dans un menu, pour ne pas parsemer la grille de boutons.
class MoviePosterCard extends StatelessWidget {
  const MoviePosterCard({
    super.key,
    required this.movie,
    required this.onAction,
    required this.onTap,
    this.metaLine,
    this.watched = false,
  });

  final Movie movie;
  final FutureOr<void> Function(MovieAction) onAction;

  /// Ouverture de la fiche. Les boutons posés sur l'affiche restent hors de
  /// cette zone, pour qu'un tap dessus ne navigue pas.
  final VoidCallback onTap;

  /// Deuxième ligne sous le titre : durée, année, genre…
  final String? metaLine;

  final bool watched;

  /// Reserve two lines for both title and metadata, including larger text.
  static double heightFor(double width, TextScaler scaler) =>
      width * 1.5 +
      10 +
      scaler.scale(14.5) * 1.3 * 2 +
      4 +
      scaler.scale(12) * 1.4 * 2;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      button: true,
      label: [
        movie.title,
        'film',
        ?metaLine,
        watched ? 'déjà vu' : 'dans ta liste',
      ].join(', '),
      // Toute la carte ouvre la fiche. Les deux boutons posés sur l'affiche
      // sont plus profonds dans l'arbre : leur détecteur remporte l'arène
      // avant celui-ci, donc un tap dessus n'ouvre pas la fiche.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: MediaImage(
                      sources: [movie.poster],
                      seed: movie.title,
                      icon: Icons.movie_outlined,
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0x24FFFFFF)),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Color(0x66080B13),
                          ],
                          stops: [0, .6, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: MovieActionsMenu(
                      watched: watched,
                      title: movie.title,
                      onAction: onAction,
                    ),
                  ),
                  if (!watched)
                    Positioned(
                      left: 8,
                      bottom: 6,
                      child: _MarkWatchedButton(
                        title: movie.title,
                        onConfirmed: () => onAction(MovieAction.markWatched),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: scaler.scale(14.5) * 1.3 * 2,
              child: Text(
                movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  letterSpacing: -.25,
                  color: TtColors.text,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: scaler.scale(12) * 1.4 * 2,
              child: Text(
                metaLine ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: TtColors.dim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton « vu » posé sur l'affiche. La coche se remplit puis le film quitte
/// la grille — l'action principale tient en un geste, sans passer par le menu.
class _MarkWatchedButton extends StatefulWidget {
  const _MarkWatchedButton({required this.title, required this.onConfirmed});

  final String title;
  final VoidCallback onConfirmed;

  @override
  State<_MarkWatchedButton> createState() => _MarkWatchedButtonState();
}

class _MarkWatchedButtonState extends State<_MarkWatchedButton> {
  bool _confirmed = false;

  Future<void> _tap() async {
    if (_confirmed) return;
    HapticFeedback.lightImpact();
    setState(() => _confirmed = true);

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduceMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
    }
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Tooltip(
      message: 'Marquer comme vu',
      excludeFromSemantics: true,
      child: Semantics(
        label: 'Marquer ${widget.title} comme vu',
        child: TextButton(
          // Keep consuming taps during confirmation so they cannot open the
          // parent card. _tap already ignores repeated confirmations.
          onPressed: _tap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(72, 44),
          ),
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _confirmed ? TtColors.amber : const Color(0xE61A1B25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _confirmed ? TtColors.amber : const Color(0x66D6CBE5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check,
                    size: 16,
                    color: _confirmed ? TtColors.bg : const Color(0xFFE5D9F6),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Vu',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: _confirmed ? TtColors.bg : const Color(0xFFF2EDF7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
