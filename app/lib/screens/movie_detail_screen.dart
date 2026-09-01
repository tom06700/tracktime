import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/cinematic.dart';
import '../media/palette.dart';
import '../providers.dart';
import '../theme.dart';
import '../tmdb/media_detail.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';
import 'media_detail_parts.dart';

/// Fiche d'un film. Consultable sans que le film soit dans la bibliothèque :
/// tout vient de TheTVDB, la base locale ne servant qu'à savoir s'il y est
/// déjà.
class MovieDetailScreen extends ConsumerWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.title = ''});

  final int movieId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(movieDetailProvider(movieId));

    // Ni AppBar ni titre collant : le fond occupe le haut de l'écran et le
    // retour flotte par-dessus, posé par la coquille. Le noir Nitrate sert de
    // socle, pour que l'attente ne soit jamais transparente.
    return Scaffold(
      backgroundColor: TtColors.bg,
      body: detail.when(
        loading: () => const MediaDetailSkeleton(),
        error: (e, st) {
          debugPrint('Fiche film $movieId — chargement impossible : $e\n$st');
          return ErrorRetry(
            title: 'Impossible de charger ce film',
            message: 'Vérifie ta connexion et réessaie.',
            onRetry: () => ref.invalidate(movieDetailProvider(movieId)),
          );
        },
        data: (m) => _Content(movie: m),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.movie});

  final MovieDetail movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(moviesProvider).value ?? const [];
    final inLibrary = movies.any((m) => m.id == movie.id);

    final meta = [
      ?movie.year,
      if (movie.runtime != null) fmtTime(movie.runtime!),
      ...movie.genres.take(2),
    ];

    return CinematicDetailShell(
      media: MediaRef(id: movie.id, isSeries: false),
      seed: movie.title,
      backdrop: movie.backdrop,
      poster: movie.poster,
      builder: (context, scope) => CustomScrollView(
        slivers: [
          CinematicBackdrop(
            title: movie.title,
            image: scope.image,
            seed: movie.title,
            icon: Icons.movie_outlined,
            palette: scope.palette,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, bottomNavInset(context)),
            sliver: SliverList.list(
              children: [
                // Le titre n'est pas repris ici : il vit sur le fond. Ne
                // restent que les informations qui l'accompagnaient.
                MediaDetailMeta(
                  metaLine: meta.join(' · '),
                  originalTitle: movie.originalTitle,
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AddToListButton(
                    label: 'Ajouter à ma liste',
                    inLibrary: inLibrary,
                    onAdd: () => addMovieToLibrary(ref, movie.id),
                    failureMessage:
                        'Impossible d\'ajouter ce film.\n'
                        'Réessaie dans un instant.',
                  ),
                ),
                const SizedBox(height: 26),
                const MediaSectionTitle('Synopsis'),
                const SizedBox(height: 8),
                if (movie.overview case final text?)
                  ExpandableSynopsis(text: text, accent: scope.palette.accent)
                else
                  const Text(
                    'Synopsis indisponible.',
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      color: TtColors.dim,
                    ),
                  ),
                if (movie.releaseDate != null) ...[
                  const SizedBox(height: 22),
                  MediaFactRow(
                    label: 'Sortie',
                    value: frenchDate(movie.releaseDate!),
                  ),
                ],
                if (movie.director != null)
                  MediaFactRow(label: 'Réalisation', value: movie.director!),
                if (movie.studio != null)
                  MediaFactRow(label: 'Studio', value: movie.studio!),
                if (movie.cast.isNotEmpty)
                  MediaFactRow(
                    label: 'Avec',
                    value: movie.cast.take(4).join(', '),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Silhouette de fiche : en-tête, titre, action, synopsis.
class MediaDetailSkeleton extends StatelessWidget {
  const MediaDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SkeletonBox(height: 230, radius: 0),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 26, radius: 6),
              SizedBox(height: 10),
              SkeletonBox(width: 200, height: 14, radius: 4),
              SizedBox(height: 20),
              SkeletonBox(width: 190, height: 46, radius: 12),
              SizedBox(height: 28),
              SkeletonBox(height: 14, radius: 4),
              SizedBox(height: 8),
              SkeletonBox(height: 14, radius: 4),
              SizedBox(height: 8),
              SkeletonBox(width: 240, height: 14, radius: 4),
            ],
          ),
        ),
      ],
    );
  }
}
