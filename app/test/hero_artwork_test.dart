import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/tmdb/media_detail.dart';
import 'package:tracktime/widgets/hero_artwork.dart';

void main() {
  test('un still miniature ne devient pas un fond plein écran Retina', () {
    const viewport = Size(390, 650);
    expect(artworkFitsHero(const Size(320, 180), viewport, 3), isFalse);
    expect(artworkFitsHero(const Size(1920, 1080), viewport, 3), isTrue);
    expect(artworkFitsHero(const Size(680, 1000), viewport, 3), isTrue);
    expect(artworkFitsHero(Size.zero, viewport, 3), isFalse);
  });
  test('le fond le plus résolu du bon type prime sur le premier résultat', () {
    final data = {
      'artworks': [
        {'type': 3, 'image': 'small.jpg', 'width': 640, 'height': 360},
        {'type': 15, 'image': 'film.jpg', 'width': 8000, 'height': 4000},
        {'type': 3, 'image': 'full.jpg', 'width': 1920, 'height': 1080},
      ]
    };
    expect(backdropOf(data, movie: false), 'full.jpg');
    expect(backdropOf(data, movie: true), 'film.jpg');
    expect(backdropOf({'artworks': []}, movie: false), isNull);
  });
}
