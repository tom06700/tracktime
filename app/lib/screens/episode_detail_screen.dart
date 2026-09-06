import 'dart:ui' as ui;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../db/database.dart';
import '../db/episode_catch_up.dart';
import '../motion.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../series/sync.dart';
import '../tmdb/add.dart';
import '../widgets/common.dart';
import '../widgets/media_image.dart';
import '../widgets/modern_controls.dart';
import '../widgets/states.dart';

/// Pack 03: one catalogue load, a lazy season carousel and explicit watch writes.
class EpisodeSheet extends ConsumerStatefulWidget {
  const EpisodeSheet(
      {super.key,
      required this.showId,
      required this.showName,
      required this.season,
      required this.initialEpisode,
      this.posterPath});
  final int showId, season, initialEpisode;
  final String showName;
  final String? posterPath;
  @override
  ConsumerState<EpisodeSheet> createState() => _EpisodeSheetState();
}

class _EpisodeSheetState extends ConsumerState<EpisodeSheet>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>>? _episodes;
  PageController? _pages;
  int _current = 0;
  bool _busy = false;
  String? _error;
  CatchUpReceipt? _receipt;
  double _offset = 0;
  late final AnimationController _drag =
      AnimationController.unbounded(vsync: this)
        ..addListener(() {
          if (mounted) setState(() => _offset = _drag.value);
        });
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pages?.dispose();
    _drag.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all =
          await ref.read(tvdbClientProvider).seriesEpisodes(widget.showId);
      final byNumber = <int, Map<String, dynamic>>{};
      for (final e in all) {
        if (e['season'] == widget.season && e['episode'] is int) {
          byNumber[e['episode'] as int] = e;
        }
      }
      final numbers = byNumber.keys.toList()..sort();
      if (numbers.isEmpty || !byNumber.containsKey(widget.initialEpisode)) {
        throw StateError('Épisode absent du catalogue');
      }
      final db = ref.read(databaseProvider);
      if (await db.showById(widget.showId) != null) {
        await db.upsertEpisodes([
          for (final n in numbers)
            EpisodesCompanion.insert(
                showId: widget.showId,
                season: widget.season,
                episode: n,
                name: Value(byNumber[n]!['name'] as String?),
                still: Value(byNumber[n]!['image'] as String?),
                airDate:
                    Value(DateTime.tryParse('${byNumber[n]!['aired'] ?? ''}')))
        ]);
      }
      if (!mounted) return;
      _pages?.dispose();
      _current = numbers.indexOf(widget.initialEpisode);
      setState(() {
        _episodes = [for (final n in numbers) byNumber[n]!];
        _pages = PageController(initialPage: _current);
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Impossible de charger les épisodes de cette saison.');
      }
    }
  }

  Future<void> _select(int index) async {
    if (_busy || _pages == null || index < 0 || index >= _episodes!.length) {
      return;
    }
    if ((index - _current).abs() > 1 || reduceMotionOf(context)) {
      _pages!.jumpToPage(index);
    } else {
      await _pages!.animateToPage(index,
          duration: const Duration(milliseconds: 500),
          curve: const Cubic(.2, .8, .3, 1));
    }
  }

  void _endDrag(DragEndDetails details) {
    if (_busy) return;
    final dismiss = _offset > MediaQuery.sizeOf(context).height * .16 ||
        (details.primaryVelocity ?? 0) > 700;
    _drag.value = _offset;
    if (dismiss) {
      _drag
          .animateTo(MediaQuery.sizeOf(context).height,
              duration: motionOf(context, const Duration(milliseconds: 200)),
              curve: Curves.easeIn)
          .then((_) {
        if (mounted) context.pop();
      });
    } else {
      _drag.animateTo(0,
          duration: motionOf(context, const Duration(milliseconds: 300)),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on CatchUpChanged {
      _message('La progression a changé. Vérifie et confirme à nouveau.');
    } catch (_) {
      _message('Impossible de modifier la progression. Réessaie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _toggle(int number, bool watched) => _run(() async {
        final db = ref.read(databaseProvider);
        if (watched) {
          await db.setEpisodeUnwatched(widget.showId, widget.season, number);
        } else {
          // Preserve the existing episode-screen behaviour: watching follows a show.
          await addShowFromTvdb(db, ref.read(tvdbClientProvider), widget.showId,
              preferredName: widget.showName);
          if (!mounted) return;
          await db.setEpisodeWatched(widget.showId, widget.season, number);
        }
        if (mounted) HapticFeedback.lightImpact();
      });

  Future<void> _catchUp(int number) => _run(() async {
        final db = ref.read(databaseProvider);
        final tvdb = ref.read(tvdbClientProvider);
        await addShowFromTvdb(db, tvdb, widget.showId,
            preferredName: widget.showName);
        final show = await db.showById(widget.showId);
        if (show == null || !mounted) return;
        await syncShowEpisodes(db, tvdb, show);
        final service = EpisodeCatchUp(db);
        final plan =
            await service.prepare(widget.showId, widget.season, number);
        if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
        if (plan.keys.isEmpty) {
          _message('Tous ces épisodes sont déjà vus.');
          return;
        }
        final specials = plan.keys.any((e) => e.season == 0);
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF19191F),
                    title: const Text('Tout marquer jusqu’ici ?'),
                    content: SingleChildScrollView(
                        child: Text(
                            '${plan.keys.length} épisodes non vus, jusqu’à S${widget.season} · E$number inclus. '
                            'Cette action inclut les saisons précédentes connues'
                            '${specials ? ', y compris les spéciaux en saison 0' : ''}. '
                            'Les anciennes dates de visionnage sont conservées.')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Annuler')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Confirmer'))
                    ]));
        if (confirmed != true || !mounted) return;
        final receipt = await service.apply(plan);
        if (mounted) setState(() => _receipt = receipt);
      });

  Future<void> _undo() => _run(() async {
        final receipt = _receipt;
        if (receipt == null) return;
        final removed =
            await EpisodeCatchUp(ref.read(databaseProvider)).undo(receipt);
        if (mounted) setState(() => _receipt = null);
        _message('$removed visionnages du rattrapage annulés.');
      });

  Future<void> _all() async {
    if (_busy) return;
    final index = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF19191F),
        builder: (_) => _EpisodePicker(
            showId: widget.showId,
            season: widget.season,
            episodes: _episodes!,
            current: _current));
    if (mounted && index != null) await _select(index);
  }

  @override
  Widget build(BuildContext context) {
    final keys =
        ref.watch(watchedKeysProvider(widget.showId)).value ?? <String>{};
    return PopScope(
        canPop: !_busy,
        child: SafeArea(
            bottom: false,
            child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                    heightFactor: .96,
                    child: Transform.translate(
                        offset: Offset(0, _offset),
                        child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(31)),
                            child: Material(
                                color: ModernPalette.background,
                                child: Stack(children: [
                                  if (_error != null)
                                    ErrorRetry(
                                        title: 'Épisode indisponible',
                                        message: _error!,
                                        onRetry: () {
                                          setState(() => _error = null);
                                          _load();
                                        })
                                  else if (_episodes == null)
                                    const Center(
                                        child: CircularProgressIndicator())
                                  else
                                    PageView.builder(
                                        controller: _pages,
                                        physics: _busy
                                            ? const NeverScrollableScrollPhysics()
                                            : null,
                                        itemCount: _episodes!.length,
                                        onPageChanged: (i) {
                                          setState(() => _current = i);
                                          HapticFeedback.selectionClick();
                                        },
                                        itemBuilder: (_, i) => _EpisodePage(
                                            key: ValueKey(
                                                'episode-${_episodes![i]['episode']}'),
                                            showId: widget.showId,
                                            showName: widget.showName,
                                            season: widget.season,
                                            data: _episodes![i],
                                            position: i + 1,
                                            total: _episodes!.length,
                                            seen: _episodes!
                                                .where((e) => keys.contains(
                                                    'S${widget.season}E${e['episode']}'))
                                                .length,
                                            posterPath: widget.posterPath,
                                            busy: _busy,
                                            active: i == _current,
                                            receipt: _receipt,
                                            onUndo: _undo,
                                            previous: i > 0
                                                ? () => _select(i - 1)
                                                : null,
                                            next: i + 1 < _episodes!.length
                                                ? () => _select(i + 1)
                                                : null,
                                            nextNumber:
                                                i + 1 < _episodes!.length
                                                    ? _episodes![i + 1]
                                                        ['episode'] as int
                                                    : null,
                                            onAll: _all,
                                            onToggle: (watched) => _toggle(
                                                _episodes![i]['episode'] as int,
                                                watched),
                                            onCatchUp: () => _catchUp(
                                                _episodes![i]['episode']
                                                    as int),
                                            onDragStart: (_) {
                                              if (!_busy) _drag.stop();
                                            },
                                            onDragUpdate: (d) {
                                              if (!_busy) {
                                                setState(() => _offset =
                                                    (_offset + d.delta.dy)
                                                        .clamp(0.0,
                                                            double.infinity));
                                              }
                                            },
                                            onDragEnd: _endDrag)),
                                  Positioned(
                                      top: 15,
                                      right: 14,
                                      child: IconButton.filledTonal(
                                          tooltip: 'Fermer la fiche épisode',
                                          onPressed: _busy
                                              ? null
                                              : () => context.pop(),
                                          icon: const Icon(Icons.close))),
                                ]))))))));
  }
}

