/// Nature d'un résultat de recherche TheTVDB.
///
/// `/v4/search` ne renvoie pas que des séries et des films : il mélange aussi
/// des listes d'utilisateurs, des personnes et des sociétés. Les types
/// inconnus deviennent [other] plutôt que d'être assimilés à une série.
enum SearchMediaType { series, movie, other }

/// Un résultat de recherche, débarrassé des subtilités de l'API.
class MediaSearchResult {
  const MediaSearchResult({
    required this.tvdbId,
    required this.name,
    required this.type,
    required this.aliases,
    this.originalName,
    this.image,
    this.year,
  });

  /// Identifiant TheTVDB. Peut être nul : le résultat reste affichable, mais
  /// n'est pas ajoutable.
  final int? tvdbId;

  /// Nom à afficher, traduit quand une traduction existe.
  final String name;

  final SearchMediaType type;

  /// Nom d'origine quand il diffère de [name] — beaucoup d'animés sont
  /// catalogués sous leur titre japonais.
  final String? originalName;

  final String? image;
  final String? year;

  /// Titres alternatifs, utilisés pour le classement.
  final List<String> aliases;

  bool get canAdd => tvdbId != null;
}

/// Réduit une chaîne à sa forme comparable : sans accents, sans ponctuation,
/// sans casse ni espaces superflus.
String normalizeTitle(String? s) {
  if (s == null) return '';
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    final i = from.indexOf(c);
    final mapped = i >= 0 ? to[i] : c;
    // On garde lettres, chiffres et espaces ; le reste devient une coupure.
    if (RegExp(r'[a-z0-9]').hasMatch(mapped)) {
      buf.write(mapped);
    } else if (mapped.trim().isEmpty || !RegExp(r'[a-z0-9]').hasMatch(mapped)) {
      buf.write(' ');
    }
  }
  return buf
      .toString()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .join(' ');
}

SearchMediaType _typeOf(Map<String, dynamic> raw) {
  final t = '${raw['type'] ?? raw['primary_type'] ?? ''}'.toLowerCase();
  return switch (t) {
    'series' || 'tv' || 'tvseries' => SearchMediaType.series,
    'movie' || 'film' => SearchMediaType.movie,
    _ => SearchMediaType.other,
  };
}

/// Extrait l'identifiant numérique. `/v4/search` expose `tvdb_id` en clair,
/// mais aussi un `id` préfixé du type (« series-81797 ») ; on accepte les deux.
int? parseTvdbId(Map<String, dynamic> raw) {
  for (final key in const ['tvdb_id', 'id', 'objectID']) {
    final v = raw[key];
    if (v == null) continue;
    if (v is num) return v.toInt();
    final m = RegExp(r'(\d+)$').firstMatch('$v');
    if (m != null) return int.tryParse(m.group(1)!);
  }
  return null;
}

/// Traduit un résultat brut. Renvoie null pour ce qui n'est ni série ni film
/// — listes d'utilisateurs, personnes, sociétés.
///
/// Le nom affiché privilégie la traduction française puis anglaise : beaucoup
/// d'animés sont catalogués sous leur titre japonais (« ワンピース »), qu'un
/// utilisateur francophone ne reconnaîtrait pas.
MediaSearchResult? parseSearchResult(Map<String, dynamic> raw) {
  final type = _typeOf(raw);
  if (type == SearchMediaType.other) return null;

  final original = '${raw['name'] ?? ''}'.trim();
  final translations = (raw['translations'] as Map?)?.cast<String, dynamic>();
  String? tr(String lang) {
    final v = translations?[lang];
    final s = v == null ? '' : '$v'.trim();
    return s.isEmpty ? null : s;
  }

  final display = tr('fra') ?? tr('eng') ?? original;
  if (display.isEmpty) return null;

  final aliases = <String>[
    for (final a in (raw['aliases'] as List?) ?? const [])
      if ('$a'.trim().isNotEmpty) '$a'.trim(),
    // Les autres traductions servent aussi de titres alternatifs.
    for (final v in translations?.values ?? const [])
      if ('$v'.trim().isNotEmpty && '$v'.trim() != display) '$v'.trim(),
  ];

  final year = raw['year'];
  final image = raw['image_url'] ?? raw['image'];

  return MediaSearchResult(
    tvdbId: parseTvdbId(raw),
    name: display,
    type: type,
    originalName: original != display && original.isNotEmpty ? original : null,
    // Aucune exigence d'image : un résultat sans affiche reste un résultat.
    image: image == null || '$image'.isEmpty ? null : '$image',
    year: year == null || '$year'.isEmpty ? null : '$year',
    aliases: aliases,
  );
}

