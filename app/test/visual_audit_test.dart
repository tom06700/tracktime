// Audit visuel : monte la vraie app à la taille d'un iPhone, avec de vraies
// polices et de vraies images servies en local, et capture chaque écran en
// PNG pour inspection. Ne fait aucune assertion visuelle : il relève les
// exceptions de rendu (débordements, etc.) et produit les captures.
//
// Outil de travail, pas un test de non-régression : il ne s'exécute que sur
// demande, sinon `flutter test` le saute en un instant.
//
//   NITRATE_AUDIT=1 flutter test test/visual_audit_test.dart
//
// Les captures vont dans build/audit/ (ou NITRATE_AUDIT_OUT). Les polices
// viennent du cache du SDK Flutter ($HOME/flutter/bin/cache).
@Tags(['audit'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
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
import 'package:tracktime/main.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/router.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/tmdb/tvdb.dart';

final _out = Platform.environment['NITRATE_AUDIT_OUT'] ?? 'build/audit';
final _fonts = Platform.environment['NITRATE_AUDIT_FONTS'] ??
    '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts';

// ─────────────────────────────── Polices ────────────────────────────────

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String f) async =>
      ByteData.sublistView(await File('$_fonts/$f').readAsBytes());
  final roboto = FontLoader('Roboto')
    ..addFont(bytes('Roboto-Regular.ttf'))
    ..addFont(bytes('Roboto-Medium.ttf'))
    ..addFont(bytes('Roboto-Bold.ttf'))
    ..addFont(bytes('Roboto-Black.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('MaterialIcons-Regular.otf'));
  await icons.load();
  final editorial = FontLoader('CormorantGaramond')..addFont(File('assets/fonts/CormorantGaramond.ttf').readAsBytes().then(ByteData.sublistView));
  await editorial.load();
}

// ─────────────────────────── Images servies ──────────────────────────────

/// Une image par URL : dégradé dont la teinte dépend de l'URL, pour que les
/// fonds diffèrent et que les palettes aient quelque chose à extraire.
final Map<String, Uint8List> _pngs = {};

Future<Uint8List> _pngFor(String url, {int w = 640, int h = 360}) async {
  if (_pngs[url] case final b?) return b;
  final hue = (url.hashCode % 360).toDouble();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  c.drawRect(
    rect,
    Paint()
      ..shader =
          ui.Gradient.linear(Offset.zero, Offset(w.toDouble(), h.toDouble()), [
            HSLColor.fromAHSL(1, hue, 0.6, 0.55).toColor(),
            HSLColor.fromAHSL(1, (hue + 50) % 360, 0.7, 0.25).toColor(),
          ]),
  );
  // Un peu de matière pour ne pas ressembler à un aplat.
  for (var i = 0; i < 40; i++) {
    c.drawCircle(
      Offset((i * 97 % w).toDouble(), (i * 53 % h).toDouble()),
      18 + (i % 5) * 9,
      Paint()..color = Colors.white.withValues(alpha: 0.06 + (i % 3) * 0.04),
    );
  }
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return _pngs[url] = data!.buffer.asUint8List();
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this._bytes);
  final Uint8List _bytes;

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  HttpHeaders get headers => _Headers();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([_bytes]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Uint8List _fixtureBytes(Uri url) {
  final name = url.path;
  if (name.contains('371980')) {
    return _pngs[name.contains('backdrop') ? 'severance-backdrop' : 'severance'] ?? _pngs['audit']!;
  }
  if (name.contains('81797')) return _pngs['one-piece'] ?? _pngs['audit']!;
  if (name.contains('392256')) return _pngs['last-of-us'] ?? _pngs['audit']!;
  return _pngs['audit']!;
}

class _Request implements HttpClientRequest {
  _Request(this.url);
  final Uri url;
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() async =>
      _Response(_fixtureBytes(url));
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Client implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(url);
  @override
  Future<HttpClientRequest> openUrl(String m, Uri url) async => _Request(url);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

// ────────────────────────────── TheTVDB ──────────────────────────────────

http.Response _ok(Object? data, {Map<String, Object?>? extra}) => http.Response(
  jsonEncode({
    'data': data,
    'links': {'next': null},
    ...?extra,
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _hit(int id, String name, String year) => {
  'id': id,
  'tvdb_id': '$id',
  'name': name,
  'year': year,
  'image': 'https://img.test/poster-$id.jpg',
  'type': 'series',
};

TvdbClient _tvdb() => TvdbClient(
  'k',
  client: MockClient((req) async {
    final p = req.url.path;
    if (p.endsWith('/login')) {
      return http.Response('{"data":{"token":"t"}}', 200);
    }
    if (p.endsWith('/search')) return _ok([_hit(81797, 'One Piece', '1999')]);
    if (p.contains('/series/filter')) {
      return _ok([
        _hit(81797, 'One Piece', '1999'),
        _hit(70523, 'Dark', '2017'),
        _hit(371572, 'Severance', '2022'),
        _hit(392256, 'The Last of Us', '2023'),
        _hit(305288, 'Stranger Things', '2016'),
        _hit(153021, 'Arcane', '2021'),
      ]);
    }
    if (p.contains('/movies/filter')) {
      return _ok([
        _hit(1406, 'Dune', '2021'),
        _hit(496243, 'Parasite', '2019'),
        _hit(27205, 'Inception', '2010'),
        _hit(157336, 'Interstellar', '2014'),
        _hit(603, 'Oppenheimer', '2023'),
      ]);
    }
    if (p.contains('/movies/') && p.endsWith('/extended')) {
      final id = int.tryParse(p.split('/')[3]) ?? 1406;
      const titles = {
        1406: 'Dune',
        1: 'The Assassination of Jesse James by the Coward Robert Ford',
        872585: 'Once Upon a Time in Hollywood',
      };
      return _ok({
        'name': titles[id] ?? 'Dune',
        'image': 'https://img.test/poster-1406.jpg',
        'runtime': 155,
        'first_release': {'date': '2021-09-15'},
        'genres': [
          {'name': 'Science-Fiction'},
          {'name': 'Aventure'},
        ],
        'artworks': [
          {'type': 15, 'image': 'https://img.test/backdrop-1406.jpg'},
        ],
        'characters': [
          {'personName': 'Denis Villeneuve', 'peopleType': 'Director'},
          {'personName': 'Timothée Chalamet', 'peopleType': 'Actor'},
          {'personName': 'Zendaya', 'peopleType': 'Actor'},
          {'personName': 'Rebecca Ferguson', 'peopleType': 'Actor'},
        ],
        'studios': [
          {'name': 'Legendary Pictures'},
        ],
      });
    }
    if (p.contains('/movies/') && p.contains('/translations/')) {
      return _ok({
        'overview':
            'Sur la planète Arrakis, seule source de l\'épice, les Atréides '
            'prennent la relève des Harkonnen. Paul, héritier du duc Leto, '
            'se découvre un destin qui le dépasse et devra choisir entre la '
            'vengeance de son père et le salut d\'un peuple entier, au '
            'risque de précipiter une guerre sainte à travers tout '
            'l\'univers connu.',
      });
    }
    if (p.contains('/series/') && p.endsWith('/extended')) {
      return _ok({
        'name': 'ワンピース',
        'image': 'https://img.test/poster-81797.jpg',
        'firstAired': '1999-10-20',
        'averageRuntime': 25,
        'status': {'name': 'Continuing'},
        'genres': [
          {'name': 'Animation'},
          {'name': 'Aventure'},
        ],
        'originalNetwork': {'name': 'Fuji TV'},
        'seasons': [
          {
            'number': 1,
            'type': {'type': 'official'},
          },
          {
            'number': 2,
            'type': {'type': 'official'},
          },
          {
            'number': 3,
            'type': {'type': 'official'},
          },
        ],
        'artworks': [
          {'type': 3, 'image': p.contains('/371980/') ? 'https://img.test/backdrop-371980.jpg' : 'https://img.test/backdrop-81797.jpg'},
        ],
      });
    }
    if (p.contains('/series/') && p.contains('/translations/')) {
      return _ok({
        'name': 'One Piece',
        'overview':
            'Gold Roger est le seigneur des pirates. À sa mort, une grande '
            'vague de piraterie s\'abat sur le monde. Monkey D. Luffy, un '
            'garçon qui rêve de devenir pirate, part à la recherche du One '
            'Piece, le fabuleux trésor amassé par Gold Roger durant toute '
            'sa vie.',
      });
    }
    if (p.contains('/episodes/')) {
      return _ok({
        'episodes': [
          for (var s = 1; s <= 3; s++)
            for (var e = 1; e <= 8; e++)
              {
                'seasonNumber': s,
                'number': e,
                'name': 'Épisode $e de la saison $s',
                'overview': 'Résumé.',
                'image': 'https://img.test/still-$s-$e.jpg',
                'aired': '2026-0$s-${e.toString().padLeft(2, '0')}',
              },
        ],
      });
    }
    return _ok(<String, Object?>{});
  }),
);

// ─────────────────────────────── Données ─────────────────────────────────

Future<AppDatabase> _seed() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  Future<void> show(
    int id,
    String name,
    int seasons,
    int perSeason,
    int watched, {
    String? status,
  }) async {
    await db.upsertShow(
      ShowsCompanion.insert(
        id: Value(id),
        name: name,
        poster: Value('https://img.test/poster-$id.jpg'),
        totalEpisodes: Value(seasons * perSeason),
        seasonCount: Value(seasons),
        runtime: const Value(45),
        status: Value(status ?? 'Continuing'),
        genres: const Value('Drame|Science-Fiction'),
        episodesSyncedAt: Value(DateTime.now()),
      ),
    );
    await db.upsertEpisodes([
      for (var s = 1; s <= seasons; s++)
        for (var e = 1; e <= perSeason; e++)
          EpisodesCompanion.insert(
            showId: id,
            season: s,
            episode: e,
            name: Value('Épisode $e'),
            still: Value('https://img.test/still-$id-$s-$e.jpg'),
            airDate: Value(
              DateTime(2026, 1, 1).add(Duration(days: (s - 1) * 30 + e)),
            ),
          ),
    ]);
    var n = 0;
    for (var s = 1; s <= seasons && n < watched; s++) {
      for (var e = 1; e <= perSeason && n < watched; e++) {
        await db.setEpisodeWatched(
          id,
          s,
          e,
          at: DateTime.now().subtract(Duration(days: watched - n)),
        );
        n++;
      }
    }
  }

  await show(371980, 'Severance', 2, 9, 11);
  await show(392256, 'The Last of Us', 2, 9, 3);
  // Une série avec un épisode à venir aujourd'hui et cette semaine.
  await db.upsertShow(
    ShowsCompanion.insert(
      id: const Value(81797),
      name: 'One Piece',
      poster: const Value('https://img.test/poster-81797.jpg'),
      totalEpisodes: const Value(1120),
      seasonCount: const Value(21),
      runtime: const Value(25),
      status: const Value('Continuing'),
      genres: const Value('Animation|Aventure'),
      episodesSyncedAt: Value(DateTime.now()),
    ),
  );
  final today = DateTime.now();
  await db.upsertEpisodes([
    for (var e = 1118; e <= 1123; e++)
      EpisodesCompanion.insert(
        showId: 81797,
        season: 21,
        episode: e,
        name: Value('Épisode $e'),
        still: Value('https://img.test/still-op-$e.jpg'),
        airDate: Value(today.add(Duration(days: (e - 1120) * 7))),
      ),
  ]);
  for (var e = 1118; e < 1120; e++) {
    await db.setEpisodeWatched(81797, 21, e);
  }

  final movies = [
    (1406, 'Dune', 155, null),
    (496243, 'Parasite', 132, DateTime(2026, 6, 2)),
    (27205, 'Inception', 148, null),
    (157336, 'Interstellar', 169, DateTime(2026, 5, 20)),
    (603, 'Oppenheimer', 180, null),
    (872585, 'Once Upon a Time in Hollywood', 161, null),
    (
      1,
      'The Assassination of Jesse James by the Coward Robert Ford',
      160,
      null,
    ),
  ];
  for (final (id, title, rt, seen) in movies) {
    await db.upsertMovie(
      MoviesCompanion.insert(
        id: Value(id),
        title: title,
        poster: Value('https://img.test/poster-$id.jpg'),
        runtime: Value(rt),
        watchedAt: Value(seen),
        genres: const Value('Drame'),
        releaseDate: Value(DateTime(2021, 9, 15)),
      ),
    );
  }
  return db;
}

// ─────────────────────────────── Capture ─────────────────────────────────

final _boundary = GlobalKey();
final _issues = <String>[];

Future<void> _settleReal(WidgetTester tester, [int ms = 350]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

// A TextStyle without a family uses the engine's test font, even after
// Roboto is loaded. Resolve only that default on render paragraphs; keep
// explicit icon fonts. Production uses the platform font automatically.
InlineSpan _readableSpan(InlineSpan span) {
  if (span is! TextSpan) return span;
  final style = span.style ?? const TextStyle();
  return TextSpan(
    text: span.text,
    style: style.fontFamily == null || style.fontFamily == 'Ahem'
        ? style.copyWith(fontFamily: 'Roboto')
        : style,
    children: span.children?.map(_readableSpan).toList(),
    recognizer: span.recognizer,
    semanticsLabel: span.semanticsLabel,
  );
}

void _readableFonts(RenderObject object) {
  if (object is RenderParagraph) object.text = _readableSpan(object.text);
  object.visitChildren(_readableFonts);
}

Future<void> _shot(WidgetTester tester, String name) async {
  // ignore: avoid_print
  print("[shot] $name");
  await _settleReal(tester);
  _readableFonts(_boundary.currentContext!.findRenderObject()!);
  await tester.pump();
  final e = tester.takeException();
  if (e != null) _issues.add('$name : $e');
  await tester.runAsync(() async {
    final ro =
        _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: 2);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$_out/$name.png').writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  testWidgets(
    'audit visuel',
    skip: Platform.environment['NITRATE_AUDIT'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      Directory(_out).createSync(recursive: true);
      debugNetworkImageHttpClientProvider = _Client.new;
      await tester.runAsync(_loadFonts);
      // Decode fixture art outside the fake-async zone before image requests.
      await tester.runAsync(() => _pngFor('audit'));
      await tester.runAsync(() async {
        for (final name in ['severance', 'severance-backdrop', 'one-piece', 'last-of-us']) {
          final file = File('test/fixtures/cinema/$name.jpg');
          if (file.existsSync()) _pngs[name] = await file.readAsBytes();
        }
      });
      debugPrint('Audit: fonts ready');
      SharedPreferences.setMockInitialValues({});

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);

      final db = await _seed();
      debugPrint('Audit: seed ready');
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tvdbClientProvider.overrideWithValue(_tvdb()),
          ],
          child: RepaintBoundary(key: _boundary, child: const NitrateApp()),
        ),
      );
      await _settleReal(tester, 600);

      final ctx = tester.element(find.byType(NitrateApp));
      final container = ProviderScope.containerOf(ctx);
      Future<void> tab(int i) async {
        container.read(homeTabProvider.notifier).select(i);
        await _settleReal(tester, 500);
      }

      // Keep the chosen reference's series featured with deterministic activity.
      await db.setEpisodeWatched(371980, 2, 2, at: DateTime.now().add(const Duration(seconds: 1)));
      await _settleReal(tester, 900);
      await _shot(tester, '01-series');
      if (Platform.environment['NITRATE_MOTION'] == '1') {
        Directory('$_out/motion').createSync(recursive: true);
        for (var frame = 0; frame < 90; frame++) {
          if (frame == 12) await tester.tap(find.text('Marquer vu'));
          if (frame == 48) await tester.tap(find.text('Voir l’épisode'));
          await tester.pump(const Duration(microseconds: 33333));
          _readableFonts(_boundary.currentContext!.findRenderObject()!);
          await tester.pump();
          await tester.runAsync(() async {
            final ro = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await ro.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            await File('$_out/motion/${frame.toString().padLeft(3, '0')}.png').writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (router.canPop()) router.pop();
        await _settleReal(tester);
      }
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
      await _shot(tester, '01b-series-programme');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
      await _settleReal(tester);

      // Onglet À venir.
      await tester.tap(find.text('À venir'));
      await _shot(tester, '02-series-a-venir');
      await tester.tap(find.text('À voir'));
      await _settleReal(tester);

      await tab(1);
      await _shot(tester, '03-films');
      await tab(2);
      await _shot(tester, '04-explorer');
      await tab(3);
      await _shot(tester, '05-profil');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
      await _shot(tester, '06-profil-bas');

      router.push('/movie/1406', extra: 'Dune');
      await _settleReal(tester, 900);
      await _shot(tester, '07-fiche-film');
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -420),
      );
      await _shot(tester, '08-fiche-film-scroll');
      router.pop();
      await _settleReal(tester, 500);

      router.push('/show/81797', extra: 'One Piece');
      await _settleReal(tester, 900);
      await _shot(tester, '09-fiche-serie');
      await tester.tap(find.text('Épisodes'));
      await _settleReal(tester, 600);
      await _shot(tester, '10-fiche-serie-episodes');
      await tester.tap(find.text('Saison 1'));
      await _settleReal(tester, 400);
      await _shot(tester, '11-fiche-serie-saison');
      router.pop();
      await _settleReal(tester, 500);

      // Fiche d'un titre très long, non suivi.
      router.push(
        '/movie/1',
        extra: 'The Assassination of Jesse James by the Coward Robert Ford',
      );
      await _settleReal(tester, 900);
      await _shot(tester, '12-fiche-film-titre-long');
      router.pop();
      await _settleReal(tester, 500);

      for (final (route, name) in [
        ('/settings', '13-reglages'),
        ('/import', '14-import'),
        ('/history', '15-historique-series'),
        ('/movie-history', '16-historique-films'),
        ('/series', '17-mes-series'),
      ]) {
        router.push(route);
        await _settleReal(tester, 600);
        await _shot(tester, name);
        router.pop();
        await _settleReal(tester, 400);
      }

      // Épisode : feuille modale.
      router.push(
        '/episode/371572/1/12',
        extra: {
          'name': 'Severance',
          'poster': 'https://img.test/poster-371572.jpg',
        },
      );
      await _settleReal(tester, 900);
      await _shot(tester, '18-episode');
      router.pop();
      await _settleReal(tester, 400);

      // Films : après un « vu ».
      await tab(1);
      await tester.tap(find.byIcon(Icons.check).first);
      await _shot(tester, '19-films-apres-vu');

      // Explorer : recherche.
      await tab(2);
      await tester.enterText(find.byType(TextField).first, 'one piece');
      await _settleReal(tester, 900);
      await _shot(tester, '20-explorer-recherche');

      File('$_out/issues.txt').writeAsStringSync(_issues.join('\n'));
      debugNetworkImageHttpClientProvider = null;
      // Démontage propre.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
