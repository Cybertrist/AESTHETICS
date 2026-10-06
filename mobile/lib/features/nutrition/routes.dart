import 'package:go_router/go_router.dart';

import '../../app/navigation.dart';
import '../../core/models/models.dart';
import 'data/nutrition_logic.dart';
import 'data/recipe.dart';
import 'nav.dart';
import 'pages/add_food_page.dart';
import 'pages/calendar_page.dart';
import 'pages/food_editor_page.dart';
import 'pages/food_page.dart';
import 'pages/goals_page.dart';
import 'pages/journal_page.dart';
import 'pages/meal_detail_page.dart';
import 'pages/my_foods_page.dart';
import 'pages/quick_add_page.dart';
import 'pages/recipes_page.dart';
import 'pages/saved_meals_page.dart';
import 'pages/scanner_page.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';
import 'pages/water_page.dart';

/// Routes du module nutrition. Les saisies (ajout, fiche, scan, éditeurs)
/// s'ouvrent en plein écran au-dessus de la barre des onglets.
List<RouteBase> nutritionRoutes() => [
      GoRoute(
        path: '/nutrition',
        builder: (context, state) => JournalPage(initialDay: NutritionLogic.parseDay(state.uri.queryParameters['jour'])),
        routes: [
          GoRoute(path: 'calendrier', builder: (context, state) => const CalendarPage()),
          GoRoute(
            path: 'ajouter',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) {
              final q = state.uri.queryParameters;
              return AddFoodPage(
                jour: NutritionLogic.parseDay(q['jour']),
                repas: NutritionLogic.parseMeal(q['repas']),
                choisir: q['choisir'] == '1',
                scanAuDemarrage: q['scan'] == '1',
              );
            },
          ),
          GoRoute(path: 'scanner', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const ScannerPage()),
          GoRoute(
            path: 'aliment',
            parentNavigatorKey: rootNavigatorKey,
            redirect: (context, state) => state.extra is FoodPageArgs ? null : NutritionNav.root,
            builder: (context, state) => FoodPage(args: state.extra! as FoodPageArgs),
          ),
          GoRoute(
            path: 'aliment-perso',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => FoodEditorPage(
              food: state.extra is Food ? state.extra! as Food : null,
              codeBarres: state.uri.queryParameters['code'],
              nom: state.uri.queryParameters['nom'],
            ),
          ),
          GoRoute(
            path: 'ajout-rapide',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => QuickAddPage(
              jour: NutritionLogic.parseDay(state.uri.queryParameters['jour']),
              repas: NutritionLogic.parseMeal(state.uri.queryParameters['repas']),
              entry: state.extra is FoodEntry ? state.extra! as FoodEntry : null,
            ),
          ),
          GoRoute(
            path: 'repas/:repas',
            builder: (context, state) => MealDetailPage(
              jour: NutritionLogic.parseDay(state.uri.queryParameters['jour']) ?? DateTime.now(),
              repas: NutritionLogic.parseMeal(state.pathParameters['repas']),
            ),
          ),
          GoRoute(path: 'eau', builder: (context, state) => const WaterPage()),
          GoRoute(path: 'objectifs', builder: (context, state) => const GoalsPage()),
          GoRoute(path: 'statistiques', builder: (context, state) => const StatsPage()),
          GoRoute(path: 'aliments', builder: (context, state) => const MyFoodsPage()),
          GoRoute(
            path: 'repas-enregistres',
            builder: (context, state) => const SavedMealsPage(),
            routes: [
              GoRoute(
                path: 'edition',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => MealEditorPage(meal: state.extra is Meal ? state.extra! as Meal : null),
              ),
            ],
          ),
          GoRoute(
            path: 'recettes',
            builder: (context, state) => const RecipesPage(),
            routes: [
              GoRoute(
                path: 'edition',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => RecipeEditorPage(recipe: state.extra is Recipe ? state.extra! as Recipe : null),
              ),
              GoRoute(
                path: 'fiche/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => RecipeDetailPage(
                  id: state.pathParameters['id']!,
                  jour: NutritionLogic.parseDay(state.uri.queryParameters['jour']),
                  repas: NutritionLogic.parseMeal(state.uri.queryParameters['repas']),
                ),
              ),
            ],
          ),
          GoRoute(path: 'reglages', builder: (context, state) => const NutritionSettingsPage()),
        ],
      ),
    ];
