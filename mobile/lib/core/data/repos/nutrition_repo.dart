import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../logic/dates.dart';
import '../../logic/text_search.dart';
import '../../models/models.dart';
import '../collection.dart';
import '../store.dart';

/// Aliments, journal des repas, repas enregistrés et eau.
/// Les objectifs vivent dans le profil (voir NutritionCalc.effectifs).
class NutritionRepo extends ChangeNotifier {
  NutritionRepo(this.store)
      : _foods = JsonCollection(store: store, name: 'aliments', fromJson: Food.fromJson, toJson: (f) => f.toJson(), idOf: (f) => f.id),
        _entries = JsonCollection(store: store, name: 'journal_repas', fromJson: FoodEntry.fromJson, toJson: (e) => e.toJson(), idOf: (e) => e.id),
        _meals = JsonCollection(store: store, name: 'repas_enregistres', fromJson: Meal.fromJson, toJson: (m) => m.toJson(), idOf: (m) => m.id),
        _water = JsonCollection(store: store, name: 'eau', fromJson: WaterLog.fromJson, toJson: (w) => w.toJson(), idOf: (w) => w.id);

  final Store store;
  final JsonCollection<Food> _foods;
  final JsonCollection<FoodEntry> _entries;
  final JsonCollection<Meal> _meals;
  final JsonCollection<WaterLog> _water;
  List<Food> _catalogue = [];

  /// Base d'aliments embarquée (facultative) : assets/data/aliments.json.
  static const catalogueAsset = 'assets/data/aliments.json';

  List<Food> get foodsPerso => _foods.items;
  List<Food> get catalogue => _catalogue;
  List<Food> get allFoods => [..._foods.items, ..._catalogue];
  List<Meal> get meals => [..._meals.items]..sort((a, b) => a.nom.compareTo(b.nom));
  List<FoodEntry> get entries => _entries.items;

  Future<void> load() async {
    await Future.wait([_foods.load(), _entries.load(), _meals.load(), _water.load()]);
    _catalogue = await _loadCatalogue();
    notifyListeners();
  }

