import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracktime/notifications/feed.dart';
import 'package:tracktime/notifications/providers.dart';
import 'package:tracktime/notifications/screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'lectures concurrentes conservées après recréation du provider',
    () async {
      final c = ProviderContainer();
      await c.read(notificationReadProvider.future);
      await Future.wait([
        c.read(notificationReadProvider.notifier).markRead(['episode:1:1:1']),
        c.read(notificationReadProvider.notifier).markRead(['movie:7']),
      ]);
      c.dispose();
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(await next.read(notificationReadProvider.future), {
        'episode:1:1:1',
        'movie:7',
      });
    },
  );
  final items = [
    ReleaseNotification(
      id: 'movie:7',
      kind: ReleaseKind.movie,
      title: 'Un film attendu',
      detail: 'Nouvelle sortie',
      day: DateTime(2026, 9, 8),
      location: '/movie/7',
      extra: 'Un film attendu',
    ),
  ];

  testWidgets('Tout lire retire l’indicateur sans supprimer la notification', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          releaseNotificationsProvider.overrideWith((ref) async => items),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('1 non lue'), findsOneWidget);
    await t.tap(find.text('Tout lire'));
    await t.pumpAndSettle();
    expect(find.text('Tu es à jour'), findsOneWidget);
    expect(find.text('Un film attendu'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        notificationReadKey,
      ),
      ['movie:7'],
    );
  });
  testWidgets('toucher une notification la lit puis ouvre la bonne fiche', (
    t,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const NotificationsScreen()),
        GoRoute(
          path: '/movie/7',
          builder: (_, state) => Scaffold(body: Text('Fiche : ${state.extra}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          releaseNotificationsProvider.overrideWith((ref) async => items),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Un film attendu'));
    await t.pumpAndSettle();
    expect(find.text('Fiche : Un film attendu'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        notificationReadKey,
      ),
      ['movie:7'],
    );
  });
  testWidgets('une collection sans sortie affiche un état vide honnête', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          releaseNotificationsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Rien de nouveau\npour le moment'), findsOneWidget);
    expect(find.text('Tout lire'), findsNothing);
  });
}
