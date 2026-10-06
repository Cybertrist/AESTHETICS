import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../data/nutrition_logic.dart';
import '../data/recipe.dart';
import '../nav.dart';
import '../widgets/nutri_page.dart';
import '../widgets/journal_actions.dart';
import '../widgets/nutri_widgets.dart';

/// Liste des recettes.
class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final x = NutritionExtras.of(context);
    return ListenableBuilder(
      listenable: x,
      builder: (context, _) {
        final list = x.recettes;
        return NutriSubPage(
          title: 'Recettes',
          haloColor: c.weight,
          actions: [IconButton(tooltip: 'Nouvelle recette', onPressed: () => NutritionNav.editRecipe(context), icon: const Icon(Icons.add_rounded))],
          body: !x.loaded
              ? const Padding(padding: EdgeInsets.all(AppTokens.gutter), child: SkeletonList(count: 4))
              : list.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTokens.gutter),
                        child: EmptyState(
                          icon: Icons.menu_book_outlined,
                          iconColor: c.weight,
                          title: 'Aucune recette',
                          message: 'Assemble tes ingrédients, indique le nombre de portions : chaque part se note ensuite en un geste.',
                          actionLabel: 'Créer une recette',
                          onAction: () => NutritionNav.editRecipe(context),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                      children: [
                        TileGroup(
                          label: Fmt.pluriel(list.length, 'recette').toUpperCase(),
                          children: [for (final r in list) RecipeRow(recipe: r, onTap: () => NutritionNav.recipe(context, r.id))],
                        ),
                      ],
                    ),
        );
      },
    );
  }
}

