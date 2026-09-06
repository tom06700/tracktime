import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/tmdb/tvdb.dart';
import 'package:tracktime/screens/explorer_screen.dart';
import 'package:tracktime/theme.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Map<String, dynamic> _item(int id, String name, [String? year]) => {
      'id': id,
      'name': name,
      'year': year,
      'image': 'https://artworks.thetvdb.com/x.jpg',
    };

/// Monte Explorer avec des rangées de découverte figées : aucun appel réseau,
/// les tests restent déterministes.
Future<void> _mount(
  WidgetTester tester,
  AppDatabase db, {
  List<Map<String, dynamic>> series = const [],
  List<Map<String, dynamic>> movies = const [],
  TvdbClient? tvdb,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  // Surface d'iPhone : la surface de test par défaut (800×600) donnerait des
  // cellules de grille démesurées, poussant les boutons hors de l'écran.
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tvdbClientProvider.overrideWithValue(tvdb ?? _silentTvdb()),
        popularSeriesProvider.overrideWith((ref) async => series),
        popularMoviesProvider.overrideWith((ref) async => movies),
        upcomingReleasesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: child!),
        home: const Scaffold(body: ExplorerScreen()),
      ),
    ),
  );
  // Plusieurs pompes : les flux drift émettent de façon asynchrone, une seule
  // ne suffit pas pour que la base ait alimenté les providers.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

/// Client TheTVDB muet : les écrans déclenchent une synchro au montage, et son
/// échec réseau lèverait une erreur asynchrone non gérée en plein test.
TvdbClient _silentTvdb() => TvdbClient(
      'test',
      client: MockClient(
        (_) async =>
            http.Response('{"data":{"token":"t"},"status":"success"}', 200),
      ),
    );

/// Client renvoyant une réponse de recherche par requête, avec un délai
/// optionnel pour simuler une réponse arrivant en retard.
TvdbClient _searchTvdb(
  Map<String, List<Map<String, dynamic>>> byQuery, {
  Map<String, Duration> delays = const {},
}) {
  return TvdbClient(
    'test',
    client: MockClient((req) async {
      if (req.url.path.endsWith('/login')) {
        return http.Response('{"data":{"token":"t"},"status":"success"}', 200);
      }
      final q = req.url.queryParameters['query'] ?? '';
      final wait = delays[q];
      if (wait != null) await Future<void>.delayed(wait);
      return http.Response(
        jsonEncode({'data': byQuery[q] ?? const []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

Map<String, dynamic> _hit(String type, String name, int id) => {
      'type': type,
      'name': name,
      'tvdb_id': id,
    };

/// Saisit une requête et laisse passer le debounce.
Future<void> _type(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField), q);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('sans recherche, l\'écran montre de quoi découvrir', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _mount(
      tester,
      db,
      series: [_item(1, 'Stranger Things', '2016')],
      movies: [_item(2, 'Titanic', '1997')],
    );

    expect(find.text('Tu pars où ?'), findsOneWidget);
    expect(find.text('Stranger Things'), findsOneWidget);
    expect(find.text('Titanic'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('découverte lisible à 320 px avec texte doublé', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _mount(tester, db,
        size: const Size(320, 740),
        scale: 2,
        series: [_item(1, 'Une série avec un titre particulièrement long')]);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
        find.text('Une série avec un titre particulièrement long'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await _settle(tester);
  });

  testWidgets('un titre déjà suivi s\'annonce comme ajouté', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertShow(
      ShowsCompanion.insert(id: const Value(1), name: 'Stranger Things'),
    );

    await _mount(tester, db, series: [_item(1, 'Stranger Things', '2016')]);

    // Le bouton bascule sur la coche : plus d'invitation à ajouter.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);

    await _settle(tester);
  });

  testWidgets('les filtres restent accessibles avant et pendant la recherche', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _mount(tester, db);
    expect(find.text('Tout'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'dune');
    await tester.pump();

    expect(find.text('Tout'), findsOneWidget);
    expect(find.text('Séries'), findsOneWidget);
    expect(find.text('Films'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('la carte « ce soir » attend une liste fournie', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Un seul film : pas de quoi tirer au sort, la carte reste absente.
    await db.upsertMovie(
      MoviesCompanion.insert(id: const Value(1), title: 'Dune'),
    );
    await _mount(tester, db);
    expect(find.text('Quoi regarder ce soir ?'), findsNothing);

    // Deux titres : la proposition apparaît.
    await db.upsertMovie(
      MoviesCompanion.insert(id: const Value(2), title: 'Arrival'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Quoi regarder ce soir ?'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('les filtres restreignent par type de média', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final tvdb = _searchTvdb({
      'one piece': [
        _hit('series', 'One Piece', 81797),
        _hit('movie', 'One Piece Film: Red', 318462),
        // Les listes d'utilisateurs ne doivent jamais atteindre l'écran.
        _hit('list', 'One Piece', 11),
      ],
    });

    await _mount(tester, db, tvdb: tvdb);
    await _type(tester, 'one piece');

    // « Tout » : les deux médias, jamais la liste.
    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('One Piece Film: Red'), findsOneWidget);

    await tester.tap(find.text('Séries'));
    await tester.pump();
    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('One Piece Film: Red'), findsNothing);

    await tester.tap(find.text('Films'));
    await tester.pump();
    expect(find.text('One Piece'), findsNothing);
    expect(find.text('One Piece Film: Red'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('une réponse tardive n\'écrase pas la recherche courante', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final tvdb = _searchTvdb(
      {
        'one': [_hit('series', 'Résultat périmé', 1)],
        'one piece': [_hit('series', 'One Piece', 81797)],
      },
      // « one » répond après « one piece ».
      delays: {'one': const Duration(milliseconds: 900)},
    );

    await _mount(tester, db, tvdb: tvdb);
    await _type(tester, 'one');
    await _type(tester, 'one piece');

    expect(find.text('One Piece'), findsOneWidget);

    // Laisse la réponse retardataire arriver : elle doit être ignorée.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.text('Résultat périmé'), findsNothing);
    expect(find.text('One Piece'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('un anime sans affiche reste dans les résultats', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final tvdb = _searchTvdb({
      'naruto': [
        {
          'type': 'series',
          'name': 'NARUTO－ナルト－',
          'tvdb_id': 78857,
          'translations': {'eng': 'Naruto'},
          // Aucune image : le résultat doit tout de même s'afficher.
        },
      ],
    });

    await _mount(tester, db, tvdb: tvdb);
    await _type(tester, 'naruto');

    expect(find.text('Naruto'), findsOneWidget);

    await _settle(tester);
  });
}
