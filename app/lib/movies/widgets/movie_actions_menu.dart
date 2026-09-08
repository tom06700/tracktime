import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/action_pill_menu.dart';

enum MovieAction { markWatched, markUnwatched, remove }

class MovieActionsMenu extends StatelessWidget {
  const MovieActionsMenu({
    super.key,
    required this.title,
    required this.watched,
    required this.onAction,
    this.diameter = 30,
    this.enabled = true,
  });
  final String title;
  final bool watched;
  final FutureOr<void> Function(MovieAction) onAction;
  final double diameter;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ActionPillMenuButton(
    label: 'Actions pour $title',
    diameter: diameter,
    enabled: enabled,
    actions: [
      ActionPill(
        label: watched ? 'Remettre à voir' : 'Marquer comme vu',
        icon: watched ? Icons.replay_rounded : Icons.check_rounded,
        onSelected: () => onAction(
          watched ? MovieAction.markUnwatched : MovieAction.markWatched,
        ),
      ),
      ActionPill(
        label: 'Retirer de ma liste',
        icon: Icons.delete_outline_rounded,
        destructive: true,
        onSelected: () => onAction(MovieAction.remove),
      ),
    ],
  );
}
