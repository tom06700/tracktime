import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../motion.dart';

abstract final class ModernPalette {
  static const background = Color(0xFF101113);
  static const surface = Color(0xFF1A1B1F);
  static const lime = Color(0xFFD4F5A0);
  static const lilac = Color(0xFFCAB7FF);
  static const peach = Color(0xFFF3B99D);
  static const coral = Color(0xFFFF9989);
  static const text = Color(0xFFF2F3F5);
  static const muted = Color(0xFFA6A7AE);
}

enum CommandShape { softCheck, attach, nextUp, surprise }

/// Four authored families, sharing native focus, semantics and async handling.
/// Selected state belongs to real application data, never a demo toggle.
class ModernCommand extends StatefulWidget {
  const ModernCommand(
      {super.key,
      required this.shape,
      required this.label,
      required this.onPressed,
      this.selected = false,
      this.subtitle,
      this.eyebrow,
      this.labelSize,
      this.compact = false,
      this.height,
      this.subtitleAbove = false});
  final CommandShape shape;
  final String label;
  final String? subtitle;
  final String? eyebrow;
  final double? labelSize;
  final FutureOr<void> Function()? onPressed;
  final bool selected, compact;
  final double? height;
  final bool subtitleAbove;
  @override
  State<ModernCommand> createState() => _ModernCommandState();
}

