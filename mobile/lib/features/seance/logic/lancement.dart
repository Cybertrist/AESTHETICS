import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/ui/ui.dart';
import 'chrono.dart';
import 'repos_minuteur.dart';

/// Démarrages de séance, avec la question d'usage si une autre tourne déjà.
abstract final class Lancement {
  /// Faux si l'utilisateur préfère garder la séance en cours.
  static Future<bool> libererPlace(BuildContext context) async {
    final repo = context.read<SessionRepo>();
    final a = repo.active;
    if (a == null) return true;
    final ok = await showConfirmDialog(
      context,
      title: 'Une séance est déjà en cours',
      message: '« ${a.nom} » tourne depuis ${a.duree.inMinutes} min. L\'abandonner pour en démarrer une nouvelle ? Ses séries seront perdues.',
      confirmLabel: 'Abandonner et démarrer',
      cancelLabel: 'Garder l\'actuelle',
      destructive: true,
      icon: Icons.fitness_center_rounded,
    );
    if (ok) {
      ReposMinuteur.instance.passer();
      PauseSeance.instance.oublier();
      await repo.discardActive();
    }
    return ok;
  }

  static Future<WorkoutSession> vide(SessionRepo repo) {
    final h = DateTime.now().hour;
    final nom = h < 11 ? 'Séance du matin' : (h < 14 ? 'Séance du midi' : (h < 18 ? 'Séance de l\'après-midi' : 'Séance du soir'));
    return repo.startEmpty(nom: nom);
  }

  static Future<WorkoutSession> routine(SessionRepo repo, Routine r, {String? programId}) =>
      repo.startFromRoutine(r, programId: programId);

  /// Relance une séance passée : mêmes exercices et charges, rien de coché.
  static Future<WorkoutSession> refaire(SessionRepo repo, WorkoutSession passee) async {
    final s = WorkoutSession(
      id: newId(),
      nom: passee.nom,
      debut: DateTime.now(),
      routineId: passee.routineId,
      exercices: [
        for (final e in passee.exercices)
          SessionExercise(
            id: newId(),
            exerciseId: e.exerciseId,
            reposSec: e.reposSec,
            supersetId: e.supersetId,
            notes: e.notes,
            series: [
              for (final x in e.series)
                WorkoutSet(id: newId(), type: x.type, poids: x.poids, reps: x.reps, dureeSec: x.dureeSec, distanceM: x.distanceM),
            ],
          ),
      ],
    );
    await repo.updateActive(s);
    return s;
  }
}
