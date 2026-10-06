import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/navigation.dart';
import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/ui/ui.dart';
import '../logic/exercise_notes.dart';

/// Ce que la suppression d'un exercice perso entraîne, en clair.
String messageSuppression({required int seances, required int routines}) {
  final parties = <String>[
    if (routines > 0) 'Il sera retiré de ${routines == 1 ? 'la routine qui le contient' : 'tes $routines routines qui le contiennent'}.',
    if (seances > 0)
      'Il apparaît dans ${Fmt.pluriel(seances, 'séance')} : ${seances == 1 ? 'elle reste' : 'elles restent'} dans l\'historique, sous le nom « Exercice supprimé ».',
  ];
  return parties.isEmpty ? 'L\'exercice disparaît de la bibliothèque.' : parties.join(' ');
}

/// Les routines sans l'exercice [id] ; seules celles qui changent sont rendues.
List<Routine> retirerDesRoutines(List<Routine> routines, String id) => [
      for (final r in routines)
        if (r.exercices.any((x) => x.exerciseId == id))
          r.copyWith(modifieLe: DateTime.now(), exercices: [for (final x in r.exercices) if (x.exerciseId != id) x]),
    ];

/// Actions partagées par la fiche, la bibliothèque et l'accueil.
abstract final class ExerciseActions {
  /// Ajoute des exercices à la séance en cours, ou en démarre une.
  static Future<void> entrainer(BuildContext context, List<String> ids) async {
    if (ids.isEmpty) return;
    final sessions = context.read<SessionRepo>();
    final exercises = context.read<ExerciseRepo>();
    final repos = context.read<SettingsRepo>().settings.reposParDefautSec;
    final router = GoRouter.of(context);
    final demarrer = !sessions.hasActive;
    if (demarrer) {
      final nom = ids.length == 1 ? exercises.nameOf(ids.first) : 'Séance libre';
      await sessions.startEmpty(nom: nom);
    }
    for (final id in ids) {
      await sessions.addExerciseToActive(id, reposSec: repos);
    }
    if (!context.mounted) return;
    if (demarrer) {
      router.push(Paths.seance);
    } else {
      Toasts.success(
        context,
        ids.length == 1 ? 'Ajouté à la séance en cours' : '${ids.length} exercices ajoutés à la séance',
        actionLabel: 'Ouvrir',
        onAction: () => router.push(Paths.seance),
      );
    }
  }

  /// Ajoute l'exercice à la fin d'une routine choisie (3 séries de 8 à 12).
  static Future<void> ajouterARoutine(BuildContext context, String exerciseId) async {
    final repo = context.read<RoutineRepo>();
    final repos = context.read<SettingsRepo>().settings.reposParDefautSec;
    if (repo.routines.isEmpty) {
      final creer = await showConfirmDialog(
        context,
        title: 'Aucune routine',
        message: 'Crée d\'abord une routine pour y ranger tes exercices.',
        confirmLabel: 'Créer une routine',
        icon: Icons.playlist_add_rounded,
      );
      if (creer && context.mounted) context.push('${Paths.entrainer}/routines/nouvelle');
      return;
    }
    final id = await showChoiceDialog<String>(
      context,
      title: 'Ajouter à une routine',
      options: [for (final r in repo.routines) (r.id, r.nom)],
    );
    if (id == null) return;
    final r = repo.routines.firstWhere((e) => e.id == id);
    final dejaLa = r.exercices.any((e) => e.exerciseId == exerciseId);
    await repo.save(r.copyWith(
      modifieLe: DateTime.now(),
      exercices: [
        ...r.exercices,
        RoutineExercise(
          id: newId(),
          exerciseId: exerciseId,
          reposSec: repos,
          series: const [PlannedSet(reps: 8, repsMax: 12), PlannedSet(reps: 8, repsMax: 12), PlannedSet(reps: 8, repsMax: 12)],
        ),
      ],
    ));
    if (context.mounted) {
      Toasts.success(context, dejaLa ? 'Ajouté une seconde fois à ${r.nom}' : 'Ajouté à ${r.nom}');
    }
  }

  /// Copie un exercice du catalogue en exercice perso modifiable.
  static Future<Exercise> dupliquer(BuildContext context, Exercise e) {
    final copie = Exercise.fromJson({
      ...e.toJson(),
      'id': '',
      'nom': '${e.nom} (perso)',
      'source': 'copie:${e.id}',
      'perso': true,
    });
    return context.read<ExerciseRepo>().addCustom(copie);
  }

  /// Supprime un exercice perso après confirmation. Vrai si supprimé.
  static Future<bool> supprimer(BuildContext context, Exercise e) async {
    final n = context.read<SessionRepo>().historyFor(e.id).length;
    final routines = context.read<RoutineRepo>();
    final store = context.read<Store>();
    final concernees = routines.routines.where((r) => r.exercices.any((x) => x.exerciseId == e.id)).toList();
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer « ${e.nom} » ?',
      message: messageSuppression(seances: n, routines: concernees.length),
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return false;
    final exercices = context.read<ExerciseRepo>();
    // Une routine ne garde pas un exercice qui n'existe plus : elle le
    // proposerait à la prochaine séance sous le nom « Exercice supprimé ».
    if (concernees.isNotEmpty) await routines.saveAll(retirerDesRoutines(concernees, e.id));
    await exercices.deleteCustom(e.id);
    await ExerciseNotes.of(store).set(e.id, null);
    if (context.mounted) Toasts.success(context, 'Exercice supprimé');
    return true;
  }
}
