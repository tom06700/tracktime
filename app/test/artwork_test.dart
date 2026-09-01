import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/tmdb/artwork.dart';

void main() {
  group('absoluteArtwork', () {
    test('laisse une URL complète intacte', () {
      const u = 'https://artworks.thetvdb.com/banners/posters/1.jpg';
      expect(absoluteArtwork(u), u);
      expect(absoluteArtwork('http://x.test/a.jpg'), 'http://x.test/a.jpg');
    });

    test('complète un chemin relatif — la forme du filtre films et des '
        'épisodes', () {
      expect(
        absoluteArtwork('/banners/v4/episode/361895/screencap/604d.jpg'),
        'https://artworks.thetvdb.com/banners/v4/episode/361895/screencap/604d.jpg',
      );
      expect(
        absoluteArtwork('banners/movies/63/posters/5ebb.jpg'),
        'https://artworks.thetvdb.com/banners/movies/63/posters/5ebb.jpg',
      );
    });

    test('complète le schéma d\'une URL sans protocole', () {
      expect(
        absoluteArtwork('//artworks.thetvdb.com/banners/a.jpg'),
        'https://artworks.thetvdb.com/banners/a.jpg',
      );
    });

    test('rend nul ce qui est vide, pour passer à la source suivante', () {
      expect(absoluteArtwork(null), isNull);
      expect(absoluteArtwork(''), isNull);
      expect(absoluteArtwork('   '), isNull);
    });
  });
}
