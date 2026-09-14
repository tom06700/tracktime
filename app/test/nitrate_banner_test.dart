import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/widgets/nitrate_banner.dart';

Future<NitrateMessenger> _mount(
  WidgetTester t, {
  double scale = 1,
  bool reduced = false,
  VoidCallback? onBackground,
}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  late NitrateMessenger messenger;
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 59, bottom: 34),
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            messenger = NitrateMessenger.of(context);
            return Center(
              child: TextButton(
                onPressed: onBackground,
                child: const Text('Page'),
              ),
            );
          },
        ),
      ),
    ),
  );
  return messenger;
}

void main() {
  for (final message in [
    'Film retiré',
    'Young Sherlock retirée de Mes séries',
  ]) {
    testWidgets('texte, coche et fermeture alignés : $message', (t) async {
      final messenger = await _mount(t);
      messenger.showBanner(
        NitrateBanner(kind: NitrateBannerKind.success, content: Text(message)),
      );
      await t.pumpAndSettle();
      final textCenter = t.getCenter(find.text(message)).dy;
      expect(
        t.getCenter(find.byIcon(Icons.check_rounded)).dy,
        closeTo(textCenter, 0.5),
      );
      expect(
        t.getCenter(find.byIcon(Icons.close_rounded)).dy,
        closeTo(textCenter, 0.5),
      );
    });
  }

  testWidgets('action temporaire, zone sûre et page encore tactile', (t) async {
    var background = 0, actions = 0;
    final messenger = await _mount(t, onBackground: () => background++);
    messenger.showBanner(
      NitrateBanner(
        content: const Text('Young Sherlock ajoutée à Mes séries'),
        kind: NitrateBannerKind.success,
        action: NitrateBannerAction(
          label: 'Voir la série',
          onPressed: () => actions++,
        ),
      ),
    );
    await t.pumpAndSettle();
    final rect = t.getRect(find.byType(NitrateBanner));
    expect(rect.top, greaterThanOrEqualTo(59));
    expect(rect.left, 16);
    expect(rect.right, 374);
    await t.tap(find.text('Page'));
    expect(background, 1);
    await t.pump(const Duration(seconds: 7));
    await t.pumpAndSettle();
    expect(find.byType(NitrateBanner), findsNothing);
    expect(actions, 0);
  });

  testWidgets('remplacement sans file et action exécutée une seule fois', (
    t,
  ) async {
    final messenger = await _mount(t);
    messenger.showBanner(const NitrateBanner(content: Text('Premier')));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 3));
    var actions = 0;
    messenger.showBanner(
      NitrateBanner(
        content: const Text('Deuxième'),
        action: NitrateBannerAction(
          label: 'Annuler',
          onPressed: () => actions++,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Premier'), findsNothing);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Deuxième'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(actions, 1);
    expect(find.byType(NitrateBanner), findsNothing);
  });

  testWidgets('fermeture manuelle, balayage et réduction du mouvement', (
    t,
  ) async {
    final messenger = await _mount(t, reduced: true);
    messenger.showBanner(const NitrateBanner(content: Text('Message')));
    await t.pump();
    await t.tap(find.byTooltip('Fermer le message'));
    await t.pump();
    expect(find.byType(NitrateBanner), findsNothing);
    messenger.showBanner(const NitrateBanner(content: Text('Message suivant')));
    await t.pump();
    await t.drag(find.byType(NitrateBanner), const Offset(0, -90));
    await t.pumpAndSettle();
    expect(find.byType(NitrateBanner), findsNothing);
  });

  testWidgets('petit écran, texte doublé, message long et action', (t) async {
    final messenger = await _mount(t, scale: 2);
    t.view.physicalSize = const Size(320, 640);
    messenger.showBanner(
      NitrateBanner(
        title: 'Ajouté à Mes séries',
        content: const Text(
          'Une très longue série avec un titre complet sur plusieurs lignes',
        ),
        action: NitrateBannerAction(label: 'Voir la série', onPressed: () {}),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final rect = t.getRect(find.byType(NitrateBanner));
    expect(rect.bottom, lessThan(600));
    expect(t.getRect(find.text('Voir la série')).right, lessThan(304));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 10));
    expect(t.takeException(), isNull);
    // A captured messenger is harmless after its navigator has disappeared.
    messenger.showBanner(const NitrateBanner(content: Text('Tardif')));
  });
}
