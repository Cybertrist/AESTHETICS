import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/logic/nutrition_calc.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../widgets/nutri_page.dart';
import '../widgets/journal_actions.dart';
import '../widgets/nutri_widgets.dart';

/// Objectifs : calcul depuis le profil, réglage à la main, cyclage.
class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  late final NutritionExtras x = NutritionExtras.of(context);
  late NutritionGoals _g = NutritionCalc.effectifs(context.read<ProfileRepo>().profile);
  late CarbCycling _cy = x.cyclage;
  bool _pourcent = false;
  bool _dirty = false;
  bool _saving = false;

  void _set(NutritionGoals g) => setState(() {
        _g = g;
        _dirty = true;
      });

  double get _kcalMacros => NutritionCalc.kcalDesMacros(proteines: _g.proteinesG, glucides: _g.glucidesG, lipides: _g.lipidesG);

  /// Glucides recalculés pour que les macros tombent sur les calories.
  void _equilibrer() {
    final g = ((_g.kcal - _g.proteinesG * 4 - _g.lipidesG * 9) / 4).clamp(0, 2000).toDouble();
    _set(_g.copyWith(glucidesG: (g / 5).round() * 5.0));
  }

  /// Répartition en pourcentages : les glucides prennent le reste.
  void _setPct({int? p, int? l}) {
    final (pp0, _, lp0) = macroPercents(Macros(proteines: _g.proteinesG, glucides: _g.glucidesG, lipides: _g.lipidesG));
    final pp = (p ?? pp0).clamp(5, 70);
    final lp = (l ?? lp0).clamp(5, 70);
    final gp = (100 - pp - lp).clamp(0, 90);
    _set(_g.copyWith(
      proteinesG: (_g.kcal * pp / 100 / 4).roundToDouble(),
      lipidesG: (_g.kcal * lp / 100 / 9).roundToDouble(),
      glucidesG: (_g.kcal * gp / 100 / 4).roundToDouble(),
    ));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await saveGoals(context, _g);
    await x.setCyclage(_cy);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    _dirty = false;
    Toasts.success(context, 'Objectifs enregistrés');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profil = context.watch<ProfileRepo>().profile;
    final reco = profil == null ? null : NutritionCalc.objectifs(profil);
    final bmr = profil == null
        ? null
        : NutritionCalc.metabolismeDeBase(sexe: profil.sexe, poidsKg: profil.poidsKg ?? 75, tailleCm: profil.tailleCm ?? 178, age: profil.age ?? 28);
    final tdee = profil == null ? null : NutritionCalc.depenseTotale(profil);
    final manque = profil == null ? <String>[] : [if (profil.poidsKg == null) 'poids', if (profil.tailleCm == null) 'taille', if (profil.naissance == null) 'date de naissance'];
    final (pp, gp, lp) = macroPercents(Macros(proteines: _g.proteinesG, glucides: _g.glucidesG, lipides: _g.lipidesG));
    final ecart = _kcalMacros - _g.kcal;

    final calcul = AppCard(
      label: 'CALCUL DEPUIS TON PROFIL',
      labelTrailing: AccentLink(label: 'Profil', onTap: () => context.go('/profil')),
      child: profil == null
          ? Text('Crée ton profil pour obtenir un calcul personnalisé.', style: AppType.rowSubtitle())
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                '${profil.sexe.label}, ${profil.age ?? '?'} ans, ${Fmt.n(profil.tailleCm, decimals: 0)} cm, ${Fmt.poids(profil.poidsKg)} · activité ${profil.activite.label.toLowerCase()} · ${profil.objectif.label.toLowerCase()}',
                style: AppType.rowSubtitle(color: c.text2),
              ),
              if (manque.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: c.warning),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Il manque ${manque.join(', ')} : une valeur moyenne est utilisée.', style: AppType.rowSubtitle(color: c.warning))),
                ]),
              ],
              const SizedBox(height: 14),
              _CalcRow('Métabolisme de base', Fmt.kcal(bmr), 'Mifflin-St Jeor'),
              _CalcRow('Dépense du quotidien', Fmt.kcal(tdee), '× ${Fmt.n(profil.activite.facteur, decimals: 3)} (activité)'),
              _CalcRow('Selon ton objectif', '${NutritionCalc.ajustement(profil.objectif) >= 0 ? '+' : ''}${Fmt.kcal(NutritionCalc.ajustement(profil.objectif))}', profil.objectif.label),
              Divider(color: c.line, height: 20),
              Row(children: [
                Expanded(child: BigNumber(label: 'Recommandé', value: Fmt.n(reco!.kcal, decimals: 0), unit: 'kcal', size: 32, caption: 'P ${Fmt.n(reco.proteinesG, decimals: 0)} g · G ${Fmt.n(reco.glucidesG, decimals: 0)} g · L ${Fmt.n(reco.lipidesG, decimals: 0)} g')),
                PillButton.secondary(label: 'Utiliser', size: PillSize.small, onPressed: () => _set(reco)),
              ]),
            ]),
    );

    final kcal = AppCard(
      label: 'MES OBJECTIFS',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        NumberStepper(label: 'Calories par jour', value: _g.kcal, step: 50, min: 1000, max: 7000, unit: 'kcal', onChanged: (v) => _set(_g.copyWith(kcal: v))),
        const SizedBox(height: 18),
        SegmentedControl<bool>(
          height: 44,
          segments: const [(false, 'En grammes'), (true, 'En pourcentages')],
          value: _pourcent,
          onChanged: (v) => setState(() => _pourcent = v),
        ),
        const SizedBox(height: 16),
        if (!_pourcent) ...[
          NumberStepper(label: 'Protéines', value: _g.proteinesG, step: 5, min: 0, max: 500, unit: 'g', onChanged: (v) => _set(_g.copyWith(proteinesG: v))),
          if (profil?.poidsKg != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${Fmt.n(_g.proteinesG / profil!.poidsKg!, decimals: 1)} g par kilo de poids de corps', style: AppType.rowSubtitle()),
            ),
          const SizedBox(height: 14),
          NumberStepper(label: 'Glucides', value: _g.glucidesG, step: 5, min: 0, max: 1000, unit: 'g', onChanged: (v) => _set(_g.copyWith(glucidesG: v))),
          const SizedBox(height: 14),
          NumberStepper(label: 'Lipides', value: _g.lipidesG, step: 5, min: 0, max: 400, unit: 'g', onChanged: (v) => _set(_g.copyWith(lipidesG: v))),
        ] else ...[
          _PctSlider(label: 'Protéines', value: pp, color: c.proteines, grams: _g.proteinesG, onChanged: (v) => _setPct(p: v)),
          _PctSlider(label: 'Lipides', value: lp, color: c.lipides, grams: _g.lipidesG, onChanged: (v) => _setPct(l: v)),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: c.glucides, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text('Glucides : le reste, $gp %', style: AppType.rowTitle().copyWith(fontSize: 14))),
              Text('${Fmt.n(_g.glucidesG, decimals: 0)} g', style: AppType.rowValue().copyWith(fontSize: 14)),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        SegmentedBar(parts: [(pp.toDouble(), c.proteines), (gp.toDouble(), c.glucides), (lp.toDouble(), c.lipides)]),
        const SizedBox(height: 8),
        Text('Protéines $pp %, glucides $gp %, lipides $lp %', style: AppType.rowSubtitle()),
        if (ecart.abs() > 60) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: c.warning),
            const SizedBox(width: 6),
            Expanded(child: Text('Les macros font ${Fmt.kcal(_kcalMacros)}, soit ${Fmt.n(ecart.abs(), decimals: 0)} kcal ${ecart > 0 ? 'de plus' : 'de moins'}.', style: AppType.rowSubtitle(color: c.warning))),
          ]),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: PillButton.link(label: 'Ajuster les glucides', size: PillSize.small, onPressed: _equilibrer)),
        ],
      ]),
    );

    final autres = AppCard(
      label: 'FIBRES ET EAU',
      child: Column(children: [
        NumberStepper(label: 'Fibres', value: _g.fibresG, step: 5, min: 0, max: 100, unit: 'g', onChanged: (v) => _set(_g.copyWith(fibresG: v))),
        const SizedBox(height: 14),
        NumberStepper(label: 'Eau', value: _g.eauMl.toDouble(), step: 250, min: 500, max: 6000, unit: 'ml', onChanged: (v) => _set(_g.copyWith(eauMl: v.round()))),
      ]),
    );

    const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final entr = _g.kcal + _cy.bonusEntrainement;
    final repos = _g.kcal - _cy.baisseRepos;
    final nEntr = _cy.joursEntrainement.length;
    final moyenne = (entr * nEntr + repos * (7 - nEntr)) / 7;
    final cyclage = AppCard(
      label: 'CYCLAGE DES CALORIES',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _cy.actif,
          onChanged: (v) => setState(() {
            _cy = _cy.copyWith(actif: v);
            _dirty = true;
          }),
          title: Text('Manger plus les jours d\'entraînement', style: AppType.rowTitle()),
          subtitle: Text('L\'écart passe par les glucides, les protéines et lipides ne bougent pas.', style: AppType.rowSubtitle()),
        ),
        if (_cy.actif) ...[
          const SizedBox(height: 8),
          Text('Jours d\'entraînement', style: AppType.rowSubtitle(color: c.text2)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 1; i <= 7; i++)
              ChipFilter(
                label: jours[i - 1],
                selected: _cy.joursEntrainement.contains(i),
                onTap: () => setState(() {
                  final s = {..._cy.joursEntrainement};
                  if (!s.remove(i)) s.add(i);
                  _cy = _cy.copyWith(joursEntrainement: s);
                  _dirty = true;
                }),
              ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _cy.suivreSeances,
            onChanged: (v) => setState(() {
              _cy = _cy.copyWith(suivreSeances: v);
              _dirty = true;
            }),
            title: Text('Suivre mes séances', style: AppType.rowTitle().copyWith(fontSize: 14)),
            subtitle: Text('Un jour avec une séance enregistrée compte comme entraînement.', style: AppType.rowSubtitle()),
          ),
          const SizedBox(height: 6),
          NumberStepper(label: 'En plus, jour d\'entraînement', value: _cy.bonusEntrainement, step: 50, min: 0, max: 1500, unit: 'kcal', onChanged: (v) => setState(() {
            _cy = _cy.copyWith(bonusEntrainement: v);
            _dirty = true;
          })),
          const SizedBox(height: 14),
          NumberStepper(label: 'En moins, jour de repos', value: _cy.baisseRepos, step: 50, min: 0, max: 1500, unit: 'kcal', onChanged: (v) => setState(() {
            _cy = _cy.copyWith(baisseRepos: v);
            _dirty = true;
          })),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Mini(icon: Icons.fitness_center_rounded, color: c.training, label: 'Entraînement', value: Fmt.n(entr, decimals: 0))),
            const SizedBox(width: 8),
            Expanded(child: _Mini(icon: Icons.self_improvement_rounded, color: c.sleep, label: 'Repos', value: Fmt.n(repos, decimals: 0))),
            const SizedBox(width: 8),
            Expanded(child: _Mini(icon: Icons.functions_rounded, color: c.nutrition, label: 'Moyenne', value: Fmt.n(moyenne, decimals: 0))),
          ]),
        ],
      ]),
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await showConfirmDialog(context, title: 'Quitter sans enregistrer ?', confirmLabel: 'Quitter', destructive: true);
        if (ok && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: NutriSubPage(
        title: 'Objectifs',
        subtitle: 'Calories, macros, eau, cyclage',
        bottomBar: PillButton(label: 'Enregistrer', icon: Icons.check_rounded, expand: true, size: PillSize.large, loading: _saving, onPressed: _dirty ? _save : null),
        maxContentWidth: 1000,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
          children: [
            TwoPane(
              breakpoint: 680,
              left: Padding(
                padding: EdgeInsets.only(right: context.screenWidth >= 680 ? 8 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [calcul, const SizedBox(height: 12), kcal]),
              ),
              right: Padding(
                padding: EdgeInsets.only(top: context.screenWidth < 680 ? 12 : 0, left: context.screenWidth >= 680 ? 8 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cyclage, const SizedBox(height: 12), autres]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  const _CalcRow(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppType.rowTitle().copyWith(fontSize: 14)),
              Text(detail, style: AppType.rowSubtitle()),
            ]),
          ),
          Text(value, style: AppType.rowValue().copyWith(fontSize: 14)),
        ]),
      );
}

class _PctSlider extends StatelessWidget {
  const _PctSlider({required this.label, required this.value, required this.color, required this.grams, required this.onChanged});
  final String label;
  final int value;
  final Color color;
  final double grams;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text('$label : $value %', style: AppType.rowTitle().copyWith(fontSize: 14))),
          Text('${Fmt.n(grams, decimals: 0)} g', style: AppType.rowValue().copyWith(fontSize: 14)),
        ]),
        Slider(value: value.toDouble().clamp(5, 70), min: 5, max: 70, divisions: 65, activeColor: color, label: '$value %', onChanged: (v) => onChanged(v.round())),
      ]);
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.color, required this.label, required this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.colors.surface2, borderRadius: AppTokens.radius14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle()),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text.rich(TextSpan(children: [TextSpan(text: value, style: AppType.number(18)), TextSpan(text: ' kcal', style: AppType.rowSubtitle())]))),
        ]),
      );
}
