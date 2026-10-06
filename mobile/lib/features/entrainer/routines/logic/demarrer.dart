import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/navigation.dart';
import '../../../../core/data/data.dart';
import '../../../../core/models/models.dart';
import '../../../../core/ui/ui.dart';
import 'program_plan.dart';
import 'progression.dart';

/// Routine du jour d'un programme (progression appliquée), ou la routine telle quelle.
RoutineDuJour routinePrevue(BuildContext context, Routine routine, {String? programId}) {
  final prog = programId == null ? null : context.read<ProgramRepo>().byId(programId);
  if (prog == null) return RoutineDuJour(routine, const []);
  final plan = ProgramPlanRepo.of(context.read<Store>()).planFor(prog.id);
  final ex = context.read<ExerciseRepo>();
  return appliquerProgression(
    routine: routine,
    plan: plan,
    semaine: prog.semaineCourante,
    sessions: context.read<SessionRepo>(),
    lookup: ex.byId,
  );
}

enum _Conflit { reprendre, remplacer }

/// Démarre une séance depuis une routine puis ouvre `/seance`. Si une séance
/// est déjà en cours, propose de la reprendre ou de l'abandonner.
Future<bool> demarrerRoutine(BuildContext context, Routine routine, {String? programId}) async {
  final sessions = context.read<SessionRepo>();
  if (sessions.hasActive) {
    final choix = await showChoiceDialog<_Conflit>(
      context,
      title: 'Une séance est déjà en cours',
      message: '« ${sessions.active!.nom} » n\'est pas terminée.',
      options: const [
        (_Conflit.reprendre, 'Reprendre la séance en cours'),
        (_Conflit.remplacer, 'L\'abandonner et démarrer celle-ci'),
      ],
    );
    if (!context.mounted || choix == null) return false;
    if (choix == _Conflit.reprendre) {
      context.push(Paths.seance);
      return false;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Abandonner la séance en cours ?',
      message: 'Les séries déjà cochées de « ${sessions.active!.nom} » seront perdues.',
      confirmLabel: 'Abandonner',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!context.mounted || !ok) return false;
    await sessions.discardActive();
  }
  if (!context.mounted) return false;
  if (routine.exercices.isEmpty) {
    final ok = await showConfirmDialog(
      context,
      title: 'Routine vide',
      message: 'Aucun exercice n\'est prévu. Tu pourras en ajouter pendant la séance.',
      confirmLabel: 'Démarrer quand même',
    );
    if (!context.mounted || !ok) return false;
  }
  try {
    final prevue = routinePrevue(context, routine, programId: programId);
    await sessions.startFromRoutine(prevue.routine, programId: programId);
  } catch (e) {
    if (context.mounted) Toasts.error(context, 'Impossible de démarrer la séance.');
    return false;
  }
  if (context.mounted) context.push(Paths.seance);
  return true;
}
