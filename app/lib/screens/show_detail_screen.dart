import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db/database.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../tmdb/tvdb.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

class ShowDetailScreen extends ConsumerStatefulWidget {
  const ShowDetailScreen({super.key, required this.showId, required this.title});

  final int showId;
  final String title;

  @override
  ConsumerState<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends ConsumerState<ShowDetailScreen> {
  Map<String, dynamic>? _details;
  String _name = '';
  String _overview = '';
  String? _backdrop;
  List<int> _seasonNumbers = const [];
  String? _error;

  final Map<int, List<int>> _episodesBySeason = {};
  final Map<int, Map<int, String>> _episodeNames = {};

  @override
  void initState() {
    super.initState();
    _name = widget.title;
    _load();
  }

  Future<void> _load() async {
    final tvdb = ref.read(tvdbClientProvider);
    final db = ref.read(databaseProvider);
    try {
      final d = await tvdb.seriesExtended(widget.showId);
      final fr = await tvdb.seriesTranslation(widget.showId, 'fra');
      final name = _firstNonEmpty(
          [fr['name'], d['name'], widget.title]) ?? widget.title;
      final overview =
          _firstNonEmpty([fr['overview'], d['overview']]) ?? '';

      // Épisodes (toutes saisons > 0), groupés puis mis en cache DB.
      final eps = await tvdb.seriesEpisodes(widget.showId);
      final bySeason = <int, List<int>>{};
      final names = <int, Map<int, String>>{};
      final rows = <EpisodesCompanion>[];
      for (final e in eps) {
        final s = e['season'] as int;
        if (s < 1) continue;
        final n = e['episode'] as int;
        (bySeason[s] ??= []).add(n);
        (names[s] ??= {})[n] = '${e['name'] ?? 'Épisode $n'}';
        rows.add(EpisodesCompanion.insert(
          showId: widget.showId,
          season: s,
          episode: n,
          name: Value(e['name'] as String?),
          still: Value(e['image'] as String?),
          airDate: Value(
              DateTime.tryParse('${e['aired'] ?? ''}')),
        ));
      }
      for (final l in bySeason.values) {
        l.sort();
      }
      final seasons = bySeason.keys.toList()..sort();

      final followed = await db.showById(widget.showId) != null;
      if (rows.isNotEmpty) await db.upsertEpisodes(rows);
      if (followed) {
        await _upsertFromDetails(d, name);
        if (bySeason.isNotEmpty) {
          final total =
              bySeason.values.fold<int>(0, (s, l) => s + l.length);
          await db.updateShowCounts(widget.showId,
              total: total, seasons: seasons.last);
        }
      }

      if (!mounted) return;
      setState(() {
        _details = d;
        _name = name;
        _overview = overview;
        _backdrop = _backdropOf(d);
        _episodesBySeason
          ..clear()
          ..addAll(bySeason);
        _episodeNames
          ..clear()
          ..addAll(names);
        _seasonNumbers = seasons;
      });
    } on TvdbException catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _upsertFromDetails(Map<String, dynamic> d, String name) {
    return ref.read(databaseProvider).upsertShow(ShowsCompanion(
          id: Value(widget.showId),
          name: Value(name),
          poster: Value(TvdbClient.posterOf(d)),
          seasonCount: Value(_seasonNumbers.isEmpty ? null : _seasonNumbers.last),
          runtime: Value((d['averageRuntime'] as num?)?.toInt() ?? 42),
          status: Value(TvdbClient.statusOf(d)),
          genres: Value(TvdbClient.genresOf(d)),
        ));
  }

  bool _followed(List<ShowWithProgress> shows) =>
      shows.any((s) => s.show.id == widget.showId);

  Future<void> _ensureFollowed() async {
    final db = ref.read(databaseProvider);
    if (await db.showById(widget.showId) == null && _details != null) {
      await _upsertFromDetails(_details!, _name);
    }
  }

  Future<List<int>> _loadSeason(int season) async =>
      _episodesBySeason[season] ?? const [];

  Future<void> _toggleEpisode(int season, int episode, bool watched) async {
    HapticFeedback.selectionClick();
    await _ensureFollowed();
    final db = ref.read(databaseProvider);
    if (watched) {
      db.setEpisodeUnwatched(widget.showId, season, episode);
    } else {
      db.setEpisodeWatched(widget.showId, season, episode);
    }
  }

  Future<void> _setSeason(int season, List<int> eps, bool on) async {
    HapticFeedback.lightImpact();
    await _ensureFollowed();
    ref.read(databaseProvider).setSeasonWatched(widget.showId, season, eps, on);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer « $_name » ?'),
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
    final shows = ref.watch(showsProvider).value ?? const [];
    final followed = _followed(shows);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (followed)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Retirer',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: _error != null
          ? EmptyState(icon: Icons.error_outline, message: _error!)
          : _details == null
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(followed),
    );
  }

  Widget _buildContent(bool followed) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _Header(
            name: _name,
            backdrop: _backdrop,
            episodeCount: _totalEpisodes(),
            network: _networkOf(_details!),
          ),
          const TabBar(
            labelColor: TtColors.amber,
            unselectedLabelColor: TtColors.dim,
            indicatorColor: TtColors.amber,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
            tabs: [Tab(text: 'À PROPOS'), Tab(text: 'ÉPISODES')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AboutTab(
                  overview: _overview,
                  genres: _genresOf(_details!),
                  year: _yearOf(_details!),
                  followed: followed,
                  onFollow: _ensureFollowed,
                ),
                _EpisodesTab(
                  showId: widget.showId,
                  seasonNumbers: _seasonNumbers,
                  loadSeason: _loadSeason,
                  episodeName: (s, e) => _episodeNames[s]?[e] ?? 'Épisode $e',
                  onToggle: _toggleEpisode,
                  onSetSeason: _setSeason,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int? _totalEpisodes() {
    if (_episodesBySeason.isEmpty) return null;
    return _episodesBySeason.values.fold<int>(0, (s, l) => s + l.length);
  }

  static List<String> _genresOf(Map<String, dynamic> d) =>
      ((d['genres'] as List?) ?? const [])
          .whereType<Map>()
          .map((g) => '${g['name'] ?? ''}')
          .where((n) => n.isNotEmpty)
          .toList();

  static String _yearOf(Map<String, dynamic> d) {
    final y = d['year'];
    if (y is String && y.isNotEmpty) return y;
    final first = '${d['firstAired'] ?? ''}';
    return first.length >= 4 ? first.substring(0, 4) : '';
  }

  static String _networkOf(Map<String, dynamic> d) {
    final latest = d['latestNetwork'];
    if (latest is Map && latest['name'] is String) return latest['name'];
    final orig = d['originalNetwork'];
    if (orig is Map && orig['name'] is String) return orig['name'];
    return '';
  }

  static String? _backdropOf(Map<String, dynamic> d) {
    // Artwork de type « background » (3) si dispo, sinon l'affiche.
    for (final a in ((d['artworks'] as List?) ?? const []).whereType<Map>()) {
      if ((a['type'] as num?)?.toInt() == 3 && a['image'] is String) {
        return a['image'] as String;
      }
    }
    return TvdbClient.posterOf(d);
  }

  static String? _firstNonEmpty(List<Object?> vals) {
    for (final v in vals) {
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }
}

// ------------------------------------------------------------------ Header

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.backdrop,
    required this.episodeCount,
    required this.network,
  });

  final String name;
  final String? backdrop;
  final int? episodeCount;
  final String network;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (episodeCount != null) '$episodeCount épisodes',
      if (network.isNotEmpty) network,
    ].join(' · ');

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdrop != null)
            Image.network(backdrop!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: TtColors.surface))
          else
            const ColoredBox(color: TtColors.surface),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0x00000000), Color(0xE6000000)],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(meta,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- À propos

class _AboutTab extends StatelessWidget {
  const _AboutTab({
    required this.overview,
    required this.genres,
    required this.year,
    required this.followed,
    required this.onFollow,
  });

  final String overview;
  final List<String> genres;
  final String year;
  final bool followed;
  final Future<void> Function() onFollow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomNavInset(context)),
      children: [
        if (!followed) ...[
          SizedBox(
            width: double.infinity,
            child: ProminentGlassButton(
              icon: Icons.add,
              onPressed: onFollow,
              child: const Text('Suivre cette série'),
            ),
          ),
          const SizedBox(height: 18),
        ],
        _SectionTitle('Infos'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (year.isNotEmpty)
              _MetaItem(icon: Icons.event_outlined, text: year),
            if (genres.isNotEmpty)
              _MetaItem(
                  icon: Icons.local_offer_outlined, text: genres.join(', ')),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          overview.isEmpty ? 'Pas de résumé disponible.' : overview,
          style: TextStyle(
              fontSize: 14.5,
              height: 1.6,
              color: overview.isEmpty ? TtColors.dim : TtColors.text),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: TtColors.amber),
      );
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: TtColors.dim),
        const SizedBox(width: 5),
        Flexible(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: TtColors.text))),
      ],
    );
  }
}

