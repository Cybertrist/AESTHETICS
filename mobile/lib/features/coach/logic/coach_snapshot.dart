import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';

/// Nutrition d'une journée.
class JourNutrition {
  const JourNutrition(this.jour, this.macros, this.eauMl, this.nbEntrees);
  final DateTime jour;
  final Macros macros;
  final int eauMl;
  final int nbEntrees;
  bool get renseigne => nbEntrees > 0;
}

/// Progression d'un exercice fréquent : meilleur 1RM estimé récent contre avant.
class TendanceExercice {
  const TendanceExercice({required this.exercice, required this.recent, required this.avant, required this.seances});
  final Exercise exercice;
  final double recent;
  final double avant;
  final int seances;

  double get variation => avant <= 0 ? 0 : (recent - avant) / avant;
  bool get stagne => avant > 0 && recent <= avant * 1.005;
}

/// Photographie des données de l'appli, lue par le coach (hors ligne et en ligne).
class CoachSnapshot {
  CoachSnapshot({
    required this.profile,
    required this.settings,
    required this.sessionsRepo,
    required this.exercises,
    required this.routines,
    required this.programs,
    required this.nutrition,
    required this.health,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  factory CoachSnapshot.read(BuildContext context, {DateTime? now}) => CoachSnapshot(
        profile: context.read<ProfileRepo>(),
        settings: context.read<SettingsRepo>(),
        sessionsRepo: context.read<SessionRepo>(),
        exercises: context.read<ExerciseRepo>(),
        routines: context.read<RoutineRepo>(),
        programs: context.read<ProgramRepo>(),
        nutrition: context.read<NutritionRepo>(),
        health: context.read<HealthRepo>(),
        now: now,
      );

  final ProfileRepo profile;
  final SettingsRepo settings;
  final SessionRepo sessionsRepo;
  final ExerciseRepo exercises;
  final RoutineRepo routines;
  final ProgramRepo programs;
  final NutritionRepo nutrition;
  final HealthRepo health;
  final DateTime now;

  UserProfile? get user => profile.profile;
  UnitePoids get unite => profile.unite;
  String get prenom => (user?.prenom.trim().isNotEmpty ?? false) ? user!.prenom.trim() : '';
  DateTime get today => Dates.jour(now);
  int get premierJour => settings.settings.premierJourSemaine;

  /// Séances terminées, la plus récente d'abord.
  late final List<WorkoutSession> sessions = sessionsRepo.sessions.where((s) => !s.enCours).toList();

  List<WorkoutSession> sessionsSince(DateTime from) => sessions.where((s) => !s.debut.isBefore(from)).toList();

  late final WorkoutSession? derniere = sessions.isEmpty ? null : sessions.first;

  int? get joursDepuisDerniere => derniere == null ? null : today.difference(Dates.jour(derniere!.debut)).inDays;

  late final List<WorkoutSession> semaine =
      sessionsSince(Dates.debutSemaine(now, premierJour: premierJour));

  int get objectifSemaine => user?.joursParSemaine ?? 3;

  Exercise? lookup(String id) => exercises.byId(id);

  late final Map<Muscle, double> fatigue = Recovery.fatigue(sessions.take(40), lookup, now: now);

  /// Muscles encore bien fatigués (plus de 55 %), du plus fatigué au moins.
  List<MapEntry<Muscle, double>> get fatigues =>
      (fatigue.entries.where((e) => e.value >= 0.55).toList()..sort((a, b) => b.value.compareTo(a.value)));

  /// Séries effectives par muscle sur 7 jours glissants.
  late final Map<Muscle, double> seriesSemaine =
      Strength.setsParMuscle(sessionsSince(today.subtract(const Duration(days: 6))), lookup);

  /// Tendances des exercices les plus faits (8 dernières semaines).
  late final List<TendanceExercice> tendances = _tendances();

  List<TendanceExercice> _tendances() {
    final debut = today.subtract(const Duration(days: 56));
    final milieu = today.subtract(const Duration(days: 21));
    final compte = <String, int>{};
    for (final s in sessionsSince(debut)) {
      for (final e in s.exercices) {
        if (e.seriesFaites.any((x) => x.type.counts && (x.poids ?? 0) > 0)) {
          compte[e.exerciseId] = (compte[e.exerciseId] ?? 0) + 1;
        }
      }
    }
    final top = compte.entries.where((e) => e.value >= 3).toList()..sort((a, b) => b.value.compareTo(a.value));
    final out = <TendanceExercice>[];
    for (final entry in top.take(8)) {
      final ex = lookup(entry.key);
      if (ex == null) continue;
      double best(bool Function(DateTime d) keep) {
        var b = 0.0;
        for (final s in sessions) {
          if (!keep(s.debut)) continue;
          for (final e in s.exercices) {
            if (e.exerciseId != entry.key) continue;
            for (final x in e.seriesFaites) {
              if (!x.type.counts || (x.poids ?? 0) <= 0 || (x.reps ?? 0) <= 0) continue;
              final v = Strength.oneRepMax(x.poids!, x.reps!);
              if (v > b) b = v;
            }
          }
        }
        return b;
      }

      final recent = best((d) => !d.isBefore(milieu));
      final avant = best((d) => !d.isBefore(debut) && d.isBefore(milieu));
      if (recent <= 0 || avant <= 0) continue;
      out.add(TendanceExercice(exercice: ex, recent: recent, avant: avant, seances: entry.value));
    }
    return out;
  }

  // Nutrition

  NutritionGoals get objectifs => NutritionCalc.effectifs(user);

  JourNutrition nutritionDu(DateTime jour) => JourNutrition(
        Dates.jour(jour),
        nutrition.totalsFor(jour),
        nutrition.waterFor(jour),
        nutrition.entriesFor(jour).length,
      );

  late final JourNutrition aujourdhui = nutritionDu(today);

  /// Sept jours avant aujourd'hui (hier en premier).
  late final List<JourNutrition> septJours = [
    for (var i = 1; i <= 7; i++) nutritionDu(today.subtract(Duration(days: i))),
  ];

  /// Moyenne sur les jours renseignés des 7 derniers jours (hors aujourd'hui).
  Macros? get moyenneNutrition {
    final jours = septJours.where((j) => j.renseigne).toList();
    if (jours.isEmpty) return null;
    final total = jours.fold(Macros.zero, (a, j) => a + j.macros);
    return Macros(
      kcal: total.kcal / jours.length,
      proteines: total.proteines / jours.length,
      glucides: total.glucides / jours.length,
      lipides: total.lipides / jours.length,
      fibres: total.fibres / jours.length,
    );
  }

  int get joursNutritionRenseignes => septJours.where((j) => j.renseigne).length;

  // Sommeil et poids

  Duration? get sommeilMoyen => health.averageSleep(days: 7, now: now);
  SleepEntry? get derniereNuit => health.lastSleep;

  double? get poids => health.latestWeight ?? user?.poidsKg;

  /// Variation de poids sur 28 jours (kg), si au moins deux pesées.
  double? get variationPoids28j {
    final serie = health.weightSeries(since: today.subtract(const Duration(days: 28)));
    if (serie.length < 2) return null;
    return serie.last.kg - serie.first.kg;
  }

  bool get vide => sessions.isEmpty && nutrition.entries.isEmpty && health.sleep.isEmpty && health.measurements.isEmpty;
}
