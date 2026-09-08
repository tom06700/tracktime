import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/widgets/nitrate_home_button.dart';

void main() {
  testWidgets('logo returns to Séries home and clears pushed pages', (t) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(homeTabProvider.notifier).select(HomeTab.movies);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Accueil séries')),
        ),
        GoRoute(
          path: '/detail',
          builder: (_, _) => const Scaffold(body: NitrateHomeButton()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/detail');
    await t.pumpAndSettle();
    final semantics = t.ensureSemantics();
    expect(t.getSemantics(find.byType(TextButton)).label, 'Nitrate, accueil');
    expect(t.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(44));
    await t.tap(find.byTooltip('Accueil'));
    await t.pumpAndSettle();
    expect(container.read(homeTabProvider), HomeTab.series);
    expect(find.text('Accueil séries'), findsOneWidget);
    expect(router.canPop(), false);
    semantics.dispose();
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('home finishes the introductory flow before leaving', (t) async {
    var finished = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/intro',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Accueil')),
        ),
        GoRoute(
          path: '/intro',
          builder: (_, _) => Scaffold(
            body: NitrateHomeButton(
              beforeHome: () async {
                finished = true;
              },
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(TextButton));
    await t.pumpAndSettle();
    expect(finished, true);
    expect(router.canPop(), false);
    expect(find.text('Accueil'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
