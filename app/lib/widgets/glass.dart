import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Système « Liquid Glass » partagé (nav bar + boutons).
///
/// Principes repris de la Human Interface Guidelines d'Apple :
/// matériau translucide avec flou d'arrière-plan, reflet spéculaire discret
/// sur le bord haut, lueur de réfraction, et repli opaque quand l'utilisateur
/// a activé « Réduire la transparence » (via highContrast côté Flutter).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blurSigma = 24,
    this.tint,
    this.tintOpacity = 0.55,
    this.glow,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;

  /// Teinte du verre. `null` = verre neutre (voile clair sur le flou).
  final Color? tint;
  final double tintOpacity;

  /// Lueur colorée diffuse (réfraction / état proéminent).
  final Color? glow;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final reduceTransparency = MediaQuery.highContrastOf(context);

    // Couleur de fond du matériau.
    final base = tint == null
        ? TtColors.surface.withValues(alpha: reduceTransparency ? 1 : tintOpacity)
        : tint!.withValues(alpha: reduceTransparency ? 1 : 0.92);

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: reduceTransparency ? 0.0 : 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          if (glow != null && !reduceTransparency)
            BoxShadow(
              color: glow!.withValues(alpha: 0.4),
              blurRadius: 26,
              spreadRadius: -4,
            ),
        ],
      ),
      // Reflet spéculaire : léger dégradé clair en haut (amplitude discrète).
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: reduceTransparency
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.45],
                ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (reduceTransparency) {
      return ClipRRect(borderRadius: radius, child: content);
    }
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );
  }
}

/// Bouton « verre » neutre (frosté), façon « Glass Button ».
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  });

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
    return _PressScale(
      enabled: enabled,
      down: _down,
      onTapDown: () => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        setState(() => _down = false);
        widget.onPressed?.call();
      },
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: GlassSurface(
          borderRadius: 14,
          blurSigma: 14,
          tintOpacity: 0.10,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: _label(TtColors.text),
        ),
      ),
    );
  }

  Widget _label(Color color) {
    final text = DefaultTextStyle.merge(
      style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: color),
      child: widget.child,
    );
    if (widget.icon == null) return Center(widthFactor: 1, child: text);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: 18, color: color),
        const SizedBox(width: 8),
        text,
      ],
    );
  }
}

/// Bouton « verre » proéminent (teinté ambre + lueur), façon
/// « Prominent Glass Button ».
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

  /// Teinte (défaut : ambre de la marque).
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
    // Texte sombre sur ambre (contraste), clair sur teinte foncée (danger).
    final onTint =
        tint.computeLuminance() > 0.5 ? const Color(0xFF131313) : Colors.white;
    return _PressScale(
      enabled: enabled,
      down: _down,
      onTapDown: () => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        setState(() => _down = false);
        widget.onPressed?.call();
      },
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GlassSurface(
          borderRadius: 14,
          blurSigma: 8,
          tint: tint,
          glow: tint,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: _label(onTint),
        ),
      ),
    );
  }

  Widget _label(Color color) {
    final text = DefaultTextStyle.merge(
      style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: color),
      child: widget.child,
    );
    if (widget.icon == null) return Center(widthFactor: 1, child: text);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: 18, color: color),
        const SizedBox(width: 8),
        text,
      ],
    );
  }
}

/// Léger effet d'enfoncement (scale) au toucher, façon iOS.
class _PressScale extends StatelessWidget {
  const _PressScale({
    required this.child,
    required this.enabled,
    required this.down,
    required this.onTap,
    required this.onTapDown,
    required this.onTapCancel,
  });

  final Widget child;
  final bool enabled;
  final bool down;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => onTapDown() : null,
      onTapCancel: enabled ? onTapCancel : null,
      onTap: enabled ? onTap : null,
      child: AnimatedScale(
        scale: down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}
