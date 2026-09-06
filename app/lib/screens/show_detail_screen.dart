import '../widgets/validated_detail.dart';
import '../widgets/modern_controls.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db/database.dart';
import '../providers.dart';
import '../motion.dart';
import '../series/catch_up.dart';
import '../series/widgets/catch_up_sheet.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../tmdb/tvdb.dart';
import 'movie_detail_screen.dart' show DetailWithBack, MediaDetailSkeleton;
import '../widgets/common.dart';
import '../widgets/states.dart';
import 'media_detail_parts.dart' show addSeriesToLibrary;

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

class _ShowDetailScreenState extends ConsumerState<ShowDetailScreen> {
  int _tab = 0;
  int? _selectedSeason;
  bool _onlyUnseen = false;
  bool _busy = false;
  final Map<int, Map<int, DateTime?>> _episodeDates = {};
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

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// Saisons officielles déclarées par `/series/{id}/extended`, y compris les spéciaux en saison 0.
  static List<int> _officialSeasons(Map<String, dynamic> d) {
    final out = <int>{};
    for (final s in (d['seasons'] as List?) ?? const []) {
      if (s is! Map) continue;
      final n = (s['number'] as num?)?.toInt();
      if ((s['type'] as Map?)?['type'] == 'official' && n != null && n >= 0) {
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
        if (s < 0) continue;
        final n = e['episode'] as int;
        (bySeason[s] ??= []).add(n);
        (names[s] ??= {})[n] = '${e['name'] ?? 'Épisode $n'}';
        (_episodeDates[s] ??= {})[n] = DateTime.tryParse('${e['aired'] ?? ''}');
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
      for (final key in bySeason.keys.toList()) {
        bySeason[key] = bySeason[key]!.toSet().toList()..sort();
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
    await ref
        .read(databaseProvider)
        .setSeasonWatched(widget.showId, season, eps, on);
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
              child: ErrorRetry(
                  title: 'Impossible de charger cette série',
                  message: _error!,
                  onRetry: _load),
            )
          : _details == null
              // La forme de la fiche plutôt qu'un rond qui tourne : la mise en
              // page est connue d'avance, autant l'annoncer.
              ? const DetailWithBack(child: MediaDetailSkeleton())
              : _buildContent(followed),
    );
  }

  Widget _buildContent(bool followed) {
    final watched =
        ref.watch(watchedKeysProvider(widget.showId)).value ?? <String>{};
    final all = [
      for (final s in _seasonNumbers)
        for (final e in _episodesBySeason[s] ?? <int>[]) (season: s, episode: e)
    ];
    final seen =
        all.where((e) => watched.contains('S${e.season}E${e.episode}')).length;
    final next = all.where((e) {
      final air = _episodeDates[e.season]?[e.episode];
      return !watched.contains('S${e.season}E${e.episode}') &&
          (air == null || !air.isAfter(DateTime.now()));
    }).firstOrNull;
    final selected =
        _selectedSeason ?? next?.season ?? _seasonNumbers.firstOrNull;
    final numbers = _episodesBySeason[selected] ?? <int>[];
    final visible = numbers
        .where((e) => !_onlyUnseen || !watched.contains('S${selected}E$e'))
        .toList();
    final gap = MediaQuery.sizeOf(context).width < 370 ? 18.0 : 24.0;
    Widget padded(Widget child, {double bottom = 0}) => Padding(
        padding: EdgeInsets.fromLTRB(gap, 0, gap, bottom), child: child);
    void open(int s, int e) => context.push('/episode/${widget.showId}/$s/$e',
        extra: {'name': _name, 'poster': TvdbClient.posterOf(_details!)});
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child: ValidatedDetailHero(
              title: _name,
              kicker: _genresOf(_details!).take(2).join(' · '),
              subtitle: [_yearOf(_details!), _networkOf(_details!)]
                  .where((x) => x.isNotEmpty)
                  .join(' · '),
              sources: [TvdbClient.posterOf(_details!), _backdrop],
              onManage: () => _manage(followed))),
      SliverToBoxAdapter(
          child: padded(
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: Text(followed ? '•  Dans ta collection' : '•  À découvrir',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFFACA6B5)))),
          SizedBox(
              width: 116,
              child: ModernCommand(
                  shape: CommandShape.attach,
                  height: 44,
                  compact: true,
                  selected: followed,
                  label: followed ? 'Ajouté' : 'Ma liste',
                  onPressed: followed
                      ? () {}
                      : () => _guard(() async {
                            if (!await _addToLibrary()) {
                              throw StateError('Ajout impossible');
                            }
                          }))),
        ]),
        const SizedBox(height: 26),
        Row(children: [
          const Expanded(
              child: Text('Ton voyage',
                  style: TextStyle(fontSize: 11, color: Color(0xFFC9C4D0)))),
          Text(
              all.isEmpty
                  ? 'Progression à charger'
                  : '$seen / ${all.length} vus',
              style: const TextStyle(fontSize: 11, color: ModernPalette.lime))
        ]),
        const SizedBox(height: 11),
        TweenAnimationBuilder<double>(
            tween: Tween(end: all.isEmpty ? 0 : seen / all.length),
            duration: motionOf(context, const Duration(milliseconds: 650)),
            curve: const Cubic(.2, .8, .2, 1),
            builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                color: ModernPalette.lime,
                backgroundColor: const Color(0xFF2D2E31),
                semanticsLabel:
                    'Progression de la série : $seen sur ${all.length}')),
        const SizedBox(height: 9),
        Text(
            all.isEmpty
                ? 'Les épisodes officiels apparaîtront ici.'
                : '${all.length - seen} épisodes à retrouver',
            style: const TextStyle(fontSize: 11, color: Color(0xFF908B98))),
        const SizedBox(height: 26),
        ModernCommand(
            shape: CommandShape.nextUp,
            height: 105,
            eyebrow: 'ON EN ÉTAIT LÀ',
            labelSize: 22,
            label: !followed
                ? 'Commencer'
                : next == null
                    ? 'Explorer les épisodes'
                    : 'Reprendre',
            subtitle: next == null
                ? null
                : 'Saison ${next.season} · Épisode ${next.episode}',
            onPressed: _busy
                ? null
                : () async {
                    if (!followed) {
                      await _offerAdd();
                      return;
                    }
                    if (!_episodesRequested) await _loadEpisodes();
                    if (!mounted) return;
                    if (next != null) {
                      open(next.season, next.episode);
                    } else {
                      _selectTab(1);
                    }
                  }),
        const SizedBox(height: 26),
        GlideControl(
            dense: true,
            labels: const ['À propos', 'Épisodes'],
            index: _tab,
            onSelected: _selectTab),
        const SizedBox(height: 22),
      ]))),
      if (_tab == 0)
        SliverToBoxAdapter(
            child: padded(EntranceFade(
                key: const ValueKey('series-about'),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DetailSectionHeading('L’histoire',
                          hint: 'Le début, sans spoiler'),
                      const SizedBox(height: 12),
                      Text(
                          _overview.isEmpty
                              ? 'Synopsis indisponible.'
                              : _overview,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.85,
                              color: Color(0xFFB6AFBF))),
                      const SizedBox(height: 22),
                      if (selected != null)
                        Material(
                            color: const Color(0xFF1D1C23),
                            borderRadius: BorderRadius.circular(21),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                                contentPadding: const EdgeInsets.all(17),
                                onTap: () => _selectTab(1),
                                title: Text(
                                    selected == 0
                                        ? 'Épisodes spéciaux'
                                        : 'Saison $selected',
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500)),
                                subtitle: Text(
                                    '${numbers.where((e) => !watched.contains('S${selected}E$e')).length} épisodes non vus',
                                    style: const TextStyle(fontSize: 11)),
                                trailing: const Icon(Icons.arrow_forward,
                                    color: ModernPalette.lilac))),
                    ])))),
      if (_tab == 1) ...[
        SliverToBoxAdapter(
            child: padded(Column(children: [
          if (_loadingEpisodes) const LinearProgressIndicator(),
          if (_episodesError != null)
            ErrorRetry(
                title: 'Épisodes indisponibles',
                message: 'Réessaie pour charger les saisons.',
                onRetry: () => _loadEpisodes(refresh: true)),
          if (selected != null)
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<int>(
                      initialValue: selected,
                      key: ValueKey(selected),
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Saison'),
                      items: [
                        for (final s in _seasonNumbers)
                          DropdownMenuItem(
                              value: s,
                              child: Text(s == 0 ? 'Spéciaux' : 'Saison $s'))
                      ],
                      onChanged: _busy
                          ? null
                          : (s) => setState(() => _selectedSeason = s))),
              const SizedBox(width: 10),
              Flexible(
                  child: TextButton(
                      onPressed: _busy || numbers.isEmpty
                          ? null
                          : () => _confirmSeason(selected, numbers, watched),
                      child: Text(
                          numbers.every(
                                  (e) => watched.contains('S${selected}E$e'))
                              ? 'Tout marquer non vu'
                              : 'Tout marquer vu',
                          style: const TextStyle(
                              color: ModernPalette.lilac, fontSize: 11))))
            ]),
          const SizedBox(height: 13),
          Row(children: [
            ChoiceChip(
                label: const Text('Tous'),
                selected: !_onlyUnseen,
                onSelected: (_) => setState(() => _onlyUnseen = false)),
            const SizedBox(width: 7),
            ChoiceChip(
                label: const Text('Non vus'),
                selected: _onlyUnseen,
                onSelected: (_) => setState(() => _onlyUnseen = true)),
            const Spacer(),
            IconButton(
                tooltip: 'Aller à un numéro',
                onPressed:
                    selected == null ? null : () => _jump(selected, numbers),
                icon: const Icon(Icons.search))
          ]),
          if (!_loadingEpisodes && _episodesError == null && visible.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun épisode à afficher.')),
        ]))),
        SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: gap),
            sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final e = visible[i],
                      isSeen = watched.contains('S${selected}E$e');
                  return _OfficialEpisodeRow(
                      number: e,
                      name: _episodeNames[selected]?[e] ?? 'Épisode $e',
                      seen: isSeen,
                      onOpen: () => open(selected!, e),
                      onToggle: _busy
                          ? null
                          : () => _guard(
                              () => _toggleEpisode(selected!, e, isSeen)));
                })),
      ],
      SliverToBoxAdapter(
          child: Padding(
              padding:
                  EdgeInsets.fromLTRB(gap, 20, gap, bottomNavInset(context)),
              child: const Text('Ta progression reste entre tes mains.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFFA79CAB))))),
    ]);
  }

  void _selectTab(int value) {
    setState(() => _tab = value);
    if (value == 1) _loadEpisodes();
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Modification impossible. Réessaie.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offerAdd() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Ajouter à ma liste'),
                content: Text(
                    'Ajoute « $_name » à ta collection pour suivre ses épisodes.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Ajouter'))
                ]));
    if (yes == true && mounted) {
      await _guard(() async {
        if (!await _addToLibrary()) throw StateError('Ajout impossible');
      });
    }
  }

  Future<void> _manage(bool followed) async {
    if (_busy) return;
    if (!followed) {
      await _offerAdd();
      return;
    }
    await _confirmDelete();
  }

  Future<void> _confirmSeason(
      int season, List<int> numbers, Set<String> watched) async {
    if (!await _requireFollowed() || !mounted) return;
    final missing =
        numbers.where((e) => !watched.contains('S${season}E$e')).toList();
    final clear = missing.isEmpty;
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(clear
                    ? 'Recommencer la saison $season ?'
                    : 'Terminer la saison $season ?'),
                content: Text(clear
                    ? '${numbers.length} visionnages de cette saison seront retirés de ton historique.'
                    : '${missing.length} épisodes non vus seront marqués vus. Les visionnages existants sont conservés.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Confirmer'))
                ]));
    if (yes == true && mounted) {
      await _guard(() => _setSeason(season, clear ? numbers : missing, !clear));
    }
  }

  Future<void> _jump(int season, List<int> numbers) async {
    final controller = TextEditingController();
    String? error;
    final number = await showDialog<int>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, change) => AlertDialog(
                    title: const Text('Aller à un épisode'),
                    content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: 'Numéro dans la saison $season',
                            errorText: error)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annuler')),
                      FilledButton(
                          onPressed: () {
                            final n = int.tryParse(controller.text.trim());
                            if (n == null || !numbers.contains(n)) {
                              change(() => error =
                                  'Ce numéro n’existe pas dans cette saison.');
                              return;
                            }
                            Navigator.pop(ctx, n);
                          },
                          child: const Text('Ouvrir la fiche'))
                    ])));
    // Let the dialog finish its reverse transition before disposing its field.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (number != null && mounted) {
      context.push('/episode/${widget.showId}/$season/$number',
          extra: {'name': _name});
    }
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

