import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/motion.dart';
import 'package:tracktime/movies/widgets/movie_poster_card.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/theme.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
  theme: buildTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: child!,
  ),
  home: home,
);

Movie _movie(int id, String title) =>
    Movie(id: id, title: title, runtime: 110, addedAt: DateTime(2026, 1, 1));

void main() {
  group('conventions', () {
    test('les durées restent courtes et ordonnées', () {
      expect(Motion.fast < Motion.normal, isTrue);
      expect(Motion.normal < Motion.slow, isTrue);
      expect(Motion.slow.inMilliseconds, lessThanOrEqualTo(350));
    });

    test('l\'échelonnement s\'arrête après quelques éléments', () {
      expect(Motion.staggerAt(0), Duration.zero);
      expect(Motion.staggerAt(1), Motion.stagger);
      // Au-delà, les cartes apparaissent directement : pas de cascade.
      expect(Motion.staggerAt(Motion.staggerMax), Duration.zero);
      expect(Motion.staggerAt(50), Duration.zero);
      final total = Motion.stagger * (Motion.staggerMax - 1);
      expect(total.inMilliseconds, lessThanOrEqualTo(220));
    });

    test('le tag d\'affiche ne dépend que du type et de l\'identifiant', () {
      expect(MediaPosterHero.tagFor(id: 81797, isSeries: true), 'series-81797');
      expect(MediaPosterHero.tagFor(id: 1406, isSeries: false), 'movie-1406');
      // Une série et un film de même identifiant restent distincts.
      expect(
        MediaPosterHero.tagFor(id: 7, isSeries: true),
        isNot(MediaPosterHero.tagFor(id: 7, isSeries: false)),
      );
    });
  });

  group('réduire les animations', () {
    testWidgets('une durée est ramenée à zéro', (tester) async {
      late Duration normal;
      late Duration reduced;

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (c) {
              normal = motionOf(c, Motion.normal);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (c) {
              reduced = motionOf(c, Motion.normal);
              return const SizedBox();
            },
          ),
          reduceMotion: true,
        ),
      );

      expect(normal, Motion.normal);
      expect(reduced, Duration.zero);
    });

    testWidgets('l\'entrée décorative disparaît, le contenu reste', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const EntranceFade(child: Text('Contenu')), reduceMotion: true),
      );
      await tester.pump();

      // Aucun mouvement : ni fondu, ni déplacement, mais le texte est là.
      expect(find.text('Contenu'), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('sans réduction, l\'entrée s\'anime puis se stabilise', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const EntranceFade(child: Text('Contenu'))));
      await tester.pump();
      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

      await tester.pump(Motion.normal);
      expect(find.text('Contenu'), findsOneWidget);
    });

    testWidgets('un démontage pendant l\'entrée ne laisse rien derrière', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const EntranceFade(
            delay: Duration(milliseconds: 200),
            child: Text('Contenu'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));

      // Démontage avant la fin du délai : le minuteur doit être annulé.
      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    });
  });

  group('liaison affiche → fiche', () {
    testWidgets('une affiche porte un Hero, unique sur l\'écran', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: _app(
            Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 120,
                    child: MoviePosterCard(
                      movie: _movie(1406, 'Dune'),
                      onAction: (_) {},
                      onTap: () {},
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: MoviePosterCard(
                      movie: _movie(27205, 'Inception'),
                      onAction: (_) {},
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final tags = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((h) => h.tag)
          .toList();
      expect(tags, containsAll(['movie-1406', 'movie-27205']));
      // Aucun doublon : deux Hero de même tag lèveraient à la navigation.
      expect(tags.toSet().length, tags.length);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('naviguer depuis l\'affiche ne provoque aucun conflit', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: SizedBox(
                width: 120,
                child: MoviePosterCard(
                  movie: _movie(1406, 'Dune'),
                  onAction: (_) {},
                  onTap: () => context.push('/cible'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/cible',
            builder: (_, _) => Scaffold(
              body: Hero(
                tag: MediaPosterHero.tagFor(id: 1406, isSeries: false),
                child: const SizedBox(width: 96, height: 144),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(MoviePosterCard));

      // Le vol se déroule : c'est là qu'un tag dupliqué exploserait.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
