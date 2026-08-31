import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion.dart';
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
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

    return MediaEntrance(
      child: ListView(
        padding: EdgeInsets.only(bottom: bottomNavInset(context)),
        children: [
          MediaDetailHeader(
            backdrop: movie.backdrop,
            poster: movie.poster,
            seed: movie.title,
            icon: Icons.movie_outlined,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MediaDetailTitle(
                  title: movie.title,
                  originalTitle: movie.originalTitle,
                  metaLine: meta.join(' · '),
                ),
                const SizedBox(height: 18),
                AddToListButton(
                  label: 'Ajouter à ma liste',
                  inLibrary: inLibrary,
                  onAdd: () => addMovieToLibrary(ref, movie.id),
                  failureMessage:
                      'Impossible d\'ajouter ce film.\n'
                      'Réessaie dans un instant.',
                ),
                const SizedBox(height: 26),
                const MediaSectionTitle('Synopsis'),
                const SizedBox(height: 8),
                Text(
                  movie.overview ?? 'Synopsis indisponible.',
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.65,
                    color: TtColors.text,
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
