import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/explorer_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shows_screen.dart';
import 'settings/settings_screen.dart';
import 'theme.dart';
import 'widgets/liquid_glass_nav_bar.dart';

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

  static const _navItems = [
    NavItem(icon: Icons.tv_outlined, activeIcon: Icons.tv, label: 'Séries'),
    NavItem(
        icon: Icons.movie_outlined,
        activeIcon: Icons.movie,
        label: 'Films'),
    NavItem(
        icon: Icons.travel_explore_outlined,
        activeIcon: Icons.travel_explore,
        label: 'Explorer'),
    NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    const screens = [
      ShowsScreen(),
      MoviesScreen(),
      ExplorerScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text.rich(TextSpan(children: [
          TextSpan(text: 'Track'),
          TextSpan(text: 'Time', style: TextStyle(color: TtColors.amber)),
        ])),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Réglages',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: LiquidGlassNavBar(
        items: _navItems,
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
      ),
    );
  }
}
