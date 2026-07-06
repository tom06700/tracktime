import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String? _error;

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
      if (!mounted) return;
      setState(() => _data = d);
    } on TmdbException catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  String get _key => 'S${widget.season}E${widget.episode}';

  void _toggleWatched(bool watched) {
    HapticFeedback.lightImpact();
    final db = ref.read(databaseProvider);
    if (watched) {
      db.setEpisodeUnwatched(widget.showId, widget.season, widget.episode);
    } else {
      db.setEpisodeWatched(widget.showId, widget.season, widget.episode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final watched = (ref.watch(watchedKeysProvider(widget.showId)).value ??
            const <String>{})
        .contains(_key);

    return Scaffold(
      appBar: AppBar(title: Text(widget.showName, overflow: TextOverflow.ellipsis)),
      body: _error != null
          ? EmptyState(icon: Icons.error_outline, message: _error!)
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(_data!, watched),
    );
  }

  Widget _buildContent(Map<String, dynamic> d, bool watched) {
    final still = d['still_path'] as String?;
    final title = '${d['name'] ?? 'Épisode ${widget.episode}'}';
    final overview = '${d['overview'] ?? ''}';
    final runtime = (d['runtime'] as num?)?.toInt();
    final vote = (d['vote_average'] as num?)?.toDouble() ?? 0;
    final air = DateTime.tryParse('${d['air_date'] ?? ''}');

    return ListView(
      padding: EdgeInsets.only(bottom: bottomNavInset(context)),
      children: [
        _Hero(stillPath: still, seed: widget.showName),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saison ${widget.season} · Épisode ${widget.episode}',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: TtColors.amber),
              ),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, height: 1.15)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (air != null)
                    _Meta(icon: Icons.event_outlined, text: frenchDate(air)),
                  if (runtime != null && runtime > 0)
                    _Meta(icon: Icons.schedule, text: fmtTime(runtime)),
                  if (vote > 0)
                    _Meta(
                        icon: Icons.star_rounded,
                        text: vote.toStringAsFixed(1),
                        iconColor: TtColors.amber),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                overview.isEmpty ? 'Pas de résumé disponible.' : overview,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.6,
                    color: overview.isEmpty ? TtColors.dim : TtColors.text),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
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
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.stillPath, required this.seed});

  final String? stillPath;
  final String seed;

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
      child: const Center(child: Icon(Icons.tv, color: Colors.white54, size: 40)),
    );
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: (stillPath == null || stillPath!.isEmpty)
          ? placeholder
          : Image.network(
              'https://image.tmdb.org/t/p/w780$stillPath',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.iconColor});

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor ?? TtColors.dim),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(fontSize: 13, color: TtColors.text)),
      ],
    );
  }
}
