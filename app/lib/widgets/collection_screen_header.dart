import 'package:flutter/material.dart';

import '../widgets/nitrate_home_button.dart';
import '../notifications/bell.dart';
import 'modern_controls.dart';

/// Shared geometry for the Séries and Films headers, including their safe area.
class CollectionScreenHeader extends StatelessWidget {
  const CollectionScreenHeader({
    super.key,
    required this.collectionButton,
    required this.labels,
    required this.index,
    required this.onSelected,
  });

  final Widget collectionButton;
  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: NitrateHomeButton()),
              collectionButton,
              const NotificationBell(),
            ],
          ),
          const SizedBox(height: 16),
          GlideControl(
            dense: true,
            labels: labels,
            index: index,
            onSelected: onSelected,
          ),
        ],
      ),
    ),
  );
}
