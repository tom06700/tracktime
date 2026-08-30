import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/tmdb/media_detail.dart';

/// Réponse `/series/{id}/extended` réduite à ce que la fiche exploite,
/// calquée sur celle de One Piece.
final onePieceExtended = <String, dynamic>{
  'name': 'ワンピース',
  'overview': 'Monkey D. Luffy sets off on his journey...',
  'firstAired': '1999-10-20',
  'averageRuntime': 25,
  'image': 'https://artworks.thetvdb.com/posters/81797.jpg',
  'status': {'name': 'Continuing'},
  'genres': [
    {'name': 'Animation'},
    {'name': 'Aventure'},
  ],
  'seasons': [
    {'number': 0, 'type': {'type': 'official'}},
    {'number': 1, 'type': {'type': 'official'}},
    {'number': 2, 'type': {'type': 'official'}},
    {'number': 1, 'type': {'type': 'dvd'}},
  ],
  'companies': [
    {'name': 'Fuji TV'},
  ],
  'artworks': [
    {'type': 2, 'image': 'poster.jpg'},
    {'type': 3, 'image': 'backdrop.jpg'},
  ],
};

void main() {
  group('parseSeriesDetail', () {
    test('préfère le titre traduit et conserve l\'original', () {
      final d = parseSeriesDetail(
        81797,
        onePieceExtended,
        translation: {'name': 'One Piece', 'overview': 'Luffy part en mer…'},
      );
      expect(d.name, 'One Piece');
      expect(d.originalName, 'ワンピース');
      expect(d.overview, 'Luffy part en mer…');
    });

    test('retombe sur le titre d\'origine sans traduction', () {
      final d = parseSeriesDetail(81797, onePieceExtended);
      expect(d.name, 'ワンピース');
      expect(d.originalName, isNull, reason: 'identique au nom affiché');
      expect(d.overview, startsWith('Monkey D. Luffy'));
    });

    test('traduit le statut et ne garde que les saisons officielles', () {
      final d = parseSeriesDetail(81797, onePieceExtended);
      expect(d.status, 'En cours');
      // Saison 0 (spéciaux) et doublon DVD écartés.
      expect(d.seasonNumbers, [1, 2]);
    });

    test('tait un statut inconnu au lieu de l\'afficher brut', () {
      final d = parseSeriesDetail(1, {
        'name': 'X',
        'status': {'name': 'Something'},
      });
      expect(d.status, isNull);
    });

    test('retient le fond horizontal, type 3 pour une série', () {
      final d = parseSeriesDetail(81797, onePieceExtended);
      expect(d.backdrop, 'backdrop.jpg');
      expect(d.poster, contains('posters/81797'));
    });

    test('survit à une réponse minimale', () {
      final d = parseSeriesDetail(5, {'name': 'Minimale'});
      expect(d.name, 'Minimale');
      expect(d.backdrop, isNull);
      expect(d.genres, isEmpty);
      expect(d.seasonNumbers, isEmpty);
      expect(d.year, isNull);
    });

    test('expose année, réseau et durée', () {
      final d = parseSeriesDetail(81797, onePieceExtended);
      expect(d.year, '1999');
      expect(d.network, 'Fuji TV');
      expect(d.runtime, 25);
      expect(d.genres, ['Animation', 'Aventure']);
    });
  });

  group('parseMovieDetail', () {
    final duneExtended = <String, dynamic>{
      'name': 'Dune',
      'runtime': 155,
      'first_release': {'date': '2021-09-15'},
      'image': 'poster.jpg',
      'genres': [
        {'name': 'Science-Fiction'},
      ],
      'artworks': [
        {'type': 14, 'image': 'poster.jpg'},
        {'type': 15, 'image': 'wide.jpg'},
      ],
      'characters': [
        {'personName': 'Denis Villeneuve', 'peopleType': 'Director'},
        {'personName': 'Timothée Chalamet', 'peopleType': 'Actor'},
        {'personName': 'Zendaya', 'peopleType': 'Actor'},
      ],
      'studios': [
        {'name': 'Legendary'},
      ],
    };

    test('assemble titre, durée, date et distribution', () {
      final d = parseMovieDetail(
        1406,
        duneExtended,
        translation: {'overview': 'Paul Atreides rejoint Arrakis.'},
      );
      expect(d.title, 'Dune');
      expect(d.runtime, 155);
      expect(d.releaseDate, DateTime(2021, 9, 15));
      expect(d.year, '2021');
      expect(d.director, 'Denis Villeneuve');
      expect(d.cast, ['Timothée Chalamet', 'Zendaya']);
      expect(d.studio, 'Legendary');
      expect(d.overview, 'Paul Atreides rejoint Arrakis.');
    });

    test('retient le fond horizontal, type 15 pour un film', () {
      final d = parseMovieDetail(1406, duneExtended);
      expect(d.backdrop, 'wide.jpg');
    });

    test('sans synopsis traduit, le champ reste nul plutôt que vide', () {
      final d = parseMovieDetail(1406, duneExtended);
      expect(d.overview, isNull);
    });

    test('survit à une réponse sans distribution ni artwork', () {
      final d = parseMovieDetail(9, {'name': 'Inconnu'});
      expect(d.title, 'Inconnu');
      expect(d.cast, isEmpty);
      expect(d.director, isNull);
      expect(d.backdrop, isNull);
      expect(d.releaseDate, isNull);
    });
  });

  group('preferredText', () {
    test('retient la première valeur non vide', () {
      expect(preferredText([null, '  ', 'Bon']), 'Bon');
      expect(preferredText([null, '']), isNull);
    });
  });
}
