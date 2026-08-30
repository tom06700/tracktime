import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/tmdb/search_result.dart';

/// Fixtures calquées sur des réponses réelles de `/v4/search`.
Map<String, dynamic> raw({
  required String type,
  required String name,
  Object? tvdbId,
  Object? id,
  Map<String, String>? translations,
  List<String>? aliases,
  String? image,
  String? year,
}) => {
  'type': type,
  'name': name,
  'tvdb_id': ?tvdbId,
  'id': ?id,
  'translations': ?translations,
  'aliases': ?aliases,
  'image_url': ?image,
  'year': ?year,
};

/// L'anime One Piece tel que TheTVDB le renvoie : titre japonais, traductions
/// séparées, et une longue liste d'alias.
final onePieceAnime = raw(
  type: 'series',
  name: 'ワンピース',
  tvdbId: 81797,
  id: 'series-81797',
  translations: {'jpn': 'ワンピース', 'eng': 'One Piece', 'fra': 'One Piece'},
  aliases: ['ONE PIECE', 'Wan Pisu', '海賊王'],
  image: 'https://artworks.thetvdb.com/x.jpg',
  year: '1999',
);

void main() {
  group('parseSearchResult', () {
    test('affiche la traduction plutôt que le titre japonais', () {
      final r = parseSearchResult(onePieceAnime)!;
      expect(r.name, 'One Piece');
      expect(r.originalName, 'ワンピース');
      expect(r.type, SearchMediaType.series);
      expect(r.tvdbId, 81797);
      expect(r.canAdd, isTrue);
    });

    test('conserve un résultat sans image', () {
      final r = parseSearchResult(
        raw(type: 'series', name: 'Sans affiche', tvdbId: 42),
      )!;
      expect(r.image, isNull);
      expect(r.name, 'Sans affiche');
    });

    test('écarte les listes, personnes et sociétés', () {
      for (final t in ['list', 'person', 'company', 'inconnu']) {
        expect(
          parseSearchResult(raw(type: t, name: 'X', tvdbId: 1)),
          isNull,
          reason: 'le type $t ne doit pas devenir un média',
        );
      }
    });

    test('lit l\'identifiant depuis tvdb_id, texte ou id préfixé', () {
      expect(parseSearchResult(raw(type: 'movie', name: 'A', tvdbId: 7))!
          .tvdbId, 7);
      expect(parseSearchResult(raw(type: 'movie', name: 'B', tvdbId: '1234'))!
          .tvdbId, 1234);
      expect(parseSearchResult(raw(type: 'series', name: 'C', id: 'series-81797'))!
          .tvdbId, 81797);
    });

    test('un résultat sans identifiant reste affichable mais non ajoutable', () {
      final r = parseSearchResult(raw(type: 'series', name: 'Orpheline'))!;
      expect(r.tvdbId, isNull);
      expect(r.canAdd, isFalse);
    });

    test('les traductions rejoignent les alias', () {
      final r = parseSearchResult(onePieceAnime)!;
      expect(r.aliases, contains('ワンピース'));
      expect(r.aliases, contains('ONE PIECE'));
    });
  });

  group('parseSearchResults', () {
    test('déduplique sur type + identifiant, pas sur le titre', () {
      final list = parseSearchResults([
        raw(type: 'series', name: 'One Piece', tvdbId: 81797),
        raw(type: 'movie', name: 'One Piece', tvdbId: 147553),
        // Même œuvre répétée : celle-ci seule est écartée.
        raw(type: 'series', name: 'One Piece', tvdbId: 81797),
      ]);
      expect(list, hasLength(2));
      expect(list.map((r) => r.type), [
        SearchMediaType.series,
        SearchMediaType.movie,
      ]);
    });
  });

  group('rankSearchResults', () {
    test('l\'anime One Piece passe devant les dérivés', () {
      final results = parseSearchResults([
        raw(type: 'movie', name: 'One Piece!', tvdbId: 147553),
        raw(type: 'movie', name: 'One Piece Film: Red', tvdbId: 318462),
        raw(
          type: 'series',
          name: 'ONE PIECE (2023)',
          tvdbId: 392276,
          aliases: ['One Piece'],
        ),
        raw(type: 'series', name: 'THE ONE PIECE', tvdbId: 464521),
        onePieceAnime,
      ]);

      final ranked = rankSearchResults(results, 'One Piece');
      expect(ranked.first.tvdbId, 81797);
      expect(ranked.first.type, SearchMediaType.series);
      // Les autres restent présents : on classe, on ne supprime pas.
      expect(ranked, hasLength(5));
    });

    test('un alias exact vaut correspondance', () {
      final results = parseSearchResults([
        raw(type: 'series', name: 'Autre chose', tvdbId: 1),
        raw(
          type: 'series',
          name: 'Shingeki no Kyojin',
          tvdbId: 267440,
          aliases: ['Attack on Titan'],
        ),
      ]);
      final ranked = rankSearchResults(results, 'Attack on Titan');
      expect(ranked.first.tvdbId, 267440);
    });

    test('le titre strict prime sur le titre ponctué', () {
      // Sans ce palier il faudrait privilégier les séries à égalité, ce qui
      // remonterait la série Oppenheimer de 1980 devant le film.
      final results = parseSearchResults([
        raw(type: 'movie', name: 'Oppenheimer', tvdbId: 287533),
        raw(type: 'series', name: 'Oppenheimer', tvdbId: 87351),
      ]);
      final ranked = rankSearchResults(results, 'Oppenheimer');
      expect(ranked.first.tvdbId, 287533, reason: 'ordre API conservé à égalité');
    });

    test('accents et casse sont ignorés', () {
      final results = parseSearchResults([
        raw(type: 'series', name: 'Zorro', tvdbId: 1),
        raw(type: 'series', name: 'Les Révoltés', tvdbId: 2),
      ]);
      expect(rankSearchResults(results, 'les revoltes').first.tvdbId, 2);
    });
  });

  group('rankSearchResults, titres non latins', () {
    test('une requête en japonais retrouve la bonne œuvre', () {
      // Un export peut porter le titre d'origine. normalizeTitle réduit un
      // titre japonais à une chaîne vide : sans traitement dédié, tous les
      // résultats se vaudraient et l'ordre brut de l'API l'emporterait.
      final results = parseSearchResults([
        raw(type: 'series', name: 'ONE PIECE (2023)', tvdbId: 392276),
        raw(type: 'series', name: 'THE ONE PIECE', tvdbId: 464521),
        onePieceAnime,
      ]);

      final ranked = rankSearchResults(results, 'ワンピース');
      expect(ranked.first.tvdbId, 81797);
    });

    test('sans correspondance, l\'ordre de l\'API est conservé', () {
      final results = parseSearchResults([
        raw(type: 'series', name: 'Alpha', tvdbId: 1),
        raw(type: 'series', name: 'Bravo', tvdbId: 2),
      ]);

      final ranked = rankSearchResults(results, '日本語');
      expect(ranked.map((r) => r.tvdbId), [1, 2]);
    });

    test('le titre d\'origine compte parmi les titres alternatifs', () {
      // « ワンピース » s'affiche « One Piece » : c'est son titre d'origine qui
      // doit permettre de le retrouver, pas seulement ses alias déclarés.
      final results = parseSearchResults([
        raw(type: 'series', name: 'Autre', tvdbId: 1),
        raw(
          type: 'series',
          name: 'Shingeki no Kyojin',
          tvdbId: 267440,
          translations: {'fra': 'L\'Attaque des Titans'},
        ),
      ]);

      final ranked = rankSearchResults(results, 'Shingeki no Kyojin');
      expect(ranked.first.tvdbId, 267440);
      expect(ranked.first.name, 'L\'Attaque des Titans');
    });
  });

  group('normalizeTitle', () {
    test('réduit accents, casse et ponctuation', () {
      expect(normalizeTitle('  Les  Révoltés !  '), 'les revoltes');
      expect(normalizeTitle('One Piece!'), 'one piece');
      expect(normalizeTitle(null), '');
    });
  });
}
