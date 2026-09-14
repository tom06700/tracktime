import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/widgets/portal/portal_empty.dart';
import 'package:tracktime/widgets/portal/portal_geometry.dart';
import 'package:tracktime/widgets/portal/portal_transition_host.dart';

class Harness extends StatefulWidget {
  const Harness({super.key, this.reduced = false});
  final bool reduced;
  @override
  State<Harness> createState() => HarnessState();
}

class HarnessState extends State<Harness> {
  int index = 0, changes = 0;
  void select(int value) {
    setState(() {
      index = value;
      changes++;
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: widget.reduced,
      ),
      child: PortalTransitionHost(
        index: index,
        onSelected: select,
        scaffoldBuilder: (body, _) => Scaffold(body: body),
        screens: [
          PortalEmpty(onExplore: () => select(2)),
          const SizedBox(),
          const SafeArea(
            child: Column(
              children: [
                Text('Explorer réel'),
                TextField(key: ValueKey('query')),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'empty portal remains reachable with large text on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(body: PortalEmpty(onExplore: () => opened = true)),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Explorer les séries'));
      await tester.tap(find.text('Explorer les séries'));
      await tester.pump();
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'CTA reveals the existing Explorer and commits once after travel',
    (tester) async {
      final key = GlobalKey<HarnessState>();
      await tester.pumpWidget(Harness(key: key));
      await tester.pump();
      await tester.ensureVisible(find.text('Explorer les séries'));
      await tester.tap(find.text('Explorer les séries'));
      await tester.pump();
      expect(find.byKey(const ValueKey('portal-traversal')), findsOneWidget);
      expect(key.currentState!.index, 0);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('Explorer réel'), findsOneWidget);
      expect(key.currentState!.index, 0);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      expect(key.currentState!.index, 2);
      expect(key.currentState!.changes, 1);
      expect(find.byKey(const ValueKey('portal-traversal')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('query')), 'Severance');
      key.currentState!.select(0);
      await tester.pump();
      await tester.tap(
        find.bySemanticsLabel('Traverser la porte vers Explorer'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pump();
      expect(find.text('Severance'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('reduced motion navigates directly with no overlay', (
    tester,
  ) async {
    final key = GlobalKey<HarnessState>();
    await tester.pumpWidget(Harness(key: key, reduced: true));
    await tester.tap(find.bySemanticsLabel('Traverser la porte vers Explorer'));
    await tester.pump();
    expect(key.currentState!.index, 2);
    expect(key.currentState!.changes, 1);
    expect(find.byKey(const ValueKey('portal-traversal')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('system back cancels passage and leaves the source usable', (
    tester,
  ) async {
    final key = GlobalKey<HarnessState>();
    await tester.pumpWidget(Harness(key: key));
    await tester.tap(find.bySemanticsLabel('Traverser la porte vers Explorer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(key.currentState!.index, 0);
    expect(key.currentState!.changes, 0);
    expect(find.byKey(const ValueKey('portal-traversal')), findsNothing);
    await tester.tap(find.bySemanticsLabel('Traverser la porte vers Explorer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();
    expect(key.currentState!.index, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('double activation and disposal do not leave a pending passage', (
    tester,
  ) async {
    final key = GlobalKey<HarnessState>();
    await tester.pumpWidget(Harness(key: key));
    final button = find.bySemanticsLabel('Traverser la porte vers Explorer');
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();
    expect(key.currentState!.changes, 1);
    key.currentState!.select(0);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  test('idle seam and initial projection agree; aperture covers arrival', () {
    const stage = Rect.fromLTWH(0, 190, 390, 260), size = Size(390, 844);
    final rest = PortalGeometry(stage: stage, viewport: size, phase: .4);
    final entry = PortalGeometry(
      stage: stage,
      viewport: size,
      phase: .4,
      travelling: true,
    );
    expect(entry.project(.4, .8, .1), rest.project(.4, .8, .1));
    expect(entry.angle, rest.angle);
    final start = PortalGeometry(stage: stage, viewport: size, phase: 0);
    final end = PortalGeometry(stage: stage, viewport: size, phase: 1);
    expect(start.angle, end.angle);
    for (var i = 0; i < 100; i++) {
      expect(
        PortalGeometry(stage: stage, viewport: size, phase: i / 100).angle,
        greaterThanOrEqualTo(.72),
      );
    }
    final arrived = PortalGeometry(
      stage: stage,
      viewport: size,
      phase: 0,
      travelling: true,
      seconds: 1.86,
    );
    expect(arrived.aperture.getBounds(), Offset.zero & size);
  });
}
