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

class EpisodeDetailScreen extends ConsumerStatefulWidget {
  const EpisodeDetailScreen({
    super.key,
    required this.showId,
    required this.showName,
    required this.season,
    required this.episode,
    this.posterPath,
  });

  final int showId;
  final String showName;
  final int season;
  final int episode;
  final String? posterPath;

  @override
  ConsumerState<EpisodeDetailScreen> createState() =>
      _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends ConsumerState<EpisodeDetailScreen> {
  Map<String, dynamic>? _data;
  List<int> _seasonEpisodes = const []; // numéros d'épisodes de la saison
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tmdb = ref.read(tmdbClientProvider);
    try {
      final d = await tmdb.episode(widget.showId, widget.season, widget.episode);
      if (!mounted) return;
      setState(() => _data = d);
      // Épisodes de la saison (position, précédent/suivant) + réchauffe le
      // cache (bénéficie au fil « à voir » / « à venir »).
      _loadSeason(tmdb);
    } on TmdbException catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _loadSeason(TmdbClient tmdb) async {
    try {
      final j = await tmdb.season(widget.showId, widget.season);
      final eps = ((j['episodes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final numbers = <int>[];
      final rows = <EpisodesCompanion>[];
      for (final e in eps) {
        final n = (e['episode_number'] as num?)?.toInt();
        if (n == null) continue;
        numbers.add(n);
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
      numbers.sort();
      if (mounted) setState(() => _seasonEpisodes = numbers);
    } on TmdbException {
      /* ignoré */
    }
  }

  int get _index => _seasonEpisodes.indexOf(widget.episode);
  int? get _prev => _index > 0 ? _seasonEpisodes[_index - 1] : null;
  int? get _next => (_index >= 0 && _index < _seasonEpisodes.length - 1)
      ? _seasonEpisodes[_index + 1]
      : null;

  void _goTo(int episode) {
    context.replace(
      '/episode/${widget.showId}/${widget.season}/$episode',
      extra: {'name': widget.showName, 'poster': widget.posterPath},
    );
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
    final ref0 = (
      showId: widget.showId,
      season: widget.season,
      episode: widget.episode
    );
    final watchedRow = ref.watch(watchedEpisodeProvider(ref0)).value;
    final watched = watchedRow != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Partager',
            onPressed: _data == null ? null : _share,
          ),
        ],
      ),
      body: _error != null
          ? EmptyState(icon: Icons.error_outline, message: _error!)
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(_data!, watched, watchedRow?.watchedAt),
    );
  }

  Widget _buildContent(
      Map<String, dynamic> d, bool watched, DateTime? watchedAt) {
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
    final position = _index >= 0 && _seasonEpisodes.isNotEmpty
        ? '${_index + 1} sur ${_seasonEpisodes.length}'
        : null;

    return ListView(
      padding: EdgeInsets.only(bottom: bottomNavInset(context)),
      children: [
        _Hero(
          stillPath: still,
          seed: widget.showName,
          season: widget.season,
          episode: widget.episode,
          title: title,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Note en étoiles + votes.
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
              // Méta : date, durée, position.
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (air != null)
                    _Meta(icon: Icons.event_outlined, text: frenchDate(air)),
                  if (runtime != null && runtime > 0)
                    _Meta(icon: Icons.schedule, text: fmtTime(runtime)),
                  if (position != null)
                    _Meta(icon: Icons.tag, text: position),
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
                        style: const TextStyle(
                            fontSize: 13, color: TtColors.teal)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              // Actions vu / rattraper.
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
              const SizedBox(height: 24),
              _EpisodeNav(
                onPrev: _prev == null ? null : () => _goTo(_prev!),
                onNext: _next == null ? null : () => _goTo(_next!),
              ),
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
  });

  final String? stillPath;
  final String seed;
  final int season;
  final int episode;
  final String title;

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
      height: 250,
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
                colors: [Color(0x66000000), Color(0x00000000), Color(0xE6000000)],
                stops: [0, 0.4, 1],
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
                      fontSize: 24,
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
  const _Stars({required this.rating}); // rating 0..10

  final double rating;

  @override
  Widget build(BuildContext context) {
    final stars = rating / 2; // 0..5
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
            text: name, style: const TextStyle(fontSize: 13, color: TtColors.text)),
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

class _EpisodeNav extends StatelessWidget {
  const _EpisodeNav({this.onPrev, this.onNext});
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NavButton(
            icon: Icons.chevron_left,
            label: 'Précédent',
            onTap: onPrev,
            alignEnd: false,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NavButton(
            icon: Icons.chevron_right,
            label: 'Suivant',
            onTap: onNext,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.alignEnd,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final row = Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              Icon(icon, size: 22),
            ]
          : [
              Icon(icon, size: 22),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
            ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: TtColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: row,
          ),
        ),
      ),
    );
  }
}
