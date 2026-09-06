import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/screens/episode_detail_screen.dart';
import 'package:tracktime/tmdb/tvdb.dart';
import 'package:tracktime/theme.dart';

class EpisodeFixture extends TvdbClient {
  EpisodeFixture(this.numbers) : super('');
  final List<int> numbers;
  int calls = 0;
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> seriesEpisodes(int id,
      {bool force = false}) async {
    calls++;
    if (fail) throw StateError('offline');
    return [
      for (final n in numbers)
        {
          'season': 1,
          'episode': n,
          'name': 'Titre $n',
          'overview': n == 1156 ? null : 'Résumé caché $n',
          'runtime': n == 1156 ? null : 24
        }
    ];
  }
}

void main() {
  Future<AppDatabase> mount(WidgetTester tester, EpisodeFixture api,
      {double scale = 1,
      int initial = 1155,
      Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.upsertShow(
        ShowsCompanion.insert(id: const Value(1), name: 'Série test'));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await db.close();
    });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tvdbClientProvider.overrideWithValue(api)
        ],
        child: MaterialApp(
            theme: buildTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const Scaffold(body: SizedBox()))));
    // Keep the same provider container while installing the sheet.
    await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tvdbClientProvider.overrideWithValue(api)
        ],
        child: MaterialApp(
            theme: buildTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: EpisodeSheet(
                    showId: 1,
                    showName: 'Série test',
                    season: 1,
                    initialEpisode: initial)))));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
      '1200 épisodes, résumé protégé, accès direct et navigation sans écriture',
      (tester) async {
    final api = EpisodeFixture(List.generate(1200, (i) => i + 1));
    final db = await mount(tester, api);
    expect(find.text('ÉP. 1155'), findsOneWidget);
    expect(find.textContaining('1155 sur 1200'), findsOneWidget);
    expect(find.text('Résumé caché 1155'), findsNothing);
    await tap(tester, find.text('Révéler le résumé'));
    expect(find.text('Résumé caché 1155'), findsOneWidget);
    await tap(tester, find.text('Tous les épisodes'));
    expect(find.byType(ListTile).evaluate().length, lessThan(25));
    await tester.enterText(find.byType(TextField), '1201');
    await tap(tester, find.text('Aller'));
    expect(
        find.text('Ce numéro n’existe pas dans cette saison.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1200');
    await tap(tester, find.text('Aller'));
    expect(find.text('ÉP. 1200'), findsOneWidget);
    expect(find.text('Résumé caché 1155'), findsNothing);
    expect(await db.allWatchedEpisodes(), isEmpty);
    expect(api.calls, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('trous, dates absentes, petit écran et texte agrandi',
      (tester) async {
    final db = await mount(tester, EpisodeFixture([1155, 1156, 1200]),
        scale: 2, size: const Size(320, 568));
    await tap(tester, find.text('Épisode 1156'));
    expect(find.text('ÉP. 1156'), findsOneWidget);
    await tap(tester, find.text('Tous les épisodes'));
    await tester.enterText(find.byType(TextField), '1157');
    await tap(tester, find.text('Aller'));
    expect(
        find.text('Ce numéro n’existe pas dans cette saison.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1200');
    await tap(tester, find.text('Aller'));
    expect(find.text('ÉP. 1200'), findsOneWidget);
    expect(await db.allWatchedEpisodes(), isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cocher ne change pas de page, rattrapage confirmé puis annulé',
      (tester) async {
    final db = await mount(tester, EpisodeFixture([1, 3, 1155]));
    final old = DateTime(2020, 2, 3);
    await db.setEpisodeWatched(1, 1, 1, at: old);
    await tap(tester, find.text('Marquer vu'));
    await tester.runAsync(() => db.allWatchedEpisodes());
    await tester.pumpAndSettle();
    expect(find.text('Titre 1155'), findsOneWidget);
    expect(await db.watchWatchedKeys(1).first, {'S1E1', 'S1E1155'});
    await tap(tester, find.text('Tout marquer jusqu’ici'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Confirmer'), findsOneWidget);
    expect(await db.watchWatchedKeys(1).first, {'S1E1', 'S1E1155'});
    await tap(tester, find.text('Confirmer'));
    await tester.runAsync(() => db.allWatchedEpisodes());
    await tester.pumpAndSettle();
    await tap(tester, find.text('Annuler ce rattrapage'));
    await tester.runAsync(() => db.allWatchedEpisodes());
    await tester.pumpAndSettle();
    expect(await db.watchWatchedKeys(1).first, {'S1E1', 'S1E1155'});
    expect((await db.watchWatchedEpisode(1, 1, 1).first)!.watchedAt, old);
  });
  testWidgets('erreur de catalogue visible puis réessai', (tester) async {
    final api = EpisodeFixture([1155])..fail = true;
    await mount(tester, api);
    expect(find.text('Épisode indisponible'), findsOneWidget);
    api.fail = false;
    await tap(tester, find.text('Réessayer'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('ÉP. 1155'), findsOneWidget);
  });
}