  static Future<List<Food>> _loadCatalogue() async {
    try {
      final raw = jsonDecode(await rootBundle.loadString(catalogueAsset));
      final list = raw is Map ? raw['aliments'] : raw;
      if (list is! List) return [];
      return list.whereType<Map>().map((e) => Food.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  // Aliments

  Food? foodById(String id) => _foods.byId(id) ?? _catalogue.firstWhereOrNull((f) => f.id == id);

  Food? foodByBarcode(String code) => allFoods.firstWhereOrNull((f) => f.codeBarres == code);

  List<Food> searchFoods(String query, {int limit = 60}) {
    if (query.trim().isEmpty) return allFoods.take(limit).toList();
    final scored = <(Food, int)>[];
    for (final f in allFoods) {
      final s = TextSearch.score(query, f.nom, [f.marque]);
      if (s > 0) scored.add((f, s + (f.favori ? 5 : 0)));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  List<Food> get favoriteFoods => allFoods.where((f) => f.favori).toList();

  /// Aliments notés récemment, sans doublon.
  List<Food> recentFoods({int limit = 20}) {
    final sorted = [..._entries.items]..sort((a, b) => b.date.compareTo(a.date));
    final out = <Food>[];
    final seen = <String>{};
    for (final e in sorted) {
      final id = e.foodId;
      if (id == null || !seen.add(id)) continue;
      final f = foodById(id);
      if (f != null) out.add(f);
      if (out.length >= limit) break;
    }
    return out;
  }

  Future<Food> saveFood(Food f) async {
    final food = f.id.isEmpty ? Food.fromJson({...f.toJson(), 'id': newId()}) : f;
    await _foods.upsert(food);
    notifyListeners();
    return food;
  }

  Future<void> deleteFood(String id) async {
    await _foods.remove(id);
    notifyListeners();
  }

  Future<void> toggleFavoriteFood(String id) async {
    final f = foodById(id);
    if (f == null) return;
    await saveFood(f.copyWith(favori: !f.favori));
  }

  // Journal

  List<FoodEntry> entriesFor(DateTime day, [MealType? repas]) => _entries.items
      .where((e) => Dates.memeJour(e.date, day) && (repas == null || e.repas == repas))
      .sorted((a, b) => a.date.compareTo(b.date));

  Macros totalsFor(DateTime day, [MealType? repas]) =>
      entriesFor(day, repas).fold(Macros.zero, (a, e) => a + e.macros);

  /// Ajoute un aliment au journal (quantité en grammes).
  Future<FoodEntry> addFood(Food f, double grammes, {required DateTime date, required MealType repas, String? portionLabel}) async {
    final e = FoodEntry(
      id: newId(),
      date: date,
      repas: repas,
      nom: f.marque == null ? f.nom : '${f.nom} (${f.marque})',
      quantiteG: grammes,
      macros: f.pour(grammes),
      foodId: f.id,
      portionLabel: portionLabel,
    );
    // Un aliment venu du catalogue ou d'un scan est gardé pour les récents.
    if (_foods.byId(f.id) == null && _catalogue.every((c) => c.id != f.id)) {
      await _foods.upsert(f);
    }
    await _entries.upsert(e);
    notifyListeners();
    return e;
  }

  Future<void> saveEntry(FoodEntry e) async {
    await _entries.upsert(e);
    notifyListeners();
  }

  Future<void> addEntries(List<FoodEntry> list) async {
    await _entries.upsertAll(list);
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    await _entries.remove(id);
    notifyListeners();
  }

  /// Copie les repas d'un jour vers un autre.
  Future<void> copyDay(DateTime from, DateTime to, [MealType? repas]) async {
    final copies = [
      for (final e in entriesFor(from, repas))
        FoodEntry(
          id: newId(),
          date: DateTime(to.year, to.month, to.day, e.date.hour, e.date.minute),
          repas: e.repas,
          nom: e.nom,
          quantiteG: e.quantiteG,
          macros: e.macros,
          foodId: e.foodId,
          portionLabel: e.portionLabel,
        ),
    ];
    await addEntries(copies);
  }

  // Repas enregistrés

  Future<Meal> saveMeal(Meal m) async {
    final meal = m.id.isEmpty ? Meal.fromJson({...m.toJson(), 'id': newId()}) : m;
    await _meals.upsert(meal);
    notifyListeners();
    return meal;
  }

  Future<void> deleteMeal(String id) async {
    await _meals.remove(id);
    notifyListeners();
  }

  Future<void> addMealToDay(Meal m, {required DateTime date, required MealType repas}) async {
    await addEntries([
      for (final i in m.items)
        FoodEntry(id: newId(), date: date, repas: repas, nom: i.nom, quantiteG: i.grammes, macros: i.macros, foodId: i.foodId),
    ]);
  }

  // Eau

  int waterFor(DateTime day) => _water.items.where((w) => Dates.memeJour(w.date, day)).fold(0, (a, w) => a + w.ml);

  List<WaterLog> waterLogsFor(DateTime day) => _water.items.where((w) => Dates.memeJour(w.date, day)).toList();

  Future<void> addWater(int ml, {DateTime? date}) async {
    await _water.upsert(WaterLog(id: newId(), date: date ?? DateTime.now(), ml: ml));
    notifyListeners();
  }

  /// Retire le dernier verre du jour.
  Future<void> undoWater(DateTime day) async {
    final logs = waterLogsFor(day)..sort((a, b) => a.date.compareTo(b.date));
    if (logs.isEmpty) return;
    await _water.remove(logs.last.id);
    notifyListeners();
  }

  Future<void> addWaterLogs(List<WaterLog> list) async {
    await _water.upsertAll(list);
    notifyListeners();
  }

  Future<void> clear() async {
    await Future.wait([_foods.clear(), _entries.clear(), _meals.clear(), _water.clear()]);
    notifyListeners();
  }
}
