import 'dart:convert';

import 'repos/coach_repo.dart';
import 'repos/exercise_repo.dart';
import 'repos/health_repo.dart';
import 'repos/nutrition_repo.dart';
import 'repos/profile_repo.dart';
import 'repos/program_repo.dart';
import 'repos/routine_repo.dart';
import 'repos/session_repo.dart';
import 'repos/settings_repo.dart';
import 'store.dart';

/// Tous les dépôts, créés et chargés ensemble. Fourni par Provider.
class AppData {
  AppData(this.store, {this.demo = false})
      : profile = ProfileRepo(store),
        settings = SettingsRepo(store),
        exercises = ExerciseRepo(store),
        routines = RoutineRepo(store),
        programs = ProgramRepo(store),
        sessions = SessionRepo(store),
        nutrition = NutritionRepo(store),
        health = HealthRepo(store),
        coach = CoachRepo(store) {
    sessions.estUnilateral = (id) => exercises.byId(id)?.unilateral ?? false;
  }

  final Store store;

  /// Variante démo (--dart-define=DEMO=true).
  final bool demo;
  final ProfileRepo profile;
  final SettingsRepo settings;
  final ExerciseRepo exercises;
  final RoutineRepo routines;
  final ProgramRepo programs;
  final SessionRepo sessions;
  final NutritionRepo nutrition;
  final HealthRepo health;
  final CoachRepo coach;

  static const backupVersion = 1;

  /// Dépôts qui n'ont pas pu se charger au dernier [loadAll] (nom et erreur).
  /// Vide quand tout va bien.
  final Map<String, Object> erreursChargement = {};

  /// Charge tous les dépôts. Un dépôt qui échoue ne retient pas les autres :
  /// l'appli doit toujours pouvoir démarrer, l'échec est noté dans
  /// [erreursChargement].
  Future<void> loadAll() {
    erreursChargement.clear();
    Future<void> charger(String nom, Future<void> Function() load) async {
      try {
        await load();
      } catch (e) {
        erreursChargement[nom] = e;
      }
    }

    return Future.wait([
      charger('profil', profile.load),
      charger('reglages', settings.load),
      charger('exercices', exercises.load),
      charger('routines', routines.load),
      charger('programmes', programs.load),
      charger('seances', sessions.load),
      charger('nutrition', nutrition.load),
      charger('sante', health.load),
      charger('coach', coach.load),
    ]);
  }

  /// Efface toutes les données (le routeur repart sur l'inscription).
  Future<void> resetAll() async {
    await store.wipe();
    await loadAll();
  }

  /// Sauvegarde complète en JSON (sans les photos).
  Future<String> exportBackup() async {
    final data = await store.exportAll();
    return const JsonEncoder.withIndent(' ').convert({
      'application': 'aesthetic',
      'version': backupVersion,
      'date': DateTime.now().toIso8601String(),
      'donnees': data,
    });
  }

  /// Restaure une sauvegarde produite par [exportBackup].
  Future<void> importBackup(String raw) async {
    final j = jsonDecode(raw);
    if (j is! Map || j['application'] != 'aesthetic' || j['donnees'] is! Map) {
      throw const FormatException('Ce fichier n\'est pas une sauvegarde Aesthetics.');
    }
    await store.importAll(Map<String, Object?>.from(j['donnees'] as Map));
    await loadAll();
  }
}
