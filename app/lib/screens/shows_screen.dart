import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../series/feed.dart';
import '../series/sync.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/episode_card.dart';

// Hauteurs fixes → calcul exact de l'offset d'ouverture sur « À voir ».
const double _kCardExtent = 130; // EpisodeCard 120 + marge Card 2×5
const double _kHeaderExtent = 46;

class ShowsScreen extends ConsumerStatefulWidget {
  const ShowsScreen({super.key});

  @override
  ConsumerState<ShowsScreen> createState() => _ShowsScreenState();
}

class _ShowsScreenState extends ConsumerState<ShowsScreen> {
  bool _syncStarted = false;
  final _scrollController = ScrollController();
  bool _positioned = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    await syncStaleShows(
      ref.read(databaseProvider),
      ref.read(tvdbClientProvider),
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
    final key = ref.watch(tvdbKeyProvider).value;
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
        // Historique inversé : le plus récent en bas, collé au « À voir ».
        final historyCards = feed.history.reversed.map(historyCard).toList();

        // Ouverture calée sur « À voir » : on saute la hauteur (exacte, car
        // hauteurs fixes) de la section Historique. Déclenché seulement quand
        // l'historique est réellement chargé (les flux arrivent de façon
        // asynchrone), et une seule fois.
        if (!_positioned && historyCards.isNotEmpty) {
          _positioned = true;
          final offset = _kHeaderExtent + historyCards.length * _kCardExtent;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) _scrollController.jumpTo(offset);
          });
        }

        final slivers = <Widget>[
          if (historyCards.isNotEmpty)
            _section('Historique de visionnage', historyCards),
          if (toWatchCards.isNotEmpty) _section('À voir', toWatchCards),
          if (staleCards.isNotEmpty)
            _section('Pas regardé depuis un moment', staleCards),
          SliverToBoxAdapter(child: SizedBox(height: bottomNavInset(context))),
        ];

        return CustomScrollView(controller: _scrollController, slivers: slivers);
      },
    );
  }

  /// Section à en-tête collant : la pastille reste en tête de sa catégorie et
  /// est poussée dehors par la suivante (pas d'empilement).
  Widget _section(String label, List<Widget> cards) {
    return SliverStickyHeader(
      header: Container(
        height: _kHeaderExtent,
        alignment: Alignment.center,
        child: SectionPill(label),
      ),
      sliver: SliverList.list(children: cards),
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
