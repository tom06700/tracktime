import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../tmdb/tmdb.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

/// Feuille modale glissable (remonte du bas) contenant un carrousel : on glisse
/// horizontalement pour changer d'épisode, vers le bas pour fermer. Ouverte via
/// une route go_router non opaque (le fil reste visible dessous) — voir router.
class EpisodeSheet extends ConsumerStatefulWidget {
  const EpisodeSheet({
    super.key,
    required this.showId,
    required this.showName,
    required this.season,
    required this.initialEpisode,
    this.posterPath,
  });

  final int showId;
  final String showName;
  final int season;
  final int initialEpisode;
  final String? posterPath;

  @override
  ConsumerState<EpisodeSheet> createState() => _EpisodeSheetState();
}

class _EpisodeSheetState extends ConsumerState<EpisodeSheet>
    with SingleTickerProviderStateMixin {
  List<int> _episodes = const [];
  PageController? _controller;
  int _current = 0;

  // Fermeture interactive : la feuille suit le doigt.
  double _dragOffset = 0;
  late final AnimationController _drag =
      AnimationController.unbounded(vsync: this)
        ..addListener(() => setState(() => _dragOffset = _drag.value));

  @override
  void initState() {
    super.initState();
    _loadSeason();
  }

  @override
  void dispose() {
    _drag.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) => _drag.stop();

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragOffset = (_dragOffset + d.delta.dy).clamp(0.0, double.infinity);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final h = MediaQuery.sizeOf(context).height;
    final velocity = d.primaryVelocity ?? 0;
    final dismiss = _dragOffset > h * 0.16 || velocity > 700;
    _drag.value = _dragOffset;
    if (dismiss) {
      _drag
          .animateTo(h,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeIn)
          .whenComplete(() {
        if (mounted) context.pop();
      });
    } else {
      _drag.animateTo(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _loadSeason() async {
    var numbers = <int>[widget.initialEpisode];
    try {
      final j =
          await ref.read(tmdbClientProvider).season(widget.showId, widget.season);
      final eps = ((j['episodes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final rows = <EpisodesCompanion>[];
      final nums = <int>[];
      for (final e in eps) {
        final n = (e['episode_number'] as num?)?.toInt();
        if (n == null) continue;
        nums.add(n);
        rows.add(EpisodesCompanion.insert(
          showId: widget.showId,
          season: widget.season,
          episode: n,
          name: Value(e['name'] as String?),
          still: Value(e['still_path'] as String?),
          airDate: Value(DateTime.tryParse('${e['air_date'] ?? ''}')),
        ));
      }
      if (rows.isNotEmpty) {
        await ref.read(databaseProvider).upsertEpisodes(rows);
      }
      if (nums.isNotEmpty) numbers = (nums..sort());
    } on TmdbException {
      /* on garde l'épisode seul */
    }
    if (!mounted) return;
    final index = numbers.indexOf(widget.initialEpisode).clamp(0, numbers.length - 1);
    setState(() {
      _episodes = numbers;
      _current = index;
      _controller = PageController(initialPage: index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    // Les dots restent en place et s'effacent pendant qu'on glisse la carte.
    final dotsOpacity = (1 - _dragOffset / 70).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots dans l'espace vide au-dessus de la carte → indique le swipe.
          if (_controller != null && _episodes.length > 1)
            Opacity(
              opacity: dotsOpacity,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DotsIndicator(count: _episodes.length, index: _current),
              ),
            ),
          // Seule la carte suit le doigt.
          Transform.translate(
            offset: Offset(0, _dragOffset),
            child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            // Material : fournit le style de texte (sinon soulignés jaunes) et
            // la surface de la carte.
            child: Material(
              color: TtColors.bg,
              child: SizedBox(
                height: height * 0.9,
                child: Column(
                  children: [
                    _handle(),
                    Expanded(
                      child: _controller == null
                          ? const Center(child: CircularProgressIndicator())
                          : PageView.builder(
                              controller: _controller,
                              onPageChanged: (i) {
                                HapticFeedback.selectionClick();
                                setState(() => _current = i);
                              },
                              itemCount: _episodes.length,
                              itemBuilder: (_, i) => _EpisodePage(
                                showId: widget.showId,
                                showName: widget.showName,
                                season: widget.season,
                                episode: _episodes[i],
                                posterPath: widget.posterPath,
                                position: '${i + 1} sur ${_episodes.length}',
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ],
        ),
    );
  }

  /// Poignée : glisser vers le bas ferme la feuille (la feuille suit le doigt).
  Widget _handle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Indicateur de pages (dots) : pastille active ambre allongée, fenêtre
/// glissante quand il y a beaucoup d'épisodes.
class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.index});

  final int count;
  final int index;

  static const _window = 9;

  @override
  Widget build(BuildContext context) {
    final start =
        count <= _window ? 0 : (index - _window ~/ 2).clamp(0, count - _window);
    final end = count <= _window ? count : start + _window;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = start; i < end; i++) _dot(i, start, end),
      ],
    );
  }

  Widget _dot(int i, int start, int end) {
    final active = i == index;
    // Bords rétrécis quand d'autres dots existent au-delà de la fenêtre.
    final edge = (i == start && start > 0) || (i == end - 1 && end < count);
    final size = active ? 8.0 : (edge ? 4.0 : 6.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: active ? 20 : size,
      height: size,
      decoration: BoxDecoration(
        color: active ? TtColors.amber : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ------------------------------------------------------- Une page d'épisode

class _EpisodePage extends ConsumerStatefulWidget {
  const _EpisodePage({
    required this.showId,
    required this.showName,
    required this.season,
    required this.episode,
    required this.position,
    this.posterPath,
  });

  final int showId;
  final String showName;
  final int season;
  final int episode;
  final String position;
  final String? posterPath;

  @override
  ConsumerState<_EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends ConsumerState<_EpisodePage>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref
          .read(tmdbClientProvider)
          .episode(widget.showId, widget.season, widget.episode);
      if (mounted) setState(() => _data = d);
    } on TmdbException catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _toggleWatched(bool watched) {
    HapticFeedback.lightImpact();
    final db = ref.read(databaseProvider);
    if (watched) {
      db.setEpisodeUnwatched(widget.showId, widget.season, widget.episode);
    } else {
      db.setEpisodeWatched(widget.showId, widget.season, widget.episode);
    }
  }

  Future<void> _markUpTo() async {
    HapticFeedback.mediumImpact();
    await ref
        .read(databaseProvider)
        .markWatchedUpTo(widget.showId, widget.season, widget.episode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Épisodes précédents marqués comme vus ✓')));
    }
  }

  Future<void> _share() async {
    final title = '${_data?['name'] ?? ''}';
    final code = 'S${widget.season}E${widget.episode}';
    await SharePlus.instance.share(ShareParams(
      text: '${widget.showName} — $code'
          '${title.isNotEmpty ? ' · $title' : ''}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ref0 = (
      showId: widget.showId,
      season: widget.season,
      episode: widget.episode
    );
    final watchedRow = ref.watch(watchedEpisodeProvider(ref0)).value;

    if (_error != null) {
      return EmptyState(icon: Icons.error_outline, message: _error!);
    }
    if (_data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _content(_data!, watchedRow != null, watchedRow?.watchedAt);
  }

  Widget _content(Map<String, dynamic> d, bool watched, DateTime? watchedAt) {
    final still = d['still_path'] as String?;
    final title = '${d['name'] ?? 'Épisode ${widget.episode}'}';
    final overview = '${d['overview'] ?? ''}';
    final runtime = (d['runtime'] as num?)?.toInt();
    final vote = (d['vote_average'] as num?)?.toDouble() ?? 0;
    final voteCount = (d['vote_count'] as num?)?.toInt() ?? 0;
    final air = DateTime.tryParse('${d['air_date'] ?? ''}');
    final guests = ((d['guest_stars'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final crew = ((d['crew'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final director = _crewName(crew, 'Director');
    final writer = _crewName(crew, 'Writer') ?? _crewDept(crew, 'Writing');

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _Hero(
          stillPath: still,
          seed: widget.showName,
          season: widget.season,
          episode: widget.episode,
          title: title,
          onShare: _share,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vote > 0) ...[
                Row(
                  children: [
                    _Stars(rating: vote),
                    const SizedBox(width: 8),
                    Text(vote.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    if (voteCount > 0) ...[
                      const SizedBox(width: 6),
                      Text('($voteCount votes)',
                          style: const TextStyle(
                              fontSize: 12.5, color: TtColors.dim)),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (air != null)
                    _Meta(icon: Icons.event_outlined, text: frenchDate(air)),
                  if (runtime != null && runtime > 0)
                    _Meta(icon: Icons.schedule, text: fmtTime(runtime)),
                  _Meta(icon: Icons.tag, text: widget.position),
                ],
              ),
              if (watched && watchedAt != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: TtColors.teal),
                    const SizedBox(width: 6),
                    Text('Vu le ${frenchDate(watchedAt)}',
                        style:
                            const TextStyle(fontSize: 13, color: TtColors.teal)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: watched
                        ? ProminentGlassButton(
                            color: TtColors.teal,
                            icon: Icons.check,
                            onPressed: () => _toggleWatched(true),
                            child: const Text('Épisode vu'),
                          )
                        : ProminentGlassButton(
                            icon: Icons.remove_red_eye_outlined,
                            onPressed: () => _toggleWatched(false),
                            child: const Text('Marquer comme vu'),
                          ),
                  ),
                  const SizedBox(width: 8),
                  GlassButton(
                    icon: Icons.playlist_add_check,
                    onPressed: _markUpTo,
                    child: const Text('Jusqu\'ici'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                overview.isEmpty ? 'Pas de résumé disponible.' : overview,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.6,
                    color: overview.isEmpty ? TtColors.dim : TtColors.text),
              ),
              if (director != null || writer != null) ...[
                const SizedBox(height: 16),
                if (director != null)
                  _CrewLine(role: 'Réalisation', name: director),
                if (writer != null) _CrewLine(role: 'Scénario', name: writer),
              ],
              if (guests.isNotEmpty) ...[
                const SizedBox(height: 22),
                const _SectionTitle('Avec'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: guests.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _GuestStar(guests[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String? _crewName(List<Map<String, dynamic>> crew, String job) {
    for (final c in crew) {
      if (c['job'] == job) return '${c['name']}';
    }
    return null;
  }

  static String? _crewDept(List<Map<String, dynamic>> crew, String dept) {
    for (final c in crew) {
      if (c['department'] == dept) return '${c['name']}';
    }
    return null;
  }
}

// -------------------------------------------------------------------- Hero

class _Hero extends StatelessWidget {
  const _Hero({
    required this.stillPath,
    required this.seed,
    required this.season,
    required this.episode,
    required this.title,
    required this.onShare,
  });

  final String? stillPath;
  final String seed;
  final int season;
  final int episode;
  final String title;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final hue =
        (seed.codeUnits.fold<int>(0, (a, c) => a * 31 + c) % 360).toDouble();
    final placeholder = DecoratedBox(
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
    );
    return SizedBox(
      height: 224,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (stillPath != null && stillPath!.isNotEmpty)
            Image.network('https://image.tmdb.org/t/p/w780$stillPath',
                fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder)
          else
            placeholder,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xE6000000)
                ],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.35),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.ios_share, color: Colors.white, size: 20),
                onPressed: onShare,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAISON $season · ÉPISODE $episode',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: TtColors.amber),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final double rating;
  @override
  Widget build(BuildContext context) {
    final stars = rating / 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            stars >= i + 1
                ? Icons.star_rounded
                : stars >= i + 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_border_rounded,
            size: 20,
            color: TtColors.amber,
          ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: TtColors.dim),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 13, color: TtColors.text)),
      ],
    );
  }
}

class _CrewLine extends StatelessWidget {
  const _CrewLine({required this.role, required this.name});
  final String role;
  final String name;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: '$role : ',
            style: const TextStyle(
                fontSize: 13, color: TtColors.dim, fontWeight: FontWeight.w600)),
        TextSpan(
            text: name,
            style: const TextStyle(fontSize: 13, color: TtColors.text)),
      ])),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: TtColors.amber),
      );
}

class _GuestStar extends StatelessWidget {
  const _GuestStar(this.person);
  final Map<String, dynamic> person;

  @override
  Widget build(BuildContext context) {
    final name = '${person['name'] ?? ''}';
    final character = '${person['character'] ?? ''}';
    final profile = person['profile_path'] as String?;
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: TtColors.surfaceHi,
            backgroundImage: profile != null
                ? NetworkImage('https://image.tmdb.org/t/p/w185$profile')
                : null,
            child: profile == null
                ? const Icon(Icons.person, color: TtColors.dim)
                : null,
          ),
          const SizedBox(height: 6),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          if (character.isNotEmpty)
            Text(character,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: TtColors.dim)),
        ],
      ),
    );
  }
}
