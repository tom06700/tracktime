import 'package:flutter/material.dart';

import 'screens/explorer_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shows_screen.dart';
import 'widgets/liquid_glass_nav_bar.dart';
import 'widgets/nitrate_icons.dart';

/// Coquille principale : 4 onglets (Séries · Films · Explorer · Profil) dans
/// un IndexedStack, avec la nav bar « liquid glass » flottante.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _navItems = [
    NavItem(icon: NitrateIcon.reel, label: 'Séries'),
    NavItem(icon: NitrateIcon.clapper, label: 'Films'),
    NavItem(icon: NitrateIcon.lens, label: 'Explorer'),
    NavItem(icon: NitrateIcon.portrait, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    const screens = [
      ShowsScreen(),
      MoviesScreen(),
      ExplorerScreen(),
      ProfileScreen(),
    ];
    // Aucune barre ici : chaque page pose son propre bandeau flottant
    // (GlassHeader), qui loge au besoin ses onglets. Le Profil, lui, est
    // immersif et n'a qu'un bouton Réglages flottant sur son décor.
    return Scaffold(
      extendBody: true,
      // TickerMode : gèle les animations des onglets cachés (ex. le fond
      // vivant du Profil), l'IndexedStack gardant leur état.
      body: IndexedStack(
        index: _tab,
        children: [
          for (var i = 0; i < screens.length; i++)
            TickerMode(enabled: i == _tab, child: screens[i]),
        ],
      ),
      bottomNavigationBar: LiquidGlassNavBar(
        items: _navItems,
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
      ),
    );
  }
}
