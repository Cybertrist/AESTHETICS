import 'package:intl/intl.dart';

import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import 'exercise_stats.dart';

/// Mises en forme propres à la bibliothèque (séries, courbes).
abstract final class ExFmt {
  static String distance(double m) => Affichage.distance(m);

  /// « 45 s », « 1 min 35 s », « 2 min », « 1 h 02 » : à la seconde près
  /// sous l'heure, sinon deux séries d'un gainage se confondent.
  static String secondes(num s) {
    final t = s.round();
    if (t >= 3600) return Fmt.duree(Duration(seconds: t));
    if (t < 60) return '$t s';
    return t % 60 == 0 ? '${t ~/ 60} min' : '${t ~/ 60} min ${t % 60} s';
  }

  /// « 12 kg », « 72,5 kg » : un espace avant l'unité, la virgule pour la décimale.
  static String kg(double kg, UnitePoids u) => '${Fmt.n(Fmt.poidsAffiche(kg, u))} ${u.label}';

  /// « 1 690 kg » pour un volume (sans décimale).
  static String volumeColle(double kg, UnitePoids u) => '${Fmt.n(Fmt.poidsAffiche(kg, u), decimals: 0)} ${u.label}';

  static String reps(int r) => '$r rép${r > 1 ? 's' : ''}';

  /// Une série telle qu'elle s'écrit sur la fiche : « 70 kg × 6 » (le signe
  /// de multiplication, jamais la lettre x).
  static String serieFiche(WorkoutSet s, ExerciseTracking t, UnitePoids u) {
    final p = s.poids ?? 0;
    final r = s.reps ?? 0;
    return switch (t) {
      ExerciseTracking.poidsReps => '${kg(p, u)} × $r',
      ExerciseTracking.poidsDuCorpsLeste => p > 0 ? '+${kg(p, u)} × $r' : reps(r),
      ExerciseTracking.poidsDuCorpsAssiste => p > 0 ? 'Aide ${kg(p, u)} × $r' : reps(r),
      ExerciseTracking.repsSeules => reps(r),
      ExerciseTracking.duree => secondes(s.dureeSec ?? 0),
      ExerciseTracking.distanceDuree => '${distance(s.distanceM ?? 0)}${(s.dureeSec ?? 0) > 0 ? ' en ${secondes(s.dureeSec!)}' : ''}',
      ExerciseTracking.poidsDuree => '${kg(p, u)} × ${secondes(s.dureeSec ?? 0)}',
    };
  }

  /// « 25 sept. 2026 ».
  static String dateAbregee(DateTime d) => DateFormat('d MMM y', 'fr_FR').format(d);

  /// « 25 septembre 2026 à 18:42 ».
  static String dateEtHeure(DateTime d) => '${DateFormat('d MMMM y', 'fr_FR').format(d)} à ${DateFormat('HH:mm', 'fr_FR').format(d)}';

  static String metric(StatMetric m, double v, UnitePoids u) => switch (m) {
        StatMetric.volume || StatMetric.meilleureSerie => Fmt.volume(v, u),
        // Le 1RM estimé s'écrit sans décimale, comme sur l'historique et les records.
        StatMetric.unRm => '${Fmt.n(Fmt.poidsAffiche(v, u), decimals: 0)} ${u.label}',
        StatMetric.chargeMax => Fmt.poids(v, u),
        StatMetric.repsMax || StatMetric.repsTotal => reps(v.round()),
        StatMetric.dureeMax => secondes(v),
        StatMetric.distance => distance(v),
      };

  /// Valeur courte pour les axes des graphiques.
  /// [fin] : une décimale, quand l'écart entre deux graduations est sous 1.
  static String axe(StatMetric m, double v, UnitePoids u, {bool fin = false}) {
    if (m.estPoids) {
      final d = Fmt.poidsAffiche(v, u);
      return d >= 10000 ? '${Fmt.n(d / 1000)} t' : Fmt.n(d, decimals: fin ? 1 : 0);
    }
    if (m == StatMetric.dureeMax) return v >= 60 ? '${(v / 60).round()} min' : '${v.round()} s';
    if (m == StatMetric.distance) return Affichage.distance(v, decimals: 1);
    return Fmt.n(v, decimals: 0);
  }

  /// « 80 kg × 8 », « 12 reps », « 2,5 km en 12 min »...
  static String serie(WorkoutSet s, ExerciseTracking t, UnitePoids u) {
    final p = s.poids ?? 0;
    final r = s.reps ?? 0;
    return switch (t) {
      ExerciseTracking.poidsReps => '${Fmt.poids(p, u)} × $r',
      ExerciseTracking.poidsDuCorpsLeste => p > 0 ? '+${Fmt.poids(p, u)} × $r' : 'Poids du corps × $r',
      ExerciseTracking.poidsDuCorpsAssiste => p > 0 ? 'Aide ${Fmt.poids(p, u)} × $r' : 'Sans aide × $r',
      ExerciseTracking.repsSeules => Fmt.pluriel(r, 'rep'),
      ExerciseTracking.duree => secondes(s.dureeSec ?? 0),
      ExerciseTracking.distanceDuree => '${distance(s.distanceM ?? 0)}${(s.dureeSec ?? 0) > 0 ? ' en ${secondes(s.dureeSec!)}' : ''}',
      ExerciseTracking.poidsDuree => '${Fmt.poids(p, u)} · ${secondes(s.dureeSec ?? 0)}',
    };
  }
}
