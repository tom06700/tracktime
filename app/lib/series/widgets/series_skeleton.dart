import 'package:flutter/material.dart';

import '../../widgets/skeleton.dart';

/// Silhouette de l'écran Séries pendant le chargement : elle reprend la
/// structure réelle — héros, carrousel, reprises — pour que rien ne bouge
/// quand les données arrivent.
class SeriesSkeleton extends StatelessWidget {
  const SeriesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: SkeletonBox(radius: 18),
          ),
        ),
        const SizedBox(height: 30),
        const _SectionTitleSkeleton(),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, _) => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 216, height: 121, radius: 14),
                SizedBox(height: 9),
                SkeletonBox(width: 150, height: 13, radius: 4),
                SizedBox(height: 6),
                SkeletonBox(width: 96, height: 11, radius: 4),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        const _SectionTitleSkeleton(),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 118, height: 177, radius: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 100, height: 12, radius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitleSkeleton extends StatelessWidget {
  const _SectionTitleSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SkeletonBox(width: 128, height: 17, radius: 5),
    );
  }
}
