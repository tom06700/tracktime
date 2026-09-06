import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../brand/nitrate_brand.dart';
import '../motion.dart';
import '../series/feed.dart';
import '../series/sync.dart';
import '../series/widgets/continue_watching_hero.dart';
import '../series/widgets/series_skeleton.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/media_image.dart';
import '../widgets/modern_controls.dart';
import '../widgets/states.dart';
import '../widgets/press_response.dart';

class ShowsScreen extends ConsumerStatefulWidget {
  const ShowsScreen({super.key});

  @override
  ConsumerState<ShowsScreen> createState() => _ShowsScreenState();
}

/// Synchronise les métadonnées TheTVDB des séries en retard.
Future<SyncOutcome> _sync(WidgetRef ref, {bool force = false}) =>
    syncStaleShows(
      ref.read(databaseProvider),
      ref.read(tvdbClientProvider),
      force: force,
      throttle: () => Future.delayed(const Duration(milliseconds: 120)),
    );

/// Geste « tirer pour rafraîchir » : on force la synchro, sinon le TTL et le
/// cache mémoire du client renverraient exactement ce qui est déjà affiché.
///
/// Aucune invalidation de provider : les listes viennent de flux drift, qui
/// réémettent d'eux-mêmes dès que la synchro écrit. Les invalider ferait
/// clignoter le squelette pour rien.
Future<void> _refresh(BuildContext context, WidgetRef ref) async {
  final outcome = await _sync(ref, force: true);
  if (!context.mounted || !outcome.hasFailures) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      const SnackBar(content: Text('Actualisation impossible pour le moment.')),
    );
}

void _openShow(BuildContext context, int id, String name) =>
    context.push('/show/$id', extra: name);

void _openEpisode(BuildContext context, NextUp n) => context.push(
      '/episode/${n.show.id}/${n.season}/${n.episode}',
      extra: {'name': n.show.name, 'poster': n.show.poster},
    );

Future<void> _markWatched(BuildContext context, WidgetRef ref, NextUp n) async {
  final db = ref.read(databaseProvider);
  await db.setEpisodeWatched(n.show.id, n.season, n.episode);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text('${n.show.name} · épisode enregistré'),
        action: SnackBarAction(
            label: 'Annuler',
            onPressed: () async {
              try {
                await db.setEpisodeUnwatched(n.show.id, n.season, n.episode);
              } catch (_) {
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Annulation impossible. Réessaie.')));
              }
            })));
}

class _ShowsScreenState extends ConsumerState<ShowsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(_tabChanged);
  bool _syncStarted = false;
  void _tabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_syncStarted) {
      _syncStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync(ref));
    }
    // Header and cards share the scroll coordinator. There is no fixed
    // transparent window clipping a featured title underneath the tabs.
    return NestedScrollView(
      key: const ValueKey('series-scroll'),
      headerSliverBuilder: (context, scrolled) => [
        SliverToBoxAdapter(
          child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(children: [
                  Row(children: [
                    const Expanded(child: NitrateWordmark(size: 28)),
                    IconButton(
                        tooltip: 'Mes séries',
                        onPressed: () => context.push('/series'),
                        icon: const Icon(Icons.video_library_outlined)),
                    IconButton(
                        tooltip: 'Réglages',
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings_outlined, size: 21)),
                  ]),
                  const SizedBox(height: 16),
                  GlideControl(
                      labels: const ['À voir', 'À venir'],
                      index: _tabs.index,
                      onSelected: (i) => _tabs.animateTo(i,
                          duration: motionOf(
                              context, const Duration(milliseconds: 300)))),
                ]),
              )),
        )
      ],
      body: TabBarView(
          controller: _tabs, children: const [_ToWatchTab(), _UpcomingTab()]),
    );
  }
}

// ─────────────────────────── Onglet « À voir » ───────────────────────────

class _ToWatchTab extends ConsumerWidget {
  const _ToWatchTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(seriesFeedProvider);

    return feedAsync.when(
      loading: () => const SeriesSkeleton(),
      error: (e, st) {
        debugPrint('Séries — chargement du fil impossible : $e\n$st');
        return ErrorRetry(
          title: 'Impossible de charger tes séries',
          message: 'Tes données sont toujours là. '
              'Réessaie dans un instant.',
          onRetry: () => ref.invalidate(showsProvider),
        );
      },
      data: (feed) {
        if (feed.isEmpty) {
          final hasShows =
              (ref.watch(showsProvider).value ?? const []).isNotEmpty;
          if (hasShows) {
            return EmptyPrompt(
              icon: Icons.check_circle_outline,
              title: 'Tu es à jour',
              message:
                  'Retrouve tes séries dans la bibliothèque ou consulte les prochaines diffusions.',
              actionLabel: 'Mes séries',
              onAction: () => context.push('/series'),
            );
          }
          return _CinemaEmpty(
            onExplore: () =>
                ref.read(homeTabProvider.notifier).select(HomeTab.explorer),
          );
        }
        return _ToWatchFeed(feed: feed);
      },
    );
  }
}

