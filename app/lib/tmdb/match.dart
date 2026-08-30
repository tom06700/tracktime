import 'search_result.dart';
import 'tvdb.dart';

/// Fiabilité d'une correspondance de titre.
enum MatchConfidence {
  /// Le titre affiché est identique à celui cherché.
  exact,

  /// Un titre alternatif connu correspond exactement.
  strong,

  /// Simple préfixe ou sous-chaîne : « One Piece Film: Red » pour
  /// « One Piece ». Suffisant pour proposer, pas pour décider seul.
  weak,

  /// Rien de comparable.
  none,
}

/// Résultat d'une recherche par titre, avec de quoi juger s'il est sûr.
class TitleMatch {
  const TitleMatch(this.result, this.confidence, {this.ambiguous = false});

  static const nothing = TitleMatch(null, MatchConfidence.none);

  final MediaSearchResult? result;
  final MatchConfidence confidence;

  /// Plusieurs candidats se valent — « The Office » existe en version
  /// américaine et britannique, toutes deux sous ce titre exact.
  final bool ambiguous;

  /// Assez sûr pour rattacher un historique entier sans demander.
  bool get isReliable =>
      result != null &&
      !ambiguous &&
      (confidence == MatchConfidence.exact ||
          confidence == MatchConfidence.strong);
}

MatchConfidence _confidenceOf(int rank) => switch (rank) {
  0 || 1 => MatchConfidence.exact,
  2 => MatchConfidence.strong,
  3 || 4 || 5 => MatchConfidence.weak,
  _ => MatchConfidence.none,
};

/// Cherche une œuvre sur TheTVDB à partir de son titre.
///
/// Le classement est celui d'Explorer et de l'import TV Time : l'ordre brut de
/// l'API place par exemple la série live-action « One Piece » avant l'animé.
/// Le type est imposé — une série ne peut jamais servir de correspondance à un
/// film, ni l'inverse.
///
/// [year] ne sert qu'à départager des candidats de même rang, quand la source
/// le connaît.
Future<TitleMatch> matchTitle(
  TvdbClient tvdb,
  String title,
  SearchMediaType type, {
  String? year,
}) async {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return TitleMatch.nothing;

  final raw = await tvdb.search(
    trimmed,
    type: type == SearchMediaType.series ? 'series' : 'movie',
  );
  final ranked = rankSearchResults(
    parseSearchResults(raw),
    trimmed,
  ).where((r) => r.type == type && r.tvdbId != null).toList();
  if (ranked.isEmpty) return TitleMatch.nothing;

  final topRank = rankOf(ranked.first, trimmed);
  var rivals = ranked.where((r) => rankOf(r, trimmed) == topRank).toList();
  var top = rivals.first;

  if (rivals.length > 1 && year != null && year.isNotEmpty) {
    final sameYear = rivals.where((r) => r.year == year).toList();
    if (sameYear.length == 1) {
      top = sameYear.single;
      rivals = [top];
    }
  }

  return TitleMatch(top, _confidenceOf(topRank), ambiguous: rivals.length > 1);
}
