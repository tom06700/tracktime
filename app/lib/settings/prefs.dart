import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tmdb/tvdb.dart';
import '../tmdb/tvdb_config.dart';

/// Client TheTVDB partagé : la clé projet est embarquée (voir tvdb_config),
/// donc aucun réglage utilisateur. Singleton → le cache d'épisodes persiste.
final tvdbClientProvider =
    Provider<TvdbClient>((ref) => TvdbClient(kTvdbApiKey));
