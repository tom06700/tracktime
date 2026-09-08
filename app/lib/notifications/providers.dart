import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database.dart';
import '../providers.dart';
import 'feed.dart';

final notificationClockProvider = StreamProvider.autoDispose<DateTime>((
  ref,
) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});
final notificationEpisodesProvider = StreamProvider.autoDispose<List<Episode>>(
  (ref) => ref.watch(databaseProvider).watchAllEpisodes(),
);

final releaseNotificationsProvider =
    FutureProvider.autoDispose<List<ReleaseNotification>>((ref) async {
      // Capture all dependencies before awaiting, preserving loading/error states.
      final shows = ref.watch(showsProvider.future);
      final episodes = ref.watch(notificationEpisodesProvider.future);
      final movies = ref.watch(moviesProvider.future);
      final now = ref.watch(notificationClockProvider).value ?? DateTime.now();
      final (showList, episodeList, movieList) = await (
        shows,
        episodes,
        movies,
      ).wait;
      return buildReleaseNotifications(
        shows: showList.map((s) => s.show).toList(),
        episodes: episodeList,
        movies: movieList,
        now: now,
      );
    });

const notificationReadKey = 'nitrate.notifications.read.v1';
final notificationPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);
final notificationReadProvider =
    AsyncNotifierProvider<NotificationReadNotifier, Set<String>>(
      NotificationReadNotifier.new,
    );

class NotificationReadNotifier extends AsyncNotifier<Set<String>> {
  Future<void> _pending = Future.value();
  @override
  Future<Set<String>> build() async =>
      (await ref.watch(
        notificationPreferencesProvider.future,
      )).getStringList(notificationReadKey)?.toSet() ??
      {};

  /// Serial writes ensure rapid taps cannot overwrite one another's read IDs.
  Future<void> markRead(Iterable<String> ids) {
    final snapshot = ids.toSet();
    final next = _pending.then((_) async {
      final current = state.value ?? await future;
      final updated = {...current, ...snapshot};
      if (updated.length == current.length) return;
      final prefs = await ref.read(notificationPreferencesProvider.future);
      if (!await prefs.setStringList(notificationReadKey, updated.toList())) {
        throw StateError('Impossible de conserver les notifications lues.');
      }
      state = AsyncData(updated);
    });
    _pending = next.catchError((Object _) {});
    return next;
  }
}

final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  final feed = ref.watch(releaseNotificationsProvider).value;
  final read = ref.watch(notificationReadProvider).value;
  return feed != null &&
      read != null &&
      feed.any((item) => !read.contains(item.id));
});