class _ToWatchFeed extends ConsumerStatefulWidget {
  const _ToWatchFeed({required this.feed});

  final SeriesFeed feed;
  @override
  ConsumerState<_ToWatchFeed> createState() => _ToWatchFeedState();
}

class _ToWatchFeedState extends ConsumerState<_ToWatchFeed> {
  NextUp? _holding;
  int? _selectedId;
  bool _confirmed = false;
  Future<void> _mark(NextUp n) async {
    if (_holding != null) return;
    setState(() => _holding = n);
    try {
      await _markWatched(context, ref, n);
      if (!mounted) return;
      setState(() => _confirmed = true);
      await Future<void>.delayed(
          motionOf(context, const Duration(milliseconds: 620)));
    } finally {
      if (mounted)
        setState(() {
          _holding = null;
          _confirmed = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    final queue = [...feed.toWatch, ...feed.stale];
    final selection = queue.indexWhere((n) => n.show.id == _selectedId);
    final selectedIndex = selection < 0 ? 0 : selection;
    final hero = _holding ?? (queue.isEmpty ? null : queue[selectedIndex]);
    final next = queue.length > 1 ? queue : <NextUp>[];
    void select(int index) {
      if (_holding == null)
        setState(() => _selectedId = queue[index % queue.length].show.id);
    }

    return RefreshIndicator(
      color: TtColors.amber,
      backgroundColor: TtColors.surface,
      onRefresh: () => _refresh(context, ref),
      child: ListView(
        key: const PageStorageKey('to-watch-feed'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomNavInset(context)),
        children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('À reprendre.',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -1)),
                    SizedBox(height: 4),
                    Text('Juste un épisode de plus.',
                        style: TextStyle(color: TtColors.dim, fontSize: 13)),
                  ])),
          if (hero != null)
            ContinueWatchingHero(
              // La clé lie l'état de la carte à l'épisode : la validation ne
              // « déteint » pas sur celui qui prend sa place.
              key: ValueKey('${hero.show.id}-${hero.season}-${hero.episode}'),
              next: hero,
              onOpen: () => _openEpisode(context, hero),
              onOpenShow: () =>
                  _openShow(context, hero.show.id, hero.show.name),
              confirmed: _confirmed,
              onMarkWatched: () => _mark(hero),
            ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 32),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Expanded(
                      child: Text('Dans ta rotation',
                          style: TextStyle(color: TtColors.dim))),
                  IconButton(
                      tooltip: 'Œuvre précédente',
                      onPressed: _holding == null
                          ? () => select(selectedIndex - 1)
                          : null,
                      icon: const Icon(Icons.arrow_back)),
                  IconButton(
                      tooltip: 'Œuvre suivante',
                      onPressed: _holding == null
                          ? () => select(selectedIndex + 1)
                          : null,
                      icon: const Icon(Icons.arrow_forward)),
                ])),
            _Carousel(
              height: 205 + (MediaQuery.textScalerOf(context).scale(30) - 30),
              itemCount: next.length,
              separator: 14,
              itemBuilder: (_, i) => _QueuePoster(
                next: next[i],
                onTap: () => select(i),
              ),
            ),
          ],
          if (feed.history.isNotEmpty) ...[
            const SizedBox(height: 32),
            _HistoryLink(),
          ],
        ],
      ),
    );
  }
}

/// Carrousel horizontal paresseux : seules les cartes visibles sont
/// construites, images comprises.
class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    required this.separator,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double separator;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: itemCount,
        separatorBuilder: (_, _) => SizedBox(width: separator),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// Accès secondaire à l'historique. Il ne précède plus le contenu principal :
