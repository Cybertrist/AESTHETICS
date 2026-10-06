import '../models/models.dart';

/// Un exercice unilatéral se fait un côté après l'autre : chaque série de
/// travail devient une paire, la gauche puis la droite, avec les mêmes
/// valeurs. Trois séries prévues en donnent six : G, D, G, D, G, D.
///
/// Rien ne change si les côtés sont déjà notés (une série « Gauche » ou
/// « Droite » existe) : la routine ou la dernière séance font alors foi.
/// Les autres types (échauffement, dégressive...) restent tels quels.
abstract final class Unilateral {
  static bool _cote(SetType t) => t == SetType.gauche || t == SetType.droite;

  /// Les séries prévues d'une routine, un côté après l'autre.
  static List<PlannedSet> prevues(List<PlannedSet> series) {
    if (series.any((s) => _cote(s.type))) return series;
    return [
      for (final s in series)
        if (s.type == SetType.normale)
          for (final cote in const [SetType.gauche, SetType.droite])
            PlannedSet(type: cote, poids: s.poids, reps: s.reps, repsMax: s.repsMax, dureeSec: s.dureeSec, distanceM: s.distanceM, rpe: s.rpe)
        else
          s,
    ];
  }

  /// Les séries d'une séance, un côté après l'autre. [id] donne un
  /// identifiant neuf à chaque série créée.
  static List<WorkoutSet> series(List<WorkoutSet> series, String Function() id) {
    if (series.any((s) => _cote(s.type))) return series;
    return [
      for (final s in series)
        if (s.type == SetType.normale) ...[
          s.copyWith(type: SetType.gauche),
          WorkoutSet(id: id(), type: SetType.droite, poids: s.poids, reps: s.reps, dureeSec: s.dureeSec, distanceM: s.distanceM, rpe: s.rpe),
        ] else
          s,
    ];
  }
}
