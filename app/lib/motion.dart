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

/// Relie l'affiche touchée à celle de sa fiche.
///
/// Le tag ne dépend que du type et de l'identifiant, jamais du titre — qui
/// change avec la langue et n'identifie rien.
///
/// Une même œuvre ne doit porter ce tag qu'une fois par écran, sinon Flutter
/// lève « multiple heroes share the same tag ». Les rangées de découverte
/// passent donc [enabled] à false : un même film peut figurer à la fois dans
/// les populaires et dans les sorties à venir.
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
