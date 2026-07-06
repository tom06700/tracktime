import 'dart:convert';

/// Parseur des exports TV Time (CSV/JSON) et du backup de la version web.
/// Port fidèle du parseur JavaScript de `index.html` (racine du repo).

class ParsedEpisode {
  const ParsedEpisode(this.season, this.episode, this.date);

  final int season;
  final int episode;
  final String? date; // "YYYY-MM-DD" ou null
}

class ParsedMovie {
  const ParsedMovie(this.title, this.date, {this.watched = true});

  final String title;
  final String? date;
  final bool watched;
}

class ParsedData {
  final Map<String, List<ParsedEpisode>> byShow = {};
  final List<ParsedMovie> movies = [];

  int get showCount => byShow.length;
  int get episodeCount =>
      byShow.values.fold(0, (sum, list) => sum + list.length);
  int get total => episodeCount + movies.length;
  bool get isEmpty => byShow.isEmpty && movies.isEmpty;

  void clear() {
    byShow.clear();
    movies.clear();
  }
}

bool looksLikeJson(String text) => RegExp(r'^\s*[\[{]').hasMatch(text);

/// Le texte est-il un backup exporté par la version web de TrackTime ?
/// (structure `{shows: [...], movies: [...], key: '...'}`)
bool isWebBackup(Object? decoded) =>
    decoded is Map &&
    decoded['shows'] is List &&
    (decoded['shows'] as List)
        .every((s) => s is Map && s['id'] is num && s['watched'] is Map);

String? cleanDate(Object? raw) {
  if (raw == null) return null;
  final s = '$raw'.split('T').first.split(' ').first;
  return s.isEmpty ? null : s;
}

/// Lit un CSV en gérant guillemets, échappements `""` et fins de ligne \r\n.
List<List<String>> readCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else {
      if (c == '"') {
        quoted = true;
      } else if (c == ',') {
        endField();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      } else {
        field.write(c);
      }
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

int? findCol(List<String> headers, List<String> keywords,
    [List<String> exclude = const []]) {
  for (var i = 0; i < headers.length; i++) {
    final h = headers[i];
    if (exclude.any(h.contains)) continue;
    if (keywords.any(h.contains)) return i;
  }
  return null;
}

void parseCsvInto(ParsedData parsed, String text) {
  final rows = readCsv(text);
  if (rows.length < 2) return;
  final headers = rows.first.map((h) => h.trim().toLowerCase()).toList();

  final cShow = findCol(
      headers, ['tv_show_name', 'series_name', 'show_name', 'series', 'show']);
  final cSeason = findCol(headers, ['season']);
  var cEp = findCol(headers, ['episode_number', 'episode_num'], ['season']);
  cEp ??= findCol(headers, ['episode'], ['season', 'id', 'name']);
  final cMovie = findCol(headers, ['movie_name', 'movie_title', 'movie']);
  final cTitle = findCol(headers, ['title', 'name'],
      ['show', 'series', 'episode', 'user', 'file']);
  final cDate = findCol(
      headers, ['watched_at', 'watch_date', 'watched', 'created_at', 'date']);

  for (final row in rows.skip(1)) {
    String? cell(int? i) =>
        (i != null && i < row.length) ? row[i].trim() : null;

    final season = int.tryParse(cell(cSeason) ?? '');
    final ep = int.tryParse(cell(cEp) ?? '');
    final showName = cell(cShow);
    final date = cleanDate(cell(cDate));

    if (showName != null && showName.isNotEmpty && season != null && ep != null) {
      parsed.byShow
          .putIfAbsent(showName, () => [])
          .add(ParsedEpisode(season, ep, date));
    } else {
      final title = cell(cMovie) ?? (cSeason == null ? cell(cTitle) : null);
      if (title != null && title.isNotEmpty) {
        parsed.movies.add(ParsedMovie(title, date));
      }
    }
  }
}

/// Parse un JSON déjà décodé (export GDPR TV Time ou format `tracktime_import`).
/// Renvoie false si la structure n'est pas reconnue.
bool parseJsonInto(ParsedData parsed, Object? j) {
  // Format d'import propre généré depuis l'export GDPR TV Time.
  if (j is Map && j['tracktime_import'] != null) {
    for (final s in (j['shows'] as List? ?? const [])) {
      if (s is! Map) continue;
      final name = '${s['name'] ?? ''}';
      if (name.isEmpty) continue;
      final list = parsed.byShow.putIfAbsent(name, () => []);
      for (final e in (s['episodes'] as List? ?? const [])) {
        if (e is List && e.length >= 2) {
          final season = int.tryParse('${e[0]}');
          final ep = int.tryParse('${e[1]}');
          if (season != null && ep != null) {
            list.add(
                ParsedEpisode(season, ep, cleanDate(e.length > 2 ? e[2] : null)));
          }
        }
      }
    }
    for (final m in (j['movies'] as List? ?? const [])) {
      if (m is Map && m['title'] != null) {
        parsed.movies.add(ParsedMovie('${m['title']}', cleanDate(m['date']),
            watched: m['watched'] != false));
      }
    }
    return true;
  }

  final objects = j is List
      ? j
      : (j is Map
          ? ((j['data'] is Map ? (j['data'] as Map)['objects'] : null) ??
              j['objects'] ??
              j['data'])
          : null);
  if (objects is! List) return false;

  for (final o in objects) {
    if (o is! Map) continue;
    final meta = o['meta'] is Map ? o['meta'] as Map : o;
    final name = '${meta['name'] ?? meta['title'] ?? ''}';
    if (name.isEmpty) continue;
    final type = '${o['entity_type'] ?? meta['type'] ?? ''}';
    final date = cleanDate(o['watched_at'] ?? o['created_at']);
    final season =
        int.tryParse('${o['season_number'] ?? meta['season_number'] ?? ''}');
    final ep = int.tryParse(
        '${o['episode_number'] ?? o['number'] ?? meta['number'] ?? ''}');
    if (season != null && ep != null) {
      parsed.byShow
          .putIfAbsent(name, () => [])
          .add(ParsedEpisode(season, ep, date));
    } else if (type.contains('movie') || (season == null && ep == null)) {
      parsed.movies.add(ParsedMovie(name, date));
    }
  }
  return true;
}

/// Résultat de l'analyse d'un fichier importé.
sealed class FileParseResult {
  const FileParseResult();
}

/// Backup de la version web : à restaurer directement (pas besoin de TMDB).
class WebBackupFile extends FileParseResult {
  const WebBackupFile(this.data);

  final Map<String, dynamic> data;
}

/// Entrées TV Time ajoutées à [ParsedData].
class EntriesAdded extends FileParseResult {
  const EntriesAdded(this.count);

  final int count;
}

class UnrecognizedFile extends FileParseResult {
  const UnrecognizedFile();
}

/// Analyse le contenu d'un fichier et alimente [parsed] si pertinent.
FileParseResult parseFile(ParsedData parsed, String text) {
  final before = parsed.total;
  if (looksLikeJson(text)) {
    Object? decoded;
    try {
      decoded = json.decode(text);
    } catch (_) {
      return const UnrecognizedFile();
    }
    if (isWebBackup(decoded)) {
      return WebBackupFile((decoded as Map).cast<String, dynamic>());
    }
    if (!parseJsonInto(parsed, decoded)) return const UnrecognizedFile();
  } else {
    parseCsvInto(parsed, text);
  }
  return EntriesAdded(parsed.total - before);
}
