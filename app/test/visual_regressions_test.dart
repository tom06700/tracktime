import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/screens/movies_screen.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/tmdb/tvdb.dart';
import 'package:tracktime/widgets/media_image.dart';

/// Requête qui ne répond jamais : l'image reste « en attente du premier
/// octet », l'état exact où la case restait vide.
class _Silent implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Completer<HttpClientRequest>().future;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

TvdbClient _silentTvdb() => TvdbClient(
  'test',
  client: MockClient(
    (_) async =>
        http.Response('{"data":{"token":"t"},"status":"success"}', 200),
  ),
);

void main() {
  group('MediaImage', () {
    testWidgets('le dégradé de repli est visible avant le premier octet', (
      tester,
    ) async {
      // Remis à zéro en fin de test, avant la vérification du framework qui
      // refuse qu'une variable de débogage de peinture reste modifiée.
      debugNetworkImageHttpClientProvider = _Silent.new;

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 200,
            height: 120,
            child: MediaImage(
              sources: ['https://img.test/jamais.jpg'],
              seed: 'Dune',
              icon: Icons.movie_outlined,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Le dégradé dérivé du titre est bien là…
      final gradientBoxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((d) => (d.decoration as BoxDecoration?)?.gradient != null)
          .toList();
      expect(gradientBoxes, isNotEmpty);

      // …et aucune opacité nulle ne le cache : la case n'est jamais vide.
      final hidden = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .where((o) => o.opacity == 0)
          .toList();
      for (final o in hidden) {
        final hidesGradient = find.descendant(
          of: find.byWidget(o),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                (w.decoration as BoxDecoration?)?.gradient != null,
          ),
        );
        expect(hidesGradient, findsNothing, reason: 'repli masqué');
      }

      debugNetworkImageHttpClientProvider = null;
    });
  });

  group('MediaImage — chemins TheTVDB', () {
    testWidgets(
      'un still relatif enregistré en base devient une URL chargeable',
      (tester) async {
        debugNetworkImageHttpClientProvider = _Silent.new;

        await tester.pumpWidget(
          const MaterialApp(
            home: SizedBox(
              width: 200,
              height: 120,
              child: MediaImage(
                sources: ['/banners/v4/episode/1/screencap/a.jpg'],
                seed: 'One Piece',
                icon: Icons.tv,
              ),
            ),
          ),
        );
        await tester.pump();

        final image = tester.widget<Image>(find.byType(Image));
        expect(
          (image.image as NetworkImage).url,
          'https://artworks.thetvdb.com/banners/v4/episode/1/screencap/a.jpg',
        );

        debugNetworkImageHttpClientProvider = null;
      },
    );
  });

  group('MediaScrim', () {
    /// Opacité du voile à une hauteur donnée, 0 en bas, 1 en haut, par
    /// interpolation linéaire entre les paliers du dégradé.
    double alphaAt(MediaScrim scrim, double y) {
      final g = (scrim.build(_NoContext()) as DecoratedBox).decoration;
      final grad = (g as BoxDecoration).gradient as LinearGradient;
      final stops = grad.stops!;
      final colors = grad.colors;
      if (y >= stops.last) return colors.last.a;
      for (var i = 1; i < stops.length; i++) {
        if (y <= stops[i]) {
          final t = (y - stops[i - 1]) / (stops[i] - stops[i - 1]);
          return colors[i - 1].a + (colors[i].a - colors[i - 1].a) * t;
        }
      }
      return colors.first.a;
    }

    test('sur toute la hauteur, un titre à mi-carte reste lisible', () {
      // La carte « À voir » écrit trois lignes et un bouton dans sa moitié
      // basse : sur un still clair, l'ancien profil ne posait qu'un tiers
      // d'opacité sous le titre.
      const scrim = MediaScrim(height: 1);
      expect(alphaAt(scrim, 0.57), greaterThanOrEqualTo(0.6));
      expect(alphaAt(scrim, 0.1), greaterThanOrEqualTo(0.9));
      // …et l'image reste nue en haut.
      expect(alphaAt(scrim, 0.95), lessThan(0.15));
    });
  });

  group('grille Films', () {
    testWidgets('marquer un film vu ne colore pas le bouton du suivant', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.upsertMovie(
        MoviesCompanion.insert(id: const Value(1406), title: 'Dune'),
      );
      await db.upsertMovie(
        MoviesCompanion.insert(id: const Value(27205), title: 'Inception'),
      );

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tvdbClientProvider.overrideWithValue(_silentTvdb()),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            home: const Scaffold(body: MoviesScreen()),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      int confirmedButtons() => tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .where(
            (c) => (c.decoration as BoxDecoration?)?.color == TtColors.amber,
          )
          .length;

      expect(confirmedButtons(), 0);

      // Dune est marqué vu : il quitte la grille, Inception prend sa place.
      await tester.tap(find.byIcon(Icons.check).first);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(find.text('Dune'), findsNothing);
      expect(find.text('Inception'), findsOneWidget);
      // Le bouton d'Inception n'a pas hérité de l'état confirmé de Dune.
      expect(confirmedButtons(), 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

/// Contexte factice : MediaScrim ne lit rien dedans.
class _NoContext extends Fake implements BuildContext {}
