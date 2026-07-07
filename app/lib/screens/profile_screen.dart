import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../backup/backup.dart';
import '../db/database.dart';
import '../profile/cinema.dart';
import '../profile/genre_sync.dart';
import '../profile/profile.dart';
import '../profile/reveal.dart';
import '../profile/sections.dart';
import '../profile/tonight.dart';
import '../profile/universe.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

/// Page Profil « Univers » : une frise verticale cinématographique, unique
/// par profil (salle obscure + projecteur teinté par les genres regardés),
/// parcourue de haut en bas — identité, à l'affiche, pellicule de genres,
/// activité, records, badges et liste de lecture.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
    'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  bool _backfillStarted = false;

  /// Horloge du fond vivant (poussières, scintillement) : 30 s en boucle.
  late final AnimationController _drive =
      AnimationController(vsync: this, duration: const Duration(seconds: 30));
  final _scrollCtrl = ScrollController();

  static String memberSince(DateTime since) =>
      'Membre depuis ${_months[since.month - 1]} ${since.year}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _drive.stop();
      _drive.value = 0;
    } else if (!_drive.isAnimating) {
      _drive.repeat();
    }
  }

  @override
  void dispose() {
    _drive.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rattrape les genres manquants dès que la clé TMDB est chargée (les
    // séries ajoutées avant la colonne `genres`, ou importées, n'en ont pas).
    final key = ref.watch(tmdbKeyProvider).value;
    if (!_backfillStarted && key != null && key.isNotEmpty) {
      _backfillStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _backfill());
    }

    final universe = ref.watch(universeProvider).value;
    final palette = universe?.palette ?? const [Color(0xFF6C4CE0)];
    final seed = universe?.seed ?? 7;

    return Stack(
      children: [
        Positioned.fill(
          child: CinemaBackground(
            seed: seed,
            palette: palette,
            drive: _drive,
            scroll: _scrollCtrl,
          ),
        ),
        Positioned.fill(child: _content(context, universe)),
      ],
    );
  }

  Widget _content(BuildContext context, Universe? universe) {
    final profileAsync = ref.watch(profileProvider);
    final statsAsync = ref.watch(statsProvider);
    final showsAsync = ref.watch(showsProvider);
    final moviesAsync = ref.watch(moviesProvider);
    final shows = showsAsync.value ?? const [];
    final movies = moviesAsync.value ?? const [];
    final tonight = watchlistItems(movies, shows);

    // Chaque section apparaît en fondu quand elle entre à l'écran (léger
    // stagger pour les premières, visibles dès l'ouverture).
    Widget sec(int i, List<Widget> children) => Reveal(
          delayMs: i < 3 ? i * 90 : 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );

    return ListView(
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(0, 8, 0, bottomNavInset(context)),
      children: [
        // ── Identité cosmique ──
        sec(0, [
          profileAsync.when(
            loading: () => const SizedBox(height: 200),
            error: (e, _) =>
                EmptyState(icon: Icons.error_outline, message: '$e'),
            data: (profile) => _UniverseHeader(
              profile: profile,
              tagline: universe == null ? '…' : universeTagline(universe),
              palette: universe?.palette ?? const [Color(0xFF6C4CE0)],
              memberSince: memberSince(profile.since),
            ),
          ),
        ]),

        // ── Chiffres clés ──
        sec(1, [
          statsAsync.when(
            loading: () => const SizedBox(height: 120),
            error: (_, _) => const SizedBox.shrink(),
            data: (stats) => _HeroStats(stats: stats),
          ),
        ]),

        // ── À l'affiche (aperçu, la page dédiée montre tout) ──
        sec(2, [
          UniverseSectionTitle('À l\'affiche',
              subtitle: 'Tes séries du moment, en grand écran.',
              actionLabel: 'Tout voir',
              onAction: () => context.push('/series')),
          MarqueeCarousel(
            shows: shows,
            lastActivity: universe?.lastActivityByShow ?? const {},
          ),
        ]),

        // ── Pellicule de genres ──
        sec(3, [
          const UniverseSectionTitle('Ta pellicule',
              subtitle:
                  'Chaque photogramme, un genre — à la mesure du temps passé.'),
          if (universe != null) GenreFilmStrip(universe: universe),
        ]),

        // ── Activité ──
        sec(4, [
          const UniverseSectionTitle('Ton année en épisodes',
              subtitle: 'Chaque cellule, un jour — touche pour le détail.'),
          if (universe != null) ...[
            StreakRow(
              current: universe.currentStreak,
              best: universe.bestStreak,
              accent: universe.palette.first,
            ),
            ActivityHeatmap(
              activityByDay: universe.activityByDay,
              labelsByDay: universe.labelsByDay,
              accent: universe.palette.first,
              now: DateTime.now(),
            ),
          ],
        ]),

        // ── Records ──
        if (universe != null && universe.records.isNotEmpty)
          sec(5, [
            const UniverseSectionTitle('Records'),
            RecordsBand(records: universe.records),
          ]),

        // ── Badges ──
        sec(6, [
          const UniverseSectionTitle('Trophées',
              subtitle: 'Débloque-les en explorant ton univers.'),
          if (universe != null) BadgeWall(badges: universe.badges),
        ]),

        // ── Liste de lecture ──
        sec(7, [
          const UniverseSectionTitle('Liste de lecture',
              subtitle: 'À voir prochainement.'),
          WatchlistStrip(movies: movies, shows: shows),
          const SizedBox(height: 16),
          Center(
            child: ProminentGlassButton(
              icon: Icons.movie_filter_outlined,
              onPressed: tonight.isEmpty
                  ? null
                  : () => showTonightPicker(context, tonight),
              child: const Text('Quoi regarder ce soir ?'),
            ),
          ),
        ]),

        // ── Données & réglages ──
        sec(8, [
          const UniverseSectionTitle('Mes données'),
          _DataCard(onExport: () => _export(context)),
        ]),

        const Padding(
          padding: EdgeInsets.fromLTRB(22, 18, 22, 8),
          child: Text(
            'TrackTime — 100 % local, aucun compte, aucune donnée envoyée '
            'ailleurs que TMDB (métadonnées).\n\n'
            'Ce produit utilise l\'API TMDB mais n\'est ni approuvé ni '
            'certifié par TMDB.',
            style: TextStyle(fontSize: 12, color: TtColors.dim, height: 1.6),
          ),
        ),
      ],
    );
  }

  Future<void> _backfill() async {
    try {
      await backfillGenres(
        ref.read(databaseProvider),
        ref.read(tmdbClientProvider),
        throttle: () => Future.delayed(const Duration(milliseconds: 120)),
      );
    } catch (_) {
      // Silencieux : l'univers se construit avec les genres déjà connus.
    }
  }

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final key = ref.read(tmdbKeyProvider).value ?? '';
      await exportBackup(ref.read(databaseProvider), tmdbKey: key);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export impossible : $e')));
    }
  }
}

