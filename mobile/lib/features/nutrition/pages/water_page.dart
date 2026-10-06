import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/logic/format.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../widgets/journal_actions.dart';
import '../widgets/nutri_widgets.dart';

/// L'eau d'un jour : verres, historique, objectif, sept derniers jours.
class WaterPage extends StatelessWidget {
  const WaterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final x = NutritionExtras.of(context);
    return ListenableBuilder(listenable: Listenable.merge([x, x.jour]), builder: (context, _) => _WaterBody(jour: x.jour.value, x: x));
  }
}

class _WaterBody extends StatelessWidget {
  const _WaterBody({required this.jour, required this.x});
  final DateTime jour;
  final NutritionExtras x;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final dg = goalsOf(context, jour);
    final goal = dg.goals.eauMl;
    final ml = repo.waterFor(jour);
    final logs = repo.waterLogsFor(jour)..sort((a, b) => b.date.compareTo(a.date));
    final now = DateTime.now();
    final today = Dates.memeJour(jour, now);

    Future<void> add(int v) => repo.addWater(v, date: today ? DateTime.now() : DateTime(jour.year, jour.month, jour.day, 12));

    final semaine = [for (var i = 6; i >= 0; i--) Dates.jour(jour).subtract(Duration(days: i))];
    final maxMl = semaine.map(repo.waterFor).fold<int>(goal, (a, b) => a > b ? a : b);

    final hero = AppCard(
      child: Column(children: [
        Row(children: [
          Expanded(
            child: BigNumber(
              label: today ? 'Bu aujourd\'hui' : 'Bu ce jour-là',
              value: Fmt.n(ml / 1000, decimals: 2),
              unit: 'L',
              color: c.text,
              caption: ml >= goal ? 'Objectif atteint' : 'Encore ${Fmt.n((goal - ml) / 1000, decimals: 2)} L pour ${Fmt.n(goal / 1000, decimals: 1)} L',
              captionColor: ml >= goal ? c.eau : null,
            ),
          ),
          ProgressRing(
            value: goal <= 0 ? 0 : ml / goal,
            size: 96,
            stroke: 9,
            color: c.eau,
            center: Icon(Icons.water_drop_rounded, color: c.eau, size: 30),
          ),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: PillButton(label: '+${x.verreMl} ml', icon: Icons.add_rounded, expand: true, color: c.eau, onPressed: () => add(x.verreMl))),
          const SizedBox(width: 8),
          Expanded(child: PillButton.secondary(label: '+500 ml', expand: true, color: c.eau, onPressed: () => add(500))),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.edit_rounded,
            filled: false,
            tooltip: 'Autre quantité',
            onPressed: () async {
              final v = await showNumberInputDialog(context, title: 'Quantité d\'eau', unit: 'ml', decimal: false, confirmLabel: 'Ajouter');
              if (v != null && v > 0) await add(v.round());
            },
          ),
        ]),
      ]),
    );

    final semaineCard = AppCard(
      label: 'SEPT DERNIERS JOURS',
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final d in semaine)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(repo.waterFor(d) == 0 ? '' : Fmt.n(repo.waterFor(d) / 1000, decimals: 1), style: AppType.rowSubtitle().copyWith(fontSize: 10.5)),
                    const SizedBox(height: 4),
                    Container(
                      height: 100 * (repo.waterFor(d) / (maxMl <= 0 ? 1 : maxMl)).clamp(0.02, 1.0),
                      decoration: BoxDecoration(
                        color: repo.waterFor(d) >= goal ? c.eau : c.eau.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                        border: Dates.memeJour(d, jour) ? Border.all(color: c.text, width: 1.2) : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(Dates.initiale(d), style: AppType.overline(color: Dates.memeJour(d, jour) ? c.text : c.text3).copyWith(letterSpacing: 0.4)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );

    final historique = AppCard(
      label: 'VERRES',
      labelTrailing: logs.isEmpty ? null : AccentLink(label: 'Retirer le dernier', icon: Icons.undo_rounded, onTap: () => repo.undoWater(jour)),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: logs.isEmpty
          ? Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Aucun verre noté ce jour-là.', style: AppType.rowSubtitle()))
          : Column(children: [
              for (final l in logs)
                ListTileX(
                  dense: true,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  leading: IconHalo(icon: Icons.local_drink_rounded, color: c.eau, size: 34, glow: false),
                  title: '${Fmt.n(l.ml, decimals: 0)} ml',
                  value: Fmt.heure(l.date),
                ),
            ]),
    );

    final reglages = TileGroup(margin: EdgeInsets.zero, label: 'RÉGLAGES', children: [
      ListTileX(
        leading: IconHalo(icon: Icons.flag_rounded, color: c.eau, size: 38),
        title: 'Objectif quotidien',
        value: '${Fmt.n(goal / 1000, decimals: 2)} L',
        showChevron: true,
        onTap: () async {
          final v = await showNumberInputDialog(context, title: 'Objectif d\'eau', initial: goal.toDouble(), unit: 'ml', decimal: false);
          if (v == null || v < 250 || !context.mounted) return;
          if (await saveGoals(context, dg.base.copyWith(eauMl: v.round())) && context.mounted) Toasts.success(context, 'Objectif d\'eau enregistré');
        },
      ),
      ListTileX(
        leading: IconHalo(icon: Icons.local_drink_rounded, color: c.eau, size: 38),
        title: 'Taille du verre',
        value: '${x.verreMl} ml',
        showChevron: true,
        onTap: () async {
          final v = await showChoiceDialog<int>(
            context,
            title: 'Taille du verre',
            selected: x.verreMl,
            options: const [(150, '150 ml'), (200, '200 ml'), (250, '250 ml'), (330, '330 ml (canette)'), (500, '500 ml (bouteille)'), (750, '750 ml (gourde)')],
          );
          if (v != null) await x.setVerreMl(v);
        },
      ),
    ]);

    return SubPageScaffold(
      title: 'Eau',
      subtitle: today ? 'Aujourd\'hui' : Fmt.jourCap(jour),
      haloColor: c.eau,
      maxContentWidth: 1000,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
        children: [
          TwoPane(
            breakpoint: 680,
            left: Padding(
              padding: EdgeInsets.only(right: context.screenWidth >= 680 ? 8 : 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [hero, const SizedBox(height: 12), semaineCard]),
            ),
            right: Padding(
              padding: EdgeInsets.only(top: context.screenWidth < 680 ? 12 : 0, left: context.screenWidth >= 680 ? 8 : 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [historique, const SizedBox(height: 12), reglages]),
            ),
          ),
        ],
      ),
    );
  }
}
