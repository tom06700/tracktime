import '../brand/nitrate_brand.dart';
import '../profile/identity_editor.dart';
import '../widgets/media_image.dart';
import '../widgets/modern_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../backup/backup.dart';
import '../db/database.dart';
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
import '../widgets/states.dart';

/// Page Profil « Univers » : une frise verticale cinématographique, unique
/// par profil (salle obscure + projecteur teinté par les genres regardés),
/// parcourue de haut en bas — identité, à l'affiche, pellicule de genres,
/// activité, records, badges et liste de lecture.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  bool _backfillStarted = false;

  final _scrollCtrl = ScrollController();

  static String memberSince(DateTime since) =>
      'Membre depuis ${_months[since.month - 1]} ${since.year}';

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rattrape les genres manquants au montage (clé TheTVDB embarquée).
    if (!_backfillStarted) {
      _backfillStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _backfill());
    }

    final universe = ref.watch(universeProvider).value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ColoredBox(
            color: ModernPalette.background,
            child: _content(context, universe)));
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

    // Pas d'AppBar sur le Profil : le décor remplit tout, le contenu démarre
    // juste sous la safe area (en laissant la place au bouton Réglages).
    final topInset = MediaQuery.paddingOf(context).top + 20;
    return ListView(
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(0, topInset, 0, bottomNavInset(context)),
      children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 27),
            child: Row(children: [
              const Expanded(child: NitrateWordmark(size: 22)),
              IconButton.filledTonal(
                  tooltip: 'Réglages',
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.tune, size: 19))
            ])),

        // ── Identité cosmique ──
        sec(0, [
          profileAsync.when(
            loading: () => const SizedBox(height: 200),
            error: (e, _) => ErrorRetry(
              title: 'Profil indisponible',
              message: 'Réessaie pour retrouver ton profil.',
              onRetry: () => ref.invalidate(profileProvider),
            ),
            data: (profile) => _UniverseHeader(
              profile: profile,
              tagline: universe == null ? '…' : universeTagline(universe),
              palette: universe?.palette ?? const [Color(0xFF818B73)],
              memberSince: memberSince(profile.since),
            ),
          ),
        ]),

        // ── Chiffres clés ──
        sec(1, [
          statsAsync.when(
            loading: () => const SizedBox(height: 120),
            error: (_, _) => ErrorRetry(
              title: 'Statistiques indisponibles',
              message: 'Tes visionnages restent enregistrés.',
              onRetry: () => ref.invalidate(statsProvider),
            ),
            data: (stats) => _HeroStats(stats: stats),
          ),
        ]),

        Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
            child: ModernCommand(
                shape: CommandShape.surprise,
                label: 'Quoi regarder ce soir ?',
                subtitle: 'Un choix dans ta propre collection.',
                onPressed: () => showTonightPicker(context, tonight))),
        _RecentStories(),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(children: [
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Modifier mon profil',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.north_east, size: 17),
                  onTap: profileAsync.value == null
                      ? null
                      : () => editProfile(context, profileAsync.value!)),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Réglages & données',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.north_east, size: 17),
                  onTap: () => context.push('/settings')),
            ])),
        // ── À l'affiche (aperçu, la page dédiée montre tout) ──
        sec(2, [
          UniverseSectionTitle(
            'À l\'affiche',
            subtitle: 'Tes séries du moment, en grand écran.',
            actionLabel: 'Tout voir',
            onAction: () => context.push('/series'),
          ),
          MarqueeCarousel(
            shows: shows,
            lastActivity: universe?.lastActivityByShow ?? const {},
          ),
        ]),

        // ── Pellicule de genres ──
        sec(3, [
          const UniverseSectionTitle(
            'Ta pellicule',
            subtitle:
                'Chaque photogramme, un genre — à la mesure du temps passé.',
          ),
          if (universe != null) GenreFilmStrip(universe: universe),
        ]),

        // ── Activité ──
        sec(4, [
          const UniverseSectionTitle(
            'Ton année en épisodes',
            subtitle: 'Chaque cellule, un jour — touche pour le détail.',
          ),
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
          const UniverseSectionTitle(
            'Trophées',
            subtitle: 'Débloque-les en explorant ton univers.',
          ),
          if (universe != null) BadgeWall(badges: universe.badges),
        ]),

        // ── Liste de lecture ──
        sec(7, [
          const UniverseSectionTitle(
            'Liste de lecture',
            subtitle: 'À voir prochainement.',
          ),
          WatchlistStrip(movies: movies, shows: shows),
          const SizedBox(height: 16),
        ]),

        // ── Données & réglages ──
        sec(8, [
          const UniverseSectionTitle('Mes données'),
          _DataCard(onExport: () => _export(context)),
        ]),

        const Padding(
          padding: EdgeInsets.fromLTRB(22, 18, 22, 8),
          child: Text(
            'Nitrate — 100 % local, aucun compte, aucune donnée envoyée '
            'ailleurs que TheTVDB (métadonnées).\n\n'
            'Metadata provided by TheTVDB.com — Nitrate n\'est ni approuvé '
            'ni certifié par TheTVDB.',
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
        ref.read(tvdbClientProvider),
        throttle: () => Future.delayed(const Duration(milliseconds: 120)),
      );
    } catch (_) {
      // Silencieux : l'univers se construit avec les genres déjà connus.
    }
  }

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await exportBackup(ref.read(databaseProvider));
    } catch (e) {
      debugPrint('Export impossible : $e');
      messenger.showSnackBar(const SnackBar(
          content: Text('Impossible de créer la sauvegarde. Réessaie.')));
    }
  }
}

