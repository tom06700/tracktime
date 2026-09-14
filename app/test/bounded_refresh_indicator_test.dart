import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/widgets/bounded_refresh_indicator.dart';
import 'package:tracktime/widgets/nitrate_banner.dart';

Widget host(
  Future<void> Function() refresh, {
  ScrollPhysics physics = const AlwaysScrollableScrollPhysics(),
}) => MaterialApp(
  home: Scaffold(
    body: BoundedRefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: physics,
        children: const [SizedBox(height: 1000, child: Text('Collection'))],
      ),
    ),
  ),
);

Future<void> pull(WidgetTester t) async {
  unawaited(
    t.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final physics in [
    const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
  ]) {
    testWidgets('a deliberate pull still refreshes once with $physics', (
      t,
    ) async {
      var calls = 0;
      final work = Completer<void>();
      await t.pumpWidget(
        host(() {
          calls++;
          return work.future;
        }, physics: physics),
      );
      final gesture = await t.startGesture(const Offset(200, 100));
      await t.pump();
      expect(find.byKey(const ValueKey('nitrate-refresh-mark')), findsNothing);
      await gesture.moveBy(const Offset(0, 20));
      await t.pump();
      expect(find.byKey(const ValueKey('nitrate-refresh-mark')), findsNothing);
      await gesture.moveBy(const Offset(0, 350));
      await t.pump();
      expect(
        find.byKey(const ValueKey('nitrate-refresh-mark')),
        findsOneWidget,
      );
      await gesture.up();
      for (var i = 0; i < 20 && calls == 0; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(calls, 1);
      await t.pump(const Duration(seconds: 1));
      expect(t.getTopLeft(find.text('Collection')).dy, closeTo(72, 1));
      work.complete();
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('nitrate-refresh-mark')), findsNothing);
      expect(t.getTopLeft(find.text('Collection')).dy, closeTo(0, 1));
    });
  }
  testWidgets('touching or scrolling into the list does not flash the loader', (
    t,
  ) async {
    var calls = 0;
    await t.pumpWidget(
      host(() async {
        calls++;
      }),
    );
    final gesture = await t.startGesture(const Offset(200, 300));
    await t.pump();
    expect(find.byKey(const ValueKey('nitrate-refresh-mark')), findsNothing);
    await gesture.moveBy(const Offset(0, -40));
    await t.pump();
    expect(find.byKey(const ValueKey('nitrate-refresh-mark')), findsNothing);
    await gesture.up();
    await t.pumpAndSettle();
    expect(calls, 0);
  });
  testWidgets(
    'refresh shows the Nitrate mark instead of the circular spinner',
    (t) async {
      final work = Completer<void>();
      await t.pumpWidget(host(() => work.future));
      await pull(t);
      expect(
        find.byKey(const ValueKey('nitrate-refresh-mark')),
        findsOneWidget,
      );
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(t.getTopLeft(find.text('Collection')).dy, closeTo(72, 1));
      work.complete();
      await t.pump();
      await t.pump(const Duration(milliseconds: 110));
      expect(
        t.getTopLeft(find.text('Collection')).dy,
        allOf(greaterThan(0), lessThan(72)),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('nitrate-refresh-mark')), findsNothing);
      expect(t.getTopLeft(find.text('Collection')).dy, closeTo(0, 1));
    },
  );
  testWidgets(
    'a slow refresh releases the spinner and repeated pulls share the request',
    (t) async {
      final work = Completer<void>();
      var calls = 0;
      await t.pumpWidget(
        host(() {
          calls++;
          return work.future;
        }),
      );
      try {
        await pull(t);
        expect(t.getTopLeft(find.text('Collection')).dy, closeTo(72, 1));
        await t.pump(const Duration(seconds: 9));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.getTopLeft(find.text('Collection')).dy, closeTo(0, 1));
        expect(find.byType(RefreshProgressIndicator), findsNothing);
        expect(
          find.byKey(const ValueKey('nitrate-refresh-mark')),
          findsNothing,
        );
        expect(
          find.text('La mise à jour continue en arrière-plan.'),
          findsOneWidget,
        );
        await pull(t);
        expect(calls, 1);
      } finally {
        work.complete();
        await t.pumpAndSettle();
      }
    },
  );
  testWidgets(
    'a fast refresh ends normally and the next pull can refresh again',
    (t) async {
      var calls = 0;
      await t.pumpWidget(
        host(() async {
          calls++;
        }),
      );
      await pull(t);
      await t.pumpAndSettle();
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(find.byType(NitrateBanner), findsNothing);
      await pull(t);
      await t.pumpAndSettle();
      expect(calls, 2);
    },
  );
  testWidgets('a late failure after leaving the page is handled safely', (
    t,
  ) async {
    final work = Completer<void>();
    await t.pumpWidget(host(() => work.future));
    await pull(t);
    await t.pumpWidget(const SizedBox());
    work.completeError(StateError('network failed'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('a failed refresh stops the spinner and offers retry feedback', (
    t,
  ) async {
    await t.pumpWidget(host(() async => throw StateError('network failed')));
    await pull(t);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(
      find.text('Actualisation impossible. Réessaie dans un instant.'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
}
