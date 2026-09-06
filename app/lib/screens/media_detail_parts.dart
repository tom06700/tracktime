import '../widgets/modern_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../brand/nitrate_brand.dart';
import '../tmdb/add.dart';

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
/// Ligne d'informations sous le fond d'une fiche : titre d'origine s'il
/// diffère, puis année, durée et genres.
///
/// Le titre principal n'y figure pas : il est posé sur le fond, et le répéter
/// juste en dessous ferait doublon.
class MediaDetailMeta extends StatelessWidget {
  const MediaDetailMeta({
    super.key,
    required this.metaLine,
    this.originalTitle,
  });

  final String metaLine;

  /// Titre d'origine, affiché uniquement s'il diffère du titre affiché.
  final String? originalTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (originalTitle != null)
          Text(
            originalTitle!,
            style: const TextStyle(fontSize: 13.5, color: TtColors.dim),
          ),
        if (metaLine.isNotEmpty) ...[
          if (originalTitle != null) const SizedBox(height: 4),
          Text(
            metaLine,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: TtColors.dim,
            ),
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
        style: NitrateBrand.display(28).copyWith(height: 1.15),
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
    bool ok;
    try {
      ok = await widget.onAdd();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(widget.failureMessage)));
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 255,
      child: ModernCommand(
          shape: CommandShape.attach,
          label: widget.inLibrary ? 'Dans ma liste' : widget.label,
          selected: widget.inLibrary,
          onPressed: _busy || widget.inLibrary ? null : _add));
}
