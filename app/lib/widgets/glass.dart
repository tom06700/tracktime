import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Système « Liquid Glass » v2.
///
/// Ce qui fait le rendu (d'après les HIG WWDC25 et les implémentations
/// de référence) :
/// 1. Vibrance : le flou est composé avec une hausse de saturation, pour que
///    les couleurs derrière le verre « percent » au lieu de devenir grises.
/// 2. Flou modéré (sigma 10–15) : trop de flou écrase la matière.
/// 3. Bordure en dégradé : arête spéculaire lumineuse en haut, rim discret
///    en bas, côtés éteints — jamais une bordure uniforme.
/// 4. Lensing : sur l'anneau du pourtour, l'arrière-plan est légèrement
///    grossi, comme à travers du verre bombé.
/// 5. Repli opaque quand « Réduire la transparence » est actif.

List<double> _saturationMatrix(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  return <double>[
    lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, 0,
    lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, 0,
    lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Flou + vibrance (saturation boostée), le cœur du matériau.
ui.ImageFilter _glassBackdrop(double sigma, {double saturation = 1.5}) {
  return ui.ImageFilter.compose(
    outer: ui.ImageFilter.blur(
        sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror),
    inner: ColorFilter.matrix(_saturationMatrix(saturation)),
  );
}

/// Arêtes du verre : bordure au dégradé spéculaire (lumineuse en haut, rim
/// léger en bas) + anneau interne doux simulant l'épaisseur/le lensing du
/// bord. Tout est peint (pas de second BackdropFilter : CanvasKit applique
/// les filtres de fond au rectangle englobant, ce qui flouterait le contenu).
class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({required this.radius, this.lensing = false});

  final double radius;
  final bool lensing;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Bordure spéculaire.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.30),
        ],
        stops: const [0.0, 0.35, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.7), Radius.circular(radius - 0.7)),
      border,
    );

    if (!lensing) return;

    // Épaisseur du verre : halo interne clair qui s'éteint vers le centre,
    // plus marqué en haut (lumière) — évoque la réfraction du bord.
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.03),
          Colors.white.withValues(alpha: 0.10),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(3.5), Radius.circular(radius - 3.5)),
      inner,
    );
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) =>
      old.radius != radius || old.lensing != lensing;
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blurSigma = 12,
    this.tintOpacity = 0.38,
    this.lensing = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;

  /// Opacité du voile sombre (plus bas = plus transparent).
  final double tintOpacity;

  /// Active l'anneau de réfraction sur le pourtour (réserver à la surface
  /// primaire de la vue, ex. nav bar).
  final bool lensing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final reduceTransparency = MediaQuery.highContrastOf(context);

    if (reduceTransparency) {
      return ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TtColors.surfaceHi,
            borderRadius: radius,
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Padding(padding: padding, child: child),
        ),
      );
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Couche principale : flou + vibrance + voile + ombrage interne.
        ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: _glassBackdrop(blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: TtColors.bg.withValues(alpha: tintOpacity),
              ),
              child: DecoratedBox(
                // Modelé interne : lumière en haut, assise sombre en bas.
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0.02),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.07),
                    ],
                    stops: const [0.0, 0.30, 0.72, 1.0],
                  ),
                ),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
        // Arêtes : bordure spéculaire + épaisseur du verre (peintes).
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter:
                  _GlassEdgePainter(radius: borderRadius, lensing: lensing),
            ),
          ),
        ),
      ],
    );
  }
}

/// Enveloppe d'ombre portée à placer AUTOUR d'une GlassSurface (l'ombre ne
/// peut pas vivre dans la surface : elle serait floutée par le backdrop).
class GlassShadow extends StatelessWidget {
  const GlassShadow(
      {super.key, required this.child, this.borderRadius = 24, this.glow});

  final Widget child;
  final double borderRadius;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          if (glow != null)
            BoxShadow(
              color: glow!.withValues(alpha: 0.30),
              blurRadius: 24,
              spreadRadius: -6,
            ),
        ],
      ),
      child: child,
    );
  }
}

/// Bouton « verre » neutre (frosté).
class GlassButton extends StatefulWidget {
  const GlassButton(
      {super.key, required this.onPressed, required this.child, this.icon});

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return _PressEffect(
      enabled: enabled,
      down: _down,
      onDown: (v) => setState(() => _down = v),
      onTap: widget.onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: GlassSurface(
          borderRadius: 14,
          blurSigma: 10,
          tintOpacity: 0.16,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: _ButtonLabel(
              icon: widget.icon, color: TtColors.text, child: widget.child),
        ),
      ),
    );
  }
}

/// Bouton « verre » proéminent : capsule teintée bombée (dégradé vertical,
/// liseré spéculaire, halo doux). Texte sombre sur ambre pour le contraste.
class ProminentGlassButton extends StatefulWidget {
  const ProminentGlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.color,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final Color? color;

  @override
  State<ProminentGlassButton> createState() => _ProminentGlassButtonState();
}

class _ProminentGlassButtonState extends State<ProminentGlassButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final tint = widget.color ?? TtColors.amber;
    final onTint =
        tint.computeLuminance() > 0.5 ? const Color(0xFF1A1405) : Colors.white;
    final top = Color.lerp(tint, Colors.white, 0.22)!;
    final bottom = Color.lerp(tint, Colors.black, 0.18)!;

    return _PressEffect(
      enabled: enabled,
      down: _down,
      onDown: (v) => setState(() => _down = v),
      onTap: widget.onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, tint, bottom],
              stops: const [0.0, 0.45, 1.0],
            ),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.28), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: tint.withValues(alpha: _down ? 0.20 : 0.38),
                blurRadius: 18,
                spreadRadius: -3,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child:
              _ButtonLabel(icon: widget.icon, color: onTint, child: widget.child),
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.color, required this.child, this.icon});

  final IconData? icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = DefaultTextStyle.merge(
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
      child: child,
    );
    if (icon == null) return Center(widthFactor: 1, child: text);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        text,
      ],
    );
  }
}

/// Enfoncement au toucher (échelle + retour haptique léger), façon iOS.
class _PressEffect extends StatelessWidget {
  const _PressEffect({
    required this.child,
    required this.enabled,
    required this.down,
    required this.onDown,
    required this.onTap,
  });

  final Widget child;
  final bool enabled;
  final bool down;
  final ValueChanged<bool> onDown;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => onDown(true) : null,
      onTapCancel: enabled ? () => onDown(false) : null,
      onTap: enabled
          ? () {
              onDown(false);
              HapticFeedback.lightImpact();
              onTap?.call();
            }
          : null,
      child: AnimatedScale(
        scale: down ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}
