import 'package:intl/intl.dart';

import '../models/user_profile.dart';

/// Mise en forme française des nombres, poids, durées et dates.
abstract final class Fmt {
  static const kgParLb = 0.45359237;

  static final _n0 = NumberFormat('#,##0', 'fr_FR');
  static final _n1 = NumberFormat('#,##0.#', 'fr_FR');
  static final _n2 = NumberFormat('#,##0.##', 'fr_FR');

  /// Nombre avec au plus [decimals] décimales, espace fine pour les milliers.
  static String n(num? v, {int decimals = 1}) {
    if (v == null) return '-';
    final f = switch (decimals) { 0 => _n0, 1 => _n1, _ => _n2 };
    return f.format(v).replaceAll(' ', ' ').replaceAll(' ', ' ');
  }

  /// Poids stocké en kg, affiché dans l'unité choisie.
  static double poidsAffiche(double kg, UnitePoids u) => u == UnitePoids.kg ? kg : kg / kgParLb;

  /// Poids saisi dans l'unité choisie, converti en kg pour le stockage.
  static double poidsStocke(double v, UnitePoids u) => u == UnitePoids.kg ? v : v * kgParLb;

  static String poids(double? kg, [UnitePoids u = UnitePoids.kg]) =>
      kg == null ? '-' : '${n(poidsAffiche(kg, u))} ${u.label}';

  /// Volume en kg : « 12 450 kg », « 1,2 t » au-delà de 10 tonnes.
  static String volume(double kg, [UnitePoids u = UnitePoids.kg]) {
    final v = poidsAffiche(kg, u);
    if (u == UnitePoids.kg && v >= 10000) return '${n(v / 1000)} t';
    return '${n(v, decimals: 0)} ${u.label}';
  }

  static String kcal(num? v) => v == null ? '-' : '${n(v, decimals: 0)} kcal';
  static String grammes(num? v) => v == null ? '-' : '${n(v, decimals: 0)} g';

  /// « 1 h 05 », « 45 min », « 30 s ».
  static String duree(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '$h h ${m.toString().padLeft(2, '0')}';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }

  /// Chronomètre : « 1:02:03 » ou « 02:03 ».
  static String chrono(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// Repos : « 1:30 », « 45 s ».
  static String repos(int sec) {
    if (sec < 60) return '$sec s';
    final m = sec ~/ 60;
    final s = sec % 60;
    return s == 0 ? '$m min' : '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Repos et durées courtes, toujours en minutes:secondes : « 2:30 »,
  /// « 0:45 », « 1:00 ». Écriture commune des tableaux et des réglages.
  static String minSec(int sec) {
    final t = sec < 0 ? 0 : sec;
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  /// Nombre à virgule sans séparateur de milliers, pour un champ de saisie :
  /// « 72,5 », « 100 », « 1250 ». Voir [lireDecimal] pour le relire.
  static String decimal(num? v, {int decimals = 2}) {
    if (v == null) return '';
    var t = v.toStringAsFixed(decimals < 0 ? 0 : decimals);
    if (t.contains('.')) {
      t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    if (t == '-0') t = '0';
    return t.replaceAll('.', ',');
  }

  /// Lit un nombre saisi avec une virgule ou un point (« 72,5 », « 72.5 »,
  /// « 1 250 »). Rend null si le texte n'est pas un nombre.
  static double? lireDecimal(String? texte) {
    if (texte == null) return null;
    final t = texte.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    return (v == null || v.isNaN || v.isInfinite) ? null : v;
  }

  /// Le signe de multiplication de l'écriture commune (jamais la lettre x).
  static const fois = '×';

  /// Charge et répétitions : « 70 kg × 6 », « 72,5 kg × 8 ». Sans charge
  /// (poids du corps) : « × 12 ». Sans répétitions : « 70 kg ».
  static String charge(double? kg, int? reps, [UnitePoids u = UnitePoids.kg]) {
    final p = (kg == null || kg <= 0) ? null : poids(kg, u);
    if (reps == null) return p ?? '-';
    return p == null ? '$fois $reps' : '$p $fois $reps';
  }

  /// Nombre de jours de calendrier de [de] à [a] (positif si [a] est après),
  /// juste aussi quand un changement d'heure tombe entre les deux.
  static int joursEntre(DateTime de, DateTime a) =>
      DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(de.year, de.month, de.day)).inDays;

  /// « 7 h 32 » pour une nuit.
  static String sommeil(Duration d) => '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')}';

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// « lundi 3 mars ».
  static String jour(DateTime d) => DateFormat('EEEE d MMMM', 'fr_FR').format(d);

  /// « Lundi 3 mars », capitale en tête.
  static String jourCap(DateTime d) => _cap(jour(d));

  /// « 3 mars 2026 ».
  static String date(DateTime d) => DateFormat('d MMMM y', 'fr_FR').format(d);

  /// « 03/03/2026 ».
  static String dateCourte(DateTime d) => DateFormat('dd/MM/y', 'fr_FR').format(d);

  /// « 3 mars ».
  static String jourMois(DateTime d) => DateFormat('d MMM', 'fr_FR').format(d);

  /// « mars 2026 ».
  static String mois(DateTime d) => _cap(DateFormat('MMMM y', 'fr_FR').format(d));

  /// « 18:05 ».
  static String heure(DateTime d) => DateFormat('HH:mm', 'fr_FR').format(d);

  /// « Aujourd'hui », « Hier », « Mardi », puis la date.
  static String relatif(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    // Écart en jours de calendrier, compté en UTC : entre deux minuits locaux
    // il y a 23 ou 25 heures au changement d'heure, et « inDays » tronque.
    final diff = joursEntre(d, n);
    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    if (diff == -1) return 'Demain';
    if (diff > 1 && diff < 7) return _cap(DateFormat('EEEE', 'fr_FR').format(d));
    if (d.year == n.year) return jourMois(d);
    return dateCourte(d);
  }

  /// « il y a 3 jours ».
  static String ilYa(DateTime d, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(d);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 30) return 'il y a ${diff.inDays} jours';
    final mois = diff.inDays ~/ 30;
    if (mois < 12) return 'il y a $mois mois';
    final ans = diff.inDays ~/ 365;
    return ans <= 1 ? 'il y a un an' : 'il y a $ans ans';
  }

  /// Pluriel simple : « 1 série », « 3 séries ».
  static String pluriel(num count, String singulier, [String? plurielForme]) =>
      '${n(count, decimals: 0)} ${count.abs() >= 2 ? (plurielForme ?? '${singulier}s') : singulier}';
}
