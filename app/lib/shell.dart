import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/explorer_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/profile_screen.dart';
import 'providers.dart';
import 'screens/shows_screen.dart';
import 'theme.dart';
import 'widgets/nav_bar.dart';

/// Coquille principale : 4 onglets (Séries · Films · Explorer · Profil) dans
/// un IndexedStack, surmontant le socle de navigation.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _navItems = [
    NavItem(icon: Icons.tv_outlined, label: 'Séries'),
    NavItem(icon: Icons.movie_outlined, label: 'Films'),
    NavItem(icon: Icons.travel_explore_outlined, label: 'Explorer'),
    NavItem(icon: Icons.person_outline, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // L'onglet courant vit dans un provider : un écran enfant peut ainsi
    // demander l'ouverture d'un autre onglet — le bouton « Explorer les
    // séries » de l'état vide — sans empiler une seconde instance.
    final tab = ref.watch(homeTabProvider);
    const screens = [
      ShowsScreen(),
      MoviesScreen(),
      ExplorerScreen(),
      ProfileScreen(),
    ];
    // Le Profil est une page immersive plein écran (le décor « cinéma »
    // occupe jusqu'à la safe area) : pas de barre — elle porterait un titre
    // qui chevaucherait le contenu au défilement. Elle a son propre bouton
    // Réglages flottant. Les autres onglets gardent la barre « Nitrate ».
    final immersive = tab == HomeTab.profile;
    return Scaffold(
      extendBody: true,
      appBar: immersive
          ? null
          : AppBar(
              title: const Text(
                'NITRATE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: TtColors.amber,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Réglages',
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
      // TickerMode : gèle les animations des onglets cachés (ex. le fond
      // vivant du Profil), l'IndexedStack gardant leur état.
      // Changement d'onglet instantané : aucune couche d'opacité ni de
      // translation par-dessus l'IndexedStack. La version animée produisait
      // un double mouvement — la page apparaissait d'abord telle quelle, puis
      // l'animation repartait de zéro et la faisait remonter.
      body: IndexedStack(
        index: tab,
        children: [
          for (var i = 0; i < screens.length; i++)
            TickerMode(enabled: i == tab, child: screens[i]),
        ],
      ),
      bottomNavigationBar: NitrateNavBar(
        items: _navItems,
        selectedIndex: tab,
        onSelected: ref.read(homeTabProvider.notifier).select,
      ),
    );
  }
}
