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
}) async {
  // Surface d'iPhone : la surface de test par défaut (800×600) donnerait des
  // cellules de grille démesurées, poussant les boutons hors de l'écran.
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tvdbClientProvider.overrideWithValue(_silentTvdb()),
        popularSeriesProvider.overrideWith((ref) async => series),
        popularMoviesProvider.overrideWith((ref) async => movies),
        upcomingReleasesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: buildTheme(),
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
    (_) async => http.Response('{"data":{"token":"t"},"status":"success"}', 200),
  ),
);

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

    expect(find.text('Séries populaires'), findsOneWidget);
    expect(find.text('Films populaires'), findsOneWidget);
    expect(find.text('Stranger Things'), findsOneWidget);
    expect(find.text('Titanic'), findsOneWidget);

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

  testWidgets('les filtres n\'apparaissent qu\'une fois la recherche lancée', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _mount(tester, db);
    expect(find.text('Tout'), findsNothing);

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
    expect(find.textContaining('regarde ce soir'), findsNothing);

    // Deux titres : la proposition apparaît.
    await db.upsertMovie(
      MoviesCompanion.insert(id: const Value(2), title: 'Arrival'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('regarde ce soir'), findsOneWidget);
    expect(find.text('Choisir pour moi'), findsOneWidget);

    await _settle(tester);
  });
}
