import 'package:flutter/material.dart';

import '../../theme.dart';
import '../catch_up.dart';

/// Demande à l'utilisateur s'il veut aussi cocher les épisodes qu'il a sautés.
///
/// Rend `true` pour « tout marquer », `false` ou null sinon — un balayage vaut
/// refus : l'épisode touché est déjà coché à ce stade, on ne fait qu'ajouter
/// les autres.
///
/// On propose, on ne comble jamais sans réponse.
Future<bool?> showCatchUpSheet(
  BuildContext context, {
  required List<EpisodeSlot> missing,
}) {
  final single = missing.length == 1;
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: TtColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              single
                  ? 'Marquer aussi l\'épisode précédent ?'
                  : 'Marquer les épisodes intermédiaires ?',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: TtColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              single
                  ? 'L\'épisode ${missing.single.episode} n\'est pas encore '
                        'marqué comme vu.'
                  : '${missing.length} épisodes entre ton dernier épisode vu '
                        'et celui-ci ne sont pas encore marqués comme vus.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: TtColors.dim,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: TtColors.amber,
                foregroundColor: TtColors.bg,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Tout marquer comme vu',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: TtColors.dim,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seulement cet épisode'),
            ),
          ],
        ),
      ),
    ),
  );
}
