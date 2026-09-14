import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/widgets/collection_layout_transition.dart';

Widget host({
  bool reduced = false,
  CollectionMotion motion = CollectionMotion.cascade,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: CollectionLayoutTransition(
        motion: motion,
        builder: (context, compact) => Column(
          children: [
            const CollectionLayoutToggle(series: true),
            Expanded(
              child: Align(
                alignment: compact ? Alignment.bottomRight : Alignment.topLeft,
                child: SizedBox(
                  width: compact ? 100 : 250,
                  height: compact ? 150 : 300,
                  child: const CollectionTransitionPoster(
                    id: 'one',
                    sources: [],
                    seed: 'one',
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  test('the focus pulse returns to a sharp image at the exact final frame', () {
    expect(collectionFocusPulse(0), 0);
    expect(collectionFocusPulse(.43), 1);
    expect(collectionFocusPulse(1), 0);
  });
  for (final motion in CollectionMotion.values) {
    testWidgets(
      '$motion keeps the poster visible in flight and restores its hit target',
      (t) async {
        await t.pumpWidget(host(motion: motion));
        final from = t.getRect(find.byType(CollectionTransitionPoster));
        await t.tap(find.byTooltip('Vue d’ensemble'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 350));
        // The destination exists, but its artwork is replaced by the moving layer.
        final opacity = find.descendant(
          of: find.byType(CollectionTransitionPoster),
          matching: find.byType(Opacity),
        );
        expect(t.widget<Opacity>(opacity).opacity, 0);
        expect(find.byType(Positioned), findsWidgets);
        await t.pumpAndSettle();
        final to = t.getRect(find.byType(CollectionTransitionPoster));
        expect(to.width, 100);
        expect(to.top, greaterThan(from.top));
        expect(t.widget<Opacity>(opacity).opacity, 1);
        await t.tap(find.byTooltip('Grande carte'));
        await t.pumpAndSettle();
        expect(t.getRect(find.byType(CollectionTransitionPoster)), from);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('the latest request during a transition wins', (t) async {
    await t.pumpWidget(host());
    await t.tap(find.byTooltip('Vue d’ensemble'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byTooltip('Grande carte'));
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(CollectionTransitionPoster)).width, 250);
    expect(t.takeException(), isNull);
  });
  testWidgets('reduced motion applies the layout without a flight', (t) async {
    await t.pumpWidget(host(reduced: true));
    await t.tap(find.byTooltip('Vue d’ensemble'));
    await t.pump();
    expect(t.getSize(find.byType(CollectionTransitionPoster)).width, 100);
    final opacity = find.descendant(
      of: find.byType(CollectionTransitionPoster),
      matching: find.byType(Opacity),
    );
    expect(t.widget<Opacity>(opacity).opacity, 1);
    expect(find.byType(ImageFiltered), findsNothing);
  });
  testWidgets('leaving the page during a flight disposes safely', (t) async {
    await t.pumpWidget(host());
    await t.tap(find.byTooltip('Vue d’ensemble'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
