import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/motion.dart';
import 'package:tracktime/theme.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
  // L'entrée de fiche est calée sur le glissement latéral d'iOS.
  theme: buildTheme().copyWith(platform: TargetPlatform.iOS),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: child!,
  ),
  home: home,
);

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

  group('entrée d\'une fiche', () {
    Widget opener() => Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: MediaEntrance(child: Text('Fiche'))),
          ),
        ),
        child: const Text('ouvrir'),
      ),
    );

    double? entranceScale(WidgetTester tester) {
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byKey(MediaEntrance.key_),
          matching: find.byType(Transform),
        ),
      );
      return transforms.isEmpty
          ? null
          : transforms.first.transform.getMaxScaleOnAxis();
    }

    testWidgets('avec les animations réduites, rien n\'enveloppe le contenu', (
      tester,
    ) async {
      await tester.pumpWidget(_app(opener(), reduceMotion: true));
      await tester.tap(find.text('ouvrir'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(find.text('Fiche'), findsOneWidget);
      expect(find.byKey(MediaEntrance.key_), findsNothing);
    });

    testWidgets('la fiche arrive d\'un très léger zoom, puis se pose', (
      tester,
    ) async {
      await tester.pumpWidget(_app(opener()));
      await tester.tap(find.text('ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final midFlight = entranceScale(tester);
      expect(midFlight, isNotNull);
      expect(midFlight, greaterThan(1.0));
      // Discret : le zoom reste sous les 5 %, sinon il se remarquerait.
      expect(midFlight, lessThan(1.05));

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(entranceScale(tester), closeTo(1.0, 0.001));
      expect(find.text('Fiche'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quitter la fiche en cours d\'entrée ne lève rien', (
      tester,
    ) async {
      await tester.pumpWidget(_app(opener()));
      await tester.tap(find.text('ouvrir'));
      await tester.pump(const Duration(milliseconds: 60));

      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    });
  });
}
