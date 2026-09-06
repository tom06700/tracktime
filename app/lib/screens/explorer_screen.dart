import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../profile/sections.dart' show watchlistItems;
import '../profile/tonight.dart';
import '../motion.dart';
import '../brand/nitrate_brand.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/modern_controls.dart';
import '../tmdb/add.dart';
import '../tmdb/search_result.dart';
import '../tmdb/tvdb.dart';
import '../widgets/common.dart';
import '../widgets/media_image.dart';
import '../widgets/states.dart';
import '../profile/profile.dart';

/// Ouvre la fiche du média. La navigation porte l'identifiant TheTVDB choisi,
/// jamais le titre : deux « One Piece » distincts doivent charger chacun le
/// leur.
void openMediaDetail(
  BuildContext context, {
  required int id,
  required bool isSeries,
  required String title,
}) =>
    context.push(isSeries ? '/show/$id' : '/movie/$id', extra: title);

/// Filtre appliqué aux résultats de recherche.
enum SearchFilter { all, series, movies }

/// Onglet Explorer : recherche TheTVDB, et — tant qu'on n'a rien tapé — une
/// page de découverte. L'écran ne doit jamais paraître vide : sans idée
/// précise, on doit pouvoir trouver quelque chose à ajouter.
class ExplorerScreen extends ConsumerStatefulWidget {
  const ExplorerScreen({super.key});

  @override
  ConsumerState<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends ConsumerState<ExplorerScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<MediaSearchResult> _results = const [];
  bool _loading = false;
  String? _error;
  SearchFilter _filter = SearchFilter.all;

