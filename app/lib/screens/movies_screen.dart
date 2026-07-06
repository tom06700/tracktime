import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

class MoviesScreen extends ConsumerWidget {
  const MoviesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(moviesProvider);
    return movies.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.error_outline, message: '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.movie_outlined,
            message:
                "Aucun film pour l'instant.\nAjoute-en via la recherche ou importe ton export TV Time.",
          );
        }
        final watchlist = list.where((m) => m.watchedAt == null).toList();
        final seen = list.where((m) => m.watchedAt != null).toList();
        return ListView(
          padding: EdgeInsets.only(bottom: bottomNavInset(context)),
          children: [
            if (watchlist.isNotEmpty) const SectionLabel('À voir'),
            ...watchlist.map((m) => _MovieCard(m)),
            if (seen.isNotEmpty) SectionLabel('Vus (${seen.length})'),
            ...seen.map((m) => _MovieCard(m)),
          ],
        );
      },
    );
  }
}

class _MovieCard extends ConsumerWidget {
  const _MovieCard(this.movie);

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final seen = movie.watchedAt != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PosterBox(
                posterPath: movie.poster,
                fallbackIcon: Icons.movie_outlined,
                small: true),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: seen ? TtColors.dim : TtColors.text,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                seen ? Icons.check_circle : Icons.circle_outlined,
                color: seen ? TtColors.teal : TtColors.dim,
              ),
              onPressed: () => db.toggleMovieWatched(movie),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: TtColors.dim),
              onPressed: () => db.deleteMovie(movie.id),
            ),
          ],
        ),
      ),
    );
  }
}
