import 'package:flutter/material.dart';

/// Approved modern identity; Inter is bundled with its OFL licence.
abstract final class NitrateBrand {
  static const ink = Color(0xFF101113);
  static const ivory = Color(0xFFF2F3F5);
  static const displayFamily = 'Inter';
  static TextStyle display(double size) => TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.1,
        color: ivory,
      );
}

class NitrateWordmark extends StatelessWidget {
  const NitrateWordmark({super.key, this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Nitrate',
        image: true,
        child: ExcludeSemantics(
          child: Text('nitrate', style: NitrateBrand.display(size)),
        ),
      );
}
