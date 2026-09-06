import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../motion.dart';
import '../widgets/media_image.dart';
import 'universe.dart';

const _ease = Cubic(.16, 1, .3, 1);
const _ink = Color(0xFF101113);
const _muted = Color(0xFFAAA6B1);
const _lilac = Color(0xFFCAB7FF);

/// View-only palette: do not change Universe's colors or statistical weights.
Color _color(String name) {
  final n = name.toLowerCase();
  if (n.contains('coméd') || n.contains('comed')) {
    return const Color(0xFFD4F5A0);
  }
  if (n.contains('anim')) return _lilac;
  if (n.contains('réalité') || n.contains('realit')) {
    return const Color(0xFFF3B99D);
  }
  if (n.contains('dram')) return const Color(0xFFA8C6EE);
  if (n.contains('avent') || n.contains('advent')) {
    return const Color(0xFFE5CEA0);
  }
  if (n.contains('action')) return const Color(0xFFEDAAA4);
  return Color.lerp(genreColor(name), Colors.white, .5)!;
}

class _Slice {
  _Slice(this.id, this.name, this.weight, this.color, this.poster);
  final String id, name;
  final double weight;
  final Color color;
  final String? poster;
  int percent = 0;
}

List<_Slice> _slices(Universe universe) {
  final valid =
      universe.genres.where((g) => g.weight.isFinite && g.weight > 0).toList();
  final result = [
    for (final g in valid.take(6))
      _Slice('genre:${g.name}', g.name, g.weight, _color(g.name),
          universe.posterByGenre[g.name])
  ];
  final rest = valid.skip(6).fold(0.0, (sum, g) => sum + g.weight);
  if (rest > 0) {
    result.add(_Slice('rest', 'Autres', rest, const Color(0xFFABA6B6), null));
  }
  final total = result.fold(0.0, (sum, s) => sum + s.weight);
  if (total <= 0 || !total.isFinite) return [];
  // Largest remainder rounds labels to 100 in total, without changing widths.
  for (final s in result) {
    s.percent = (s.weight / total * 100).floor();
  }
  final order = List<int>.generate(result.length, (i) => i)
    ..sort((a, b) {
      final d = (result[b].weight / total * 100 - result[b].percent)
          .compareTo(result[a].weight / total * 100 - result[a].percent);
      return d == 0 ? a.compareTo(b) : d;
    });
  final missing = 100 - result.fold<int>(0, (sum, s) => sum + s.percent);
  for (final i in order.take(missing)) {
    result[i].percent++;
  }
  return result;
}

/// Native port of validated-handoff/pellicule/reference.html. No persistence.
class GenreFilmStrip extends StatefulWidget {
  const GenreFilmStrip({super.key, required this.universe});
  final Universe universe;
  @override
  State<GenreFilmStrip> createState() => _GenreFilmStripState();
}

