import 'package:flutter/material.dart';

import '../theme.dart';

/// Dégradé stable dérivé d'un titre : deux séries différentes n'ont jamais la
/// même teinte, et une même série garde la sienne d'un écran à l'autre.
Gradient seedGradient(String seed) {
  final hue = (seed.codeUnits.fold<int>(0, (a, c) => a * 31 + c) % 360)
      .toDouble();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor(),
      HSLColor.fromAHSL(1, (hue + 40) % 360, 0.60, 0.26).toColor(),
    ],
  );
}

/// Image de contenu, avec repli en cascade et apparition en fondu.
///
/// L'ordre des sources compte : pour un épisode c'est le still horizontal qui
/// doit primer, l'affiche verticale n'étant qu'un dernier recours — un poster
/// étiré dans un cadre 16:9 est laid. Si aucune source ne charge, un dégradé
/// dérivé du titre tient lieu d'image, jamais un carré vide.
class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.sources,
    required this.seed,
    this.fit = BoxFit.cover,
    this.icon,
  });

  /// Sources par ordre de préférence ; les entrées nulles ou vides sont
  /// ignorées. Seule la première exploitable est chargée.
  final List<String?> sources;

  /// Titre servant à teinter le repli.
  final String seed;

  final BoxFit fit;

  /// Pictogramme posé sur le dégradé de repli.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final url = sources.firstWhere(
      (s) => s != null && s.isNotEmpty,
      orElse: () => null,
    );
    if (url == null) return _fallback;

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Image.network(
      url,
      fit: fit,
      // Pas de saut de mise en page pendant le chargement : le dégradé occupe
      // déjà la place définitive.
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback,
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync || reduceMotion) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: frame == null ? _fallback : child,
        );
      },
      errorBuilder: (_, _, _) => _fallback,
    );
  }

  Widget get _fallback => DecoratedBox(
    decoration: BoxDecoration(gradient: seedGradient(seed)),
    child: icon == null
        ? const SizedBox.expand()
        : Center(
            child: Icon(
              icon,
              size: 30,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
  );
}

/// Voile sombre du bas vers le haut, pour poser du texte sur une image sans
/// dépendre de sa luminosité.
class MediaScrim extends StatelessWidget {
  const MediaScrim({super.key, this.height = 0.72});

  /// Part de la hauteur couverte par le dégradé.
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            TtColors.bg.withValues(alpha: 0.94),
            TtColors.bg.withValues(alpha: 0.72),
            Colors.transparent,
          ],
          stops: [0, height * 0.5, height],
        ),
      ),
    );
  }
}
