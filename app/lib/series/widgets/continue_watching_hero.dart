import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../brand/nitrate_brand.dart';
import '../../motion.dart';
import '../../theme.dart';
import '../feed.dart';

/// Foreground of the immersive home; artwork belongs to the parent so it
/// extends behind the header and can move independently during scrolling.
class ContinueWatchingHero extends StatefulWidget {
  const ContinueWatchingHero({super.key, required this.next, required this.onOpen,
    required this.onOpenShow, required this.onMarkWatched});
  final NextUp next;
  final VoidCallback onOpen;
  final VoidCallback onOpenShow;
  final Future<void> Function() onMarkWatched;
  @override
  State<ContinueWatchingHero> createState() => _ContinueWatchingHeroState();
}

class _ContinueWatchingHeroState extends State<ContinueWatchingHero> {
  bool _saving = false;
  Future<void> _mark() async {
    if (_saving) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      await Future<void>.delayed(motionOf(context, const Duration(milliseconds: 240)));
      if (!mounted) return;
      await widget.onMarkWatched();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d’enregistrer. Réessaie.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.next;
    final width = MediaQuery.sizeOf(context).width;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: largeText ? 140 : (width * .51).clamp(150.0, 240.0)),
        EntranceFade(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(button: true, label: 'Ouvrir la série ${n.show.name}',
            child: GestureDetector(onTap: widget.onOpenShow, child: Text(n.show.name,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: NitrateBrand.display(n.show.name.length > 22 ? 44 : 58)))),
          const SizedBox(height: 10),
          Text(n.code.replaceAll(' | ', ' · '), style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w700, letterSpacing: 2.6, color: Colors.white)),
          const SizedBox(height: 3),
          Text(n.episodeName?.isNotEmpty == true ? n.episodeName! : 'Prochain épisode',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: TtColors.dim)),
        ])),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final open = FilledButton.icon(
            onPressed: widget.onOpen,
            icon: const Icon(Icons.arrow_forward_rounded, size: 21),
            label: const Text('Voir l’épisode'),
            style: FilledButton.styleFrom(backgroundColor: NitrateBrand.ivory,
              foregroundColor: NitrateBrand.ink, minimumSize: const Size(0, 50),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: const StadiumBorder()),
          );
          final watched = OutlinedButton.icon(
            onPressed: _saving ? null : _mark,
            icon: AnimatedSwitcher(duration: motionOf(context, Motion.normal),
              child: Icon(_saving ? Icons.done_all : Icons.check, key: ValueKey(_saving), size: 19)),
            label: Text(_saving ? 'Vu' : 'Marquer vu'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
              disabledForegroundColor: NitrateBrand.ivory, minimumSize: const Size(0, 50),
              backgroundColor: Colors.black.withValues(alpha: .24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              side: BorderSide(color: Colors.white.withValues(alpha: .23)), shape: const StadiumBorder()),
          );
          if (largeText || constraints.maxWidth < 325) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [open, const SizedBox(height: 10), watched]);
          }
          return Row(children: [Expanded(flex: 6, child: open), const SizedBox(width: 10), Expanded(flex: 5, child: watched)]);
        }),
      ]),
    );
  }
}
