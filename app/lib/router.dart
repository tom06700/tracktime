import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/episode_detail_screen.dart';
import 'screens/import_screen.dart';
import 'screens/series_library_screen.dart';
import 'screens/show_detail_screen.dart';
import 'settings/settings_screen.dart';
import 'shell.dart';

/// Navigation par routes (go_router) : synchronise la pile Flutter avec
/// l'historique du navigateur, pour que le geste de retour (web/PWA) et la
/// touche retour dépilent correctement les écrans au lieu de sortir de l'app.
///
/// Routes de PREMIER NIVEAU (pas imbriquées) : `context.push` empile alors une
/// seule page au-dessus de la coquille, d'où une seule animation de retour.
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeShell()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/import', builder: (_, _) => const ImportPage()),
    GoRoute(path: '/series', builder: (_, _) => const SeriesLibraryScreen()),
    GoRoute(
      path: '/show/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final name = state.extra as String? ?? '';
        return ShowDetailScreen(showId: id, title: name);
      },
    ),
    // Détail d'épisode : page modale non opaque (le fil reste visible dessous)
    // qui remonte du bas, avec carrousel d'épisodes à l'intérieur.
    GoRoute(
      path: '/episode/:showId/:season/:episode',
      pageBuilder: (context, state) {
        final p = state.pathParameters;
        final extra = (state.extra as Map<String, dynamic>?) ?? const {};
        return CustomTransitionPage(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.55),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (_, anim, _, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          child: EpisodeSheet(
            showId: int.parse(p['showId']!),
            season: int.parse(p['season']!),
            initialEpisode: int.parse(p['episode']!),
            showName: extra['name'] as String? ?? '',
            posterPath: extra['poster'] as String?,
          ),
        );
      },
    ),
  ],
);
