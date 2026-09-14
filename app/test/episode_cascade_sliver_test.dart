import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/series/widgets/episode_cascade_sliver.dart';

void main() {
  Widget fixture({
    int season = 1,
    bool reduced = false,
    int count = 1000,
    String status = 'À découvrir',
    double preceding = 0,
    List<int>? ids,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Material(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: preceding)),
            EpisodeCascadeSliver(
              key: ValueKey(season),
              itemCount: ids?.length ?? count,
              itemIds: ids,
              removedItemBuilder: (context, id, motion) =>
                  SizedBox(height: 64, child: Text('Retiré $id')),
              itemBuilder: (context, index, motion) => SizedBox(
                key: ValueKey('row-${ids?[index] ?? index}'),
                height: 64,
                child: Column(
                  children: [
                    motion.title(Text('Épisode ${ids?[index] ?? index}')),
                    motion.status(Text(status)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester, int row) {
    final element = tester.element(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.key == ValueKey('row-$row'),
      ),
    );
    double? value;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget case final FadeTransition fade) {
        value = fade.opacity.value;
        return false;
      }
      return true;
    });
    return value!;
  }

  testWidgets(
    'loading and clearing a thousand episodes keeps animation work bounded',
    (tester) async {
      await tester.pumpWidget(fixture(ids: []));
      await tester.pumpWidget(fixture(ids: List.generate(1000, (i) => i)));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, lessThan(10));
      expect(find.text('Épisode 999'), findsNothing);
      await tester.pumpAndSettle();
      await tester.pumpWidget(fixture(ids: []));
      expect(tester.binding.transientCallbackCount, lessThan(10));
      await tester.pumpAndSettle();
      expect(find.textContaining('Retiré'), findsNothing);
    },
  );

  testWidgets(
    'a removed episode confirms then collapses without jumping the next row',
    (tester) async {
      await tester.pumpWidget(fixture(ids: [0, 1, 2]));
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.text('Épisode 2')).dy;
      await tester.pumpWidget(fixture(ids: [0, 2]));
      expect(find.text('Retiré 1'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(find.text('Épisode 2')).dy, closeTo(before, .1));
      await tester.pump(const Duration(milliseconds: 180));
      final middle = tester.getTopLeft(find.text('Épisode 2')).dy;
      expect(middle, lessThan(before));
      expect(middle, greaterThan(before - 64));
      await tester.pumpAndSettle();
      expect(find.text('Retiré 1'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Épisode 2')).dy,
        closeTo(before - 64, .1),
      );
    },
  );

  testWidgets(
    'rapid removal, insertion and reduced motion settle to the latest IDs',
    (tester) async {
      await tester.pumpWidget(fixture(ids: [0, 1, 2, 3]));
      await tester.pumpAndSettle();
      await tester.pumpWidget(fixture(ids: [0, 3]));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(fixture(ids: [0, 1, 3]));
      await tester.pumpAndSettle();
      expect(find.text('Épisode 1'), findsOneWidget);
      expect(find.text('Épisode 2'), findsNothing);
      expect(find.textContaining('Retiré'), findsNothing);
      await tester.pumpWidget(fixture(ids: [3], reduced: true));
      await tester.pump();
      expect(find.text('Épisode 0'), findsNothing);
      expect(find.textContaining('Retiré'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visible cascade completes in 800 ms without rebuilding the list each frame',
    (tester) async {
      await tester.pumpWidget(fixture());
      await tester.pump();
      expect(opacity(tester, 0), 0);
      await tester.pump(const Duration(milliseconds: 140));
      expect(opacity(tester, 0), greaterThan(opacity(tester, 2)));
      expect(opacity(tester, 5), 0);
      expect(opacity(tester, 6), opacity(tester, 5));
      await tester.pump(const Duration(milliseconds: 660));
      expect(opacity(tester, 5), 1);
      expect(find.text('Épisode 999'), findsNothing);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('watch-state updates and scrolling do not restart the entrance', (
    tester,
  ) async {
    await tester.pumpWidget(fixture());
    await tester.pumpAndSettle();
    await tester.pumpWidget(fixture(status: 'Vu'));
    expect(opacity(tester, 0), 1);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2200));
    await tester.pumpAndSettle();
    expect(opacity(tester, 0), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('changing season starts a new entrance', (tester) async {
    await tester.pumpWidget(fixture());
    await tester.pumpAndSettle();
    await tester.pumpWidget(fixture(season: 2));
    expect(opacity(tester, 0), 0);
    await tester.pumpAndSettle();
    expect(opacity(tester, 5), 1);
  });

  testWidgets(
    'reduced motion shows all rows immediately and cancels an active entrance',
    (tester) async {
      await tester.pumpWidget(fixture(reduced: true));
      expect(opacity(tester, 0), 1);
      await tester.pumpWidget(fixture(season: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(tester, 5), 0);
      await tester.pumpWidget(fixture(season: 2, reduced: true));
      expect(opacity(tester, 5), 1);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'waits for data and does not consume the entrance below the viewport',
    (tester) async {
      await tester.pumpWidget(fixture(count: 0, preceding: 1600));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(fixture(preceding: 1600));
      await tester.pump(const Duration(seconds: 2));
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      scroll.position.jumpTo(1600);
      await tester.pump();
      expect(opacity(tester, 0), 0);
      await tester.pumpAndSettle();
      expect(opacity(tester, 5), 1);
      expect(tester.takeException(), isNull);
    },
  );
}
