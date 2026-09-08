import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/widgets/action_pill_menu.dart';

Widget host({
  Alignment align = Alignment.topRight,
  double scale = 1,
  bool reduce = false,
  FutureOr<void> Function()? action,
}) => MaterialApp(
  theme: buildTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      padding: const EdgeInsets.only(top: 24, bottom: 34),
      disableAnimations: reduce,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: align,
          child: ActionPillMenuButton(
            label: 'Actions du film',
            actions: [
              ActionPill(
                label: 'Marquer comme vu',
                icon: Icons.check,
                onSelected: action ?? () {},
              ),
              ActionPill(
                label: 'Retirer de ma liste',
                icon: Icons.delete_outline,
                destructive: true,
                onSelected: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('menus fit safe bounds at all corners with large text', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final scale in [1.0, 2.0, 3.0]) {
      for (final align in [
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.bottomLeft,
        Alignment.bottomRight,
      ]) {
        await t.pumpWidget(host(align: align, scale: scale));
        await t.tap(find.byTooltip('Actions du film'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final viewport = t.getRect(find.byType(SingleChildScrollView));
        expect(viewport.top, greaterThanOrEqualTo(34));
        expect(viewport.bottom, lessThanOrEqualTo(522));
        for (final label in ['Marquer comme vu', 'Retirer de ma liste']) {
          final button = find.widgetWithText(TextButton, label);
          await t.ensureVisible(button);
          await t.pumpAndSettle();
          final rect = t.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(12));
          expect(rect.right, lessThanOrEqualTo(308));
          expect(rect.top, greaterThanOrEqualTo(34));
          expect(
            rect.bottom,
            lessThanOrEqualTo(522),
            reason: '$align scale=$scale label=$label rect=$rect',
          );
          expect(rect.height, greaterThanOrEqualTo(44));
        }
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.text('Retirer de ma liste'), findsNothing);
      }
    }
  });
  testWidgets('tap outside dismisses without executing a command', (t) async {
    var calls = 0;
    await t.pumpWidget(host(action: () => calls++));
    await t.tap(find.byTooltip('Actions du film'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(10, 300));
    await t.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Retirer de ma liste'), findsNothing);
  });
  testWidgets('selection executes once and waits for an async command', (
    t,
  ) async {
    var calls = 0;
    final pending = Completer<void>();
    await t.pumpWidget(
      host(
        action: () async {
          calls++;
          await pending.future;
        },
      ),
    );
    await t.tap(find.byTooltip('Actions du film'));
    await t.pumpAndSettle();
    final tapPosition = t.getCenter(find.text('Marquer comme vu'));
    await t.tapAt(tapPosition);
    await t.tapAt(tapPosition);
    await t.pumpAndSettle();
    expect(calls, 1);
    await t.tap(find.byTooltip('Actions du film'));
    await t.pumpAndSettle();
    expect(find.text('Retirer de ma liste'), findsNothing);
    pending.complete();
    await t.pump();
    await t.tap(find.byTooltip('Actions du film'));
    await t.pumpAndSettle();
    expect(find.text('Retirer de ma liste'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
  });
  testWidgets('reduce motion presents and dismisses immediately', (t) async {
    await t.pumpWidget(host(reduce: true));
    await t.tap(find.byTooltip('Actions du film'));
    await t.pump();
    final rect = t.getRect(find.text('Marquer comme vu'));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.getRect(find.text('Marquer comme vu')), rect);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.text('Retirer de ma liste'), findsNothing);
  });
  testWidgets('removing the owner closes the overlay', (t) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (c, v, _) => v
                ? ActionPillMenuButton(
                    label: 'Actions',
                    actions: [
                      ActionPill(
                        label: 'Commande',
                        icon: Icons.check,
                        onSelected: () {},
                      ),
                    ],
                  )
                : const Text('Fermé'),
          ),
        ),
      ),
    );
    await t.tap(find.byTooltip('Actions'));
    await t.pumpAndSettle();
    visible.value = false;
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Commande'), findsNothing);
  });
}