class _EpisodePage extends ConsumerStatefulWidget {
  const _EpisodePage(
      {super.key,
      required this.showId,
      required this.showName,
      required this.season,
      required this.data,
      required this.position,
      required this.total,
      required this.seen,
      required this.busy,
      required this.active,
      required this.onToggle,
      required this.onCatchUp,
      required this.onAll,
      required this.previous,
      required this.next,
      required this.nextNumber,
      required this.receipt,
      required this.onUndo,
      required this.onDragStart,
      required this.onDragUpdate,
      required this.onDragEnd,
      this.posterPath});
  final int showId, season, position, total, seen;
  final int? nextNumber;
  final String showName;
  final String? posterPath;
  final Map<String, dynamic> data;
  final bool busy, active;
  final CatchUpReceipt? receipt;
  final Future<void> Function(bool) onToggle;
  final Future<void> Function() onCatchUp, onAll, onUndo;
  final Future<void> Function()? previous, next;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  @override
  ConsumerState<_EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends ConsumerState<_EpisodePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confirmation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) _confirmation.value = 0;
  }

  bool _revealed = false;
  @override
  void didUpdateWidget(_EpisodePage old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.data['episode'] as int;
    final watched = ref
        .watch(watchedEpisodeProvider(
            (showId: widget.showId, season: widget.season, episode: number)))
        .value;
    ref.listen(
        watchedEpisodeProvider(
            (showId: widget.showId, season: widget.season, episode: number)),
        (before, after) {
      if (before != null &&
          before.hasValue &&
          before.value == null &&
          after.value != null &&
          !reduceMotionOf(context)) {
        _confirmation.forward(from: 0);
      }
    });
    final overview = '${widget.data['overview'] ?? ''}'.trim();
    final title = '${widget.data['name'] ?? ''}'.trim();
    final air = DateTime.tryParse('${widget.data['aired'] ?? ''}');
    final runtime = (widget.data['runtime'] as num?)?.toInt();
    final small = MediaQuery.sizeOf(context).width < 370;
    final gap = small ? 18.0 : 24.0;
    return TickerMode(
        enabled: widget.active,
        child: ListView(
            key: PageStorageKey('episode-scroll-$number'),
            padding: EdgeInsets.zero,
            children: [
              GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: widget.onDragStart,
                  onVerticalDragUpdate: widget.onDragUpdate,
                  onVerticalDragEnd: widget.onDragEnd,
                  child: SizedBox(
                      height: small ? 242 : 278,
                      child: Stack(fit: StackFit.expand, children: [
                        TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: motionOf(
                                context, const Duration(milliseconds: 500)),
                            curve: const Cubic(.2, .8, .3, 1),
                            builder: (_, t, child) => Transform.scale(
                                scale: 1.13 - .09 * t,
                                child: Transform.translate(
                                    offset: Offset(12 * (1 - t), 0),
                                    child: child)),
                            child: MediaImage(sources: [
                              widget.data['image'] as String?,
                              widget.posterPath
                            ], seed: widget.showName, icon: Icons.tv)),
                        const DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                              Color(0x66000000),
                              Colors.transparent,
                              ModernPalette.background
                            ],
                                    stops: [
                              0,
                              .35,
                              1
                            ]))),
                        Positioned.fill(
                            child: IgnorePointer(
                                child: ExcludeSemantics(
                                    child: CustomPaint(
                                        painter: _WatchFlash(_confirmation))))),
                        Positioned(
                            left: gap,
                            top: 19,
                            right: 76,
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                    onPressed: widget.busy
                                        ? null
                                        : () => context.push(
                                            '/show/${widget.showId}',
                                            extra: widget.showName),
                                    style: TextButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xD9131418),
                                        foregroundColor: ModernPalette.text),
                                    child: Text('${widget.showName} ↗',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)))),
                        Positioned(
                            left: gap,
                            right: gap,
                            bottom: 20,
                            child: LayoutBuilder(
                                builder: (context, c) => Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 14,
                                        runSpacing: 10,
                                        children: [
                                          ConstrainedBox(
                                              constraints: BoxConstraints(
                                                  maxWidth: c.maxWidth),
                                              child: Text(
                                                  widget.showName.toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      letterSpacing: 2))),
                                          Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 13,
                                                      vertical: 9),
                                              decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xD9101113),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          17)),
                                              child: Text('ÉP. $number',
                                                  style: TextStyle(
                                                      fontSize: small ? 21 : 24,
                                                      letterSpacing: -.7,
                                                      fontFeatures: const [
                                                        ui.FontFeature
                                                            .tabularFigures()
                                                      ]))),
                                        ]))),
                      ]))),
              Padding(
                  padding: EdgeInsets.fromLTRB(
                      gap, 4, gap, 24 + MediaQuery.paddingOf(context).bottom),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runSpacing: 8,
                            children: [
                              Text(
                                  runtime != null && runtime > 0
                                      ? '$runtime MIN'
                                      : 'DURÉE NON RENSEIGNÉE',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                      color: ModernPalette.muted)),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF2A2533),
                                      borderRadius: BorderRadius.circular(15)),
                                  child: Text(watched == null ? 'À voir' : 'Vu',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFFD5C5F5))))
                            ]),
                        const SizedBox(height: 18),
                        Text(
                            'SAISON ${widget.season} · ${widget.position} sur ${widget.total}',
                            style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.4,
                                color: ModernPalette.muted)),
                        const SizedBox(height: 8),
                        Text(title.isEmpty ? 'Épisode $number' : title,
                            style: TextStyle(
                                fontSize: small ? 27 : 30,
                                height: 1.2,
                                letterSpacing: -1,
                                fontWeight: FontWeight.w400)),
                        const SizedBox(height: 13),
                        Text(
                            air == null
                                ? 'Date de diffusion non renseignée'
                                : 'Diffusé le ${frenchDate(air)}',
                            style: const TextStyle(
                                fontSize: 11, color: ModernPalette.muted)),
                        const SizedBox(height: 23),
                        Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            runSpacing: 6,
                            children: [
                              const Text('Cette saison',
                                  style: TextStyle(fontSize: 11)),
                              Text('${widget.seen} / ${widget.total} vus',
                                  style: const TextStyle(
                                      fontSize: 11, color: ModernPalette.muted))
                            ]),
                        const SizedBox(height: 11),
                        TweenAnimationBuilder<double>(
                            tween: Tween(end: widget.seen / widget.total),
                            duration: motionOf(
                                context, const Duration(milliseconds: 650)),
                            curve: const Cubic(.2, .8, .2, 1),
                            builder: (_, t, _) => LinearProgressIndicator(
                                value: t,
                                minHeight: 4,
                                color: ModernPalette.lime,
                                backgroundColor: const Color(0xFF292B2C),
                                semanticsLabel: 'Progression de cette saison : ${widget.seen} sur ${widget.total} épisodes vus')),
                        const SizedBox(height: 26),
                        Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            runSpacing: 6,
                            children: [
                              const Text('Dans cet épisode',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              if (overview.isNotEmpty)
                                Text(
                                    _revealed
                                        ? 'Résumé affiché'
                                        : 'Sans spoiler',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: ModernPalette.muted))
                            ]),
                        const SizedBox(height: 12),
                        if (overview.isEmpty)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text('Pas de résumé disponible.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: ModernPalette.muted)))
                        else if (!_revealed)
                          Semantics(
                              expanded: false,
                              child: FilledButton.tonal(
                                  onPressed: () =>
                                      setState(() => _revealed = true),
                                  style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 88),
                                      backgroundColor: const Color(0xFF191A1E),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(17))),
                                  child: const Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 9,
                                      children: [
                                        Icon(Icons.visibility_outlined,
                                            size: 15),
                                        Text('Révéler le résumé',
                                            style: TextStyle(fontSize: 12))
                                      ])))
                        else ...[
                          EntranceFade(
                              child: Text(overview,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.8,
                                      color: Color(0xFFB5B2BF)))),
                          TextButton(
                              onPressed: () =>
                                  setState(() => _revealed = false),
                              child: const Text('Masquer le résumé'))
                        ],
                        const SizedBox(height: 23),
                        ModernCommand(
                            shape: CommandShape.softCheck,
                            height: 66,
                            label:
                                watched == null ? 'Marquer vu' : 'Épisode vu',
                            selected: watched != null,
                            onPressed: widget.busy
                                ? null
                                : () => widget.onToggle(watched != null)),
                        const SizedBox(height: 10),
                        FilledButton.tonal(
                            onPressed: widget.busy ? null : widget.onCatchUp,
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF23202B),
                                foregroundColor: const Color(0xFFCEBEEB),
                                minimumSize: const Size(0, 48)),
                            child: const Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 9,
                                children: [
                                  Icon(Icons.playlist_add_check, size: 18),
                                  Text('Tout marquer jusqu’ici',
                                      style: TextStyle(fontSize: 12))
                                ])),
                        if (watched != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                  'Vu le ${frenchDate(watched.watchedAt)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFFC5D8B2)))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Semantics(
                                liveRegion: true,
                                child: Text(
                                    widget.busy
                                        ? 'Enregistrement…'
                                        : widget.receipt != null
                                            ? '${widget.receipt!.count} épisodes ajoutés.'
                                            : 'À ton rythme. Un épisode après l’autre.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: ModernPalette.muted)))),
                        if (widget.receipt != null)
                          TextButton(
                              onPressed: widget.busy ? null : widget.onUndo,
                              child: const Text('Annuler ce rattrapage')),
                        const SizedBox(height: 8),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              IconButton.filledTonal(
                                  tooltip: 'Épisode précédent',
                                  onPressed:
                                      widget.busy ? null : widget.previous,
                                  icon: const Icon(Icons.arrow_back),
                                  style: IconButton.styleFrom(
                                      minimumSize: const Size(52, 64))),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: ModernCommand(
                                      shape: CommandShape.nextUp,
                                      height: 64,
                                      subtitleAbove: true,
                                      label: widget.nextNumber == null
                                          ? 'Fin de cette saison'
                                          : 'Épisode ${widget.nextNumber}',
                                      subtitle: 'LA SUITE',
                                      onPressed:
                                          widget.busy ? null : widget.next))
                            ]),
                        const SizedBox(height: 20),
                        FilledButton.tonal(
                            onPressed: widget.busy ? null : widget.onAll,
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF202126),
                                minimumSize: const Size(0, 56),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17))),
                            child: const Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 12,
                                runSpacing: 5,
                                children: [
                                  Text('Tous les épisodes',
                                      style: TextStyle(fontSize: 12)),
                                  Text('Choisir un numéro ↗',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: ModernPalette.muted))
                                ])),
                      ])),
            ]));
  }
}

