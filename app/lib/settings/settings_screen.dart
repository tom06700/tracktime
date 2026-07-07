import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../tmdb/tvdb.dart';
import '../widgets/glass.dart';
import 'prefs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _tvdbController = TextEditingController();
  bool _tvdbInitialized = false;
  bool _tvdbTesting = false;

  @override
  void dispose() {
    _tvdbController.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _testTvdb() async {
    final key = _tvdbController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (key.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Colle d\'abord ta clé TheTVDB.')));
      return;
    }
    await ref.read(tvdbKeyProvider.notifier).save(key);
    setState(() => _tvdbTesting = true);
    try {
      final r = await TvdbClient(key).ping();
      messenger.showSnackBar(SnackBar(
        content: Text('TheTVDB connecté ✓ — ${r.count} résultats '
            '(ex. « ${r.sample} »)'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Échec TheTVDB : $e')));
    } finally {
      if (mounted) setState(() => _tvdbTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tvdbValue = ref.watch(tvdbKeyProvider).value;
    if (!_tvdbInitialized && tvdbValue != null) {
      _tvdbController.text = tvdbValue;
      _tvdbInitialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Clé TheTVDB ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Clé API TheTVDB',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text(
                    'Nécessaire pour rechercher, ajouter et synchroniser tes '
                    'séries et films (affiches, épisodes, durées). Clé projet '
                    'v4 depuis thetvdb.com → Dashboard → API.',
                    style: TextStyle(
                        fontSize: 13, color: TtColors.dim, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tvdbController,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Colle ta clé projet TheTVDB…',
                      filled: true,
                      fillColor: TtColors.surfaceHi,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ProminentGlassButton(
                        onPressed: () async {
                          await ref
                              .read(tvdbKeyProvider.notifier)
                              .save(_tvdbController.text);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Clé enregistrée ✓')));
                          }
                        },
                        child: const Text('Enregistrer'),
                      ),
                      const SizedBox(width: 10),
                      GlassButton(
                        onPressed: _tvdbTesting ? null : _testTvdb,
                        child: Text(
                            _tvdbTesting ? 'Test…' : 'Tester la connexion'),
                      ),
                    ],
                  ),
                  // Attribution requise par TheTVDB (lien direct obligatoire).
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: TtColors.surfaceHi),
                  const SizedBox(height: 12),
                  const Text(
                    'Metadata provided by TheTVDB. Please consider adding '
                    'missing information or subscribing.\n'
                    'Métadonnées fournies par TheTVDB — pense à compléter les '
                    'informations manquantes ou à t\'abonner.',
                    style: TextStyle(
                        fontSize: 12.5, color: TtColors.dim, height: 1.6),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _LinkChip(
                        label: 'TheTVDB.com',
                        onTap: () => _open('https://thetvdb.com'),
                      ),
                      _LinkChip(
                        label: 'S\'abonner',
                        onTap: () => _open('https://thetvdb.com/subscribe'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text('IMPORT / RESTAURATION',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: TtColors.dim)),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download_outlined, color: TtColors.amber),
              title: const Text('Importer des données',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Backup TrackTime (JSON) ou export TV Time (CSV/JSON)',
                  style: TextStyle(fontSize: 12.5, color: TtColors.dim)),
              trailing: const Icon(Icons.chevron_right, color: TtColors.dim),
              onTap: () => context.push('/import'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'TrackTime — 100 % local, aucun compte, aucune donnée envoyée '
              'ailleurs que TheTVDB (métadonnées).\n\n'
              'Metadata provided by TheTVDB.com. TrackTime n\'est ni approuvé '
              'ni certifié par TheTVDB.',
              style:
                  TextStyle(fontSize: 13, color: TtColors.dim, height: 1.6),
            ),
          ),
        ],
      ),
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
                  color: TtColors.amber),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new, size: 13, color: TtColors.amber),
          ],
        ),
      ),
    );
  }
}
