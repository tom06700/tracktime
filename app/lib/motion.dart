import 'dart:async';

import 'package:flutter/material.dart';

/// Conventions de mouvement de Nitrate.
///
/// Le mouvement explique, accompagne ou récompense — il ne distrait pas. D'où
/// l'absence de rebond, d'élastique et de translation longue : rien qui attire
/// l'œil pour lui-même.
abstract final class Motion {
  /// Réaction immédiate à un geste : coche, surbrillance, bascule d'état.
  static const fast = Duration(milliseconds: 140);

  /// Apparition de contenu, changement d'état visible.
  static const normal = Duration(milliseconds: 220);

  /// Surface qui change en entier.
  static const slow = Duration(milliseconds: 320);

  /// Changement d'ambiance : le fond d'une fiche qui prend les couleurs de son
  /// image. Plus lent que le reste, parce que c'est un décor qui s'installe et
  /// non une réponse à un geste — et une seule fois, jamais en boucle.
  static const ambient = Duration(milliseconds: 620);

  /// Entrée : décélère jusqu'à sa place, sans dépassement.
  static const enter = Curves.easeOutCubic;

  /// Va-et-vient entre deux états stables.
  static const between = Curves.easeInOutCubic;

  /// Relèvement d'une entrée. Le contenu se pose ; il n'arrive pas de loin.
  static const rise = 8.0;

  /// Décalage entre deux éléments d'une même entrée, et nombre maximal
  /// d'éléments décalés — au-delà, la cascade se voit et lasse.
  static const stagger = Duration(milliseconds: 35);
  static const staggerMax = 5;

  /// Décalage d'un élément à l'index [i] d'une entrée échelonnée.
  static Duration staggerAt(int i) =>
      i >= staggerMax ? Duration.zero : stagger * i;
}

/// Vrai quand le système demande de limiter les animations.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// [d], ou zéro si l'utilisateur a demandé moins de mouvement. L'état change
/// toujours ; seul le trajet disparaît.
Duration motionOf(BuildContext context, Duration d) =>
    reduceMotionOf(context) ? Duration.zero : d;

/// Apparition d'un contenu : fondu et léger relèvement, une seule fois.
///
/// L'animation ne rejoue pas à chaque reconstruction — sinon cocher un
/// épisode ferait clignoter toute la liste. Elle ne rejoue qu'au remontage,
/// donc au premier affichage de l'écran.
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;

  /// Décalage d'entrée, pour un échelonnement discret. Voir [Motion.staggerAt].
  final Duration delay;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      // Une frame masquée d'abord, sinon il n'y a rien à animer.
      WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    } else {
      _timer = Timer(widget.delay, _show);
    }
  }

  void _show() {
    if (mounted) setState(() => _shown = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _shown ? 1 : 0),
      duration: Motion.normal,
      curve: Motion.enter,
      // Opacité et translation seulement : rien qui déclenche une mise en page.
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * Motion.rise),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Relie une affiche d'un écran à l'autre.
///
/// Le tag ne dépend que du type et de l'identifiant, jamais du titre — qui
/// change avec la langue et n'identifie rien.
///
/// N'est plus employé pour ouvrir une fiche : c'est la transition de route qui
/// porte l'ouverture, et une affiche qui vole par-dessus lui volerait la
/// vedette. Le helper reste disponible pour des liaisons ponctuelles, avec
/// deux règles : une œuvre ne porte ce tag qu'une fois par écran — sinon
/// Flutter lève « multiple heroes share the same tag » — d'où [enabled], que
/// les listes susceptibles de répéter une œuvre laissent à false.
class MediaPosterHero extends StatelessWidget {
  const MediaPosterHero({
    super.key,
    required this.id,
    required this.isSeries,
    required this.child,
    this.enabled = true,
  });

  final int id;
  final bool isSeries;
  final Widget child;
  final bool enabled;

  static String tagFor({required int id, required bool isSeries}) =>
      '${isSeries ? 'series' : 'movie'}-$id';

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Hero(
      tag: tagFor(id: id, isSeries: isSeries),
      child: child,
    );
  }
}

/// Entrée d'une fiche média, calée sur l'animation de la route qui l'ouvre.
///
/// Le fond se pose d'un très léger zoom pendant que la page arrive, puis le
/// contenu se révèle en fondu — un seul mouvement, pas deux. Rien n'est piloté
/// par un contrôleur propre : tout suit l'animation de la route, ce qui évite
/// qu'une animation interne rejoue par-dessus la transition.
///
/// Réservé aux plateformes dont la transition de page est un glissement
/// latéral, c'est-à-dire iOS et macOS. Ailleurs, la transition de route fait
/// déjà zoom et fondu : s'y ajouter produirait le double mouvement qu'on
/// cherche précisément à éviter.
///
/// Hors d'une route animée — un test, un aperçu — l'enfant est rendu tel quel.
class MediaEntrance extends StatelessWidget {
  const MediaEntrance({super.key, required this.child});

  final Widget child;

  /// Zoom de départ. Assez pour donner de la profondeur, trop peu pour se
  /// remarquer comme un effet.
  static const _from = 1.03;

  /// Repère de l'enveloppe animée. Absente de l'arbre quand il n'y a rien à
  /// animer, ce qui rend le repli vérifiable.
  static const key_ = ValueKey<String>('entree-fiche');

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final slides =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final animation = ModalRoute.of(context)?.animation;
    if (!slides || animation == null || reduceMotionOf(context)) return child;

    return AnimatedBuilder(
      key: key_,
      animation: animation,
      // L'enfant est construit une fois : seules l'échelle et l'opacité
      // varient, deux opérations qui ne déclenchent aucune mise en page.
      child: child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(animation.value.clamp(0, 1));
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: _from + (1 - _from) * t,
            filterQuality: FilterQuality.low,
            child: child,
          ),
        );
      },
    );
  }
}
