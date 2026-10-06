// Lecture tolérante des valeurs : nombres, dates, durées, types de série.

import 'csv_table.dart';
import 'import_models.dart';

const livreEnKg = 0.45359237;

/// Nombre avec point ou virgule décimale, espaces de milliers, unité collée.
double? lireNombre(String? v) {
  if (v == null) return null;
  var t = v.trim();
  if (t.isEmpty || CsvTable.estNul(t) || t == '-') return null;
  t = t.replaceAll(RegExp(r'[\s  ]'), '');
  t = t.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
  if (t.contains(',') && t.contains('.')) {
    // 1,234.5 ou 1.234,5 : le dernier séparateur est la décimale
    if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
  } else {
    t = t.replaceAll(',', '.');
  }
  final n = double.tryParse(t);
  // « 1e400 » se lit comme l'infini : valeur absente.
  return n == null || !n.isFinite ? null : n;
}

int? lireEntier(String? v) {
  final n = lireNombre(v);
  if (n == null || n.isNaN || n.isInfinite) return null;
  return n.round();
}

/// Durée : `01:07:22`, `7:22`, `1h 5m`, `45 min`, `90s`, ou nombre.
/// Un nombre seul est lu dans l'unité [nombreEn] (secondes par défaut).
int? lireDureeSec(String? v, {Duration nombreEn = const Duration(seconds: 1)}) {
  if (v == null) return null;
  final t = v.trim().toLowerCase();
  if (t.isEmpty || CsvTable.estNul(t)) return null;
  if (t.contains(':')) {
    final p = t.split(':').map((e) => int.tryParse(e.trim())).toList();
    if (p.any((e) => e == null)) return null;
    if (p.length == 3) return p[0]! * 3600 + p[1]! * 60 + p[2]!;
    if (p.length == 2) return p[0]! * 60 + p[1]!;
    return null;
  }
  final unites = RegExp(r'(\d+(?:[.,]\d+)?)\s*(h|hr|hrs|heures?|hours?|m|min|mins|minutes?|s|sec|secs|secondes?|seconds?)\b');
  final ms = unites.allMatches(t).toList();
  if (ms.isNotEmpty) {
    var total = 0.0;
    for (final m in ms) {
      final n = double.parse(m.group(1)!.replaceAll(',', '.'));
      final u = m.group(2)!;
      if (u.startsWith('h')) {
        total += n * 3600;
      } else if (u.startsWith('m')) {
        total += n * 60;
      } else {
        total += n;
      }
    }
    return total.round();
  }
  final n = lireNombre(t);
  if (n == null) return null;
  return (n * nombreEn.inMicroseconds / 1000000).round();
}

const _mois = {
  'jan': 1, 'janv': 1, 'january': 1, 'janvier': 1,
  'feb': 2, 'fev': 2, 'fevr': 2, 'february': 2, 'fevrier': 2,
  'mar': 3, 'mars': 3, 'march': 3,
  'apr': 4, 'avr': 4, 'april': 4, 'avril': 4,
  'may': 5, 'mai': 5,
  'jun': 6, 'june': 6, 'juin': 6,
  'jul': 7, 'juil': 7, 'july': 7, 'juillet': 7,
  'aug': 8, 'aou': 8, 'aout': 8, 'august': 8,
  'sep': 9, 'sept': 9, 'september': 9, 'septembre': 9,
  'oct': 10, 'october': 10, 'octobre': 10,
  'nov': 11, 'november': 11, 'novembre': 11,
  'dec': 12, 'december': 12, 'decembre': 12,
};

