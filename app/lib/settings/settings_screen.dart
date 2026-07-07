import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _keyController = TextEditingController();
  final _tvdbController = TextEditingController();
  bool _initialized = false;
  bool _tvdbInitialized = false;
  bool _tvdbTesting = false;

  @override
  void dispose() {
    _keyController.dispose();
    _tvdbController.dispose();
    super.dispose();
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
    final keyValue = ref.watch(tmdbKeyProvider).value;
    if (!_initialized && keyValue != null) {
      _keyController.text = keyValue;
      _initialized = true;
    }
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Clé API TMDB',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text(
                    'Gratuite : compte sur themoviedb.org → Paramètres → API '
                    '→ « Clé d\'API » (v3). Elle sert uniquement aux '
                    'affiches, épisodes et durées.',
                    style: TextStyle(
                        fontSize: 13, color: TtColors.dim, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Colle ta clé API v3…',
                      filled: true,
                      fillColor: TtColors.surfaceHi,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ProminentGlassButton(
                      onPressed: () async {
                        await ref
                            .read(tmdbKeyProvider.notifier)
                            .save(_keyController.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Clé enregistrée ✓')));
                        }
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                    'Source de métadonnées alternative (séries et films). '
                    'Clé projet v4 depuis thetvdb.com → Dashboard → API.',
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
              'ailleurs que TMDB (métadonnées).\n\n'
              'Ce produit utilise l\'API TMDB mais n\'est ni approuvé ni '
              'certifié par TMDB.\n'
              'This product uses the TMDB API but is not endorsed or '
              'certified by TMDB.\nthemoviedb.org',
              style:
                  TextStyle(fontSize: 13, color: TtColors.dim, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
