import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/nutrition/data/nutrition_extras.dart';
import 'package:aesthetic/features/nutrition/data/nutrition_logic.dart';
import 'package:aesthetic/features/nutrition/data/off_client.dart';
import 'package:aesthetic/features/nutrition/data/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recette : valeurs par portion et aliment équivalent', () {
    const r = Recipe(id: 'x', nom: 'Bol', portions: 2, items: [
      MealItem(foodId: 'a', nom: 'Riz', grammes: 200, macros: Macros(kcal: 260, glucides: 56, proteines: 5)),
      MealItem(foodId: 'b', nom: 'Poulet', grammes: 200, macros: Macros(kcal: 330, proteines: 62, lipides: 7)),
    ]);
    expect(r.parPortion.kcal, 295);
    expect(r.grammesParPortion, 200);
    final f = r.toFood();
    expect(f.id, 'recette-x');
    expect(f.pour(200).kcal, closeTo(295, 0.001));
    expect(r.copyWith(poidsCuitG: 300).grammesParPortion, 150);
  });

  test('cyclage : bonus les jours d\'entraînement, baisse au repos', () {
    const cy = CarbCycling(actif: true, joursEntrainement: {1}, bonusEntrainement: 200, baisseRepos: 100, suivreSeances: false);
    final lundi = DateTime(2026, 9, 28);
    final mardi = DateTime(2026, 9, 29);
    final profil = UserProfile(id: 'p', prenom: 'T', creeLe: DateTime(2026), objectifsNutrition: const NutritionGoals(kcal: 2500, glucidesG: 300));
    final a = NutritionLogic.goalsFor(lundi, profil: profil, cyclage: cy);
    final b = NutritionLogic.goalsFor(mardi, profil: profil, cyclage: cy);
    expect(a.goals.kcal, 2700);
    expect(a.goals.glucidesG, 350);
    expect(a.entrainement, isTrue);
    expect(b.goals.kcal, 2400);
    expect(b.entrainement, isFalse);
    expect(NutritionLogic.goalsFor(lundi, profil: profil, cyclage: const CarbCycling()).goals.kcal, 2500);
  });

  test('produit en ligne : lecture tolérante', () {
    final f = OpenFoodFactsClient.parseProduct({
      'code': '123',
      'product_name_fr': 'skyr nature',
      'brands': 'Marque, Autre',
      'nutriments': {'energy-kj_100g': 418.4, 'proteins_100g': 10, 'carbohydrates_100g': 4, 'fat_100g': 0.2},
      'nutriscore_grade': 'A',
      'serving_quantity': 150,
      'serving_size': '150 g',
    });
    expect(f, isNotNull);
    expect(f!.food.nom, 'Skyr nature');
    expect(f.food.marque, 'Marque');
    expect(f.food.pour100g.kcal, closeTo(100, 0.01));
    expect(f.nutriscore, 'a');
    expect(f.food.portions.single.grammes, 150);
    expect(OpenFoodFactsClient.parseProduct({'code': '1', 'product_name': 'Sans valeurs'}), isNull);
  });

  test('journal : copier un repas de la veille et renommer', () async {
    final store = Store.memory();
    final repo = NutritionRepo(store);
    final hier = DateTime(2026, 9, 29, 12);
    const food = Food(id: 'f', nom: 'Riz', pour100g: Macros(kcal: 130));
    await repo.addFood(food, 200, date: hier, repas: MealType.dejeuner);
    final n = await repo.copyMeal(hier, MealType.dejeuner, DateTime(2026, 9, 30), MealType.diner);
    expect(n, 1);
    expect(repo.totalsFor(DateTime(2026, 9, 30), MealType.diner).kcal, 260);

    final x = NutritionExtras(store);
    await x.load();
    await x.renommerRepas(MealType.collation, 'Post-séance');
    expect(x.nomRepas(MealType.collation), 'Post-séance');
    final relu = NutritionExtras(store);
    await relu.load();
    expect(relu.nomRepas(MealType.collation), 'Post-séance');
    await relu.renommerRepas(MealType.collation, '');
    expect(relu.nomRepas(MealType.collation), 'Collation');
  });
}
