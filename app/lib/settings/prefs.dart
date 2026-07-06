import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tmdb/tmdb.dart';

const _tmdbKeyPref = 'tmdb_api_key';

class TmdbKeyNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tmdbKeyPref) ?? '';
  }

  Future<void> save(String key) async {
    final trimmed = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tmdbKeyPref, trimmed);
    state = AsyncData(trimmed);
  }
}

final tmdbKeyProvider =
    AsyncNotifierProvider<TmdbKeyNotifier, String>(TmdbKeyNotifier.new);

/// Client TMDB construit avec la clé enregistrée ('' si absente :
/// les appels lèveront alors une TmdbException explicite).
final tmdbClientProvider = Provider<TmdbClient>((ref) {
  final key = ref.watch(tmdbKeyProvider).value ?? '';
  return TmdbClient(key);
});
