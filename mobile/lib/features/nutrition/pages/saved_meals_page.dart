import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../data/nutrition_logic.dart';
import '../nav.dart';
import '../widgets/nutri_page.dart';
import '../widgets/journal_actions.dart';
import '../widgets/nutri_widgets.dart';

/// Ajoute un repas enregistré au journal, en demandant repas et jour.
Future<void> addSavedMeal(BuildContext context, Meal m) async {
  final x = NutritionExtras.of(context);
  final repo = context.read<NutritionRepo>();
  final jour = x.jour.value;
  final repas = await pickMeal(context, selected: m.repas ?? NutritionLogic.repasParDefaut(jour), title: 'Ajouter « ${m.nom} » à');
  if (repas == null) return;
  await repo.addMealToDay(m, date: NutritionLogic.heurePour(jour, repas), repas: repas);
  if (context.mounted) Toasts.success(context, '${m.nom} ajouté à ${x.nomRepas(repas).toLowerCase()} (${Fmt.relatif(jour).toLowerCase()})');
}

/// Liste des repas enregistrés.
class SavedMealsPage extends StatelessWidget {
  const SavedMealsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final x = NutritionExtras.of(context);
    final meals = repo.meals;
    return NutriSubPage(
      title: 'Repas enregistrés',
      haloColor: c.sleep,
      actions: [IconButton(tooltip: 'Nouveau repas', onPressed: () => NutritionNav.editMeal(context), icon: const Icon(Icons.add_rounded))],
      body: meals.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTokens.gutter),
                child: EmptyState(
                  icon: Icons.bookmarks_outlined,
                  iconColor: c.sleep,
                  title: 'Aucun repas enregistré',
                  message: 'Compose un repas que tu manges souvent, ou enregistre un repas du journal depuis son menu.',
                  actionLabel: 'Créer un repas',
                  onAction: () => NutritionNav.editMeal(context),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                TileGroup(
                  label: '${meals.length} REPAS',
                  children: [
                    for (final m in meals)
                      ListTileX(
                        leading: IconHalo(icon: m.repas == null ? Icons.bookmark_rounded : mealIcon(m.repas!), color: c.sleep),
                        title: m.nom,
                        subtitle: [
                          Fmt.pluriel(m.items.length, 'aliment'),
                          if (m.repas != null) x.nomRepas(m.repas!),
                          macrosLine(m.macros),
                        ].join(' · '),
                        value: Fmt.n(m.macros.kcal, decimals: 0),
                        onTap: () => NutritionNav.editMeal(context, meal: m),
                        trailing: RoundIconButton(icon: Icons.add_rounded, size: 36, filled: false, iconColor: c.accent, tooltip: 'Ajouter au journal', onPressed: () => addSavedMeal(context, m)),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Créer ou modifier un repas enregistré.
class MealEditorPage extends StatefulWidget {
  const MealEditorPage({super.key, this.meal});
  final Meal? meal;

  @override
  State<MealEditorPage> createState() => _MealEditorPageState();
}

class _MealEditorPageState extends State<MealEditorPage> {
  late final _nom = TextEditingController(text: widget.meal?.nom ?? '');
  late List<MealItem> _items = [...?widget.meal?.items];
  late MealType? _repas = widget.meal?.repas;
  bool _dirty = false;

  bool get _editing => widget.meal != null && widget.meal!.id.isNotEmpty;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  Macros get _total => _items.fold(Macros.zero, (a, i) => a + i.macros);

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
    final nom = _nom.text.trim();
    if (nom.isEmpty) {
      Toasts.error(context, 'Donne un nom au repas.');
      return;
    }
    if (_items.isEmpty) {
      Toasts.error(context, 'Ajoute au moins un aliment.');
      return;
    }
    final saved = await context.read<NutritionRepo>().saveMeal(Meal(id: _editing ? widget.meal!.id : '', nom: nom, items: _items, repas: _repas, favori: widget.meal?.favori ?? false));
    if (!mounted) return;
    Toasts.success(context, _editing ? 'Repas mis à jour' : 'Repas enregistré');
    Navigator.of(context).pop(saved);
  }

  Future<void> _delete() async {
    final m = widget.meal!;
    final ok = await showConfirmDialog(context, title: 'Supprimer « ${m.nom} » ?', message: 'Le journal n\'est pas modifié.', confirmLabel: 'Supprimer', destructive: true);
    if (!ok || !mounted) return;
    final repo = context.read<NutritionRepo>();
    await repo.deleteMeal(m.id);
    if (!mounted) return;
    Toasts.show(context, 'Repas supprimé', actionLabel: 'Annuler', onAction: () => repo.saveMeal(m));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final x = NutritionExtras.of(context);
    final t = _total;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await showConfirmDialog(context, title: 'Abandonner les modifications ?', confirmLabel: 'Abandonner', destructive: true);
        if (ok && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: NutriSubPage(
        title: _editing ? 'Modifier le repas' : 'Nouveau repas',
        closeIcon: true,
        haloColor: c.sleep,
        actions: [
          if (_editing) IconButton(tooltip: 'Ajouter au journal', onPressed: () => addSavedMeal(context, widget.meal!), icon: const Icon(Icons.playlist_add_rounded)),
          if (_editing) IconButton(tooltip: 'Supprimer', onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, color: c.error)),
        ],
        bottomBar: PillButton(label: 'Enregistrer', icon: Icons.check_rounded, expand: true, size: PillSize.large, onPressed: _save),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
          children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _nom,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _dirty = true,
                  decoration: const InputDecoration(labelText: 'Nom du repas', hintText: 'Petit-déjeuner du matin, bol post-séance…'),
                ),
                const SizedBox(height: 14),
                Text('Repas habituel', style: AppType.rowSubtitle(color: c.text2)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChipFilter(label: 'Aucun', selected: _repas == null, onTap: () => setState(() => _repas = null)),
                  for (final m in MealType.values)
                    ChipFilter(
                      label: x.nomRepas(m),
                      selected: _repas == m,
                      onTap: () => setState(() {
                        _repas = m;
                        _dirty = true;
                      }),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              label: 'TOTAL',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                BigNumber(value: Fmt.n(t.kcal, decimals: 0), unit: 'kcal', size: 36),
                const SizedBox(height: 14),
                MacroTriplet(macros: t, size: 16),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              label: 'ALIMENTS',
              labelTrailing: AccentLink(label: 'Ajouter', icon: Icons.add_rounded, onTap: _add),
              padding: const EdgeInsets.fromLTRB(18, 18, 8, 10),
              child: _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(right: 10, bottom: 8),
                      child: EmptyState(compact: true, icon: Icons.restaurant_rounded, iconColor: c.nutrition, title: 'Aucun aliment', message: 'Ajoute les aliments de ce repas.', actionLabel: 'Ajouter un aliment', onAction: _add),
                    )
                  : ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorderItem: (a, b) => setState(() {
                        final l = [..._items];
                        final it = l.removeAt(a);
                        l.insert(b, it);
                        _items = l;
                        _dirty = true;
                      }),
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          ListTileX(
                            key: ValueKey('item-$i-${_items[i].foodId}-${_items[i].nom}'),
                            dense: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            leading: ReorderableDragStartListener(index: i, child: Icon(Icons.drag_indicator_rounded, color: c.text3)),
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
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
