import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/database.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../tmdb/tmdb.dart';
import '../theme.dart';
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
  Map<String, dynamic>? _providersFr; // {link, flatrate:[...]}
  List<Map<String, dynamic>> _similar = const [];
  List<int> _seasonNumbers = const [];
  String? _error;

  // Cache épisodes par saison (numéros + titres), pour l'onglet Épisodes.
  final Map<int, List<int>> _episodesBySeason = {};
  final Map<int, Map<int, String>> _episodeNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tmdb = ref.read(tmdbClientProvider);
    final db = ref.read(databaseProvider);
    try {
      final d = await tmdb.tvDetails(widget.showId);
      final seasons = ((d['seasons'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((s) => (s['season_number'] as num?)?.toInt() ?? 0)
          .where((n) => n > 0)
          .toList();

      // Rafraîchit les métadonnées seulement si la série est déjà suivie
      // (ne pas polluer la bibliothèque en consultant une série similaire).
      if (await db.showById(widget.showId) != null) {
        await _upsertFromDetails(d);
      }

      if (!mounted) return;
      setState(() {
        _details = d;
        _seasonNumbers = seasons;
      });

      // Best-effort : plateformes + similaires (n'échouent pas la page).
      _loadProviders(tmdb);
      _loadSimilar(tmdb);
    } on TmdbException catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _loadProviders(TmdbClient tmdb) async {
    try {
      final j = await tmdb.watchProviders(widget.showId);
      final fr = (j['results'] as Map?)?['FR'];
      if (mounted && fr is Map) {
        setState(() => _providersFr = fr.cast<String, dynamic>());
      }
    } on TmdbException {
      /* ignoré */
    }
  }

  Future<void> _loadSimilar(TmdbClient tmdb) async {
    try {
      final list = await tmdb.similarTv(widget.showId);
      if (mounted) setState(() => _similar = list);
    } on TmdbException {
      /* ignoré */
    }
  }

  Future<void> _upsertFromDetails(Map<String, dynamic> d) {
    return ref.read(databaseProvider).upsertShow(ShowsCompanion(
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
  }

  bool _followed(List<ShowWithProgress> shows) =>
      shows.any((s) => s.show.id == widget.showId);

  Future<void> _ensureFollowed() async {
    final db = ref.read(databaseProvider);
    if (await db.showById(widget.showId) == null && _details != null) {
      await _upsertFromDetails(_details!);
    }
  }

  Future<List<int>> _loadSeason(int season) async {
    final cached = _episodesBySeason[season];
    if (cached != null) return cached;
    final j = await ref.read(tmdbClientProvider).season(widget.showId, season);
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
    if (rows.isNotEmpty) await ref.read(databaseProvider).upsertEpisodes(rows);
    _episodesBySeason[season] = numbers;
    _episodeNames[season] = names;
    return numbers;
  }

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
              : _buildContent(_details!, followed),
    );
  }

  Widget _buildContent(Map<String, dynamic> d, bool followed) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _Header(details: d, title: widget.title),
          const TabBar(
            labelColor: TtColors.amber,
            unselectedLabelColor: TtColors.dim,
            indicatorColor: TtColors.amber,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle:
                TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
            tabs: [Tab(text: 'À PROPOS'), Tab(text: 'ÉPISODES')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AboutTab(
                  details: d,
                  providersFr: _providersFr,
                  similar: _similar,
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
}

// ------------------------------------------------------------------ Header

class _Header extends StatelessWidget {
  const _Header({required this.details, required this.title});

  final Map<String, dynamic> details;
  final String title;

  @override
  Widget build(BuildContext context) {
    final backdrop = details['backdrop_path'] as String? ??
        details['poster_path'] as String?;
    final name = '${details['name'] ?? title}';
    final epCount = (details['number_of_episodes'] as num?)?.toInt();
    final networks = (details['networks'] as List?) ?? const [];
    final network =
        networks.isNotEmpty ? '${(networks.first as Map)['name'] ?? ''}' : '';

    final meta = [
      if (epCount != null) '$epCount épisodes',
      if (network.isNotEmpty) network,
    ].join(' · ');

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdrop != null)
            Image.network('https://image.tmdb.org/t/p/w780$backdrop',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: TtColors.surface))
          else
            const ColoredBox(color: TtColors.surface),
          // Dégradé pour lisibilité du texte.
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
    required this.details,
    required this.providersFr,
    required this.similar,
    required this.followed,
    required this.onFollow,
  });

  final Map<String, dynamic> details;
  final Map<String, dynamic>? providersFr;
  final List<Map<String, dynamic>> similar;
  final bool followed;
  final Future<void> Function() onFollow;

  @override
  Widget build(BuildContext context) {
    final overview = '${details['overview'] ?? ''}';
    final genres = ((details['genres'] as List?) ?? const [])
        .map((g) => '${(g as Map)['name']}')
        .toList();
    final year =
        '${details['first_air_date'] ?? ''}'.padRight(4).substring(0, 4).trim();
    final vote = (details['vote_average'] as num?)?.toDouble() ?? 0;
    final flatrate = ((providersFr?['flatrate'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final link = providersFr?['link'] as String?;

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
        _SectionTitle('Où regarder'),
        const SizedBox(height: 8),
        if (flatrate.isEmpty)
          const Text('Non disponible en streaming (abonnement) en France.',
              style: TextStyle(fontSize: 13.5, color: TtColors.dim))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in flatrate)
                _ProviderChip(
                  name: '${p['provider_name'] ?? ''}',
                  logoPath: p['logo_path'] as String?,
                  onTap: link == null ? null : () => _open(link),
                ),
            ],
          ),
        const SizedBox(height: 22),
        _SectionTitle('Infos'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (year.isNotEmpty)
              _MetaItem(icon: Icons.event_outlined, text: year),
            if (vote > 0)
              _MetaItem(
                  icon: Icons.star_rounded,
                  text: vote.toStringAsFixed(1),
                  iconColor: TtColors.amber),
            if (genres.isNotEmpty)
              _MetaItem(icon: Icons.local_offer_outlined, text: genres.join(', ')),
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
        if (similar.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionTitle('Séries similaires'),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: similar.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _SimilarCard(similar[i]),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.name, required this.logoPath, this.onTap});

  final String name;
  final String? logoPath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: TtColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network('https://image.tmdb.org/t/p/w92$logoPath',
                    width: 26, height: 26, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 26, height: 26)),
              ),
            const SizedBox(width: 8),
            Text(name,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            const Icon(Icons.open_in_new, size: 13, color: TtColors.dim),
          ],
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text, this.iconColor});
  final IconData icon;
  final String text;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor ?? TtColors.dim),
        const SizedBox(width: 5),
        Flexible(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: TtColors.text))),
      ],
    );
  }
}

class _SimilarCard extends StatelessWidget {
  const _SimilarCard(this.show);
  final Map<String, dynamic> show;

  @override
  Widget build(BuildContext context) {
    final id = (show['id'] as num).toInt();
    final name = '${show['name'] ?? ''}';
    final poster = show['poster_path'] as String?;
    return GestureDetector(
      onTap: () => context.push('/show/$id', extra: name),
      child: SizedBox(
        width: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: poster == null
                  ? Container(
                      width: 108,
                      height: 150,
                      color: TtColors.surfaceHi,
                      child: const Icon(Icons.tv, color: TtColors.dim))
                  : Image.network('https://image.tmdb.org/t/p/w185$poster',
                      width: 108, height: 150, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                          width: 108, height: 150, color: TtColors.surfaceHi)),
            ),
            const SizedBox(height: 6),
            Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
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
                  // Bouton « valider toute la saison ».
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
