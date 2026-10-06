import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';

/// Texte d'un message du coach découpé : le markdown affiché et les actions proposées.
class ParsedReply {
  const ParsedReply(this.texte, this.actions, {this.actionEnCours = false});
  final String texte;
  final List<CoachAction> actions;

  /// Un bloc d'action est en train d'arriver (flux non terminé).
  final bool actionEnCours;
}

sealed class CoachAction {
  const CoachAction();

  static final _bloc = RegExp(r'```action\s*\n([\s\S]*?)```');

  /// Sépare le texte et les blocs `action`. Un bloc non fermé (réponse en cours) est masqué.
  static ParsedReply parse(String raw) {
    final actions = <CoachAction>[];
    var texte = raw.replaceAllMapped(_bloc, (m) {
      final a = _fromJson(m.group(1) ?? '');
      if (a != null) actions.add(a);
      return '';
    });
    var enCours = false;
    final ouvert = texte.indexOf('```action');
    if (ouvert >= 0) {
      texte = texte.substring(0, ouvert);
      enCours = true;
    }
    return ParsedReply(texte.trim(), actions, actionEnCours: enCours);
  }

  static CoachAction? _fromJson(String src) {
    try {
      final j = jsonDecode(src.trim());
      if (j is! Map) return null;
      final m = j.cast<String, dynamic>();
      return switch (m['type']) {
        'routine' => RoutineAction.fromJson(m),
        'charge' => ChargeAction.fromJson(m),
        'repas' => RepasAction.fromJson(m),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  String get titre;
  String get sousTitre;
  IconData get icon;
  AppDomain get domain;
  String get boutonAppliquer;
  String get libelleApplique;
}

double? _d(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v.replaceAll(',', '.')) : null);
int? _i(Object? v) => _d(v)?.round();

class RoutineExerciceProp {
  const RoutineExerciceProp({required this.nom, this.series = 3, this.reps, this.repsMax, this.poids, this.repos, this.muscles = const []});
  final String nom;
  final int series;
  final int? reps;
  final int? repsMax;
  final double? poids;
  final int? repos;
  final List<Muscle> muscles;

  String resume(UnitePoids u) {
    final r = reps == null ? '' : (repsMax != null && repsMax != reps ? ' x $reps à $repsMax' : ' x $reps');
    final p = poids == null ? '' : ' à ${Fmt.poids(Fmt.poidsStocke(poids!, u), u)}';
    return '$series séries$r$p';
  }
}

class RoutineAction extends CoachAction {
  const RoutineAction({required this.nom, this.notes, required this.exercices});

  factory RoutineAction.fromJson(Map<String, dynamic> j) => RoutineAction(
        nom: (j['nom'] as String?)?.trim().isNotEmpty == true ? (j['nom'] as String).trim() : 'Routine du coach',
        notes: j['notes'] as String?,
        exercices: [
          if (j['exercices'] is List)
            for (final e in j['exercices'] as List)
              if (e is Map && e['nom'] is String)
                RoutineExerciceProp(
                  nom: (e['nom'] as String).trim(),
                  series: (_i(e['series']) ?? 3).clamp(1, 12),
                  reps: _i(e['reps']),
                  repsMax: _i(e['repsMax']),
                  poids: _d(e['poids']),
                  repos: _i(e['repos']),
                  muscles: [
                    if (e['muscles'] is List)
                      for (final m in e['muscles'] as List) ...[Muscle.tryParse(m)].whereType<Muscle>(),
                  ],
                ),
        ],
      );

  final String nom;
  final String? notes;
  final List<RoutineExerciceProp> exercices;

  @override
  String get titre => nom;
  @override
  String get sousTitre => '${Fmt.pluriel(exercices.length, 'exercice')}, ${Fmt.pluriel(exercices.fold(0, (a, e) => a + e.series), 'série')}';
  @override
  IconData get icon => Icons.playlist_add_rounded;
  @override
  AppDomain get domain => AppDomain.entrainement;
  @override
  String get boutonAppliquer => 'Ajouter la routine';
  @override
  String get libelleApplique => 'Routine ajoutée';
}

class ChargeAction extends CoachAction {
  const ChargeAction({required this.exercice, this.poids, this.reps, this.routine});

  factory ChargeAction.fromJson(Map<String, dynamic> j) => ChargeAction(
        exercice: (j['exercice'] as String? ?? '').trim(),
        poids: _d(j['poids']),
        reps: _i(j['reps']),
        routine: (j['routine'] as String?)?.trim(),
      );

  final String exercice;
  final double? poids;
  final int? reps;
  final String? routine;

  @override
  String get titre => exercice;
  @override
  String get sousTitre => [
        if (poids != null) 'charge ${Fmt.n(poids)}',
        if (reps != null) '$reps répétitions',
        if (routine != null && routine!.isNotEmpty) 'dans $routine',
      ].join(', ');
  @override
  IconData get icon => Icons.fitness_center_rounded;
  @override
  AppDomain get domain => AppDomain.entrainement;
  @override
  String get boutonAppliquer => 'Modifier la charge';
  @override
  String get libelleApplique => 'Charge modifiée';
}

class RepasAction extends CoachAction {
  const RepasAction({required this.nom, required this.repas, this.quantite, required this.macros});

  factory RepasAction.fromJson(Map<String, dynamic> j) {
    final r = j['repas'];
    final repas = MealType.values.firstWhere(
      (m) => m.name == r || TextSearch.normalize(m.label) == TextSearch.normalize('${r ?? ''}'),
      orElse: () => MealType.pourHeure(DateTime.now().hour),
    );
    return RepasAction(
      nom: (j['nom'] as String?)?.trim().isNotEmpty == true ? (j['nom'] as String).trim() : 'Repas proposé par le coach',
      repas: repas,
      quantite: _d(j['quantite']),
      macros: Macros(
        kcal: _d(j['kcal']) ?? 0,
        proteines: _d(j['proteines']) ?? 0,
        glucides: _d(j['glucides']) ?? 0,
        lipides: _d(j['lipides']) ?? 0,
        fibres: _d(j['fibres']) ?? 0,
      ),
    );
  }

  final String nom;
  final MealType repas;
  final double? quantite;
  final Macros macros;

  @override
  String get titre => nom;
  @override
  String get sousTitre => '${repas.label}, ${Fmt.kcal(macros.kcal)}, ${Fmt.n(macros.proteines, decimals: 0)} g de protéines';
  @override
  IconData get icon => Icons.restaurant_rounded;
  @override
  AppDomain get domain => AppDomain.nutrition;
  @override
  String get boutonAppliquer => 'Ajouter au journal';
  @override
  String get libelleApplique => 'Ajouté au journal';
}

/// Correspondance d'un nom d'exercice proposé avec la bibliothèque.
class ExerciseMatch {
  const ExerciseMatch(this.nom, this.exercise);
  final String nom;

  /// Null : l'exercice sera créé en exercice personnel.
  final Exercise? exercise;
}

/// Résultat d'une action appliquée.
class ActionResult {
  const ActionResult(this.message, {this.route});
  final String message;

  /// Page à ouvrir pour voir le résultat.
  final String? route;
}

/// Applique les actions sur les dépôts de l'appli.
class CoachActionRunner {
  CoachActionRunner({
    required this.exercises,
    required this.routines,
    required this.nutrition,
    required this.unite,
  });

  final ExerciseRepo exercises;
  final RoutineRepo routines;
  final NutritionRepo nutrition;
  final UnitePoids unite;

  /// Trouve l'exercice le plus proche d'un nom : exact, sinon recherche.
  Exercise? find(String nom) {
    final exact = exercises.findByName(nom);
    if (exact != null) return exact;
    final res = exercises.search(query: nom);
    if (res.isEmpty) return null;
    final top = res.first;
    final score = TextSearch.score(nom, top.nom, [top.nomEn, ...top.alias]);
    return score >= 40 ? top : null;
  }

  List<ExerciseMatch> matches(RoutineAction a) => [for (final e in a.exercices) ExerciseMatch(e.nom, find(e.nom))];

  /// Routines qui contiennent l'exercice d'une action de charge.
  List<Routine> routinesPour(ChargeAction a) {
    final ex = find(a.exercice);
    if (ex == null) return const [];
    var list = routines.routines.where((r) => r.exercices.any((e) => e.exerciseId == ex.id)).toList();
    final nomRoutine = a.routine;
    if (nomRoutine != null && nomRoutine.isNotEmpty) {
      final filtre = list.where((r) => TextSearch.matches(nomRoutine, [r.nom]) || TextSearch.matches(r.nom, [nomRoutine])).toList();
      if (filtre.isNotEmpty) list = filtre;
    }
    return list;
  }

  /// Raison pour laquelle l'action ne peut pas s'appliquer (null si possible).
  String? blocage(CoachAction a) => switch (a) {
        RoutineAction(:final exercices) => exercices.isEmpty ? 'La routine proposée ne contient aucun exercice.' : null,
        ChargeAction() => a.poids == null && a.reps == null
            ? 'Aucune charge ni répétition indiquée.'
            : find(a.exercice) == null
                ? 'Exercice « ${a.exercice} » introuvable dans ta bibliothèque.'
                : routinesPour(a).isEmpty
                    ? 'Aucune de tes routines ne contient cet exercice.'
                    : null,
        RepasAction(:final macros) => macros.kcal <= 0 && macros.proteines <= 0 ? 'Valeurs nutritionnelles manquantes.' : null,
      };

  Future<ActionResult> apply(CoachAction a, {String? folderId}) async {
    switch (a) {
      case RoutineAction():
        final list = <RoutineExercise>[];
        for (final p in a.exercices) {
          var ex = find(p.nom);
          ex ??= await exercises.addCustom(Exercise(
            id: '',
            nom: p.nom,
            musclesPrincipaux: p.muscles,
            source: 'coach',
            notes: 'Créé à partir d\'une routine proposée par le coach.',
          ));
          final poidsKg = p.poids == null ? null : Fmt.poidsStocke(p.poids!, unite);
          list.add(RoutineExercise(
            id: newId(),
            exerciseId: ex.id,
            reposSec: p.repos ?? 90,
            series: [
              for (var i = 0; i < p.series; i++) PlannedSet(poids: poidsKg, reps: p.reps, repsMax: p.repsMax),
            ],
          ));
        }
        final r = await routines.save(Routine(
          id: '',
          nom: a.nom,
          notes: a.notes,
          folderId: folderId,
          exercices: list,
          creeLe: DateTime.now(),
        ));
        return ActionResult('Routine « ${r.nom} » ajoutée.', route: '/entrainer/routines/${r.id}');
      case ChargeAction():
        final ex = find(a.exercice)!;
        final cibles = routinesPour(a);
        final poidsKg = a.poids == null ? null : Fmt.poidsStocke(a.poids!, unite);
        for (final r in cibles) {
          await routines.save(r.copyWith(
            exercices: [
              for (final e in r.exercices)
                e.exerciseId == ex.id
                    ? e.copyWith(series: [
                        for (final s in e.series)
                          s.type == SetType.echauffement
                              ? s
                              : PlannedSet(
                                  type: s.type,
                                  poids: poidsKg ?? s.poids,
                                  reps: a.reps ?? s.reps,
                                  repsMax: a.reps != null ? null : s.repsMax,
                                  dureeSec: s.dureeSec,
                                  distanceM: s.distanceM,
                                  rpe: s.rpe,
                                ),
                      ])
                    : e,
            ],
          ));
        }
        return ActionResult(
          '${ex.nom} mis à jour dans ${cibles.length == 1 ? '« ${cibles.first.nom} »' : '${cibles.length} routines'}.',
          route: cibles.length == 1 ? '/entrainer/routines/${cibles.first.id}' : '/entrainer/routines',
        );
      case RepasAction():
        final now = DateTime.now();
        await nutrition.saveEntry(FoodEntry(
          id: newId(),
          date: now,
          repas: a.repas,
          nom: a.nom,
          quantiteG: a.quantite ?? 100,
          macros: a.macros,
        ));
        return ActionResult('${a.nom} ajouté au ${a.repas.label.toLowerCase()}.', route: '/nutrition');
    }
  }
}