/// Petit bouton rond « verre » flottant (Réglages), lisible sur le décor.
class _UniverseHeader extends ConsumerWidget {
  const _UniverseHeader(
      {required this.profile,
      required this.tagline,
      required this.palette,
      required this.memberSince});
  final Profile profile;
  final String tagline, memberSince;
  final List<Color> palette;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: Column(children: [
        Row(children: [
          Transform.rotate(
              angle: -.105,
              child: Material(
                  color: ModernPalette.lilac,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      onTap: () => editProfile(context, profile),
                      child: SizedBox(
                          width: 68,
                          height: 68,
                          child: Center(
                              child: Text(profile.emoji,
                                  style: const TextStyle(fontSize: 32))))))),
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('TON CARNET DE BORD',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.7,
                        color: Color(0xFFC1ADC9))),
                Text(profile.displayName,
                    style: const TextStyle(
                        fontSize: 31,
                        height: 1.1,
                        letterSpacing: -1.2,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 6),
                const Text('Chaque histoire laisse une trace.',
                    style: TextStyle(fontSize: 11, color: Color(0xFFB09FBB))),
              ])),
        ]),
        const SizedBox(height: 8),
        Align(
            alignment: Alignment.centerLeft,
            child: Text(memberSince,
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFF93889F)))),
      ]));
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.stats});
  final WatchStats stats;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: const Color(0xFFD2BFF8),
                borderRadius: BorderRadius.circular(27)),
            child: Stack(children: [
              Positioned(
                  right: -50,
                  bottom: -75,
                  child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              width: 26, color: const Color(0xA6B499DE))))),
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 23, vertical: 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TEMPS DE VISIONNAGE ESTIMÉ',
                            style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.7,
                                color: Color(0xFF645174))),
                        const SizedBox(height: 14),
                        Text(fmtTime(stats.totalMinutes),
                            style: const TextStyle(
                                fontSize: 49,
                                height: 1.1,
                                letterSpacing: -2,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF32233F))),
                        const SizedBox(height: 9),
                        const Text(
                            'Calculé à partir de tes films et épisodes vus.',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF645172))),
                      ]))
            ])),
        const SizedBox(height: 15),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _MiniStat(
              value: '${stats.episodeCount}',
              label: 'épisodes vus',
              onTap: () => context.push('/history')),
          const SizedBox(width: 7),
          _MiniStat(
              value: '${stats.moviesSeen}',
              label: 'films vus',
              onTap: () => context.push('/movie-history')),
          const SizedBox(width: 7),
          _MiniStat(
              value: '${stats.showCount}',
              label: 'séries suivies',
              onTap: () => context.push('/series')),
        ]),
        const SizedBox(height: 10),
        Text('${stats.doneShowCount} séries terminées',
            style: const TextStyle(fontSize: 11, color: Color(0xFFAD9CB8))),
      ]));
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.value, required this.label, required this.onTap});
  final String value, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
      child: Material(
          color: const Color(0xFF222028),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 7),
                  child: Column(children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 25,
                            height: 1.2,
                            fontWeight: FontWeight.w400)),
                    const SizedBox(height: 6),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFFAD9CB8)))
                  ])))));
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
      child: Material(
        type: MaterialType.transparency,
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
              subtitle: 'Sauvegarde ou export TV Time',
              onTap: () => context.push('/import'),
            ),
            const _TileDivider(),
            _ActionTile(
              icon: Icons.tune,
              title: 'Réglages',
              subtitle: 'Métadonnées TheTVDB, à propos',
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
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
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12.5,
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.white.withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 56,
        color: Colors.white.withValues(alpha: 0.08),
      );
}

class _RecentStories extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref.watch(watchHistoryProvider).value ?? [];
    final movies = ref.watch(moviesProvider).value ?? [];
    final entries = <({
      String title,
      String subtitle,
      String? image,
      DateTime at,
      String route,
      Object? extra
    })>[
      for (final e in episodes.take(3))
        (
          title: e.show.name,
          subtitle: '${e.code} · ${frenchDate(e.watchedAt)}',
          image: e.show.poster,
          at: e.watchedAt,
          route: '/episode/${e.show.id}/${e.season}/${e.episode}',
          extra: {'name': e.show.name}
        ),
      for (final m in movies.where((m) => m.watchedAt != null))
        (
          title: m.title,
          subtitle: 'Film vu · ${frenchDate(m.watchedAt!)}',
          image: m.poster,
          at: m.watchedAt!,
          route: '/movie/${m.id}',
          extra: m.title
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return Padding(
        padding: const EdgeInsets.fromLTRB(22, 25, 22, 12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Text('Dernières histoires',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
            TextButton(
                onPressed: () => context.push('/history'),
                child: const Text('Tout voir'))
          ]),
          if (entries.isEmpty)
            const Text('Ton premier visionnage apparaîtra ici.',
                style: TextStyle(color: TtColors.dim)),
          for (final e in entries.take(3))
            ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => context.push(e.route, extra: e.extra),
                leading: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: SizedBox(
                        width: 43,
                        height: 57,
                        child: MediaImage(
                            sources: [e.image],
                            seed: e.title,
                            icon: Icons.movie_outlined))),
                title: Text(e.title, style: const TextStyle(fontSize: 12)),
                subtitle: Text(e.subtitle,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFAA9BB4))),
                trailing: const Icon(Icons.north_east,
                    size: 16, color: ModernPalette.lilac)),
        ]));
  }
}