// --------------------------------------------------------------- Épisodes

class _EpisodesTab extends ConsumerWidget {
  const _EpisodesTab({
    required this.showId,
    required this.seasonNumbers,
    required this.loadSeason,
    required this.episodeName,
    required this.onToggle,
    required this.onSetSeason,
  });

  final int showId;
  final List<int> seasonNumbers;
  final Future<List<int>> Function(int season) loadSeason;
  final String Function(int season, int episode) episodeName;
  final Future<void> Function(int season, int episode, bool watched) onToggle;
  final Future<void> Function(int season, List<int> eps, bool on) onSetSeason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watched =
        ref.watch(watchedKeysProvider(showId)).value ?? const <String>{};
    if (seasonNumbers.isEmpty) {
      return const EmptyState(icon: Icons.tv, message: 'Aucune saison.');
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomNavInset(context)),
      children: [
        for (final n in seasonNumbers)
          _SeasonCard(
            key: ValueKey('season-$n'),
            season: n,
            watchedKeys: watched,
            loadEpisodes: () => loadSeason(n),
            episodeName: (e) => episodeName(n, e),
            onToggle: (e, w) => onToggle(n, e, w),
            onSetSeason: (eps, on) => onSetSeason(n, eps, on),
          ),
      ],
    );
  }
}

