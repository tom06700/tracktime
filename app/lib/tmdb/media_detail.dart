import 'tvdb.dart';

/// Choisit la meilleure version d'un texte : français, puis anglais, puis la
/// valeur d'origine.
///
/// Même règle que pour les résultats de recherche : TheTVDB catalogue nombre
/// d'œuvres sous leur titre d'origine, souvent japonais, la version lisible
/// vivant dans les traductions.
String? preferredText(List<String?> candidates) {
  for (final c in candidates) {
    final s = c?.trim();
    if (s != null && s.isNotEmpty) return s;
  }
  return null;
}

/// URL d'artwork horizontal, pour l'en-tête d'une fiche.
///
/// TheTVDB numérote ses types : 3 pour un fond de série, 15 pour un fond de
/// film, tous deux en 1920×1080. Vérifié sur les réponses réelles ; à défaut
/// l'affiche prend le relais.
String? backdropOf(Map<String, dynamic> d, {required bool movie}) {
  final wanted = movie ? 15 : 3;
  for (final a in (d['artworks'] as List?) ?? const []) {
    if (a is! Map) continue;
    if (a['type'] == wanted) {
      final url = '${a['image'] ?? ''}';
      if (url.isNotEmpty) return url;
    }
  }
  return null;
}

/// Sociétés d'une fiche, dans l'ordre où elles méritent d'être citées.
///
/// Liste plate (séries) : telle quelle. Objet par rôle (films) : le studio
/// d'abord, puis la production, puis le reste — jamais une exception.
List<Object?> _companiesOf(Object? raw) {
  if (raw is List) return raw;
  if (raw is Map) {
    return [
      for (final key in ['studio', 'production', 'network', 'distributor'])
        ...?(raw[key] as List?),
    ];
  }
  return const [];
}

List<String> _genresOf(Map<String, dynamic> d) => [
  for (final g in (d['genres'] as List?) ?? const [])
    if (g is Map && '${g['name'] ?? ''}'.isNotEmpty) '${g['name']}',
];

/// Statut d'une série, traduit. Les valeurs inconnues sont tues plutôt que
/// montrées telles quelles.
String? frenchStatus(String? raw) => switch (raw?.toLowerCase()) {
  'continuing' => 'En cours',
  'ended' => 'Terminée',
  'upcoming' => 'À venir',
  _ => null,
};

/// Fiche d'une série, telle qu'affichée. Construite depuis
/// `/series/{id}/extended` et sa traduction — jamais depuis la base locale,
/// pour qu'une série non suivie reste consultable.
class SeriesDetail {
  const SeriesDetail({
    required this.id,
    required this.name,
    required this.genres,
    required this.seasonNumbers,
    this.originalName,
    this.overview,
    this.poster,
    this.backdrop,
    this.year,
    this.status,
    this.network,
    this.runtime,
  });

  final int id;
  final String name;

  /// Titre d'origine, seulement s'il diffère de [name].
  final String? originalName;

  final String? overview;
  final String? poster;
  final String? backdrop;
  final String? year;

  /// Statut déjà traduit, ou null si TheTVDB en donne un inconnu.
  final String? status;

  final String? network;
  final int? runtime;
  final List<String> genres;

  /// Saisons officielles, sans la saison 0 (spéciaux).
  final List<int> seasonNumbers;
}

SeriesDetail parseSeriesDetail(
  int id,
  Map<String, dynamic> extended, {
  Map<String, dynamic> translation = const {},
  String fallbackName = '',
}) {
  final original = '${extended['name'] ?? ''}'.trim();
  final name =
      preferredText([
        translation['name'] as String?,
        original,
        fallbackName,
      ]) ??
      fallbackName;

  final seasons = <int>{};
  for (final s in (extended['seasons'] as List?) ?? const []) {
    if (s is! Map) continue;
    final type = (s['type'] as Map?)?['type'];
    final number = (s['number'] as num?)?.toInt();
    if (type == 'official' && number != null && number > 0) seasons.add(number);
  }

  final companies = (extended['companies'] as List?) ?? const [];
  final network = preferredText([
    (extended['latestNetwork'] as Map?)?['name'] as String?,
    (extended['originalNetwork'] as Map?)?['name'] as String?,
    for (final c in companies.take(1))
      if (c is Map) '${c['name'] ?? ''}',
  ]);

  return SeriesDetail(
    id: id,
    name: name,
    originalName: original.isNotEmpty && original != name ? original : null,
    overview: preferredText([
      translation['overview'] as String?,
      extended['overview'] as String?,
    ]),
    poster: preferredText([extended['image'] as String?]),
    backdrop: backdropOf(extended, movie: false),
    year: preferredText([extended['firstAired'] as String?])?.split('-').first,
    status: frenchStatus((extended['status'] as Map?)?['name'] as String?),
    network: network,
    runtime: (extended['averageRuntime'] as num?)?.toInt(),
    genres: _genresOf(extended),
    seasonNumbers: seasons.toList()..sort(),
  );
}

/// Fiche d'un film. `/movies/{id}/extended` ne porte pas de synopsis : il
/// n'existe que dans les traductions, d'où le paramètre dédié.
class MovieDetail {
  const MovieDetail({
    required this.id,
    required this.title,
    required this.genres,
    required this.cast,
    this.originalTitle,
    this.overview,
    this.poster,
    this.backdrop,
    this.releaseDate,
    this.runtime,
    this.director,
    this.studio,
  });

  final int id;
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? poster;
  final String? backdrop;
  final DateTime? releaseDate;
  final int? runtime;
  final String? director;
  final String? studio;
  final List<String> genres;

  /// Interprètes principaux, dans l'ordre donné par TheTVDB.
  final List<String> cast;

  String? get year => releaseDate?.year.toString();
}

MovieDetail parseMovieDetail(
  int id,
  Map<String, dynamic> extended, {
  Map<String, dynamic> translation = const {},
  String fallbackTitle = '',
}) {
  final original = '${extended['name'] ?? ''}'.trim();
  final title =
      preferredText([
        translation['name'] as String?,
        original,
        fallbackTitle,
      ]) ??
      fallbackTitle;

  String? director;
  final cast = <String>[];
  for (final c in (extended['characters'] as List?) ?? const []) {
    if (c is! Map) continue;
    final person = '${c['personName'] ?? ''}'.trim();
    if (person.isEmpty) continue;
    final role = '${c['peopleType'] ?? ''}'.toLowerCase();
    if (role == 'director') {
      director ??= person;
    } else if (role == 'actor' && cast.length < 5 && !cast.contains(person)) {
      cast.add(person);
    }
  }

  // Sur un film, `companies` est un objet groupé par rôle — studio,
  // production, distributeur… — là où une série renvoie une liste plate. Le
  // cast en liste faisait échouer toutes les fiches film sur l'API réelle.
  final studio = preferredText([
    for (final s in (extended['studios'] as List?) ?? const [])
      if (s is Map) '${s['name'] ?? ''}',
    for (final c in _companiesOf(extended['companies']).take(1))
      if (c is Map) '${c['name'] ?? ''}',
  ]);

  return MovieDetail(
    id: id,
    title: title,
    originalTitle: original.isNotEmpty && original != title ? original : null,
    overview: preferredText([translation['overview'] as String?]),
    poster: preferredText([extended['image'] as String?]),
    backdrop: backdropOf(extended, movie: true),
    releaseDate: TvdbClient.releaseDateOf(extended),
    runtime: (extended['runtime'] as num?)?.toInt(),
    director: director,
    studio: studio,
    genres: _genresOf(extended),
    cast: cast,
  );
}
