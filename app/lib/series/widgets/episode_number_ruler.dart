import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../motion.dart';
import '../../widgets/modern_controls.dart';

/// A lazy ruler indexed by official episodes, not by the numerical range.
class EpisodeNumberRuler extends StatefulWidget {
  const EpisodeNumberRuler({
    super.key,
    required this.numbers,
    required this.selected,
    required this.onChanged,
  });
  final List<int> numbers;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  State<EpisodeNumberRuler> createState() => _EpisodeNumberRulerState();
}

class _EpisodeNumberRulerState extends State<EpisodeNumberRuler> {
  ScrollController? _scroll;
  double _extent = 32;
  int _reported = 0, _generation = 0;
  bool _programmatic = false;
  int get _index => widget.numbers
      .indexOf(widget.selected)
      .clamp(0, widget.numbers.length - 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extent = math.max(
      32.0,
      MediaQuery.textScalerOf(context).scale(10) *
              '${widget.numbers.last}'.length *
              .65 +
          16,
    );
    if (_scroll == null) {
      _extent = extent;
      _reported = _index;
      _scroll = ScrollController(initialScrollOffset: _index * extent)
        ..addListener(_onScroll);
    } else if (_extent != extent) {
      _extent = extent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveToSelection(jump: true);
      });
    }
  }

  void _onScroll() {
    if (_programmatic || !_scroll!.hasClients) return;
    final index = (_scroll!.offset / _extent).round().clamp(
      0,
      widget.numbers.length - 1,
    );
    if (index == _reported) return;
    _reported = index;
    widget.onChanged(widget.numbers[index]);
  }

  void _moveToSelection({bool jump = false}) {
    if (!_scroll!.hasClients) return;
    final target = _index * _extent;
    if ((_scroll!.offset - target).abs() < .1) return;
    final generation = ++_generation;
    _programmatic = true;
    _reported = _index;
    if (jump || reduceMotionOf(context)) {
      _scroll!.jumpTo(target);
      _programmatic = false;
    } else {
      _scroll!
          .animateTo(
            target,
            duration: const Duration(milliseconds: 340),
            curve: Motion.enter,
          )
          .whenComplete(() {
            if (mounted && generation == _generation) _programmatic = false;
          });
    }
  }

  @override
  void didUpdateWidget(EpisodeNumberRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected && _index != _reported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveToSelection();
      });
    }
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    final height = 28 + MediaQuery.textScalerOf(context).scale(10) * 1.5;
    return Semantics(
      label: 'Choisir un épisode en glissant',
      value: 'Épisode ${widget.selected}',
      slider: true,
      increasedValue: index < widget.numbers.length - 1
          ? 'Épisode ${widget.numbers[index + 1]}'
          : null,
      decreasedValue: index > 0 ? 'Épisode ${widget.numbers[index - 1]}' : null,
      onIncrease: index < widget.numbers.length - 1
          ? () => widget.onChanged(widget.numbers[index + 1])
          : null,
      onDecrease: index > 0
          ? () => widget.onChanged(widget.numbers[index - 1])
          : null,
      child: ExcludeSemantics(
        child: SizedBox(
          height: math.max(48, height),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              alignment: Alignment.topCenter,
              children: [
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0, .16, .84, 1],
                  ).createShader(rect),
                  child: NotificationListener<ScrollStartNotification>(
                    onNotification: (notification) {
                      if (notification.dragDetails != null) {
                        _generation++;
                        _programmatic = false;
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: _EpisodeSnapPhysics(
                        extent: _extent,
                        parent: const BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: math.max(
                          0,
                          (constraints.maxWidth - _extent) / 2,
                        ),
                      ),
                      itemExtent: _extent,
                      itemCount: widget.numbers.length,
                      itemBuilder: (context, i) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onChanged(widget.numbers[i]),
                        child: Column(
                          children: [
                            const SizedBox(height: 6),
                            Container(
                              width: 1,
                              height: 12,
                              color: i == index
                                  ? ModernPalette.lilac
                                  : const Color(0xFF625B6C),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '${widget.numbers[i]}',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                color: i == index
                                    ? ModernPalette.lilac
                                    : ModernPalette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    width: 2,
                    height: 20,
                    decoration: BoxDecoration(
                      color: ModernPalette.lilac,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeSnapPhysics extends ScrollPhysics {
  const _EpisodeSnapPhysics({required this.extent, super.parent});
  final double extent;
  @override
  _EpisodeSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _EpisodeSnapPhysics(extent: extent, parent: buildParent(ancestor));
  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final projected =
        position.pixels + (velocity * .06).clamp(-extent * 8, extent * 8);
    final target = ((projected / extent).round() * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < .1 && velocity.abs() < 1) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}
