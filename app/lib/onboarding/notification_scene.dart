import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../motion.dart';

/// Decorative notification examples, using the pack's artwork and timings.
class NotificationScene extends StatelessWidget {
  const NotificationScene({super.key, required this.clock});
  final ValueNotifier<double> clock;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 352,
        child: LayoutBuilder(
            builder: (context, constraints) => MediaQuery.withNoTextScaling(
                child: AnimatedBuilder(
                    animation: clock,
                    builder: (context, _) {
                      final reduced = reduceMotionOf(context);
                      final t = reduced ? 1.3 : clock.value;
                      double wave(double period, [double delay = 0]) => reduced
                          ? 0
                          : (1 - math.cos((t + delay) / period * math.pi * 2)) /
                              2;
                      final arrive = reduced
                          ? 1.0
                          : const Cubic(.2, 1.15, .3, 1)
                              .transform((t / 1.3).clamp(0.0, 1.0));
                      final hover = wave(7, -1.3);
                      final ring = (t - 1) % 6;
                      Widget object(String asset, double size, double tilt,
                              double delay) =>
                          Transform.translate(
                              offset: Offset(0, -16 * wave(8, delay)),
                              child: Transform.rotate(
                                  angle: (tilt + 9 * wave(8, delay)) *
                                      math.pi /
                                      180,
                                  child: Image.asset(
                                      'assets/objects/$asset.png',
                                      width: size,
                                      height: size)));
                      return Stack(clipBehavior: Clip.none, children: [
                        for (final back in [false, true])
                          Positioned(
                              top: back ? 8 : 40,
                              left:
                                  (constraints.maxWidth - (back ? 330 : 266)) /
                                      2,
                              child: Transform(
                                  transform: Matrix4.identity()
                                    ..rotateX((back ? 65 : 57) * math.pi / 180)
                                    ..rotateZ(
                                        (back ? 29 : -28) * math.pi / 180),
                                  alignment: Alignment.center,
                                  child: Container(
                                      width: back ? 330 : 266,
                                      height: back ? 330 : 266,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Color(back
                                                  ? 0x73232027
                                                  : 0xCC232027)))))),
                        Positioned(
                            top: 72 - 7 * wave(9),
                            left: constraints.maxWidth * .105,
                            right: constraints.maxWidth * .105,
                            child: Opacity(
                                opacity: .55,
                                child: Transform.rotate(
                                    angle: (-8 + 3 * wave(9)) * math.pi / 180,
                                    child: Transform.scale(
                                        scale: .92,
                                        child: _alert(back: true))))),
                        Positioned(
                            top: 44,
                            left: constraints.maxWidth * .08,
                            child: object('popcorn', 47, -16, 0)),
                        Positioned(
                            top: 72,
                            right: constraints.maxWidth * .03,
                            child: object('dragon', 65, 12, 3)),
                        Positioned(
                            top: 242,
                            left: constraints.maxWidth * .12,
                            child: object('admission_tickets', 53, -18, 5)),
                        Positioned(
                            top: 137 +
                                55 * (1 - arrive) -
                                (t > 1.3 ? 9 * hover : 0),
                            left: constraints.maxWidth * .04,
                            right: constraints.maxWidth * .04,
                            child: Opacity(
                                opacity: arrive.clamp(0.0, 1.0),
                                child: Transform.rotate(
                                    angle: (-10 +
                                            13 * arrive -
                                            (t > 1.3 ? 2 * hover : 0)) *
                                        math.pi /
                                        180,
                                    child: Transform.scale(
                                        scale: .8 + .2 * arrive,
                                        child: _alert(back: false))))),
                        Positioned(
                            top: 265,
                            left: (constraints.maxWidth - 51) / 2,
                            child: Container(
                                width: 51,
                                height: 51,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                        color: const Color(0xFF38353E)),
                                    gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF333038),
                                          Color(0xFF121114)
                                        ])),
                                child:
                                    Stack(clipBehavior: Clip.none, children: [
                                  Center(
                                      child: Transform.rotate(
                                          alignment: Alignment.topCenter,
                                          angle: !reduced && ring < .48
                                              ? math.sin(ring /
                                                      .48 *
                                                      math.pi *
                                                      6) *
                                                  .24
                                              : 0,
                                          child: const Icon(
                                              Icons.notifications_none_rounded,
                                              size: 24,
                                              color: Color(0xFFE8E1F6)))),
                                  Positioned(
                                      top: -5,
                                      right: -5,
                                      child: Transform.scale(
                                          scale: !reduced && ring < .6
                                              ? 1 +
                                                  .18 *
                                                      math.sin(
                                                          ring / .6 * math.pi)
                                              : 1,
                                          child: Container(
                                              width: 20,
                                              height: 20,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFD4F5A0),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: Colors.black,
                                                      width: 2)),
                                              child: const Text('1',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Color(
                                                          0xFF253219)))))),
                                ]))),
                        const Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Text('Aperçu de notification',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10, color: Color(0xFF929096)))),
                      ]);
                    }))),
      );

  Widget _alert({required bool back}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      decoration: BoxDecoration(
          color: Color(back ? 0xFF121214 : 0xFF222226),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: Color(back ? 0xFF29272D : 0xFF44434C)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x88000000), blurRadius: 45, offset: Offset(0, 16))
          ]),
      child: Row(children: [
        Container(
            width: 39,
            height: 39,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFFD3C0FF),
                borderRadius: BorderRadius.circular(13)),
            child: const Text('n.',
                style: TextStyle(
                    fontSize: 23,
                    letterSpacing: -2,
                    color: Color(0xFF20182E)))),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              Row(children: [
                const Expanded(
                    child: Text('NITRATE',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            color: Color(0xFFC0BDC9)))),
                if (!back)
                  const Text('maintenant',
                      style: TextStyle(fontSize: 10, color: Color(0xFFA5A2AF)))
              ]),
              const SizedBox(height: 4),
              Text(back ? 'La suite arrive.' : 'La suite de ton histoire.',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(
                  back
                      ? 'Une nouvelle saison à retrouver.'
                      : 'Un nouvel épisode de One Piece est sorti.',
                  style: const TextStyle(
                      fontSize: 11, height: 1.5, color: Color(0xFFBDBAC5))),
            ])),
        if (!back) ...[
          const SizedBox(width: 6),
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFFD4F5A0)))
        ],
      ]));
}
