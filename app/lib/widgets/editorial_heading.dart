import 'package:flutter/material.dart';

import '../brand/nitrate_brand.dart';
import '../theme.dart';

/// A scrolling chapter heading, shared by collections and discovery.
/// Counts remain plain text and never animate while the user reads them.
class EditorialHeading extends StatelessWidget {
  const EditorialHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.padding = const EdgeInsets.fromLTRB(24, 28, 24, 20),
  });
  final String eyebrow;
  final String title;
  final String? description;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: TtColors.dim,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: NitrateBrand.display(36).copyWith(height: 1.06)),
        if (description != null) ...[
          const SizedBox(height: 10),
          Text(
            description!,
            style: const TextStyle(
              color: TtColors.dim,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ],
    ),
  );
}