class _GenreFilmStripState extends State<GenreFilmStrip>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late List<_Slice> _items = _slices(widget.universe);
  late final AnimationController _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1190), value: 1);
  String? _active;
  int _previous = 0, _revision = 0;
  double _oldAngle = -20, _newAngle = -20;
  bool _reduced = false;
  int get _index => math.max(0, _items.indexWhere((s) => s.id == _active));
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = reduceMotionOf(context);
    if (_reduced || !TickerMode.valuesOf(context).enabled) {
      _motion.value = 1;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _motion.value = 1;
  }

  @override
  void didUpdateWidget(GenreFilmStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updated = _slices(widget.universe);
    final changed = updated.length != _items.length ||
        List.generate(updated.length, (i) => i).any((i) =>
            updated[i].id != _items[i].id ||
            updated[i].weight != _items[i].weight);
    _items = updated;
    if (changed) {
      _active = _items.isEmpty ? null : _items[_index].id;
      _motion.value = 1;
      _oldAngle = _newAngle = _index * 57.0 - 20;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  double get _ms => _motion.value * 1190;
  double _progress(double duration, [double delay = 0]) =>
      ((_ms - delay) / duration).clamp(0.0, 1.0);
  void _select(int index) {
    final old = _items[_index];
    final angle = ui.lerpDouble(_oldAngle, _newAngle,
        const Cubic(.2, .85, .2, 1.15).transform(_progress(800)))!;
    setState(() {
      _previous = old.percent;
      _active = _items[index].id;
      _oldAngle = angle;
      _newAngle = index * 57.0 - 20;
      _revision++;
      if (_reduced) {
        _motion.value = 1;
      } else {
        _motion.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: LayoutBuilder(builder: (context, bounds) {
          final small = bounds.maxWidth <= 360;
          return Container(
            padding: EdgeInsets.symmetric(
                horizontal: small ? 16 : 24, vertical: small ? 22 : 26),
            decoration: BoxDecoration(
                color: _ink, borderRadius: BorderRadius.circular(28)),
            child: DefaultTextStyle(
              style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFF4F1F7),
                  fontSize: 14,
                  height: 1.5),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Text('TON PROFIL DE SPECTATEUR',
                              style: TextStyle(
                                  color: _muted,
                                  fontSize: 10,
                                  letterSpacing: 1.7))),
                      const SizedBox(width: 12),
                      const ExcludeSemantics(
                          child: Text('n.',
                              style: TextStyle(
                                  color: _lilac,
                                  fontSize: 28,
                                  letterSpacing: -3,
                                  fontWeight: FontWeight.w500))),
                    ]),
                    const SizedBox(height: 24),
                    Text.rich(
                        TextSpan(text: 'Ta pellicule', children: const [
                          TextSpan(text: '.', style: TextStyle(color: _lilac))
                        ]),
                        style: TextStyle(
                            fontSize: small ? 34 : 37,
                            height: 1.1,
                            letterSpacing: -1.8,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 9),
                    const Text('Toutes les nuances de tes histoires.',
                        style:
                            TextStyle(color: Color(0xFFB4AFB9), fontSize: 13)),
                    const SizedBox(height: 29),
                    if (_items.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                              'Tes genres apparaîtront ici après tes premiers visionnages avec des genres renseignés.',
                              key: ValueKey('pellicule-empty'),
                              style: TextStyle(color: _muted)))
                    else ...[
                      AnimatedBuilder(
                          animation: _motion,
                          builder: (context, _) => _reel(small)),
                      const Padding(
                          padding: EdgeInsets.fromLTRB(1, 12, 1, 23),
                          child: Row(children: [
                            Expanded(
                                child: Text('Le temps estimé, image par image.',
                                    style: TextStyle(
                                        fontSize: 10, color: _muted))),
                            SizedBox(width: 12),
                            Text('100 %',
                                style: TextStyle(fontSize: 10, color: _muted)),
                          ])),
                      AnimatedBuilder(
                          animation: _motion,
                          builder: (context, _) => _focus()),
                      const SizedBox(height: 17),
                      LayoutBuilder(builder: (context, constraints) {
                        final oneColumn =
                            MediaQuery.textScalerOf(context).scale(12) > 18 ||
                                constraints.maxWidth < 250;
                        final width = oneColumn
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 8) / 2;
                        return Wrap(spacing: 8, runSpacing: 8, children: [
                          for (var i = 0; i < _items.length; i++)
                            SizedBox(
                                width: i == _items.length - 1 &&
                                        _items.length.isOdd
                                    ? constraints.maxWidth
                                    : width,
                                child: _GenreButton(
                                    key: ValueKey(
                                        'pellicule-genre-${_items[i].id}'),
                                    slice: _items[i],
                                    selected: i == _index,
                                    revision: _revision,
                                    reduced: _reduced,
                                    small: small,
                                    onTap: () => _select(i))),
                        ]);
                      }),
                    ],
                  ]),
            ),
          );
        }),
      ));

  Widget _reel(bool small) {
    final total = _items.fold(0.0, (sum, s) => sum + s.weight);
    final height = small ? 105.0 : 118.0;
    return DecoratedBox(
        decoration: BoxDecoration(
            color: const Color(0xFF202125),
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
          child: Column(children: [
            _holes(),
            const SizedBox(height: 16),
            SizedBox(
                height: height,
                child: LayoutBuilder(builder: (context, c) {
                  var x = 0.0;
                  final panels = <Widget>[];
                  Widget? selected;
                  for (var i = 0; i < _items.length; i++) {
                    final width = c.maxWidth * _items[i].weight / total;
                    final panel = Positioned(
                        left: x,
                        width: width,
                        top: 0,
                        height: height,
                        child: _frame(i, width));
                    if (i == _index) {
                      selected = panel;
                    } else {
                      panels.add(panel);
                    }
                    x += width;
                  }
                  return Stack(clipBehavior: Clip.none, children: [
                    ...panels,
                    ...[selected].whereType<Widget>()
                  ]);
                })),
            const SizedBox(height: 12),
            _holes(),
          ]),
        ));
  }

  Widget _holes() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
          height: 7,
          width: double.infinity,
          child: CustomPaint(
              painter: _HolesPainter(
                  _reduced ? 0 : 76 * (1 - _ease.transform(_progress(850)))))));

  Widget _frame(int index, double width) {
    final s = _items[index];
    final active = index == _index;
    final t = _progress(
        active ? 950 : 800, active ? 0 : (index - _index).abs() * 35.0);
    final y = _reduced
        ? (active ? -4.0 : 0.0)
        : active
            ? _keyframes(t, [0, .23, .55, .78, 1], [0, 4, -15, -6, -8],
                const Cubic(.2, .8, .2, 1))
            : _keyframes(
                t, [0, .3, .65, 1], [0, 5, -3, 0], const Cubic(.2, .85, .2, 1));
    final angle = _reduced
        ? 0.0
        : active
            ? _keyframes(t, [0, .23, .55, .78, 1], [0, 12, -16, -4, -7],
                const Cubic(.2, .8, .2, 1))
            : _keyframes(
                t, [0, .3, .65, 1], [0, 9, -3, 0], const Cubic(.2, .85, .2, 1));
    final transform = Matrix4.identity()
      ..setEntry(3, 2, -1 / 600)
      ..setTranslationRaw(0.0, y, 0.0)
      ..rotateX(angle * math.pi / 180);
    final image = s.poster == null
        ? CustomPaint(painter: _AbstractPainter(s.id == 'rest'))
        : Opacity(
            opacity: .8,
            child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                    active ? Colors.transparent : s.color,
                    active ? BlendMode.srcOver : BlendMode.color),
                child: Transform.scale(
                    scale:
                        active ? 1 + .12 * _ease.transform(_progress(750)) : 1,
                    child: MediaImage(sources: [s.poster], seed: s.name))));
    return Transform(
        key: ValueKey('pellicule-transform-${s.id}'),
        alignment: Alignment.bottomCenter,
        transform: transform,
        child: Semantics(
            button: true,
            selected: active,
            label: 'Sélectionner ${s.name} : ${s.percent} %',
            child: FocusableActionDetector(
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
                  _select(index);
                  return null;
                })
              },
              child: GestureDetector(
                  key: ValueKey('pellicule-segment-${s.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _select(index),
                  child: AnimatedOpacity(
                    duration: _reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 500),
                    opacity: active ? 1 : .5,
                    child: Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: active
                              ? [
                                  const BoxShadow(
                                      color: Color(0x55000000),
                                      offset: Offset(0, 12),
                                      blurRadius: 16)
                                ]
                              : null),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Stack(fit: StackFit.expand, children: [
                            ColoredBox(color: s.color),
                            image,
                            const DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                  Color(0x88000000)
                                ],
                                        stops: [
                                  0,
                                  .3,
                                  1
                                ]))),
                            if (width > 16)
                              Positioned(
                                  bottom: 7,
                                  left: 0,
                                  right: 0,
                                  child: ExcludeSemantics(
                                      child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('${s.percent}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: -.3))))),
                            if (active && !_reduced)
                              IgnorePointer(
                                  child: CustomPaint(
                                      painter:
                                          _GlintPainter(_progress(1100, 80)))),
                            if (!active)
                              const Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 2,
                                  child: ColoredBox(color: Color(0xFF202125))),
                          ])),
                    ),
                  )),
            )));
  }

  Widget _focus() {
    final s = _items[_index];
    final roll = _reduced ? 1.0 : _ease.transform(_progress(850));
    final textScale = MediaQuery.textScalerOf(context).scale(62) / 62;
    final line = 62 * 1.1 * textScale;
    final glow = _reduced
        ? 0.0
        : _keyframes(_progress(1000), [0, .3, 1], [0, .15, 0], Curves.ease);
    return Semantics(
        container: true,
        liveRegion: true,
        label: '${s.name}, ${s.percent} pour cent',
        child: ExcludeSemantics(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 183),
                  color: const Color(0xFF1E1F23),
                  child: Stack(children: [
                    Positioned.fill(
                        child: Opacity(
                            opacity: glow,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                        center: Alignment.topRight,
                                        radius: 1,
                                        colors: [
                                  s.color,
                                  Colors.transparent
                                ]))))),
                    Positioned(
                        right: -15,
                        top: 51,
                        child: Transform.rotate(
                            angle: ui.lerpDouble(
                                    _oldAngle,
                                    _newAngle,
                                    const Cubic(.2, .85, .2, 1.15)
                                        .transform(_progress(800)))! *
                                math.pi /
                                180,
                            child: AnimatedContainer(
                                duration: _reduced
                                    ? Duration.zero
                                    : const Duration(milliseconds: 600),
                                width: 116,
                                height: 116,
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        color: s.color.withValues(alpha: .12),
                                        width: 26),
                                    borderRadius: BorderRadius.circular(
                                        _index.isOdd ? 58 : 32.48))))),
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(s.name,
                                        style: TextStyle(
                                            fontSize: 14, color: s.color))),
                                const SizedBox(width: 10),
                                Text(
                                    '${(_index + 1).toString().padLeft(2, '0')} / ${_items.length.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        fontSize: 11, color: _muted))
                              ]),
                              const SizedBox(height: 12),
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Flexible(
                                        child: ClipRect(
                                            child: SizedBox(
                                                key: const ValueKey(
                                                    'pellicule-counter-window'),
                                                height: line,
                                                child: Stack(children: [
                                                  Opacity(
                                                      opacity: 0,
                                                      child: Text(
                                                          _previous
                                                                      .toString()
                                                                      .length >
                                                                  s.percent
                                                                      .toString()
                                                                      .length
                                                              ? '$_previous'
                                                              : '${s.percent}',
                                                          style: const TextStyle(
                                                              fontSize: 62,
                                                              fontFeatures: [
                                                                ui.FontFeature
                                                                    .tabularFigures()
                                                              ],
                                                              height: 1.1,
                                                              letterSpacing:
                                                                  -4))),
                                                  Positioned(
                                                      top: -line * roll,
                                                      left: 0,
                                                      child: ImageFiltered(
                                                          imageFilter: ui.ImageFilter.blur(
                                                              sigmaX: _reduced
                                                                  ? 0
                                                                  : _keyframes(
                                                                      _progress(
                                                                          850),
                                                                      [
                                                                        0,
                                                                        .3,
                                                                        1
                                                                      ],
                                                                      [0, 2, 0],
                                                                      _ease),
                                                              sigmaY: _reduced
                                                                  ? 0
                                                                  : _keyframes(
                                                                      _progress(
                                                                          850),
                                                                      [
                                                                        0,
                                                                        .3,
                                                                        1
                                                                      ],
                                                                      [0, 2, 0],
                                                                      _ease)),
                                                          child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                SizedBox(
                                                                    height:
                                                                        line,
                                                                    child: Text(
                                                                        '$_previous',
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                62,
                                                                            fontFeatures: [
                                                                              ui.FontFeature.tabularFigures()
                                                                            ],
                                                                            height:
                                                                                1.1,
                                                                            letterSpacing:
                                                                                -4))),
                                                                SizedBox(
                                                                    height:
                                                                        line,
                                                                    child: Text(
                                                                        '${s.percent}',
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                62,
                                                                            fontFeatures: [
                                                                              ui.FontFeature.tabularFigures()
                                                                            ],
                                                                            height:
                                                                                1.1,
                                                                            letterSpacing:
                                                                                -4))),
                                                              ]))),
                                                ])))),
                                    const Padding(
                                        padding:
                                            EdgeInsets.only(left: 6, bottom: 3),
                                        child: Text('%',
                                            key: ValueKey(
                                                'pellicule-percent-symbol'),
                                            style: TextStyle(
                                                fontSize: 25,
                                                height: 1.1,
                                                letterSpacing: -1,
                                                color: Color(0xFFABA7B3)))),
                                  ]),
                              const SizedBox(height: 7),
                              ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 215),
                                  child: Text(
                                      s.id == 'rest'
                                          ? 'Le reste de tes genres réunis.'
                                          : 'de ton temps de visionnage estimé',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFB7B3BF)))),
                            ])),
                  ]),
                ))));
  }
}

