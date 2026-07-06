import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'show_detail_screen.dart';

class ShowsScreen extends ConsumerWidget {
  const ShowsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shows = ref.watch(showsProvider);
    return shows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        debugPrint('DB error: $e\n$st');
        return EmptyState(icon: Icons.error_outline, message: '$e');
      },
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.tv,
            message:
                "Aucune série pour l'instant.\nAjoute-en via la recherche ou importe ton export TV Time.",
          );
        }
        final inProgress = list.where((s) => !s.isDone).toList();
        final done = list.where((s) => s.isDone).toList();
        return ListView(
          padding: EdgeInsets.only(bottom: bottomNavInset(context)),
          children: [
            if (inProgress.isNotEmpty) const SectionLabel('En cours'),
            ...inProgress.map((s) => _ShowCard(s)),
            if (done.isNotEmpty) const SectionLabel('Terminées / à jour'),
            ...done.map((s) => _ShowCard(s)),
          ],
        );
      },
    );
  }
}

class _ShowCard extends StatelessWidget {
  const _ShowCard(this.item);

  final ShowWithProgress item;

  @override
  Widget build(BuildContext context) {
    final show = item.show;
    final total = show.totalEpisodes;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ShowDetailScreen(showId: show.id, title: show.name),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PosterBox(posterPath: show.poster, fallbackIcon: Icons.tv),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.watchedCount}${total != null ? ' / $total' : ''} épisodes vus',
                      style:
                          const TextStyle(fontSize: 12.5, color: TtColors.dim),
                    ),
                    const SizedBox(height: 8),
                    ThinProgressBar(value: item.progress),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: TtColors.dim),
            ],
          ),
        ),
      ),
    );
  }
}
