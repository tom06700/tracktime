import 'package:flutter/material.dart';
import '../db/database.dart';

Future<bool> confirmMovieRemoval(BuildContext context, Movie movie) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce film ?'),
        content: Text(
          '« ${movie.title} » et son visionnage seront retirés de ta collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    ) ??
    false;
