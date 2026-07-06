import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../series/feed.dart';
import '../series/sync.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/episode_card.dart';

class ShowsScreen extends ConsumerStatefulWidget {
  const ShowsScreen({super.key});

  @override
  ConsumerState<ShowsScreen> createState() => _ShowsScreenState();
}

class _ShowsScreenState extends ConsumerState<ShowsScreen> {
  bool _syncStarted = false;

  Future<void> _sync() async {
    await syncStaleShows(
      ref.read(databaseProvider),
      ref.read(tmdbClientProvider),
      throttle: () => Future.delayed(const Duration(milliseconds: 120)),
    );
  }

  void _openShow(int id, String name) {
    context.push('/show/$id', extra: name);
  }

  void _openEpisode(int showId, String showName, int season, int episode,
      String? poster) {
    context.push(
      '/episode/$showId/$season/$episode',
      extra: {'name': showName, 'poster': poster},
    );
  }

  void _markWatched(NextUp n) {
    HapticFeedback.lightImpact();
    ref.read(databaseProvider).setEpisodeWatched(n.show.id, n.season, n.episode);
  }

  @override
  Widget build(BuildContext context) {
    // Lance la synchro TMDB dès que la clé API est réellement chargée
    // (SharedPreferences est asynchrone : au montage, elle est souvent encore
    // vide, d'où l'onglet « À venir » resté vide sans ce déclenchement tardif).
    final key = ref.watch(tmdbKeyProvider).value;
    if (!_syncStarted && key != null && key.isNotEmpty) {
      _syncStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
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
            labelStyle: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
            tabs: [
              Tab(text: 'À VOIR'),
              Tab(text: 'À VENIR'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildToWatch(context),
                _buildUpcoming(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToWatch(BuildContext context) {
    final feedAsync = ref.watch(seriesFeedProvider);
    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.error_outline, message: '$e'),
      data: (feed) {
        if (feed.isEmpty) {
          return const EmptyState(
            icon: Icons.tv,
            message:
                "Aucune série pour l'instant.\nAjoute-en via Explorer ou importe ton export TV Time.",
          );
        }

        Widget historyCard(HistoryEntry h) => EpisodeCard(
              history: true,
              showName: h.show.name,
              code: h.code,
              stillPath: h.still,
              posterPath: h.show.poster,
              seed: h.show.name,
              episodeTitle: h.episodeName,
              onTap: () => _openEpisode(
                  h.show.id, h.show.name, h.season, h.episode, h.show.poster),
              onShowTap: () => _openShow(h.show.id, h.show.name),
            );

        final toWatchCards = [
          for (var i = 0; i < feed.toWatch.length; i++)
            _card(feed.toWatch[i], badge: i == 0 ? 'PLUS RÉCENT' : null),
        ];
        final staleCards = [for (final n in feed.stale) _card(n)];
        final historyCards = feed.history.map(historyCard).toList();

        final hasBelow = toWatchCards.isNotEmpty || staleCards.isNotEmpty;

        // Tout est à jour (rien « à voir ») : simple liste de l'historique.
        if (!hasBelow) {
          return ListView(
            padding: EdgeInsets.only(bottom: bottomNavInset(context)),
            children: [
              if (historyCards.isNotEmpty)
                _pillSection('Historique de visionnage', historyCards),
            ],
          );
        }

        // Sections « à voir » / délaissées : en-tête collant (pastille centrée
        // qui reste en tête et glisse avec la catégorie), contenu défilant
        // dessous. Le centre du scroll = la 1re pastille collante (l'onglet
        // s'ouvre au niveau « À voir »).
        const centerKey = ValueKey('to-watch-center');
        final belowSlivers = <Widget>[];
        var centerAssigned = false;
        void addSection(String label, List<Widget> cards) {
          belowSlivers.add(SliverPersistentHeader(
            key: centerAssigned ? null : centerKey,
            pinned: true,
            delegate: _StickyPillHeader(label),
          ));
          centerAssigned = true;
          belowSlivers.add(SliverList.list(children: cards));
        }

        if (toWatchCards.isNotEmpty) addSection('À voir', toWatchCards);
        if (staleCards.isNotEmpty) {
          addSection('Pas regardé depuis un moment', staleCards);
        }

        return CustomScrollView(
          center: centerKey,
          slivers: [
            // Historique au-dessus (scroll vers le haut) ; pastille non
            // collante. Inversé pour coller le plus récent au « À voir ».
            SliverList.list(children: [
              if (historyCards.isNotEmpty)
                _pillSection('Historique de visionnage',
                    historyCards.reversed.toList()),
            ]),
            ...belowSlivers,
            SliverToBoxAdapter(
                child: SizedBox(height: bottomNavInset(context))),
          ],
        );
      },
    );
  }

  /// Section non collante = capsule grise centrée qui chevauche la 1re carte
  /// (utilisée pour l'historique, au-dessus du centre).
  Widget _pillSection(String label, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: cards.first,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: SectionPill(label)),
            ),
          ],
        ),
        ...cards.skip(1),
      ],
    );
  }

  Widget _buildUpcoming(BuildContext context) {
    final upcomingAsync = ref.watch(upcomingProvider);
    return upcomingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.error_outline, message: '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.event_outlined,
            message:
                'Aucun épisode à venir connu.\nAjoute des séries en cours de diffusion — leurs prochaines dates apparaîtront ici.',
          );
        }
        final now = DateTime.now();
        return ListView.builder(
          padding: EdgeInsets.only(top: 8, bottom: bottomNavInset(context)),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final u = list[i];
            return EpisodeCard(
              showName: u.show.name,
              code: u.code,
              stillPath: u.still,
              posterPath: u.show.poster,
              seed: u.show.name,
              episodeTitle: u.name ?? _formatDate(u.airDate),
              upcomingInDays: u.daysFrom(now),
              onTap: () => _openEpisode(
                  u.show.id, u.show.name, u.season, u.episode, u.show.poster),
              onShowTap: () => _openShow(u.show.id, u.show.name),
            );
          },
        );
      },
    );
  }

  static const _months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.',
    'août', 'sept.', 'oct.', 'nov.', 'déc.'
  ];

  static String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  Widget _card(NextUp n, {String? badge}) {
    return EpisodeCard(
      showName: n.show.name,
      code: n.code,
      stillPath: n.still,
      posterPath: n.show.poster,
      seed: n.show.name,
      episodeTitle: n.episodeName,
      remaining: n.remaining,
      badge: badge,
      onTap: () => _openEpisode(
          n.show.id, n.show.name, n.season, n.episode, n.show.poster),
      onShowTap: () => _openShow(n.show.id, n.show.name),
      onMarkWatched: () => _markWatched(n),
    );
  }
}

/// En-tête de section collant : bande transparente avec la capsule centrée.
/// Épinglée en haut, le contenu défile dessous et la pastille suit la
/// catégorie (poussée par la suivante).
class _StickyPillHeader extends SliverPersistentHeaderDelegate {
  const _StickyPillHeader(this.label);

  final String label;
  static const double _height = 46;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Center(child: SectionPill(label));
  }

  @override
  bool shouldRebuild(_StickyPillHeader oldDelegate) => oldDelegate.label != label;
}
