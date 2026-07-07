import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../profile/sections.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _Status { all, ongoing, done, notStarted }

enum _Sort { recent, progress, az }

/// « Mes séries » : toute la bibliothèque en grille d'affiches (progression
/// posée dessus), avec recherche, filtre par statut, par genre et tris.
/// Ouverte depuis l'aperçu « À l'affiche » du profil.
class SeriesLibraryScreen extends ConsumerStatefulWidget {
  const SeriesLibraryScreen({super.key});

  @override
  ConsumerState<SeriesLibraryScreen> createState() =>
      _SeriesLibraryScreenState();
}

class _SeriesLibraryScreenState extends ConsumerState<SeriesLibraryScreen> {
  final _searchCtrl = TextEditingController();
  _Status _status = _Status.all;
  _Sort _sort = _Sort.recent;
  String? _genre;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shows =
        ref.watch(showsProvider).value ?? const <ShowWithProgress>[];
    final lastActivity = ref.watch(universeProvider).value?.lastActivityByShow ??
        const <int, DateTime>{};

    // Genres disponibles, fréquence décroissante.
    final freq = <String, int>{};
    for (final s in shows) {
      for (final g in (s.show.genres ?? '').split('|')) {
        final t = g.trim();
        if (t.isNotEmpty) freq[t] = (freq[t] ?? 0) + 1;
      }
    }
    final genreNames = freq.keys.toList()
      ..sort((a, b) => freq[b]!.compareTo(freq[a]!));

    final list = _filtered(shows, lastActivity);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes séries')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 28),
        children: [
          // ── Recherche ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Rechercher une série…',
                hintStyle: const TextStyle(color: TtColors.dim, fontSize: 14.5),
                prefixIcon:
                    const Icon(Icons.search, color: TtColors.dim, size: 21),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close,
                            color: TtColors.dim, size: 19),
                        onPressed: () =>
                            setState(() => _searchCtrl.clear()),
                      ),
                filled: true,
                fillColor: TtColors.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Statut ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                    label: 'Toutes',
                    selected: _status == _Status.all,
                    onTap: () => setState(() => _status = _Status.all)),
                _Pill(
                    label: 'En cours',
                    selected: _status == _Status.ongoing,
                    onTap: () => setState(() => _status = _Status.ongoing)),
                _Pill(
                    label: 'Terminées',
                    selected: _status == _Status.done,
                    onTap: () => setState(() => _status = _Status.done)),
                _Pill(
                    label: 'À commencer',
                    selected: _status == _Status.notStarted,
                    onTap: () =>
                        setState(() => _status = _Status.notStarted)),
              ],
            ),
          ),

          // ── Genres ──
          if (genreNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: genreNames.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final g = genreNames[i];
                  return _Pill(
                    label: g,
                    selected: _genre == g,
                    onTap: () =>
                        setState(() => _genre = _genre == g ? null : g),
                  );
                },
              ),
            ),
          ],

          // ── Tri ──
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Text('Trier :',
                      style: TextStyle(fontSize: 12.5, color: TtColors.dim)),
                ),
                _Pill(
                    label: 'Récentes',
                    selected: _sort == _Sort.recent,
                    onTap: () => setState(() => _sort = _Sort.recent)),
                _Pill(
                    label: 'Progression',
                    selected: _sort == _Sort.progress,
                    onTap: () => setState(() => _sort = _Sort.progress)),
                _Pill(
                    label: 'A → Z',
                    selected: _sort == _Sort.az,
                    onTap: () => setState(() => _sort = _Sort.az)),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '${list.length} série${list.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: TtColors.dim),
            ),
          ),
          const SizedBox(height: 8),

          // ── Grille ──
          if (list.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              message: 'Aucune série ne correspond à ces filtres.',
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: list.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 116,
                  childAspectRatio: 0.53,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (context, i) {
                  final s = list[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: SeriesPosterTile(item: s)),
                      const SizedBox(height: 5),
                      Text(
                        s.show.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<ShowWithProgress> _filtered(
    List<ShowWithProgress> shows,
    Map<int, DateTime> lastActivity,
  ) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = shows.where((s) {
      if (q.isNotEmpty && !s.show.name.toLowerCase().contains(q)) {
        return false;
      }
      switch (_status) {
        case _Status.ongoing:
          if (s.watchedCount == 0 || s.isDone) return false;
        case _Status.done:
          if (!s.isDone) return false;
        case _Status.notStarted:
          if (s.watchedCount > 0) return false;
        case _Status.all:
          break;
      }
      final genre = _genre;
      if (genre != null &&
          !(s.show.genres ?? '').split('|').contains(genre)) {
        return false;
      }
      return true;
    }).toList();

    int byName(ShowWithProgress a, ShowWithProgress b) =>
        a.show.name.toLowerCase().compareTo(b.show.name.toLowerCase());

    switch (_sort) {
      case _Sort.recent:
        list.sort((a, b) {
          final da = lastActivity[a.show.id];
          final db = lastActivity[b.show.id];
          if (da != null && db != null) return db.compareTo(da);
          if (da != null) return -1;
          if (db != null) return 1;
          return byName(a, b);
        });
      case _Sort.progress:
        list.sort((a, b) {
          final c = b.progress.compareTo(a.progress);
          if (c != 0) return c;
          final w = b.watchedCount.compareTo(a.watchedCount);
          return w != 0 ? w : byName(a, b);
        });
      case _Sort.az:
        list.sort(byName);
    }
    return list;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? TtColors.amber.withValues(alpha: 0.16)
              : TtColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? TtColors.amber.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? TtColors.amber : TtColors.text,
          ),
        ),
      ),
    );
  }
}
