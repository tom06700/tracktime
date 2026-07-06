import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';

class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Importer une sauvegarde',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text(
                  'Étape 2 : import du backup JSON de la version web '
                  "et de l'export TV Time (CSV/JSON), avec correspondance TMDB.",
                  style: TextStyle(
                      fontSize: 13, color: TtColors.dim, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
