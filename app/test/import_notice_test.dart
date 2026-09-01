import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/screens/import_screen.dart';

void main() {
  group('tvTimeNotice', () {
    test('avant l\'échéance, presse d\'exporter', () {
      expect(
        tvTimeNotice(DateTime(2026, 6, 1)),
        contains('avant le 15 juillet'),
      );
    });

    test('après l\'échéance, ne demande plus d\'exporter dans le passé', () {
      final after = tvTimeNotice(DateTime(2026, 9, 1));
      expect(after, isNot(contains('avant le')));
      expect(after, contains('a cessé'));
      expect(after, contains('importent toujours'));
    });

    test('le jour même bascule déjà sur le message de clôture', () {
      expect(tvTimeNotice(DateTime(2026, 7, 15)), contains('a cessé'));
    });
  });
}
