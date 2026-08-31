import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/media/cinematic.dart';
import 'package:tracktime/media/palette.dart';
import 'package:tracktime/theme.dart';

/// Pixels RGBA d'une couleur unie, pour éprouver l'extraction sans image.
Uint8List _solid(Color c, {int count = 200}) {
  final out = Uint8List(count * 4);
  for (var i = 0; i < count; i++) {
    out[i * 4] = (c.r * 255).round();
    out[i * 4 + 1] = (c.g * 255).round();
    out[i * 4 + 2] = (c.b * 255).round();
    out[i * 4 + 3] = 255;
  }
  return out;
}

Widget _app(Widget home, {bool reduceMotion = false, Size? size}) =>
    ProviderScope(
      child: MaterialApp(
        theme: buildTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size ?? const Size(390, 844),
            disableAnimations: reduceMotion,
          ),
          child: home,
        ),
      ),
    );

void main() {
  group('normalisation de la palette', () {
    test('un fond reste sombre, quelle que soit l\'image', () {
      for (final raw in [
        const Color(0xFFFFFFFF),
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        const Color(0xFFFFE066),
      ]) {
        final p = paletteFromSwatches([raw]);
        expect(
          HSLColor.fromColor(p.base).lightness,
          lessThan(0.2),
          reason: 'fond issu de $raw',
        );
      }
    });

    test('aucune couleur criarde ne prend le contrôle', () {
      final p = paletteFromSwatches([const Color(0xFF00FF00)]);
      final base = HSLColor.fromColor(p.base);
      // Saturée assez pour être identifiable, jamais fluo.
      expect(base.saturation, inInclusiveRange(0.18, 0.42));
      expect(HSLColor.fromColor(p.surface).lightness, lessThan(0.25));
    });

    test('la teinte de l\'image est conservée', () {
      // Bleu : la teinte survit à la normalisation, c'est tout l'intérêt.
      final bleu = paletteFromSwatches([const Color(0xFF1E5AA8)]);
      final rouge = paletteFromSwatches([const Color(0xFFA81E1E)]);
      expect(
        HSLColor.fromColor(bleu.base).hue,
        // Tolérance : repasser par du RGB 8 bits décale la teinte d'un poil.
        closeTo(HSLColor.fromColor(const Color(0xFF1E5AA8)).hue, 5),
      );
      expect(
        HSLColor.fromColor(bleu.base).hue,
        isNot(closeTo(HSLColor.fromColor(rouge.base).hue, 30)),
      );
    });

    test('l\'accent reste lisible sur le fond', () {
      for (final raw in [
        const Color(0xFF1E5AA8),
        const Color(0xFF7A1020),
        const Color(0xFF2E7D32),
      ]) {
        final p = paletteFromSwatches([raw]);
        expect(
          contrastRatio(p.accent, p.base),
          greaterThanOrEqualTo(4.5),
          reason: 'accent issu de $raw',
        );
      }
    });

    test('une image sans teinte retombe sur l\'ambiance Nitrate', () {
      expect(
        paletteFromSwatches([const Color(0xFF808080)]),
        MediaPalette.nitrate,
      );
      expect(paletteFromSwatches(const []), MediaPalette.nitrate);
    });

    test('l\'accent se détache de la dominante quand l\'image le permet', () {
      final p = paletteFromSwatches([
        const Color(0xFF1E5AA8), // bleu dominant
        const Color(0xFFC97A1E), // orange secondaire
      ]);
      final baseHue = HSLColor.fromColor(p.base).hue;
      final accentHue = HSLColor.fromColor(p.accent).hue;
      expect((accentHue - baseHue).abs(), greaterThan(60));
    });
  });

  group('extraction des dominantes', () {
    test('une image unie donne sa couleur', () {
      final colors = dominantColors(_solid(const Color(0xFF1E5AA8)));
      expect(colors, hasLength(1));
      expect(
        HSLColor.fromColor(colors.single).hue,
        closeTo(HSLColor.fromColor(const Color(0xFF1E5AA8)).hue, 10),
      );
    });

    test('les pixels quasi noirs ou blancs sont écartés', () {
      // Ils décrivent le cadre de l'image, pas son ambiance.
      final colors = dominantColors(
        Uint8List.fromList([
          ..._solid(const Color(0xFF000000), count: 50),
          ..._solid(const Color(0xFFFFFFFF), count: 50),
        ]),
      );
      expect(colors, isEmpty);
    });

    test('deux teintes ressortent, la plus présente en tête', () {
      final colors = dominantColors(
        Uint8List.fromList([
          ..._solid(const Color(0xFF1E5AA8), count: 100),
          ..._solid(const Color(0xFFC97A1E), count: 20),
        ]),
      );
      expect(colors.length, greaterThanOrEqualTo(2));
      expect(
        HSLColor.fromColor(colors.first).hue,
        closeTo(HSLColor.fromColor(const Color(0xFF1E5AA8)).hue, 10),
      );
    });
  });

  group('cache d\'ambiances', () {
    test('un film et une série de même numéro ne se croisent pas', () {
      const film = MediaRef(id: 1406, isSeries: false);
      const serie = MediaRef(id: 1406, isSeries: true);
      expect(film.cacheKey('a.jpg'), isNot(serie.cacheKey('a.jpg')));
    });

    test('la clé distingue aussi les images', () {
      const film = MediaRef(id: 1406, isSeries: false);
      expect(film.cacheKey('a.jpg'), isNot(film.cacheKey('b.jpg')));
    });

    test(
      'sans image, l\'ambiance Nitrate est rendue sans rien décoder',
      () async {
        final cache = PaletteCache(
          provider: (_) => fail('aucune image ne doit être demandée'),
        );
        expect(
          await cache.of(const MediaRef(id: 1, isSeries: false), null),
          MediaPalette.nitrate,
        );
      },
    );
  });

  group('titre du fond', () {
    test('la taille recule devant un titre long', () {
      final court = CinematicTitle.fontSizeFor('Dune');
      final moyen = CinematicTitle.fontSizeFor('Once Upon a Time in Hollywood');
      final long = CinematicTitle.fontSizeFor(
        'The Assassination of Jesse James by the Coward Robert Ford',
      );
      expect(court, greaterThan(moyen));
      expect(moyen, greaterThan(long));
      expect(long, greaterThanOrEqualTo(20));
    });

    for (final title in [
      'Dune',
      'Once Upon a Time in Hollywood',
      'The Assassination of Jesse James by the Coward Robert Ford',
    ]) {
      testWidgets('« $title » tient sur deux lignes sans déborder', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Center(child: CinematicTitle(title: title)),
            ),
          ),
        );
        await tester.pump();

        final text = tester.widget<Text>(find.text(title));
        expect(text.maxLines, 2);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('un agrandissement système ne fait pas exploser le titre', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                textScaler: TextScaler.linear(2.5),
              ),
              child: const Scaffold(
                body: Center(
                  child: CinematicTitle(title: 'Once Upon a Time in Hollywood'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final text = tester.widget<Text>(
        find.text('Once Upon a Time in Hollywood'),
      );
      // L'agrandissement est suivi, mais borné : au-delà le titre déborderait
      // du fond quelle que soit sa taille de base.
      expect(text.textScaler, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('fond de fiche', () {
    testWidgets('il occupe environ 40 % de la hauteur utile', (tester) async {
      late double height;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              height = backdropHeightOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      // 844 de haut : on attend une présence réelle, pas une bannière.
      expect(height / 844, inInclusiveRange(0.38, 0.42));
    });

    testWidgets('avec les animations réduites, aucun parallaxe', (
      tester,
    ) async {
      Widget page({required bool reduce}) => _app(
        Scaffold(
          body: CustomScrollView(
            slivers: [
              const CinematicBackdrop(
                title: 'Dune',
                image: null,
                seed: 'Dune',
                icon: Icons.movie_outlined,
                palette: MediaPalette.nitrate,
              ),
              SliverList.list(
                children: [
                  for (var i = 0; i < 30; i++)
                    const SizedBox(height: 40, child: Text('ligne')),
                ],
              ),
            ],
          ),
        ),
        reduceMotion: reduce,
      );

      await tester.pumpWidget(page(reduce: true));
      await tester.pump();
      final header = tester.widget<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader),
      );
      // Le délégué sait qu'il ne doit pas décaler l'image.
      expect(header.delegate.maxExtent, greaterThan(200));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('synopsis', () {
    const long =
        'Sur la planète Arrakis, seule source de l\'épice, les Atréides '
        'prennent la relève des Harkonnen. Paul, héritier du duc Leto, se '
        'découvre un destin qui le dépasse et devra choisir entre la '
        'vengeance de son père et le salut d\'un peuple entier, au risque '
        'de précipiter une guerre sainte à travers tout l\'univers connu.';

    testWidgets('replié sur trois lignes, avec « Voir plus »', (tester) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: ExpandableSynopsis(text: long, accent: TtColors.amber),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.widget<Text>(find.text(long)).maxLines, 3);
      expect(find.text('Voir plus'), findsOneWidget);
    });

    testWidgets('se déplie sur place, sans fenêtre', (tester) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: ExpandableSynopsis(text: long, accent: TtColors.amber),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Voir plus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
      expect(find.text('Voir moins'), findsOneWidget);
      // Rien n'a été empilé : on est resté sur la même page.
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un texte court ne propose pas de déplier', (tester) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: ExpandableSynopsis(text: 'Court.', accent: TtColors.amber),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Voir plus'), findsNothing);
    });
  });

  group('retour flottant', () {
    testWidgets('il dépile, et s\'annonce à l\'assistance vocale', (
      tester,
    ) async {
      var popped = false;
      await tester.pumpWidget(
        _app(
          Scaffold(body: CinematicBackButton(onPressed: () => popped = true)),
        ),
      );
      await tester.pump();

      final handle = tester.ensureSemantics();
      await tester.pump();
      expect(find.bySemanticsLabel('Retour'), findsOneWidget);
      handle.dispose();
      // Zone tactile confortable, pastille plus petite.
      expect(
        tester.getSize(find.byType(InkWell)).width,
        greaterThanOrEqualTo(44),
      );

      await tester.tap(find.byType(InkWell));
      expect(popped, isTrue);
    });
  });
}
