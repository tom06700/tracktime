import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../brand/nitrate_brand.dart';
import '../providers.dart';

/// The header signature always returns to the Séries home, without pushing it.
class NitrateHomeButton extends StatelessWidget {
  const NitrateHomeButton({
    super.key,
    this.size = 22,
    this.enabled = true,
    this.beforeHome,
  });

  final double size;
  final bool enabled;
  final Future<void> Function()? beforeHome;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    heightFactor: 1,
    child: Tooltip(
      message: 'Accueil',
      excludeFromSemantics: true,
      child: TextButton(
        onPressed: !enabled
            ? null
            : () async {
                final router = GoRouter.of(context);
                FocusManager.instance.primaryFocus?.unfocus();
                ProviderScope.containerOf(
                  context,
                  listen: false,
                ).read(homeTabProvider.notifier).select(HomeTab.series);
                await beforeHome?.call();
                // Completing onboarding may have removed this button already.
                router.go('/');
              },
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Semantics(
          label: 'Nitrate, accueil',
          child: ExcludeSemantics(child: NitrateWordmark(size: size)),
        ),
      ),
    ),
  );
}
