import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/screens/explorer_screen.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/tmdb/tvdb.dart';

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  for (final series in [true, false]) {
    for (final watched in [false, true]) {
      testWidgets('${series ? "série" : "film"} : décocher et recocher '
          '${watched ? "avec" : "sans"} historique', (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final date = DateTime(2026, 9, 10);
        if (series) {
          await db.upsertShow(
            ShowsCompanion.insert(id: const Value(1), name: 'Titre'),
          );
          await db.upsertShow(
            ShowsCompanion.insert(id: const Value(2), name: 'Autre'),
          );
          await db.setEpisodeWatched(2, 1, 1, at: date);
          await db
              .into(db.episodes)
              .insert(
                EpisodesCompanion.insert(showId: 1, season: 1, episode: 1),
              );
          if (watched) await db.setEpisodeWatched(1, 1, 1, at: date);
        } else {
          await db.upsertMovie(
            MoviesCompanion.insert(
              id: const Value(1),
              title: 'Titre',
              watchedAt: Value(watched ? date : null),
            ),
          );
        }
        var requests = 0;
        final api = TvdbClient(
          'test',
          client: MockClient((req) async {
            requests++;
            return http.Response(
              jsonEncode({
                'data': req.url.path.endsWith('/login')
                    ? {'token': 't'}
                    : {'name': 'Titre'},
              }),
              200,
            );
          }),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              tvdbClientProvider.overrideWithValue(api),
            ],
            child: MaterialApp(
              theme: buildTheme(),
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final already = series
                        ? (ref.watch(showsProvider).value ?? []).any(
                            (s) => s.show.id == 1,
                          )
                        : (ref.watch(moviesProvider).value ?? []).any(
                            (m) => m.id == 1,
                          );
                    return AddButton(
                      id: 1,
                      isSeries: series,
                      name: 'Titre',
                      already: already,
                      compact: true,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await _flush(tester);
        // Repeated taps must not launch overlapping collection changes.
        final check = find.byIcon(Icons.check);
        if (!watched) await tester.tap(check);
        await tester.tap(check);
        await _flush(tester);
        if (watched) {
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('Annuler'));
          await _flush(tester);
          if (series) {
            expect(
              (await (db.select(
                db.watchedEpisodes,
              )..where((e) => e.showId.equals(1))).get()).single.watchedAt,
              date,
            );
          } else {
            expect((await db.movieById(1))!.watchedAt, date);
          }
          expect(find.byIcon(Icons.check), findsOneWidget);
          await tester.tap(find.byIcon(Icons.check));
          await _flush(tester);
          await tester.tap(find.text('Retirer'));
          await _flush(tester);
        } else {
          expect(find.byType(AlertDialog), findsNothing);
        }
        expect(series ? await db.showById(1) : await db.movieById(1), isNull);
        expect(find.bySemanticsLabel('Ajouter Titre'), findsOneWidget);
        expect(requests, 0, reason: 'Le retrait est local');
        if (series) {
          expect(
            await (db.select(
              db.watchedEpisodes,
            )..where((e) => e.showId.equals(1))).get(),
            isEmpty,
          );
          expect(
            await (db.select(
              db.episodes,
            )..where((e) => e.showId.equals(1))).get(),
            isEmpty,
          );
          expect(
            (await (db.select(
              db.watchedEpisodes,
            )..where((e) => e.showId.equals(2))).get()).single.watchedAt,
            date,
          );
        }
        await tester.tap(find.bySemanticsLabel('Ajouter Titre'));
        await _flush(tester);
        expect(
          series ? await db.showById(1) : await db.movieById(1),
          isNotNull,
        );
        expect(
          find.bySemanticsLabel('Retirer Titre de ma liste'),
          findsOneWidget,
        );
        if (series) {
          expect(
            await (db.select(
              db.watchedEpisodes,
            )..where((e) => e.showId.equals(1))).get(),
            isEmpty,
          );
        } else {
          expect((await db.movieById(1))!.watchedAt, isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
