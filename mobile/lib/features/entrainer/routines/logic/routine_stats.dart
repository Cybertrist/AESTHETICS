import 'package:flutter/material.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';

/// Couleurs des supersets, dans l'ordre d'apparition (ni rouge ni vert).
const supersetPalette = <Color>[
  AppTokens.domainTraining,
  AppTokens.domainSleep,
  AppTokens.domainWeight,
  AppTokens.domainCoach,
  AppTokens.domainHeart,
  AppTokens.text2,
];

/// Identifiants de superset d'une routine, dans l'ordre, avec leur lettre
/// (A, B, C...) et leur couleur.
Map<String, ({String lettre, Color couleur})> supersetsDe(List<RoutineExercise> exercices) {
  final out = <String, ({String lettre, Color couleur})>{};
  for (final e in exercices) {
    final id = e.supersetId;
    if (id == null || out.containsKey(id)) continue;
    // Un superset d'un seul exercice n'en est pas un.
    if (exercices.where((x) => x.supersetId == id).length < 2) continue;
    final i = out.length;
    out[id] = (lettre: String.fromCharCode(65 + i % 26), couleur: supersetPalette[i % supersetPalette.length]);
  }
  return out;
}

/// Retire les supersets orphelins (un seul exercice) et garde les exercices
/// d'un même superset côte à côte.
List<RoutineExercise> normaliserSupersets(List<RoutineExercise> list) {
  final counts = <String, int>{};
  for (final e in list) {
    if (e.supersetId != null) counts[e.supersetId!] = (counts[e.supersetId!] ?? 0) + 1;
  }
  return [
    for (final e in list) (e.supersetId != null && (counts[e.supersetId!] ?? 0) < 2) ? e.copyWith(clearSuperset: true) : e,
  ];
}

/// Séries (hors échauffement) par muscle : 1 pour un muscle principal,
/// 0,5 pour un muscle secondaire.
Map<Muscle, double> seriesParMuscle(Iterable<RoutineExercise> exercices, Exercise? Function(String) lookup) {
  final out = <Muscle, double>{};
  for (final re in exercices) {
    final ex = lookup(re.exerciseId);
    if (ex == null) continue;
    final n = poidsDesSeries(re.series.map((s) => s.type));
    if (n == 0) continue;
    for (final m in ex.musclesSecondaires) {
      out[m] = (out[m] ?? 0) + n * 0.5;
    }
    for (final m in ex.musclesPrincipaux) {
      out[m] = (out[m] ?? 0) + n;
    }
  }
  return out;
}

/// Intensités 0..1 pour le personnage (le muscle le plus travaillé vaut 1).
Map<Muscle, double> intensitesPour(Map<Muscle, double> series) {
  if (series.isEmpty) return const {};
  final max = series.values.reduce((a, b) => a > b ? a : b);
  if (max <= 0) return const {};
  return {for (final e in series.entries) e.key: (0.35 + 0.65 * e.value / max).clamp(0.0, 1.0)};
}

/// Charge de référence d'une série : celle prévue, sinon la dernière réalisée.
double? chargeReference(PlannedSet s, int index, SessionExercise? dernier) {
  if (s.poids != null) return s.poids;
  final faites = dernier?.seriesFaites ?? const <WorkoutSet>[];
  if (faites.isEmpty) return null;
  return (index < faites.length ? faites[index] : faites.last).poids;
}

/// Volume prévu (charge x répétitions, hors échauffement) ; [estime] est vrai
/// quand une partie vient de la dernière performance.
({double volume, bool estime}) volumePrevu(Routine r, SessionRepo sessions) {
  var total = 0.0;
  var estime = false;
  for (final re in r.exercices) {
    final dernier = sessions.lastFor(re.exerciseId);
    for (var i = 0; i < re.series.length; i++) {
      final s = re.series[i];
      if (!s.type.counts) continue;
      final kg = chargeReference(s, i, dernier);
      final reps = s.reps ?? ((dernier?.seriesFaites.isNotEmpty ?? false) ? dernier!.seriesFaites.last.reps : null);
      if (kg == null || reps == null) continue;
      if (s.poids == null || s.reps == null) estime = true;
      total += kg * reps;
    }
  }
  return (volume: total, estime: estime);
}

