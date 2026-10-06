import 'package:collection/collection.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/logic/nutrition_calc.dart';
import '../../../core/models/models.dart';
import 'nutrition_extras.dart';

/// Objectifs d'un jour précis, cyclage compris.
class DayGoals {
  const DayGoals({required this.goals, required this.base, this.entrainement, this.ecartKcal = 0});

  /// Objectifs du jour (après cyclage).
  final NutritionGoals goals;

  /// Objectifs de base, avant cyclage.
  final NutritionGoals base;

  /// Vrai jour d'entraînement, faux jour de repos, null sans cyclage.
  final bool? entrainement;
  final double ecartKcal;

  String? get libelle => entrainement == null ? null : (entrainement! ? 'Jour d\'entraînement' : 'Jour de repos');
}

abstract final class NutritionLogic {
  /// Objectifs du jour [jour] selon le profil et le cyclage.
  static DayGoals goalsFor(DateTime jour, {UserProfile? profil, required CarbCycling cyclage, SessionRepo? sessions}) {
    final base = NutritionCalc.effectifs(profil);
    if (!cyclage.actif) return DayGoals(goals: base, base: base);
    final seance = cyclage.suivreSeances && sessions != null && sessions.sessionsOn(jour).isNotEmpty;
    final entrainement = seance || cyclage.joursEntrainement.contains(jour.weekday);
    final ecart = entrainement ? cyclage.bonusEntrainement : -cyclage.baisseRepos;
    final glucides = (base.glucidesG + ecart / 4).clamp(0, 2000).toDouble();
    return DayGoals(
      goals: base.copyWith(kcal: (base.kcal + ecart).clamp(800, 9000).toDouble(), glucidesG: glucides),
      base: base,
      entrainement: entrainement,
      ecartKcal: ecart,
    );
  }

  /// Totaux par jour sur [jours] jours finissant à [fin] (inclus).
  static List<(DateTime, Macros)> dailyTotals(NutritionRepo repo, DateTime fin, int jours) {
    final byDay = <DateTime, Macros>{};
    final start = Dates.jour(fin).subtract(Duration(days: jours - 1));
    for (final e in repo.entries) {
      final d = Dates.jour(e.date);
      if (d.isBefore(start) || d.isAfter(Dates.jour(fin))) continue;
      byDay[d] = (byDay[d] ?? Macros.zero) + e.macros;
    }
    return [
      for (var i = 0; i < jours; i++)
        () {
          final d = DateTime(start.year, start.month, start.day + i);
          return (d, byDay[d] ?? Macros.zero);
        }(),
    ];
  }

  /// Jours où au moins un aliment a été noté.
  static Set<DateTime> loggedDays(NutritionRepo repo) => {for (final e in repo.entries) Dates.jour(e.date)};

  /// Nombre de jours consécutifs notés jusqu'à aujourd'hui (hier compte si
  /// aujourd'hui est encore vide).
  static int streak(NutritionRepo repo, {DateTime? now}) {
    final days = loggedDays(repo);
    var d = Dates.jour(now ?? DateTime.now());
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  /// Aliments les plus notés sur la période.
  static List<(String, int, double)> topFoods(NutritionRepo repo, DateTime from, DateTime to, {int limit = 5}) {
    final count = <String, (int, double)>{};
    for (final e in repo.entries) {
      if (e.date.isBefore(from) || e.date.isAfter(to)) continue;
      final (n, k) = count[e.nom] ?? (0, 0.0);
      count[e.nom] = (n + 1, k + e.macros.kcal);
    }
    final list = count.entries.map((e) => (e.key, e.value.$1, e.value.$2)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list.take(limit).toList();
  }

  /// Écart relatif accepté pour dire qu'un objectif est tenu.
  static const tolerance = 0.10;

  static bool tenu(double valeur, double objectif) => objectif > 0 && (valeur - objectif).abs() / objectif <= tolerance;

  /// Heure proposée pour une entrée de [repas] au jour [jour].
  static DateTime heurePour(DateTime jour, MealType repas) {
    final now = DateTime.now();
    if (Dates.memeJour(jour, now) && MealType.pourHeure(now.hour) == repas) {
      return DateTime(jour.year, jour.month, jour.day, now.hour, now.minute);
    }
    return DateTime(jour.year, jour.month, jour.day, repas.heure);
  }

  /// Repas le plus probable à cette heure.
  static MealType repasParDefaut(DateTime jour) {
    final now = DateTime.now();
    return Dates.memeJour(jour, now) ? MealType.pourHeure(now.hour) : MealType.dejeuner;
  }

  static String dayParam(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parseDay(String? s) {
    if (s == null) return null;
    final d = DateTime.tryParse(s);
    return d == null ? null : Dates.jour(d);
  }

  static MealType? parseMeal(String? s) => MealType.values.firstWhereOrNull((m) => m.name == s);
}

/// Petites méthodes ajoutées au dépôt commun pour ce module.
extension NutritionRepoX on NutritionRepo {
  /// Déplace une entrée vers un autre repas ou un autre jour.
  Future<void> moveEntry(FoodEntry e, {DateTime? jour, MealType? repas}) async {
    final d = jour ?? e.date;
    await saveEntry(e.copyWith(
      date: DateTime(d.year, d.month, d.day, e.date.hour, e.date.minute),
      repas: repas ?? e.repas,
    ));
  }

  /// Duplique une entrée (même jour et même repas par défaut).
  Future<void> duplicateEntry(FoodEntry e, {DateTime? jour, MealType? repas}) async {
    final d = jour ?? e.date;
    await saveEntry(FoodEntry(
      id: newId(),
      date: DateTime(d.year, d.month, d.day, e.date.hour, e.date.minute),
      repas: repas ?? e.repas,
      nom: e.nom,
      quantiteG: e.quantiteG,
      macros: e.macros,
      foodId: e.foodId,
      portionLabel: e.portionLabel,
    ));
  }

  /// Copie un repas d'un jour vers un autre repas (et un autre jour).
  Future<int> copyMeal(DateTime from, MealType repasSource, DateTime to, MealType repasCible) async {
    final list = entriesFor(from, repasSource);
    await addEntries([
      for (final e in list)
        FoodEntry(
          id: newId(),
          date: DateTime(to.year, to.month, to.day, e.date.hour, e.date.minute),
          repas: repasCible,
          nom: e.nom,
          quantiteG: e.quantiteG,
          macros: e.macros,
          foodId: e.foodId,
          portionLabel: e.portionLabel,
        ),
    ]);
    return list.length;
  }

  Future<void> deleteEntries(Iterable<FoodEntry> list) async {
    for (final e in list.toList()) {
      await deleteEntry(e.id);
    }
  }
}
