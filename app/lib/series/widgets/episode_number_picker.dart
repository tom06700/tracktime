import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../motion.dart';
import 'episode_number_reels.dart';
import 'episode_number_ruler.dart';
import '../../widgets/modern_controls.dart';

/// Selects an official episode without changing watch history.
Future<int?> showEpisodeNumberPicker({
  required BuildContext context,
  required int season,
  required List<int> numbers,
  required Map<int, String> names,
  AnimationController? transitionController,
}) {
  final ordered = numbers.toSet().toList()..sort();
  if (ordered.isEmpty) return Future.value();
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    transitionAnimationController: transitionController,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: ModernPalette.surface,
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: AnimationStyle(
      duration: motionOf(context, const Duration(milliseconds: 500)),
      reverseDuration: motionOf(context, const Duration(milliseconds: 300)),
    ),
    builder: (_) =>
        _EpisodeNumberSheet(season: season, numbers: ordered, names: names),
  );
}

class _EpisodeNumberSheet extends StatefulWidget {
  const _EpisodeNumberSheet({
    required this.season,
    required this.numbers,
    required this.names,
  });
  final int season;
  final List<int> numbers;
  final Map<int, String> names;

  @override
  State<_EpisodeNumberSheet> createState() => _EpisodeNumberSheetState();
}

class _EpisodeNumberSheetState extends State<_EpisodeNumberSheet> {
  late final _controller = TextEditingController(
    text: '${widget.numbers.first}',
  );
  final _focus = FocusNode();
  String? _error;
  bool _animateNumber = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  int? get _number => int.tryParse(_controller.text.trim());

  void _step(int number) {
    if (number == _number) return;
    _focus.unfocus();
    HapticFeedback.selectionClick();
    _controller.value = TextEditingValue(
      text: '$number',
      selection: TextSelection.collapsed(offset: '$number'.length),
    );
    setState(() {
      _error = null;
      _animateNumber = true;
    });
  }

  void _submit() {
    final number = _number;
    if (number == null || !widget.numbers.contains(number)) {
      setState(() => _error = 'Ce numéro n’existe pas dans cette saison.');
      return;
    }
    Navigator.pop(context, number);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final number = _number;
    final valid = widget.numbers.contains(number);
    final previous = number == null
        ? null
        : widget.numbers.where((n) => n < number).lastOrNull;
    final next = number == null
        ? null
        : widget.numbers.where((n) => n > number).firstOrNull;
    final season = widget.season == 0 ? 'Spéciaux' : 'Saison ${widget.season}';
    final count = widget.numbers.length;
    return AnimatedPadding(
      duration: motionOf(context, Motion.normal),
      curve: Motion.enter,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Choisir un épisode',
                      style: TextStyle(
                        color: ModernPalette.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Annuler',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              Text(
                '$season · $count épisode${count > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: ModernPalette.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF211E29),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ModernPalette.lilac.withValues(alpha: .18),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      _EpisodeStepButton(
                        tooltip: 'Épisode précédent',
                        onPressed: previous == null
                            ? null
                            : () => _step(previous),
                        icon: Icons.chevron_left_rounded,
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ExcludeSemantics(
                              child: Text(
                                'ÉPISODE',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.8,
                                  color: ModernPalette.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                if (!_focus.hasFocus && valid)
                                  IgnorePointer(
                                    child: EpisodeNumberReels(
                                      number: number!,
                                      animated: _animateNumber,
                                    ),
                                  ),
                                Semantics(
                                  label: 'Numéro d’épisode',
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _focus,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w600,
                                      color: _focus.hasFocus || !valid
                                          ? ModernPalette.lilac
                                          : Colors.transparent,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'N°',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                    ),
                                    onTap: () =>
                                        _controller.selection = TextSelection(
                                          baseOffset: 0,
                                          extentOffset: _controller.text.length,
                                        ),
                                    onChanged: (_) => setState(() {
                                      _error = null;
                                      _animateNumber = false;
                                    }),
                                    onSubmitted: (_) => _submit(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _EpisodeStepButton(
                        tooltip: 'Épisode suivant',
                        onPressed: next == null ? null : () => _step(next),
                        icon: Icons.chevron_right_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              EpisodeNumberRuler(
                key: const ValueKey('episode-number-ruler'),
                numbers: widget.numbers,
                selected: valid ? number! : widget.numbers.first,
                onChanged: _step,
              ),
              const SizedBox(height: 22),
              SizedBox(
                height:
                    MediaQuery.textScalerOf(context).scale(16) * 1.5 * 3 +
                    MediaQuery.textScalerOf(context).scale(12) * 1.5 * 2 +
                    8,
                child: AnimatedSwitcher(
                  duration: motionOf(
                    context,
                    const Duration(milliseconds: 200),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      ...previous.map(
                        (child) => ExcludeSemantics(child: child),
                      ),
                      ?current,
                    ],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, .05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: SizedBox(
                    key: ValueKey((number, _error)),
                    width: double.infinity,
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _error != null
                                ? 'Numéro indisponible'
                                : valid
                                ? 'Épisode $number'
                                : 'Choisis un numéro',
                            style: const TextStyle(
                              fontSize: 12,
                              color: ModernPalette.muted,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _error ??
                                (valid
                                    ? (widget.names[number] ??
                                          'Épisode $number')
                                    : 'Entre ${widget.numbers.first} et ${widget.numbers.last}'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: _error == null
                                  ? ModernPalette.text
                                  : ModernPalette.coral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: ModernPalette.lilac,
                  foregroundColor: const Color(0xFF342453),
                  minimumSize: const Size(double.infinity, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Ouvrir la fiche'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeStepButton extends StatefulWidget {
  const _EpisodeStepButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  State<_EpisodeStepButton> createState() => _EpisodeStepButtonState();
}

class _EpisodeStepButtonState extends State<_EpisodeStepButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.onPressed == null
        ? null
        : (_) => setState(() => _pressed = true),
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed && !reduceMotionOf(context) ? .88 : 1,
      duration: motionOf(context, Duration(milliseconds: _pressed ? 90 : 220)),
      curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
      child: IconButton(
        tooltip: widget.tooltip,
        onPressed: widget.onPressed,
        color: ModernPalette.lilac,
        icon: Icon(widget.icon),
      ),
    ),
  );
}
