import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/import_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/shows_screen.dart';
import 'screens/stats_screen.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: TrackTimeApp()));
}

class TrackTimeApp extends StatelessWidget {
  const TrackTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackTime',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _screens = [
    ShowsScreen(),
    MoviesScreen(),
    StatsScreen(),
    ImportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text.rich(TextSpan(children: [
          TextSpan(text: 'Track'),
          TextSpan(text: 'Time', style: TextStyle(color: TtColors.amber)),
        ])),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Recherche',
            onPressed: () {
              // Étape 3 : recherche TMDB.
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Réglages',
            onPressed: () {
              // Étape 3 : réglages (sauvegarde, attribution TMDB).
            },
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tv), label: 'Séries'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), label: 'Films'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(
              icon: Icon(Icons.download_outlined), label: 'Import'),
        ],
      ),
    );
  }
}
