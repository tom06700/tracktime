import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../backup/backup.dart';
import '../build_info.dart';
import '../db/database.dart';
import '../providers.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.exportData = exportBackup});

  /// Point d'injection pour les tests : la feuille de partage native n'existe
  /// pas dans un test widget. En production, c'est [exportBackup].
  final Future<void> Function(AppDatabase db) exportData;

  Future<void> _open(BuildContext context, String url) async {
    try {
      if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (e) {
      debugPrint('Lien externe indisponible : $e');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir ce lien. Réessaie.')),
      );
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer toutes mes données ?'),
        content: const Text(
          'Toutes tes séries, films et ton historique de visionnage seront '
          'définitivement supprimés de cet appareil. Cette action est '
          'irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).clearAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Toutes tes données ont été effacées.')),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          8,
          0,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        children: [
          // Sauvegarder, puis restaurer, puis effacer : l'ordre du parcours.
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'DONNÉES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: TtColors.dim,
              ),
            ),
          ),
          Card(
            child: _ExportTile(
              onExport: () => exportData(ref.read(databaseProvider)),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.download_outlined,
                color: TtColors.amber,
              ),
              title: const Text(
                'Importer des données',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Sauvegarde Nitrate ou export TV Time',
                style: TextStyle(fontSize: 12.5, color: TtColors.dim),
              ),
              trailing: const Icon(Icons.chevron_right, color: TtColors.dim),
              onTap: () => context.push('/import'),
            ),
          ),

          // ── Zone dangereuse ──
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 4),
            child: Text(
              'SUPPRESSION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: TtColors.dim,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Effacer toutes mes données',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
              subtitle: const Text(
                'Supprime toutes les séries, films et l\'historique',
                style: TextStyle(fontSize: 12.5, color: TtColors.dim),
              ),
              onTap: () => _confirmClearAll(context, ref),
            ),
          ),

          // ── À propos + attribution TheTVDB (lien direct obligatoire) ──
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 4),
            child: Text(
              'À PROPOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: TtColors.dim,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'Nitrate — 100 % local, aucun compte, aucune donnée envoyée '
              'ailleurs que TheTVDB (métadonnées).\n\n'
              'Metadata provided by TheTVDB. Please consider adding missing '
              'information or subscribing. Nitrate n\'est ni approuvé ni '
              'certifié par TheTVDB.',
              style: TextStyle(fontSize: 13, color: TtColors.dim, height: 1.6),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Wrap(
              spacing: 8,
              children: [
                _LinkChip(
                  label: 'TheTVDB.com',
                  onTap: () => _open(context, 'https://thetvdb.com'),
                ),
                _LinkChip(
                  label: 'S\'abonner',
                  onTap: () => _open(context, 'https://thetvdb.com/subscribe'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Text(
              'Version $kBuildMarker',
              style: TextStyle(fontSize: 12, color: TtColors.dim),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne « Exporter mes données ».
///
/// Stateful pour son seul état d'attente : la feuille de partage met un
/// instant à s'ouvrir, et deux taps ne doivent pas produire deux fichiers.
class _ExportTile extends StatefulWidget {
  const _ExportTile({required this.onExport});

  final Future<void> Function() onExport;

  @override
  State<_ExportTile> createState() => _ExportTileState();
}

class _ExportTileState extends State<_ExportTile> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onExport();
      // Pas de message de succès : la feuille de partage peut être annulée,
      // annoncer « sauvegarde enregistrée » serait mentir.
    } catch (e, st) {
      debugPrint('Export de sauvegarde impossible : $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Impossible de créer la sauvegarde. Réessaie.'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: !_busy,
      leading: const Icon(Icons.ios_share_outlined, color: TtColors.amber),
      title: const Text(
        'Exporter mes données',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'Crée une sauvegarde Nitrate de tes séries, films et visionnages',
        style: TextStyle(fontSize: 12.5, color: TtColors.dim),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: TtColors.amber,
              ),
            )
          : const Icon(Icons.chevron_right, color: TtColors.dim),
      onTap: _run,
    );
  }
}

/// Petit lien en pastille (attribution TheTVDB).
class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: TtColors.surfaceHi,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: TtColors.amber.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: TtColors.amber,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new, size: 13, color: TtColors.amber),
          ],
        ),
      ),
    );
  }
}
