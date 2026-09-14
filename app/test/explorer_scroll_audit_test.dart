@Tags(['audit'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/screens/explorer_screen.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/tmdb/tvdb.dart';

void main() {
  testWidgets(
    'audit local du défilement Explorer',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      await (FontLoader(
        'Inter',
      )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
      final fonts = Platform.environment['NITRATE_AUDIT_FONTS']!;
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(
              ByteData.sublistView(
                File('$fonts/MaterialIcons-Regular.otf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
      final out = Directory('../docs/audits/2026-09-14-explorer-scroll-after')
        ..createSync(recursive: true);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      for (var i = 1; i <= 2; i++) {
        await db.upsertMovie(
          MoviesCompanion.insert(id: Value(i), title: 'Ma liste $i'),
        );
      }
      final series = List.generate(
        20,
        (i) => <String, dynamic>{
          'id': 1000 + i,
          'name': 'Série ${i + 1}',
          'year': '2026',
        },
      );
      final movies = List.generate(
        20,
        (i) => <String, dynamic>{
          'id': 2000 + i,
          'name': 'Film ${i + 1}',
          'year': '2026',
        },
      );
      final api = TvdbClient(
        'test',
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'data': req.url.path.endsWith('/login')
                  ? {'token': 'test'}
                  : req.url.path.endsWith('/search')
                  ? movies
                        .map((m) => {...m, 'tvdb_id': m['id'], 'type': 'movie'})
                        .toList()
                  : <String, dynamic>{},
            }),
            200,
          ),
        ),
      );
      final key = GlobalKey();
      var scale = 1.0;
      late StateSetter updateMedia;
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tvdbClientProvider.overrideWithValue(api),
            recentSeriesProvider.overrideWith((_) async => series),
            recentMoviesProvider.overrideWith((_) async => movies),
            recentAnimeSeriesProvider.overrideWith((_) async => series),
            recentAnimeMoviesProvider.overrideWith((_) async => movies),
          ],
          child: MaterialApp(
            theme: buildTheme().copyWith(platform: TargetPlatform.iOS),
            builder: (context, child) => StatefulBuilder(
              builder: (context, setState) {
                updateMedia = setState;
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 59, bottom: 34),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: RepaintBoundary(key: key, child: child!),
                );
              },
            ),
            home: const Scaffold(body: ExplorerScreen()),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 60));
      }
      await t.pumpAndSettle();
      final report = <String, dynamic>{};
      final scroll = t
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      Map<String, dynamic> geometry() => {
        'offset': scroll.offset,
        'extent': scroll.position.maxScrollExtent,
        'headerY': t.getTopLeft(find.byType(TextField)).dy,
        'pinnedHeight': t
            .renderObject<RenderSliver>(
              find.byKey(const ValueKey('explorer-search-header')),
            )
            .geometry!
            .maxPaintExtent,
      };
      Future<void> capture(String name) async {
        await t.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await t.runAsync(
          () => boundary.toImage(pixelRatio: 1.5),
        ))!;
        final bytes = await t.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        );
        File(
          '${out.path}/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
        report[name] = geometry();
        expect(t.takeException(), isNull);
      }

      await capture('01-arrivee');
      // Reach the second rail using a real vertical drag on the scroll view.
      await t.drag(find.byType(CustomScrollView), const Offset(0, -410));
      await t.pumpAndSettle();
      await capture('02-defilement');
      final savedOffset = scroll.offset;
      await t.ensureVisible(find.byTooltip('Tout voir : Films récents'));
      await t.tap(find.byTooltip('Tout voir : Films récents'));
      await t.pumpAndSettle();
      await capture('03-grille');
      await t.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await t.pumpAndSettle();
      report['gridScrolled'] = geometry();
      // Back stays pinned even deep in the grid.
      report['backVisibleWhenScrolled'] = find
          .byTooltip('Retour à la découverte')
          .hitTestable()
          .evaluate()
          .isNotEmpty;
      expect(report['backVisibleWhenScrolled'], isTrue);
      await t.tap(find.byTooltip('Retour à la découverte'));
      await t.pumpAndSettle();
      await capture('04-retour-decouverte');
      report['discoveryBeforeGrid'] = savedOffset;
      await t.enterText(find.byType(TextField), 'film');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      await capture('05-recherche');
      await t.tapAt(const Offset(8, 300));
      await t.pump();
      await t.tap(find.byTooltip('Effacer'));
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(320, 640);
      updateMedia(() => scale = 2);
      await t.pumpAndSettle();
      scroll.jumpTo(180);
      await t.pumpAndSettle();
      await capture('06-grand-texte');
      File(
        '${out.path}/mesures.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 1));
    },
    skip: Platform.environment['NITRATE_EXPLORER_AUDIT'] != '1',
  );
}
