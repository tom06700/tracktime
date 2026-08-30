/// Repère d'un épisode dans l'ordre de diffusion.
///
/// L'ordre canonique est (saison, numéro) : jamais l'identifiant TheTVDB, qui
/// ne suit pas l'ordre de diffusion.
typedef EpisodeSlot = ({int season, int episode});

/// Clé « SxEy », telle que la base la produit pour les épisodes vus.
String watchedKeyOf(int season, int episode) => 'S${season}E$episode';

int compareEpisodeSlots(EpisodeSlot a, EpisodeSlot b) {
  final s = a.season.compareTo(b.season);
  return s != 0 ? s : a.episode.compareTo(b.episode);
}

/// Épisodes non vus qu'on peut raisonnablement proposer de cocher en même
/// temps que [target] : ceux de la même saison qui le précèdent.
///
/// Rien n'est proposé quand :
/// - [target] est un spécial (saison 0) ou porte un numéro nul ou négatif ;
/// - aucun épisode antérieur n'est déjà vu — l'utilisateur vient peut-être
///   d'ajouter la série et coche un épisode au hasard ; lui proposer de
///   marquer les 599 précédents serait absurde.
///
/// La fenêtre s'arrête à la saison de [target]. C'est ce qui évite qu'en
/// cochant un épisode de la saison 21 l'app propose de cocher un trou laissé
/// dans la saison 1 des années plus tôt. Un changement de saison reste
/// couvert : dernier épisode vu en S04, on coche S05E04, on propose S05E01
/// à E03.
///
/// Fonction pure et déterministe : la liste rendue est triée et sans doublon.
List<EpisodeSlot> findMissingEpisodesBetween({
  required Iterable<EpisodeSlot> episodes,
  required Set<String> watchedKeys,
  required EpisodeSlot target,
}) {
  if (target.season < 1 || target.episode < 1) return const [];

  bool seen(EpisodeSlot e) =>
      watchedKeys.contains(watchedKeyOf(e.season, e.episode));

  final candidates = <EpisodeSlot>{};
  var anyWatchedBefore = false;
  for (final e in episodes) {
    // Les spéciaux ne participent jamais au remplissage automatique.
    if (e.season < 1 || e.episode < 1) continue;
    // Jamais un épisode postérieur à celui que l'utilisateur vient de cocher.
    if (compareEpisodeSlots(e, target) >= 0) continue;
    if (seen(e)) {
      anyWatchedBefore = true;
      continue;
    }
    if (e.season == target.season) candidates.add(e);
  }
  if (!anyWatchedBefore) return const [];

  return candidates.toList()..sort(compareEpisodeSlots);
}
