import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/logic/format.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/nutrition_extras.dart';
import '../data/nutrition_logic.dart';
import '../widgets/journal_actions.dart';
import '../widgets/nutri_widgets.dart';

/// Calendrier du journal : un mois, chaque jour coloré selon l'objectif.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final NutritionExtras x = NutritionExtras.of(context);
  late DateTime _mois = Dates.debutMois(x.jour.value);

  void _open(DateTime d) {
    x.jour.value = d;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final now = Dates.jour(DateTime.now());
    final first = _mois;
    final nbJours = DateTime(first.year, first.month + 1, 0).day;
    final decalage = first.weekday - 1;
    final jours = [for (var i = 0; i < nbJours; i++) DateTime(first.year, first.month, i + 1)];

    var notes = 0, tenus = 0, depasses = 0;
    double somme = 0;
    final etats = <DateTime, (double, double)>{};
    for (final d in jours) {
      final k = repo.totalsFor(d).kcal;
      if (k <= 0) continue;
      final g = goalsOf(context, d).goals.kcal;
      etats[d] = (k, g);
      notes++;
      somme += k;
      if (NutritionLogic.tenu(k, g)) tenus++;
      if (k > g * (1 + NutritionLogic.tolerance)) depasses++;
    }

    Color? couleur(DateTime d) {
      final e = etats[d];
      if (e == null) return null;
      final (k, g) = e;
      if (NutritionLogic.tenu(k, g)) return c.kcal;
      if (k > g) return c.warning;
      return c.text3;
    }

    return SubPageScaffold(
      title: 'Calendrier',
      subtitle: 'Touche un jour pour l\'ouvrir',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
        children: [
          MonthSelector(month: _mois, onChanged: (m) => setState(() => _mois = m), last: DateTime(now.year, now.month + 1)),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: Column(children: [
              Row(children: [
                for (final l in Dates.initiales)
                  Expanded(child: Center(child: Text(l, style: AppType.overline(color: c.text3)))),
              ]),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (var i = 0; i < decalage; i++) const SizedBox.shrink(),
                  for (final d in jours)
                    _DayCell(
                      day: d,
                      color: couleur(d),
                      selected: Dates.memeJour(d, x.jour.value),
                      today: Dates.memeJour(d, now),
                      onTap: () => _open(d),
                    ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 14, runSpacing: 8, children: [
            _Legend(color: c.kcal, label: 'Objectif tenu (à 10 % près)'),
            _Legend(color: c.warning, label: 'Au-dessus'),
            _Legend(color: c.text3, label: 'En dessous'),
          ]),
          const SizedBox(height: 16),
          AppCard(
            label: Fmt.mois(_mois).toUpperCase(),
            child: notes == 0
                ? Text('Rien de noté ce mois-ci.', style: AppType.rowSubtitle())
                : Row(children: [
                    Expanded(child: _Mini(label: 'Jours notés', value: '$notes')),
                    Expanded(child: _Mini(label: 'Objectif tenu', value: '$tenus')),
                    Expanded(child: _Mini(label: 'Moyenne', value: Fmt.n(somme / notes, decimals: 0), unit: 'kcal')),
                    Expanded(child: _Mini(label: 'Au-dessus', value: '$depasses')),
                  ]),
          ),
          const SizedBox(height: 16),
          Center(child: PillButton.link(label: 'Revenir à aujourd\'hui', icon: Icons.today_rounded, onPressed: () => _open(now))),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.color, required this.selected, required this.today, required this.onTap});
  final DateTime day;
  final Color? color;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: Fmt.jourCap(day),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTokens.radius12,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : (color == null ? Colors.transparent : color!.withValues(alpha: 0.12)),
            borderRadius: AppTokens.radius12,
            border: Border.all(color: selected ? c.accent : (today ? c.text3 : Colors.transparent), width: selected ? 1.5 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${day.day}', style: AppType.number(14, color: color == null ? c.text3 : c.text)),
            const SizedBox(height: 3),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color ?? Colors.transparent, shape: BoxShape.circle)),
          ]),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppType.rowSubtitle()),
      ]);
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, this.unit});
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle()),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: value, style: AppType.number(20)),
            if (unit != null) TextSpan(text: ' $unit', style: AppType.rowSubtitle()),
          ])),
        ),
      ]);
}
