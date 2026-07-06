import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db/database.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../tmdb/tmdb.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ShowDetailScreen extends ConsumerStatefulWidget {
  const ShowDetailScreen({super.key, required this.showId, required this.title});

  final int showId;
  final String title;

  @override
  ConsumerState<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends ConsumerState<ShowDetailScreen> {
  List<int>? _seasonNumbers; // numéros de saison (>0), null tant que chargement
  String? _error;
  // Cache des épisodes par saison : numéro de saison -> numéros d'épisodes.
  final Map<int, List<int>> _episodesBySeason = {};
  final Map<int, Map<int, String>> _episodeNames = {};

  @override
  void initState() {
    super.initState();
    _loadShow();
  }

  Future<void> _loadShow() async {
    final db = ref.read(databaseProvider);
    final tmdb = ref.read(tmdbClientProvider);
    try {
      final d = await tmdb.tvDetails(widget.showId);
      // Rafraîchit les totaux stockés (nombre d'épisodes, statut, affiche…).
      await db.upsertShow(ShowsCompanion(
        id: Value(widget.showId),
        name: Value('${d['name'] ?? widget.title}'),
        poster: Value(d['poster_path'] as String?),
        totalEpisodes: Value((d['number_of_episodes'] as num?)?.toInt()),
        seasonCount: Value((d['number_of_seasons'] as num?)?.toInt()),
        runtime: Value(
            ((d['episode_run_time'] as List?)?.firstOrNull as num?)?.toInt() ??
                42),
        status: Value(d['status'] as String?),
      ));
      final seasons = ((d['seasons'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((s) => (s['season_number'] as num?)?.toInt() ?? 0)
          .where((n) => n > 0)
          .toList();
      if (!mounted) return;
      setState(() => _seasonNumbers = seasons);
    } on TmdbException catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<List<int>> _loadSeason(int season) async {
    final cached = _episodesBySeason[season];
    if (cached != null) return cached;
    final tmdb = ref.read(tmdbClientProvider);
    final j = await tmdb.season(widget.showId, season);
    final eps = ((j['episodes'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final numbers = <int>[];
    final names = <int, String>{};
    final rows = <EpisodesCompanion>[];
    for (final e in eps) {
      final n = (e['episode_number'] as num?)?.toInt();
      if (n == null) continue;
      numbers.add(n);
      names[n] = '${e['name'] ?? 'Épisode $n'}';
      rows.add(EpisodesCompanion.insert(
        showId: widget.showId,
        season: season,
        episode: n,
        name: Value(e['name'] as String?),
        still: Value(e['still_path'] as String?),
        airDate: Value(DateTime.tryParse('${e['air_date'] ?? ''}')),
      ));
    }
    // Réchauffe le cache pour le fil « à voir ».
    if (rows.isNotEmpty) await ref.read(databaseProvider).upsertEpisodes(rows);
    _episodesBySeason[season] = numbers;
    _episodeNames[season] = names;
    return numbers;
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer « ${widget.title} » ?'),
        content: const Text('La série et sa progression seront supprimées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TtColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).deleteShow(widget.showId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final watchedKeys =
        ref.watch(watchedKeysProvider(widget.showId)).value ?? const {};
    final showAsync = ref.watch(showsProvider).value;
    final show = showAsync
        ?.firstWhere(
          (s) => s.show.id == widget.showId,
          orElse: () => ShowWithProgress(
            Show(
                id: widget.showId,
                name: widget.title,
                runtime: 42,
                addedAt: DateTime.now()),
            0,
          ),
        )
        .show;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Retirer',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: _buildBody(show, watchedKeys),
    );
  }

  Widget _buildBody(Show? show, Set<String> watchedKeys) {
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline, message: _error!);
    }
    if (_seasonNumbers == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final total = show?.totalEpisodes;
    final watched = watchedKeys.length;
    final progress = (total != null && total > 0)
        ? (watched / total).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$watched${total != null ? ' / $total' : ''} épisodes',
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      show?.status == 'Ended' ? 'Terminée' : 'En diffusion',
                      style: const TextStyle(
                          fontSize: 12.5, color: TtColors.dim),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ThinProgressBar(value: progress),
              ],
            ),
          ),
        ),
        for (final n in _seasonNumbers!)
          _SeasonTile(
            key: ValueKey('season-$n'),
            season: n,
            watchedKeys: watchedKeys,
            loadEpisodes: () => _loadSeason(n),
            episodeName: (ep) => _episodeNames[n]?[ep] ?? 'Épisode $ep',
            showId: widget.showId,
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SeasonTile extends ConsumerStatefulWidget {
  const _SeasonTile({
    super.key,
    required this.season,
    required this.watchedKeys,
    required this.loadEpisodes,
    required this.episodeName,
    required this.showId,
  });

  final int season;
  final Set<String> watchedKeys;
  final Future<List<int>> Function() loadEpisodes;
  final String Function(int episode) episodeName;
  final int showId;

  @override
  ConsumerState<_SeasonTile> createState() => _SeasonTileState();
}

class _SeasonTileState extends ConsumerState<_SeasonTile> {
  bool _expanded = false;
  List<int>? _episodes;
  bool _loading = false;
  String? _error;

  int get _watchedInSeason => widget.watchedKeys
      .where((k) => k.startsWith('S${widget.season}E'))
      .length;

  Future<void> _toggle() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    setState(() => _expanded = true);
    if (_episodes == null && !_loading) {
      setState(() => _loading = true);
      try {
        final eps = await widget.loadEpisodes();
        if (!mounted) return;
        setState(() {
          _episodes = eps;
          _loading = false;
        });
      } on TmdbException catch (e) {
        if (!mounted) return;
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eps = _episodes;
    final subtitle = eps != null
        ? '$_watchedInSeason / ${eps.length} vus'
        : '$_watchedInSeason vus';

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Saison ${widget.season}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12.5, color: TtColors.dim)),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: TtColors.dim),
                ],
              ),
            ),
          ),
          if (_expanded) _buildExpanded(eps),
        ],
      ),
    );
  }

  Widget _buildExpanded(List<int>? eps) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(_error!,
            style: const TextStyle(fontSize: 13, color: TtColors.dim)),
      );
    }
    if (eps == null || eps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text('Aucun épisode.',
            style: TextStyle(fontSize: 13, color: TtColors.dim)),
      );
    }
    final db = ref.read(databaseProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Tout vu'),
                onPressed: () => db.setSeasonWatched(
                    widget.showId, widget.season, eps, true),
              ),
              TextButton(
                onPressed: () => db.setSeasonWatched(
                    widget.showId, widget.season, eps, false),
                child: const Text('Tout décocher'),
              ),
            ],
          ),
        ),
        for (final ep in eps)
          _EpisodeRow(
            showId: widget.showId,
            season: widget.season,
            episode: ep,
            name: widget.episodeName(ep),
            watched: widget.watchedKeys.contains('S${widget.season}E$ep'),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _EpisodeRow extends ConsumerWidget {
  const _EpisodeRow({
    required this.showId,
    required this.season,
    required this.episode,
    required this.name,
    required this.watched,
  });

  final int showId;
  final int season;
  final int episode;
  final String name;
  final bool watched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    return InkWell(
      onTap: () => watched
          ? db.setEpisodeUnwatched(showId, season, episode)
          : db.setEpisodeWatched(showId, season, episode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(
              watched ? Icons.check_circle : Icons.circle_outlined,
              color: watched ? TtColors.amber : TtColors.dim,
              size: 24,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                '$episode. $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: watched ? TtColors.dim : TtColors.text,
                  decoration:
                      watched ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
