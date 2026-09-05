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
import '../widgets/editorial_heading.dart';
import '../tmdb/add.dart';
import '../tmdb/search_result.dart';
import '../tmdb/tvdb.dart';
import '../widgets/common.dart';
import '../widgets/media_image.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';

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

    return Column(
      children: [
        _SearchField(
          controller: _controller,
          onChanged: _onChanged,
          onSubmitted: _search,
          onClear: () {
            _controller.clear();
            _search('');
          },
        ),
        if (searching)
          _FilterRow(
            value: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
        Expanded(
          // Passer de la découverte aux résultats ne doit pas remplacer
          // l'écran d'un coup. Fondu seul : un glissement latéral suggérerait
          // une navigation, alors qu'on reste au même endroit.
          child: AnimatedSwitcher(
            duration: motionOf(context, Motion.normal),
            switchInCurve: Motion.enter,
            child: searching
                ? _SearchResults(
                    key: const ValueKey('resultats'),
                    results: _filtered,
                    loading: _loading,
                    error: _error,
                    onRetry: () => _search(_controller.text),
                  )
                : const _Discovery(key: ValueKey('decouverte')),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Chercher une série ou un film…',
          prefixIcon: const Icon(Icons.search, size: 20, color: TtColors.dim),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 19, color: TtColors.dim),
                  tooltip: 'Effacer',
                  onPressed: onClear,
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          filled: true,
          fillColor: TtColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Filtres sobres : du texte souligné, pas des capsules colorées.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.value, required this.onChanged});

  final SearchFilter value;
  final ValueChanged<SearchFilter> onChanged;

  static const _labels = {
    SearchFilter.all: 'Tout',
    SearchFilter.series: 'Séries',
    SearchFilter.movies: 'Films',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          for (final f in SearchFilter.values)
            Semantics(
              button: true,
              selected: f == value,
              label: _labels[f],
              child: GestureDetector(
                onTap: () => onChanged(f),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 18, top: 8, bottom: 10),
                  child: Text(
                    _labels[f]!,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: f == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: f == value ? TtColors.amber : TtColors.dim,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Découverte ─────────────────────────────

class _Discovery extends ConsumerWidget {
  const _Discovery({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.only(top: 4, bottom: bottomNavInset(context)),
      children: [
        const EditorialHeading(
          eyebrow: 'Le prochain coup de cœur',
          title: 'Laisse-toi surprendre.',
          description: 'Des histoires à découvrir, une collection à inventer.',
        ),
        const _TonightCard(),
        _DiscoveryRow(
          title: 'Séries populaires',
          provider: popularSeriesProvider,
          isSeries: true,
        ),
        _DiscoveryRow(
          title: 'Films populaires',
          provider: popularMoviesProvider,
          isSeries: false,
        ),
        _DiscoveryRow(
          title: 'Sorties annoncées',
          provider: upcomingReleasesProvider,
          isSeries: false,
        ),
      ],
    );
  }
}

/// Carte signature « Quoi regarder ce soir ». Elle réutilise le tirage du
/// Profil et n'apparaît que si la liste contient de quoi choisir.
class _TonightCard extends ConsumerWidget {
  const _TonightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(moviesProvider).value ?? const [];
    final shows = ref.watch(showsProvider).value ?? const [];
    final items = watchlistItems(movies, shows);
    if (items.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: TtColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.movie_filter_outlined,
              size: 26,
              color: TtColors.amber,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Qu\'est-ce qu\'on regarde ce soir ?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: TtColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Laisse Nitrate choisir dans ta liste.',
                    style: const TextStyle(fontSize: 12.5, color: TtColors.dim),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => showTonightPicker(context, items),
                    style: TextButton.styleFrom(
                      foregroundColor: TtColors.amber,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      backgroundColor: TtColors.amber.withValues(alpha: 0.12),
                      textStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Choisir pour moi'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryRow extends ConsumerWidget {
  const _DiscoveryRow({
    required this.title,
    required this.provider,
    required this.isSeries,
  });

  final String title;
  final FutureProvider<List<Map<String, dynamic>>> provider;
  final bool isSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);

    // Une rangée qui a échoué ne doit pas condamner tout l'écran : les autres
    // restent utilisables, celle-ci disparaît simplement.
    if (async.hasError) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(title),
            subtitle: const Text('Chargement indisponible'),
            trailing: IconButton(
              tooltip: 'Réessayer : $title',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(provider),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: NitrateBrand.display(28),
          ),
        ),
        SizedBox(
          height: 254 + (MediaQuery.textScalerOf(context).scale(32) - 32),
          child: async.when(
            loading: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 128, height: 192, radius: 12),
                  SizedBox(height: 8),
                  SkeletonBox(width: 100, height: 12, radius: 4),
                ],
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (list) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) =>
                  _DiscoveryCard(item: list[i], isSeries: isSeries),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiscoveryCard extends ConsumerWidget {
  const _DiscoveryCard({required this.item, required this.isSeries});

  final Map<String, dynamic> item;
  final bool isSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = (item['id'] as num?)?.toInt();
    final name = '${item['name'] ?? ''}';
    final year = '${item['year'] ?? ''}';
    final poster = item['image'] as String?;

    final shows = ref.watch(showsProvider).value ?? const [];
    final movies = ref.watch(moviesProvider).value ?? const [];
    final already =
        id != null &&
        (isSeries
            ? shows.any((s) => s.show.id == id)
            : movies.any((m) => m.id == id));

    return SizedBox(
      width: 128,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Semantics(
                button: true,
                label: 'Ouvrir la fiche de $name',
                child: GestureDetector(
                  onTap: id == null
                      ? null
                      : () => openMediaDetail(
                          context,
                          id: id,
                          isSeries: isSeries,
                          title: name,
                        ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 128,
                      height: 192,
                      child: MediaImage(
                        sources: [poster],
                        seed: name,
                        icon: isSeries ? Icons.tv : Icons.movie_outlined,
                      ),
                    ),
                  ),
                ),
              ),
              if (id != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: AddButton(
                    id: id,
                    isSeries: isSeries,
                    name: name,
                    already: already,
                    compact: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: TtColors.text,
              ),
            ),
          ),
          if (year.isNotEmpty)
            Text(
              year,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: TtColors.dim),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Résultats de recherche ───────────────────────────

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    super.key,
    required this.results,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<MediaSearchResult> results;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ErrorRetry(
        title: 'Recherche indisponible',
        message: 'Vérifie ta connexion et réessaie.',
        onRetry: onRetry,
      );
    }
    if (loading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 6,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SkeletonBox(width: 52, height: 78, radius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 15, radius: 4),
                    SizedBox(height: 7),
                    SkeletonBox(width: 90, height: 12, radius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return const EmptyPrompt(
        icon: Icons.search_off,
        title: 'Aucun résultat',
        message: 'Essaie une autre orthographe, ou le titre original.',
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: bottomNavInset(context)),
      itemCount: results.length,
      itemBuilder: (_, i) => _ResultRow(result: results[i]),
    );
  }
}

class _ResultRow extends ConsumerWidget {
  const _ResultRow({required this.result});

  final MediaSearchResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = result;
    final isSeries = r.type == SearchMediaType.series;

    final shows = ref.watch(showsProvider).value ?? const [];
    final movies = ref.watch(moviesProvider).value ?? const [];
    final already =
        r.tvdbId != null &&
        (isSeries
            ? shows.any((s) => s.show.id == r.tvdbId)
            : movies.any((m) => m.id == r.tvdbId));

    // La zone média ouvre la fiche ; le bouton d'ajout vit à côté, hors de
    // cette zone, pour qu'un tap dessus n'ouvre pas la fiche au passage.
    final media = Semantics(
      button: true,
      label: 'Ouvrir la fiche de ${r.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: r.tvdbId == null
            ? null
            : () => openMediaDetail(
                context,
                id: r.tvdbId!,
                isSeries: isSeries,
                title: r.name,
              ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 78,
                child: MediaImage(
                  sources: [r.image],
                  seed: r.name,
                  icon: isSeries ? Icons.tv : Icons.movie_outlined,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: TtColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      isSeries ? 'Série' : 'Film',
                      ?r.year,
                      // Titre d'origine en clair : beaucoup d'animés sont
                      // catalogués sous leur nom japonais.
                      ?r.originalName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: TtColors.dim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(child: media),
          const SizedBox(width: 8),
          // Sans identifiant exploitable la carte reste visible, seul l'ajout
          // est indisponible.
          if (r.canAdd)
            AddButton(
              id: r.tvdbId!,
              isSeries: isSeries,
              name: r.name,
              already: already,
            ),
        ],
      ),
    );
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
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);

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
          ? const Icon(Icons.check, size: 18, color: TtColors.bg)
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
        color: TtColors.amber,
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
                    ? TtColors.amber
                    : Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(widget.compact ? 30 : 10),
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
