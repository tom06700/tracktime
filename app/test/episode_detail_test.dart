import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'support/audit_fonts.dart';
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
  void episodeTest(String name, Future<void> Function(WidgetTester) body,
      {bool skip = false}) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      }
    }, skip: skip);
  }

  Future<AppDatabase> mount(WidgetTester tester, EpisodeFixture api,
      {double scale = 1,
      bool reduce = true,
      int initial = 1155,
      Size size = const Size(390, 844)}) async {
    if (Platform.environment['NITRATE_EPISODE_AUDIT'] == '1') {
      await tester.runAsync(loadAuditFonts);
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.upsertShow(
        ShowsCompanion.insert(id: const Value(1), name: 'Série test'));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
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
                    disableAnimations: reduce,
                    textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                    key: const ValueKey('episode-audit'), child: child!)),
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
                    disableAnimations: reduce,
                    textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                    key: const ValueKey('episode-audit'), child: child!)),
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
    final button = find.ancestor(
        of: finder, matching: find.bySubtype<ButtonStyleButton>());
    final target = button.evaluate().isEmpty ? finder : button.first;
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.environment['NITRATE_EPISODE_AUDIT'] != '1') return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('episode-audit')));
    readableAuditFonts(boundary);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = Directory('build/modern-audit')..createSync(recursive: true);
      File('${out.path}/$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  episodeTest(
      '1200 épisodes, résumé protégé, accès direct et navigation sans écriture',
      (tester) async {
    final api = EpisodeFixture(List.generate(1200, (i) => i + 1));
    final db = await mount(tester, api);
    expect(find.text('ÉP. 1155'), findsOneWidget);
    await capture(tester, 'episode-1155');
    expect(find.textContaining('1155 sur 1200'), findsOneWidget);
    expect(find.text('Résumé caché 1155'), findsNothing);
    await tap(tester, find.text('Révéler le résumé'));
    expect(find.text('Résumé caché 1155'), findsOneWidget);
    await tap(tester, find.text('Tous les épisodes'));
    expect(find.byType(ListTile).evaluate().length, lessThan(25));
    await capture(tester, 'episode-picker-1200');
    await tester.enterText(find.byType(TextField), '1201');
    await tap(tester, find.text('Aller'));
    expect(
        find.text('Ce numéro n’existe pas dans cette saison.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1200');
    await tap(tester, find.text('Aller'));
    expect(find.text('ÉP. 1200'), findsOneWidget);
    await capture(tester, 'episode-1200-scale');
    expect(find.text('Résumé caché 1155'), findsNothing);
    expect(await db.allWatchedEpisodes(), isEmpty);
    expect(api.calls, 1);
    expect(tester.takeException(), isNull);
  });
  episodeTest('trous, dates absentes, petit écran et texte agrandi',
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
    await capture(tester, 'episode-1200-scale');
    expect(await db.allWatchedEpisodes(), isEmpty);
    expect(tester.takeException(), isNull);
  });
  episodeTest('cocher ne change pas de page, rattrapage confirmé puis annulé',
      (tester) async {
    final db = await mount(tester, EpisodeFixture([1, 3, 1155]));
    final old = DateTime(2020, 2, 3);
    await db.setEpisodeWatched(1, 1, 1, at: old);
    await tap(tester, find.text('Marquer vu'));
    await tester.runAsync(() => db.allWatchedEpisodes());
    await tester.pumpAndSettle();
    expect(find.text('Titre 1155'), findsOneWidget);
    expect(
        (await tester.runAsync(db.allWatchedEpisodes))!
            .map((e) => 'S${e.season}E${e.episode}')
            .toSet(),
        {'S1E1', 'S1E1155'});
    await tap(tester, find.text('Tout marquer jusqu’ici'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Confirmer'), findsOneWidget);
    await capture(tester, 'episode-confirm');
    expect(
        (await tester.runAsync(db.allWatchedEpisodes))!
            .map((e) => 'S${e.season}E${e.episode}')
            .toSet(),
        {'S1E1', 'S1E1155'});
    await tap(tester, find.text('Confirmer'));
    await tester.runAsync(() => db.allWatchedEpisodes());
    await tester.pumpAndSettle();
    await tap(tester, find.text('Annuler ce rattrapage'));
    await tester.runAsync(() => db.allWatchedEpisodes());
    await tester.pumpAndSettle();
    expect(
        (await tester.runAsync(db.allWatchedEpisodes))!
            .map((e) => 'S${e.season}E${e.episode}')
            .toSet(),
        {'S1E1', 'S1E1155'});
    expect(
        (await tester.runAsync(db.allWatchedEpisodes))!
            .firstWhere((e) => e.season == 1 && e.episode == 1)
            .watchedAt,
        old);
  });
  episodeTest('erreur de catalogue visible puis réessai', (tester) async {
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
  episodeTest('séquence visuelle de confirmation après sauvegarde',
      (tester) async {
    final db =
        await mount(tester, EpisodeFixture([1, 1155, 1200]), reduce: false);
    final button = find
        .ancestor(
            of: find.text('Marquer vu'), matching: find.byType(FilledButton))
        .first;
    await Scrollable.ensureVisible(tester.element(button), alignment: .75);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    for (var frame = 0; frame < 14; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      await capture(tester, 'episode-motion-$frame');
    }
    expect((await tester.runAsync(db.allWatchedEpisodes))!.length, 1);
  }, skip: Platform.environment['NITRATE_EPISODE_AUDIT'] != '1');
}
