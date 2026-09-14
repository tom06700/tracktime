import 'package:flutter/material.dart';
import '../../widgets/modern_controls.dart';
import 'season_selector.dart';

/// Naturally sized so pinned controls still fit with larger system text.
class SeriesEpisodeControls extends StatelessWidget {
  const SeriesEpisodeControls({
    super.key,
    required this.seasons,
    required this.selected,
    required this.onlyUnseen,
    required this.allSeen,
    required this.onSeasonChanged,
    required this.onFilterChanged,
    this.onToggleSeason,
    this.onJump,
  });
  final List<int> seasons;
  final int? selected;
  final bool onlyUnseen, allSeen;
  final ValueChanged<int?>? onSeasonChanged;
  final ValueChanged<bool> onFilterChanged;
  final VoidCallback? onToggleSeason, onJump;

  @override
  Widget build(BuildContext context) {
    final gap = MediaQuery.sizeOf(context).width < 370 ? 18.0 : 24.0;
    Widget filter(String label, bool unseen) => ChoiceChip(
      label: Text(label),
      showCheckmark: false,
      selected: onlyUnseen == unseen,
      selectedColor: ModernPalette.lilac,
      backgroundColor: const Color(0xFF241E2B),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: TextStyle(
        fontSize: 12,
        color: onlyUnseen == unseen
            ? const Color(0xFF342453)
            : const Color(0xFFB7A6C4),
      ),
      onSelected: (_) => onFilterChanged(unseen),
    );
    return Material(
      color: ModernPalette.background,
      child: Container(
        padding: EdgeInsets.fromLTRB(gap, 12, gap, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF29262E))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected != null) ...[
              Row(
                children: [
                  Expanded(
                    child: SeasonSelector(
                      key: const ValueKey('season-selector'),
                      seasons: seasons,
                      selected: selected!,
                      onChanged: onSeasonChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: TextButton(
                      onPressed: onToggleSeason,
                      child: Text(
                        allSeen ? 'Tout marquer non vu' : 'Tout marquer vu',
                        style: const TextStyle(
                          color: ModernPalette.lilac,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 4,
                    children: [filter('Tous', false), filter('Non vus', true)],
                  ),
                ),
                IconButton(
                  tooltip: 'Aller à un numéro',
                  onPressed: onJump,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
