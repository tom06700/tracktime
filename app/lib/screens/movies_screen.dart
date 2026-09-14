import 'dart:async';
import '../movies/confirm_removal.dart';
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
import '../widgets/portal/portal_empty.dart';
import '../widgets/portal/portal_preview_scope.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/collection_screen_header.dart';
import '../widgets/films_seen_button.dart';
import '../widgets/common.dart';
import '../widgets/media_image.dart';
import '../widgets/bounded_refresh_indicator.dart';
import '../widgets/collection_layout_transition.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';
import '../widgets/nitrate_banner.dart';

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
          Builder(
            builder: (context) {
              final tabs = DefaultTabController.of(context);
              return AnimatedBuilder(
                animation: tabs,
                builder: (context, _) => CollectionScreenHeader(
                  collectionButton: FilmsSeenButton(
                    onPressed: () => context.push('/movie-history'),
                  ),
                  labels: const ['Ma liste', 'Sorties'],
                  index: tabs.index,
                  onSelected: (i) => tabs.animateTo(
                    i,
                    duration: motionOf(
                      context,
                      const Duration(milliseconds: 300),
                    ),
                  ),
                ),
              );
            },
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
    if (PortalPreviewScope.enabled(context)) {
      return PortalEmpty(
        movies: true,
        onExplore: () =>
            ref.read(homeTabProvider.notifier).select(HomeTab.explorer),
      );
    }
    final feedAsync = ref.watch(movieFeedProvider);

    return feedAsync.when(
      loading: () => const _GridSkeleton(withHeading: true),
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
          return PortalEmpty(
            movies: true,
            onExplore: () =>
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

class _LibraryGrid extends ConsumerStatefulWidget {
  const _LibraryGrid({required this.library, required this.watchedCount});

  final List<Movie> library;
  final int watchedCount;

  @override
  ConsumerState<_LibraryGrid> createState() => _LibraryGridState();
}

class _LibraryGridState extends ConsumerState<_LibraryGrid> {
  final _held = <int, (Movie, int)>{};
  final _release = <int, Timer>{};

  Future<void> _markWithFeedback(Movie movie, int index) async {
    if (_held.containsKey(movie.id)) return;
    final pause = motionOf(context, const Duration(milliseconds: 550));
    setState(() => _held[movie.id] = (movie, index));
    try {
      await ref.read(databaseProvider).toggleMovieWatched(movie);
      if (!mounted) return;
      if (pause == Duration.zero) {
        setState(() => _held.remove(movie.id));
      } else {
        _release[movie.id] = Timer(pause, () {
          _release.remove(movie.id);
          if (mounted) setState(() => _held.remove(movie.id));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _held.remove(movie.id));
      rethrow;
    }
  }

  @override
  void dispose() {
    for (final timer in _release.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final library = [...widget.library];
    final held = _held.values.toList()..sort((a, b) => a.$2.compareTo(b.$2));
    for (final entry in held) {
      if (!library.any((movie) => movie.id == entry.$1.id)) {
        library.insert(entry.$2.clamp(0, library.length), entry.$1);
      }
    }
    final watchedCount = widget.watchedCount;

    Future<void> act(Movie m, MovieAction a) async {
      if (_held.containsKey(m.id)) return;
      HapticFeedback.lightImpact();
      try {
        switch (a) {
          case MovieAction.markWatched:
          case MovieAction.markUnwatched:
            await db.toggleMovieWatched(m);
          case MovieAction.remove:
            if (!await confirmMovieRemoval(context, m) || !context.mounted) {
              return;
            }
            await db.deleteMovie(m.id);
        }
      } catch (error, stack) {
        debugPrint('Action film impossible : $error\n$stack');
        if (!context.mounted) return;
        NitrateMessenger.of(context).showBanner(
          const NitrateBanner(
            kind: NitrateBannerKind.error,
            content: Text('Modification impossible. Réessaie.'),
          ),
        );
      }
    }

    return CollectionLayoutTransition(
      motion: CollectionMotion.films,
      builder: (context, compact) => BoundedRefreshIndicator(
        onRefresh: () => _sync(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _LibraryHeading(count: library.length)),
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final scaler = MediaQuery.textScalerOf(context);
                    final columns = scaler.scale(14) > 21
                        ? 1
                        : compact && scaler.scale(14) <= 17
                        ? 3
                        : 2;
                    final width =
                        (constraints.crossAxisExtent - 13 * (columns - 1)) /
                        columns;
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 13,
                        mainAxisSpacing: 22,
                        mainAxisExtent: MoviePosterCard.heightFor(
                          width,
                          scaler,
                        ),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final m = library[i];
                          // Keep action state tied to the movie when columns change.
                          return MoviePosterCard(
                            key: ValueKey(m.id),
                            movie: m,
                            metaLine: movieMeta(m),
                            onTap: () =>
                                context.push('/movie/${m.id}', extra: m.title),
                            onAction: (a) => act(m, a),
                            onMarkWatched: () => _markWithFeedback(m, i),
                            actionsEnabled: !_held.containsKey(m.id),
                          );
                        },
                        childCount: library.length,
                        findChildIndexCallback: (key) {
                          if (key is! ValueKey<int>) return null;
                          final index = library.indexWhere(
                            (movie) => movie.id == key.value,
                          );
                          return index < 0 ? null : index;
                        },
                      ),
                    );
                  },
                ),
              ),
            if (watchedCount > 0)
              SliverToBoxAdapter(child: _WatchedLink(count: watchedCount)),
            SliverToBoxAdapter(
              child: SizedBox(height: bottomNavInset(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryHeading extends StatelessWidget {
  const _LibraryHeading({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ta prochaine séance.',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count == 0
                    ? 'Ta liste est à jour.'
                    : '$count ${count == 1 ? 'film à découvrir' : 'films à découvrir'}.',
                style: const TextStyle(color: TtColors.dim, fontSize: 13),
              ),
            ],
          ),
        ),
        if (count > 0) const CollectionLayoutToggle(),
      ],
    ),
  );
}

class _WatchedLink extends StatelessWidget {
  const _WatchedLink({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
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
  const _GridSkeleton({this.withHeading = false});
  final bool withHeading;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        if (withHeading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: 220,
                    height: scaler.scale(23) * 1.2,
                    radius: 5,
                  ),
                  const SizedBox(height: 4),
                  SkeletonBox(
                    width: 132,
                    height: scaler.scale(13) * 1.2,
                    radius: 4,
                  ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = scaler.scale(14) > 21 ? 1 : 2;
              final width =
                  (constraints.crossAxisExtent - 13 * (columns - 1)) / columns;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 13,
                  mainAxisSpacing: 22,
                  mainAxisExtent: MoviePosterCard.heightFor(width, scaler),
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AspectRatio(
                        aspectRatio: 2 / 3,
                        child: SkeletonBox(radius: 18),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: scaler.scale(14.5) * 1.3 * 2,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SkeletonBox(
                            height: scaler.scale(14.5),
                            radius: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SkeletonBox(
                        width: width * .7,
                        height: scaler.scale(12),
                        radius: 4,
                      ),
                    ],
                  ),
                  childCount: 6,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
