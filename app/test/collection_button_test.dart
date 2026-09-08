import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/widgets/collection_button.dart';

void main() {
  Widget host(VoidCallback onPressed, {bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(body: CollectionButton(onPressed: onPressed)),
    ),
  );
  testWidgets(
    'zone tactile accessible et ouverture unique malgré deux appuis',
    (t) async {
      var calls = 0;
      await t.pumpWidget(host(() => calls++));
      final semantics = t.ensureSemantics();
      final button = find.byType(TextButton);
      expect(t.getSemantics(button).label, 'Mes séries');
      expect(t.getSize(button).width, greaterThanOrEqualTo(48));
      expect(t.getSize(button).height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Mes séries'), findsOneWidget);
      await t.tap(button);
      await t.pump(const Duration(milliseconds: 30));
      await t.tap(button);
      await t.pump(const Duration(milliseconds: 600));
      expect(calls, 1);
      expect(t.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets('réduction du mouvement ouvre immédiatement', (t) async {
    var calls = 0;
    await t.pumpWidget(host(() => calls++, reduced: true));
    await t.tap(find.byType(TextButton));
    expect(calls, 1);
    await t.pump(const Duration(milliseconds: 600));
  });
  testWidgets('un geste annulé ne navigue pas et le clic ouvre immédiatement', (
    t,
  ) async {
    var calls = 0;
    await t.pumpWidget(host(() => calls++));
    final gesture = await t.startGesture(t.getCenter(find.byType(TextButton)));
    await gesture.moveBy(const Offset(200, 0));
    await gesture.cancel();
    await t.pump(const Duration(milliseconds: 600));
    expect(calls, 0);
    await t.tap(find.byType(TextButton));
    expect(calls, 1);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    expect(calls, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('anime sans appui et reste immobile en réduction du mouvement', (
    t,
  ) async {
    await t.pumpWidget(host(() {}));
    Matrix4 pose() => t
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(CollectionButton),
            matching: find.byType(Transform),
          ),
        )
        .first
        .transform
        .clone();
    final rest = pose();
    await t.pump(const Duration(milliseconds: 360));
    expect(pose(), isNot(rest));
    await t.pumpWidget(host(() {}, reduced: true));
    await t.pump();
    final reduced = pose();
    await t.pump(const Duration(seconds: 1));
    expect(pose(), reduced);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('suspend le mouvement lorsque l’onglet est masqué', (t) async {
    Widget scene(bool visible) =>
        TickerMode(enabled: visible, child: host(() {}));
    await t.pumpWidget(scene(true));
    await t.pump(const Duration(milliseconds: 250));
    await t.pumpWidget(scene(false));
    await t.pump();
    Matrix4 pose() => t
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(CollectionButton),
            matching: find.byType(Transform),
          ),
        )
        .first
        .transform
        .clone();
    final stopped = pose();
    await t.pump(const Duration(seconds: 1));
    expect(pose(), stopped);
    await t.pumpWidget(scene(true));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(pose(), isNot(stopped));
    await t.pumpWidget(const SizedBox());
  });
}
