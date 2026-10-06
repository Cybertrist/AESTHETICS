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

/// Une unité de saisie : grammes (ou ml), ou une portion nommée.
class _Unit {
  const _Unit(this.label, this.grammes, {this.portion});
  final String label;
  final double grammes;
  final Portion? portion;
}

/// Fiche d'un aliment : quantité, unité, portion, valeurs, Nutri-Score.
class FoodPage extends StatefulWidget {
  const FoodPage({super.key, required this.args});
  final FoodPageArgs args;

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  late final NutritionExtras x = NutritionExtras.of(context);
  late Food food = widget.args.food;
  late final List<_Unit> _units;
  late _Unit _unit;
  late final TextEditingController _qty;
  late DateTime _jour = widget.args.jour ?? x.jour.value;
  late MealType _repas = widget.args.repas ?? NutritionLogic.repasParDefaut(_jour);
  bool _per100 = false;
  bool _saving = false;

  FoodPageMode get mode => widget.args.mode;
  String get _u => food.liquide ? 'ml' : 'g';

  @override
  void initState() {
    super.initState();
    _units = [
      _Unit(_u, 1),
      for (final p in food.portions) _Unit(p.label, p.grammes, portion: p),
    ];
    final g = widget.args.grammes;
    final pl = widget.args.portionLabel;
    // On retrouve la portion d'une entrée existante (« 2 œuf »).
    _Unit? found;
    double? count;
    if (pl != null && g != null) {
      for (final u in _units.skip(1)) {
        if (pl.endsWith(u.label) && u.grammes > 0) {
          found = u;
          count = g / u.grammes;
        }
      }
    }
    if (found != null) {
      _unit = found;
      _qty = TextEditingController(text: numberText(count, decimals: 2));
    } else if (g != null) {
      _unit = _units.first;
      _qty = TextEditingController(text: numberText(g));
    } else if (_units.length > 1) {
      _unit = _units[1];
      _qty = TextEditingController(text: '1');
    } else {
      _unit = _units.first;
      _qty = TextEditingController(text: '100');
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  double get _count => parseNumber(_qty.text) ?? 0;
  double get _grammes => _count * _unit.grammes;
  Macros get _macros => food.pour(_grammes);

  String? get _portionLabel => _unit.portion == null ? null : '${numberText(_count, decimals: 2)} ${_unit.label}';

  void _step(double delta) {
    final step = _unit.portion == null ? (_grammes >= 100 ? 10.0 : 5.0) : 0.5;
    final v = (_count + delta * step).clamp(0, 99999).toDouble();
    setState(() => _qty.text = numberText(v, decimals: 2));
  }

  void _setUnit(_Unit u) {
    if (u == _unit) return;
    final g = _grammes;
    setState(() {
      _unit = u;
      final c = u.grammes <= 0 ? 0.0 : g / u.grammes;
      _qty.text = u.portion == null ? numberText(c.roundToDouble()) : numberText((c * 2).roundToDouble() / 2, decimals: 2);
      if (parseNumber(_qty.text) == 0) _qty.text = u.portion == null ? '100' : '1';
    });
  }

  Future<void> _submit() async {
    if (_grammes <= 0) {
      Toasts.error(context, 'Indique une quantité.');
      return;
    }
    final repo = context.read<NutritionRepo>();
    setState(() => _saving = true);
    final ns = widget.args.nutriscore;
    if (ns != null) await x.setNutriscore(food.id, ns);
    switch (mode) {
      case FoodPageMode.ajouter:
        await repo.addFood(food, _grammes, date: NutritionLogic.heurePour(_jour, _repas), repas: _repas, portionLabel: _portionLabel);
        if (!mounted) return;
        Toasts.success(context, '${food.nom} ajouté à ${x.nomRepas(_repas).toLowerCase()}');
        Navigator.of(context).pop(true);
      case FoodPageMode.modifier:
        final e = widget.args.entry!;
        final d = Dates.memeJour(_jour, e.date) ? e.date : DateTime(_jour.year, _jour.month, _jour.day, e.date.hour, e.date.minute);
        await repo.saveEntry(FoodEntry(
          id: e.id,
          date: d,
          repas: _repas,
          nom: e.nom,
          quantiteG: _grammes,
          macros: _macros,
          foodId: e.foodId,
          portionLabel: _portionLabel,
        ));
        if (!mounted) return;
        Toasts.success(context, 'Quantité mise à jour');
        Navigator.of(context).pop(true);
      case FoodPageMode.choisir:
        if (repo.foodById(food.id) == null) await repo.saveFood(food);
        if (!mounted) return;
        Navigator.of(context).pop(MealItem(foodId: food.id, nom: food.marque == null ? food.nom : '${food.nom} (${food.marque})', grammes: _grammes, macros: _macros));
    }
  }

  Future<void> _delete() async {
    final e = widget.args.entry!;
    await deleteEntryWithUndo(context, e);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _toggleFav() async {
    final repo = context.read<NutritionRepo>();
    if (repo.foodById(food.id) == null) await repo.saveFood(food);
    await repo.toggleFavoriteFood(food.id);
    final f = repo.foodById(food.id);
    if (f != null && mounted) {
      setState(() => food = f);
      Toasts.show(context, f.favori ? 'Ajouté aux favoris' : 'Retiré des favoris', icon: f.favori ? Icons.star_rounded : Icons.star_outline_rounded);
    }
  }

  Future<void> _edit() async {
    if (food.source == 'recette') {
      final r = x.recetteById(Recipe.recipeIdOf(food.id));
      if (r != null) await NutritionNav.editRecipe(context, recipe: r);
    } else {
      await NutritionNav.editFood(context, food: food);
    }
    if (!mounted) return;
    final f = context.read<NutritionRepo>().foodById(food.id);
    if (f != null) setState(() => food = f);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final saved = repo.foodById(food.id);
    final fav = saved?.favori ?? food.favori;
    final editable = saved != null && (food.source == 'perso' || food.source == 'recette');
    final dg = goalsOf(context, _jour);
    final m = _per100 ? food.pour100g : _macros;
    final ns = widget.args.nutriscore ?? x.nutriscoreOf(food.id);

    final head = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoodThumb(food: food, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.nom, style: AppType.rowTitle().copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                    if (food.marque != null) ...[const SizedBox(height: 2), Text(food.marque!, style: AppType.rowSubtitle(color: c.text2))],
                    const SizedBox(height: 6),
                    Text(
                      [
                        switch (food.source) {
                          'openfoodfacts' => 'Base en ligne',
                          'recette' => 'Recette',
                          'perso' => 'Aliment perso',
                          'catalogue' => 'Base intégrée',
                          _ => 'Journal',
                        },
                        if (food.codeBarres != null) food.codeBarres!,
                      ].join(' · '),
                      style: AppType.rowSubtitle(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ns != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              Text('Nutri-Score', style: AppType.rowSubtitle(color: c.text2)),
              const Spacer(),
              NutriScoreBadge(grade: ns, large: true),
            ]),
          ],
        ],
      ),
    );

    final quantity = AppCard(
      label: 'QUANTITÉ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RoundIconButton(icon: Icons.remove_rounded, onPressed: () => _step(-1), filled: false, tooltip: 'Moins'),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey('quantite'),
                  controller: _qty,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppType.number(34),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    suffixText: _unit.portion == null ? _u : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RoundIconButton(icon: Icons.add_rounded, onPressed: () => _step(1), filled: false, tooltip: 'Plus'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final u in _units)
                ChipFilter(
                  label: u.portion == null ? u.label : '${u.label} · ${Fmt.n(u.grammes, decimals: 0)} $_u',
                  selected: u == _unit,
                  onTap: () => _setUnit(u),
                ),
            ],
          ),
          if (_unit.portion != null) ...[
            const SizedBox(height: 10),
            Text('Soit ${Fmt.n(_grammes, decimals: 0)} $_u', style: AppType.rowSubtitle(color: c.text2)),
          ],
        ],
      ),
    );

    final target = mode == FoodPageMode.choisir
        ? const SizedBox.shrink()
        : TileGroup(
            margin: EdgeInsets.zero,
            children: [
              ListTileX(
                leading: IconHalo(icon: mealIcon(_repas), color: c.nutrition, size: 38),
                title: 'Repas',
                value: x.nomRepas(_repas),
                showChevron: true,
                onTap: () async {
                  final r = await pickMeal(context, selected: _repas);
                  if (r != null) setState(() => _repas = r);
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
            ],
          );

    final (pp, gp, lp) = macroPercents(m);
    final values = AppCard(
      label: 'VALEURS',
      labelTrailing: SizedBox(
        width: 190,
        child: SegmentedControl<bool>(
          height: 36,
          accentThumb: false,
          segments: [(false, 'Quantité'), (true, 'Pour 100 $_u')],
          value: _per100,
          onChanged: (v) => setState(() => _per100 = v),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: BigNumber(
                  value: Fmt.n(m.kcal, decimals: 0),
                  unit: 'kcal',
                  size: 40,
                  caption: _per100 || dg.goals.kcal <= 0 ? null : '${(m.kcal / dg.goals.kcal * 100).round()} % de ton objectif du jour',
                ),
              ),
              MacroSplitRing(
                macros: m,
                size: 88,
                center: Text(m.kcal <= 0 ? '-' : '$pp %', style: AppType.number(15, color: c.proteines)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          MacroTriplet(macros: m),
          const SizedBox(height: 10),
          if (m.kcal > 0)
            Text('Protéines $pp % · glucides $gp % · lipides $lp % des calories', style: AppType.rowSubtitle()),
          const SizedBox(height: 8),
          Divider(color: c.line),
          _ValueRow(label: 'dont sucres', value: m.sucres, unit: 'g'),
          _ValueRow(label: 'Fibres', value: m.fibres, unit: 'g'),
          _ValueRow(label: 'Sel', value: m.sel, unit: 'g', decimals: 2),
        ],
      ),
    );

    final submitLabel = switch (mode) {
      FoodPageMode.ajouter => 'Ajouter à ${x.nomRepas(_repas).toLowerCase()}',
      FoodPageMode.modifier => 'Enregistrer',
      FoodPageMode.choisir => 'Choisir ${Fmt.n(_grammes, decimals: 0)} $_u',
    };

    return NutriSubPage(
      title: mode == FoodPageMode.modifier ? 'Modifier' : 'Aliment',
      closeIcon: true,
      haloColor: c.nutrition,
      actions: [
        IconButton(
          tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
          onPressed: _toggleFav,
          icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded, color: fav ? c.accent : null),
        ),
        if (editable) IconButton(tooltip: 'Modifier l\'aliment', onPressed: _edit, icon: const Icon(Icons.edit_rounded)),
        if (mode == FoodPageMode.modifier) IconButton(tooltip: 'Supprimer du journal', onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, color: c.error)),
      ],
      bottomBar: PillButton(
        label: submitLabel,
        icon: mode == FoodPageMode.modifier ? Icons.check_rounded : Icons.add_rounded,
        expand: true,
        size: PillSize.large,
        loading: _saving,
        onPressed: _grammes > 0 ? _submit : null,
      ),
      maxContentWidth: 1000,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TwoPane(
            breakpoint: 680,
            left: Padding(
              padding: EdgeInsets.only(right: context.isWide ? 8 : 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, const SizedBox(height: 12), quantity, const SizedBox(height: 12), target]),
            ),
            right: Padding(
              padding: EdgeInsets.only(top: context.screenWidth < 680 ? 12 : 0, left: context.screenWidth >= 680 ? 8 : 0),
              child: values,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value, required this.unit, this.decimals = 1});
  final String label;
  final double value;
  final String unit;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: AppType.rowSubtitle(color: context.colors.text2).copyWith(fontSize: 14))),
        Text('${Fmt.n(value, decimals: decimals)} $unit', style: AppType.rowValue().copyWith(fontSize: 14)),
      ]),
    );
  }
}
