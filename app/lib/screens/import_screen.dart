import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backup/backup_format.dart';
import '../backup/restore.dart';
import '../import/importer.dart';
import '../import/parser.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Page autonome (avec AppBar) enveloppant [ImportScreen], à pousser depuis
/// les Réglages ou le Profil.
class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer des données')),
      body: const ImportScreen(),
    );
  }
}

/// Fin de l'export de données chez TV Time.
final kTvTimeExportDeadline = DateTime(2026, 7, 15);

/// Ce que l'écran d'import dit de TV Time, selon la date.
///
/// Avant l'échéance : presser l'utilisateur d'exporter. Après : ne plus
/// afficher un compte à rebours périmé — l'app se retrouvait à demander
/// d'exporter « avant le 15 juillet » en septembre.
String tvTimeNotice(DateTime now) => now.isBefore(kTvTimeExportDeadline)
    ? '⏳ Exporte tes données TV Time avant le 15 juillet 2026 sur '
        'gdpr.tvtime.com — après, tout est supprimé définitivement.'
    : 'TV Time a cessé de fournir ses exports le 15 juillet 2026. Si tu as '
        'gardé tes fichiers CSV ou JSON, ils s\'importent toujours ici.';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, this.now});

  /// Date de référence, injectable pour les tests.
  final DateTime? now;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final ParsedData _parsed = ParsedData();
  final List<String> _log = [];
  bool _importing = false;
  bool _legacy = false;
  double _pct = 0;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['csv', 'json', 'txt'],
      withData: true,
    );
    if (result == null) return;

    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) {
        _log.add('⚠️ ${f.name} : lecture impossible');
        continue;
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      switch (parseFile(_parsed, text)) {
        case BackupFileFound(:final backup):
          await _restore(f.name, backup);
        case EntriesAdded(:final count):
          _log.add('✅ ${f.name} : $count entrées détectées');
        case UnrecognizedFile():
          _log.add('⚠️ ${f.name} : format non reconnu');
      }
    }
    if (mounted) setState(() {});
  }

  /// Restaure une sauvegarde. Une sauvegarde Nitrate est rétablie telle quelle ;
  /// une ancienne sauvegarde TrackTime doit d'abord retrouver ses œuvres sur
  /// TheTVDB, ce qui prend un moment et passe donc par la barre de progression.
  Future<void> _restore(String fileName, BackupFile backup) async {
    final db = ref.read(databaseProvider);
    switch (backup) {
      case UnsupportedBackup(:final message):
        _log.add('❌ $fileName : $message');
      case NitrateBackup():
        final report = await restoreNitrateBackup(db, backup);
        _log
          ..addAll(report.lines)
          ..add('🎉 $fileName : ${report.summary}');
      case LegacyBackup():
        setState(() {
          _legacy = true;
          _importing = true;
          _pct = 0;
        });
        final report = await restoreLegacyBackup(
          db,
          ref.read(tvdbClientProvider),
          backup,
          onProgress: (pct, line) {
            if (!mounted) return;
            setState(() {
              _pct = pct;
              if (line != null) _log.add(line);
            });
          },
        );
        if (!mounted) return;
        setState(() {
          _importing = false;
          _log.add('🎉 $fileName : ${report.summary}');
        });
    }
  }

  Future<void> _runImport() async {
    setState(() {
      _importing = true;
      _pct = 0;
    });
    try {
      final summary = await runTvTimeImport(
        ref.read(databaseProvider),
        ref.read(tvdbClientProvider),
        _parsed,
        onProgress: (pct, line) {
          if (!mounted) return;
          setState(() {
            _pct = pct;
            if (line != null) _log.add(line);
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _importing = false;
        _log.add(
          '🎉 Import terminé : ${summary.matched} trouvés, ${summary.failed} non résolus.',
        );
        _parsed.clear();
      });
      _toast('Import terminé 🎉');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _log.add('Import interrompu. Tu peux réessayer.');
      });
      _toast('Import impossible. Vérifie ta connexion et réessaie.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Card(
          color: TtColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: TtColors.amber.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              tvTimeNotice(widget.now ?? DateTime.now()),
              style: const TextStyle(fontSize: 13, height: 1.55),
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Importer des données',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sélectionne une sauvegarde (JSON, restaurée '
                  'immédiatement) ou les fichiers de ton export TV Time '
                  '(CSV/JSON, mis en correspondance via TheTVDB).',
                  style: TextStyle(
                    fontSize: 13,
                    color: TtColors.dim,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ProminentGlassButton(
                    onPressed: _importing ? null : _pickFiles,
                    icon: Icons.folder_open,
                    child: const Text('Choisir les fichiers'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_log.isNotEmpty && !_importing)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/series'),
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Voir ma bibliothèque'),
            ),
          ),
        if (_legacy)
          Card(
            color: TtColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: TtColors.amber.withValues(alpha: 0.3)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ancienne sauvegarde TrackTime',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Ses séries doivent être associées à leur fiche TheTVDB '
                    'avant d\'être restaurées. C\'est un peu plus long, et '
                    'les titres trop ambigus sont laissés de côté plutôt que '
                    'rattachés à la mauvaise œuvre.',
                    style: TextStyle(fontSize: 13, height: 1.55),
                  ),
                ],
              ),
            ),
          ),
        if (_legacy && _importing)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _pct,
                      minHeight: 8,
                      backgroundColor: TtColors.surfaceHi,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Correspondance TheTVDB… ${(_pct * 100).round()} %',
                    style: const TextStyle(fontSize: 13, color: TtColors.dim),
                  ),
                ],
              ),
            ),
          ),
        if (!_parsed.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Détecté : ${_parsed.showCount} séries '
                    '(${_parsed.episodeCount} épisodes), '
                    '${_parsed.movies.length} films',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_importing) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _pct,
                        minHeight: 8,
                        backgroundColor: TtColors.surfaceHi,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Correspondance TheTVDB… ${(_pct * 100).round()} %',
                      style: const TextStyle(fontSize: 13, color: TtColors.dim),
                    ),
                  ] else
                    Row(
                      children: [
                        ProminentGlassButton(
                          onPressed: _runImport,
                          child: const Text('Importer via TheTVDB'),
                        ),
                        const SizedBox(width: 8),
                        GlassButton(
                          onPressed: () => setState(_parsed.clear),
                          child: const Text('Vider'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (_log.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _log.reversed.take(40).join('\n'),
                style: const TextStyle(
                  fontSize: 12,
                  color: TtColors.dim,
                  height: 1.7,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
