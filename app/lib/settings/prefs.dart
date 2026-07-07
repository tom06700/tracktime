import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tmdb/tvdb.dart';

const _tvdbKeyPref = 'tvdb_api_key';

/// Clé projet TheTVDB (v4), stockée localement.
class TvdbKeyNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tvdbKeyPref) ?? '';
  }

  Future<void> save(String key) async {
    final trimmed = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tvdbKeyPref, trimmed);
    state = AsyncData(trimmed);
  }
}

final tvdbKeyProvider =
    AsyncNotifierProvider<TvdbKeyNotifier, String>(TvdbKeyNotifier.new);

/// Client TheTVDB construit avec la clé enregistrée ('' si absente : les
/// appels lèveront une TvdbException explicite).
final tvdbClientProvider = Provider<TvdbClient>((ref) {
  final key = ref.watch(tvdbKeyProvider).value ?? '';
  return TvdbClient(key);
});
