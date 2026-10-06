import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../nav.dart';
import '../widgets/journal_actions.dart';
import '../widgets/nutri_widgets.dart';
import 'journal_page.dart';

/// Détail d'un repas (ou de la journée entière si [repas] est null) :
/// répartition des macros, part de l'objectif, aliments.
class MealDetailPage extends StatelessWidget {
  const MealDetailPage({super.key, required this.jour, this.repas});
  final DateTime jour;
  final MealType? repas;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final x = NutritionExtras.of(context);
    final entries = repo.entriesFor(jour, repas);
    final total = entries.fold(Macros.zero, (a, e) => a + e.macros);
    final dg = goalsOf(context, jour);
    final g = dg.goals;
    final (pp, gp, lp) = macroPercents(total);
    final titre = repas == null ? 'Journée' : x.nomRepas(repas!);
    final jourLabel = Dates.memeJour(jour, DateTime.now()) ? 'Aujourd\'hui' : Fmt.jourCap(jour);

    final resume = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: BigNumber(
              label: repas == null ? 'Total du jour' : 'Total du repas',
              value: Fmt.n(total.kcal, decimals: 0),
              unit: 'kcal',
              size: 40,
              caption: g.kcal <= 0 ? null : '${(total.kcal / g.kcal * 100).round()} % de l\'objectif (${Fmt.kcal(g.kcal)})',
            ),
          ),
          MacroSplitRing(
            macros: total,
            size: 96,
            center: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(Fmt.pluriel(entries.length, 'aliment'), style: AppType.rowSubtitle().copyWith(fontSize: 11)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        MacroTriplet(macros: total),
        if (total.kcal > 0) ...[
          const SizedBox(height: 14),
          SegmentedBar(parts: [(pp.toDouble(), c.proteines), (gp.toDouble(), c.glucides), (lp.toDouble(), c.lipides)]),
          const SizedBox(height: 8),
          Text('Calories : protéines $pp %, glucides $gp %, lipides $lp %', style: AppType.rowSubtitle()),
        ],
      ]),
    );

    final autres = AppCard(
      label: 'DÉTAIL',
      child: Column(children: [
        _Row('Fibres', '${Fmt.n(total.fibres)} g', g.fibresG > 0 ? '${(total.fibres / g.fibresG * 100).round()} %' : null),
        _Row('Sucres', '${Fmt.n(total.sucres)} g', null),
        _Row('Sel', '${Fmt.n(total.sel, decimals: 2)} g', null),
        _Row('Protéines', '${Fmt.n(total.proteines)} g', g.proteinesG > 0 ? '${(total.proteines / g.proteinesG * 100).round()} %' : null),
        _Row('Glucides', '${Fmt.n(total.glucides)} g', g.glucidesG > 0 ? '${(total.glucides / g.glucidesG * 100).round()} %' : null),
        _Row('Lipides', '${Fmt.n(total.lipides)} g', g.lipidesG > 0 ? '${(total.lipides / g.lipidesG * 100).round()} %' : null),
      ]),
    );

    Widget repartition() {
      final parts = [
        for (final t in MealType.values) (t, repo.totalsFor(jour, t).kcal),
      ];
      final couleurs = [c.weight, c.nutrition, c.coach, c.sleep];
      return AppCard(
        label: 'RÉPARTITION PAR REPAS',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedBar(parts: [for (var i = 0; i < parts.length; i++) (parts[i].$2, couleurs[i])]),
          const SizedBox(height: 12),
          for (var i = 0; i < parts.length; i++)
            ListTileX(
              dense: true,
              padding: const EdgeInsets.symmetric(vertical: 2),
              leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: couleurs[i], shape: BoxShape.circle)),
              title: x.nomRepas(parts[i].$1),
              value: total.kcal <= 0 ? '0 %' : '${(parts[i].$2 / total.kcal * 100).round()} %',
              subtitle: Fmt.kcal(parts[i].$2),
              onTap: () => NutritionNav.mealDetail(context, parts[i].$1, jour),
              showChevron: true,
            ),
        ]),
      );
    }

    final plusCaloriques = [...entries]..sort((a, b) => b.macros.kcal.compareTo(a.macros.kcal));
    final liste = AppCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      label: 'ALIMENTS',
      labelTrailing: LabelCount('${entries.length}'),
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: EmptyState(
                compact: true,
                icon: Icons.restaurant_rounded,
                iconColor: c.nutrition,
                title: 'Rien de noté',
                message: 'Ajoute un aliment pour voir le détail.',
                actionLabel: 'Ajouter',
                onAction: () => NutritionNav.addFood(context, jour: jour, repas: repas),
              ),
            )
          : Column(children: [for (final e in (repas == null ? plusCaloriques : entries)) EntryTile(entry: e, showTime: true)]),
    );

    return SubPageScaffold(
      title: titre,
      subtitle: jourLabel,
      haloColor: c.nutrition,
      actions: [
        IconButton(tooltip: 'Ajouter', onPressed: () => NutritionNav.addFood(context, jour: jour, repas: repas), icon: const Icon(Icons.add_rounded)),
        if (repas != null) IconButton(tooltip: 'Options du repas', onPressed: () => showMealMenu(context, repas!, jour, showDetail: false), icon: const Icon(Icons.more_vert_rounded)),
      ],
      maxContentWidth: 1000,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
        children: [
          TwoPane(
            breakpoint: 680,
            left: Padding(
              padding: EdgeInsets.only(right: context.screenWidth >= 680 ? 8 : 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                resume,
                const SizedBox(height: 12),
                if (repas == null) ...[repartition(), const SizedBox(height: 12)],
                autres,
              ]),
            ),
            right: Padding(
              padding: EdgeInsets.only(top: context.screenWidth < 680 ? 12 : 0, left: context.screenWidth >= 680 ? 8 : 0),
              child: liste,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.part);
  final String label;
  final String value;
  final String? part;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: AppType.rowSubtitle(color: context.colors.text2).copyWith(fontSize: 14))),
          Text(value, style: AppType.rowValue().copyWith(fontSize: 14)),
          if (part != null) SizedBox(width: 56, child: Text(part!, textAlign: TextAlign.right, style: AppType.rowSubtitle())),
        ]),
      );
}