/// Date et heure locales. Formats acceptés :
/// `2026-07-13 07:30:19`, ISO 8601 (avec Z ou décalage, ramené en local),
/// `22 Dec 2025, 08:00`, `13/07/2026 07:30`, `07/13/2026` (si non ambigu),
/// horodatage Unix en secondes ou millisecondes.
/// Les dates à jour et mois ambigus (`05/07/2026`) sont lues jour d'abord,
/// sauf si [moisDabord] est vrai.
DateTime? lireDate(String? v, {bool moisDabord = false}) {
  if (v == null) return null;
  var t = v.trim();
  if (t.isEmpty || CsvTable.estNul(t)) return null;

  // ISO et variantes année d'abord
  final iso = RegExp(
    r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2})(?:[.,](\d+))?)?)?\s*(z|[+-]\d{2}:?\d{2})?$',
    caseSensitive: false,
  ).firstMatch(t);
  if (iso != null) {
    final d = _construire(
      int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!),
      iso.group(4), iso.group(5), iso.group(6),
    );
    if (d == null) return null;
    final zone = iso.group(8);
    if (zone == null) return d;
    // Heure absolue : on la convertit dans le fuseau de l'appareil.
    final parse = DateTime.tryParse(t.replaceFirst(' ', 'T'));
    return parse?.toLocal() ?? d;
  }

  // 22 Dec 2025, 08:00 ou 22 déc. 2025 08:00
  final texte = RegExp(
    r'^(\d{1,2})\s+([a-zA-ZÀ-ſ]+)\.?\s+(\d{4}),?\s*(?:(\d{1,2}):(\d{2})(?::(\d{2}))?)?\s*(am|pm)?$',
    caseSensitive: false,
  ).firstMatch(t);
  if (texte != null) {
    final m = _mois[sansAccents(texte.group(2)!.toLowerCase())];
    if (m == null) return null;
    var h = texte.group(4);
    h = _ampm(h, texte.group(7));
    return _construire(int.parse(texte.group(3)!), m, int.parse(texte.group(1)!),
        h, texte.group(5), texte.group(6));
  }

  // Dec 22, 2025 08:00
  final texteUs = RegExp(
    r'^([a-zA-Z]+)\.?\s+(\d{1,2}),?\s+(\d{4}),?\s*(?:(\d{1,2}):(\d{2})(?::(\d{2}))?)?\s*(am|pm)?$',
    caseSensitive: false,
  ).firstMatch(t);
  if (texteUs != null) {
    final m = _mois[texteUs.group(1)!.toLowerCase()];
    if (m == null) return null;
    final h = _ampm(texteUs.group(4), texteUs.group(7));
    return _construire(int.parse(texteUs.group(3)!), m, int.parse(texteUs.group(2)!),
        h, texteUs.group(5), texteUs.group(6));
  }

  // 13/07/2026 07:30 (jour d'abord par défaut)
  final num = RegExp(
    r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4}),?\s*(?:(\d{1,2}):(\d{2})(?::(\d{2}))?)?\s*(am|pm)?$',
    caseSensitive: false,
  ).firstMatch(t);
  if (num != null) {
    var a = int.parse(num.group(1)!);
    var b = int.parse(num.group(2)!);
    var an = int.parse(num.group(3)!);
    if (an < 100) an += 2000;
    int jour, mois;
    if (a > 12) {
      jour = a;
      mois = b;
    } else if (b > 12) {
      jour = b;
      mois = a;
    } else if (moisDabord) {
      jour = b;
      mois = a;
    } else {
      jour = a;
      mois = b;
    }
    final h = _ampm(num.group(4), num.group(7));
    return _construire(an, mois, jour, h, num.group(5), num.group(6));
  }

  // Horodatage Unix
  if (RegExp(r'^\d{9,13}$').hasMatch(t)) {
    final n = int.parse(t);
    final ms = t.length >= 12 ? n : n * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  return null;
}

String? _ampm(String? h, String? suffixe) {
  if (h == null || suffixe == null) return h;
  var n = int.parse(h) % 12;
  if (suffixe.toLowerCase() == 'pm') n += 12;
  return '$n';
}

DateTime? _construire(int an, int mois, int jour, String? h, String? mi, String? s) {
  if (mois < 1 || mois > 12 || jour < 1 || jour > 31) return null;
  final heure = h == null ? 0 : int.parse(h);
  final minute = mi == null ? 0 : int.parse(mi);
  final seconde = s == null ? 0 : int.parse(s);
  if (heure > 23 || minute > 59 || seconde > 59) return null;
  final d = DateTime(an, mois, jour, heure, minute, seconde);
  // DateTime accepte le 31 février en le décalant : on le refuse.
  if (d.month != mois || d.day != jour) return null;
  return d;
}

/// Type de série, depuis les nombreuses écritures possibles.
/// Renvoie null si la valeur n'est pas reconnue.
SetKind? lireTypeSerie(String? v) {
  if (v == null || v.trim().isEmpty) return SetKind.normale;
  final t = sansAccents(v.trim().toLowerCase())
      .replaceAll(RegExp(r'[\s_-]+'), '')
      .replaceAll(RegExp(r'set$|serie$'), '');
  switch (t) {
    case '':
    case '0':
    case 'normal':
    case 'normale':
    case 'working':
    case 'work':
    case 'regular':
    case 'standard':
    case 'effective':
    case 'travail':
      return SetKind.normale;
    case '1':
    case 'w':
    case 'warmup':
    case 'warm':
    case 'echauffement':
    case 'echauf':
      return SetKind.echauffement;
    case 'feeder':
    case 'feed':
    case '9':
      return SetKind.feeder;
    case 'd':
    case 'drop':
    case 'dropset':
    case 'degressive':
    case 'degressif':
    case '5':
      return SetKind.degressive;
    case 'f':
    case 'failure':
    case 'tofailure':
    case 'echec':
    case 'amrap':
    case '4':
      return SetKind.echec;
    case 'negative':
    case 'negativereps':
    case 'negatives':
    case 'neg':
    case '6':
      return SetKind.negative;
    case 'backoff':
    case 'retour':
    case '11':
      return SetKind.retour;
    case 'top':
    case 'heavy':
    case 'topset':
    case 'lourde':
    case '10':
      return SetKind.lourde;
    case 'partial':
    case 'partialreps':
    case 'partielle':
    case 'partielles':
    case '7':
      return SetKind.partielle;
    case 'left':
    case 'l':
    case 'gauche':
    case 'g':
    case '2':
      return SetKind.gauche;
    case 'right':
    case 'r':
    case 'droite':
    case '3':
      return SetKind.droite;
    case 'unilateral':
    case 'unilaterale':
      return SetKind.unilaterale;
    case 'myo':
    case 'myorep':
    case 'myoreps':
    case '8':
      return SetKind.myoReps;
  }
  return null;
}
