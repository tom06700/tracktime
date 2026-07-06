import 'package:flutter/material.dart';

import '../theme.dart';

String tmdbImageUrl(String path, {String size = 'w154'}) =>
    'https://image.tmdb.org/t/p/$size$path';

/// "3 j 4 h", "2 h 05", "42 min" — même format que la version web.
String fmtTime(int min) {
  final d = min ~/ 1440, h = (min % 1440) ~/ 60, m = min % 60;
  if (d > 0) return '$d j $h h';
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')}';
  return '$m min';
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: TtColors.dim,
        ),
      ),
    );
  }
}

class PosterBox extends StatelessWidget {
  const PosterBox({super.key, this.posterPath, required this.fallbackIcon, this.small = false});

  final String? posterPath;
  final IconData fallbackIcon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final w = small ? 44.0 : 52.0;
    final h = small ? 66.0 : 78.0;
    final radius = BorderRadius.circular(10);
    final placeholder = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: TtColors.surfaceHi, borderRadius: radius),
      child: Icon(fallbackIcon, color: TtColors.dim, size: 22),
    );
    final path = posterPath;
    if (path == null || path.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        tmdbImageUrl(path),
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: TtColors.dim),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: TtColors.dim, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: TtColors.surfaceHi,
        color: value >= 1 ? TtColors.teal : TtColors.amber,
      ),
    );
  }
}
