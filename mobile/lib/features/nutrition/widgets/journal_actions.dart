import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../data/nutrition_logic.dart';
import '../data/recipe.dart';
import '../nav.dart';

/// Choix d'un repas, avec les noms personnalisés.
Future<MealType?> pickMeal(BuildContext context, {MealType? selected, String title = 'Quel repas ?'}) {
  final x = NutritionExtras.of(context);
  return showChoiceDialog<MealType>(
    context,
    title: title,
    selected: selected,
    options: [for (final t in MealType.values) (t, x.nomRepas(t))],
  );
}

/// Choix d'un jour dans le calendrier.
Future<DateTime?> pickDay(BuildContext context, {required DateTime initial, String? help}) async {
  final now = DateTime.now();
  final d = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 1, 12, 31),
    helpText: help,
    cancelText: 'Annuler',
    confirmText: 'Choisir',
  );
  return d == null ? null : Dates.jour(d);
}

/// Ouvre une entrée du journal pour la modifier (fiche aliment ou ajout rapide).
Future<void> openEntry(BuildContext context, FoodEntry e) async {
  final repo = context.read<NutritionRepo>();
  final x = NutritionExtras.of(context);
  if (e.quantiteG <= 0) {
    await NutritionNav.quickAdd(context, jour: e.date, repas: e.repas, entry: e);
    return;
  }
  var food = e.foodId == null ? null : repo.foodById(e.foodId!);
  // Aliment supprimé depuis : on rebâtit ses valeurs depuis l'entrée.
  food ??= Food(id: e.foodId ?? '', nom: e.nom, pour100g: e.macros.scale(100 / e.quantiteG), source: 'journal');
  await NutritionNav.food(
    context,
    FoodPageArgs(
      food: food,
      mode: FoodPageMode.modifier,
      entry: e,
      jour: e.date,
      repas: e.repas,
      grammes: e.quantiteG,
      portionLabel: e.portionLabel,
      nutriscore: x.nutriscoreOf(food.id),
    ),
  );
}

/// Supprime une entrée avec possibilité d'annuler.
Future<void> deleteEntryWithUndo(BuildContext context, FoodEntry e) async {
  final repo = context.read<NutritionRepo>();
  await repo.deleteEntry(e.id);
  if (!context.mounted) return;
  Toasts.show(context, '${e.nom} retiré', icon: Icons.delete_outline_rounded, actionLabel: 'Annuler', onAction: () => repo.saveEntry(e));
}

enum _EntryAction { modifier, deplacer, dupliquer, copierJour, favori, supprimer }

/// Menu d'une entrée du journal (appui long).
Future<void> showEntryMenu(BuildContext context, FoodEntry e) async {
  final repo = context.read<NutritionRepo>();
  final food = e.foodId == null ? null : repo.foodById(e.foodId!);
  final a = await showActionMenu<_EntryAction>(
    context,
    title: e.nom,
    items: [
      const ActionMenuItem(value: _EntryAction.modifier, label: 'Modifier la quantité', icon: Icons.edit_rounded),
      const ActionMenuItem(value: _EntryAction.deplacer, label: 'Déplacer vers un autre repas', icon: Icons.swap_vert_rounded),
      const ActionMenuItem(value: _EntryAction.dupliquer, label: 'Dupliquer', icon: Icons.control_point_duplicate_rounded),
      const ActionMenuItem(value: _EntryAction.copierJour, label: 'Copier vers un autre jour', icon: Icons.event_repeat_rounded),
      if (food != null)
        ActionMenuItem(
          value: _EntryAction.favori,
          label: food.favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
          icon: food.favori ? Icons.star_outline_rounded : Icons.star_rounded,
        ),
      const ActionMenuItem(value: _EntryAction.supprimer, label: 'Supprimer', icon: Icons.delete_outline_rounded, destructive: true),
    ],
  );
  if (a == null || !context.mounted) return;
  final x = NutritionExtras.of(context);
  switch (a) {
    case _EntryAction.modifier:
      await openEntry(context, e);
    case _EntryAction.deplacer:
      final m = await pickMeal(context, selected: e.repas, title: 'Déplacer vers');
      if (m == null || m == e.repas) return;
      await repo.moveEntry(e, repas: m);
      if (context.mounted) Toasts.success(context, 'Déplacé vers ${x.nomRepas(m).toLowerCase()}');
    case _EntryAction.dupliquer:
      await repo.duplicateEntry(e);
      if (context.mounted) Toasts.success(context, 'Dupliqué');
    case _EntryAction.copierJour:
      final d = await pickDay(context, initial: e.date, help: 'Copier vers quel jour ?');
      if (d == null) return;
      await repo.duplicateEntry(e, jour: d);
      if (context.mounted) Toasts.success(context, 'Copié vers ${Fmt.relatif(d).toLowerCase()}');
    case _EntryAction.favori:
      await repo.toggleFavoriteFood(food!.id);
    case _EntryAction.supprimer:
      if (context.mounted) await deleteEntryWithUndo(context, e);
  }
}

