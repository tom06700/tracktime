import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import 'glass.dart';

const double _titleRow = 52;
const double _tabsRow = 44;
const double _tabsBottomGap = 7;
const double _topGap = 8;
const double _bottomGap = 12;

/// Marge haute à réserver pour que le contenu démarre sous le bandeau
/// flottant. Le contenu ne passe volontairement PAS derrière : les listes
/// utilisent des en-têtes collants, qui se figeraient en haut du viewport,
/// donc sous le verre, et deviendraient illisibles.
double glassHeaderInset(BuildContext context, {bool withTabs = false}) =>
    MediaQuery.paddingOf(context).top +
    _topGap +
    _titleRow +
    (withTabs ? _tabsRow + _tabsBottomGap : 0) +
    _bottomGap;

/// Bandeau flottant « Liquid Glass », jumeau de la barre de navigation :
/// même pilule translucide (flou, vibrance, lensing, arête spéculaire), posée
/// en haut. Les onglets de la page, s'il y en a, se logent dedans plutôt que
/// de former une seconde barre.
class GlassHeader extends StatelessWidget {
  const GlassHeader({super.key, this.tabs});

  /// Onglets affichés dans la pilule. Doit être placé sous un TabController
  /// (le widget est construit dans le sous-arbre du DefaultTabController).
  final Widget? tabs;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, safeTop + _topGap, 20, 0),
      child: GlassShadow(
        borderRadius: 28,
        child: GlassSurface(
          borderRadius: 28,
          blurSigma: 16,
          tintOpacity: 0.52,
          lensing: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _titleRow,
                child: Row(
                  children: [
                    const SizedBox(width: 18),
                    const _Wordmark(),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 21),
                      color: TtColors.text,
                      tooltip: 'Réglages',
                      onPressed: () => context.push('/settings'),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              if (tabs != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: _tabsBottomGap),
                  child: SizedBox(height: _tabsRow, child: tabs),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « NITRATE » en capitales espacées : un carton de générique plutôt qu'un
/// titre d'application.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'NITRATE',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 3.5,
        color: TtColors.amber,
      ),
    );
  }
}
