import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../widgets/commun.dart';

/// Nutrition d'un jour : calories, macros, repas, eau.
class NutritionJourPage extends StatefulWidget {
  const NutritionJourPage({super.key});

  @override
  State<NutritionJourPage> createState() => _NutritionJourPageState();
}

class _NutritionJourPageState extends State<NutritionJourPage> {
  DateTime _jour = Dates.jour(DateTime.now());

  bool get _aujourdhui => Dates.memeJour(_jour, DateTime.now());

  DateTime get _heureAjout {
    final now = DateTime.now();
    return _aujourdhui ? now : DateTime(_jour.year, _jour.month, _jour.day, 12);
  }

  Future<void> _eau(int ml) async {
    final n = context.read<NutritionRepo>();
    await n.addWater(ml, date: _heureAjout);
    if (!mounted) return;
    Toasts.success(context, '+${Fmt.n(ml, decimals: 0)} ml d\'eau', actionLabel: 'Annuler', onAction: () => n.undoWater(_jour));
  }

  Future<void> _eauLibre() async {
    final v = await showNumberInputDialog(context, title: 'Ajouter de l\'eau', unit: 'ml', decimal: false, confirmLabel: 'Ajouter');
    if (v == null || !mounted) return;
    if (v <= 0 || v > 3000) {
      Toasts.error(context, 'Entre une quantité entre 1 et 3 000 ml.');
      return;
    }
    await _eau(v.round());
  }