enum _MealAction { ajouter, rapide, copierHier, copierDepuis, copierVers, enregistrer, recette, renommer, detail, vider }

/// Menu d'un repas du journal.
Future<void> showMealMenu(BuildContext context, MealType repas, DateTime jour, {bool showDetail = true}) async {
  final repo = context.read<NutritionRepo>();
  final x = NutritionExtras.of(context);
  final entries = repo.entriesFor(jour, repas);
  final hier = jour.subtract(const Duration(days: 1));
  final nbHier = repo.entriesFor(hier, repas).length;
  final a = await showActionMenu<_MealAction>(
    context,
    title: x.nomRepas(repas),
    items: [
      const ActionMenuItem(value: _MealAction.ajouter, label: 'Ajouter un aliment', icon: Icons.add_rounded),
      const ActionMenuItem(value: _MealAction.rapide, label: 'Ajout rapide de calories', icon: Icons.bolt_rounded),
      if (nbHier > 0) ActionMenuItem(value: _MealAction.copierHier, label: 'Copier celui de la veille (${Fmt.pluriel(nbHier, 'aliment')})', icon: Icons.history_rounded),
      const ActionMenuItem(value: _MealAction.copierDepuis, label: 'Copier depuis un autre jour', icon: Icons.event_rounded),
      if (entries.isNotEmpty) ...[
        const ActionMenuItem(value: _MealAction.copierVers, label: 'Copier vers un autre jour', icon: Icons.event_repeat_rounded),
        const ActionMenuItem(value: _MealAction.enregistrer, label: 'Enregistrer comme repas', icon: Icons.bookmark_add_rounded),
        const ActionMenuItem(value: _MealAction.recette, label: 'En faire une recette', icon: Icons.menu_book_rounded),
      ],
      const ActionMenuItem(value: _MealAction.renommer, label: 'Renommer ce repas', icon: Icons.drive_file_rename_outline_rounded),
      if (showDetail && entries.isNotEmpty) const ActionMenuItem(value: _MealAction.detail, label: 'Voir le détail', icon: Icons.insights_rounded),
      if (entries.isNotEmpty) const ActionMenuItem(value: _MealAction.vider, label: 'Vider ce repas', icon: Icons.delete_sweep_rounded, destructive: true),
    ],
  );
  if (a == null || !context.mounted) return;
  switch (a) {
    case _MealAction.ajouter:
      await NutritionNav.addFood(context, jour: jour, repas: repas);
    case _MealAction.rapide:
      await NutritionNav.quickAdd(context, jour: jour, repas: repas);
    case _MealAction.copierHier:
      final n = await repo.copyMeal(hier, repas, jour, repas);
      if (context.mounted) Toasts.success(context, '${Fmt.pluriel(n, 'aliment copié', 'aliments copiés')} depuis la veille');
    case _MealAction.copierDepuis:
      final d = await pickDay(context, initial: hier, help: 'Copier depuis quel jour ?');
      if (d == null || !context.mounted) return;
      final src = await pickMeal(context, selected: repas, title: 'Quel repas de ce jour ?');
      if (src == null) return;
      final n = await repo.copyMeal(d, src, jour, repas);
      if (!context.mounted) return;
      if (n == 0) {
        Toasts.show(context, 'Ce repas était vide ce jour-là.');
      } else {
        Toasts.success(context, Fmt.pluriel(n, 'aliment copié', 'aliments copiés'));
      }
    case _MealAction.copierVers:
      final d = await pickDay(context, initial: jour.add(const Duration(days: 1)), help: 'Copier vers quel jour ?');
      if (d == null) return;
      final n = await repo.copyMeal(jour, repas, d, repas);
      if (context.mounted) Toasts.success(context, '${Fmt.pluriel(n, 'aliment copié', 'aliments copiés')} vers ${Fmt.relatif(d).toLowerCase()}');
    case _MealAction.enregistrer:
      final nom = await showTextInputDialog(context, title: 'Nom du repas', initial: '${x.nomRepas(repas)} du ${Fmt.jourMois(jour)}', confirmLabel: 'Enregistrer');
      if (nom == null || nom.trim().isEmpty) return;
      await repo.saveMeal(Meal(
        id: '',
        nom: nom.trim(),
        repas: repas,
        items: [for (final e in entries) MealItem(foodId: e.foodId ?? '', nom: e.nom, grammes: e.quantiteG, macros: e.macros)],
      ));
      if (context.mounted) Toasts.success(context, 'Repas enregistré', actionLabel: 'Voir', onAction: () => NutritionNav.meals(context));
    case _MealAction.recette:
      final items = [
        for (final e in entries.where((e) => e.quantiteG > 0)) MealItem(foodId: e.foodId ?? '', nom: e.nom, grammes: e.quantiteG, macros: e.macros),
      ];
      await NutritionNav.editRecipe(context, recipe: Recipe(id: '', nom: '', items: items, portions: 1));
    case _MealAction.renommer:
      final nom = await showTextInputDialog(context, title: 'Renommer « ${x.nomRepas(repas)} »', initial: x.nomRepas(repas), hint: repas.label, maxLength: 30);
      if (nom == null) return;
      await x.renommerRepas(repas, nom);
    case _MealAction.detail:
      await NutritionNav.mealDetail(context, repas, jour);
    case _MealAction.vider:
      final ok = await showConfirmDialog(
        context,
        title: 'Vider ${x.nomRepas(repas).toLowerCase()} ?',
        message: '${Fmt.pluriel(entries.length, 'aliment')} seront retirés de ce jour.',
        confirmLabel: 'Vider',
        destructive: true,
      );
      if (!ok) return;
      await repo.deleteEntries(entries);
      if (context.mounted) {
        Toasts.show(context, 'Repas vidé', icon: Icons.delete_sweep_rounded, actionLabel: 'Annuler', onAction: () => repo.addEntries(entries));
      }
  }
}

/// Totaux et objectifs pour un jour, prêts à afficher.
DayGoals goalsOf(BuildContext context, DateTime jour, {bool listen = true}) {
  final profil = listen ? context.watch<ProfileRepo>().profile : context.read<ProfileRepo>().profile;
  final sessions = listen ? context.watch<SessionRepo>() : context.read<SessionRepo>();
  final x = NutritionExtras.of(context);
  return NutritionLogic.goalsFor(jour, profil: profil, cyclage: x.cyclage, sessions: sessions);
}

/// Enregistre des objectifs dans le profil. Faux s'il n'y a pas de profil.
Future<bool> saveGoals(BuildContext context, NutritionGoals goals) async {
  final profiles = context.read<ProfileRepo>();
  if (profiles.profile == null) {
    Toasts.error(context, 'Crée d\'abord ton profil pour enregistrer des objectifs.');
    return false;
  }
  await profiles.update((p) => p.copyWith(objectifsNutrition: goals));
  return true;
}
