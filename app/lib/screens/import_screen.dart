import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/importer.dart';
import '../import/parser.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../settings/settings_screen.dart';
import '../theme.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final ParsedData _parsed = ParsedData();
  final List<String> _log = [];
  bool _importing = false;
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

    final db = ref.read(databaseProvider);
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) {
        _log.add('⚠️ ${f.name} : lecture impossible');
        continue;
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      switch (parseFile(_parsed, text)) {
        case WebBackupFile(:final data):
          final r = await importWebBackup(db, data);
          if (r.tmdbKey != null &&
              (ref.read(tmdbKeyProvider).value ?? '').isEmpty) {
            await ref.read(tmdbKeyProvider.notifier).save(r.tmdbKey!);
            _log.add('🔑 Clé API TMDB récupérée du backup');
          }
          _log.add(
              '✅ ${f.name} : sauvegarde restaurée (${r.shows} séries, ${r.movies} films)');
        case EntriesAdded(:final count):
          _log.add('✅ ${f.name} : $count entrées détectées');
        case UnrecognizedFile():
          _log.add('⚠️ ${f.name} : format non reconnu');
      }
    }
    setState(() {});
  }

  Future<void> _runImport() async {
    final key = ref.read(tmdbKeyProvider).value ?? '';
    if (key.isEmpty) {
      _toast('Ajoute d’abord ta clé TMDB dans ⚙️ Réglages');
      if (mounted) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }
      return;
    }
    setState(() {
      _importing = true;
      _pct = 0;
    });
    final summary = await runTvTimeImport(
      ref.read(databaseProvider),
      ref.read(tmdbClientProvider),
      _parsed,
      onProgress: (pct, line) {
        if (!mounted) return;
        setState(() {
          _pct = pct;
          if (line != null) _log.add(line);
        });
      },
      throttle: () => Future.delayed(const Duration(milliseconds: 120)),
    );
    if (!mounted) return;
    setState(() {
      _importing = false;
      _log.add(
          '🎉 Import terminé : ${summary.matched} trouvés, ${summary.failed} non résolus.');
      _parsed.clear();
    });
    _toast('Import terminé 🎉');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Card(
          color: const Color(0xFF241D10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: TtColors.amber.withValues(alpha: 0.3)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              '⏳ Exporte tes données TV Time avant le 15 juillet 2026 sur '
              'gdpr.tvtime.com — après, tout est supprimé définitivement.',
              style: TextStyle(fontSize: 13, height: 1.55),
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Importer des données',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  'Sélectionne un backup TrackTime (JSON, restauré '
                  'immédiatement) ou les fichiers de ton export TV Time '
                  '(CSV/JSON, mis en correspondance via TMDB).',
                  style: TextStyle(
                      fontSize: 13, color: TtColors.dim, height: 1.6),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _importing ? null : _pickFiles,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choisir les fichiers'),
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
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_importing) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: _pct,
                          minHeight: 8,
                          backgroundColor: TtColors.surfaceHi),
                    ),
                    const SizedBox(height: 6),
                    Text('Correspondance TMDB… ${(_pct * 100).round()} %',
                        style: const TextStyle(
                            fontSize: 13, color: TtColors.dim)),
                  ] else
                    Row(
                      children: [
                        FilledButton(
                          onPressed: _runImport,
                          child: const Text('Importer via TMDB'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
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
                    fontSize: 12, color: TtColors.dim, height: 1.7),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