double _keyframes(
    double t, List<double> stops, List<double> values, Curve curve) {
  for (var i = 1; i < stops.length; i++) {
    if (t <= stops[i]) {
      return ui.lerpDouble(
          values[i - 1],
          values[i],
          curve.transform(((t - stops[i - 1]) / (stops[i] - stops[i - 1]))
              .clamp(0.0, 1.0)))!;
    }
  }
  return values.last;
}

class _GenreButton extends StatefulWidget {
  const _GenreButton(
      {super.key,
      required this.slice,
      required this.selected,
      required this.revision,
      required this.reduced,
      required this.small,
      required this.onTap});
  final _Slice slice;
  final bool selected, reduced, small;
  final int revision;
  final VoidCallback onTap;
  @override
  State<_GenreButton> createState() => _GenreButtonState();
}

class _GenreButtonState extends State<_GenreButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      value: widget.selected ? 1 : 0);
  bool _pressed = false;
  @override
  void didUpdateWidget(_GenreButton old) {
    super.didUpdateWidget(old);
    if (widget.reduced) {
      _fill.value = widget.selected ? 1 : 0;
    } else if (widget.selected != old.selected ||
        widget.revision != old.revision && widget.selected) {
      if (widget.selected) {
        _fill.forward(from: 0);
      } else {
        _fill.reverse();
      }
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: widget.selected,
      label: '${widget.slice.name}, ${widget.slice.percent} %',
      onTap: widget.onTap,
      child: ExcludeSemantics(
          child: AnimatedScale(
              scale: _pressed && !widget.reduced ? .955 : 1,
              duration: widget.reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              curve: const Cubic(.2, .8, .2, 1.3),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: AnimatedBuilder(
                      animation: _fill,
                      builder: (context, _) {
                        final t = _fill.status == AnimationStatus.reverse
                            ? 1 - _ease.transform(1 - _fill.value)
                            : _ease.transform(_fill.value);
                        final color = Color.lerp(const Color(0xFFDDD9E3),
                            const Color(0xFF25212A), t)!;
                        return Material(
                            color: const Color(0xFF1B1C20),
                            child: InkWell(
                                onTap: widget.onTap,
                                onHighlightChanged: (value) =>
                                    setState(() => _pressed = value),
                                child: Stack(children: [
                                  Positioned.fill(
                                      child: FractionalTranslation(
                                          translation: Offset(0, 1.1 * (1 - t)),
                                          child: ColoredBox(
                                              color: widget.slice.color))),
                                  ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minHeight: 54),
                                      child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: widget.small ? 12 : 14,
                                              horizontal:
                                                  widget.small ? 9 : 12),
                                          child: Row(children: [
                                            Transform.scale(
                                                scale: 1 - .3 * t,
                                                child: Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Color.lerp(
                                                            widget.slice.color,
                                                            const Color(
                                                                0xFF25212A),
                                                            t)))),
                                            SizedBox(
                                                width: widget.small ? 6 : 9),
                                            Expanded(
                                                child: Text(widget.slice.name,
                                                    style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 12,
                                                        height: 1.5,
                                                        color: color))),
                                            const SizedBox(width: 6),
                                            Text('${widget.slice.percent} %',
                                                style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 12,
                                                    color: color.withValues(
                                                        alpha: .8))),
                                          ]))),
                                ])));
                      })))));
}