class _OfficialEpisodeRow extends StatelessWidget {
  const _OfficialEpisodeRow(
      {required this.number,
      required this.name,
      required this.seen,
      required this.onOpen,
      required this.onToggle});
  final int number;
  final String name;
  final bool seen;
  final VoidCallback onOpen;
  final VoidCallback? onToggle;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF29262E)))),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(
                child: InkWell(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 3),
                        child: Row(children: [
                          Container(
                              constraints: const BoxConstraints(minWidth: 49),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 5),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF222027),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('$number',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFFA89BB9)))),
                          const SizedBox(width: 11),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFECE6F5))),
                                Text(seen ? 'Vu' : 'À découvrir',
                                    style: const TextStyle(
                                        fontSize: 10, color: Color(0xFF9A90A6)))
                              ]))
                        ])))),
            const SizedBox(width: 9),
            TweenAnimationBuilder<double>(
                tween: Tween(end: seen ? 1 : 0),
                duration: motionOf(context, const Duration(milliseconds: 500)),
                curve: const Cubic(.2, 1.5, .3, 1),
                builder: (context, t, child) =>
                    Transform.rotate(angle: t * 6.283185, child: child),
                child: IconButton.filledTonal(
                    key: ValueKey('series-episode-check-$number'),
                    onPressed: onToggle,
                    tooltip: seen ? 'Marquer non vu' : 'Marquer vu',
                    style: IconButton.styleFrom(
                        backgroundColor:
                            seen ? ModernPalette.lime : const Color(0xFF27292A),
                        foregroundColor: seen
                            ? const Color(0xFF334523)
                            : const Color(0xFF92988C)),
                    icon: const Icon(Icons.check, size: 18))),
          ])));
}