class _ModernCommandState extends State<ModernCommand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: widget.selected ? 1 : 0);
  bool _busy = false;
  @override
  void didUpdateWidget(ModernCommand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      if (reduceMotionOf(context)) {
        _motion.value = widget.selected ? 1 : 0;
      } else {
        widget.selected ? _motion.forward() : _motion.reverse();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _motion.stop();
      _motion.value = widget.selected ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _press() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      if (widget.shape == CommandShape.nextUp ||
          widget.shape == CommandShape.surprise) {
        _motion.duration = Duration(
            milliseconds: widget.shape == CommandShape.surprise ? 1000 : 700);
        if (!reduceMotionOf(context)) {
          _motion.forward(from: 0);
          await Future<void>.delayed(Duration(
              milliseconds: widget.shape == CommandShape.nextUp ? 280 : 1000));
        }
      }
      if (mounted) await widget.onPressed!();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Impossible d’enregistrer. Réessaie.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final check = widget.shape == CommandShape.softCheck;
    final attach = widget.shape == CommandShape.attach;
    final next = widget.shape == CommandShape.nextUp;
    final iconOnly = attach && widget.label.isEmpty;
    final color = check
        ? const Color(0xFF30332E)
        : attach
            ? ModernPalette.lilac
            : next
                ? const Color(0xFFE9ECF3)
                : ModernPalette.coral;
    final foreground = check
        ? const Color(0xFFE9F3DE)
        : attach
            ? const Color(0xFF342453)
            : next
                ? const Color(0xFF272C37)
                : const Color(0xFF592D28);
    final height = widget.height ??
        (widget.compact
            ? 56.0
            : check
                ? 72.0
                : attach
                    ? 74.0
                    : 82.0);
    final orb = widget.height != null
        ? height - 16
        : widget.compact
            ? 41.0
            : 54.0;
    return AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final raw = _motion.value;
          final t = const Cubic(.2, .85, .25, 1).transform(raw);
          final elastic = Curves.easeOutBack.transform(raw);
          final done = widget.selected;
          final textColor =
              check && done ? const Color(0xFF26371B) : foreground;
          Widget face = FilledButton(
            onPressed: _busy || widget.onPressed == null ? null : _press,
            style: FilledButton.styleFrom(
              backgroundColor: attach && !iconOnly ? Colors.transparent : color,
              disabledBackgroundColor:
                  attach && !iconOnly ? Colors.transparent : color,
              foregroundColor: textColor,
              disabledForegroundColor: textColor,
              minimumSize: Size(0, height),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(check ? 40 : 26)),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(check ? 40 : 26),
                child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: Stack(alignment: Alignment.center, children: [
                      if (check)
                        Positioned(
                            left: -100,
                            top: -140,
                            child: Transform.scale(
                                scale: 1.6 * t,
                                child: Container(
                                    width: 380,
                                    height: 380,
                                    decoration: const BoxDecoration(
                                        color: ModernPalette.lime,
                                        shape: BoxShape.circle)))),
                      if (attach && !iconOnly)
                        Positioned.fill(
                            child: LayoutBuilder(
                                builder: (context, c) => Stack(children: [
                                      Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: math.max(
                                              0,
                                              c.maxWidth -
                                                  (widget.compact ? 48 : 80) +
                                                  (widget.compact ? 25 : 46) *
                                                      t),
                                          child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                  color: ModernPalette.lilac,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          26)))),
                                      Positioned(
                                          right: 8 * t,
                                          top: 7 * t,
                                          bottom: 7 * t,
                                          width: (widget.compact ? 42 : 66) -
                                              6 * t,
                                          child: Transform.rotate(
                                              angle: 2 * math.pi * elastic,
                                              child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                      color: Color.lerp(
                                                          ModernPalette.lilac,
                                                          const Color(
                                                              0xFFB39AE9),
                                                          t),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              26 + 4 * t)),
                                                  child: Icon(
                                                      done
                                                          ? Icons.check
                                                          : Icons.add,
                                                      size: 25,
                                                      color: foreground)))),
                                    ]))),
                      if (iconOnly)
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: Transform.rotate(
                                angle: 2 * math.pi * elastic,
                                child: Icon(
                                    done
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    size: 22,
                                    color: foreground)))
                      else
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: check ? 7 : 13, vertical: 8),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (check) ...[
                                    Transform.rotate(
                                        angle: elastic * math.pi * 2,
                                        child: Container(
                                            width: orb,
                                            height: orb,
                                            decoration: BoxDecoration(
                                                color: Color.lerp(
                                                    ModernPalette.lime,
                                                    const Color(0xFFB4DC81),
                                                    t),
                                                shape: BoxShape.circle),
                                            child: Center(
                                                child: _busy && !done
                                                    ? const SizedBox(
                                                        width: 17,
                                                        height: 17,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Color(
                                                                    0xFF455E33)))
                                                    : Icon(
                                                        done
                                                            ? Icons.check
                                                            : Icons
                                                                .circle_outlined,
                                                        color: const Color(
                                                            0xFF455E33),
                                                        size:
                                                            done ? 23 : 20)))),
                                    const SizedBox(width: 9),
                                  ],
                                  if (widget.shape ==
                                      CommandShape.surprise) ...[
                                    Transform.rotate(
                                        angle: raw * math.pi * 2,
                                        child: Transform.scale(
                                            scale: 1 -
                                                math.sin(raw * math.pi * 2) *
                                                    .18,
                                            child: const SizedBox(
                                                width: 53,
                                                height: 53,
                                                child: CustomPaint(
                                                    painter:
                                                        _FlowerPainter())))),
                                    const SizedBox(width: 13),
                                  ],
                                  Expanded(
                                      child: Padding(
                                          padding: EdgeInsets.only(
                                              right: attach
                                                  ? (widget.compact ? 36 : 66)
                                                  : 0),
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: attach
                                                  ? CrossAxisAlignment.center
                                                  : CrossAxisAlignment.start,
                                              children: [
                                                if (widget.eyebrow != null) ...[
                                                  Text(widget.eyebrow!,
                                                      style: TextStyle(
                                                          fontSize: 9,
                                                          letterSpacing: 1.5,
                                                          color: foreground
                                                              .withValues(
                                                                  alpha: .7))),
                                                  const SizedBox(height: 5),
                                                ],
                                                if (widget.subtitle != null &&
                                                    widget.subtitleAbove) ...[
                                                  Text(widget.subtitle!,
                                                      style: TextStyle(
                                                          fontSize: 9,
                                                          letterSpacing: 1.4,
                                                          color: foreground
                                                              .withValues(
                                                                  alpha: .7))),
                                                  const SizedBox(height: 2),
                                                ],
                                                Text(
                                                    _busy && !check
                                                        ? 'Un instant…'
                                                        : widget.label,
                                                    style: TextStyle(
                                                        fontSize:
                                                            widget.labelSize ??
                                                                (widget.compact
                                                                    ? 13
                                                                    : 15),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: textColor)),
                                                if (widget.subtitle != null &&
                                                    !widget.subtitleAbove) ...[
                                                  const SizedBox(height: 5),
                                                  Text(widget.subtitle!,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: foreground
                                                              .withValues(
                                                                  alpha: .7)))
                                                ],
                                              ]))),
                                  if (check && !widget.compact)
                                    Opacity(
                                        opacity: 1 - t,
                                        child: const Padding(
                                            padding: EdgeInsets.only(right: 12),
                                            child: Icon(Icons.north_east,
                                                size: 15,
                                                color: Color(0xFFBCCDAF)))),
                                  if (!attach && !check)
                                    Container(
                                        width: widget.compact ? 28 : 39,
                                        height: widget.compact ? 28 : 39,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: next
                                                ? const Color(0xFFCDD6EB)
                                                : Colors.transparent),
                                        child: Icon(Icons.north_east,
                                            size: widget.compact ? 17 : 22)),
                                ])),
                    ]))),
          );
          if (next && !widget.compact) {
            final dx = raw < .39 ? raw / .38 * 38 : 0.0;
            final dy = raw >= .39 ? -15 * (1 - (raw - .39) / .61) : 0.0;
            face = Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                  top: -13,
                  bottom: 13,
                  child: FractionallySizedBox(
                      widthFactor: .86,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: const Color(0xFF33353E),
                              borderRadius: BorderRadius.circular(25))))),
              Positioned.fill(
                  top: -7,
                  bottom: 7,
                  child: FractionallySizedBox(
                      widthFactor: .94,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: const Color(0xFF626774),
                              borderRadius: BorderRadius.circular(25))))),
              Transform.translate(offset: Offset(dx, dy), child: face),
            ]);
          }
          return MergeSemantics(
              child: Semantics(
                  selected: (check || attach) ? widget.selected : null,
                  child: face));
        });
  }
}

