import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/media_image.dart';
import '../feed.dart';

/// Carte du carrousel « Ensuite » : image large, texte dessous. Plus compacte
/// que le héros, mais toujours menée par l'image.
class NextEpisodeCard extends StatelessWidget {
  const NextEpisodeCard({super.key, required this.next, required this.onTap});

  static const double width = 216;

  final NextUp next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${next.show.name}, ${next.code}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: MediaImage(
                    sources: [next.still, next.show.poster],
                    seed: next.show.name,
                    icon: Icons.tv,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                next.show.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: TtColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                next.episodeName == null || next.episodeName!.isEmpty
                    ? next.code
                    : '${next.code}  ·  ${next.episodeName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: TtColors.dim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte « À reprendre » : une série délaissée. L'affiche verticale convient
/// ici — c'est la série qu'on montre, pas un épisode précis.
class ResumeShowCard extends StatelessWidget {
  const ResumeShowCard({
    super.key,
    required this.next,
    required this.since,
    required this.onTap,
  });

  static const double width = 118;

  final NextUp next;

  /// Dernière activité sur cette série, pour le libellé « il y a … ».
  final DateTime? since;

  final VoidCallback onTap;

  /// « il y a 3 semaines », « il y a 5 mois » — une précision au mois suffit
  /// pour une série qu'on a laissée de côté.
  static String? _ago(DateTime? since, DateTime now) {
    if (since == null) return null;
    final days = now.difference(since).inDays;
    if (days < 21) return 'il y a $days j';
    if (days < 60) return 'il y a ${(days / 7).round()} sem.';
    return 'il y a ${(days / 30).round()} mois';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${next.show.name}, reprendre à ${next.code}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: MediaImage(
                    sources: [next.show.poster, next.still],
                    seed: next.show.name,
                    icon: Icons.tv,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                next.show.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: TtColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [next.code, ?_ago(since, DateTime.now())].join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: TtColors.dim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
