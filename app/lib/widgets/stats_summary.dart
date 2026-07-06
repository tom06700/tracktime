import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme.dart';
import 'common.dart';

/// Bloc « temps total » + grille de 4 tuiles, réutilisable (page Profil).
class StatsSummary extends StatelessWidget {
  const StatsSummary({super.key, required this.stats});

  final WatchStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                  fmtTime(stats.totalMinutes),
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
              StatCard(
                icon: Icons.tv,
                value: '${stats.episodeCount}',
                label: 'épisodes vus',
                sub: fmtTime(stats.tvMinutes),
              ),
              StatCard(
                icon: Icons.movie_outlined,
                value: '${stats.moviesSeen}',
                label: 'films vus',
                sub: fmtTime(stats.movieMinutes),
              ),
              StatCard(
                icon: Icons.collections_bookmark_outlined,
                value: '${stats.showCount}',
                label: 'séries suivies',
                sub: '${stats.doneShowCount} terminées',
              ),
              StatCard(
                icon: Icons.bookmark_outline,
                value: '${stats.watchlistCount}',
                label: 'films à voir',
                sub: 'dans la watchlist',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
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
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 12.5, color: TtColors.dim)),
          Text(sub, style: const TextStyle(fontSize: 11.5, color: TtColors.dim)),
        ],
      ),
    );
  }
}
