import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db/database.dart';
import '../movies/sync.dart';
import '../movies/feed.dart';
import '../movies/widgets/movie_poster_card.dart';
import '../motion.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/media_image.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';

/// Deuxième ligne d'une affiche : durée, genre, et l'année quand elle apporte
/// quelque chose.
String movieMeta(Movie m, {bool includeYear = true}) {
  final parts = <String>[];
  if (includeYear && m.releaseDate != null) parts.add('${m.releaseDate!.year}');
  parts.add(fmtTime(m.runtime));
  final genre = (m.genres ?? '')
      .split('|')
      .map((g) => g.trim())
      .firstWhere((g) => g.isNotEmpty, orElse: () => '');
  if (genre.isNotEmpty) parts.add(genre);
  return parts.join(' · ');
}

Future<void> _sync(WidgetRef ref) => backfillMovieMeta(
  ref.read(databaseProvider),
  ref.read(tvdbClientProvider),
  throttle: () => Future.delayed(const Duration(milliseconds: 120)),
);

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  bool _syncStarted = false;

  @override
  Widget build(BuildContext context) {
    // Rattrape genres + dates de sortie (pour peupler « Sorties »).
    if (!_syncStarted) {
      _syncStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync(ref));
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: TtColors.amber,
            unselectedLabelColor: TtColors.dim,
            indicatorColor: TtColors.amber,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: 'Ma liste'),
              Tab(text: 'Sorties'),
            ],
          ),
          const Expanded(
            child: TabBarView(children: [_LibraryTab(), _ReleasesTab()]),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Onglet « Ma liste » ──────────────────────────

class _LibraryTab extends ConsumerWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(movieFeedProvider);

    return feedAsync.when(
      loading: () => const _GridSkeleton(),
      error: (e, st) {
        debugPrint('Films — chargement impossible : $e\n$st');
        return ErrorRetry(
          title: 'Impossible de charger tes films',
          message: 'Tes données sont toujours là. Réessaie dans un instant.',
          onRetry: () => ref.invalidate(moviesProvider),
        );
      },
      data: (feed) {
        // La collection, c'est la watchlist : les films vus la quittent pour
        // leur page dédiée au lieu d'être grisés au milieu des autres.
        final library = [...feed.toWatch, ...feed.stale];
        if (library.isEmpty && feed.history.isEmpty) {
          return EmptyPrompt(
            icon: Icons.movie_outlined,
            title: 'Aucun film dans ta liste',
            message:
                'Ajoute les films que tu veux voir '
                'et retrouve-les ici.',
            actionLabel: 'Explorer les films',
            onAction: () =>
                ref.read(homeTabProvider.notifier).select(HomeTab.explorer),
          );
        }
        return _LibraryGrid(
          library: library,
          watchedCount: feed.history.length,
        );
      },
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  const _LibraryGrid({required this.library, required this.watchedCount});

  final List<Movie> library;
  final int watchedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);

    Future<void> act(Movie m, MovieAction a) async {
      HapticFeedback.lightImpact();
      switch (a) {
        case MovieAction.markWatched:
        case MovieAction.markUnwatched:
          await db.toggleMovieWatched(m);
        case MovieAction.remove:
          await db.deleteMovie(m.id);
      }
    }

    return RefreshIndicator(
      color: TtColors.amber,
      backgroundColor: TtColors.surface,
      onRefresh: () async {
        await _sync(ref);
        ref.invalidate(moviesProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (library.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Text(
                  'Tous tes films sont vus.\n'
                  'Ajoute-en de nouveaux pour remplir ta liste.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: TtColors.dim,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 13,
                  mainAxisSpacing: 20,
                  // Affiche 2:3 plus deux lignes de texte.
                  childAspectRatio: 0.52,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final m = library[i];
                  // Apparition échelonnée sur les toutes premières affiches
                  // seulement : au-delà, la cascade se verrait plus que la
                  // grille. Le décalage total reste sous 150 ms.
                  return EntranceFade(
                    // La clé lie la carte au film, pas à sa position : quand
                    // un film vu quitte la grille, le suivant prend sa place
                    // sans hériter de l'état de son bouton « vu ».
                    key: ValueKey(m.id),
                    delay: Motion.staggerAt(i),
                    child: MoviePosterCard(
                      movie: m,
                      metaLine: movieMeta(m),
                      onTap: () =>
                          context.push('/movie/${m.id}', extra: m.title),
                      onAction: (a) => act(m, a),
                    ),
                  );
                }, childCount: library.length),
              ),
            ),
          if (watchedCount > 0)
            SliverToBoxAdapter(child: _WatchedLink(count: watchedCount)),
          SliverToBoxAdapter(child: SizedBox(height: bottomNavInset(context))),
        ],
      ),
    );
  }
}

class _WatchedLink extends StatelessWidget {
  const _WatchedLink({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/movie-history'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: TtColors.dim,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Films vus ($count)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: TtColors.text,
                    ),
                  ),
                ),
                const Text(
                  'Voir tout',
                  style: TextStyle(fontSize: 13.5, color: TtColors.amber),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: TtColors.amber,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Onglet « Sorties » ──────────────────────────

class _ReleasesTab extends ConsumerWidget {
  const _ReleasesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingMoviesProvider);

    return upcomingAsync.when(
      loading: () => const _GridSkeleton(),
      error: (e, st) {
        debugPrint('Films — sorties indisponibles : $e\n$st');
        return ErrorRetry(
          title: 'Impossible de charger les sorties',
          message: 'Tes données sont toujours là. Réessaie dans un instant.',
          onRetry: () => ref.invalidate(moviesProvider),
        );
      },
      data: (list) {
        if (list.isEmpty) {
          return const EmptyPrompt(
            icon: Icons.event_outlined,
            title: 'Aucune sortie annoncée',
            message:
                'Ajoute des films pas encore sortis — '
                'leur date apparaîtra ici.',
          );
        }
        final groups = groupReleasesByMonth(list);
        final now = DateTime.now();
        return ListView.builder(
          padding: EdgeInsets.only(top: 16, bottom: bottomNavInset(context)),
          itemCount: groups.length,
          itemBuilder: (context, gi) {
            final g = groups[gi];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (gi > 0) const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    g.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: TtColors.dim,
                    ),
                  ),
                ),
                for (final u in g.movies) _ReleaseRow(upcoming: u, now: now),
              ],
            );
          },
        );
      },
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.upcoming, required this.now});

  final UpcomingMovie upcoming;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final m = upcoming.movie;
    final days = DateTime(
      upcoming.releaseDate.year,
      upcoming.releaseDate.month,
      upcoming.releaseDate.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    return Semantics(
      button: true,
      label: '${m.title}, sortie le ${frenchDate(upcoming.releaseDate)}',
      child: InkWell(
        onTap: () => context.push('/movie/${m.id}', extra: m.title),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 84,
                  child: MediaImage(
                    sources: [m.poster],
                    seed: m.title,
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
                      m.title,
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
                      frenchDate(upcoming.releaseDate),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: TtColors.dim,
                      ),
                    ),
                    if (days > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        days == 1 ? 'demain' : 'dans $days jours',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: TtColors.amber,
                        ),
                      ),
                    ],
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

/// Silhouette de la grille pendant le chargement.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 13,
        mainAxisSpacing: 20,
        childAspectRatio: 0.52,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SkeletonBox(radius: 14)),
          SizedBox(height: 8),
          SkeletonBox(height: 14, radius: 4),
          SizedBox(height: 6),
          SkeletonBox(width: 80, height: 11, radius: 4),
        ],
      ),
    );
  }
}