class _SeasonCard extends StatefulWidget {
  const _SeasonCard({
    super.key,
    required this.season,
    required this.watchedKeys,
    required this.loadEpisodes,
    required this.episodeName,
    required this.onToggle,
    required this.onSetSeason,
  });

  final int season;
  final Set<String> watchedKeys;
  final Future<List<int>> Function() loadEpisodes;
  final String Function(int episode) episodeName;
  final Future<void> Function(int episode, bool watched) onToggle;
  final Future<void> Function(List<int> eps, bool on) onSetSeason;

  @override
  State<_SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends State<_SeasonCard> {
  bool _expanded = false;
  List<int>? _eps;
  bool _loading = false;
  String? _error;

  int get _watchedInSeason =>
      widget.watchedKeys.where((k) => k.startsWith('S${widget.season}E')).length;

  Future<void> _toggleExpand() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    setState(() => _expanded = true);
    if (_eps == null && !_loading) {
      setState(() => _loading = true);
      try {
        final eps = await widget.loadEpisodes();
        if (mounted) setState(() => _eps = eps);
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eps = _eps;
    final total = eps?.length;
    final watched = _watchedInSeason;
    final allWatched = total != null && total > 0 && watched >= total;
    final progress = (total != null && total > 0) ? watched / total : 0.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saison ${widget.season}',
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          total != null ? '$watched / $total vus' : '$watched vus',
                          style: const TextStyle(
                              fontSize: 12.5, color: TtColors.dim),
                        ),
                        if (total != null) ...[
                          const SizedBox(height: 8),
                          ThinProgressBar(value: progress),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SeasonCheck(
                    allWatched: allWatched,
                    enabled: eps != null,
                    onTap: eps == null
                        ? null
                        : () => widget.onSetSeason(eps, !allWatched),
                  ),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: TtColors.dim),
                ],
              ),
            ),
          ),
          if (_expanded) _buildEpisodes(eps),
        ],
      ),
    );
  }

  Widget _buildEpisodes(List<int>? eps) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(18),
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
    return Column(
      children: [
        const Divider(height: 1, color: TtColors.surfaceHi),
        for (final e in eps)
          _EpisodeRow(
            number: e,
            name: widget.episodeName(e),
            watched: widget.watchedKeys.contains('S${widget.season}E$e'),
            onTap: () => widget.onToggle(
                e, widget.watchedKeys.contains('S${widget.season}E$e')),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _SeasonCheck extends StatelessWidget {
  const _SeasonCheck(
      {required this.allWatched, required this.enabled, this.onTap});

  final bool allWatched;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: allWatched
                ? TtColors.teal
                : Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
                color: allWatched
                    ? TtColors.teal
                    : Colors.white.withValues(alpha: 0.22)),
          ),
          child: Icon(Icons.done_all,
              size: 20,
              color: allWatched ? const Color(0xFF0C1A15) : TtColors.text),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.number,
    required this.name,
    required this.watched,
    required this.onTap,
  });

  final int number;
  final String name;
  final bool watched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(
              watched ? Icons.check_circle : Icons.circle_outlined,
              color: watched ? TtColors.amber : TtColors.dim,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$number. $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: watched ? TtColors.dim : TtColors.text,
                  decoration: watched ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
