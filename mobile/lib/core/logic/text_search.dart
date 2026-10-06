/// Recherche tolérante : sans accents, sans casse, mots dans n'importe quel ordre.
abstract final class TextSearch {
  static const _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'æ': 'ae',
    'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'œ': 'oe',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
  };

  /// Minuscules, sans accents, ponctuation remplacée par des espaces.
  static String normalize(String s) {
    final b = StringBuffer();
    for (final rune in s.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final m = _accents[ch] ?? ch;
      b.write(RegExp(r'[a-z0-9]').hasMatch(m) || m.length > 1 ? m : ' ');
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Vrai si chaque mot de la requête apparaît dans l'un des textes.
  static bool matches(String query, Iterable<String?> haystack) {
    final q = normalize(query);
    if (q.isEmpty) return true;
    final text = haystack.whereType<String>().map(normalize).join(' ');
    return q.split(' ').every(text.contains);
  }

  /// Score de pertinence (plus haut = mieux), 0 si aucun rapport.
  static int score(String query, String title, [Iterable<String?> others = const []]) {
    final q = normalize(query);
    if (q.isEmpty) return 1;
    final t = normalize(title);
    if (t == q) return 100;
    if (t.startsWith(q)) return 80;
    if (t.split(' ').any((w) => w.startsWith(q))) return 60;
    if (t.contains(q)) return 50;
    if (matches(query, [title])) return 40;
    if (matches(query, [title, ...others])) return 20;
    return 0;
  }
}