/// Fiche d'une recette : valeurs par portion, ingrédients, ajout au journal.
class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({super.key, required this.id, this.jour, this.repas});
  final String id;
  final DateTime? jour;
  final MealType? repas;

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  late final NutritionExtras x = NutritionExtras.of(context);
  double _parts = 1;
  late DateTime _jour = widget.jour ?? x.jour.value;
  late MealType _repas = widget.repas ?? NutritionLogic.repasParDefaut(_jour);

  Future<void> _add(Recipe r) async {
    final repo = context.read<NutritionRepo>();
    final food = repo.foodById(Recipe.foodIdFor(r.id)) ?? await repo.saveFood(r.toFood());
    await repo.addFood(food, r.grammesParPortion * _parts, date: NutritionLogic.heurePour(_jour, _repas), repas: _repas, portionLabel: '${numberText(_parts, decimals: 2)} portion');
    if (!mounted) return;
    Toasts.success(context, '${Fmt.pluriel(_parts, 'portion')} de ${r.nom} ajoutée${_parts >= 2 ? 's' : ''}');
    Navigator.of(context).pop();
  }

  Future<void> _delete(Recipe r) async {
    final ok = await showConfirmDialog(context, title: 'Supprimer « ${r.nom} » ?', message: 'Les portions déjà notées restent dans le journal.', confirmLabel: 'Supprimer', destructive: true);
    if (!ok || !mounted) return;
    await x.deleteRecipe(r.id, context.read<NutritionRepo>());
    if (!mounted) return;
    Toasts.show(context, 'Recette supprimée');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: x,
      builder: (context, _) {
        final r = x.recetteById(widget.id);
        if (!x.loaded) return const NutriSubPage(title: 'Recette', body: Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 4)));
        if (r == null) {
          return NutriSubPage(
            title: 'Recette',
            body: EmptyState(icon: Icons.menu_book_outlined, title: 'Recette introuvable', message: 'Elle a peut-être été supprimée.', actionLabel: 'Retour', onAction: () => Navigator.of(context).pop()),
          );
        }
        final m = r.parPortion.scale(_parts);
        final entete = AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconHalo(icon: Icons.menu_book_rounded, color: c.weight, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.nom, style: AppType.rowTitle().copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${Fmt.pluriel(r.portions, 'portion')} de ${Fmt.n(r.grammesParPortion, decimals: 0)} g · ${Fmt.kcal(r.total.kcal)} au total', style: AppType.rowSubtitle()),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            NumberStepper(value: _parts, onChanged: (v) => setState(() => _parts = v), step: 0.5, min: 0.5, max: 50, decimals: 1, unit: 'portion', label: 'Combien de portions ?'),
            const SizedBox(height: 18),
            BigNumber(value: Fmt.n(m.kcal, decimals: 0), unit: 'kcal', size: 38, caption: '${Fmt.n(r.grammesParPortion * _parts, decimals: 0)} g'),
            const SizedBox(height: 14),
            MacroTriplet(macros: m),
          ]),
        );
        final cible = TileGroup(margin: EdgeInsets.zero, children: [
          ListTileX(
            leading: IconHalo(icon: mealIcon(_repas), color: c.nutrition, size: 38),
            title: 'Repas',
            value: x.nomRepas(_repas),
            showChevron: true,
            onTap: () async {
              final v = await pickMeal(context, selected: _repas);
              if (v != null) setState(() => _repas = v);
            },
          ),
          ListTileX(
            leading: IconHalo(icon: Icons.event_rounded, color: c.nutrition, size: 38),
            title: 'Jour',
            value: Dates.memeJour(_jour, DateTime.now()) ? 'Aujourd\'hui' : Fmt.relatif(_jour),
            showChevron: true,
            onTap: () async {
              final d = await pickDay(context, initial: _jour);
              if (d != null) setState(() => _jour = d);
            },
          ),
        ]);
        final ingredients = AppCard(
          label: 'INGRÉDIENTS',
          labelTrailing: LabelCount('${r.items.length}'),
          child: Column(children: [
            for (final i in r.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Expanded(child: Text(i.nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontSize: 14))),
                  Text('${Fmt.n(i.grammes, decimals: 0)} g', style: AppType.rowSubtitle()),
                  const SizedBox(width: 12),
                  SizedBox(width: 48, child: Text(Fmt.n(i.macros.kcal, decimals: 0), textAlign: TextAlign.right, style: AppType.rowValue().copyWith(fontSize: 14, color: c.text2))),
                ]),
              ),
            if (r.poidsCuitG != null) ...[
              Divider(color: c.line),
              Row(children: [
                Expanded(child: Text('Poids une fois cuit', style: AppType.rowSubtitle(color: c.text2))),
                Text('${Fmt.n(r.poidsCuitG, decimals: 0)} g', style: AppType.rowValue().copyWith(fontSize: 14)),
              ]),
            ],
          ]),
        );
        return NutriSubPage(
          title: 'Recette',
          haloColor: c.weight,
          actions: [
            IconButton(tooltip: 'Modifier', onPressed: () => NutritionNav.editRecipe(context, recipe: r), icon: const Icon(Icons.edit_rounded)),
            IconButton(tooltip: 'Supprimer', onPressed: () => _delete(r), icon: Icon(Icons.delete_outline_rounded, color: c.error)),
          ],
          bottomBar: PillButton(label: 'Ajouter à ${x.nomRepas(_repas).toLowerCase()}', icon: Icons.add_rounded, expand: true, size: PillSize.large, onPressed: () => _add(r)),
          maxContentWidth: 1000,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
            children: [
              TwoPane(
                breakpoint: 680,
                left: Padding(
                  padding: EdgeInsets.only(right: context.screenWidth >= 680 ? 8 : 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [entete, const SizedBox(height: 12), cible]),
                ),
                right: Padding(
                  padding: EdgeInsets.only(top: context.screenWidth < 680 ? 12 : 0, left: context.screenWidth >= 680 ? 8 : 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ingredients,
                    if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      AppCard(label: 'NOTES', child: Text(r.notes!, style: context.textStyles.bodyMedium?.copyWith(color: c.text2))),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Créer ou modifier une recette.
class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({super.key, this.recipe});
  final Recipe? recipe;

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  late final Recipe? r = widget.recipe;
  late final _nom = TextEditingController(text: r?.nom ?? '');
  late final _notes = TextEditingController(text: r?.notes ?? '');
  late final _cuit = TextEditingController(text: numberText(r?.poidsCuitG));
  late List<MealItem> _items = [...?r?.items];
  late double _portions = r?.portions ?? 2;
  bool _dirty = false;
  bool _saving = false;

  bool get _editing => r != null && r!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _dirty = r != null && r!.id.isEmpty && r!.items.isNotEmpty;
  }

  @override
  void dispose() {
    _nom.dispose();
    _notes.dispose();
    _cuit.dispose();
    super.dispose();
  }

  Recipe get _draft => Recipe(
        id: _editing ? r!.id : '',
        nom: _nom.text.trim(),
        items: _items,
        portions: _portions,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        poidsCuitG: parseNumber(_cuit.text),
      );

  Future<void> _add() async {
    final item = await NutritionNav.pickFood(context);
    if (item != null) {
      setState(() {
        _items = [..._items, item];
        _dirty = true;
      });
    }
  }

  Future<void> _editItem(int i) async {
    final it = _items[i];
    final g = await showNumberInputDialog(context, title: it.nom, initial: it.grammes, unit: 'g');
    if (g == null || g <= 0) return;
    setState(() {
      _items = [..._items]..[i] = MealItem(foodId: it.foodId, nom: it.nom, grammes: g, macros: it.grammes <= 0 ? it.macros : it.macros.scale(g / it.grammes));
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final d = _draft;
    if (d.nom.isEmpty) {
      Toasts.error(context, 'Donne un nom à la recette.');
      return;
    }
    if (d.items.isEmpty) {
      Toasts.error(context, 'Ajoute au moins un ingrédient.');
      return;
    }
    setState(() => _saving = true);
    final saved = await NutritionExtras.of(context).saveRecipe(d, context.read<NutritionRepo>());
    if (!mounted) return;
    Toasts.success(context, _editing ? 'Recette mise à jour' : 'Recette créée');
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = _draft;
    final pp = d.parPortion;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await showConfirmDialog(context, title: 'Abandonner la recette ?', confirmLabel: 'Abandonner', destructive: true);
        if (ok && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: NutriSubPage(
        title: _editing ? 'Modifier la recette' : 'Nouvelle recette',
        closeIcon: true,
        haloColor: c.weight,
        bottomBar: PillButton(label: 'Enregistrer', icon: Icons.check_rounded, expand: true, size: PillSize.large, loading: _saving, onPressed: _save),
        maxContentWidth: 1000,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            TwoPane(
              breakpoint: 680,
              left: Padding(
                padding: EdgeInsets.only(right: context.screenWidth >= 680 ? 8 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextField(
                        controller: _nom,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() => _dirty = true),
                        decoration: const InputDecoration(labelText: 'Nom de la recette', hintText: 'Chili con carne, overnight oats…'),
                      ),
                      const SizedBox(height: 16),
                      NumberStepper(
                        label: 'Nombre de portions',
                        value: _portions,
                        min: 1,
                        max: 40,
                        step: 1,
                        onChanged: (v) => setState(() {
                          _portions = v;
                          _dirty = true;
                        }),
                      ),
                      const SizedBox(height: 16),
                      NumberField(
                        controller: _cuit,
                        label: 'Poids une fois cuit (facultatif)',
                        suffix: 'g',
                        hint: Fmt.n(d.poidsIngredients, decimals: 0),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 6),
                      Text('Utile si tu pèses ta part : la cuisson change le poids, pas les calories.', style: AppType.rowSubtitle()),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    label: 'PAR PORTION',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      BigNumber(value: Fmt.n(pp.kcal, decimals: 0), unit: 'kcal', size: 36, caption: '${Fmt.n(d.grammesParPortion, decimals: 0)} g la portion · ${Fmt.kcal(d.total.kcal)} au total'),
                      const SizedBox(height: 14),
                      MacroTriplet(macros: pp, size: 16),
                    ]),
                  ),
                ]),
              ),
              right: Padding(
                padding: EdgeInsets.only(top: context.screenWidth < 680 ? 12 : 0, left: context.screenWidth >= 680 ? 8 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AppCard(
                    label: 'INGRÉDIENTS',
                    labelTrailing: AccentLink(label: 'Ajouter', icon: Icons.add_rounded, onTap: _add),
                    padding: const EdgeInsets.fromLTRB(18, 18, 8, 10),
                    child: _items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(right: 10, bottom: 8),
                            child: EmptyState(compact: true, icon: Icons.egg_rounded, iconColor: c.weight, title: 'Aucun ingrédient', message: 'Ajoute chaque ingrédient avec sa quantité crue.', actionLabel: 'Ajouter un ingrédient', onAction: _add),
                          )
                        : Column(children: [
                            for (var i = 0; i < _items.length; i++)
                              ListTileX(
                                dense: true,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                title: _items[i].nom,
                                subtitle: '${Fmt.n(_items[i].grammes, decimals: 0)} g · ${macrosLine(_items[i].macros)}',
                                value: Fmt.n(_items[i].macros.kcal, decimals: 0),
                                onTap: () => _editItem(i),
                                trailing: IconButton(
                                  tooltip: 'Retirer',
                                  onPressed: () => setState(() {
                                    _items = [..._items]..removeAt(i);
                                    _dirty = true;
                                  }),
                                  icon: Icon(Icons.close_rounded, color: c.text3, size: 20),
                                ),
                              ),
                          ]),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    label: 'NOTES',
                    child: TextField(
                      controller: _notes,
                      maxLines: 5,
                      minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _dirty = true,
                      decoration: const InputDecoration(hintText: 'Étapes, astuces, cuisson…'),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
