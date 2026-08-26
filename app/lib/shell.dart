import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/explorer_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shows_screen.dart';
import 'theme.dart';
import 'widgets/liquid_glass_nav_bar.dart';

/// Coquille principale : 4 onglets (Séries · Films · Explorer · Profil) dans
/// un IndexedStack, avec la nav bar « liquid glass » flottante.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  /// Fondu joué à chaque bascule d'onglet. Il anime l'IndexedStack lui-même
  /// plutôt que d'échanger ses enfants : l'état, les positions de défilement
  /// et les contrôleurs de chaque page restent intacts.
  late final AnimationController _switch = AnimationController(
    vsync: this,
    duration: kNavTransition,
    value: 1,
  );

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _switch.forward(from: 0);
    }
  }

  static const _navItems = [
    NavItem(icon: Icons.tv_outlined, activeIcon: Icons.tv, label: 'Séries'),
    NavItem(
      icon: Icons.movie_outlined,
      activeIcon: Icons.movie,
      label: 'Films',
    ),
    NavItem(
      icon: Icons.travel_explore_outlined,
      activeIcon: Icons.travel_explore,
      label: 'Explorer',
    ),
    NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
    final immersive = _tab == 3;
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
      body: _SwitchFade(
        animation: _switch,
        child: IndexedStack(
          index: _tab,
          children: [
            for (var i = 0; i < screens.length; i++)
              TickerMode(enabled: i == _tab, child: screens[i]),
          ],
        ),
      ),
      bottomNavigationBar: LiquidGlassNavBar(
        items: _navItems,
        selectedIndex: _tab,
        onSelected: _select,
      ),
    );
  }
}

/// Fondu + très légère montée appliqués à la page qui vient d'être affichée.
/// Le sous-arbre n'est jamais reconstruit : seule la couche de composition
/// change, donc l'état des écrans est préservé.
class _SwitchFade extends StatelessWidget {
  const _SwitchFade({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      // `child` passe par le paramètre dédié : il n'est pas reconstruit à
      // chaque frame de l'animation.
      child: child,
      builder: (context, kid) {
        final t = Curves.easeOutCubic.transform(animation.value);
        if (t >= 1) return kid!;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 6),
            child: kid,
          ),
        );
      },
    );
  }
}
