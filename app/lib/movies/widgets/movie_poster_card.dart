import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db/database.dart';
import '../../theme.dart';
import '../../widgets/media_image.dart';

/// Action proposée dans le menu d'une affiche.
enum MovieAction { markWatched, markUnwatched, remove }

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
  final ValueChanged<MovieAction> onAction;

  /// Ouverture de la fiche. Les boutons posés sur l'affiche restent hors de
  /// cette zone, pour qu'un tap dessus ne navigue pas.
  final VoidCallback onTap;

  /// Deuxième ligne sous le titre : durée, année, genre…
  final String? metaLine;

  final bool watched;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: [
        movie.title,
        'film',
        ?metaLine,
        watched ? 'déjà vu' : 'dans ta liste',
      ].join(', '),
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
                  borderRadius: BorderRadius.circular(14),
                  child: MediaImage(
                    sources: [movie.poster],
                    seed: movie.title,
                    icon: Icons.movie_outlined,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: _ActionMenu(
                    watched: watched,
                    title: movie.title,
                    onAction: onAction,
                  ),
                ),
                if (!watched)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: _MarkWatchedButton(
                      title: movie.title,
                      onConfirmed: () => onAction(MovieAction.markWatched),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            // Deux lignes : un titre long ne doit pas être tronqué dès que
            // l'utilisateur agrandit le texte.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: TtColors.text,
            ),
          ),
          if (metaLine != null) ...[
            const SizedBox(height: 2),
            Text(
              metaLine!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: TtColors.dim),
            ),
          ],
        ],
      ),
    );
  }
}

/// Menu « ••• » posé sur l'affiche. Zone tactile de 44 px, comme tout bouton,
/// même si le pictogramme est petit.
class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.watched,
    required this.title,
    required this.onAction,
  });

  final bool watched;
  final String title;
  final ValueChanged<MovieAction> onAction;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MovieAction>(
      tooltip: 'Actions pour $title',
      icon: const Icon(Icons.more_horiz, size: 19, color: Colors.white),
      iconSize: 19,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      color: TtColors.surfaceHi,
      onSelected: (a) {
        HapticFeedback.selectionClick();
        onAction(a);
      },
      itemBuilder: (context) => [
        if (watched)
          const PopupMenuItem(
            value: MovieAction.markUnwatched,
            child: Text('Remettre à voir'),
          )
        else
          const PopupMenuItem(
            value: MovieAction.markWatched,
            child: Text('Marquer comme vu'),
          ),
        const PopupMenuItem(
          value: MovieAction.remove,
          child: Text('Retirer de ma liste'),
        ),
      ],
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
    return Semantics(
      button: true,
      label: 'Marquer ${widget.title} comme vu',
      child: GestureDetector(
        onTap: _tap,
        // Zone tactile de 44 px, alors que la pastille visible en fait 32.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _confirmed
                    ? TtColors.amber
                    : Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _confirmed
                      ? TtColors.amber
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.check,
                size: 18,
                color: _confirmed ? TtColors.bg : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