class _HolesPainter extends CustomPainter {
  const _HolesPainter(this.offset);
  final double offset;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)));
    final paint = Paint()..color = const Color(0xFF0C0D0F);
    for (double x = offset % 19 - 19; x < size.width; x += 19) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 9, 7), paint);
    }
  }

  @override
  bool shouldRepaint(_HolesPainter old) => old.offset != offset;
}

class _AbstractPainter extends CustomPainter {
  const _AbstractPainter(this.rest);
  final bool rest;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, 53);
    canvas.rotate(math.pi / 6);
    if (rest) {
      for (final r in [45.0, 57.0, 69.0]) {
        canvas.drawCircle(
            Offset.zero,
            r,
            Paint()
              ..color = Colors.white.withValues(alpha: r == 45 ? .25 : .06)
              ..style = PaintingStyle.stroke
              ..strokeWidth = r == 45 ? 1 : 12);
      }
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-36, -36, 72, 72), const Radius.circular(21)),
          Paint()
            ..color = Colors.white.withValues(alpha: .25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 18);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AbstractPainter old) => old.rest != rest;
}

class _GlintPainter extends CustomPainter {
  const _GlintPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final progress = const Cubic(.2, .75, .2, 1).transform(t);
    final rect = Rect.fromLTWH(
        -size.width * .65 + size.width * 2.3 * (2 * progress - 1),
        -size.height * .25,
        size.width * 2.3,
        size.height * 1.5);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment(-1, -.36),
              end: Alignment(1, .36),
              colors: [
                Colors.transparent,
                Color(0x70FFFFFF),
                Color(0x15FFFFFF),
                Colors.transparent
              ],
              stops: [
                .35,
                .48,
                .55,
                .65
              ]).createShader(rect));
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.t != t;
}
