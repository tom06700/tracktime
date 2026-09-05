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
import '../widgets/states.dart';

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

Future<void> _markWatched(WidgetRef ref, NextUp n) => ref
    .read(databaseProvider)
    .setEpisodeWatched(n.show.id, n.season, n.episode);

class _ShowsScreenState extends ConsumerState<ShowsScreen> {
  bool _syncStarted = false;
  final _scroll = ValueNotifier<double>(0);
  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // Lance la synchro TheTVDB au montage (la clé est embarquée).
    if (!_syncStarted) {
      _syncStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync(ref));
    }

    final feed = ref.watch(seriesFeedProvider).value;
    final queue = [...?feed?.toWatch, ...?feed?.stale];
    final featured = queue.isEmpty ? null : queue.first;
    final detail = featured == null ? null : ref.watch(seriesDetailProvider(featured.show.id)).value;
    return DefaultTabController(
      length: 2,
      child: Stack(children: [
        Positioned(top: 0, left: 0, right: 0,
          child: IgnorePointer(child: SizedBox(
            height: MediaQuery.paddingOf(context).top + 590,
            child: AnimatedBuilder(animation: _scroll, builder: (context, _) {
              final offset = reduceMotionOf(context) ? 0.0 : _scroll.value.clamp(0.0, 500.0) * .18;
              return Transform.translate(offset: Offset(0, -offset), child: Stack(fit: StackFit.expand, children: [
                if (featured != null)
                  AnimatedSwitcher(duration: motionOf(context, Motion.ambient),
                    child: SizedBox.expand(key: ValueKey(featured.show.id), child: MediaImage(
                      sources: [detail?.backdrop, featured.still, featured.show.poster], seed: featured.show.name))),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0x44080C0B), Color(0x11080C0B), Color(0xDD080C0B), NitrateBrand.ink],
                  stops: [0, .28, .72, 1]))),
              ]));
            }),
          ))),
        Column(children: [
          SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 4),
            child: Row(children: [
              const Expanded(child: NitrateWordmark()),
              IconButton(tooltip: 'Mes séries', onPressed: () => context.push('/series'),
                icon: const Icon(Icons.video_library_outlined)),
              IconButton(tooltip: 'Réglages', onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined, size: 21)),
            ]),
          )),
          Align(alignment: Alignment.centerLeft, child: TabBar(
            isScrollable: true, tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.only(left: 8), labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            labelColor: NitrateBrand.ivory, unselectedLabelColor: TtColors.dim,
            indicatorColor: NitrateBrand.ivory, indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label, dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'À voir'), Tab(text: 'À venir')],
          )),
          Expanded(child: TabBarView(children: [
            NotificationListener<ScrollNotification>(onNotification: (n) {
              if (n.depth == 0 && n.metrics.axis == Axis.vertical) _scroll.value = n.metrics.pixels;
              return false;
            }, child: const _ToWatchTab()),
            const ColoredBox(color: NitrateBrand.ink, child: _UpcomingTab()),
          ])),
        ]),
      ]),
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
          message:
              'Tes données sont toujours là. '
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
          return _CinemaEmpty(onExplore: () =>
            ref.read(homeTabProvider.notifier).select(HomeTab.explorer));
        }
        return _ToWatchFeed(feed: feed);
      },
    );
  }
}

class _ToWatchFeed extends ConsumerWidget {
  const _ToWatchFeed({required this.feed});

  final SeriesFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = [...feed.toWatch, ...feed.stale];
    final hero = queue.isEmpty ? null : queue.first;
    final next = queue.skip(1).toList();

    return RefreshIndicator(
      color: TtColors.amber,
      backgroundColor: TtColors.surface,
      onRefresh: () => _refresh(context, ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomNavInset(context)),
        children: [
          if (hero != null)
            ContinueWatchingHero(
              // La clé lie l'état de la carte à l'épisode : la validation ne
              // « déteint » pas sur celui qui prend sa place.
              key: ValueKey('${hero.show.id}-${hero.season}-${hero.episode}'),
              next: hero,
              onOpen: () => _openEpisode(context, hero),
              onOpenShow: () =>
                  _openShow(context, hero.show.id, hero.show.name),
              onMarkWatched: () => _markWatched(ref, hero),
            ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 30),
            const _SectionHeader(
              'Dans ta liste',
            ),
            _Carousel(
              height: 205 + (MediaQuery.textScalerOf(context).scale(30) - 30),
              itemCount: next.length,
              separator: 14,
              itemBuilder: (_, i) => _QueuePoster(
                next: next[i],
                onTap: () => _openEpisode(context, next[i]),
              ),
            ),
          ],
          if (feed.history.isNotEmpty) ...[
            const SizedBox(height: 30),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: -.6,
                    fontWeight: FontWeight.w700,
                    color: TtColors.text,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: TtColors.dim,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
          message:
              'Tes données sont toujours là. '
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
            message:
                'Ajoute des séries en cours de diffusion — '
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
  Widget build(BuildContext context) => SizedBox(width: 112, child: Semantics(
    button: true, label: '${next.show.name}, ${next.code}',
    child: GestureDetector(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: BorderRadius.circular(9), child: SizedBox(height: 164, width: 112,
        child: MediaImage(sources: [next.show.poster, next.still], seed: next.show.name))),
      const SizedBox(height: 8),
      Text(next.show.name, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ])),
  ));
}

class _CinemaEmpty extends StatelessWidget {
  const _CinemaEmpty({required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.only(bottom: bottomNavInset(context)),
    child: Column(children: [
      SizedBox(height: 290, width: double.infinity,
        child: Image.asset('assets/images/empty_cinema.webp', fit: BoxFit.cover, alignment: Alignment.topCenter)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: Column(children: [
        Text('Ta liste est vide', textAlign: TextAlign.center, style: NitrateBrand.display(42)),
        const SizedBox(height: 12),
        const Text('Les histoires restent.
Retrouve ici celles que tu veux suivre.', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: TtColors.dim)),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: onExplore, icon: const Icon(Icons.add), label: const Text('Explorer les séries'),
          style: FilledButton.styleFrom(backgroundColor: NitrateBrand.ivory, foregroundColor: NitrateBrand.ink,
            minimumSize: const Size(double.infinity, 50), shape: const StadiumBorder())),
      ])),
    ]),
  );
}