/// « 3 × 8 à 12 · 80 kg · RPE 8 » pour un exercice de routine.
String resumeSeries(RoutineExercise re, Exercise? ex, UnitePoids unite) {
  final travail = re.series.where((s) => s.type != SetType.echauffement).toList();
  final echauf = re.series.length - travail.length;
  if (re.series.isEmpty) return 'Aucune série';
  final suivi = ex?.suivi ?? ExerciseTracking.poidsReps;
  final parts = <String>[];
  final ref = travail.isNotEmpty ? travail.first : re.series.first;
  final memes = travail.every((s) => s.repsLabel == ref.repsLabel && s.poids == ref.poids && s.dureeSec == ref.dureeSec);
  final n = travail.isEmpty ? re.series.length : travail.length;
  if (suivi.usesDuration && ref.dureeSec != null) {
    parts.add(memes ? '$n × ${Fmt.repos(ref.dureeSec!)}' : Fmt.pluriel(n, 'série'));
  } else if (ref.repsLabel.isNotEmpty) {
    parts.add(memes ? '$n × ${ref.repsLabel}' : Fmt.pluriel(n, 'série'));
  } else {
    parts.add(Fmt.pluriel(n, 'série'));
  }
  if (memes && ref.poids != null && suivi.usesWeight) parts.add(Fmt.poids(ref.poids, unite));
  if (ref.distanceM != null && suivi.usesDistance) parts.add('${Fmt.n(Affichage.distanceAffichee(ref.distanceM!), decimals: 2)} ${Affichage.distanceLabel}');
  if (memes && ref.rpe != null) parts.add('RPE ${Fmt.n(ref.rpe)}');
  if (echauf > 0) parts.add('+ ${Fmt.pluriel(echauf, 'échauffement')}');
  return parts.join(' · ');
}

/// Texte d'une série prévue : « 8 à 12 reps · 80 kg · RPE 8 ».
String texteSerie(PlannedSet s, ExerciseTracking suivi, UnitePoids unite) {
  final parts = <String>[];
  if (suivi.usesReps || (!suivi.usesDuration && s.reps != null)) {
    parts.add(s.reps == null ? 'reps libres' : '${s.repsLabel} reps');
  }
  if (suivi.usesDuration) parts.add(s.dureeSec == null ? 'durée libre' : Fmt.repos(s.dureeSec!));
  if (suivi.usesDistance && s.distanceM != null) parts.add('${Fmt.n(Affichage.distanceAffichee(s.distanceM!), decimals: 2)} ${Affichage.distanceLabel}');
  if (suivi.usesWeight) {
    final signe = suivi == ExerciseTracking.poidsDuCorpsAssiste ? '-' : (suivi == ExerciseTracking.poidsDuCorpsLeste ? '+' : '');
    parts.add(s.poids == null ? 'charge auto' : '$signe${Fmt.poids(s.poids, unite)}');
  }
  if (s.rpe != null) parts.add('RPE ${Fmt.n(s.rpe)}');
  return parts.join(' · ');
}

/// La routine en texte simple, pour la partager.
String routineEnTexte(Routine r, ExerciseRepo exercices, UnitePoids unite) {
  final b = StringBuffer()..writeln(r.nom.toUpperCase());
  if (r.notes != null && r.notes!.trim().isNotEmpty) b.writeln(r.notes!.trim());
  b.writeln('${Fmt.pluriel(r.exercices.length, 'exercice')} · ${Fmt.pluriel(r.nbSeries, 'série')} · environ ${r.dureeEstimeeMin} min');
  final ss = supersetsDe(r.exercices);
  for (final re in r.exercices) {
    final ex = exercices.byId(re.exerciseId);
    final suivi = ex?.suivi ?? ExerciseTracking.poidsReps;
    b.writeln();
    final tag = ss[re.supersetId] == null ? '' : ' [superset ${ss[re.supersetId]!.lettre}]';
    b.writeln('${exercices.nameOf(re.exerciseId)}$tag');
    for (var i = 0; i < re.series.length; i++) {
      final s = re.series[i];
      final label = s.type == SetType.normale ? 'Série ${i + 1}' : s.type.label;
      b.writeln('  $label : ${texteSerie(s, suivi, unite)}');
    }
    b.writeln('  Repos ${Fmt.repos(re.reposSec)}');
    if (re.notes != null && re.notes!.trim().isNotEmpty) b.writeln('  Note : ${re.notes!.trim()}');
  }
  b
    ..writeln()
    ..write('Partagé depuis Aesthetics');
  return b.toString();
}

/// Muscles principaux d'une routine, les plus travaillés d'abord.
List<Muscle> musclesPrincipaux(Routine r, Exercise? Function(String) lookup, {int max = 3}) {
  final m = seriesParMuscle(r.exercices, lookup).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return m.take(max).map((e) => e.key).toList();
}

/// « 5 exercices · 18 séries · 1 h 05 ».
String resumeRoutine(Routine r) {
  if (r.exercices.isEmpty) return 'Routine vide';
  return '${Fmt.pluriel(r.exercices.length, 'exercice')} · ${Fmt.pluriel(r.nbSeries, 'série')} · ${Fmt.duree(Duration(minutes: r.dureeEstimeeMin))}';
}
