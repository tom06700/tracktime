import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../shell.dart';
import '../widgets/portal/portal_preview_scope.dart';

/// A development-only entry to inspect empty states on a populated phone.
/// The same HomeShell handles the passage and the real Explorer destination.
class PortalPreviewScreen extends StatelessWidget {
  const PortalPreviewScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Aperçu du portail', style: TextStyle(fontSize: 17)),
    ),
    body: ProviderScope(
      overrides: [homeTabProvider.overrideWith(HomeTabNotifier.new)],
      child: const PortalPreviewScope(child: HomeShell()),
    ),
  );
}
