import '../../../core/models/json.dart';
import '../../../core/models/nutrition.dart';

/// Recette : plusieurs aliments, un nombre de portions.
/// Chaque recette est aussi publiée comme aliment (id `recette-<id>`) pour
/// apparaître dans la recherche, les récents et les favoris.
class Recipe {
  const Recipe({
    required this.id,
    required this.nom,
    this.items = const [],
    this.portions = 1,
    this.notes,
    this.poidsCuitG,
  });

  final String id;
  final String nom;
  final List<MealItem> items;
  final double portions;
  final String? notes;

  /// Poids total une fois cuit (facultatif) ; sinon la somme des ingrédients.
  final double? poidsCuitG;

  static String foodIdFor(String recipeId) => 'recette-$recipeId';
  static bool isRecipeFood(String? foodId) => foodId != null && foodId.startsWith('recette-');
  static String recipeIdOf(String foodId) => foodId.substring('recette-'.length);

  Macros get total => items.fold(Macros.zero, (a, i) => a + i.macros);
  double get poidsIngredients => items.fold(0.0, (a, i) => a + i.grammes);
  double get poidsTotal => (poidsCuitG != null && poidsCuitG! > 0) ? poidsCuitG! : poidsIngredients;
  double get grammesParPortion => portions <= 0 ? poidsTotal : poidsTotal / portions;
  Macros get parPortion => portions <= 0 ? total : total.scale(1 / portions);

  /// L'aliment équivalent (valeurs pour 100 g, une portion nommée).
  Food toFood({bool favori = false}) {
    final poids = poidsTotal;
    return Food(
      id: foodIdFor(id),
      nom: nom,
      pour100g: poids <= 0 ? Macros.zero : total.scale(100 / poids),
      portions: [Portion(label: 'portion', grammes: grammesParPortion <= 0 ? 100 : grammesParPortion)],
      source: 'recette',
      favori: favori,
    );
  }

  Recipe copyWith({String? nom, List<MealItem>? items, double? portions, String? notes, double? poidsCuitG, bool clearPoids = false}) => Recipe(
        id: id,
        nom: nom ?? this.nom,
        items: items ?? this.items,
        portions: portions ?? this.portions,
        notes: notes ?? this.notes,
        poidsCuitG: clearPoids ? null : (poidsCuitG ?? this.poidsCuitG),
      );

  factory Recipe.fromJson(Json j) => Recipe(
        id: asString(j['id']) ?? '',
        nom: asString(j['nom']) ?? 'Recette',
        items: asList(j['items'], MealItem.fromJson),
        portions: asDouble(j['portions']) ?? 1,
        notes: asString(j['notes']),
        poidsCuitG: asDouble(j['poidsCuitG']),
      );

  Json toJson() => compact({
        'id': id,
        'nom': nom,
        'items': items.map((i) => i.toJson()).toList(),
        'portions': portions,
        'notes': notes,
        'poidsCuitG': poidsCuitG,
      });
}