  /// Jeton de la requête courante. Une réponse tardive portant un jeton
  /// périmé est ignorée : taper « One » puis « One Piece » ne doit pas laisser
  /// la première réponse écraser la seconde.
  int _requestToken = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _requestToken++;
    setState(() {}); // rafraîchit le bouton d'effacement
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    _debounce?.cancel();
    final q = query.trim();
    final token = ++_requestToken;

    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref.read(tvdbClientProvider).search(q);
      if (!mounted || token != _requestToken) return;
      setState(() {
        _results = rankSearchResults(parseSearchResults(raw), q);
        _loading = false;
      });
    } on TvdbException catch (e) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Le filtre s'applique localement : la requête a déjà tout ramené, inutile
  /// de rappeler l'API pour restreindre.
  List<MediaSearchResult> get _filtered => switch (_filter) {
        SearchFilter.all => _results,
        SearchFilter.series =>
          _results.where((r) => r.type == SearchMediaType.series).toList(),
        SearchFilter.movies =>
          _results.where((r) => r.type == SearchMediaType.movie).toList(),
      };

  @override
  Widget build(BuildContext context) {
    final searching = _controller.text.trim().isNotEmpty;
    final series = ref.watch(popularSeriesProvider),
        films = ref.watch(popularMoviesProvider),
        upcoming = ref.watch(upcomingReleasesProvider);
    final groups = [
      if (_filter != SearchFilter.movies)
        (
          title: 'Séries populaires',
          data: series,
          provider: popularSeriesProvider,
          type: SearchMediaType.series
        ),
      if (_filter != SearchFilter.series)
        (
          title: 'Films populaires',
          data: films,
          provider: popularMoviesProvider,
          type: SearchMediaType.movie
        ),
      if (_filter != SearchFilter.series)
        (
          title: 'Sorties annoncées',
          data: upcoming,
          provider: upcomingReleasesProvider,
          type: SearchMediaType.movie
        )
    ];
    final found = <String>{};
    final discovery = <MediaSearchResult>[];
    for (final g in groups) {
      for (final m in g.data.value ?? <Map<String, dynamic>>[]) {
        final id = (m['id'] as num?)?.toInt();
        final name = '${m['name'] ?? ''}';
        if (!found.add('${g.type}-$id-$name')) continue;
        discovery.add(MediaSearchResult(
            tvdbId: id,
            name: name,
            type: g.type,
            aliases: const [],
            image: m['image'] as String?,
            year: m['year']?.toString()));
      }
    }
    final items = searching ? _filtered : discovery;
    final featured = discovery
        .where((m) => m.type == SearchMediaType.series && m.tvdbId != null)
        .firstOrNull;
    final profile = ref.watch(profileProvider).value;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = scale > 1.6
        ? 1
        : MediaQuery.sizeOf(context).width > 600
            ? 3
            : 2;
    final width =
        (MediaQuery.sizeOf(context).width - 44 - (columns - 1) * 13) / columns;
    final tonight = watchlistItems(ref.watch(moviesProvider).value ?? [],
        ref.watch(showsProvider).value ?? []);
    return CustomScrollView(
        key: const PageStorageKey('explorer-feed'),
        slivers: [
          SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  22, MediaQuery.paddingOf(context).top + 20, 22, 0),
              sliver: SliverToBoxAdapter(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Row(children: [
                      const Expanded(child: NitrateWordmark(size: 22)),
                      IconButton.filledTonal(
                          tooltip: 'Ouvrir mon profil',
                          onPressed: () => ref
                              .read(homeTabProvider.notifier)
                              .select(HomeTab.profile),
                          style: IconButton.styleFrom(
                              backgroundColor: ModernPalette.lilac),
                          icon: Text(profile?.emoji ?? '🍿',
                              style: const TextStyle(fontSize: 20)))
                    ]),
                    const SizedBox(height: 27),
                    const Text('LA PROCHAINE HISTOIRE',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.7,
                            color: Color(0xFFC1ADC9))),
                    const SizedBox(height: 9),
                    const Text('Tu pars où ?',
                        style: TextStyle(
                            fontSize: 36,
                            height: 1.1,
                            letterSpacing: -1.7,
                            fontWeight: FontWeight.w400)),
                    const SizedBox(height: 11),
                    const Text('Films, séries et anime. Suis ton envie.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFFA79BAD))),
                    const SizedBox(height: 24),
                    TextField(
                        controller: _controller,
                        autocorrect: false,
                        textInputAction: TextInputAction.search,
                        onChanged: _onChanged,
                        onSubmitted: _search,
                        decoration: InputDecoration(
                            hintText: 'Un titre, une nouvelle obsession…',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _controller.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Effacer',
                                    onPressed: () {
                                      _controller.clear();
                                      _search('');
                                    },
                                    icon: const Icon(Icons.close)),
                            filled: true,
                            fillColor: const Color(0xFF25212C),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(21),
                                borderSide:
                                    const BorderSide(color: Color(0xFF41354E))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(21),
                                borderSide: const BorderSide(
                                    color: Color(0xFF41354E))))),
                    const SizedBox(height: 15),
                    GlideControl(
                        labels: const ['Tout', 'Séries', 'Films'],
                        index: _filter.index,
                        onSelected: (i) =>
                            setState(() => _filter = SearchFilter.values[i])),
                    const SizedBox(height: 22),
                    if (!searching && featured != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 23),
                          child: Material(
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                  onTap: () => openMediaDetail(context,
                                      id: featured.tvdbId!,
                                      isSeries: true,
                                      title: featured.name),
                                  child: SizedBox(
                                      height: 150,
                                      child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            MediaImage(
                                                sources: [featured.image],
                                                seed: featured.name,
                                                icon: Icons.tv),
                                            const DecoratedBox(
                                                decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                        colors: [
                                                  Color(0xE615141E),
                                                  Color(0x55000000)
                                                ]))),
                                            const Padding(
                                                padding: EdgeInsets.all(20),
                                                child: Row(children: [
                                                  Expanded(
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                        Text('À DÉCOUVRIR',
                                                            style: TextStyle(
                                                                fontSize: 9,
                                                                letterSpacing:
                                                                    1.5)),
                                                        SizedBox(height: 6),
                                                        Text(
                                                            'Change\nd’univers.',
                                                            style: TextStyle(
                                                                fontSize: 24,
                                                                height: 1.15,
                                                                letterSpacing:
                                                                    -.7))
                                                      ])),
                                                  Icon(Icons.north_east)
                                                ]))
                                          ]))))),
                    Row(children: [
                      Expanded(
                          child: Text(searching ? 'Résultats' : 'À explorer',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500))),
                      Text('${items.length} titres',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFB5A6C1)))
                    ]),
                    const SizedBox(height: 12),
                    if (searching && _error != null)
                      ErrorRetry(
                          title: 'Recherche indisponible',
                          message: 'Vérifie ta connexion et réessaie.',
                          onRetry: () => _search(_controller.text)),
                    if (!searching)
                      for (final g in groups)
                        if (g.data.hasError)
                          ListTile(
                              title: Text(g.title),
                              subtitle: const Text('Chargement indisponible'),
                              trailing: IconButton(
                                  tooltip: 'Réessayer : ${g.title}',
                                  onPressed: () => ref.invalidate(g.provider),
                                  icon: const Icon(Icons.refresh))),
                    if (searching
                        ? _loading
                        : groups.any((g) => g.data.isLoading))
                      const Padding(
                          padding: EdgeInsets.all(20),
                          child: LinearProgressIndicator()),
                    if (items.isEmpty &&
                        !(searching
                            ? _loading
                            : groups.any((g) => g.data.isLoading)))
                      Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              searching
                                  ? 'Aucun résultat. Essaie une autre orthographe.'
                                  : 'Aucun titre disponible pour le moment.',
                              textAlign: TextAlign.center)),
                  ]))),
          SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 13,
                      mainAxisSpacing: 23,
                      mainAxisExtent: width * 1.325 + 72 * scale),
                  itemCount: items.length,
                  itemBuilder: (context, i) => EntranceFade(
                      key: ValueKey(
                          '${items[i].type}-${items[i].tvdbId}-${items[i].name}'),
                      child: _CatalogueCard(result: items[i])))),
          if (!searching && tonight.length >= 2)
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: ModernCommand(
                        shape: CommandShape.surprise,
                        label: 'Quoi regarder ce soir ?',
                        subtitle: 'Dans ta propre collection',
                        onPressed: () => showTonightPicker(context, tonight)))),
          SliverToBoxAdapter(child: SizedBox(height: bottomNavInset(context))),
        ]);
  }
}

