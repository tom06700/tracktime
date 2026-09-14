import 'package:tracktime/widgets/watched_check.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/movies/widgets/movie_poster_card.dart';
import 'package:tracktime/theme.dart';

void main() {
  final movie = Movie(
    id: 1,
    title: 'Un très long titre de film qui doit tenir sur deux lignes',
    runtime: 126,
    addedAt: DateTime(2026),
  );
  Widget host({
    double scale = 1,
    double width = 154,
    VoidCallback? onTap,
    FutureOr<void> Function(MovieAction)? onAction,
  }) => MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Center(
          child: SizedBox(
            width: width,
            height: MoviePosterCard.heightFor(width, TextScaler.linear(scale)),
            child: MoviePosterCard(
              movie: movie,
              metaLine: '2026 · 2 h 06 · Science-fiction',
              onTap: onTap ?? () {},
              onAction: onAction ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('long titles and metadata fit at normal and large text sizes', (
    t,
  ) async {
    for (final scale in [1.0, 1.5, 2.0]) {
      await t.pumpWidget(host(scale: scale, width: scale > 1.5 ? 280 : 154));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text(movie.title), findsOneWidget);
      expect(find.text('Vu'), findsOneWidget);
    }
  });
  testWidgets('Vu marks once without opening the film', (t) async {
    var opened = 0;
    final actions = <MovieAction>[];
    await t.pumpWidget(host(onTap: () => opened++, onAction: actions.add));
    await t.tap(find.text('Vu'));
    await t.pump();
    await t.tap(find.text('Vu'));
    await t.pump(const Duration(milliseconds: 250));
    expect(actions, [MovieAction.markWatched]);
    expect(opened, 0);
  });
  testWidgets('save starts immediately, failure allows retry without success', (
    t,
  ) async {
    final save = Completer<void>();
    var writes = 0;
    await t.pumpWidget(
      host(
        onAction: (_) {
          writes++;
          return save.future;
        },
      ),
    );
    await t.tap(find.text('Vu'));
    await t.pump();
    expect(writes, 1);
    expect(
      find.byWidgetPredicate((w) => w is WatchedCheck && w.confirmed),
      findsNothing,
    );
    await t.tap(find.text('Vu'));
    expect(writes, 1);
    save.completeError(StateError('save failed'));
    await t.pumpAndSettle();
    expect(find.text('Impossible d’enregistrer. Réessaie.'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is WatchedCheck && w.confirmed),
      findsNothing,
    );
    await t.tap(find.text('Vu'));
    await t.pumpAndSettle();
    expect(writes, 2);
  });
  testWidgets('menu is separate from opening the poster', (t) async {
    var opened = 0;
    final actions = <MovieAction>[];
    await t.pumpWidget(host(onTap: () => opened++, onAction: actions.add));
    await t.tap(find.byTooltip('Actions pour ${movie.title}'));
    await t.pumpAndSettle();
    await t.tap(find.text('Retirer de ma liste'));
    await t.pumpAndSettle();
    expect(actions, [MovieAction.remove]);
    expect(opened, 0);
    await t.tap(find.text(movie.title));
    expect(opened, 1);
  });
  testWidgets('the deployed menu closes without opening or changing the film', (
    t,
  ) async {
    var opened = 0;
    final actions = <MovieAction>[];
    await t.pumpWidget(host(onTap: () => opened++, onAction: actions.add));
    await t.tap(find.byTooltip('Actions pour ${movie.title}'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Fermer les actions'), findsOneWidget);
    await t.tap(find.byTooltip('Fermer les actions'));
    await t.pumpAndSettle();
    expect(find.text('Retirer de ma liste'), findsNothing);
    expect(opened, 0);
    expect(actions, isEmpty);
  });
}
