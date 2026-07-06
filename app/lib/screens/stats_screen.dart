import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    return stats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.error_outline, message: '$e'),
      data: (s) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              child: Column(
                children: [
                  const Text(
                    'TEMPS TOTAL DE VISIONNAGE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: TtColors.dim,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fmtTime(s.totalMinutes),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: TtColors.amber,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.55,
              children: [
                _StatCard(
                  icon: Icons.tv,
                  value: '${s.episodeCount}',
                  label: 'épisodes vus',
                  sub: fmtTime(s.tvMinutes),
                ),
                _StatCard(
                  icon: Icons.movie_outlined,
                  value: '${s.moviesSeen}',
                  label: 'films vus',
                  sub: fmtTime(s.movieMinutes),
                ),
                _StatCard(
                  icon: Icons.collections_bookmark_outlined,
                  value: '${s.showCount}',
                  label: 'séries suivies',
                  sub: '${s.doneShowCount} terminées',
                ),
                _StatCard(
                  icon: Icons.bookmark_outline,
                  value: '${s.watchlistCount}',
                  label: 'films à voir',
                  sub: 'dans la watchlist',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.sub,
  });

  final IconData icon;
  final String value;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: TtColors.text),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(fontSize: 12.5, color: TtColors.dim)),
          Text(sub,
              style: const TextStyle(fontSize: 11.5, color: TtColors.dim)),
        ],
      ),
    );
  }
}
