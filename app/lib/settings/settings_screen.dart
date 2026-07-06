import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/glass.dart';
import 'prefs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _keyController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyValue = ref.watch(tmdbKeyProvider).value;
    if (!_initialized && keyValue != null) {
      _keyController.text = keyValue;
      _initialized = true;
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
