import 'widgets/portal/portal_transition_host.dart';
import 'widgets/portal/portal_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/explorer_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/profile_screen.dart';
import 'providers.dart';
import 'screens/shows_screen.dart';
import 'widgets/nav_bar.dart';
import 'widgets/scroll_navigation.dart';

/// Coquille principale : 4 onglets (Séries · Films · Explorer · Profil) dans
/// une pile qui conserve les écrans, avec une traversée dédiée à Explorer.
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
    return PortalTransitionHost(
      index: tab,
      screens: screens,
      onSelected: ref.read(homeTabProvider.notifier).select,
      scaffoldBuilder: (body, portal) => ScrollNavigationScaffold(
        tabIndex: tab,
        body: body,
        bottomNavigationBar: AnimatedBuilder(
          animation: portal ?? const AlwaysStoppedAnimation<double>(0),
          child: NitrateNavBar(
            items: _navItems,
            selectedIndex: tab,
            onSelected: ref.read(homeTabProvider.notifier).select,
          ),
          builder: (context, child) => IgnorePointer(
            ignoring: portal != null,
            child: ExcludeSemantics(
              excluding: portal != null,
              child: Opacity(
                opacity: portal == null
                    ? 1
                    : 1 - portalEase(0, .42, portal.value * 2.2),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
