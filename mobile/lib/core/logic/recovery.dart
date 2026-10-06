import 'dart:math' as math;

import '../models/exercise.dart';
import '../models/muscle.dart';
import '../models/workout.dart';

/// Récupération par muscle, estimée à partir des séances récentes.
abstract final class Recovery {
  /// Heures pour récupérer d'une séance normale (gros muscles plus lents).
  static double heuresRecuperation(Muscle m) => switch (m) {
        Muscle.quadriceps || Muscle.ischios || Muscle.fessiers || Muscle.grandDorsal || Muscle.lombaires => 72,
        Muscle.pectoraux || Muscle.trapezes || Muscle.rhomboides || Muscle.adducteurs || Muscle.abducteurs => 60,
        _ => 48,
      };

  /// Fatigue de 0 (reposé) à 1 (tout juste travaillé), par muscle.
  /// Chaque série compte (secondaires à moitié) et s'efface linéairement.
  static Map<Muscle, double> fatigue(
    Iterable<WorkoutSession> sessions,
    Exercise? Function(String id) lookup, {
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final charge = <Muscle, double>{};
    for (final s in sessions) {
      final fin = s.fin ?? s.debut;
      final heures = t.difference(fin).inMinutes / 60;
      if (heures < 0 || heures > 96) continue;
      for (final e in s.exercices) {
        final ex = lookup(e.exerciseId);
        if (ex == null) continue;
        final n = e.seriesFaites.where((x) => x.type.counts).length;
        if (n == 0) continue;
        void add(Muscle m, double poids) {
          final reste = 1 - heures / heuresRecuperation(m);
          if (reste <= 0) return;
          // 6 séries effectives saturent le muscle.
          charge[m] = (charge[m] ?? 0) + n * poids * reste / 6;
        }

        for (final m in ex.musclesPrincipaux) {
          add(m, 1);
        }
        for (final m in ex.musclesSecondaires) {
          add(m, 0.5);
        }
      }
    }
    return charge.map((m, v) => MapEntry(m, math.min(1.0, v)));
  }

  /// Récupération en pourcentage (100 = prêt).
  static Map<Muscle, int> pourcentages(Map<Muscle, double> fatigue) => {
        for (final m in Muscle.values) m: ((1 - (fatigue[m] ?? 0)) * 100).round(),
      };

  /// Muscles prêts à être travaillés (récupérés à 80 % ou plus).
  static List<Muscle> prets(Map<Muscle, double> fatigue) =>
      Muscle.values.where((m) => (fatigue[m] ?? 0) <= 0.2).toList();
}
