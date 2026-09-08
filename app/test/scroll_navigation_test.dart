import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/widgets/scroll_navigation.dart';

void main() {
  Widget host({
    int tab = 0,
    bool short = false,
    bool horizontal = false,
    bool reduced = false,
    bool accessible = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduced,
        accessibleNavigation: accessible,
      ),
      child: ScrollNavigationScaffold(
        tabIndex: tab,
        body: ListView(
          scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
          children: [SizedBox(height: short ? 100 : 3000, width: 3000)],
        ),
        bottomNavigationBar: const SizedBox(
          height: 90,
          child: Text('Navigation'),
        ),
      ),
    ),
  );
  bool hidden(WidgetTester tester) => tester
      .widget<IgnorePointer>(
        find.byKey(const ValueKey('navigation-interaction')),
      )
      .ignoring;

  testWidgets('masque après une descente franche, revient à la remontée', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.drag(find.byType(ListView), const Offset(0, -35));
    await t.pumpAndSettle();
    expect(hidden(t), isFalse);
    await t.drag(find.byType(ListView), const Offset(0, -180));
    await t.pumpAndSettle();
    expect(hidden(t), isTrue);
    await t.drag(find.byType(ListView), const Offset(0, 50));
    await t.pumpAndSettle();
    expect(hidden(t), isFalse);
  });
  testWidgets('reste visible sur une page courte ou un défilement horizontal', (
    t,
  ) async {
    await t.pumpWidget(host(short: true));
    await t.drag(find.byType(ListView), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(hidden(t), isFalse);
    await t.pumpWidget(host(horizontal: true));
    await t.drag(find.byType(ListView), const Offset(-200, 0));
    await t.pumpAndSettle();
    expect(hidden(t), isFalse);
  });
  testWidgets('réapparaît au changement d’onglet sans déplacer le contenu', (
    t,
  ) async {
    await t.pumpWidget(host());
    final height = t.getSize(find.byType(ListView)).height;
    await t.drag(find.byType(ListView), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(hidden(t), isTrue);
    expect(t.getSize(find.byType(ListView)).height, height);
    await t.pumpWidget(host(tab: 1));
    await t.pumpAndSettle();
    expect(hidden(t), isFalse);
  });
  testWidgets('respecte la réduction des animations et le lecteur d’écran', (
    t,
  ) async {
    await t.pumpWidget(host(reduced: true));
    await t.drag(find.byType(ListView), const Offset(0, -200));
    await t.pump();
    expect(hidden(t), isTrue);
    expect(
      t.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
      Duration.zero,
    );
    await t.pumpWidget(host(accessible: true));
    await t.drag(find.byType(ListView), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(hidden(t), isFalse);
  });
  testWidgets('fonctionne avec le défilement imbriqué de Séries', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: ScrollNavigationScaffold(
          tabIndex: 0,
          body: NestedScrollView(
            headerSliverBuilder: (_, _) => [
              const SliverToBoxAdapter(child: SizedBox(height: 150)),
            ],
            body: ListView(children: const [SizedBox(height: 3000)]),
          ),
          bottomNavigationBar: const SizedBox(
            height: 90,
            child: Text('Navigation'),
          ),
        ),
      ),
    );
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(hidden(t), isTrue);
    await t.drag(find.byType(ListView), const Offset(0, 70));
    await t.pumpAndSettle();
    expect(hidden(t), isFalse);
  });
}
