import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../series/feed.dart';
import '../series/sync.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/episode_card.dart';
import 'show_detail_screen.dart';

class ShowsScreen extends ConsumerStatefulWidget {
  const ShowsScreen({super.key});

  @override
  ConsumerState<ShowsScreen> createState() => _ShowsScreenState();
}

class _ShowsScreenState extends ConsumerState<ShowsScreen> {
  @override
  void initState() {
    super.initState();
    // Réchauffe le cache d'épisodes en tâche de fond (silencieux sans clé).
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<void> _sync() async {
    await syncStaleShows(
      ref.read(databaseProvider),
      ref.read(tmdbClientProvider),
      throttle: () => Future.delayed(const Duration(milliseconds: 120)),
    );
  }

  void _openShow(int id, String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ShowDetailScreen(showId: id, title: name),
    ));
  }

  void _markWatched(NextUp n) {
    HapticFeedback.lightImpact();
    ref.read(databaseProvider).setEpisodeWatched(n.show.id, n.season, n.episode);
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: () => _openShow(h.show.id, h.show.name),
            );

        // La partie basse (À voir + délaissées), affichée à partir du haut.
        final belowChildren = <Widget>[
          if (feed.toWatch.isNotEmpty) ...[
            const SectionLabel('À voir'),
            for (var i = 0; i < feed.toWatch.length; i++)
              _card(feed.toWatch[i], badge: i == 0 ? 'PLUS RÉCENT' : null),
          ],
          if (feed.stale.isNotEmpty) ...[
            const SectionLabel('Pas regardé depuis un moment'),
            ...feed.stale.map((n) => _card(n)),
          ],
          SizedBox(height: bottomNavInset(context)),
        ];

        // Rien « à voir » (tout est à jour) : simple liste de l'historique.
        if (belowChildren.length == 1) {
          return ListView(
            padding: EdgeInsets.only(bottom: bottomNavInset(context)),
            children: [
              const SectionLabel('Historique de visionnage'),
              ...feed.history.map(historyCard),
            ],
          );
        }

        // Vue bidirectionnelle : « À voir » démarre en haut (offset 0),
        // l'historique est au-dessus (scroll vers le haut).
        // Les enfants AVANT le centre sont inversés par le growth reverse,
        // d'où l'ordre [historique (récent→ancien), libellé] qui se lit
        // [libellé, ancien→récent] avec le plus récent collé au « À voir ».
        const centerKey = ValueKey('to-watch-center');
        final aboveChildren = <Widget>[
          if (feed.history.isNotEmpty) ...[
            ...feed.history.map(historyCard),
            const SectionLabel('Historique de visionnage'),
          ],
          const SizedBox(height: 8),
        ];

        return CustomScrollView(
          center: centerKey,
          slivers: [
            SliverList.list(children: aboveChildren),
            SliverList.list(key: centerKey, children: belowChildren),
          ],
        );
      },
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
              onTap: () => _openShow(u.show.id, u.show.name),
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
      onTap: () => _openShow(n.show.id, n.show.name),
      onMarkWatched: () => _markWatched(n),
    );
  }
}