/// on le consulte quand on le cherche.
class _HistoryLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/history'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.history, size: 20, color: TtColors.dim),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Historique de visionnage',
                    style: TextStyle(
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

// ────────────────────────── Onglet « À venir » ──────────────────────────

class _UpcomingTab extends ConsumerStatefulWidget {
  const _UpcomingTab();

  @override
  ConsumerState<_UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends ConsumerState<_UpcomingTab> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final upcomingAsync = ref.watch(upcomingProvider);

    return upcomingAsync.when(
      loading: () => const SeriesSkeleton(),
      error: (e, st) {
        debugPrint('Séries — chargement des sorties impossible : $e\n$st');
        return ErrorRetry(
          title: 'Impossible de charger les prochaines sorties',
          message: 'Tes données sont toujours là. '
              'Réessaie dans un instant.',
          onRetry: () => ref.invalidate(showsProvider),
        );
      },
      data: (list) {
        if (list.isEmpty) {
          return EmptyPrompt(
            actionLabel: 'Actualiser les dates',
            onAction: () => _refresh(context, ref),
            icon: Icons.event_outlined,
            title: 'Rien d\'annoncé',
            message: 'Ajoute des séries en cours de diffusion — '
                'leurs prochaines dates apparaîtront ici.',
          );
        }

        final now = DateTime.now();
        final groups = groupUpcoming(
          list,
          now,
          laterPerShowLimit: _showAll ? list.length : 3,
        );
        final visibleCount = groups.fold<int>(
          0,
          (n, g) => n + g.episodes.length,
        );
        // Les dates de diffusion bougent : c'est l'onglet où le geste de
        // rafraîchissement a le plus de sens.
        return RefreshIndicator(
          color: TtColors.amber,
          backgroundColor: TtColors.surface,
          onRefresh: () => _refresh(context, ref),
          child: ListView.builder(
            padding: EdgeInsets.only(top: 16, bottom: bottomNavInset(context)),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: groups.length + 1,
            itemBuilder: (context, gi) {
              if (gi == groups.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_showAll || visibleCount < list.length)
                        TextButton(
                          onPressed: () => setState(() => _showAll = !_showAll),
                          child: Text(
                            _showAll
                                ? 'Réduire'
                                : 'Voir les ${list.length} épisodes',
                          ),
                        ),
                      const Text(
                        'Dates annoncées sur les 90 prochains jours.',
                        style: TextStyle(color: TtColors.dim, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }
              final group = groups[gi];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (gi > 0) const SizedBox(height: 26),
                  _SectionHeader(group.bucket.label),
                  for (final u in group.episodes)
                    _UpcomingRow(upcoming: u, now: now),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.upcoming, required this.now});

  final UpcomingEpisode upcoming;
  final DateTime now;

  static const _months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  @override
  Widget build(BuildContext context) {
    final u = upcoming;
    final days = u.daysFrom(now);

    return Semantics(
      button: true,
      label: '${u.show.name}, ${u.code}',
      child: InkWell(
        onTap: () => context.push(
          '/episode/${u.show.id}/${u.season}/${u.episode}',
          extra: {'name': u.show.name, 'poster': u.show.poster},
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 104,
                  height: 59,
                  child: MediaImage(
                    sources: [u.still, u.show.poster],
                    seed: u.show.name,
                    icon: Icons.tv,
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
                      u.show.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: TtColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u.name == null || u.name!.isEmpty
                          ? u.code
                          : '${u.code}  ·  ${u.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: TtColors.dim,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${u.airDate.day} ${_months[u.airDate.month - 1]}',
                      style: const TextStyle(fontSize: 12, color: TtColors.dim),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _DayCounter(days: days),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compteur de jours restants. Il reste discret : c'est une métadonnée, pas
/// l'information principale de la ligne.
class _DayCounter extends StatelessWidget {
  const _DayCounter({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    if (days <= 0) {
      return const Text(
        'Aujourd’hui',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: TtColors.amber,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$days',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            height: 1,
            color: TtColors.amber,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          days > 1 ? 'jours' : 'jour',
          style: const TextStyle(fontSize: 10.5, color: TtColors.dim),
        ),
      ],
    );
  }
}

class _QueuePoster extends StatelessWidget {
  const _QueuePoster({required this.next, required this.onTap});
  final NextUp next;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 112,
        child: Semantics(
          button: true,
          label: '${next.show.name}, ${next.code}',
          child: PressTarget(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    height: 164,
                    width: 112,
                    child: MediaImage(
                      sources: [next.show.poster, next.still],
                      seed: next.show.name,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  next.show.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CinemaEmpty extends StatelessWidget {
  const _CinemaEmpty({required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomNavInset(context)),
        child: Column(
          children: [
            SizedBox(
              height: 290,
              width: double.infinity,
              child: Image.asset(
                'assets/images/empty_cinema.webp',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Text(
                    'Ta liste est vide',
                    textAlign: TextAlign.center,
                    style: NitrateBrand.display(42),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Les histoires restent.\nRetrouve ici celles que tu veux suivre.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: TtColors.dim,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onExplore,
                    icon: const Icon(Icons.add),
                    label: const Text('Explorer les séries'),
                    style: FilledButton.styleFrom(
                      backgroundColor: NitrateBrand.ivory,
                      foregroundColor: NitrateBrand.ink,
                      minimumSize: const Size(double.infinity, 50),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