class _CatalogueCard extends ConsumerWidget {
  const _CatalogueCard({required this.result});
  final MediaSearchResult result;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = result, isSeries = r.type == SearchMediaType.series;
    final already = isSeries
        ? (ref.watch(showsProvider).value ?? [])
            .any((s) => s.show.id == r.tvdbId)
        : (ref.watch(moviesProvider).value ?? []).any((m) => m.id == r.tvdbId);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(
          aspectRatio: 2 / 2.65,
          child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(fit: StackFit.expand, children: [
                Semantics(
                    button: true,
                    label: 'Ouvrir la fiche de ${r.name}',
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: r.tvdbId == null
                            ? null
                            : () => openMediaDetail(context,
                                id: r.tvdbId!,
                                isSeries: isSeries,
                                title: r.name),
                        child: MediaImage(
                            sources: [r.image],
                            seed: r.name,
                            icon: isSeries ? Icons.tv : Icons.movie_outlined))),
                if (r.canAdd)
                  Positioned(
                      right: 9,
                      bottom: 9,
                      child: AddButton(
                          id: r.tvdbId!,
                          isSeries: isSeries,
                          name: r.name,
                          already: already,
                          compact: true)),
              ]))),
      const SizedBox(height: 9),
      Text(r.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, height: 1.3)),
      const SizedBox(height: 4),
      Text(
          [
            isSeries ? 'Série' : 'Film',
            if (r.year != null) r.year!,
            if (r.originalName != null) r.originalName!
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: Color(0xFFA397AE))),
    ]);
  }
}

/// Bouton d'ajout, du « + » à la coche. Il dit explicitement « Ajouté » plutôt
/// que d'afficher une icône sans contexte.
class AddButton extends ConsumerStatefulWidget {
  const AddButton({
    super.key,
    required this.id,
    required this.isSeries,
    required this.name,
    required this.already,
    this.compact = false,
  });

  final int id;
  final bool isSeries;
  final String name;
  final bool already;

  /// Sur une affiche de découverte : pastille ronde, sans libellé.
  final bool compact;

  @override
  ConsumerState<AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends ConsumerState<AddButton> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy || widget.already) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    final tvdb = ref.read(tvdbClientProvider);
    try {
      if (widget.isSeries) {
        await addShowFromTvdb(db, tvdb, widget.id);
      } else {
        await addMovieFromTvdb(db, tvdb, widget.id);
      }
    } on TvdbException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 200);

    final label = widget.already
        ? 'Déjà dans ta liste : ${widget.name}'
        : 'Ajouter ${widget.name}';

    Widget content;
    if (_busy) {
      content = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: TtColors.amber),
      );
    } else if (widget.already) {
      content = widget.compact
          ? const Icon(Icons.check, size: 18, color: ModernPalette.lilac)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check, size: 17, color: TtColors.bg),
                SizedBox(width: 5),
                Text(
                  'Ajouté',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: TtColors.bg,
                  ),
                ),
              ],
            );
    } else {
      content = Icon(
        Icons.add,
        size: widget.compact ? 18 : 20,
        color: const Color(0xFF332144),
      );
    }

    return Semantics(
      button: !widget.already,
      label: label,
      child: GestureDetector(
        onTap: widget.already ? null : _add,
        child: SizedBox(
          width: widget.already && !widget.compact ? 96 : 44,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              padding: widget.compact || widget.already && !widget.compact
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
                  : const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: widget.already
                    ? const Color(0xED1A1A21)
                    : ModernPalette.lilac,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.already
                      ? TtColors.amber
                      : TtColors.amber.withValues(alpha: 0.55),
                ),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
