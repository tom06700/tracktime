import '../widgets/modern_controls.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db/database.dart';
import '../providers.dart';
import '../media/cinematic.dart';
import '../media/palette.dart';
import '../motion.dart';
import '../series/catch_up.dart';
import '../series/widgets/catch_up_sheet.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../tmdb/tvdb.dart';
import 'media_detail_parts.dart';
import 'movie_detail_screen.dart' show DetailWithBack, MediaDetailSkeleton;
import '../widgets/common.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';

class ShowDetailScreen extends ConsumerStatefulWidget {
  const ShowDetailScreen({
    super.key,
    required this.showId,
    required this.title,
  });

  final int showId;
  final String title;

  @override
  ConsumerState<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends ConsumerState<ShowDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      // Les épisodes ne sont chargés qu'à l'ouverture de leur onglet : leur
      // liste est une requête paginée coûteuse — plus de mille épisodes pour
      // One Piece — qu'on ne déclenche pas pour un simple aperçu.
      if (_tabs.index == 1) _loadEpisodes();
    });

  bool _episodesRequested = false;
  bool _loadingEpisodes = false;
  String? _episodesError;

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

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tvdb = ref.read(tvdbClientProvider);
    try {
      final d = await tvdb.seriesExtended(widget.showId);
      final fr = await tvdb.seriesTranslation(widget.showId, 'fra');
      final name =
          _firstNonEmpty([fr['name'], d['name'], widget.title]) ?? widget.title;
      final overview = _firstNonEmpty([fr['overview'], d['overview']]) ?? '';

      if (!mounted) return;
      setState(() {
        _details = d;
        _name = name;
        _overview = overview;
        _backdrop = _backdropOf(d);
        // Saisons officielles connues sans appeler la liste des épisodes.
        _seasonNumbers = _officialSeasons(d);
      });

      // Série déjà suivie : ses épisodes sont l'intérêt principal de la fiche,
      // on les charge sans attendre l'ouverture de l'onglet.
      if (await ref.read(databaseProvider).showById(widget.showId) != null) {
        await _loadEpisodes();
      }
    } on TvdbException catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// Saisons officielles déclarées par `/series/{id}/extended`, hors saison 0.
  static List<int> _officialSeasons(Map<String, dynamic> d) {
    final out = <int>{};
    for (final s in (d['seasons'] as List?) ?? const []) {
      if (s is! Map) continue;
      final n = (s['number'] as num?)?.toInt();
      if ((s['type'] as Map?)?['type'] == 'official' && n != null && n > 0) {
        out.add(n);
      }
    }
    return out.toList()..sort();
  }

  /// Charge la liste des épisodes, et ne la persiste que si la série est
  /// suivie. [refresh] rejoue le chargement alors qu'il a déjà eu lieu : c'est
  /// ce qui persiste les épisodes déjà affichés au moment où la série entre
  /// dans la bibliothèque (le client garde la liste en mémoire, pas de réseau).
  Future<void> _loadEpisodes({bool refresh = false}) async {
    if (_episodesRequested && !refresh) return;
    _episodesRequested = true;
    if (!mounted) return;
    setState(() {
      _loadingEpisodes = true;
      _episodesError = null;
    });

    final tvdb = ref.read(tvdbClientProvider);
    final db = ref.read(databaseProvider);
    try {
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
        rows.add(
          EpisodesCompanion.insert(
            showId: widget.showId,
            season: s,
            episode: n,
            name: Value(e['name'] as String?),
            still: Value(e['image'] as String?),
            airDate: Value(DateTime.tryParse('${e['aired'] ?? ''}')),
          ),
        );
      }
      for (final l in bySeason.values) {
        l.sort();
      }
      final seasons = bySeason.keys.toList()..sort();

      // Rien n'est persisté tant que la série n'est pas dans la bibliothèque :
      // les épisodes la référencent par clé étrangère, et une simple
      // consultation depuis Explorer laisserait sinon des lignes orphelines
      // rattachées à une série absente.
      final followed = await db.showById(widget.showId) != null;
      if (followed && rows.isNotEmpty) await db.upsertEpisodes(rows);
      if (followed && bySeason.isNotEmpty) {
        await _upsertFromDetails(_details!, _name);
        final total = bySeason.values.fold<int>(0, (s, l) => s + l.length);
        await db.updateShowCounts(
          widget.showId,
          total: total,
          seasons: seasons.last,
        );
      }

      if (!mounted) return;
      setState(() {
        _episodesBySeason
          ..clear()
          ..addAll(bySeason);
        _episodeNames
          ..clear()
          ..addAll(names);
        if (seasons.isNotEmpty) _seasonNumbers = seasons;
        _loadingEpisodes = false;
      });
    } on TvdbException catch (e) {
      debugPrint('Épisodes de ${widget.showId} indisponibles : $e');
      // La fiche reste consultable : seul l'onglet Épisodes restera vide.
      _episodesRequested = false;
      if (mounted) {
        setState(() {
          _loadingEpisodes = false;
          _episodesError = '$e';
        });
      }
    }
  }

  Future<void> _upsertFromDetails(Map<String, dynamic> d, String name) {
    return ref.read(databaseProvider).upsertShow(
          ShowsCompanion(
            id: Value(widget.showId),
            name: Value(name),
            poster: Value(TvdbClient.posterOf(d)),
            seasonCount: Value(
              _seasonNumbers.isEmpty ? null : _seasonNumbers.last,
            ),
            runtime: Value((d['averageRuntime'] as num?)?.toInt() ?? 42),
            status: Value(TvdbClient.statusOf(d)),
            genres: Value(TvdbClient.genresOf(d)),
          ),
        );
  }

  bool _followed(List<ShowWithProgress> shows) =>
      shows.any((s) => s.show.id == widget.showId);

  /// Garde de toute écriture de progression. Une série n'entre dans la
  /// bibliothèque que par « Ajouter à ma liste » : cocher un épisode depuis
  /// une fiche ouverte au hasard dans Explorer l'y ajoutait en douce, sans
  /// que l'utilisateur ait rien demandé.
  Future<bool> _requireFollowed() async {
    if (await ref.read(databaseProvider).showById(widget.showId) != null) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Ajoute d\'abord cette série à ta liste '
              'pour suivre tes épisodes.',
            ),
          ),
        );
    }
    return false;
  }

  /// Ajoute la série à la bibliothèque puis récupère ses épisodes — c'est le
  /// moment où leur téléchargement devient justifié, et le seul endroit d'où
  /// une série peut entrer dans la bibliothèque.
  Future<bool> _addToLibrary() async {
    final ok = await addSeriesToLibrary(ref, widget.showId);
    if (!ok) return false;
    if (_details != null) await _upsertFromDetails(_details!, _name);
    await _loadEpisodes(refresh: true);
    return true;
  }

  Future<List<int>> _loadSeason(int season) async =>
      _episodesBySeason[season] ?? const [];

  Future<void> _toggleEpisode(int season, int episode, bool watched) async {
    if (!await _requireFollowed()) return;
    HapticFeedback.selectionClick();
    final db = ref.read(databaseProvider);
    if (watched) {
      // Décocher ne propose jamais rien : on ne devine pas une régression.
      await db.setEpisodeUnwatched(widget.showId, season, episode);
      return;
    }

    // Calculé avant l'écriture : le flux des épisodes vus est asynchrone, et
    // la fenêtre ne dépend de toute façon que des épisodes antérieurs.
    final missing = findMissingEpisodesBetween(
      episodes: [
        for (final entry in _episodesBySeason.entries)
          for (final n in entry.value) (season: entry.key, episode: n),
      ],
      watchedKeys:
          ref.read(watchedKeysProvider(widget.showId)).value ?? const {},
      target: (season: season, episode: episode),
    );

    await db.setEpisodeWatched(widget.showId, season, episode);
    if (missing.isEmpty || !mounted) return;

    final all = await showCatchUpSheet(context, missing: missing);
    if (all != true) return;
    HapticFeedback.lightImpact();
    // Une seule transaction, donc une seule émission des flux : les coches
    // se mettent à jour ensemble plutôt qu'en cascade.
    await db.setEpisodesWatched(widget.showId, missing);
  }

  Future<void> _setSeason(int season, List<int> eps, bool on) async {
    if (!await _requireFollowed()) return;
    HapticFeedback.lightImpact();
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
            child: const Text('Annuler'),
          ),
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

    // Le noir Nitrate sous tout : le fond ambiant se peint par-dessus une
    // fois la fiche chargée, et l'attente n'est jamais transparente.
    return Scaffold(
      backgroundColor: TtColors.bg,
      body: _error != null
          ? DetailWithBack(
              child: EmptyState(icon: Icons.error_outline, message: _error!),
            )
          : _details == null
              // La forme de la fiche plutôt qu'un rond qui tourne : la mise en
              // page est connue d'avance, autant l'annoncer.
              ? const DetailWithBack(child: MediaDetailSkeleton())
              : _buildContent(followed),
    );
  }

  Widget _buildContent(bool followed) {
    final poster = TvdbClient.posterOf(_details!);
    final meta = [
      _yearOf(_details!),
      if (_totalEpisodes() case final n?) '$n épisodes',
      if (_networkOf(_details!) case final n when n.isNotEmpty) n,
      ..._genresOf(_details!).take(2),
    ].where((s) => s.isNotEmpty).join(' · ');

    return CinematicDetailShell(
      media: MediaRef(id: widget.showId, isSeries: true),
      seed: _name,
      backdrop: _backdrop,
      poster: poster,
      builder: (context, scope) => Stack(
        children: [
          // Le fond défile avec le contenu, les onglets prennent ensuite le
          // relais : c'est le rôle de NestedScrollView, qui accorde un
          // défilement extérieur à des listes intérieures.
          NestedScrollView(
            headerSliverBuilder: (context, _) => [
              CinematicBackdrop(
                title: _name,
                image: scope.image,
                seed: _name,
                icon: Icons.tv,
                palette: scope.palette,
              ),
            ],
            body: Column(
              children: [
                TabBar(
                  controller: _tabs,
                  labelColor: scope.palette.accent,
                  unselectedLabelColor: TtColors.dim,
                  indicatorColor: scope.palette.accent,
                  // Pas de trait sous les onglets : ce serait une ligne de
                  // coupe entre le fond et le contenu.
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                  tabs: const [
                    Tab(text: 'À propos'),
                    Tab(text: 'Épisodes'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _AboutTab(
                        metaLine: meta,
                        overview: _overview,
                        followed: followed,
                        accent: scope.palette.accent,
                        onAdd: _addToLibrary,
                        onOpenEpisodes: () => _tabs.animateTo(1),
                      ),
                      if (_loadingEpisodes)
                        _SeasonsSkeleton(tint: scope.palette.surface)
                      else if (_episodesError != null)
                        ErrorRetry(
                          title: 'Épisodes indisponibles',
                          message:
                              'Vérifie ta connexion pour charger les saisons.',
                          onRetry: () => _loadEpisodes(refresh: true),
                        )
                      else
                        _EpisodesTab(
                          showId: widget.showId,
                          showName: _name,
                          seasonNumbers: _seasonNumbers,
                          loadSeason: _loadSeason,
                          episodeName: (s, e) =>
                              _episodeNames[s]?[e] ?? 'Épisode $e',
                          onToggle: _toggleEpisode,
                          onSetSeason: _setSeason,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (followed)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 10, 0),
                  child: Semantics(
                    button: true,
                    label: 'Retirer de ma liste',
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.42),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _confirmDelete,
                          child: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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

// --------------------------------------------------------------- À propos

class _AboutTab extends StatelessWidget {
  const _AboutTab({
    required this.metaLine,
    required this.overview,
    required this.followed,
    required this.accent,
    required this.onAdd,
    required this.onOpenEpisodes,
  });

  final String metaLine;
  final String overview;
  final bool followed;
  final Color accent;
  final Future<bool> Function() onAdd;
  final VoidCallback onOpenEpisodes;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomNavInset(context)),
      children: [
        // Le titre vit sur le fond ; ici ne restent que ses informations.
        if (metaLine.isNotEmpty) ...[
          Text(
            metaLine,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: TtColors.dim,
            ),
          ),
          const SizedBox(height: 18),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: followed
              ? SizedBox(
                  width: 252,
                  child: ModernCommand(
                      shape: CommandShape.nextUp,
                      label: 'Voir les épisodes',
                      onPressed: onOpenEpisodes))
              : AddToListButton(
                  label: 'Ajouter à ma liste',
                  inLibrary: followed,
                  onAdd: onAdd,
                  failureMessage: 'Impossible d\'ajouter cette série.\n'
                      'Réessaie dans un instant.',
                ),
        ),
        const SizedBox(height: 26),
        const MediaSectionTitle('Synopsis'),
        const SizedBox(height: 8),
        if (overview.isEmpty)
          const Text(
            'Synopsis indisponible.',
            style: TextStyle(fontSize: 14.5, height: 1.6, color: TtColors.dim),
          )
        else
          ExpandableSynopsis(text: overview, accent: accent),
      ],
    );
  }
}

// --------------------------------------------------------------- Épisodes

class _EpisodesTab extends ConsumerWidget {
  const _EpisodesTab({
    required this.showId,
    required this.showName,
    required this.seasonNumbers,
    required this.loadSeason,
    required this.episodeName,
    required this.onToggle,
    required this.onSetSeason,
  });

  final int showId;
  final String showName;
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
            onOpen: (e) => context.push(
              '/episode/$showId/$n/$e',
              extra: {'name': showName},
            ),
            onToggle: (e, w) => onToggle(n, e, w),
            onSetSeason: (eps, on) => onSetSeason(n, eps, on),
          ),
      ],
    );
  }
}

/// Cartes de saison en attente : mêmes hauteurs, mêmes marges que les vraies,
/// pour que rien ne bouge quand la liste arrive.
class _SeasonsSkeleton extends StatelessWidget {
  const _SeasonsSkeleton({this.tint});

  /// Teinte de l'ambiance : l'attente s'accorde à la fiche sans s'éclaircir.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomNavInset(context)),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonBox(height: 92, radius: 12, tint: tint),
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
    required this.onOpen,
    required this.episodeName,
    required this.onToggle,
    required this.onSetSeason,
  });

  final int season;
  final Set<String> watchedKeys;
  final Future<List<int>> Function() loadEpisodes;
  final void Function(int episode) onOpen;
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

  int get _watchedInSeason => widget.watchedKeys
      .where((k) => k.startsWith('S${widget.season}E'))
      .length;

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
                        Text(
                          'Saison ${widget.season}',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          total != null
                              ? '$watched / $total vus'
                              : '$watched vus',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: TtColors.dim,
                          ),
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
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: TtColors.dim,
                  ),
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
        padding: EdgeInsets.fromLTRB(14, 6, 14, 14),
        child: Column(
          children: [
            SkeletonBox(height: 18, radius: 4),
            SizedBox(height: 12),
            SkeletonBox(height: 18, radius: 4),
            SizedBox(height: 12),
            SkeletonBox(width: 180, height: 18, radius: 4),
          ],
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          _error!,
          style: const TextStyle(fontSize: 13, color: TtColors.dim),
        ),
      );
    }
    if (eps == null || eps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'Aucun épisode.',
          style: TextStyle(fontSize: 13, color: TtColors.dim),
        ),
      );
    }
    return Column(
      children: [
        const Divider(height: 1, color: TtColors.surfaceHi),
        for (final e in eps)
          _EpisodeRow(
            number: e,
            onOpen: () => widget.onOpen(e),
            name: widget.episodeName(e),
            watched: widget.watchedKeys.contains('S${widget.season}E$e'),
            onTap: () => widget.onToggle(
              e,
              widget.watchedKeys.contains('S${widget.season}E$e'),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _SeasonCheck extends StatelessWidget {
  const _SeasonCheck({
    required this.allWatched,
    required this.enabled,
    this.onTap,
  });

  final bool allWatched;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label:
          allWatched ? 'Remettre la saison à non vue' : 'Marquer la saison vue',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: allWatched
                  ? TtColors.teal
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: allWatched
                    ? TtColors.teal
                    : Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              Icons.done_all,
              size: 20,
              color: allWatched ? const Color(0xFF0C1A15) : TtColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.number,
    required this.onOpen,
    required this.name,
    required this.watched,
    required this.onTap,
  });

  final int number;
  final VoidCallback onOpen;
  final String name;
  final bool watched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Cocher un épisode est le geste le plus fréquent de l'app : la coche se
    // remplit et le titre s'estompe ensemble, en un seul mouvement court.
    // Rien ne rebondit, rien ne grossit.
    final duration = motionOf(context, Motion.normal);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: duration,
              switchInCurve: Motion.enter,
              // Un fondu croisé entre le cercle vide et la coche pleine ;
              // pas de bascule sèche, pas de rebond.
              child: IconButton(
                tooltip: watched ? 'Marquer non vu' : 'Marquer vu',
                onPressed: onTap,
                icon: Icon(
                  watched ? Icons.check_circle : Icons.circle_outlined,
                  key: ValueKey(watched),
                  color: watched ? TtColors.amber : TtColors.dim,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: duration,
                curve: Motion.between,
                style: TextStyle(
                  fontSize: 14,
                  color: watched ? TtColors.dim : TtColors.text,
                  decoration: watched ? TextDecoration.lineThrough : null,
                  decorationColor: TtColors.dim,
                ),
                child: Text(
                  '$number. $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
