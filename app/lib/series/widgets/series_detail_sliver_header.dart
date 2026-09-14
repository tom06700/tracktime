import 'package:flutter/material.dart';
import '../../widgets/modern_controls.dart';
import '../../widgets/validated_detail.dart';

/// The existing cover becomes a compact navigation bar as its sliver collapses.
class SeriesDetailSliverHeader extends StatelessWidget {
  const SeriesDetailSliverHeader({
    super.key,
    required this.title,
    required this.sources,
    required this.onManage,
    this.kicker = '',
    this.subtitle = '',
  });

  final String title, kicker, subtitle;
  final List<String?> sources;
  final VoidCallback onManage;

  static double toolbarHeightOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(20).clamp(20.0, 44.0) + 36;

  static double collapsedExtentOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + toolbarHeightOf(context);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final toolbar = toolbarHeightOf(context);
    final hero = ValidatedDetailHero(
      title: title,
      sources: sources,
      kicker: kicker,
      subtitle: subtitle,
      showNavigation: false,
    );
    final expanded = hero.heightFor(context);
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      toolbarHeight: toolbar,
      collapsedHeight: toolbar,
      expandedHeight: expanded - top,
      backgroundColor: ModernPalette.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 64,
      leading: Center(
        child: IconButton.filledTonal(
          tooltip: 'Retour',
          onPressed: () => Navigator.maybePop(context),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xBC15171B),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.arrow_back, size: 20),
        ),
      ),
      actions: [
        IconButton.filledTonal(
          tooltip: 'Gérer',
          onPressed: onManage,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xBC15171B),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.more_horiz, size: 20),
        ),
        const SizedBox(width: 12),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final collapse =
              ((expanded - constraints.maxHeight) / (expanded - top - toolbar))
                  .clamp(0.0, 1.0);
          final titleOpacity = ((collapse - .7) / .3).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: hero,
              ),
              // An opaque backing keeps the small title legible over any poster.
              IgnorePointer(
                child: Opacity(
                  opacity: titleOpacity,
                  child: ColoredBox(color: ModernPalette.background),
                ),
              ),
              if (titleOpacity > 0)
                Positioned(
                  top: top,
                  left: 68,
                  right: 68,
                  height: toolbar,
                  child: Center(
                    child: Opacity(
                      opacity: titleOpacity,
                      child: Text(
                        title,
                        key: const ValueKey('series-compact-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF4F2F8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
