import 'package:flutter/material.dart';

import '../theme.dart';

String tmdbImageUrl(String path, {String size = 'w154'}) =>
    'https://image.tmdb.org/t/p/$size$path';

/// Marge basse à réserver dans les vues défilantes pour que le dernier
/// élément puisse remonter au-dessus de la nav bar flottante (le contenu
/// intermédiaire, lui, passe derrière la barre translucide).
double bottomNavInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 92;

const _frMonths = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
  'août', 'septembre', 'octobre', 'novembre', 'décembre'
];

/// "12 juillet 2026".
String frenchDate(DateTime d) => '${d.day} ${_frMonths[d.month - 1]} ${d.year}';

/// "3 j 4 h", "2 h 05", "42 min" — même format que la version web.
String fmtTime(int min) {
  final d = min ~/ 1440, h = (min % 1440) ~/ 60, m = min % 60;
  if (d > 0) return '$d j $h h';
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')}';
  return '$m min';
}

/// Encart de section en capsule grise centrée, façon TV Time — pensé pour
/// chevaucher (« glisser par-dessus ») le haut de la première carte.
class SectionPill extends StatelessWidget {
  const SectionPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xF23B414D),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.anchor});

  final String text;

  /// Clé posée sur le libellé pour s'y aligner (ex. ouverture au « À voir »).
  final Key? anchor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: anchor,
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
  const PosterBox({
    super.key,
    this.posterPath,
    required this.fallbackIcon,
    this.small = false,
    this.label,
  });

  final String? posterPath;
  final IconData fallbackIcon;
  final bool small;

  /// Titre servant à teinter le placeholder (dégradé stable par titre)
  /// quand il n'y a pas d'affiche.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final w = small ? 44.0 : 52.0;
    final h = small ? 66.0 : 78.0;
    final radius = BorderRadius.circular(10);
    final placeholder = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: label == null ? TtColors.surfaceHi : null,
        gradient: label == null ? null : _posterGradient(label!),
      ),
      child: Icon(fallbackIcon,
          color: label == null
              ? TtColors.dim
              : Colors.white.withValues(alpha: 0.8),
          size: 22),
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

  static Gradient _posterGradient(String seed) {
    final hue = (seed.codeUnits.fold<int>(0, (a, c) => a * 31 + c) % 360)
        .toDouble();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor(),
        HSLColor.fromAHSL(1, (hue + 40) % 360, 0.60, 0.26).toColor(),
      ],
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
