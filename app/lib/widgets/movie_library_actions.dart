import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers.dart';
import '../theme.dart';

/// Actions de la fiche : la bibliothèque reste la source du statut affiché.
class MovieLibraryActions extends ConsumerStatefulWidget {
  const MovieLibraryActions({super.key, required this.movie});
  final Movie movie;

  @override
  ConsumerState<MovieLibraryActions> createState() => _MovieLibraryActionsState();
}

class _MovieLibraryActionsState extends ConsumerState<MovieLibraryActions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(AppDatabase) action) async {
    if (_busy) return;
    final db = ref.read(databaseProvider);
    setState(() => _busy = true);
    try {
      await action(db);
    } catch (e, st) {
      debugPrint('Action film impossible : $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Modification impossible. Réessaie dans un instant.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final movie = widget.movie;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce film ?'),
        content: Text('« ${movie.title} » sera retiré de ta bibliothèque et de ton historique.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _run((db) => db.deleteMovie(movie.id));
  }

  @override
  Widget build(BuildContext context) {
    final seen = widget.movie.watchedAt != null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : () => _run((db) => db.toggleMovieWatched(widget.movie)),
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(seen ? Icons.undo : Icons.check),
          label: Text(seen ? 'Remettre à voir' : 'Marquer comme vu'),
        ),
        if (seen) const Text('Film vu', style: TextStyle(color: TtColors.dim)),
        IconButton(
          tooltip: 'Retirer de ma liste',
          onPressed: _busy ? null : _remove,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
