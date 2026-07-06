import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../backup/backup.dart';
import '../profile/profile.dart';
import '../providers.dart';
import '../settings/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/stats_summary.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
    'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final statsAsync = ref.watch(statsProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(0, 8, 0, bottomNavInset(context)),
      children: [
        profileAsync.when(
          loading: () => const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) =>
              EmptyState(icon: Icons.error_outline, message: '$e'),
          data: (profile) => _IdentityCard(profile: profile),
        ),
        const SectionLabel('Mes chiffres'),
        statsAsync.when(
          loading: () => const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator())),
          error: (e, _) =>
              EmptyState(icon: Icons.error_outline, message: '$e'),
          data: (stats) => StatsSummary(stats: stats),
        ),
        const SectionLabel('Mes données'),
        Card(
          child: Column(
            children: [
              _ActionTile(
                icon: Icons.ios_share,
                title: 'Exporter mes données',
                subtitle: 'Sauvegarde JSON (compatible avec l\'import)',
                onTap: () => _export(context, ref),
              ),
              const _TileDivider(),
              _ActionTile(
                icon: Icons.download_outlined,
                title: 'Importer / restaurer',
                subtitle: 'Backup TrackTime ou export TV Time',
                onTap: () => context.push('/import'),
              ),
              const _TileDivider(),
              _ActionTile(
                icon: Icons.key_outlined,
                title: 'Clé API TMDB',
                subtitle: 'Réglages de connexion à TMDB',
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            'TrackTime — 100 % local, aucun compte, aucune donnée envoyée '
            'ailleurs que TMDB (métadonnées).\n\n'
            'Ce produit utilise l\'API TMDB mais n\'est ni approuvé ni '
            'certifié par TMDB.',
            style: TextStyle(fontSize: 12.5, color: TtColors.dim, height: 1.6),
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final key = ref.read(tmdbKeyProvider).value ?? '';
      await exportBackup(ref.read(databaseProvider), tmdbKey: key);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Export impossible : $e')));
    }
  }

  static String memberSince(DateTime since) =>
      'Membre depuis ${_months[since.month - 1]} ${since.year}';
}

class _IdentityCard extends ConsumerWidget {
  const _IdentityCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _pickEmoji(context, ref),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: TtColors.surfaceHi,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(profile.emoji,
                    style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ProfileScreen.memberSince(profile.since),
                    style:
                        const TextStyle(fontSize: 12.5, color: TtColors.dim),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: TtColors.dim),
              tooltip: 'Modifier le nom',
              onPressed: () => _editName(context, ref, profile.name),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ton nom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: 'Ex. Thomas'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (name != null) {
      await ref.read(profileProvider.notifier).setName(name);
    }
  }

  Future<void> _pickEmoji(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TtColors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choisis ton avatar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in avatarChoices)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, e),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: e == profile.emoji
                            ? TtColors.amber.withValues(alpha: 0.18)
                            : TtColors.surfaceHi,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) {
      await ref.read(profileProvider.notifier).setEmoji(choice);
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: TtColors.amber),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12.5, color: TtColors.dim)),
      trailing: const Icon(Icons.chevron_right, color: TtColors.dim),
      onTap: onTap,
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 56, color: TtColors.surfaceHi);
}
