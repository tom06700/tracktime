import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/main.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/tmdb/tvdb.dart';
import 'package:tracktime/widgets/collection_screen_header.dart';
import 'package:tracktime/widgets/films_seen_button.dart';
import 'package:tracktime/widgets/modern_controls.dart';
import 'package:tracktime/widgets/nav_bar.dart';

void main() {
  testWidgets(
    'Séries and Films align headers and compact selectors; Films opens history',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'nitrate.welcome.v1': true});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tvdbClientProvider.overrideWithValue(TvdbClient('')),
          ],
          child: const NitrateApp(),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      final header = find.byType(CollectionScreenHeader);
      final selector = find.descendant(
        of: header,
        matching: find.byType(GlideControl),
      );
      final seriesHeader = t.getRect(header);
      final seriesSelector = t.getRect(selector);
      await t.tap(
        find.descendant(
          of: find.byType(NitrateNavBar),
          matching: find.text('Films'),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      expect(t.getRect(header), seriesHeader);
      expect(t.getRect(selector), seriesSelector);
      expect(find.byType(FilmsSeenButton), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.byType(FilmsSeenButton));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Films vus'), findsWidgets);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );
}
