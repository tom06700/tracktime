import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import '../db/database.dart';
import '../movies/sync.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/movie_card.dart';

// Hauteurs fixes → calcul exact de l'offset d'ouverture sur « À voir »
// (mêmes dimensions que la page Séries : Card 120 + marge 2×5).
const double _kCardExtent = 130;
const double _kHeaderExtent = 46;

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  bool _syncStarted = false;
  final _scrollController = ScrollController();
  bool _positioned = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    // Rattrape genres + dates de sortie (pour peupler « À venir »).
    await backfillMovieMeta(
      ref.read(databaseProvider),
      ref.read(tvdbClientProvider),
      throttle: () => Future.delayed(const Duration(milliseconds: 120)),
    );
  }

  void _toggleWatched(Movie m) {
    HapticFeedback.lightImpact();
    ref.read(databaseProvider).toggleMovieWatched(m);
  }

  Future<void> _confirmDelete(Movie m) async {
    final db = ref.read(databaseProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer ce film ?'),
        content: Text('« ${m.title} » sera retiré de ta liste.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Retirer')),
        ],
      ),
    );
    if (ok == true) await db.deleteMovie(m.id);
  }

  @override
  Widget build(BuildContext context) {
    // Lance le rattrapage TMDB dès que la clé API est réellement chargée
    // (SharedPreferences est asynchrone), pour peupler l'onglet « À venir ».
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
    final feedAsync = ref.watch(movieFeedProvider);
    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.error_outline, message: '$e'),
      data: (feed) {
        if (feed.isEmpty) {
          return const EmptyState(
            icon: Icons.movie_outlined,
            message:
                "Aucun film pour l'instant.\nAjoute-en via Explorer ou importe ton export TV Time.",
          );
        }

        final toWatchCards = [
          for (var i = 0; i < feed.toWatch.length; i++)
            _card(feed.toWatch[i], badge: i == 0 ? 'RÉCENT' : null),
        ];
        final staleCards = [for (final m in feed.stale) _card(m)];
        // Historique inversé : le plus récent en bas, collé au « À voir ».
        final historyCards =
            feed.history.reversed.map((m) => _card(m, history: true)).toList();

        // Ouverture calée sur « À voir » : on saute la hauteur (exacte, car
        // hauteurs fixes) de la section Historique, une seule fois, quand elle
        // est chargée (mêmes règles que la page Séries).
        if (!_positioned && historyCards.isNotEmpty) {
          _positioned = true;
          final offset = _kHeaderExtent + historyCards.length * _kCardExtent;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) _scrollController.jumpTo(offset);
          });
        }

        final slivers = <Widget>[
          if (historyCards.isNotEmpty)
            _section('Films vus', historyCards),
          if (toWatchCards.isNotEmpty) _section('À voir', toWatchCards),
          if (staleCards.isNotEmpty)
            _section('Dans ta liste depuis longtemps', staleCards),
          SliverToBoxAdapter(child: SizedBox(height: bottomNavInset(context))),
        ];

        return CustomScrollView(controller: _scrollController, slivers: slivers);
      },
    );
  }

  /// Section à en-tête collant, poussé dehors par la suivante (pas d'empilement).
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
    final upcomingAsync = ref.watch(upcomingMoviesProvider);
    return upcomingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.error_outline, message: '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.event_outlined,
            message:
                'Aucun film à venir connu.\nAjoute des films pas encore sortis — leur date de sortie apparaîtra ici.',
          );
        }
        final now = DateTime.now();
        return ListView.builder(
          padding: EdgeInsets.only(top: 8, bottom: bottomNavInset(context)),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final u = list[i];
            return MovieCard(
              title: u.movie.title,
              poster: u.movie.poster,
              metaLine: _meta(u.movie, includeYear: false),
              upcomingInDays: u.daysFrom(now),
            );
          },
        );
      },
    );
  }

  Widget _card(Movie m, {String? badge, bool history = false}) {
    return Dismissible(
      key: ValueKey('movie-${m.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDelete(m);
        // Le retrait effectif vient du flux ; on ne laisse pas Dismissible
        // sortir la carte lui-même (évite l'erreur « dismissed still in tree »).
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: TtColors.danger.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: MovieCard(
        title: m.title,
        poster: m.poster,
        metaLine: _meta(m),
        badge: badge,
        history: history,
        onToggleWatched: () => _toggleWatched(m),
      ),
    );
  }

  /// « 2021 · 2 h 35 · Science-Fiction » (année optionnelle).
  String _meta(Movie m, {bool includeYear = true}) {
    final parts = <String>[];
    if (includeYear && m.releaseDate != null) {
      parts.add('${m.releaseDate!.year}');
    }
    parts.add(fmtTime(m.runtime));
    final genre = (m.genres ?? '')
        .split('|')
        .map((g) => g.trim())
        .firstWhere((g) => g.isNotEmpty, orElse: () => '');
    if (genre.isNotEmpty) parts.add(genre);
    return parts.join(' · ');
  }
}
