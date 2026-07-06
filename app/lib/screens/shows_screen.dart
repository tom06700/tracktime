import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../series/feed.dart';
import '../series/sync.dart';
import '../settings/prefs.dart';
import '../widgets/common.dart';
import '../widgets/episode_card.dart';
import 'show_detail_screen.dart';

class ShowsScreen extends ConsumerStatefulWidget {
  const ShowsScreen({super.key});

  @override
  ConsumerState<ShowsScreen> createState() => _ShowsScreenState();
}

class _ShowsScreenState extends ConsumerState<ShowsScreen> {
  // Ancre posée sur la section « À voir » : à la première ouverture, on
  // s'aligne dessus (l'historique reste au-dessus, accessible en scrollant).
  final _toWatchAnchor = GlobalKey();
  bool _positioned = false;

  @override
  void initState() {
    super.initState();
    // Réchauffe le cache d'épisodes en tâche de fond (silencieux sans clé).
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _positionAtToWatch() {
    if (_positioned) return;
    final ctx = _toWatchAnchor.currentContext;
    if (ctx == null) return;
    _positioned = true;
    Scrollable.ensureVisible(ctx, duration: Duration.zero, alignment: 0);
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

        // Après la mise en page, on cale la vue sur « À voir ».
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _positionAtToWatch());

        // La section qui reçoit l'ancre : « À voir » si présente, sinon
        // « Pas regardé depuis un moment ».
        final anchorOnToWatch = feed.toWatch.isNotEmpty;

        return ListView(
          padding: EdgeInsets.only(bottom: bottomNavInset(context)),
          children: [
            if (feed.history.isNotEmpty) ...[
              const SectionLabel('Historique de visionnage'),
              ...feed.history.map((h) => EpisodeCard(
                    history: true,
                    showName: h.show.name,
                    code: h.code,
                    stillPath: h.still,
                    posterPath: h.show.poster,
                    seed: h.show.name,
                    episodeTitle: h.episodeName,
                    onTap: () => _openShow(h.show.id, h.show.name),
                  )),
            ],
            if (feed.toWatch.isNotEmpty) ...[
              SectionLabel('À voir', anchor: _toWatchAnchor),
              for (var i = 0; i < feed.toWatch.length; i++)
                _card(feed.toWatch[i], badge: i == 0 ? 'PLUS RÉCENT' : null),
            ],
            if (feed.stale.isNotEmpty) ...[
              SectionLabel('Pas regardé depuis un moment',
                  anchor: anchorOnToWatch ? null : _toWatchAnchor),
              ...feed.stale.map((n) => _card(n)),
            ],
          ],
        );
      },
    );
  }

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
