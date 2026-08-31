import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion.dart';
import '../theme.dart';
import '../widgets/media_image.dart';
import 'palette.dart';

/// Cache d'ambiances, partagé par toutes les fiches de la session.
final paletteCacheProvider = Provider<PaletteCache>((ref) => PaletteCache());

/// Part de la hauteur utile occupée par le fond d'une fiche.
const _backdropFraction = 0.40;

/// Hauteur du fond pour l'écran courant, bornée pour que ni un iPhone SE ni un
/// iPad ne donnent une bannière absurde.
double backdropHeightOf(BuildContext context) {
  final media = MediaQuery.of(context);
  final usable = media.size.height - media.padding.top;
  return (usable * _backdropFraction).clamp(240.0, 420.0);
}

/// Fond ambiant d'une fiche : la couleur du média en haut, le noir Nitrate en
/// bas. L'influence colorée s'efface à mesure qu'on descend, ce qui laisse la
/// fin de page à l'identité de l'app.
class CinematicBackground extends StatelessWidget {
  const CinematicBackground({
    super.key,
    required this.palette,
    required this.child,
  });

  final MediaPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Anime la couleur, pas la mise en page : quand l'ambiance arrive, elle se
    // substitue au noir Nitrate sans à-coup, et plus rien ne bouge ensuite.
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: palette.base),
      duration: motionOf(context, Motion.ambient),
      curve: Motion.between,
      builder: (context, color, child) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color ?? TtColors.bg, TtColors.bg],
            stops: const [0, 0.55],
          ),
        ),
        child: child,
      ),
      child: child,
    );
  }
}

/// Fond d'une fiche : l'image en grand, son titre posé dessus, et une fusion
/// progressive avec le contenu qui suit.
///
/// Rendu en sliver pour que le défilement puisse le décaler moins vite que le
/// reste sans reconstruire la page : seul l'en-tête est rebâti, et uniquement
/// tant qu'il est à l'écran.
class CinematicBackdrop extends StatelessWidget {
  const CinematicBackdrop({
    super.key,
    required this.title,
    required this.image,
    required this.seed,
    required this.icon,
    required this.palette,
  });

  final String title;

  /// Image de fond réellement affichée — celle dont l'ambiance est tirée.
  final String? image;

  final String seed;
  final IconData icon;
  final MediaPalette palette;

  @override
  Widget build(BuildContext context) {
    final height = backdropHeightOf(context);
    return SliverPersistentHeader(
      delegate: _BackdropDelegate(
        height: height,
        title: title,
        image: image,
        seed: seed,
        icon: icon,
        palette: palette,
        parallax: !reduceMotionOf(context),
      ),
    );
  }
}

class _BackdropDelegate extends SliverPersistentHeaderDelegate {
  const _BackdropDelegate({
    required this.height,
    required this.title,
    required this.image,
    required this.seed,
    required this.icon,
    required this.palette,
    required this.parallax,
  });

  final double height;
  final String title;
  final String? image;
  final String seed;
  final IconData icon;
  final MediaPalette palette;
  final bool parallax;

  /// Part du défilement reprise par l'image. Assez pour donner de la
  /// profondeur, trop peu pour se remarquer comme un effet.
  static const _depth = 0.32;

  @override
  double get maxExtent => height;

  @override
  double get minExtent => 0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final shift = parallax ? shrinkOffset * _depth : 0.0;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: height,
        minHeight: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(0, shift),
              child: MediaImage(sources: [image], seed: seed, icon: icon),
            ),
            // Assombrissement concentré sur le bas : le haut et le centre de
            // l'image restent intacts, seule la zone du titre et la jonction
            // avec le contenu sont protégées.
            const _ReadabilityScrim(),
            // Fusion avec le fond de page : aucune ligne de coupe.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height * 0.34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [palette.base, palette.base.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 22,
              child: CinematicTitle(title: title),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_BackdropDelegate old) =>
      old.height != height ||
      old.title != title ||
      old.image != image ||
      old.palette != palette ||
      old.parallax != parallax;
}

/// Voile de lisibilité. Pas un noir uniforme : l'image doit rester belle, seule
/// la moitié basse est assombrie, et surtout son dernier tiers.
class _ReadabilityScrim extends StatelessWidget {
  const _ReadabilityScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x1A000000),
            Color(0x00000000),
            Color(0x73000000),
            Color(0xD9000000),
          ],
          stops: [0, 0.42, 0.78, 1],
        ),
      ),
    );
  }
}

/// Titre posé sur le fond. Deux lignes au maximum, et une taille qui recule
/// devant un titre long plutôt que de le tronquer trop tôt.
class CinematicTitle extends StatelessWidget {
  const CinematicTitle({super.key, required this.title});

  final String title;

  /// Taille choisie sur la longueur du titre : « Dune » mérite d'occuper
  /// l'espace, « Once Upon a Time in Hollywood » doit tenir sur deux lignes.
  static double fontSizeFor(String title) {
    final n = title.characters.length;
    if (n <= 14) return 36;
    if (n <= 26) return 30;
    if (n <= 42) return 25;
    return 21;
  }

