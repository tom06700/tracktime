import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/widgets/movie_library_actions.dart';

void main() {
  testWidgets('la fiche permet de voir un film, annuler, puis confirmer son retrait', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertMovie(MoviesCompanion.insert(id: const Value(42), title: 'Dune'));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: Scaffold(body: Consumer(builder: (context, ref, _) {
        final movies = ref.watch(moviesProvider).value ?? const <Movie>[];
        return movies.isEmpty ? const Text('Vide') : MovieLibraryActions(movie: movies.first);
      }))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marquer comme vu'));
    await tester.pumpAndSettle();
    expect((await db.movieById(42))!.watchedAt, isNotNull);
    expect(find.text('Remettre à voir'), findsOneWidget);
    await tester.tap(find.text('Remettre à voir'));
    await tester.pumpAndSettle();
    expect((await db.movieById(42))!.watchedAt, isNull);
    await tester.tap(find.byTooltip('Retirer de ma liste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(await db.movieById(42), isNotNull);
    await tester.tap(find.byTooltip('Retirer de ma liste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    expect(await db.movieById(42), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
