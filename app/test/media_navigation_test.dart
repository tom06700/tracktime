import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/screens/movie_history_screen.dart';
import 'package:tracktime/screens/movies_screen.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/tmdb/tvdb.dart';

/// Client muet : les écrans lancent une synchro au montage, dont l'échec
/// réseau lèverait une erreur asynchrone en plein test.
TvdbClient _silentTvdb() => TvdbClient(
  'test',
  client: MockClient(
    (_) async => http.Response('{"data":{"token":"t"},"status":"success"}', 200),
  ),
);

/// Routes réduites à ce qui nous intéresse : on note ce qui a été ouvert.
GoRouter _router(Widget home, List<String> opened) => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => Scaffold(body: home)),
    GoRoute(
      path: '/movie/:id',
      builder: (_, state) {
        opened.add('/movie/${state.pathParameters['id']}');
        return const Scaffold(body: Text('fiche film'));
      },
    ),
    GoRoute(
      path: '/movie-history',
      builder: (_, _) => const Scaffold(body: Text('historique')),
    ),
    GoRoute(
      path: '/show/:id',
      builder: (_, state) {
        opened.add('/show/${state.pathParameters['id']}');
        return const Scaffold(body: Text('fiche série'));
      },
    ),
  ],
);

Future<void> _mount(
  WidgetTester tester,
  AppDatabase db,
  Widget home,
  List<String> opened, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = _router(home, opened);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tvdbClientProvider.overrideWithValue(_silentTvdb()),
      ],
      child: MaterialApp.router(
        theme: buildTheme(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Laisse une navigation se dérouler entièrement.
Future<void> _navigate(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<AppDatabase> _withMovies() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.upsertMovie(
    MoviesCompanion.insert(id: const Value(1406), title: 'Dune'),
  );
  await db.upsertMovie(
    MoviesCompanion.insert(id: const Value(27205), title: 'Inception'),
  );
  return db;
}

void main() {
  testWidgets('une affiche de la grille Films ouvre sa fiche', (tester) async {
    // La régression : la carte recevait bien un onTap, mais rien ne le
    // branchait — l'affiche n'était reliée à aucun détecteur de geste.
    final db = await _withMovies();
    addTearDown(db.close);
    final opened = <String>[];

    await _mount(tester, db, const MoviesScreen(), opened);
    await tester.tap(find.text('Dune'));
    await _navigate(tester);

    expect(opened, ['/movie/1406']);
    await _settle(tester);
  });

  testWidgets('l\'affiche elle-même est tappable, pas seulement le titre', (
    tester,
  ) async {
    final db = await _withMovies();
    addTearDown(db.close);
    final opened = <String>[];

    await _mount(tester, db, const MoviesScreen(), opened);
    // Au centre de l'affiche : ni le titre en dessous, ni les deux boutons
    // posés dans les coins.
    await tester.tapAt(tester.getCenter(find.byType(AspectRatio).first));
    await _navigate(tester);

    expect(opened, hasLength(1));
    expect(opened.single, startsWith('/movie/'));
    await _settle(tester);
  });

  testWidgets('les boutons posés sur l\'affiche ne naviguent pas', (
    tester,
  ) async {
    final db = await _withMovies();
    addTearDown(db.close);
    final opened = <String>[];

    await _mount(tester, db, const MoviesScreen(), opened);
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await _navigate(tester);

    expect(opened, isEmpty, reason: 'le menu s\'ouvre, il ne navigue pas');
    await _settle(tester);
  });

  testWidgets('l\'historique des films ouvre la fiche', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertMovie(
      MoviesCompanion.insert(
        id: const Value(1406),
        title: 'Dune',
        watchedAt: Value(DateTime(2026, 1, 1)),
      ),
    );
    final opened = <String>[];

    await _mount(tester, db, const MovieHistoryScreen(), opened);
    await tester.tap(find.text('Dune'));
    await _navigate(tester);

    expect(opened, ['/movie/1406']);
    await _settle(tester);
  });

  testWidgets('naviguer puis revenir ne laisse aucune exception', (
    tester,
  ) async {
    final db = await _withMovies();
    addTearDown(db.close);
    final opened = <String>[];

    await _mount(tester, db, const MoviesScreen(), opened);
    await tester.tap(find.text('Dune'));
    await _navigate(tester);
    expect(find.text('fiche film'), findsOneWidget);

    // Retour : le bouton et le geste système aboutissent au même endroit.
    final context = tester.element(find.text('fiche film'));
    GoRouter.of(context).pop();
    await _navigate(tester);

    expect(find.byType(MoviesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _settle(tester);
  });

  testWidgets('avec les animations réduites, la navigation aboutit quand même',
      (tester) async {
    final db = await _withMovies();
    addTearDown(db.close);
    final opened = <String>[];

    await _mount(tester, db, const MoviesScreen(), opened, reduceMotion: true);
    await tester.tap(find.text('Dune'));
    await _navigate(tester);

    expect(opened, ['/movie/1406']);
    expect(tester.takeException(), isNull);
    await _settle(tester);
  });

  testWidgets('aucun conflit de Hero pendant l\'ouverture d\'une fiche', (
    tester,
  ) async {
    final db = await _withMovies();
    addTearDown(db.close);
    final opened = <String>[];

    await _mount(tester, db, const MoviesScreen(), opened);
    final tags = tester
        .widgetList<Hero>(find.byType(Hero))
        .map((h) => h.tag)
        .toList();
    expect(tags.toSet().length, tags.length, reason: 'aucun tag en double');

    await tester.tap(find.text('Dune'));
    await _navigate(tester);
    expect(tester.takeException(), isNull);
    await _settle(tester);
  });
}
