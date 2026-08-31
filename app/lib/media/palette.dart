import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Ambiance d'une fiche, dérivée de l'image que l'utilisateur voit.
///
/// Trois rôles seulement, parce qu'une fiche n'a pas besoin de plus : le fond
/// de page, la surface des blocs posés dessus, et un accent pour ce qui doit
/// ressortir. Les couleurs sont toujours retravaillées avant d'arriver ici —
/// une dominante brute donne du néon, du rouge agressif ou un fond trop clair.
@immutable
class MediaPalette {
  const MediaPalette({
    required this.base,
    required this.surface,
    required this.accent,
  });

  /// Fond de page : profond, presque noir, teinté.
  final Color base;

  /// Blocs posés sur le fond.
  final Color surface;

  /// Accent lisible sur [base].
  final Color accent;

  /// Ambiance par défaut : celle de Nitrate, servie tant qu'aucune image n'a
  /// livré ses couleurs, et retenue pour les images sans teinte exploitable.
  static const nitrate = MediaPalette(
    base: TtColors.bg,
    surface: TtColors.surface,
    accent: TtColors.amber,
  );

  @override
  bool operator ==(Object other) =>
      other is MediaPalette &&
      other.base == base &&
      other.surface == surface &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(base, surface, accent);
}

/// Rapport de contraste WCAG entre deux couleurs.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// En dessous, l'image est trop grise pour qu'une teinte veuille dire quelque
/// chose : la teinter donnerait un gris sale, pas une ambiance.
const _minSaturation = 0.10;

/// Transforme des couleurs brutes en ambiance Nitrate.
///
/// Trois garde-fous : la clarté est imposée, donc jamais de fond clair ; la
/// saturation est bornée, donc jamais de néon ni de rouge criard ; et l'accent
/// est remonté jusqu'à contraster franchement avec le fond, la lisibilité
/// primant sur la fidélité à l'image.
///
/// Fonction pure : c'est elle qui porte toute la décision esthétique, et elle
/// se teste sans image.
MediaPalette paletteFromSwatches(List<Color> swatches) {
  final usable = swatches
      .map(HSLColor.fromColor)
      .where((c) => c.saturation >= _minSaturation)
      .toList();
  if (usable.isEmpty) return MediaPalette.nitrate;

  final dominant = usable.first;

  // Fond : la teinte de l'image, sa saturation ramenée dans une plage sobre,
  // et une clarté imposée — c'est ce qui garde toutes les fiches également
  // sombres, quelle que soit l'affiche.
  final base = HSLColor.fromAHSL(
    1,
    dominant.hue,
    dominant.saturation.clamp(0.18, 0.42),
    0.085,
  ).toColor();

  final surface = HSLColor.fromAHSL(
    1,
    dominant.hue,
    dominant.saturation.clamp(0.14, 0.34),
    0.165,
  ).toColor();

  // Accent : la teinte la plus éloignée de la dominante, pour qu'il se
  // distingue du fond au lieu de s'y fondre.
  final accentSource = usable.reduce(
    (a, b) =>
        _hueDistance(b.hue, dominant.hue) > _hueDistance(a.hue, dominant.hue)
        ? b
        : a,
  );
  var accent = HSLColor.fromAHSL(
    1,
    accentSource.hue,
    accentSource.saturation.clamp(0.35, 0.62),
    0.62,
  );

  // Lisibilité d'abord : on éclaircit jusqu'à un contraste franc avec le fond.
  while (contrastRatio(accent.toColor(), base) < 4.5 &&
      accent.lightness < 0.9) {
    accent = accent.withLightness(accent.lightness + 0.05);
  }

  return MediaPalette(base: base, surface: surface, accent: accent.toColor());
}

double _hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

