import 'dart:convert';

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
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/tmdb/tvdb.dart';
import 'package:tracktime/screens/explorer_screen.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/widgets/nitrate_banner.dart';

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
        recentSeriesProvider.overrideWith((ref) async => series),
        recentMoviesProvider.overrideWith((ref) async => movies),
        recentAnimeSeriesProvider.overrideWith(
          (ref) async => [_item(800, 'Anime récent')],
        ),
        recentAnimeMoviesProvider.overrideWith(
          (ref) async => [_item(801, 'Film animé récent')],
        ),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
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
  testWidgets('retour visible dans une grille profonde et position restaurée', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _mount(tester, db,
      series: List.generate(20, (i) => _item(i + 1, 'Série $i')),
      movies: List.generate(20, (i) => _item(i + 100, 'Film $i')));
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    scroll.jumpTo(100);
    await tester.pump();
    final before = scroll.offset;
    await tester.tap(find.byTooltip('Tout voir : Nouvelles séries'));
    await tester.pumpAndSettle();
    scroll.jumpTo(700);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retour à la découverte').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Retour à la découverte'));
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(before, 1));
    await tester.tap(find.byTooltip('Tout voir : Nouvelles séries'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('20 titres'), findsNothing);
    expect(scroll.offset, closeTo(before, 1));
    await _settle(tester);
  });

  testWidgets('saisir une recherche ne déplace pas le champ', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _mount(tester, db, series: [_item(1, 'Série')]);
    final before = tester.getTopLeft(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Sherlock');
    await tester.pump();
    expect(tester.getTopLeft(find.byType(TextField)), before);
    await tester.tap(find.byTooltip('Effacer'));
    await tester.pumpAndSettle();
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    scroll.jumpTo(84);
    await tester.pump();
    final pinned = tester.getTopLeft(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Sherlock');
    await tester.pump();
    expect(tester.getTopLeft(find.byType(TextField)), pinned);
    await _settle(tester);
  });

  testWidgets(
    'un toucher hors recherche ferme le clavier sans effacer le texte',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _mount(
        tester,
        db,
        tvdb: _searchTvdb({
          'dune': [_hit('movie', 'Dune', 42), _hit('series', 'Dune série', 43)],
        }),
      );
      await _type(tester, 'dune');
      expect(tester.testTextInput.isVisible, isTrue);
      final field = find.byType(TextField);
      await tester.tapAt(tester.getTopLeft(field) + const Offset(-10, 24));
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.widget<TextField>(field).controller!.text, 'dune');
      expect(find.text('Dune'), findsOneWidget);

      // A filter tap still performs its action while dismissing the keyboard.
      await tester.tap(field);
      await tester.pump();
      await tester.tap(find.text('Films'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Dune'), findsOneWidget);
      expect(find.text('Dune série'), findsNothing);

      // Controls inside the field remain part of its editing region.
      await tester.tap(field);
      await tester.pump();
      await tester.tap(find.byTooltip('Effacer'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(tester.testTextInput.isVisible, isTrue);
      await _settle(tester);
    },
  );

  testWidgets(
    'la confirmation ouvre la bonne fiche sans marquer d’épisode vu',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final api = TvdbClient(
        'test',
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'data': req.url.path.endsWith('/login')
                  ? {'token': 't'}
                  : {'name': 'Young Sherlock'},
            }),
            200,
          ),
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: AddButton(
                id: 450633,
                isSeries: true,
                name: 'Young Sherlock',
                already: false,
              ),
            ),
          ),
          GoRoute(
            path: '/show/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Fiche ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tvdbClientProvider.overrideWithValue(api),
          ],
          child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Ajouter Young Sherlock'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('Voir la série'));
      await tester.pumpAndSettle();
      expect(find.text('Fiche 450633'), findsOneWidget);
      expect(await db.showById(450633), isNotNull);
      expect(await db.select(db.watchedEpisodes).get(), isEmpty);
      await _settle(tester);
    },
  );

  testWidgets(
    'une affiche ajoutée reste visible et confirmée pendant la visite',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final api = TvdbClient(
        'test',
        client: MockClient((req) async {
          return http.Response(
            jsonEncode({
              'data': req.url.path.endsWith('/login')
                  ? {'token': 't'}
                  : {'name': 'Young Sherlock'},
            }),
            200,
          );
        }),
      );
      await _mount(
        tester,
        db,
        series: [_item(450633, 'Young Sherlock')],
        tvdb: api,
      );
      await tester.tap(find.bySemanticsLabel('Ajouter Young Sherlock'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(await db.showById(450633), isNotNull);
      expect(find.text('Young Sherlock'), findsNWidgets(2));
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Ajouté à Mes séries'), findsOneWidget);
      expect(find.text('Voir la série'), findsOneWidget);
      final confirmation = find.descendant(
        of: find.byType(NitrateBanner),
        matching: find.text('Young Sherlock'),
      );
      final message = tester.widget<Text>(confirmation);
      final inheritedStyle = DefaultTextStyle.of(
        tester.element(confirmation),
      ).style;
      expect(inheritedStyle.merge(message.style).color, Colors.white);
      final actionText = tester.widget<RichText>(
        find
            .descendant(
              of: find.byType(NitrateBannerAction),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(actionText.text.style?.color, Colors.white);
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.byType(NitrateBanner), findsNothing);
      expect(find.text('Young Sherlock'), findsOneWidget);
      expect(find.bySemanticsLabel('Ajouter Young Sherlock'), findsNothing);
      final tabs = ProviderScope.containerOf(
        tester.element(find.byType(ExplorerScreen)),
      ).read(homeTabProvider.notifier);
      tabs.select(HomeTab.movies);
      await tester.pump();
      tabs.select(HomeTab.explorer);
      await tester.pump();
      expect(
        find.text('Young Sherlock'),
        findsNothing,
        reason: 'La visite suivante exclut de nouveau la collection',
      );
      await _settle(tester);
    },
  );

  testWidgets('un titre anglais de découverte privilégie aussi le français', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _mount(
      tester,
      db,
      movies: [_item(276, 'Spirited Away')],
      tvdb: TvdbClient(
        'test',
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'data': req.url.path.endsWith('/login')
                  ? {'token': 't'}
                  : {'name': 'Le Voyage de Chihiro'},
            }),
            200,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Le Voyage de Chihiro'), findsOneWidget);
    expect(find.text('Spirited Away'), findsNothing);
    await _settle(tester);
  });

  testWidgets('les affiches japonaises utilisent leur titre traduit', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _mount(
      tester,
      db,
      series: [_item(81797, 'ワンピース')],
      tvdb: TvdbClient(
        'test',
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'data': req.url.path.endsWith('/login')
                  ? {'token': 't'}
                  : {'name': 'One Piece'},
            }),
            200,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('One Piece'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets(
    'Animés possède sa découverte et filtre sans garder le live action',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _mount(
        tester,
        db,
        tvdb: _searchTvdb({
          'one piece': [
            {
              ..._hit('series', 'One Piece animé', 81797),
              'genres': ['Anime'],
            },
            _hit('series', 'One Piece live action', 392276),
            {
              ..._hit('movie', 'One Piece Film Red', 318462),
              'genres': ['Anime'],
            },
          ],
        }),
      );
      await tester.tap(find.text('Animés'));
      await tester.pumpAndSettle();
      expect(find.text('Nouveaux animés'), findsOneWidget);
      expect(find.text('Anime récent'), findsOneWidget);
      await _type(tester, 'one piece');
      expect(find.text('One Piece animé'), findsOneWidget);
      expect(find.text('One Piece live action'), findsNothing);
      await tester.tap(find.text('Tout'));
      await tester.pumpAndSettle();
      expect(find.text('One Piece live action'), findsOneWidget);
      await tester.tap(find.text('Animés'));
      await tester.pumpAndSettle();
      expect(find.text('One Piece live action'), findsNothing);
      expect(find.text('One Piece Film Red'), findsOneWidget);
      await _settle(tester);
    },
  );

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

    expect(find.text('Nouvelles séries'), findsOneWidget);
    expect(find.text('Films récents'), findsOneWidget);
    expect(find.text('Tu pars où ?'), findsNothing);
    expect(find.text('Stranger Things'), findsOneWidget);
    expect(find.text('Titanic'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('une sélection ouvre sa grille et revient à la découverte', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _mount(
      tester,
      db,
      series: List.generate(20, (i) => _item(i + 1, 'Série $i')),
      movies: [_item(100, 'Film témoin')],
    );
    await tester.tap(find.byTooltip('Tout voir : Nouvelles séries'));
    await tester.pump();
    expect(find.text('20 titres'), findsOneWidget);
    expect(find.text('Films récents'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(find.text('Films').hitTestable(), findsOneWidget);
    // Changer de filtre depuis une grille profonde ramène au nouveau contenu.
    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();
    expect(find.text('Film témoin').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Tout'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tout voir : Nouvelles séries'));
    await tester.pump();
    await tester.tap(find.byTooltip('Retour à la découverte'));
    await tester.pump();
    expect(find.text('Films récents'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('découverte lisible à 320 px avec texte doublé', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _mount(
      tester,
      db,
      size: const Size(320, 740),
      scale: 2,
      series: [_item(1, 'Une série avec un titre particulièrement long')],
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Une série avec un titre particulièrement long'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await _settle(tester);
  });

  testWidgets('un titre déjà suivi ne réapparaît pas dans la découverte', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertShow(
      ShowsCompanion.insert(id: const Value(1), name: 'Stranger Things'),
    );

    await _mount(tester, db, series: [_item(1, 'Stranger Things', '2016')]);

    // La découverte laisse la place à de nouvelles œuvres.
    expect(find.text('Stranger Things'), findsNothing);
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
    expect(find.text('Que regarder ce soir ?'), findsNothing);

    // Deux titres : la proposition apparaît.
    await db.upsertMovie(
      MoviesCompanion.insert(id: const Value(2), title: 'Arrival'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Que regarder ce soir ?'), findsOneWidget);

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

    // Le champ reste à sa place pendant la saisie ; le logo peut ensuite
    // défiler naturellement, sans déplacer le clavier ou perdre le focus.
    expect(tester.getTopLeft(find.byType(TextField)).dy, 84);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

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
