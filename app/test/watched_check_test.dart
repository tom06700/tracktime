import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:tracktime/widgets/watched_check.dart';

void main() {
  testWidgets('the rendered glyph uses its requested foreground color', (
    t,
  ) async {
    final key = GlobalKey();
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: const WatchedCheck(
              confirmed: false,
              size: 48,
              color: Color(0xFFE5D9F6),
            ),
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await t.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await t.runAsync(() => boundary.toImage());
    final bytes = (await t.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    var opaque = 0;
    for (var i = 0; i < bytes.lengthInBytes; i += 4) {
      // rawRgba is premultiplied; compare only fully opaque stroke pixels.
      if (bytes.getUint8(i + 3) == 255) {
        opaque++;
        expect(bytes.getUint8(i), closeTo(229, 1));
        expect(bytes.getUint8(i + 1), closeTo(217, 1));
        expect(bytes.getUint8(i + 2), closeTo(246, 1));
      }
    }
    expect(opaque, greaterThan(30));
    image!.dispose();
  });
  Widget host({
    bool confirmed = false,
    bool busy = false,
    bool reduced = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(
        child: WatchedCheck(confirmed: confirmed, busy: busy),
      ),
    ),
  );

  testWidgets('confirmation animates only after success and does not replay', (
    t,
  ) async {
    await t.pumpWidget(host());
    final glyphElement = t.element(find.byType(LottieBuilder));
    await t.pumpWidget(host(busy: true));
    expect(
      find.byWidgetPredicate((w) => w is WatchedCheck && w.confirmed),
      findsNothing,
    );
    await t.pumpWidget(host(confirmed: true));
    expect(
      t.element(find.byType(LottieBuilder)),
      same(glyphElement),
      reason: 'Keep the loaded animation mounted while drawing the check',
    );
    await t.pump(const Duration(milliseconds: 160));
    final controller = t
        .widget<LottieBuilder>(find.byType(LottieBuilder))
        .controller!;
    expect(controller.value, allOf(greaterThan(0), lessThan(1)));
    await t.pump(const Duration(milliseconds: 500));
    expect(controller.value, 1);
    await t.pumpWidget(host(confirmed: true));
    expect(controller.value, 1);
    await t.pumpWidget(host());
    expect(controller.value, 0);
  });

  testWidgets('reduced motion goes straight to the static check', (t) async {
    await t.pumpWidget(host(reduced: true));
    await t.pumpWidget(host(confirmed: true, reduced: true));
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(LottieBuilder), findsNothing);
    expect(t.binding.hasScheduledFrame, isFalse);
  });
}