/// Convertit et déduplique une réponse brute.
///
/// La clé de déduplication est le couple type + identifiant : deux entrées
/// nommées « One Piece » peuvent parfaitement être deux œuvres distinctes.
List<MediaSearchResult> parseSearchResults(List<Map<String, dynamic>> raw) {
  final seen = <String>{};
  final out = <MediaSearchResult>[];
  for (final r in raw) {
    final parsed = parseSearchResult(r);
    if (parsed == null) continue;
    final key = '${parsed.type.name}-${parsed.tvdbId ?? parsed.name}';
    if (!seen.add(key)) continue;
    out.add(parsed);
  }
  return out;
}

/// Rang d'un résultat pour une requête donnée : plus petit = plus pertinent.
int _rank(MediaSearchResult r, String query) {
  final q = normalizeTitle(query);
  final known = [?r.originalName, ...r.aliases];

  // Requête sans un seul caractère latin — un titre japonais, cyrillique,
  // arabe… La normalisation la réduirait à une chaîne vide et tous les
  // résultats se vaudraient. On compare alors les chaînes brutes, seule
  // comparaison qui garde du sens.
  if (q.isEmpty) {
    final raw = query.trim().toLowerCase();
    if (raw.isEmpty) return 6;
    if (r.name.trim().toLowerCase() == raw) return 0;
    if (known.any((a) => a.trim().toLowerCase() == raw)) return 2;
    return 6;
  }

  final name = normalizeTitle(r.name);
  // Le titre d'origine compte parmi les titres alternatifs : c'est sous lui
  // que beaucoup d'œuvres sont cataloguées.
  final aliases = known.map(normalizeTitle).where((a) => a.isNotEmpty).toList();

  // Égalité stricte du titre avant égalité après normalisation : « One Piece »
  // doit primer sur « One Piece! ». Sans ce palier il faudrait privilégier les
  // séries à égalité, ce qui remonterait la série Oppenheimer de 1980 devant
  // le film, et la mini-série Dune devant celui de Villeneuve.
  //
  // La comparaison ne porte QUE sur le titre affiché. L'étendre aux alias
  // ferait remonter le film « One Piece! », dont un alias est « ONE PIECE »,
  // devant l'anime — c'est justement ce que ce palier doit éviter.
  if (r.name.trim().toLowerCase() == query.trim().toLowerCase()) return 0;
  if (name == q) return 1;
  if (aliases.contains(q)) return 2;
  if (name.startsWith(q)) return 3;
  if (aliases.any((a) => a.startsWith(q))) return 4;
  if (name.contains(q)) return 5;
  return 6;
}

/// Rang d'un résultat, exposé pour juger de la fiabilité d'une correspondance.
/// 0 = titre identique, 6 = aucun rapport visible.
int rankOf(MediaSearchResult r, String query) => _rank(r, query);

/// Reclasse les résultats : correspondances exactes d'abord, puis les débuts
/// de titre, puis le reste dans l'ordre de l'API.
///
/// TheTVDB classe « One Piece » en plaçant l'anime original en 38ᵉ position,
/// derrière des listes d'utilisateurs et des films dérivés ; sans ce
/// reclassement il resterait invisible.
List<MediaSearchResult> rankSearchResults(
  List<MediaSearchResult> results,
  String query,
) {
  final indexed =
      [
        for (var i = 0; i < results.length; i++)
          (rank: _rank(results[i], query), order: i, value: results[i]),
      ]..sort((a, b) {
        final r = a.rank.compareTo(b.rank);
        return r != 0 ? r : a.order.compareTo(b.order);
      });
  return [for (final e in indexed) e.value];
}
