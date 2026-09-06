import 'package:flutter/material.dart';
import 'package:tracktime/profile/universe.dart';

Universe pelliculeFixture(
        {List<GenreSlice>? genres, Map<String, String> posters = const {}}) =>
    Universe(
        genres: genres ??
            const [
              GenreSlice('Comédie', 19),
              GenreSlice('Animation', 13),
              GenreSlice('Télé-réalité', 10),
              GenreSlice('Drame', 8),
              GenreSlice('Aventure', 7),
              GenreSlice('Action', 6),
              GenreSlice('Documentaire', 20),
              GenreSlice('Mystère', 17)
            ],
        palette: const [Colors.purple],
        seed: 1,
        activityByDay: const {},
        labelsByDay: const {},
        lastActivityByShow: const {},
        posterByGenre: posters,
        currentStreak: 0,
        bestStreak: 0,
        badges: const [],
        records: const [],
        hasGenres: true);
