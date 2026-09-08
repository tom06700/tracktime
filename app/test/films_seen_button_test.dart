import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/widgets/films_seen_button.dart';
import 'package:tracktime/widgets/films_seen_painter.dart';

void main() {
  Widget host(
    VoidCallback onPressed, {
    bool reduced = false,
    bool visible = true,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: TickerMode(
        enabled: visible,
        child: Scaffold(body: FilmsSeenButton(onPressed: onPressed)),
      ),
    ),
  );
  double progress(WidgetTester t) => t
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<FilmsSeenPainter>()
      .single
      .progress;

  testWidgets(
    'accessible immediate navigation, debounced taps and cancelled drag',
    (t) async {
      var calls = 0;
      await t.pumpWidget(host(() => calls++));
      final semantics = t.ensureSemantics();
      final button = find.byType(TextButton);
      expect(t.getSemantics(button).label, 'Films vus');
      expect(t.getSize(button).shortestSide, greaterThanOrEqualTo(48));
      final gesture = await t.startGesture(t.getCenter(button));
      await gesture.moveBy(const Offset(200, 0));
      await gesture.cancel();
      expect(calls, 0);
      await t.tap(button);
      expect(calls, 1);
      await t.tap(button);
      expect(calls, 1);
      semantics.dispose();
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('1.6 second animation rests then replays at 7 seconds', (
    t,
  ) async {
    await t.pumpWidget(host(() {}));
    await t.pump(const Duration(milliseconds: 400));
    expect(progress(t), closeTo(.25, .001));
    await t.pump(const Duration(milliseconds: 1200));
    expect(progress(t), 1);
    await t.pump(const Duration(milliseconds: 5399));
    expect(progress(t), 1);
    await t.pump(const Duration(milliseconds: 1));
    await t.pump(const Duration(milliseconds: 400));
    expect(progress(t), closeTo(.25, .001));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 8));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'reduced motion and hidden tab stop animation and restart safely',
    (t) async {
      await t.pumpWidget(host(() {}));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpWidget(host(() {}, visible: false));
      await t.pump(const Duration(seconds: 8));
      expect(progress(t), 0);
      await t.pumpWidget(host(() {}, reduced: true));
      await t.pump(const Duration(seconds: 8));
      expect(progress(t), 0);
      await t.pumpWidget(host(() {}));
      await t.pump(const Duration(milliseconds: 400));
      expect(progress(t), greaterThan(0));
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('background and covering route suspend the button', (t) async {
    await t.pumpWidget(host(() {}));
    await t.pump(const Duration(milliseconds: 400));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump(const Duration(seconds: 8));
    expect(progress(t), 0);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(progress(t), greaterThan(0));
    final navigator = t.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Films vus')),
      ),
    );
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 8));
    final hidden = t
        .widgetList<CustomPaint>(find.byType(CustomPaint, skipOffstage: false))
        .map((w) => w.painter)
        .whereType<FilmsSeenPainter>()
        .single;
    expect(hidden.progress, 0);
    navigator.pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(progress(t), greaterThan(0));
    await t.pumpWidget(const SizedBox());
  });
}
