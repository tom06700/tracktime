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

  // La sélection et les actions natives restent sur le même nœud accessible.
  testWidgets('chaque onglet expose sa sélection à VoiceOver', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(2, (_) {}));

    expect(
      tester.getSemantics(find.text('Explorer')),
      matchesSemantics(
        label: 'Explorer',
        isButton: true,
        isFocusable: true,
        isEnabled: true,
        hasEnabledState: true,
        hasFocusAction: true,
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
        isFocusable: true,
        isEnabled: true,
        hasEnabledState: true,
        hasFocusAction: true,
        hasTapAction: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('la navigation conserve ses marges jusqu’au bas de l’écran', (
    tester,
  ) async {
    await tester.pumpWidget(host(0, (_) {}));
    final foundation = find.byKey(const ValueKey('navigation-foundation'));
    final rect = tester.getRect(foundation);
    final screen = tester.getSize(find.byType(Scaffold));
    expect(rect.left, 0);
    expect(rect.right, screen.width);
    expect(rect.bottom, screen.height);
  });

  testWidgets('les zones tactiles dépassent 44 px', (tester) async {
    await tester.pumpWidget(host(0, (_) {}));
    for (final item in items) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(item.label),
          matching: find.byType(TextButton),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
    }
  });
  testWidgets(
    'glisser prévisualise puis sélectionne uniquement au relâchement',
    (t) async {
      var selected = 0;
      final visits = <int>[];
      await t.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: NitrateNavBar(
                items: items,
                selectedIndex: selected,
                onSelected: (i) {
                  visits.add(i);
                  setState(() => selected = i);
                },
              ),
            ),
          ),
        ),
      );
      final gesture = await t.startGesture(t.getCenter(find.text('Séries')));
      await t.pump(const Duration(milliseconds: 10));
      expect(visits, isEmpty);
      for (final label in ['Films', 'Explorer', 'Profil']) {
        await gesture.moveTo(t.getCenter(find.text(label)));
        await t.pump(const Duration(milliseconds: 30));
      }
      expect(visits, isEmpty);
      expect(selected, 0);
      await gesture.moveBy(const Offset(1, 0));
      await gesture.up();
      await t.pump();
      expect(visits, [3]);
      expect(selected, 3);
    },
  );

  testWidgets(
    'un glissement rapide sélectionne la destination au relâchement',
    (t) async {
      final visits = <int>[];
      await t.pumpWidget(host(0, visits.add));
      final gesture = await t.startGesture(t.getCenter(find.text('Séries')));
      await t.pump(const Duration(milliseconds: 80));
      await gesture.moveTo(t.getCenter(find.text('Profil')));
      await gesture.up();
      await t.pump();
      expect(visits, [3]);
    },
  );

  testWidgets('quitter la barre verticalement interrompt la sélection', (
    t,
  ) async {
    final visits = <int>[];
    await t.pumpWidget(host(0, visits.add));
    final gesture = await t.startGesture(t.getCenter(find.text('Séries')));
    await t.pump(const Duration(milliseconds: 10));
    await gesture.moveTo(
      t.getCenter(find.text('Profil')) - const Offset(0, 160),
    );
    await gesture.up();
    await t.pump();
    expect(visits, isEmpty);
  });
  testWidgets('annuler le geste ne change pas la page', (t) async {
    final visits = <int>[];
    await t.pumpWidget(host(0, visits.add));
    final gesture = await t.startGesture(t.getCenter(find.text('Séries')));
    await gesture.moveTo(t.getCenter(find.text('Profil')));
    await t.pump();
    expect(visits, isEmpty);
    await gesture.cancel();
    await t.pump();
    expect(visits, isEmpty);
  });
}
