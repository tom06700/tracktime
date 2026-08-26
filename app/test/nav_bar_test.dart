import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/widgets/nav_bar.dart';

void main() {
  const items = [
    NavItem(icon: Icons.tv_outlined, label: 'Séries'),
    NavItem(icon: Icons.movie_outlined, label: 'Films'),
    NavItem(icon: Icons.travel_explore_outlined, label: 'Explorer'),
    NavItem(icon: Icons.person_outline, label: 'Profil'),
  ];

  Widget host(int selected, ValueChanged<int> onSelected) => MaterialApp(
    home: Scaffold(
      bottomNavigationBar: NitrateNavBar(
        items: items,
        selectedIndex: selected,
        onSelected: onSelected,
      ),
    ),
  );

  testWidgets('taper un autre onglet le notifie', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(host(0, taps.add));
    await tester.tap(find.text('Films'));
    expect(taps, [1]);
  });

  testWidgets('retaper l\'onglet courant ne notifie rien', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(host(0, taps.add));
    await tester.tap(find.text('Séries'));
    expect(taps, isEmpty);
  });

  // Pas d'attente `isFocusable` : les onglets ne sont pas dans l'arbre de
  // focus clavier, ce dont VoiceOver n'a pas besoin — il balaie les nœuds par
  // label et action.
  testWidgets('chaque onglet expose sa sélection à VoiceOver', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(2, (_) {}));

    expect(
      tester.getSemantics(find.text('Explorer')),
      matchesSemantics(
        label: 'Explorer',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Séries')),
      matchesSemantics(
        label: 'Séries',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('les zones tactiles dépassent 44 px', (tester) async {
    await tester.pumpWidget(host(0, (_) {}));
    for (final item in items) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(item.label),
          matching: find.byType(GestureDetector),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
    }
  });
}