  @override
  Widget build(BuildContext context) {
    // L'agrandissement système est suivi, mais borné : au-delà, le titre
    // déborderait du fond quelle que soit sa taille de base.
    final scaler = MediaQuery.textScalerOf(context);
    final size = fontSizeFor(title);
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textScaler: TextScaler.linear(
        (scaler.scale(size) / size).clamp(1.0, 1.25),
      ),
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.06,
        // Un peu plus resserré que le reste de l'app : c'est ce qui donne au
        // titre son allure d'affiche sans changer de police.
        letterSpacing: -0.9,
        color: Colors.white,
        shadows: const [
          Shadow(
            color: Color(0xB3000000),
            blurRadius: 18,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// Retour flottant, posé au-dessus du fond. Pas une barre : rien ne doit
/// s'installer en haut de l'écran pendant le défilement.
class CinematicBackButton extends StatelessWidget {
  const CinematicBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 0, 0),
        child: Semantics(
          button: true,
          label: 'Retour',
          child: SizedBox(
            // Zone tactile confortable, pastille plus petite.
            width: 48,
            height: 48,
            child: Material(
              color: Colors.black.withValues(alpha: 0.42),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Synopsis replié sur trois lignes, dépliable sur place.
///
/// Pas de page ni de fenêtre pour lire cinq lignes de plus : le texte pousse
/// simplement le contenu qui suit.
class ExpandableSynopsis extends StatefulWidget {
  const ExpandableSynopsis({
    super.key,
    required this.text,
    required this.accent,
    this.collapsedLines = 3,
  });

  final String text;
  final Color accent;
  final int collapsedLines;

  @override
  State<ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<ExpandableSynopsis> {
  bool _open = false;

  static const _style = TextStyle(
    fontSize: 14.5,
    height: 1.6,
    color: TtColors.text,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Le bouton n'apparaît que si le texte dépasse vraiment : proposer
        // « Voir plus » sous deux lignes serait absurde.
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: _style),
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: motionOf(context, Motion.normal),
              curve: Motion.between,
              alignment: Alignment.topLeft,
              child: Text(
                widget.text,
                style: _style,
                maxLines: _open ? null : widget.collapsedLines,
                overflow: _open ? null : TextOverflow.ellipsis,
              ),
            ),
            if (overflows)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _open = !_open);
                  },
                  child: Semantics(
                    button: true,
                    child: Text(
                      _open ? 'Voir moins' : 'Voir plus',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: widget.accent,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Coquille commune aux fiches Film et Série.
///
/// Elle porte tout ce qui ne dépend pas du média : l'ambiance tirée de
/// l'image, le fond qui en découle, le retour flottant et l'entrée globale de
/// r9.1. Le contenu, lui, reste propre à chaque fiche — la coquille lui passe
/// simplement l'ambiance et l'image à afficher.
class CinematicDetailShell extends ConsumerStatefulWidget {
  const CinematicDetailShell({
    super.key,
    required this.media,
    required this.seed,
    required this.builder,
    this.backdrop,
    this.poster,
  });

  final MediaRef media;

  /// Titre servant à teindre le repli quand aucune image n'est disponible.
  final String seed;

  /// Fond, puis affiche à défaut : l'ambiance est tirée de celle qui s'affiche
  /// réellement, jamais d'une image que l'utilisateur ne verra pas.
  final String? backdrop;
  final String? poster;

  final Widget Function(BuildContext context, CinematicScope scope) builder;

  @override
  ConsumerState<CinematicDetailShell> createState() =>
      _CinematicDetailShellState();
}

/// Ce que la coquille met à disposition du contenu.
class CinematicScope {
  const CinematicScope({required this.palette, required this.image});

  final MediaPalette palette;

  /// Image du fond, déjà arbitrée entre backdrop et affiche.
  final String? image;
}

class _CinematicDetailShellState extends ConsumerState<CinematicDetailShell> {
  MediaPalette _palette = MediaPalette.nitrate;
  bool _asked = false;

  String? get _image {
    for (final s in [widget.backdrop, widget.poster]) {
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;

    final cache = ref.read(paletteCacheProvider);
    final url = _image;
    if (url == null) {
      // Aucune image : l'ambiance vient du dégradé qui en tient lieu. Elle est
      // dérivée du titre, donc stable d'une ouverture à l'autre.
      _palette = paletteFromSwatches(seedGradient(widget.seed).colors);
      return;
    }

    // Déjà connue : l'ambiance est là dès la première image, sans transition
    // ni recalcul.
    final known = cache.peek(widget.media, url);
    if (known != null) {
      _palette = known;
      return;
    }
    // Sinon on ouvre la fiche sur le noir Nitrate et l'ambiance s'installe
    // quand elle arrive — rien n'attend, rien ne tourne.
    cache.of(widget.media, url).then((p) {
      if (mounted && p != _palette) setState(() => _palette = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = CinematicScope(palette: _palette, image: _image);
    return CinematicBackground(
      palette: _palette,
      child: Stack(
        children: [
          Positioned.fill(
            child: MediaEntrance(child: widget.builder(context, scope)),
          ),
          // Au-dessus du contenu, mais posé seulement là où il est : le reste
          // de l'écran reste tactile.
          Positioned(
            top: 0,
            left: 0,
            child: CinematicBackButton(
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