  Future<void> _supprimer(FoodEntry e) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Retirer ${e.nom} ?',
      message: '${Fmt.n(e.quantiteG, decimals: 0)} g, ${Fmt.kcal(e.macros.kcal)}',
      confirmLabel: 'Retirer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final n = context.read<NutritionRepo>();
    await n.deleteEntry(e.id);
    if (mounted) Toasts.show(context, '${e.nom} retiré.', actionLabel: 'Annuler', onAction: () => n.saveEntry(e));
  }

  Future<void> _modifierQuantite(FoodEntry e) async {
    final v = await showNumberInputDialog(context, title: 'Quantité de ${e.nom}', initial: e.quantiteG, unit: 'g', decimal: false);
    if (v == null || v <= 0 || !mounted) return;
    final f = v / (e.quantiteG <= 0 ? 1 : e.quantiteG);
    await context.read<NutritionRepo>().saveEntry(e.copyWith(quantiteG: v, macros: e.macros.scale(f), portionLabel: ''));
  }

  Future<void> _copierVeille() async {
    final veille = _jour.subtract(const Duration(days: 1));
    await context.read<NutritionRepo>().copyDay(veille, _jour);
    if (mounted) Toasts.success(context, 'Repas de la veille copiés.');
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NutritionRepo>();
    final goals = NutritionCalc.effectifs(context.watch<ProfileRepo>().profile);
    final c = context.colors;
    final tot = n.totalsFor(_jour);
    final entries = n.entriesFor(_jour);
    final reste = goals.kcal - tot.kcal;
    final eau = n.waterFor(_jour);
    final veilleVide = n.entriesFor(_jour.subtract(const Duration(days: 1))).isEmpty;
    final large = context.isWide;
    final cp = CouleursMacros.proteines(context), cg = CouleursMacros.glucides(context), cl = CouleursMacros.lipides(context);

    final centre = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(reste >= 0 ? 'RESTANTES' : 'EN TROP', style: AppType.overline()),
        const SizedBox(height: 4),
        Text(Fmt.n(reste.abs(), decimals: 0), style: AppType.number(40, color: reste >= 0 ? null : c.warning)),
        Text('sur ${Fmt.kcal(goals.kcal)}', style: AppType.rowSubtitle()),
      ],
    );

    final anneau = AppCard(
      child: Column(
        children: [
          Center(
            child: tot.kcal <= 0
                ? ProgressRing(value: 0, size: 230, stroke: 14, rings: true, center: centre)
                : SegmentRing(
                    size: 280,
                    parts: [
                      RingPart(tot.proteines * 4, cp, Icons.egg_alt_rounded),
                      RingPart(tot.glucides * 4, cg, Icons.bakery_dining_rounded),
                      RingPart(tot.lipides * 9, cl, Icons.water_drop_outlined),
                    ],
                    center: centre,
                  ),
          ),
          const SizedBox(height: 12),
          ProgressBar(
            value: goals.kcal <= 0 ? 0 : tot.kcal / goals.kcal,
            color: c.nutrition,
            label: '${Fmt.kcal(tot.kcal)} consommées',
            trailing: '${goals.kcal <= 0 ? 0 : (tot.kcal / goals.kcal * 100).round()} %',
          ),
        ],
      ),
    );

    Widget ligneMacro(String nom, double v, double obj, Color col, double kcalParG) {
      final part = tot.kcal <= 0 ? 0 : (v * kcalParG / tot.kcal * 100).round();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: ProgressBar(
          value: obj <= 0 ? 0 : v / obj,
          color: col,
          label: '$nom · $part % des calories',
          trailing: '${Fmt.n(v, decimals: 0)} / ${Fmt.n(obj, decimals: 0)} g',
        ),
      );
    }

    final macros = AppCard(
      label: 'Macros',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ligneMacro('Protéines', tot.proteines, goals.proteinesG, cp, 4),
          ligneMacro('Glucides', tot.glucides, goals.glucidesG, cg, 4),
          ligneMacro('Lipides', tot.lipides, goals.lipidesG, cl, 9),
          Row(
            children: [
              Expanded(child: _Petit(label: 'Fibres', valeur: '${Fmt.n(tot.fibres, decimals: 0)} / ${Fmt.n(goals.fibresG, decimals: 0)} g')),
              Expanded(child: _Petit(label: 'Sucres', valeur: Fmt.grammes(tot.sucres))),
              Expanded(child: _Petit(label: 'Sel', valeur: '${Fmt.n(tot.sel)} g')),
            ],
          ),
        ],
      ),
    );

    final repas = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.isEmpty)
          AppCard(
            child: Column(
              children: [
                EmptyState(
                  compact: true,
                  icon: Icons.restaurant_rounded,
                  iconColor: c.nutrition,
                  title: _aujourdhui ? 'Rien noté aujourd\'hui' : 'Rien noté ce jour-là',
                  message: 'Note tes repas pour suivre tes calories et tes protéines.',
                  actionLabel: 'Noter un repas',
                  onAction: () => context.go(Paths.nutrition),
                  secondaryLabel: veilleVide ? null : 'Copier la veille',
                  onSecondary: veilleVide ? null : _copierVeille,
                ),
              ],
            ),
          )
        else
          for (final m in MealType.values) ...[
            TileGroup(
              margin: EdgeInsets.zero,
              label: m.label,
              labelTrailing: LabelCount(Fmt.kcal(n.totalsFor(_jour, m).kcal)),
              children: [
                for (final e in n.entriesFor(_jour, m))
                  ListTileX(
                    dense: true,
                    leading: IconHalo.domain(AppDomain.nutrition, icon: Icons.restaurant_rounded, size: 34, glow: false),
                    title: e.nom,
                    subtitle: [
                      if (e.portionLabel != null && e.portionLabel!.isNotEmpty) e.portionLabel!,
                      '${Fmt.n(e.quantiteG, decimals: 0)} g',
                      'P ${Fmt.n(e.macros.proteines, decimals: 0)} · G ${Fmt.n(e.macros.glucides, decimals: 0)} · L ${Fmt.n(e.macros.lipides, decimals: 0)}',
                    ].join(' · '),
                    value: Fmt.n(e.macros.kcal, decimals: 0),
                    onTap: () => _modifierQuantite(e),
                    onLongPress: () => _supprimer(e),
                  ),
                if (n.entriesFor(_jour, m).isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
                    child: Text('Rien pour ce repas.', style: AppType.rowSubtitle()),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        if (entries.isNotEmpty)
          Text('Touche un aliment pour changer sa quantité, appui long pour le retirer.', textAlign: TextAlign.center, style: AppType.rowSubtitle()),
      ],
    );

    final logs = n.waterLogsFor(_jour)..sort((a, b) => b.date.compareTo(a.date));
    final cEau = CouleursMacros.eau(context);
    final carteEau = AppCard(
      label: 'Eau',
      labelTrailing: logs.isEmpty ? null : AccentLink(label: 'Annuler le dernier', onTap: () => n.undoWater(_jour)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigNumber(
            value: Fmt.n(eau / 1000, decimals: 2),
            unit: 'L',
            size: 36,
            caption: eau >= goals.eauMl ? 'Objectif atteint' : 'Encore ${Fmt.n((goals.eauMl - eau) / 1000, decimals: 2)} L pour ${Fmt.n(goals.eauMl / 1000, decimals: 1)} L',
            captionColor: eau >= goals.eauMl ? c.accent : null,
          ),
          const SizedBox(height: 10),
          ProgressBar(value: goals.eauMl <= 0 ? 0 : eau / goals.eauMl, color: cEau),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ml in const [250, 500, 750]) PillButton(label: '+$ml ml', variant: PillVariant.outline, size: PillSize.small, onPressed: () => _eau(ml)),
              PillButton(label: 'Autre', icon: Icons.edit_rounded, variant: PillVariant.outline, size: PillSize.small, onPressed: _eauLibre),
            ],
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(logs.take(6).map((w) => '${Fmt.heure(w.date)} ${w.ml} ml').join('  ·  '), style: AppType.rowSubtitle()),
          ],
        ],
      ),
    );

    final libelleJour = _aujourdhui
        ? 'Aujourd\'hui'
        : Dates.memeJour(_jour, DateTime.now().subtract(const Duration(days: 1)))
            ? 'Hier'
            : Fmt.jourCap(_jour);

    return SousPage(
      title: 'Nutrition',
      subtitle: 'Objectif ${Fmt.kcal(goals.kcal)} · P ${Fmt.n(goals.proteinesG, decimals: 0)} g',
      haloColor: c.nutrition,
      maxContentWidth: large ? 1100 : Breakpoints.content,
      bottomBar: PillButton(
        label: 'Noter un repas',
        icon: Icons.add_rounded,
        size: PillSize.large,
        expand: true,
        onPressed: () => context.go(Paths.nutrition),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          StepSelector(
            label: libelleJour,
            previousTooltip: 'Jour précédent',
            nextTooltip: 'Jour suivant',
            onPrevious: () => setState(() => _jour = _jour.subtract(const Duration(days: 1))),
            onNext: _aujourdhui ? null : () => setState(() => _jour = _jour.add(const Duration(days: 1))),
            onTapLabel: _aujourdhui ? null : () => setState(() => _jour = Dates.jour(DateTime.now())),
          ),
          const SizedBox(height: 12),
          if (large)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: [anneau, const SizedBox(height: 12), macros, const SizedBox(height: 12), carteEau])),
                const SizedBox(width: 12),
                Expanded(child: repas),
              ],
            )
          else ...[
            anneau,
            const SizedBox(height: 12),
            macros,
            const SizedBox(height: 12),
            carteEau,
            const SizedBox(height: 12),
            repas,
          ],
        ],
      ),
    );
  }
}

class _Petit extends StatelessWidget {
  const _Petit({required this.label, required this.valeur});
  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppType.overline()),
          const SizedBox(height: 3),
          Text(valeur, style: AppType.rowValue().copyWith(fontSize: 13.5)),
        ],
      );
}
