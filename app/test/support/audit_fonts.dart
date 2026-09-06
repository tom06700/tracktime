import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

Future<void> loadAuditFonts() async {
  final fonts = Platform.environment['NITRATE_AUDIT_FONTS'] ??
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(File('$fonts/Roboto-$weight.ttf')
        .readAsBytes()
        .then(ByteData.sublistView));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
  await (FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
      .load();
}

// Resolve the test engine's square glyphs only; preserve explicit asset fonts.
InlineSpan _readableSpan(InlineSpan span) {
  if (span is! TextSpan) return span;
  final style = span.style ?? const TextStyle();
  return TextSpan(
      text: span.text,
      style: style.fontFamily == null || style.fontFamily == 'Ahem'
          ? style.copyWith(fontFamily: 'Roboto')
          : style,
      children: span.children?.map(_readableSpan).toList(),
      recognizer: span.recognizer,
      semanticsLabel: span.semanticsLabel);
}

void readableAuditFonts(RenderObject object) {
  if (object is RenderParagraph) object.text = _readableSpan(object.text);
  object.visitChildren(readableAuditFonts);
}
