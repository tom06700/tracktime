import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'sections.dart';

/// « Quoi regarder ce soir ? » : le projecteur balaie ta liste de lecture et
/// s'arrête au hasard sur un titre. Relance possible ; « Ouvrir la fiche »
/// pour les séries.
Future<void> showTonightPicker(BuildContext context, List<WatchItem> items) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.82),
    builder: (_) => _TonightDialog(items: items),
  );
}

class _TonightDialog extends StatefulWidget {
  const _TonightDialog({required this.items});

  final List<WatchItem> items;

  @override
  State<_TonightDialog> createState() => _TonightDialogState();
}

class _TonightDialogState extends State<_TonightDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutQuart);

  final _rnd = math.Random();
  late int _target;
  late int _spins;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _settled = true);
      }
    });
    _spin();
  }

  void _spin() {
    _settled = false;
    _target = _rnd.nextInt(widget.items.length);
    // Au moins deux tours complets avant de se poser sur la cible.
    _spins = widget.items.length * 2 + _target;
    if (widget.items.length == 1) _spins = 1;
    _c
      ..reset()
      ..forward();
    setState(() {});
  }

  int get _index {
    final raw = (_a.value * _spins).floor();
    return raw.clamp(0, _spins) % widget.items.length;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final item = widget.items[_index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lampe au-dessus.
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: TtColors.amber.withValues(alpha: 0.9),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Affiche sous le halo du projecteur.
              AnimatedScale(
                scale: _settled ? 1 : 0.94,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: TtColors.amber
                            .withValues(alpha: _settled ? 0.45 : 0.22),
                        blurRadius: 44,
                        spreadRadius: -4,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: _PickerPoster(item: item),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _settled ? item.title : 'Le projecteur choisit…',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _settled ? 18 : 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: const [
                    Shadow(color: Color(0xAA000000), blurRadius: 10)
                  ],
                ),
              ),
              const SizedBox(height: 4),
              AnimatedOpacity(
                opacity: _settled ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Text(
                  item.isMovie
                      ? 'Film · dans ta liste de lecture'
                      : 'Série · pas encore commencée',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassButton(
                    icon: Icons.casino_outlined,
                    onPressed: _settled ? _spin : null,
                    child: const Text('Relancer'),
                  ),
                  if (!item.isMovie) ...[
                    const SizedBox(width: 10),
                    ProminentGlassButton(
                      icon: Icons.arrow_forward,
                      onPressed: _settled
                          ? () {
                              Navigator.of(context).pop();
                              context.push('/show/${item.id}',
                                  extra: item.title);
                            }
                          : null,
                      child: const Text('Ouvrir'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Fermer',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PickerPoster extends StatelessWidget {
  const _PickerPoster({required this.item});

  final WatchItem item;

  static const _w = 172.0, _h = 258.0;

  @override
  Widget build(BuildContext context) {
    final hue = (item.title.codeUnits.fold<int>(0, (a, c) => a * 31 + c) % 360)
        .toDouble();
    final fallback = Container(
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.5, 0.4).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, 0.55, 0.24).toColor(),
          ],
        ),
      ),
      child: Icon(
        item.isMovie ? Icons.movie_outlined : Icons.tv,
        color: Colors.white54,
        size: 40,
      ),
    );
    final path = item.poster;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: path == null || path.isEmpty
          ? fallback
          : Image.network(
              tmdbImageUrl(path, size: 'w342'),
              width: _w,
              height: _h,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