// ─────────────────────────── Identité cosmique ─────────────────────────────

class _UniverseHeader extends ConsumerWidget {
  const _UniverseHeader({
    required this.profile,
    required this.tagline,
    required this.palette,
    required this.memberSince,
  });

  final Profile profile;
  final String tagline;
  final List<Color> palette;
  final String memberSince;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Teinte chaude « projecteur » dérivée de la palette du profil.
    final spot = Color.lerp(palette.first, const Color(0xFFF5D9A0), 0.45)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        children: [
          // Avatar mis en lumière : halo doux du projecteur + anneau net,
          // reflet en haut (la lumière qui tombe dessus).
          GestureDetector(
            onTap: () => _pickEmoji(context, ref),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF0C0F16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: spot.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                gradient: RadialGradient(
                  center: const Alignment(0, -0.7),
                  radius: 1.1,
                  colors: [
                    spot.withValues(alpha: 0.22),
                    const Color(0xFF0C0F16),
                  ],
                  stops: const [0, 0.75],
                ),
                boxShadow: [
                  BoxShadow(
                    color: spot.withValues(alpha: 0.32),
                    blurRadius: 34,
                    spreadRadius: -6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(profile.emoji, style: const TextStyle(fontSize: 46)),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _editName(context, ref, profile.name),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    shadows: [Shadow(color: Color(0xAA000000), blurRadius: 12)],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined,
                    size: 16, color: Colors.white.withValues(alpha: 0.5)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            memberSince,
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ton nom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: 'Ex. Thomas'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (name != null) {
      await ref.read(profileProvider.notifier).setName(name);
    }
  }

  Future<void> _pickEmoji(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TtColors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choisis ton avatar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in avatarChoices)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, e),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: e == profile.emoji
                            ? TtColors.amber.withValues(alpha: 0.18)
                            : TtColors.surfaceHi,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) {
      await ref.read(profileProvider.notifier).setEmoji(choice);
    }
  }
}

// ─────────────────────────────── Chiffres ──────────────────────────────────

class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.stats});

  final WatchStats stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        children: [
          Text(
            fmtTime(stats.totalMinutes),
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              color: TtColors.amber,
              letterSpacing: -1.5,
              shadows: [
                Shadow(
                    color: TtColors.amber.withValues(alpha: 0.4),
                    blurRadius: 24),
              ],
            ),
          ),
          Text(
            'DE PROJECTION DANS TA SALLE OBSCURE',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _MiniStat(
                  value: '${stats.episodeCount}', label: 'épisodes'),
              _MiniStat(value: '${stats.moviesSeen}', label: 'films'),
              _MiniStat(
                  value: '${stats.showCount}', label: 'séries'),
              _MiniStat(
                  value: '${stats.doneShowCount}', label: 'terminées'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                fontSize: 11.5, color: Colors.white.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────── Données ──────────────────────────────────

class _DataCard extends StatelessWidget {
  const _DataCard({required this.onExport});

  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.ios_share,
            title: 'Exporter mes données',
            subtitle: 'Sauvegarde JSON (compatible avec l\'import)',
            onTap: onExport,
          ),
          const _TileDivider(),
          _ActionTile(
            icon: Icons.download_outlined,
            title: 'Importer / restaurer',
            subtitle: 'Backup TrackTime ou export TV Time',
            onTap: () => context.push('/import'),
          ),
          const _TileDivider(),
          _ActionTile(
            icon: Icons.key_outlined,
            title: 'Clé API TMDB',
            subtitle: 'Réglages de connexion à TMDB',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: TtColors.amber),
      title: Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 12.5, color: Colors.white.withValues(alpha: 0.55))),
      trailing: Icon(Icons.chevron_right,
          color: Colors.white.withValues(alpha: 0.4)),
      onTap: onTap,
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) => Divider(
      height: 1, indent: 56, color: Colors.white.withValues(alpha: 0.08));
}
