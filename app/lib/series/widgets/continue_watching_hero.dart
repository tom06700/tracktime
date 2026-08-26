import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../../widgets/media_image.dart';
import '../feed.dart';

/// Grande carte d'ouverture : l'épisode que l'utilisateur doit regarder
/// maintenant. C'est le seul élément de la page dimensionné pour l'image ;
/// tout le reste l'accompagne.
class ContinueWatchingHero extends StatefulWidget {
  const ContinueWatchingHero({
    super.key,
    required this.next,
    required this.onOpen,
    required this.onOpenShow,
    required this.onMarkWatched,
  });

  final NextUp next;
  final VoidCallback onOpen;
  final VoidCallback onOpenShow;

  /// Appelé une fois l'animation de validation jouée.
  final VoidCallback onMarkWatched;

  @override
  State<ContinueWatchingHero> createState() => _ContinueWatchingHeroState();
}

class _ContinueWatchingHeroState extends State<ContinueWatchingHero> {
  bool _confirmed = false;

  @override
  void didUpdateWidget(ContinueWatchingHero old) {
    super.didUpdateWidget(old);
    // Le feed a fourni l'épisode suivant : la carte reprend son état normal.
    final changed =
        old.next.show.id != widget.next.show.id ||
        old.next.season != widget.next.season ||
        old.next.episode != widget.next.episode;
    if (changed && _confirmed) _confirmed = false;
  }

  Future<void> _markWatched() async {
    if (_confirmed) return;
    HapticFeedback.lightImpact();
    setState(() => _confirmed = true);

    // Laisse la coche se dessiner avant d'écrire : le feed se recompose
    // aussitôt et remplacerait la carte au milieu de l'animation.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduceMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
    }
    widget.onMarkWatched();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.next;
    final remaining = n.remaining;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        button: true,
        label: '${n.show.name}, ${n.code}. Ouvrir l\'épisode.',
        child: GestureDetector(
          onTap: widget.onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Still d'épisode d'abord : c'est la seule image réellement
                  // horizontale. L'affiche verticale n'est qu'un repli.
                  MediaImage(
                    sources: [n.still, n.show.poster],
                    seed: n.show.name,
                    icon: Icons.tv,
                  ),
                  const MediaScrim(),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 16,
                    child: _HeroText(
                      next: n,
                      remaining: remaining,
                      onOpenShow: widget.onOpenShow,
                      confirmed: _confirmed,
                      onMarkWatched: _markWatched,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({
    required this.next,
    required this.remaining,
    required this.onOpenShow,
    required this.confirmed,
    required this.onMarkWatched,
  });

  final NextUp next;
  final int? remaining;
  final VoidCallback onOpenShow;
  final bool confirmed;
  final VoidCallback onMarkWatched;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onOpenShow,
          child: Text(
            next.show.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          [
            next.code,
            if (next.episodeName != null && next.episodeName!.isNotEmpty)
              next.episodeName,
          ].join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        if (remaining != null && remaining! > 0) ...[
          const SizedBox(height: 3),
          Text(
            '$remaining épisode${remaining! > 1 ? 's' : ''} restant'
            '${remaining! > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12.5, color: TtColors.dim),
          ),
        ],
        const SizedBox(height: 14),
        _WatchedButton(confirmed: confirmed, onTap: onMarkWatched),
      ],
    );
  }
}

/// Bouton « Vu ». À l'appui il bascule en ambre plein et la coche se dessine —
/// une confirmation immédiate, avant même que la base n'ait notifié le feed.
class _WatchedButton extends StatelessWidget {
  const _WatchedButton({required this.confirmed, required this.onTap});

  final bool confirmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Semantics(
      button: true,
      label: confirmed ? 'Épisode marqué comme vu' : 'Marquer comme vu',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          // Hauteur non contrainte : le libellé doit pouvoir grandir avec les
          // réglages d'accessibilité.
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: confirmed
                ? TtColors.amber
                : Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: confirmed
                  ? TtColors.amber
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: confirmed ? 1 : 0),
                duration: duration,
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  size: const Size(17, 17),
                  painter: _CheckPainter(
                    progress: confirmed ? t : 1,
                    color: confirmed ? TtColors.bg : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: duration,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: confirmed ? TtColors.bg : Colors.white,
                ),
                child: Text(confirmed ? 'Vu' : 'Marquer comme vu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coche tracée progressivement : le trait se dessine au lieu d'apparaître.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final w = size.width, h = size.height;
    final a = Offset(w * 0.18, h * 0.52);
    final b = Offset(w * 0.42, h * 0.76);
    final c = Offset(w * 0.84, h * 0.26);

    // Deux segments dessinés à la suite : 0 → 0.4 la descente, puis la montée.
    final path = Path()..moveTo(a.dx, a.dy);
    if (progress <= 0.4) {
      final t = progress / 0.4;
      path.lineTo(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
    } else {
      final t = (progress - 0.4) / 0.6;
      path
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx + (c.dx - b.dx) * t, b.dy + (c.dy - b.dy) * t);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
