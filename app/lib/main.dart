import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(retry: _noRetry, child: NitrateApp()));
}

/// Riverpod 3 relance de lui-même tout provider en échec, jusqu'à dix fois,
/// et repasse l'écran en attente entre deux essais : une fiche introuvable
/// clignotait entre erreur et squelette pendant une minute, pour dix 404. La
/// politique de réessai vit déjà dans le client TheTVDB — bornée, réservée
/// aux pannes passagères — et n'a pas besoin d'un second étage.
Duration? _noRetry(int retryCount, Object error) => null;

class NitrateApp extends StatelessWidget {
  const NitrateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nitrate',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
