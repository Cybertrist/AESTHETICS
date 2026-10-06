import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import 'data/nutrition_logic.dart';
import 'data/recipe.dart';

/// Ce que la fiche aliment doit faire.
enum FoodPageMode {
  /// Ajouter au journal.
  ajouter,

  /// Modifier une entrée existante du journal.
  modifier,

  /// Choisir une quantité pour un repas enregistré ou une recette (rend un MealItem).
  choisir,
}

class FoodPageArgs {
  const FoodPageArgs({
    required this.food,
    this.mode = FoodPageMode.ajouter,
    this.entry,
    this.jour,
    this.repas,
    this.nutriscore,
    this.grammes,
    this.portionLabel,
  });

  final Food food;
  final FoodPageMode mode;
  final FoodEntry? entry;
  final DateTime? jour;
  final MealType? repas;
  final String? nutriscore;
  final double? grammes;
  final String? portionLabel;
}

/// Chemins et ouvertures des pages du module.
abstract final class NutritionNav {
  static const root = '/nutrition';

  static String _q(Map<String, String?> p) {
    final e = p.entries.where((e) => e.value != null).map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value!)}');
    return e.isEmpty ? '' : '?${e.join('&')}';
  }

  static String _d(DateTime? d) => d == null ? '' : NutritionLogic.dayParam(d);

  static Future<void> addFood(BuildContext context, {required DateTime jour, MealType? repas, bool scan = false}) =>
      context.push('$root/ajouter${_q({'jour': _d(jour), 'repas': repas?.name, 'scan': scan ? '1' : null})}');

  /// Choisir un aliment et une quantité (repas enregistré, recette).
  static Future<MealItem?> pickFood(BuildContext context) => context.push<MealItem>('$root/ajouter?choisir=1');

  static Future<String?> scan(BuildContext context) => context.push<String>('$root/scanner');

  static Future<Object?> food(BuildContext context, FoodPageArgs args) => context.push<Object>('$root/aliment', extra: args);

  /// Crée (ou modifie) un aliment perso ; rend l'aliment enregistré.
  static Future<Food?> editFood(BuildContext context, {Food? food, String? codeBarres, String? nom}) =>
      context.push<Food>('$root/aliment-perso${_q({'code': codeBarres, 'nom': nom})}', extra: food);

  static Future<void> quickAdd(BuildContext context, {required DateTime jour, MealType? repas, FoodEntry? entry}) =>
      context.push('$root/ajout-rapide${_q({'jour': _d(jour), 'repas': repas?.name})}', extra: entry);

  static Future<void> calendar(BuildContext context) => context.push('$root/calendrier');
  static Future<void> water(BuildContext context) => context.push('$root/eau');
  static Future<void> goals(BuildContext context) => context.push('$root/objectifs');
  static Future<void> stats(BuildContext context) => context.push('$root/statistiques');
  static Future<void> myFoods(BuildContext context) => context.push('$root/aliments');
  static Future<void> meals(BuildContext context) => context.push('$root/repas-enregistres');
  static Future<Meal?> editMeal(BuildContext context, {Meal? meal}) => context.push<Meal>('$root/repas-enregistres/edition', extra: meal);
  static Future<void> recipes(BuildContext context) => context.push('$root/recettes');
  static Future<Recipe?> editRecipe(BuildContext context, {Recipe? recipe}) => context.push<Recipe>('$root/recettes/edition', extra: recipe);
  static Future<void> recipe(BuildContext context, String id, {DateTime? jour, MealType? repas}) =>
      context.push('$root/recettes/fiche/$id${_q({'jour': jour == null ? null : _d(jour), 'repas': repas?.name})}');
  /// Détail d'un repas, ou de toute la journée si [repas] est null.
  static Future<void> mealDetail(BuildContext context, MealType? repas, DateTime jour) =>
      context.push('$root/repas/${repas?.name ?? 'journee'}${_q({'jour': _d(jour)})}');
  static Future<void> settings(BuildContext context) => context.push('$root/reglages');
}