class _FlowerPainter extends CustomPainter {
  const _FlowerPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 53);
    canvas.translate(26.5, 26.5);
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 2);
      canvas.drawCircle(const Offset(-7.5, -7.5), 13,
          Paint()..color = const Color(0xFFA7473D));
      canvas.restore();
    }
    canvas.drawCircle(
        Offset.zero, 6.5, Paint()..color = const Color(0xFFFFC7AD));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlowerPainter oldDelegate) => false;
}

/// Shared sliding capsule. Selection is supplied by the tab/filter controller.
class GlideControl extends StatelessWidget {
  const GlideControl(
      {super.key,
      required this.labels,
      required this.index,
      required this.onSelected,
      this.navigation = false,
      this.dense = false,
      this.icons});
  final List<String> labels;
  final List<IconData>? icons;
  final int index;
  final ValueChanged<int> onSelected;
  final bool navigation, dense;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final height = (navigation
                ? 67.0
                : dense
                    ? 44.0
                    : 60.0) +
            (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0.0, 30.0);
        final width = (constraints.maxWidth - 12) / labels.length;
        return DecoratedBox(
            decoration: BoxDecoration(
                color: const Color(0xFF2B2C33),
                borderRadius: BorderRadius.circular(navigation ? 28 : 40)),
            child: Padding(
                padding: const EdgeInsets.all(6),
                child: SizedBox(
                    height: height,
                    child: Stack(clipBehavior: Clip.none, children: [
                      AnimatedPositioned(
                          duration: motionOf(context,
                              Duration(milliseconds: navigation ? 650 : 700)),
                          // Translation stays inside the track, including jumps
                          // between the first and last tabs.
                          curve: const Cubic(.22, 1, .3, 1),
                          left: index * width,
                          top: 0,
                          bottom: 0,
                          width: width,
                          child: DecoratedBox(
                              key: const ValueKey('glide-capsule'),
                              decoration: BoxDecoration(
                                  color: navigation
                                      ? const Color(0xFFE7EBF2)
                                      : ModernPalette.peach,
                                  borderRadius: BorderRadius.circular(navigation
                                      ? 22
                                      : dense
                                          ? 21
                                          : 35)))),
                      Row(
                          children: List.generate(
                              labels.length,
                              (i) => Expanded(
                                      child: MergeSemantics(
                                          child: Semantics(
                                    selected: index == i,
                                    inMutuallyExclusiveGroup: true,
                                    child: TextButton(
                                        onPressed: () {
                                          if (index != i) onSelected(i);
                                        },
                                        style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 3),
                                            minimumSize: Size(width, height),
                                            foregroundColor: index == i
                                                ? const Color(0xFF282D39)
                                                : const Color(0xFFB6B8C1)),
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (icons != null) ...[
                                                AnimatedRotation(
                                                    turns: i == index
                                                        ? -7 / 360
                                                        : 0,
                                                    duration: motionOf(
                                                        context,
                                                        const Duration(
                                                            milliseconds: 400)),
                                                    child: Icon(icons![i],
                                                        size: 21)),
                                                const SizedBox(height: 6)
                                              ],
                                              Text(labels[i],
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize:
                                                          navigation ? 11 : 14,
                                                      fontWeight:
                                                          FontWeight.w500)),
                                            ])),
                                  ))))),
                    ]))));
      });
}
