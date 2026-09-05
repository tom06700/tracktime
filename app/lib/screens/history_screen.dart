import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../series/feed.dart';
import '../theme.dart';
import '../widgets/editorial_heading.dart';
import '../widgets/media_image.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';

/// Historique de visionnage : tous les épisodes vus, du plus récent au plus
/// ancien. Sorti du fil principal, où il repoussait le contenu à regarder.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(watchHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Épisodes vus'),
        actions: [
          TextButton(
            onPressed: () => context.push('/movie-history'),
            child: const Text('Films vus'),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 8,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              children: [
                SkeletonBox(width: 96, height: 54, radius: 10),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 14, radius: 4),
                      SizedBox(height: 7),
                      SkeletonBox(width: 130, height: 11, radius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        error: (e, st) {
          debugPrint('Historique — chargement impossible : $e\n$st');
          return ErrorRetry(
            title: 'Impossible de charger ton historique',
            message: 'Tes données sont toujours là. '
                'Réessaie dans un instant.',
            onRetry: () => ref.invalidate(showsProvider),
          );
        },
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyPrompt(
              icon: Icons.history,
              title: 'Rien de vu pour l\'instant',
              message: 'Les épisodes que tu marques comme vus '
                  'apparaîtront ici, du plus récent au plus ancien.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length + 1,
            itemBuilder: (context, i) => i == 0
                ? EditorialHeading(
                    eyebrow: '${entries.length} épisodes vus',
                    title: 'Le fil de tes soirées.')
                : _HistoryRow(entry: entries[i - 1]),
          );
        },
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.entry});

  final WatchedEntry entry;

  static const _months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  static String _stamp(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _unwatch(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await ref
        .read(databaseProvider)
        .setEpisodeUnwatched(entry.show.id, entry.season, entry.episode);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('${entry.code} remis à « non vu »')),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: '${entry.show.name}, ${entry.code}, vu le '
          '${_stamp(entry.watchedAt)}',
      child: InkWell(
        onTap: () => context.push(
          '/episode/${entry.show.id}/${entry.season}/${entry.episode}',
          extra: {'name': entry.show.name, 'poster': entry.show.poster},
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 96,
                  height: 54,
                  child: MediaImage(
                    sources: [entry.still, entry.show.poster],
                    seed: entry.show.name,
                    icon: Icons.tv,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => context.push(
                        '/show/${entry.show.id}',
                        extra: entry.show.name,
                      ),
                      child: Text(
                        entry.show.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: TtColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.episodeName == null || entry.episodeName!.isEmpty
                          ? entry.code
                          : '${entry.code}  ·  ${entry.episodeName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: TtColors.dim,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _stamp(entry.watchedAt),
                      style: const TextStyle(fontSize: 12, color: TtColors.dim),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_done, size: 19),
                color: TtColors.dim,
                tooltip: 'Remettre à non vu',
                onPressed: () => _unwatch(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
