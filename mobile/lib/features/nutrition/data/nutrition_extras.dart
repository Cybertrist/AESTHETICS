import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/models/models.dart';
import 'recipe.dart';

/// Cyclage des calories : plus les jours d'entraînement, moins au repos.
class CarbCycling {
  const CarbCycling({
    this.actif = false,
    this.joursEntrainement = const {1, 2, 4, 5},
    this.bonusEntrainement = 200,
    this.baisseRepos = 200,
    this.suivreSeances = true,
  });

  final bool actif;

  /// Jours de la semaine (1 = lundi ... 7 = dimanche).
  final Set<int> joursEntrainement;

  /// Calories ajoutées un jour d'entraînement (en glucides).
  final double bonusEntrainement;

  /// Calories retirées un jour de repos (en glucides).
  final double baisseRepos;

  /// Un jour avec une séance enregistrée compte comme entraînement.
  final bool suivreSeances;

  CarbCycling copyWith({bool? actif, Set<int>? joursEntrainement, double? bonusEntrainement, double? baisseRepos, bool? suivreSeances}) =>
      CarbCycling(
        actif: actif ?? this.actif,
        joursEntrainement: joursEntrainement ?? this.joursEntrainement,
        bonusEntrainement: bonusEntrainement ?? this.bonusEntrainement,
        baisseRepos: baisseRepos ?? this.baisseRepos,
        suivreSeances: suivreSeances ?? this.suivreSeances,
      );

  factory CarbCycling.fromJson(Json? j) => j == null
      ? const CarbCycling()
      : CarbCycling(
          actif: asBool(j['actif']),
          joursEntrainement: (j['jours'] is List) ? (j['jours'] as List).map((e) => asInt(e) ?? 0).where((e) => e >= 1 && e <= 7).toSet() : const {1, 2, 4, 5},
          bonusEntrainement: asDouble(j['bonus']) ?? 200,
          baisseRepos: asDouble(j['baisse']) ?? 200,
          suivreSeances: asBool(j['suivreSeances'], true),
        );

  Json toJson() => {
        'actif': actif,
        'jours': joursEntrainement.toList()..sort(),
        'bonus': bonusEntrainement,
        'baisse': baisseRepos,
        'suivreSeances': suivreSeances,
      };
}

/// Ce que le module nutrition garde en plus du dépôt commun : noms des
/// repas, cyclage, taille du verre, recettes, Nutri-Score des aliments,
/// cache de la recherche en ligne et jour affiché dans le journal.
class NutritionExtras extends ChangeNotifier {
  NutritionExtras(this.store);

  final Store store;

  static const _prefsName = 'nutrition_reglages';
  static const _recipesName = 'nutrition_recettes';
  static const cacheName = 'nutrition_cache_en_ligne';

  static final Expando<NutritionExtras> _instances = Expando('nutrition');

  /// L'instance liée au stockage de l'appli (chargée à la première demande).
  static NutritionExtras of(BuildContext context) => forStore(context.read<Store>());

  static NutritionExtras forStore(Store store) {
    final existing = _instances[store];
    if (existing != null) return existing;
    final created = NutritionExtras(store);
    _instances[store] = created;
    created.load();
    return created;
  }

  bool _loaded = false;
  bool get loaded => _loaded;
  Future<void>? _loading;

  Map<MealType, String> _noms = {};
  int _verreMl = 250;
  bool _rechercheEnLigne = true;
  CarbCycling _cyclage = const CarbCycling();
  Map<String, String> _nutriscore = {};
  List<String> _recherches = [];
  List<Recipe> _recettes = [];

