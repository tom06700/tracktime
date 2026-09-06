import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../motion.dart';
import '../notifications/notification_permission.dart';
import 'notification_scene.dart';

/// The explanatory screen precedes the real OS prompt. No push is sent here.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen(
      {super.key,
      required this.onFinish,
      this.permission = const NotificationPermission()});
  final Future<void> Function() onFinish;
  final NotificationPermission permission;
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_tick);
  Duration? _previous;
  bool _active = true, _busy = false, _result = false;
  NotificationAccess? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readStatus();
  }

  Future<void> _readStatus() async {
    try {
      final value = await widget.permission.status();
      if (mounted && !_busy) {
        setState(() {
          _status = value;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && !_busy) {
        setState(() {
          _status = NotificationAccess.unavailable;
          _error = 'Impossible de vérifier la permission. Tu peux continuer.';
        });
      }
    }
  }

  void _tick(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    if (previous != null) {
      _clock.value +=
          ((elapsed - previous).inMicroseconds / 1000000).clamp(0.0, .06);
    }
  }

  void _syncMotion() {
    final run = _active &&
        !_result &&
        TickerMode.valuesOf(context).enabled &&
        !reduceMotionOf(context);
    if (run && !_ticker.isActive) {
      _previous = null;
      _ticker.start();
    }
    if (!run && _ticker.isActive) {
      _ticker.stop();
      _previous = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _syncMotion();
    if (_active && !_busy) _readStatus();
  }

  Future<void> _ask() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await widget.permission.request();
      if (mounted) {
        setState(() {
          _status = value;
          _result = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'La demande n’a pas abouti. Réessaie ou continue sans notifications.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _syncMotion();
      }
    }
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onFinish();
    } catch (_) {
      if (mounted) setState(() => _error = 'Ouverture impossible. Réessaie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settings() async {
    try {
      await widget.permission.openSettings();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Ouvre les réglages de ton appareil pour modifier cette permission.');
      }
    }
  }

  bool get _allowed =>
      _status == NotificationAccess.authorized ||
      _status == NotificationAccess.provisional;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Inter')),
        child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Expanded(
                              child: Text('nitrate',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -1.2))),
                          Text(_result ? '' : '02 / 02',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF99999F),
                                  letterSpacing: 2))
                        ]),
                        if (!_result) ...[
                          Semantics(
                              label: 'Aperçu de notifications fictives',
                              image: true,
                              child: ExcludeSemantics(
                                  child: RepaintBoundary(
                                      child: LayoutBuilder(
                                          builder: (context, c) => SizedBox(
                                              height: 352,
                                              child: OverflowBox(
                                                  maxWidth: c.maxWidth + 18,
                                                  child: SizedBox(
                                                      width: c.maxWidth + 18,
                                                      child: NotificationScene(
                                                          clock: _clock)))))))),
                          const Padding(
                              padding: EdgeInsets.only(top: 30, bottom: 18),
                              child: Text('La suite.\nSans la manquer.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 34,
                                      fontWeight: FontWeight.w400,
                                      height: 1.12,
                                      letterSpacing: -1.5))),
                          const Text(
                              'Prépare les alertes de tes séries suivies.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.7,
                                  color: Color(0xFFAAA8B1))),
                          const SizedBox(height: 13),
                          const Text('Pas de spoilers. Juste l’essentiel.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFFD1CBDC))),
                          const SizedBox(height: 12),
                          const Text(
                              'Les alertes de sortie ne sont pas encore disponibles.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  height: 1.5,
                                  color: Color(0xFF99969F))),
                          const SizedBox(height: 30),
                          _primary(
                              _allowed
                                  ? 'Continuer'
                                  : _status == NotificationAccess.denied
                                      ? 'Ouvrir les réglages'
                                      : 'Activer les notifications',
                              _allowed
                                  ? _continue
                                  : _status == NotificationAccess.denied
                                      ? _settings
                                      : _ask,
                              bell: !_allowed),
                          TextButton(
                              onPressed: _busy ? null : _continue,
                              child: const Text('Plus tard',
                                  style: TextStyle(
                                      color: Color(0xFFAAA7B1), fontSize: 13))),
                        ] else ...[
                          const SizedBox(height: 110),
                          Center(
                              child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFD4F5A0),
                                      borderRadius: BorderRadius.circular(24)),
                                  child: Icon(
                                      _allowed
                                          ? Icons.check
                                          : Icons.notifications_off_outlined,
                                      color: const Color(0xFF27371A),
                                      size: 30))),
                          const SizedBox(height: 30),
                          Text(
                              _allowed
                                  ? 'Autorisation accordée.'
                                  : 'À ton rythme.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 30,
                                  height: 1.2,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -1)),
                          const SizedBox(height: 22),
                          Text(
                              _allowed
                                  ? 'Ton choix est enregistré par ton appareil.\nLes alertes de sortie seront disponibles plus tard.'
                                  : 'Tu peux continuer sans notifications et modifier ce choix dans les réglages.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Color(0xFFAAA7B1), height: 1.7)),
                          const SizedBox(height: 70),
                          _primary('Découvrir Nitrate', _continue),
                          if (_status == NotificationAccess.denied)
                            TextButton(
                                onPressed: _settings,
                                child:
                                    const Text('Réglages des notifications')),
                        ],
                        if (_error != null)
                          Semantics(
                              liveRegion: true,
                              child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(_error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Color(0xFFD1CBDC),
                                          fontSize: 12)))),
                      ])),
            )),
      );

  Widget _primary(String label, Future<void> Function() action,
          {bool bell = false}) =>
      AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final ring = (_clock.value - 2) % 6;
            final angle =
                ring < .48 ? math.sin(ring / .48 * math.pi * 6) * .23 : 0.0;
            final sheen = ((_clock.value - 2) % 7 / 7 - .75) / .25;
            return FilledButton(
                onPressed: _busy ? null : action,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF4F3FA),
                    disabledBackgroundColor: const Color(0xFFF4F3FA),
                    foregroundColor: const Color(0xFF17151C),
                    disabledForegroundColor: const Color(0xFF17151C),
                    minimumSize: const Size(0, 59),
                    padding: EdgeInsets.zero),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          child: Row(children: [
                            if (bell) ...[
                              Transform.rotate(
                                  angle: reduceMotionOf(context) ? 0 : angle,
                                  alignment: Alignment.topCenter,
                                  child: const Icon(
                                      Icons.notifications_none_rounded,
                                      size: 18)),
                              const SizedBox(width: 11)
                            ],
                            Expanded(
                                child: Text(_busy ? 'Un instant…' : label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500))),
                            const SizedBox(width: 8),
                            const Icon(Icons.north_east, size: 19),
                          ])),
                      if (!reduceMotionOf(context) && sheen > 0)
                        Positioned.fill(
                            child: IgnorePointer(
                                child: FractionalTranslation(
                                    translation: Offset(-1.3 + sheen * 3, 0),
                                    child: const DecoratedBox(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                      Colors.transparent,
                                      Color(0x44D8CCE7),
                                      Colors.transparent
                                    ])))))),
                    ])));
          });
}
