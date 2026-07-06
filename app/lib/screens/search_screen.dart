import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../settings/prefs.dart';
import '../tmdb/add.dart';
import '../tmdb/tmdb.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
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
      final tmdb = ref.read(tmdbClientProvider);
      final results = await tmdb.searchMulti(q);
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _results = results
            .where((r) =>
                r['media_type'] == 'tv' || r['media_type'] == 'movie')
            .toList();
        _loading = false;
      });
    } on TmdbException catch (e) {
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _search,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Série ou film…',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline, message: _error!);
    }
    if (_controller.text.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        message: 'Cherche une série ou un film à ajouter.',
      );
    }
    if (_results.isEmpty) {
      return const EmptyState(icon: Icons.search_off, message: 'Aucun résultat.');
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, i) => _SearchResultCard(_results[i]),
    );
  }
}

class _SearchResultCard extends ConsumerStatefulWidget {
  const _SearchResultCard(this.result);

  final Map<String, dynamic> result;

  @override
  ConsumerState<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends ConsumerState<_SearchResultCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final isTv = r['media_type'] == 'tv';
    final id = (r['id'] as num).toInt();
    final name = '${r['name'] ?? r['title'] ?? ''}';
    final date = '${r['first_air_date'] ?? r['release_date'] ?? ''}';
    final year = date.length >= 4 ? date.substring(0, 4) : '';

    final shows = ref.watch(showsProvider).value ?? const [];
    final movies = ref.watch(moviesProvider).value ?? const [];
    final already = isTv
        ? shows.any((s) => s.show.id == id)
        : movies.any((m) => m.id == id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PosterBox(
              posterPath: r['poster_path'] as String?,
              fallbackIcon: isTv ? Icons.tv : Icons.movie_outlined,
              small: true,
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
            if (already)
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
    final tmdb = ref.read(tmdbClientProvider);
    try {
      if (isTv) {
        await addShowFromTmdb(db, tmdb, id);
      } else {
        await addMovieFromTmdb(db, tmdb, id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« $name » ajouté${isTv ? 'e' : ''} ✓')),
      );
    } on TmdbException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
