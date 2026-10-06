import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/logic/format.dart';
import '../../../core/logic/nutrition_calc.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../data/nutrition_logic.dart';
import '../widgets/nutri_page.dart';
import '../widgets/journal_actions.dart';
import '../widgets/nutri_widgets.dart';

/// Ajout rapide : des calories (et des macros si on les connaît) sans aliment.
class QuickAddPage extends StatefulWidget {
  const QuickAddPage({super.key, this.jour, this.repas, this.entry});
  final DateTime? jour;
  final MealType? repas;
  final FoodEntry? entry;

  @override
  State<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends State<QuickAddPage> {
  late final NutritionExtras x = NutritionExtras.of(context);
  late final FoodEntry? e = widget.entry;
  late final _nom = TextEditingController(text: e == null || e!.nom == 'Ajout rapide' ? '' : e!.nom);
  late final _kcal = TextEditingController(text: numberText(e?.macros.kcal));
  late final _p = TextEditingController(text: numberText(e?.macros.proteines));
  late final _g = TextEditingController(text: numberText(e?.macros.glucides));
  late final _l = TextEditingController(text: numberText(e?.macros.lipides));
  late DateTime _jour = widget.jour ?? e?.date ?? x.jour.value;
  late MealType _repas = widget.repas ?? e?.repas ?? NutritionLogic.repasParDefaut(_jour);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_nom, _kcal, _p, _g, _l]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _macroKcal => NutritionCalc.kcalDesMacros(proteines: parseNumber(_p.text) ?? 0, glucides: parseNumber(_g.text) ?? 0, lipides: parseNumber(_l.text) ?? 0);
  double get _kcalFinal => parseNumber(_kcal.text) ?? _macroKcal;

  Future<void> _save() async {
    final kcal = _kcalFinal;
    if (kcal <= 0) {
      Toasts.error(context, 'Indique des calories ou des macros.');
      return;
    }
    setState(() => _saving = true);
    final repo = context.read<NutritionRepo>();
    final macros = Macros(kcal: kcal, proteines: parseNumber(_p.text) ?? 0, glucides: parseNumber(_g.text) ?? 0, lipides: parseNumber(_l.text) ?? 0);
    final nom = _nom.text.trim().isEmpty ? 'Ajout rapide' : _nom.text.trim();
    final date = e != null && Dates.memeJour(e!.date, _jour) ? e!.date : NutritionLogic.heurePour(_jour, _repas);
    await repo.saveEntry(FoodEntry(id: e?.id ?? newId(), date: date, repas: _repas, nom: nom, quantiteG: 0, macros: macros));
    if (!mounted) return;
    Toasts.success(context, e == null ? '${Fmt.kcal(kcal)} ajoutées à ${x.nomRepas(_repas).toLowerCase()}' : 'Ajout rapide mis à jour');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await deleteEntryWithUndo(context, e!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mk = _macroKcal;
    return NutriSubPage(
      title: e == null ? 'Ajout rapide' : 'Modifier l\'ajout rapide',
      subtitle: 'Des calories sans chercher d\'aliment',
      closeIcon: true,
      haloColor: c.nutrition,
      actions: [if (e != null) IconButton(tooltip: 'Supprimer', onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, color: c.error))],
      bottomBar: PillButton(label: e == null ? 'Ajouter' : 'Enregistrer', icon: Icons.check_rounded, expand: true, size: PillSize.large, loading: _saving, onPressed: _save),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Calories', style: AppType.rowSubtitle(color: c.text2)),
              TextField(
                controller: _kcal,
                autofocus: e == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppType.number(40),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: mk > 0 ? Fmt.n(mk, decimals: 0) : '0',
                  suffixText: 'kcal',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              if (mk > 0 && (parseNumber(_kcal.text) ?? 0) <= 0)
                Text('Calculées depuis les macros : ${Fmt.kcal(mk)}', style: AppType.rowSubtitle(color: c.text2)),
              const SizedBox(height: 10),
              TextField(controller: _nom, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nom (facultatif)', hintText: 'Restaurant, goûter…')),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            label: 'MACROS (FACULTATIF)',
            child: Row(children: [
              Expanded(child: NumberField(controller: _p, label: 'Protéines', suffix: 'g', onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: NumberField(controller: _g, label: 'Glucides', suffix: 'g', onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: NumberField(controller: _l, label: 'Lipides', suffix: 'g', onChanged: (_) => setState(() {}))),
            ]),
          ),
          const SizedBox(height: 12),
          TileGroup(margin: EdgeInsets.zero, children: [
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
          ]),
        ],
      ),
    );
  }
}
