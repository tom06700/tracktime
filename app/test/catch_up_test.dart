import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/series/catch_up.dart';

/// Épisodes d'une saison, de [from] à [to] inclus.
List<EpisodeSlot> season(int s, int from, int to) => [
  for (var n = from; n <= to; n++) (season: s, episode: n),
];

Set<String> watched(Iterable<EpisodeSlot> eps) => {
  for (final e in eps) watchedKeyOf(e.season, e.episode),
};

/// Raccourci de lecture des propositions.
List<int> numbers(List<EpisodeSlot> eps) => [for (final e in eps) e.episode];

void main() {
  group('findMissingEpisodesBetween', () {
    test('aucun trou : rien à proposer', () {
      final eps = season(1, 1, 60);
      final missing = findMissingEpisodesBetween(
        episodes: eps,
        watchedKeys: watched(season(1, 1, 59)),
        target: (season: 1, episode: 60),
      );
      expect(missing, isEmpty);
    });

    test('trou continu : les dix épisodes sautés', () {
      // Le cas One Piece : vu jusqu'à E49, on coche E60.
      final missing = findMissingEpisodesBetween(
        episodes: season(1, 1, 60),
        watchedKeys: watched(season(1, 1, 49)),
        target: (season: 1, episode: 60),
      );
      expect(missing, hasLength(10));
      expect(numbers(missing), [50, 51, 52, 53, 54, 55, 56, 57, 58, 59]);
    });

    test('trous dispersés : exactement ceux qui manquent', () {
      final missing = findMissingEpisodesBetween(
        episodes: season(1, 50, 56),
        watchedKeys: watched([
          (season: 1, episode: 50),
          (season: 1, episode: 52),
          (season: 1, episode: 54),
        ]),
        target: (season: 1, episode: 56),
      );
      expect(numbers(missing), [51, 53, 55]);
    });

    test('aucun épisode antérieur vu : on ne propose rien', () {
      // Série tout juste ajoutée, l'utilisateur coche E60 au hasard : lui
      // proposer les 59 précédents serait absurde.
      final missing = findMissingEpisodesBetween(
        episodes: season(1, 1, 60),
        watchedKeys: const {},
        target: (season: 1, episode: 60),
      );
      expect(missing, isEmpty);
    });

    test('un spécial ne déclenche aucune propagation', () {
      final missing = findMissingEpisodesBetween(
        episodes: [...season(0, 1, 5), ...season(1, 1, 10)],
        watchedKeys: watched(season(1, 1, 9)),
        target: (season: 0, episode: 3),
      );
      expect(missing, isEmpty);
    });

    test('les spéciaux ne sont jamais proposés', () {
      final missing = findMissingEpisodesBetween(
        episodes: [...season(0, 1, 5), ...season(1, 1, 10)],
        watchedKeys: watched(season(1, 1, 7)),
        target: (season: 1, episode: 10),
      );
      expect(numbers(missing), [8, 9]);
    });

    test('changement de saison : la nouvelle saison seulement', () {
      final missing = findMissingEpisodesBetween(
        episodes: [...season(4, 1, 10), ...season(5, 1, 10)],
        watchedKeys: watched(season(4, 1, 10)),
        target: (season: 5, episode: 4),
      );
      expect(missing, [
        (season: 5, episode: 1),
        (season: 5, episode: 2),
        (season: 5, episode: 3),
      ]);
    });

    test('un vieux trou d\'une autre saison reste intact', () {
      // S01E03 jamais vu, dernier épisode vu S05E02, on coche S05E05.
      final all = [...season(1, 1, 5), ...season(5, 1, 10)];
      final seen = watched([
        ...season(1, 1, 5).where((e) => e.episode != 3),
        (season: 5, episode: 1),
        (season: 5, episode: 2),
      ]);
      final missing = findMissingEpisodesBetween(
        episodes: all,
        watchedKeys: seen,
        target: (season: 5, episode: 5),
      );
      expect(missing, [(season: 5, episode: 3), (season: 5, episode: 4)]);
    });

    test('jamais un épisode postérieur à la cible', () {
      final missing = findMissingEpisodesBetween(
        episodes: season(1, 1, 20),
        watchedKeys: watched(season(1, 1, 5)),
        target: (season: 1, episode: 10),
      );
      expect(numbers(missing), [6, 7, 8, 9]);
    });

    test('numéros nuls ou négatifs écartés', () {
      final missing = findMissingEpisodesBetween(
        episodes: [
          (season: 1, episode: 0),
          (season: 1, episode: -1),
          ...season(1, 1, 5),
        ],
        watchedKeys: watched([(season: 1, episode: 1)]),
        target: (season: 1, episode: 5),
      );
      expect(numbers(missing), [2, 3, 4]);
    });

    test('résultat trié et sans doublon, quel que soit l\'ordre d\'entrée', () {
      final missing = findMissingEpisodesBetween(
        episodes: [
          (season: 1, episode: 4),
          (season: 1, episode: 2),
          (season: 1, episode: 4), // doublon
          (season: 1, episode: 1),
          (season: 1, episode: 3),
          (season: 1, episode: 5),
        ],
        watchedKeys: watched([(season: 1, episode: 1)]),
        target: (season: 1, episode: 5),
      );
      expect(numbers(missing), [2, 3, 4]);
    });
  });

  group('compareEpisodeSlots', () {
    test('la saison prime sur le numéro', () {
      expect(
        compareEpisodeSlots((season: 1, episode: 99), (season: 2, episode: 1)),
        isNegative,
      );
      expect(
        compareEpisodeSlots((season: 2, episode: 1), (season: 2, episode: 10)),
        isNegative,
      );
      expect(
        compareEpisodeSlots((season: 3, episode: 4), (season: 3, episode: 4)),
        0,
      );
    });
  });
}
