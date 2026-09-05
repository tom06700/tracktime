import 'package:flutter/material.dart';

/// Cormorant Garamond is bundled (OFL); no runtime font download.
abstract final class NitrateBrand {
  static const ink = Color(0xFF080C0B);
  static const ivory = Color(0xFFF3E7CF);
  static const displayFamily = 'CormorantGaramond';
  static TextStyle display(double size) => TextStyle(
    fontFamily: displayFamily,
    fontSize: size,
    height: .98,
    fontWeight: FontWeight.w500,
    letterSpacing: -1.6,
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
      child: Text('Nitrate', style: NitrateBrand.display(size)),
    ),
  );
}
