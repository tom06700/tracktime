import 'package:go_router/go_router.dart';
import '../db/database.dart';
import '../motion.dart';
import '../widgets/modern_controls.dart';
import '../widgets/validated_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/cinematic.dart';
import '../providers.dart';
import '../theme.dart';
import '../tmdb/media_detail.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';
import 'media_detail_parts.dart';

/// Fiche d'un film. Consultable sans que le film soit dans la bibliothèque :
/// tout vient de TheTVDB, la base locale ne servant qu'à savoir s'il y est
/// déjà.
class MovieDetailScreen extends ConsumerWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.title = ''});

  final int movieId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(movieDetailProvider(movieId));

    // Ni AppBar ni titre collant : le fond occupe le haut de l'écran et le
    // retour flotte par-dessus, posé par la coquille. Le noir Nitrate sert de
    // socle, pour que l'attente ne soit jamais transparente.
    return Scaffold(
      backgroundColor: TtColors.bg,
      body: detail.when(
        // Un rechargement après erreur garde l'erreur affichée plutôt que de
        // faire réapparaître le squelette.
        skipLoadingOnReload: true,
        loading: () => const DetailWithBack(child: MediaDetailSkeleton()),
        error: (e, st) {
          debugPrint('Fiche film $movieId — chargement impossible : $e\n$st');
          return DetailWithBack(
            child: ErrorRetry(
              title: 'Impossible de charger ce film',
              message: 'Vérifie ta connexion et réessaie.',
              onRetry: () => ref.invalidate(movieDetailProvider(movieId)),
            ),
          );
        },
        data: (m) => _Content(movie: m),
      ),
    );
  }
}