class _EpisodePicker extends ConsumerStatefulWidget {
  const _EpisodePicker(
      {required this.showId,
      required this.season,
      required this.episodes,
      required this.current});
  final int showId, season, current;
  final List<Map<String, dynamic>> episodes;
  @override
  ConsumerState<_EpisodePicker> createState() => _EpisodePickerState();
}

class _EpisodePickerState extends ConsumerState<_EpisodePicker> {
  late final TextEditingController _input = TextEditingController(
      text: '${widget.episodes[widget.current]['episode']}');
  String? _error;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _jump() {
    final number = int.tryParse(_input.text.trim());
    final index = widget.episodes.indexWhere((e) => e['episode'] == number);
    if (index < 0) {
      setState(() => _error = 'Ce numéro n’existe pas dans cette saison.');
      return;
    }
    Navigator.pop(context, index);
  }

  @override
  Widget build(BuildContext context) {
    final keys =
        ref.watch(watchedKeysProvider(widget.showId)).value ?? <String>{};
    return SafeArea(
        child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .85,
                child: CustomScrollView(slivers: [
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      sliver: SliverToBoxAdapter(
                          child: Column(children: [
                        Row(children: [
                          Expanded(
                              child: Text('Épisodes · saison ${widget.season}',
                                  style: const TextStyle(fontSize: 17))),
                          IconButton(
                              tooltip: 'Fermer la liste',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close))
                        ]),
                        const SizedBox(height: 12),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: TextField(
                                      controller: _input,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.go,
                                      onSubmitted: (_) => _jump(),
                                      decoration: InputDecoration(
                                          labelText: 'Numéro dans cette saison',
                                          errorText: _error,
                                          errorMaxLines: 3))),
                              const SizedBox(width: 8),
                              FilledButton(
                                  onPressed: _jump, child: const Text('Aller'))
                            ]),
                      ]))),
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((_, i) {
                        final n = widget.episodes[i]['episode'] as int;
                        return ListTile(
                            selected: i == widget.current,
                            selectedTileColor: ModernPalette.lilac,
                            selectedColor: const Color(0xFF302344),
                            title: Text('Épisode $n'),
                            subtitle: Text(
                                keys.contains('S${widget.season}E$n')
                                    ? 'Vu'
                                    : i == widget.current
                                        ? 'En consultation'
                                        : 'Non vu',
                                style: const TextStyle(fontSize: 10)),
                            onTap: () => Navigator.pop(context, i));
                      }, childCount: widget.episodes.length))),
                ]))));
  }
}

class _WatchFlash extends CustomPainter {
  _WatchFlash(this.animation) : super(repaint: animation);
  final Animation<double> animation;
  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0 || t >= 1) return;
    final opacity = (t < .25 ? t / .25 : (1 - t) / .75) * .9;
    final paint = Paint()
      ..color = const Color(0xFFECFFD7).withValues(alpha: opacity)
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      final y = size.height * [.35, .43, .55][i];
      final width = size.width * [.45, .31, .23][i];
      final end = Offset(size.width * 1.05 + 40 - 110 * t, y);
      canvas.drawLine(end - Offset(width, -width * .4), end, paint);
    }
  }

  @override
  bool shouldRepaint(_WatchFlash old) => old.animation != animation;
}