/// Couleurs dominantes de pixels RGBA bruts, de la plus fréquente à la moins.
///
/// Regroupe les pixels par teinte plutôt que par valeur exacte : deux bleus
/// voisins comptent pour le même, sinon un dégradé de ciel produirait mille
/// couleurs uniques et aucune dominante.
///
/// Les pixels trop sombres, trop clairs ou trop peu transparents sont écartés :
/// ils décrivent le cadre de l'image, pas son ambiance.
List<Color> dominantColors(Uint8List rgba, {int max = 3}) {
  const buckets = 24; // 15° de teinte par groupe
  final weight = List<double>.filled(buckets, 0);
  final sumSat = List<double>.filled(buckets, 0);
  final sumLight = List<double>.filled(buckets, 0);

  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) continue;
    final color = Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]);
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.12 || hsl.lightness > 0.94) continue;
    if (hsl.saturation < _minSaturation) continue;

    final b = (hsl.hue / 360 * buckets).floor().clamp(0, buckets - 1);
    // Une couleur franche pèse plus qu'une couleur délavée : c'est elle qui
    // donne son caractère à l'image.
    final w = hsl.saturation;
    weight[b] += w;
    sumSat[b] += hsl.saturation * w;
    sumLight[b] += hsl.lightness * w;
  }

  final ranked = [
    for (var b = 0; b < buckets; b++)
      if (weight[b] > 0) (bucket: b, weight: weight[b]),
  ]..sort((a, b) => b.weight.compareTo(a.weight));

  return [
    for (final e in ranked.take(max))
      HSLColor.fromAHSL(
        1,
        (e.bucket + 0.5) * 360 / buckets,
        sumSat[e.bucket] / weight[e.bucket],
        sumLight[e.bucket] / weight[e.bucket],
      ).toColor(),
  ];
}

/// Œuvre dont on calcule l'ambiance. Le type fait partie de l'identité : un
/// film 1406 et une série 1406 sont deux œuvres sans rapport.
@immutable
class MediaRef {
  const MediaRef({required this.id, required this.isSeries});

  final int id;
  final bool isSeries;

  String cacheKey(String url) => '${isSeries ? 'series' : 'movie'}-$id|$url';

  @override
  bool operator ==(Object other) =>
      other is MediaRef && other.id == id && other.isSeries == isSeries;

  @override
  int get hashCode => Object.hash(id, isSeries);
}

/// Extrait l'ambiance d'une image et la retient pour la session.
///
/// Le cache est indispensable : sans lui, revenir sur une fiche recalculerait
/// tout, et un rebuild pendant le défilement aussi. La clé est l'URL de
/// l'image réellement affichée — deux fiches qui montrent la même image
/// partagent donc la même ambiance, ce qui est exactement ce qu'on veut.
class PaletteCache {
  PaletteCache({ImageProvider Function(String url)? provider})
    : _provider = provider ?? NetworkImage.new;

  final ImageProvider Function(String url) _provider;
  final Map<String, MediaPalette> _done = {};
  final Map<String, Future<MediaPalette>> _running = {};

  /// Ambiance déjà connue, sans rien déclencher : c'est ce qui permet de
  /// rouvrir une fiche avec son ambiance dès la première image.
  MediaPalette? peek(MediaRef ref, String? url) =>
      url == null ? null : _done[ref.cacheKey(url)];

  Future<MediaPalette> of(MediaRef ref, String? url) {
    if (url == null || url.isEmpty) {
      return Future.value(MediaPalette.nitrate);
    }
    final key = ref.cacheKey(url);
    final known = _done[key];
    if (known != null) return Future.value(known);
    // Deux fiches ouvertes coup sur coup ne décodent pas deux fois la même
    // image.
    return _running[key] ??= _compute(url).then((p) {
      _done[key] = p;
      _running.remove(key);
      return p;
    });
  }

  Future<MediaPalette> _compute(String url) async {
    try {
      final swatches = await swatchesOfImage(_provider(url));
      return paletteFromSwatches(swatches);
    } catch (e, st) {
      // Une image illisible ne doit pas priver la fiche de son fond.
      debugPrint('Ambiance de $url indisponible : $e\n$st');
      return MediaPalette.nitrate;
    }
  }

  @visibleForTesting
  void clear() {
    _done.clear();
    _running.clear();
  }
}

/// Taille à laquelle l'image est relue pour l'analyse.
///
/// Une miniature suffit largement à trouver des dominantes, et évite de
/// parcourir deux millions de pixels sur le fil d'exécution de l'interface.
const _sampleWidth = 32;
const _sampleHeight = 18;

/// Redessine [provider] en miniature et en extrait ses couleurs dominantes.
Future<List<Color>> swatchesOfImage(ImageProvider provider) async {
  final image = await _resolve(provider);
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    const Rect.fromLTWH(0, 0, _sampleWidth * 1.0, _sampleHeight * 1.0),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final small = await recorder.endRecording().toImage(
    _sampleWidth,
    _sampleHeight,
  );
  try {
    final data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return const [];
    return dominantColors(data.buffer.asUint8List());
  } finally {
    small.dispose();
  }
}

Future<ui.Image> _resolve(ImageProvider provider) {
  final completer = Completer<ui.Image>();
  // Passe par le cache d'images de Flutter : l'image affichée par la fiche est
  // déjà là, on ne la retélécharge pas.
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image);
      stream.removeListener(listener);
    },
    onError: (error, stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}