  /// Jour affiché dans le journal (partagé entre le journal et le calendrier).
  final ValueNotifier<DateTime> jour = ValueNotifier(Dates.jour(DateTime.now()));

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final p = await store.readObject(_prefsName) ?? {};
    final noms = asJson(p['noms']) ?? {};
    _noms = {
      for (final t in MealType.values)
        if (asString(noms[t.name])?.trim().isNotEmpty ?? false) t: asString(noms[t.name])!.trim(),
    };
    _verreMl = asInt(p['verreMl']) ?? 250;
    _rechercheEnLigne = asBool(p['enLigne'], true);
    _cyclage = CarbCycling.fromJson(asJson(p['cyclage']));
    _nutriscore = (asJson(p['nutriscore']) ?? {}).map((k, v) => MapEntry(k, v.toString()));
    _recherches = asStringList(p['recherches']);
    _recettes = (await store.readList(_recipesName)).map(Recipe.fromJson).toList();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _savePrefs() => store.write(_prefsName, {
        'noms': {for (final e in _noms.entries) e.key.name: e.value},
        'verreMl': _verreMl,
        'enLigne': _rechercheEnLigne,
        'cyclage': _cyclage.toJson(),
        'nutriscore': _nutriscore,
        'recherches': _recherches,
      });

  // Noms des repas

  String nomRepas(MealType t) => _noms[t] ?? t.label;
  bool estRenomme(MealType t) => _noms.containsKey(t);

  Future<void> renommerRepas(MealType t, String? nom) async {
    final n = nom?.trim() ?? '';
    if (n.isEmpty || n == t.label) {
      _noms.remove(t);
    } else {
      _noms[t] = n;
    }
    notifyListeners();
    await _savePrefs();
  }

  // Eau

  int get verreMl => _verreMl;
  Future<void> setVerreMl(int ml) async {
    _verreMl = ml.clamp(50, 2000);
    notifyListeners();
    await _savePrefs();
  }

  // Recherche en ligne

  bool get rechercheEnLigne => _rechercheEnLigne;
  Future<void> setRechercheEnLigne(bool v) async {
    _rechercheEnLigne = v;
    notifyListeners();
    await _savePrefs();
  }

  List<String> get recherchesRecentes => List.unmodifiable(_recherches);

  Future<void> noterRecherche(String q) async {
    final t = q.trim();
    if (t.length < 2) return;
    _recherches = [t, ..._recherches.where((e) => e.toLowerCase() != t.toLowerCase())].take(8).toList();
    notifyListeners();
    await _savePrefs();
  }

  Future<void> effacerRecherches() async {
    _recherches = [];
    notifyListeners();
    await _savePrefs();
  }

  // Cyclage

  CarbCycling get cyclage => _cyclage;
  Future<void> setCyclage(CarbCycling c) async {
    _cyclage = c;
    notifyListeners();
    await _savePrefs();
  }

  // Nutri-Score (lettre a..e) des aliments venus de la base en ligne

  String? nutriscoreOf(String foodId) => _nutriscore[foodId];

  Future<void> setNutriscore(String foodId, String? grade) async {
    final g = grade?.toLowerCase();
    if (g == null || !'abcde'.contains(g) || g.length != 1) return;
    if (_nutriscore[foodId] == g) return;
    _nutriscore[foodId] = g;
    await _savePrefs();
  }

  // Recettes

  List<Recipe> get recettes => [..._recettes]..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

  Recipe? recetteById(String id) {
    for (final r in _recettes) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Enregistre la recette et met à jour l'aliment qui la représente.
  Future<Recipe> saveRecipe(Recipe r, NutritionRepo repo) async {
    final recipe = r.id.isEmpty ? Recipe.fromJson({...r.toJson(), 'id': newId()}) : r;
    final i = _recettes.indexWhere((e) => e.id == recipe.id);
    if (i < 0) {
      _recettes.add(recipe);
    } else {
      _recettes[i] = recipe;
    }
    await store.write(_recipesName, _recettes.map((e) => e.toJson()).toList());
    final old = repo.foodById(Recipe.foodIdFor(recipe.id));
    await repo.saveFood(recipe.toFood(favori: old?.favori ?? false));
    notifyListeners();
    return recipe;
  }

  Future<void> deleteRecipe(String id, NutritionRepo repo) async {
    _recettes.removeWhere((e) => e.id == id);
    await store.write(_recipesName, _recettes.map((e) => e.toJson()).toList());
    await repo.deleteFood(Recipe.foodIdFor(id));
    notifyListeners();
  }

  /// Réglages remis à zéro (les recettes restent).
  Future<void> reinitialiserReglages() async {
    _noms = {};
    _verreMl = 250;
    _rechercheEnLigne = true;
    _cyclage = const CarbCycling();
    notifyListeners();
    await _savePrefs();
  }
}
