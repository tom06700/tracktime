import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../tmdb/add.dart';
import '../tmdb/tvdb.dart';
import '../widgets/common.dart';

/// Onglet Explorer : recherche TheTVDB (séries et films) + résultats.
/// Conçu comme corps d'onglet (pas de Scaffold ni d'AppBar propre).
class ExplorerScreen extends ConsumerStatefulWidget {
  const ExplorerScreen({super.key});

  @override
  ConsumerState<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends ConsumerState<ExplorerScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // rafraîchit le bouton d'effacement
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _lastQuery = q;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tvdb = ref.read(tvdbClientProvider);
      final results = await tvdb.search(q);
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _results = results.where((r) {
          final t = '${r['type'] ?? r['primary_type'] ?? ''}';
          return t == 'series' || t == 'movie';
        }).toList();
        _loading = false;
      });
    } on TvdbException catch (e) {
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _controller,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Chercher une série ou un film…',
              prefixIcon: const Icon(Icons.search, color: TtColors.dim),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: TtColors.dim),
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: TtColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline, message: _error!);
    }
    if (_controller.text.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.travel_explore,
        message: 'Cherche une série ou un film à ajouter à ton suivi.',
      );
    }
    if (_results.isEmpty) {
      return const EmptyState(icon: Icons.search_off, message: 'Aucun résultat.');
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: bottomNavInset(context)),
      itemCount: _results.length,
      itemBuilder: (_, i) => _ResultCard(_results[i]),
    );
  }
}

class _ResultCard extends ConsumerStatefulWidget {
  const _ResultCard(this.result);

  final Map<String, dynamic> result;

  @override
  ConsumerState<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends ConsumerState<_ResultCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final isTv = '${r['type'] ?? r['primary_type'] ?? ''}' == 'series';
    final id = TvdbClient.tvdbId(r);
    final name = '${r['name'] ?? ''}';
    final year = '${r['year'] ?? ''}';
    final poster = r['image_url'] as String?;

    final shows = ref.watch(showsProvider).value ?? const [];
    final movies = ref.watch(moviesProvider).value ?? const [];
    final already = id != null &&
        (isTv
            ? shows.any((s) => s.show.id == id)
            : movies.any((m) => m.id == id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PosterBox(
              posterPath: poster,
              fallbackIcon: isTv ? Icons.tv : Icons.movie_outlined,
              small: true,
              label: name,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '${isTv ? 'Série' : 'Film'}${year.isNotEmpty ? ' · $year' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: TtColors.dim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (id == null)
              const SizedBox.shrink()
            else if (already)
              const Icon(Icons.check_circle, color: TtColors.teal)
            else if (_busy)
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton.filled(
                icon: const Icon(Icons.add),
                onPressed: () => _add(id, isTv, name),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(int id, bool isTv, String name) async {
    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    final tvdb = ref.read(tvdbClientProvider);
    try {
      if (isTv) {
        await addShowFromTvdb(db, tvdb, id);
      } else {
        await addMovieFromTvdb(db, tvdb, id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« $name » ajouté${isTv ? 'e' : ''} ✓')),
      );
    } on TvdbException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
