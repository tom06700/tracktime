/// Hôte des images TheTVDB.
///
/// L'API n'est pas cohérente : `/series/filter`, `/search` et les fiches
/// étendues renvoient des URLs complètes, mais `/movies/filter` et la liste
/// des épisodes renvoient des chemins relatifs (`/banners/...`). Passés tels
/// quels à Image.network, ils échouent en silence et la carte reste sur son
/// dégradé de repli — vérifié sur l'app réelle, pas seulement en test.
const kTvdbArtworkHost = 'https://artworks.thetvdb.com';

/// Rend une image TheTVDB chargeable, quelle que soit la forme reçue.
///
/// Une URL complète est rendue telle quelle ; un chemin relatif est préfixé
/// de l'hôte des images ; le vide devient nul, pour que les listes de sources
/// puissent passer à la suivante.
String? absoluteArtwork(String? pathOrUrl) {
  final s = pathOrUrl?.trim();
  if (s == null || s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('//')) return 'https:$s';
  return s.startsWith('/') ? '$kTvdbArtworkHost$s' : '$kTvdbArtworkHost/$s';
}
