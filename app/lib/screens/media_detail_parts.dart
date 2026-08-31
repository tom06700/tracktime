import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../tmdb/add.dart';
import '../widgets/media_image.dart';

/// Ajoute une série et renvoie false si TheTVDB refuse.
Future<bool> addSeriesToLibrary(WidgetRef ref, int id) async {
  try {
    await addShowFromTvdb(
      ref.read(databaseProvider),
      ref.read(tvdbClientProvider),
      id,
    );
    return true;
  } catch (e, st) {
    debugPrint('Ajout série $id impossible : $e\n$st');
    return false;
  }
}

Future<bool> addMovieToLibrary(WidgetRef ref, int id) async {
  try {
    await addMovieFromTvdb(
      ref.read(databaseProvider),
      ref.read(tvdbClientProvider),
      id,
    );
    return true;
  } catch (e, st) {
    debugPrint('Ajout film $id impossible : $e\n$st');
    return false;
  }
}

/// En-tête d'une fiche : fond horizontal, voile, et affiche posée dessus.
class MediaDetailHeader extends StatelessWidget {
  const MediaDetailHeader({
    super.key,
    required this.seed,
    required this.icon,
    this.backdrop,
    this.poster,
  });

  final String? backdrop;
  final String? poster;
  final String seed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Le fond horizontal d'abord ; à défaut l'affiche, puis un dégradé.
          MediaImage(sources: [backdrop, poster], seed: seed, icon: icon),
          const MediaScrim(height: 0.85),
          Positioned(
            left: 20,
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 96,
                height: 144,
                child: MediaImage(
                  sources: [poster, backdrop],
                  seed: seed,
                  icon: icon,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MediaDetailTitle extends StatelessWidget {
  const MediaDetailTitle({
    super.key,
    required this.title,
    required this.metaLine,
    this.originalTitle,
  });

  final String title;
  final String metaLine;

  /// Titre d'origine, affiché en second uniquement s'il diffère.
  final String? originalTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: TtColors.text,
          ),
        ),
        if (originalTitle != null) ...[
          const SizedBox(height: 3),
          Text(
            originalTitle!,
            style: const TextStyle(fontSize: 13.5, color: TtColors.dim),
          ),
        ],
        if (metaLine.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            metaLine,
            style: const TextStyle(fontSize: 13.5, color: TtColors.dim),
          ),
        ],
      ],
    );
  }
}

class MediaSectionTitle extends StatelessWidget {
  const MediaSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: TtColors.text,
    ),
  );
}

/// Ligne « libellé : valeur ». Le texte s'enroule au lieu d'être tronqué,
/// pour rester lisible avec un texte agrandi.
class MediaFactRow extends StatelessWidget {
  const MediaFactRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: TtColors.dim),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: TtColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action principale d'une fiche : ajouter, puis constater l'appartenance.
/// La fiche reste ouverte après l'ajout — on peut continuer à la lire.
class AddToListButton extends ConsumerStatefulWidget {
  const AddToListButton({
    super.key,
    required this.label,
    required this.inLibrary,
    required this.onAdd,
    required this.failureMessage,
  });

  final String label;
  final bool inLibrary;

  /// Renvoie false en cas d'échec, pour afficher un message compréhensible.
  final Future<bool> Function() onAdd;

  final String failureMessage;

  @override
  ConsumerState<AddToListButton> createState() => _AddToListButtonState();
}

class _AddToListButtonState extends ConsumerState<AddToListButton> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy || widget.inLibrary) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final ok = await widget.onAdd();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(widget.failureMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final done = widget.inLibrary;

    return Semantics(
      button: true,
      label: done ? 'Déjà dans ta liste' : widget.label,
      child: GestureDetector(
        onTap: _add,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          // Pas de hauteur fixe : le libellé doit pouvoir grandir.
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: done ? Colors.transparent : TtColors.amber,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done ? TtColors.amber.withValues(alpha: 0.55) : TtColors.amber,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TtColors.bg,
                  ),
                )
              else
                Icon(
                  done ? Icons.check : Icons.add,
                  size: 19,
                  color: done ? TtColors.amber : TtColors.bg,
                ),
              const SizedBox(width: 8),
              Text(
                done ? 'Dans ma liste' : widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: done ? TtColors.amber : TtColors.bg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
