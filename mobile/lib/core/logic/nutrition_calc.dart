import '../models/nutrition.dart';
import '../models/user_profile.dart';

/// Besoins caloriques et répartition des macros.
abstract final class NutritionCalc {
  /// Métabolisme de base, Mifflin-St Jeor (kcal/jour).
  static double metabolismeDeBase({required Sexe sexe, required double poidsKg, required double tailleCm, required int age}) {
    final base = 10 * poidsKg + 6.25 * tailleCm - 5 * age;
    return switch (sexe) {
      Sexe.homme => base + 5,
      Sexe.femme => base - 161,
      Sexe.autre => base - 78,
    };
  }

  /// Dépense totale : métabolisme × facteur d'activité.
  static double depenseTotale(UserProfile p) {
    final bmr = metabolismeDeBase(
      sexe: p.sexe,
      poidsKg: p.poidsKg ?? 75,
      tailleCm: p.tailleCm ?? 178,
      age: p.age ?? 28,
    );
    return bmr * p.activite.facteur;
  }

  /// Ajustement selon l'objectif (en kcal par jour).
  static double ajustement(Objectif o) => switch (o) {
        Objectif.prendreDuMuscle => 300,
        Objectif.secher => -450,
        Objectif.recomposition => -150,
        Objectif.force => 200,
        Objectif.forme => 0,
      };

  /// Objectifs complets calculés depuis le profil.
  static NutritionGoals objectifs(UserProfile p) {
    final poids = p.poidsKg ?? 75;
    final kcal = _arrondi(depenseTotale(p) + ajustement(p.objectif), 10);
    // Protéines : 2 g/kg (2,2 en sèche), lipides : 0,9 g/kg, le reste en glucides.
    final protParKg = p.objectif == Objectif.secher ? 2.2 : (p.objectif == Objectif.forme ? 1.6 : 2.0);
    final proteines = _arrondi(poids * protParKg, 5);
    final lipides = _arrondi(poids * 0.9, 5);
    final glucides = _arrondi(((kcal - proteines * 4 - lipides * 9) / 4).clamp(50, 1000), 5);
    final eau = (_arrondi(poids * 35, 250)).round().clamp(1500, 5000);
    return NutritionGoals(kcal: kcal, proteinesG: proteines, glucidesG: glucides, lipidesG: lipides, fibresG: 30, eauMl: eau);
  }

  /// Objectifs du profil s'ils existent, sinon calculés.
  static NutritionGoals effectifs(UserProfile? p) =>
      p == null ? const NutritionGoals() : (p.objectifsNutrition ?? objectifs(p));

  /// Calories des macros (4, 4, 9).
  static double kcalDesMacros({double proteines = 0, double glucides = 0, double lipides = 0}) =>
      proteines * 4 + glucides * 4 + lipides * 9;

  /// Indice de masse corporelle.
  static double? imc(double? poidsKg, double? tailleCm) {
    if (poidsKg == null || tailleCm == null || tailleCm <= 0) return null;
    final m = tailleCm / 100;
    return poidsKg / (m * m);
  }

  static double _arrondi(double v, double pas) => (v / pas).round() * pas;
}
