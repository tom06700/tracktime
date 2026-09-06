import 'package:flutter/material.dart';
import '../motion.dart';
import 'media_image.dart';
import 'modern_controls.dart';

/// Native geometry from global handoff 06/07. Artwork belongs to this work only.
class ValidatedDetailHero extends StatelessWidget {
  const ValidatedDetailHero(
      {super.key,
      required this.title,
      required this.sources,
      this.kicker = '',
      this.subtitle = '',
      this.film = false,
      this.onManage});
  final String title, kicker, subtitle;
  final List<String?> sources;
  final bool film;
  final VoidCallback? onManage;
  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width < 370;
    final top = MediaQuery.paddingOf(context).top;
    final shortFilm = film && title.length <= 18;
    final titleStyle = TextStyle(
        fontSize: shortFilm ? (small ? 57 : 65) : (small ? 43 : 49),
        height: 1.1,
        letterSpacing: shortFilm ? 4 : -2,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFF4F2F8));
    final textWidth = MediaQuery.sizeOf(context).width - (small ? 42 : 48);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
          text: TextSpan(
              text: text,
              style: style.copyWith(
                  fontFamily:
                      Theme.of(context).textTheme.bodyMedium?.fontFamily)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context))
        ..layout(maxWidth: textWidth);
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final contentHeight = measure(title, titleStyle) +
        (kicker.isEmpty
            ? 0
            : measure(kicker.toUpperCase(),
                    const TextStyle(fontSize: 10, letterSpacing: 2)) +
                11) +
        (subtitle.isEmpty
            ? 0
            : measure(subtitle, const TextStyle(fontSize: 12)) + 8);
    final baseHeight =
        (film ? (small ? 330.0 : 365.0) : (small ? 300.0 : 330.0)) + top;
    final height = baseHeight.clamp(top + 90 + contentHeight, double.infinity);
    return SizedBox(
        height: height,
        child: Stack(fit: StackFit.expand, children: [
          ClipRect(
              child: TweenAnimationBuilder<double>(
                  tween:
                      Tween(begin: reduceMotionOf(context) ? 1.0 : 0.0, end: 1),
                  duration: motionOf(
                      context, Duration(milliseconds: film ? 900 : 1100)),
                  curve: const Cubic(.2, .8, .2, 1),
                  builder: (_, value, child) => Transform.scale(
                      scale: 1 + (film ? .09 : .08) * (1 - value),
                      child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: .3 * (1 - value)),
                              BlendMode.srcATop),
                          child: child)),
                  child: MediaImage(
                      sources: sources,
                      seed: title,
                      alignment: Alignment(0, film ? -.4 : -.34),
                      icon: film ? Icons.movie_outlined : Icons.tv))),
          const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                Color(0x77000000),
                Colors.transparent,
                ModernPalette.background
              ],
                      stops: [
                0,
                .28,
                .99
              ]))),
          Positioned(
              top: top + 12,
              left: 12,
              right: 16,
              child: Row(children: [
                IconButton.filledTonal(
                    tooltip: 'Retour',
                    onPressed: () => Navigator.maybePop(context),
                    style: IconButton.styleFrom(
                        backgroundColor: const Color(0xBC15171B),
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.arrow_back, size: 20)),
                const Spacer(),
                if (onManage != null)
                  IconButton.filledTonal(
                      tooltip: 'Gérer',
                      onPressed: onManage,
                      style: IconButton.styleFrom(
                          backgroundColor: const Color(0xBC15171B),
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.more_horiz, size: 20)),
              ])),
          Positioned(
              left: small ? 18 : 24,
              right: 24,
              bottom: 12,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (kicker.isNotEmpty)
                      Text(kicker.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: Color(0xFFD5D7D9))),
                    const SizedBox(height: 11),
                    Text(title, style: titleStyle),
                    if (subtitle.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFC2BDC8)))),
                  ])),
        ]));
  }
}

class DetailSectionHeading extends StatelessWidget {
  const DetailSectionHeading(this.title, {super.key, this.hint});
  final String title;
  final String? hint;
  @override
  Widget build(BuildContext context) => Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            if (hint != null)
              Text(hint!,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF9F98AA))),
          ]);
}
