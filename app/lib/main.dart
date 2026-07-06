import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/import_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/shows_screen.dart';
import 'settings/settings_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      const ShowsScreen(),
      const MoviesScreen(),
      ProfileScreen(onGoToImport: () => setState(() => _tab = 3)),
      const ImportScreen(),
    ];
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
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Réglages',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tv), label: 'Séries'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), label: 'Films'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profil'),
          NavigationDestination(
              icon: Icon(Icons.download_outlined), label: 'Import'),
        ],
      ),
    );
  }
}
