import 'package:go_router/go_router.dart';

import 'screens/episode_detail_screen.dart';
import 'screens/import_screen.dart';
import 'screens/show_detail_screen.dart';
import 'settings/settings_screen.dart';
import 'shell.dart';

/// Navigation par routes (go_router) : synchronise la pile Flutter avec
/// l'historique du navigateur, pour que le geste de retour (web/PWA) et la
/// touche retour dépilent correctement les écrans au lieu de sortir de l'app.
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeShell(), routes: [
      GoRoute(
        path: 'settings',
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: 'import',
        builder: (_, _) => const ImportPage(),
      ),
      GoRoute(
        path: 'show/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final name = state.extra as String? ?? '';
          return ShowDetailScreen(showId: id, title: name);
        },
      ),
      GoRoute(
        path: 'episode/:showId/:season/:episode',
        builder: (context, state) {
          final p = state.pathParameters;
          final extra = (state.extra as Map<String, dynamic>?) ?? const {};
          return EpisodeDetailScreen(
            showId: int.parse(p['showId']!),
            season: int.parse(p['season']!),
            episode: int.parse(p['episode']!),
            showName: extra['name'] as String? ?? '',
            posterPath: extra['poster'] as String?,
          );
        },
      ),
    ]),
  ],
);