/// Attente ou erreur d'une fiche, avec le retour flottant de la coquille.
///
/// Seule la coquille cinématique posait le bouton retour : tant que la fiche
/// n'était pas chargée — ou quand elle ne se chargeait pas — l'écran n'offrait
/// aucune issue visible. Sur Android le geste système suffit ; sur iOS, seul
/// le balayage depuis le bord restait, et rien ne l'indiquait.
class DetailWithBack extends StatelessWidget {
  const DetailWithBack({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 0,
          left: 0,
          child: CinematicBackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({required this.movie});
  final MovieDetail movie;
  @override
  ConsumerState<_Content> createState() => _ContentState();
}

class _ContentState extends ConsumerState<_Content> {
  bool _revealed = false, _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Modification impossible. Réessaie.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    if (!await addMovieToLibrary(ref, widget.movie.id)) {
      throw StateError('Ajout impossible');
    }
  }

  Future<void> _toggle(Movie? movie) => _run(() async {
        if (movie == null) {
          final yes = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                      title: const Text('Ajouter à ma liste'),
                      content: const Text(
                          'Ajoute ce film à ta collection avant de suivre son visionnage.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Ajouter'))
                      ]));
          if (yes == true && mounted) await _add();
          return;
        }
        final db = ref.read(databaseProvider);
        await db.toggleMovieWatched(movie);
        final saved = await db.movieById(movie.id);
        if (!mounted) return;
        setState(() => _revealed = false);
        if (movie.watchedAt == null && saved?.watchedAt != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Visionnage enregistré.'),
              action: SnackBarAction(
                  label: 'Annuler',
                  onPressed: () => _run(() async {
                        final current = await db.movieById(movie.id);
                        if (current != null &&
                            current.watchedAt == saved!.watchedAt) {
                          await db.toggleMovieWatched(current);
                        }
                      }))));
        }
      });
  Future<void> _manage(Movie? movie) async {
    if (movie == null) {
      await _run(_add);
      return;
    }
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Retirer ce film ?'),
                content: Text(
                    '« ${movie.title} » et son visionnage seront retirés de ta collection.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Retirer'))
                ]));
    if (yes == true && mounted) {
      await _run(() => ref.read(databaseProvider).deleteMovie(movie.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final local = ref
        .watch(moviesProvider)
        .value
        ?.where((m) => m.id == movie.id)
        .firstOrNull;
    final seen = local?.watchedAt != null, visible = seen || _revealed;
    final overview = movie.overview?.trim() ?? '';
    final gap = MediaQuery.sizeOf(context).width < 370 ? 17.0 : 23.0;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child: ValidatedDetailHero(
              title: movie.title,
              film: true,
              sources: [movie.poster, movie.backdrop],
              kicker: movie.genres.take(2).join(' · '),
              subtitle: movie.originalTitle ?? '',
              onManage: _busy ? null : () => _manage(local))),
      SliverPadding(
          padding: EdgeInsets.fromLTRB(gap, 9, gap, bottomNavInset(context)),
          sliver: SliverList.list(children: [
            Row(children: [
              Expanded(
                  child: Text(
                      [
                        if (movie.year != null) movie.year!,
                        if (movie.runtime != null) fmtTime(movie.runtime!)
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFB9ACB7)))),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2D2437),
                      borderRadius: BorderRadius.circular(15)),
                  child: Text(seen ? 'Vu' : 'À voir',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFD1B3ED))))
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: ModernCommand(
                      shape: CommandShape.softCheck,
                      height: 63,
                      selected: seen,
                      label: seen ? 'Film vu' : 'Marquer vu',
                      onPressed: _busy ? null : () => _toggle(local))),
              const SizedBox(width: 9),
              SizedBox(
                  width: 64,
                  child: Semantics(
                      label: local == null
                          ? 'Ajouter à ma liste'
                          : 'Film dans ma liste',
                      child: ModernCommand(
                          shape: CommandShape.attach,
                          height: 63,
                          compact: true,
                          label: '',
                          selected: local != null,
                          onPressed: _busy
                              ? null
                              : local != null
                                  ? () {}
                                  : () => _run(_add))))
            ]),
            const SizedBox(height: 12),
            Text(
                seen
                    ? 'Vu le ${frenchDate(local!.watchedAt!)}'
                    : 'Un film à retrouver dans ta collection.',
                style: const TextStyle(fontSize: 11, color: Color(0xFFB2C6A0))),
            const SizedBox(height: 25),
            DetailSectionHeading('L’histoire',
                hint: visible ? 'Résumé affiché' : 'À révéler'),
            const SizedBox(height: 12),
            if (overview.isEmpty)
              const Text('Synopsis indisponible.',
                  style: TextStyle(color: TtColors.dim))
            else if (!visible)
              FilledButton.tonal(
                  onPressed: () => setState(() => _revealed = true),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 80),
                      backgroundColor: const Color(0xFF1D1B22),
                      foregroundColor: const Color(0xFFD1BFDF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18))),
                  child: const Wrap(spacing: 9, children: [
                    Icon(Icons.visibility_outlined, size: 16),
                    Text('Révéler le résumé')
                  ]))
            else
              EntranceFade(
                  child: Text(overview,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.8,
                          color: Color(0xFFB9AEBB)))),
            if (visible && !seen && overview.isNotEmpty)
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: () => setState(() => _revealed = false),
                      child: const Text('Masquer le résumé'))),
            const SizedBox(height: 25),
            if (movie.releaseDate != null)
              MediaFactRow(
                  label: 'Sortie', value: frenchDate(movie.releaseDate!)),
            if (movie.director != null)
              MediaFactRow(label: 'Réalisation', value: movie.director!),
            if (movie.studio != null)
              MediaFactRow(label: 'Studio', value: movie.studio!),
            if (movie.cast.isNotEmpty)
              MediaFactRow(label: 'Avec', value: movie.cast.take(4).join(', ')),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () {
                  ref.read(homeTabProvider.notifier).select(HomeTab.explorer);
                  context.go('/');
                },
                child: const Text('Trouver ma prochaine histoire ↗')),
          ])),
    ]);
  }
}

/// Silhouette de fiche : en-tête, titre, action, synopsis.
class MediaDetailSkeleton extends StatelessWidget {
  const MediaDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SkeletonBox(height: 230, radius: 0),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 26, radius: 6),
              SizedBox(height: 10),
              SkeletonBox(width: 200, height: 14, radius: 4),
              SizedBox(height: 20),
              SkeletonBox(width: 190, height: 46, radius: 12),
              SizedBox(height: 28),
              SkeletonBox(height: 14, radius: 4),
              SizedBox(height: 8),
              SkeletonBox(height: 14, radius: 4),
              SizedBox(height: 8),
              SkeletonBox(width: 240, height: 14, radius: 4),
            ],
          ),
        ),
      ],
    );
  }
}
