import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db/database.dart';
import '../providers.dart';
import '../theme.dart';
import '../movies/confirm_removal.dart';
import '../movies/widgets/movie_actions_menu.dart';
import '../widgets/editorial_heading.dart';
import '../widgets/common.dart';
import '../widgets/media_image.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';
import 'movies_screen.dart' show movieMeta;

/// Films vus, du plus récent au plus ancien. Ils quittent la grille
/// principale, qui ne représente que ce qu'il reste à regarder.
class MovieHistoryScreen extends ConsumerWidget {
  const MovieHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(movieFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Films vus'),
        actions: [
          TextButton(
            onPressed: () => context.push('/history'),
            child: const Text('Épisodes vus'),
          ),
        ],
      ),
      body: feedAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 6,
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              children: [
                SkeletonBox(width: 56, height: 84, radius: 10),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 15, radius: 4),
                      SizedBox(height: 7),
                      SkeletonBox(width: 120, height: 12, radius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        error: (e, st) {
          debugPrint('Films vus — chargement impossible : $e\n$st');
          return ErrorRetry(
            title: 'Impossible de charger tes films vus',
            message: 'Tes données sont toujours là. Réessaie dans un instant.',
            onRetry: () => ref.invalidate(moviesProvider),
          );
        },
        data: (feed) {
          if (feed.history.isEmpty) {
            return const EmptyPrompt(
              icon: Icons.check_circle_outline,
              title: 'Aucun film vu pour l\'instant',
              message:
                  'Les films que tu marques comme vus '
                  'apparaîtront ici.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: feed.history.length + 1,
            itemBuilder: (context, i) => i == 0
                ? EditorialHeading(
                    eyebrow: '${feed.history.length} films vus',
                    title: 'Après le générique.',
                  )
                : _WatchedRow(movie: feed.history[i - 1]),
          );
        },
      ),
    );
  }
}

class _WatchedRow extends ConsumerWidget {
  const _WatchedRow({required this.movie});

  final Movie movie;

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await ref.read(databaseProvider).toggleMovieWatched(movie);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('${movie.title} est de retour dans ta liste')),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seenAt = movie.watchedAt;
    return Semantics(
      label: [
        movie.title,
        'film vu',
        if (seenAt != null) 'le ${frenchDate(seenAt)}',
      ].join(', '),
      child: InkWell(
        onTap: () => context.push('/movie/${movie.id}', extra: movie.title),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 84,
                  child: MediaImage(
                    sources: [movie.poster],
                    seed: movie.title,
                    icon: Icons.movie_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: TtColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      movieMeta(movie),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: TtColors.dim,
                      ),
                    ),
                    if (seenAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Vu le ${frenchDate(seenAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: TtColors.dim,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              MovieActionsMenu(
                title: movie.title,
                watched: true,
                onAction: (action) async {
                  try {
                    if (action == MovieAction.remove) {
                      if (!await confirmMovieRemoval(context, movie) ||
                          !context.mounted) {
                        return;
                      }
                      await ref.read(databaseProvider).deleteMovie(movie.id);
                    } else {
                      await _restore(context, ref);
                    }
                  } catch (e, st) {
                    debugPrint('Action historique film impossible : $e\n$st');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Modification impossible. Réessaie.'),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
