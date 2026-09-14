import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../profile/sections.dart' show watchlistItems;
import '../profile/tonight.dart';
import '../motion.dart';
import '../movies/confirm_removal.dart';
import '../widgets/nitrate_home_button.dart';
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
import '../widgets/nitrate_banner.dart';

/// Ouvre la fiche du média. La navigation porte l'identifiant TheTVDB choisi,
/// jamais le titre : deux « One Piece » distincts doivent charger chacun le
/// leur.
void openMediaDetail(
  BuildContext context, {
  required int id,
  required bool isSeries,
  required String title,
}) => context.push(isSeries ? '/show/$id' : '/movie/$id', extra: title);

/// Filtre appliqué aux résultats de recherche.
enum SearchFilter { all, series, movies, anime }

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
  final _scroll = ScrollController();
  final _brandKey = GlobalKey();
  String? _selection;
  double _discoveryOffset = 0;
  Set<int>? _excludedShows, _excludedMovies;

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
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _requestToken++;
    if (_scroll.hasClients) {
      final brand = _brandKey.currentContext?.findRenderObject() as RenderSliver?;
      final headerExtent = brand?.geometry?.scrollExtent ?? 84;
      // Show the first results while preserving the field’s current position,
      // including when it was already pinned during discovery.
      _scroll.jumpTo(_scroll.offset.clamp(0, headerExtent));
    }
    setState(() {
      _results = const [];
      _error = null;
      _loading = value.trim().isNotEmpty;
    });
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
      final client = ref.read(tvdbClientProvider);
      final raw = _filter == SearchFilter.anime
          ? await client.searchAnime(q)
          : await client.search(q);
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

  /// Séries et films se filtrent localement. Animés enrichit si nécessaire
  /// les genres absents du moteur de recherche avant de filtrer.
  List<MediaSearchResult> get _filtered => switch (_filter) {
    SearchFilter.all => _results,
    SearchFilter.anime => _results.where((r) => r.isAnime).toList(),
    SearchFilter.series =>
      _results.where((r) => r.type == SearchMediaType.series).toList(),
    SearchFilter.movies =>
      _results.where((r) => r.type == SearchMediaType.movie).toList(),
  };

  void _returnToDiscovery() {
    setState(() => _selection = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(
          _discoveryOffset.clamp(0, _scroll.position.maxScrollExtent),
        );
      }
    });
  }

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  List<MediaSearchResult> _catalogue(
    AsyncValue<List<Map<String, dynamic>>> data,
    SearchMediaType type,
  ) {
    final found = <String>{};
    final series = type == SearchMediaType.series;
    final shows = ref.watch(showsProvider);
    final movies = ref.watch(moviesProvider);
    final known = series
        ? (shows.value ?? []).map((s) => s.show.id).toSet()
        : (movies.value ?? []).map((m) => m.id).toSet();
    // Exclude the collection as it stood when this visit began. An addition
    // must stay under the finger long enough to show its confirmed state.
    if (series && shows.hasValue) _excludedShows ??= known;
    if (!series && movies.hasValue) _excludedMovies ??= known;
    final excluded =
        (series ? _excludedShows : _excludedMovies) ?? const <int>{};
    return [
      for (final m in data.value ?? <Map<String, dynamic>>[])
        if (!(known.contains(m['id']) && excluded.contains(m['id'])) &&
            found.add('${m['id']}-${m['name']}'))
          MediaSearchResult(
            tvdbId: (m['id'] as num?)?.toInt(),
            name: '${m['name'] ?? ''}',
            type: type,
            aliases: const [],
            isAnime: _filter == SearchFilter.anime,
            image: m['image'] as String?,
            year: m['year']?.toString(),
          ),
    ].take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeTabProvider, (previous, next) {
      if (previous != HomeTab.explorer && next == HomeTab.explorer) {
        setState(() {
          _excludedShows = null;
          _excludedMovies = null;
        });
      }
    });
    final searching = _controller.text.trim().isNotEmpty;
    final anime = _filter == SearchFilter.anime;
    final seriesProvider = anime
        ? recentAnimeSeriesProvider
        : recentSeriesProvider;
    final filmsProvider = anime
        ? recentAnimeMoviesProvider
        : recentMoviesProvider;
    final groups = [
      if (_filter != SearchFilter.movies)
        (
          title: anime ? 'Nouveaux animés' : 'Nouvelles séries',
          data: ref.watch(seriesProvider),
          provider: seriesProvider,
          type: SearchMediaType.series,
        ),
      if (_filter != SearchFilter.series)
        (
          title: anime ? 'Films animés récents' : 'Films récents',
          data: ref.watch(filmsProvider),
          provider: filmsProvider,
          type: SearchMediaType.movie,
        ),
    ];
    final selected = groups.where((g) => g.title == _selection).firstOrNull;
    final grid = searching || selected != null;
    final items = searching
        ? _filtered
        : selected == null
        ? <MediaSearchResult>[]
        : _catalogue(selected.data, selected.type);
    final loading = searching ? _loading : selected?.data.isLoading ?? false;
    final profile = ref.watch(profileProvider).value;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = scale > 1.6
        ? 1
        : screenWidth > 600
        ? 3
        : 2;
    final width = (screenWidth - 44 - (columns - 1) * 13) / columns;
    final railWidth = (screenWidth * .35).clamp(132.0, 180.0);
    final tonight = watchlistItems(
      ref.watch(moviesProvider).value ?? [],
      ref.watch(showsProvider).value ?? [],
    );
    final active = TickerMode.valuesOf(context).enabled;
    return PopScope(
      canPop: !active || !grid,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !active) return;
        if (searching) {
          _controller.clear();
          _search('');
          FocusScope.of(context).unfocus();
        } else {
          _returnToDiscovery();
        }
      },
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const PageStorageKey('explorer-feed'),
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              key: _brandKey,
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(child: NitrateHomeButton()),
                    IconButton.filledTonal(
                      tooltip: 'Ouvrir mon profil',
                      onPressed: () => ref
                          .read(homeTabProvider.notifier)
                          .select(HomeTab.profile),
                      style: IconButton.styleFrom(
                        backgroundColor: ModernPalette.lilac,
                      ),
                      icon: Text(
                        profile?.emoji ?? '🍿',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PinnedHeaderSliver(
              key: const ValueKey('explorer-search-header'),
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _controller,
                        autocorrect: false,
                        textInputAction: TextInputAction.search,
                        onChanged: _onChanged,
                        onSubmitted: _search,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un film, une série',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 21,
                          ),
                          suffixIcon: _controller.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Effacer',
                                  onPressed: () {
                                    _controller.clear();
                                    _toTop();
                                    _search('');
                                  },
                                  icon: const Icon(Icons.close, size: 20),
                                ),
                          filled: true,
                          fillColor: const Color(0xFF25212C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(19),
                            borderSide: const BorderSide(
                              color: Color(0xFF41354E),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(19),
                            borderSide: const BorderSide(
                              color: Color(0xFF41354E),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 17,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final minimumWidth = 4 * (50 * scale + 16);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: constraints.maxWidth < minimumWidth
                                  ? minimumWidth
                                  : constraints.maxWidth,
                              child: GlideControl(
                                dense: true,
                                labels: const [
                                  'Tout',
                                  'Séries',
                                  'Films',
                                  'Animés',
                                ],
                                index: _filter.index,
                                onSelected: (i) {
                                  _toTop();
                                  final previous = _filter;
                                  setState(() {
                                    _filter = SearchFilter.values[i];
                                    _selection = null;
                                  });
                                  if (searching &&
                                      (previous == SearchFilter.anime ||
                                          _filter == SearchFilter.anime)) {
                                    _results = const [];
                                    _search(_controller.text);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (grid) ...[
              PinnedHeaderSliver(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                    child: Row(
                      children: [
                        if (!searching)
                          IconButton(
                            tooltip: 'Retour à la découverte',
                            onPressed: _returnToDiscovery,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 21,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            searching ? 'Résultats' : selected!.title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!loading)
                          Text(
                            '${items.length} titres',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFB5A6C1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (searching && _error != null)
                        ErrorRetry(
                          title: 'Recherche indisponible',
                          message: 'Vérifie ta connexion et réessaie.',
                          onRetry: () => _search(_controller.text),
                        ),
                      if (!searching && selected!.data.hasError)
                        ErrorRetry(
                          title: 'Chargement indisponible',
                          message: 'Vérifie ta connexion et réessaie.',
                          onRetry: () => ref.invalidate(selected.provider),
                        ),
                      if (items.isEmpty &&
                          !loading &&
                          _error == null &&
                          !(selected?.data.hasError ?? false))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Text(
                            searching
                                ? 'Aucun résultat. Essaie une autre orthographe.'
                                : 'Pas de nouveauté à découvrir pour le moment.\nTu peux rechercher un titre en haut.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 13,
                    mainAxisSpacing: 23,
                    mainAxisExtent: width * 1.325 + 72 * scale,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => EntranceFade(
                    key: ValueKey(
                      '${items[i].type}-${items[i].tvdbId}-${items[i].name}',
                    ),
                    child: _CatalogueCard(
                      result: items[i],
                      localizeTitle: !searching,
                    ),
                  ),
                ),
              ),
            ] else ...[
              if (tonight.length >= 2)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                    child: ModernCommand(
                      shape: CommandShape.surprise,
                      label: 'Que regarder ce soir ?',
                      subtitle: 'Dans ta propre collection',
                      onPressed: () => showTonightPicker(context, tonight),
                    ),
                  ),
                ),
              for (final g in groups)
                if (g.data.isLoading ||
                    g.data.hasError ||
                    _catalogue(g.data, g.type).isNotEmpty)
                  SliverToBoxAdapter(
                    child: _DiscoveryRail(
                      title: g.title,
                      items: _catalogue(g.data, g.type),
                      loading: g.data.isLoading,
                      hasError: g.data.hasError,
                      onRetry: () => ref.invalidate(g.provider),
                      width: railWidth,
                      scale: scale,
                      onSeeAll: () {
                        _discoveryOffset = _scroll.hasClients
                            ? _scroll.offset
                            : 0;
                        _toTop();
                        setState(() => _selection = g.title);
                      },
                    ),
                  ),
              if (groups.every(
                (g) =>
                    !g.data.isLoading &&
                    !g.data.hasError &&
                    _catalogue(g.data, g.type).isEmpty,
              ))
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Pas de nouveauté à découvrir pour le moment.\nTu peux rechercher un titre en haut.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(height: bottomNavInset(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryRail extends StatelessWidget {
  const _DiscoveryRail({
    required this.title,
    required this.items,
    required this.loading,
    required this.hasError,
    required this.onRetry,
    required this.width,
    required this.scale,
    required this.onSeeAll,
  });
  final String title;
  final List<MediaSearchResult> items;
  final bool loading, hasError;
  final VoidCallback onRetry, onSeeAll;
  final double width, scale;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 14, 6),
          child: Flex(
            direction: scale > 1.4 ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: scale > 1.4
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: scale > 1.4 ? 0 : 1,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -.5,
                  ),
                ),
              ),
              if (items.isNotEmpty)
                Tooltip(
                  message: 'Tout voir : $title',
                  child: TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      foregroundColor: ModernPalette.lilac,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text(
                      'Tout voir',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 8, 22, 20),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ErrorRetry(
              title: 'Chargement indisponible',
              message: 'Vérifie ta connexion et réessaie.',
              onRetry: onRetry,
            ),
          ),
        if (items.isNotEmpty)
          SizedBox(
            height: width * 1.325 + 72 * scale,
            child: ListView.separated(
              key: PageStorageKey('explorer-rail-$title'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 13),
              itemBuilder: (context, i) => SizedBox(
                width: width,
                child: EntranceFade(
                  key: ValueKey(
                    '${items[i].type}-${items[i].tvdbId}-${items[i].name}',
                  ),
                  child: _CatalogueCard(result: items[i], localizeTitle: true),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// Chargement paresseux : seules les affiches montées demandent une traduction.
final _catalogueTitleProvider =
    FutureProvider.family<
      String?,
      ({int id, bool movies, bool englishFallback})
    >((ref, key) async {
      final client = ref.watch(tvdbClientProvider);
      for (final language in ['fra', if (key.englishFallback) 'eng']) {
        final data = key.movies
            ? await client.movieTranslation(key.id, language)
            : await client.seriesTranslation(key.id, language);
        final name = '${data['name'] ?? ''}'.trim();
        if (name.isNotEmpty) return name;
      }
      return null;
    });

class _CatalogueCard extends ConsumerWidget {
  const _CatalogueCard({required this.result, this.localizeTitle = false});
  final MediaSearchResult result;
  final bool localizeTitle;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = result, isSeries = r.type == SearchMediaType.series;
    final nonLatinTitle = RegExp(
      r'[\u3040-\u30ff\u3400-\u9fff]',
    ).hasMatch(r.name);
    final translated = r.tvdbId != null && (localizeTitle || nonLatinTitle)
        ? ref
              .watch(
                _catalogueTitleProvider((
                  id: r.tvdbId!,
                  movies: !isSeries,
                  englishFallback: nonLatinTitle,
                )),
              )
              .value
        : null;
    final name = translated ?? r.name;
    final already = isSeries
        ? (ref.watch(showsProvider).value ?? []).any(
            (s) => s.show.id == r.tvdbId,
          )
        : (ref.watch(moviesProvider).value ?? []).any((m) => m.id == r.tvdbId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 2 / 2.65,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  button: true,
                  label: 'Ouvrir la fiche de $name',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: r.tvdbId == null
                        ? null
                        : () => openMediaDetail(
                            context,
                            id: r.tvdbId!,
                            isSeries: isSeries,
                            title: name,
                          ),
                    child: MediaImage(
                      sources: [r.image],
                      seed: r.name,
                      icon: isSeries ? Icons.tv : Icons.movie_outlined,
                    ),
                  ),
                ),
                if (r.canAdd)
                  Positioned(
                    right: 9,
                    bottom: 9,
                    child: AddButton(
                      id: r.tvdbId!,
                      isSeries: isSeries,
                      name: name,
                      already: already,
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [
            r.isAnime
                ? (isSeries ? 'Animé' : 'Film animé')
                : (isSeries ? 'Série' : 'Film'),
            if (r.year != null) r.year!,
            if (r.originalName != null) r.originalName!,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: Color(0xFFA397AE)),
        ),
      ],
    );
  }
}

/// Bascule la présence dans la collection, du « + » à la coche et inversement.
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

  Future<void> _remove() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    final messenger = NitrateMessenger.of(context);
    final id = widget.id, isSeries = widget.isSeries;
    final name = widget.name;
    try {
      if (isSeries) {
        final watched = await db.hasWatchedEpisodes(id);
        if (!mounted) return;
        if (watched) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Retirer « $name » ?'),
              content: const Text(
                'La série et sa progression seront supprimées.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: TtColors.danger,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Retirer'),
                ),
              ],
            ),
          );
          if (confirmed != true || !mounted) return;
        }
        await db.deleteShow(id);
      } else {
        final movie = await db.movieById(id);
        if (!mounted || movie == null) return;
        if (movie.watchedAt != null) {
          final confirmed = await confirmMovieRemoval(context, movie);
          if (!confirmed || !mounted) return;
        }
        await db.deleteMovie(id);
      }
      if (messenger.mounted) {
        messenger.showBanner(
          NitrateBanner(
            kind: NitrateBannerKind.success,
            content: Text(
              isSeries
                  ? '$name retirée de Mes séries'
                  : '$name retiré de mes films',
              style: const TextStyle(color: Colors.white),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (messenger.mounted) {
        messenger.showBanner(
          const NitrateBanner(
            kind: NitrateBannerKind.error,
            content: Text(
              'Impossible de retirer ce titre. Réessaie.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    if (_busy || widget.already) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    final tvdb = ref.read(tvdbClientProvider);
    // Capture the host before the database notification can rebuild a card.
    final messenger = NitrateMessenger.of(context);
    final router = GoRouter.maybeOf(context);
    final id = widget.id, isSeries = widget.isSeries;
    try {
      final name = isSeries
          ? await addShowFromTvdb(db, tvdb, id)
          : await addMovieFromTvdb(db, tvdb, id);
      if (messenger.mounted) {
        messenger.showBanner(
          NitrateBanner(
            kind: NitrateBannerKind.success,
            title: isSeries
                ? 'Ajouté à Mes séries'
                : 'Ajouté à mes films à voir',
            content: Text(name),
            duration: const Duration(seconds: 6),

            action: NitrateBannerAction(
              label: isSeries ? 'Voir la série' : 'Voir le film',

              onPressed: () => router?.push(
                isSeries ? '/show/$id' : '/movie/$id',
                extra: name,
              ),
            ),
          ),
        );
      }
    } on TvdbException catch (e) {
      if (!mounted) return;
      NitrateMessenger.of(context).showBanner(
        NitrateBanner(kind: NitrateBannerKind.error, content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);

    final label = widget.already
        ? 'Retirer ${widget.name} de ma liste'
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
                Icon(Icons.check, size: 17, color: ModernPalette.lilac),
                SizedBox(width: 5),
                Text(
                  'Ajouté',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
      button: true,
      enabled: !_busy,
      toggled: widget.already,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : (widget.already ? _remove : _add),
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
