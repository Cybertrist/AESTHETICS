// Lecture d'un CSV (RFC 4180) avec détection du séparateur. Dart pur.

import 'dart:convert';

/// Une ligne de données, lue par nom de colonne normalisé.
class CsvRow {
  CsvRow(this._table, this.valeurs, this.ligne);

  final CsvTable _table;
  final List<String> valeurs;

  /// Numéro de ligne dans le fichier (l'en-tête est la ligne 1).
  final int ligne;

  /// Première valeur non vide parmi les noms de colonnes proposés.
  String? get(List<String> noms) {
    for (final n in noms) {
      final i = _table.indexOf(n);
      if (i != null && i < valeurs.length) {
        final v = valeurs[i].trim();
        if (v.isNotEmpty && !CsvTable.estNul(v)) return v;
      }
    }
    return null;
  }

  /// Valeur à un index de colonne, null si vide.
  String? at(int? index) {
    if (index == null || index < 0 || index >= valeurs.length) return null;
    final v = valeurs[index].trim();
    return v.isEmpty || CsvTable.estNul(v) ? null : v;
  }
}

class CsvTable {
  CsvTable._(this.enTetes, this.separateur, List<List<String>> brutes, this.premiereLigne) {
    for (var i = 0; i < enTetes.length; i++) {
      _index.putIfAbsent(normaliserEnTete(enTetes[i]), () => i);
    }
    lignes = [
      for (var i = 0; i < brutes.length; i++)
        CsvRow(this, brutes[i], premiereLigne + 1 + i),
    ];
  }

  /// En-têtes tels qu'écrits (sans espaces autour).
  final List<String> enTetes;
  final String separateur;
  final int premiereLigne;
  late final List<CsvRow> lignes;
  final Map<String, int> _index = {};

  /// En-têtes normalisés, dans l'ordre.
  List<String> get enTetesNormalises => [for (final e in enTetes) normaliserEnTete(e)];

  int? indexOf(String nom) => _index[normaliserEnTete(nom)];

  bool contient(String nom) => _index.containsKey(normaliserEnTete(nom));

  /// Valeurs littérales qui veulent dire « rien ».
  static bool estNul(String v) {
    final l = v.toLowerCase();
    return l == 'null' || l == 'nan' || l == 'none' || l == 'undefined';
  }

  /// Minuscules, sans accents ni guillemets, espaces simples.
  static String normaliserEnTete(String s) {
    var t = s.replaceAll('﻿', '').trim().toLowerCase();
    t = t.replaceAll('"', '').replaceAll("'", '');
    t = sansAccents(t);
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  /// Décode des octets (UTF-8 avec ou sans BOM, sinon Latin-1).
  static String decoder(List<int> octets) {
    try {
      return utf8.decode(octets);
    } on FormatException {
      return latin1.decode(octets);
    }
  }

  /// Lit un texte CSV. La première ligne non vide est l'en-tête.
  static CsvTable lire(String texte, {String? separateur}) {
    var t = texte;
    if (t.startsWith('﻿')) t = t.substring(1);
    final sep = separateur ?? detecterSeparateur(t);
    final toutes = _decouper(t, sep);
    var debut = 0;
    while (debut < toutes.length && toutes[debut].every((c) => c.trim().isEmpty)) {
      debut++;
    }
    if (debut >= toutes.length) {
      return CsvTable._(const [], sep, const [], 1);
    }
    final entete = [for (final c in toutes[debut]) c.trim()];
    final donnees = <List<String>>[];
    for (final l in toutes.skip(debut + 1)) {
      if (l.every((c) => c.trim().isEmpty)) continue;
      donnees.add(l);
    }
    return CsvTable._(entete, sep, donnees, debut + 1);
  }

  /// Choisit entre virgule, point-virgule et tabulation d'après l'en-tête.
  static String detecterSeparateur(String texte) {
    final fin = texte.indexOf('\n');
    final entete = fin < 0 ? texte : texte.substring(0, fin);
    var meilleur = ',';
    var max = 0;
    for (final sep in const [',', ';', '\t', '|']) {
      var n = 0;
      var dansGuillemets = false;
      for (final c in entete.split('')) {
        if (c == '"') dansGuillemets = !dansGuillemets;
        if (!dansGuillemets && c == sep) n++;
      }
      if (n > max) {
        max = n;
        meilleur = sep;
      }
    }
    return meilleur;
  }

  // Automate simple : guillemets doublés, retours à la ligne dans les champs.
  static List<List<String>> _decouper(String t, String sep) {
    final lignes = <List<String>>[];
    var ligne = <String>[];
    final champ = StringBuffer();
    var guillemets = false;
    var i = 0;
    while (i < t.length) {
      final c = t[i];
      if (guillemets) {
        if (c == '"') {
          if (i + 1 < t.length && t[i + 1] == '"') {
            champ.write('"');
            i++;
          } else {
            guillemets = false;
          }
        } else {
          champ.write(c);
        }
      } else if (c == '"') {
        guillemets = true;
      } else if (c == sep) {
        ligne.add(champ.toString());
        champ.clear();
      } else if (c == '\r') {
        // ignoré, la fin de ligne est traitée sur \n
      } else if (c == '\n') {
        ligne.add(champ.toString());
        champ.clear();
        lignes.add(ligne);
        ligne = <String>[];
      } else {
        champ.write(c);
      }
      i++;
    }
    if (champ.isNotEmpty || ligne.isNotEmpty) {
      ligne.add(champ.toString());
      lignes.add(ligne);
    }
    return lignes;
  }
}

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', 'ø': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ñ': 'n', 'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
};

/// Retire les accents d'un texte déjà en minuscules.
String sansAccents(String s) {
  final b = StringBuffer();
  for (final c in s.split('')) {
    b.write(_accents[c] ?? c);
  }
  return b.toString();
}
