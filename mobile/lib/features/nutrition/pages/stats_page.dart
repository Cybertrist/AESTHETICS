import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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
import '../nav.dart';
import '../widgets/nutri_widgets.dart';

/// Statistiques : moyennes sur 7, 30 ou 90 jours, courbes, respect des macros.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _Jour {
  _Jour(this.date, this.m, this.goals, this.eau);
  final DateTime date;
  final Macros m;
  final NutritionGoals goals;
  final int eau;
  bool get note => m.kcal > 0;
}

class _StatsPageState extends State<StatsPage> {
  int _jours = 7;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<NutritionRepo>();
    final profil = context.watch<ProfileRepo>().profile;
    final sessions = context.watch<SessionRepo>();
    final x = NutritionExtras.of(context);
    final fin = Dates.jour(DateTime.now());
    final totals = NutritionLogic.dailyTotals(repo, fin, _jours);
    final jours = [
      for (final (d, m) in totals) _Jour(d, m, NutritionLogic.goalsFor(d, profil: profil, cyclage: x.cyclage, sessions: sessions).goals, repo.waterFor(d)),
    ];
    final notes = jours.where((j) => j.note).toList();
    final n = notes.length;

    Macros moyenne() => n == 0 ? Macros.zero : notes.fold(Macros.zero, (a, j) => a + j.m).scale(1 / n);
    double moyObj(double Function(NutritionGoals) f) => n == 0 ? f(jours.last.goals) : notes.fold(0.0, (a, j) => a + f(j.goals)) / n;
    int taux(bool Function(_Jour) ok) => n == 0 ? 0 : (notes.where(ok).length / n * 100).round();

    final moy = moyenne();
    final objKcal = moyObj((g) => g.kcal);
    final tenus = taux((j) => NutritionLogic.tenu(j.m.kcal, j.goals.kcal));
    final protOk = taux((j) => j.m.proteines >= j.goals.proteinesG * 0.9);
    final glucOk = taux((j) => NutritionLogic.tenu(j.m.glucides, j.goals.glucidesG) || (j.m.glucides - j.goals.glucidesG).abs() < 15);
    final lipOk = taux((j) => NutritionLogic.tenu(j.m.lipides, j.goals.lipidesG) || (j.m.lipides - j.goals.lipidesG).abs() < 8);
    final eauMoy = jours.isEmpty ? 0 : jours.fold(0, (a, j) => a + j.eau) / jours.length;
    final eauObj = jours.last.goals.eauMl;

    final selecteur = SegmentedChips<int>(
      segments: const [(7, '7 jours'), (30, '30 jours'), (90, '90 jours')],
      value: _jours,
      onChanged: (v) => setState(() => _jours = v),
    );

    if (n == 0) {
      return SubPageScaffold(
        title: 'Statistiques',
        haloColor: c.training,
        body: ListView(padding: const EdgeInsets.all(AppTokens.gutter), children: [
          selecteur,
          const SizedBox(height: 40),
          EmptyState(
            icon: Icons.insights_rounded,
            iconColor: c.training,
            title: 'Pas encore de données',
            message: 'Note tes repas quelques jours : moyennes, courbes et respect des macros apparaîtront ici.',
            actionLabel: 'Ajouter un repas',
            onAction: () => NutritionNav.addFood(context, jour: fin),
          ),
        ]),
      );
    }

    final resume = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BigNumber(
          label: 'Moyenne par jour noté',
          value: Fmt.n(moy.kcal, decimals: 0),
          unit: 'kcal',
          caption: '${moy.kcal >= objKcal ? '+' : ''}${Fmt.n(moy.kcal - objKcal, decimals: 0)} kcal par rapport à l\'objectif (${Fmt.n(objKcal, decimals: 0)})',
          captionColor: NutritionLogic.tenu(moy.kcal, objKcal) ? c.kcal : c.text3,
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Tile(label: 'Jours notés', value: '$n', unit: '/ $_jours')),
          const SizedBox(width: 8),
          Expanded(child: _Tile(label: 'Objectif tenu', value: '$tenus', unit: '%')),
          const SizedBox(width: 8),
          Expanded(child: _Tile(label: 'Série', value: '${NutritionLogic.streak(repo)}', unit: 'j')),
        ]),
      ]),
    );

    final kcalChart = AppCard(
      label: 'CALORIES PAR JOUR',
      labelTrailing: LabelCount('trait : objectif'),
      child: SizedBox(height: 190, child: _KcalChart(jours: jours)),
    );

    final (pp, gp, lp) = macroPercents(moy);
    final macros = AppCard(
      label: 'MACROS EN MOYENNE',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          MacroSplitRing(macros: moy, size: 104, center: Text('$pp %', style: AppType.number(16, color: c.proteines))),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Legend(color: c.proteines, label: 'Protéines', value: '$pp %'),
              _Legend(color: c.glucides, label: 'Glucides', value: '$gp %'),
              _Legend(color: c.lipides, label: 'Lipides', value: '$lp %'),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        MacroBar(label: 'Protéines', value: moy.proteines, goal: moyObj((g) => g.proteinesG), color: c.proteines, compact: true),
        const SizedBox(height: 12),
        MacroBar(label: 'Glucides', value: moy.glucides, goal: moyObj((g) => g.glucidesG), color: c.glucides, compact: true),
        const SizedBox(height: 12),
        MacroBar(label: 'Lipides', value: moy.lipides, goal: moyObj((g) => g.lipidesG), color: c.lipides, compact: true),
        const SizedBox(height: 12),
        MacroBar(label: 'Fibres', value: moy.fibres, goal: moyObj((g) => g.fibresG), color: c.nutrition, compact: true),
      ]),
    );

    final respect = AppCard(
      label: 'RESPECT DES OBJECTIFS',
      child: Column(children: [
        _Respect(label: 'Calories à 10 % près', pct: tenus, color: c.kcal),
        _Respect(label: 'Protéines atteintes', pct: protOk, color: c.proteines),
        _Respect(label: 'Glucides dans la cible', pct: glucOk, color: c.glucides),
        _Respect(label: 'Lipides dans la cible', pct: lipOk, color: c.lipides),
        _Respect(label: 'Eau atteinte', pct: (jours.where((j) => j.eau >= j.goals.eauMl).length / jours.length * 100).round(), color: c.eau),
        const SizedBox(height: 4),
        Text('Part des jours notés où l\'objectif est tenu.', style: AppType.rowSubtitle()),
      ]),
    );

    final protChart = AppCard(
      label: 'PROTÉINES PAR JOUR',
      child: SizedBox(height: 170, child: _LineChart(jours: jours, value: (j) => j.m.proteines, goal: (j) => j.goals.proteinesG, color: c.proteines)),
    );

    final eau = AppCard(
      label: 'EAU',
      child: Row(children: [
        IconHalo(icon: Icons.water_drop_rounded, color: c.eau),
        const SizedBox(width: 14),
        Expanded(child: Text('En moyenne ${Fmt.n(eauMoy / 1000, decimals: 2)} L par jour, pour ${Fmt.n(eauObj / 1000, decimals: 1)} L visés.', style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 14))),
      ]),
    );

    final debut = fin.subtract(Duration(days: _jours - 1));
    final top = NutritionLogic.topFoods(repo, debut, fin.add(const Duration(days: 1)));
    final aliments = AppCard(
      label: 'ALIMENTS LES PLUS NOTÉS',
      child: top.isEmpty
          ? Text('Aucun aliment sur la période.', style: AppType.rowSubtitle())
          : Column(children: [
              for (final (nom, fois, kcal) in top)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontSize: 14))),
                    Text('$fois fois', style: AppType.rowSubtitle()),
                    const SizedBox(width: 12),
                    SizedBox(width: 72, child: Text(Fmt.kcal(kcal), textAlign: TextAlign.right, style: AppType.rowValue().copyWith(fontSize: 13, color: c.text2))),
                  ]),
                ),
            ]),
    );

    final parRepas = <MealType, double>{for (final t in MealType.values) t: 0};
    for (final e in repo.entries) {
      if (e.date.isBefore(debut) || !e.date.isBefore(fin.add(const Duration(days: 1)))) continue;
      parRepas[e.repas] = parRepas[e.repas]! + e.macros.kcal;
    }
    final couleurs = [c.weight, c.nutrition, c.coach, c.sleep];
    final repas = AppCard(
      label: 'CALORIES PAR REPAS',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedBar(parts: [for (var i = 0; i < MealType.values.length; i++) (parRepas[MealType.values[i]]!, couleurs[i])]),
        const SizedBox(height: 10),
        for (var i = 0; i < MealType.values.length; i++)
          _Legend(color: couleurs[i], label: x.nomRepas(MealType.values[i]), value: '${Fmt.n(parRepas[MealType.values[i]]! / n, decimals: 0)} kcal'),
      ]),
    );

    return SubPageScaffold(
      title: 'Statistiques',
      subtitle: '${Fmt.jourMois(debut)} au ${Fmt.jourMois(fin)}',
      haloColor: c.training,
      maxContentWidth: 1100,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
        children: [
          selecteur,
          const SizedBox(height: 14),
          TwoPane(
            breakpoint: 720,
            left: Padding(
              padding: EdgeInsets.only(right: context.screenWidth >= 720 ? 8 : 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [resume, const SizedBox(height: 12), kcalChart, const SizedBox(height: 12), protChart, const SizedBox(height: 12), repas]),
            ),
            right: Padding(
              padding: EdgeInsets.only(top: context.screenWidth < 720 ? 12 : 0, left: context.screenWidth >= 720 ? 8 : 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [macros, const SizedBox(height: 12), respect, const SizedBox(height: 12), eau, const SizedBox(height: 12), aliments]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.unit});
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.colors.surface2, borderRadius: AppTokens.radius14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle()),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [TextSpan(text: value, style: AppType.number(22)), if (unit != null) TextSpan(text: ' $unit', style: AppType.rowSubtitle())])),
          ),
        ]),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppType.rowTitle().copyWith(fontSize: 14))),
          Text(value, style: AppType.rowValue().copyWith(fontSize: 14)),
        ]),
      );
}

class _Respect extends StatelessWidget {
  const _Respect({required this.label, required this.pct, required this.color});
  final String label;
  final int pct;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ProgressBar(value: pct / 100, label: label, trailing: '$pct %', color: color),
      );
}

String _axe(DateTime d, int n) => n <= 7 ? Dates.initiale(d) : '${d.day}/${d.month}';

class _KcalChart extends StatelessWidget {
  const _KcalChart({required this.jours});
  final List<_Jour> jours;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxY = jours.fold<double>(0, (a, j) => math.max(a, math.max(j.m.kcal, j.goals.kcal))) * 1.15;
    final n = jours.length;
    final pas = n <= 7 ? 1 : (n <= 30 ? 5 : 15);
    final larg = n <= 7 ? 18.0 : (n <= 30 ? 6.0 : 2.5);
    final obj = jours.last.goals.kcal;
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 100 : maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => c.surface3,
            getTooltipItem: (g, _, rod, _) => BarTooltipItem(
              '${Fmt.jourMois(jours[g.x].date)}\n${Fmt.kcal(rod.toY)}',
              AppType.rowSubtitle(color: c.text).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [HorizontalLine(y: obj, color: c.text2, strokeWidth: 1, dashArray: [5, 4])]),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= n || (n - 1 - i) % pas != 0) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(_axe(jours[i].date, n), style: AppType.rowSubtitle().copyWith(fontSize: 10.5)));
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < n; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: jours[i].m.kcal,
                width: larg,
                borderRadius: BorderRadius.circular(larg / 2.5),
                color: !jours[i].note
                    ? c.text3
                    : NutritionLogic.tenu(jours[i].m.kcal, jours[i].goals.kcal)
                        ? c.kcal
                        : (jours[i].m.kcal > jours[i].goals.kcal ? c.warning : c.kcal.withValues(alpha: 0.45)),
              ),
            ]),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.jours, required this.value, required this.goal, required this.color});
  final List<_Jour> jours;
  final double Function(_Jour) value;
  final double Function(_Jour) goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = jours.length;
    final pas = n <= 7 ? 1 : (n <= 30 ? 5 : 15);
    final spots = [for (var i = 0; i < n; i++) if (jours[i].note) FlSpot(i.toDouble(), value(jours[i]))];
    final maxY = jours.fold<double>(0, (a, j) => math.max(a, math.max(value(j), goal(j)))) * 1.2;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: 0,
        maxY: maxY <= 0 ? 10 : maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => c.surface3,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem('${Fmt.jourMois(jours[s.x.toInt()].date)}\n${Fmt.n(s.y, decimals: 0)} g', AppType.rowSubtitle(color: c.text).copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [HorizontalLine(y: goal(jours.last), color: c.text2, strokeWidth: 1, dashArray: [5, 4])]),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (v != i.toDouble() || i < 0 || i >= n || (n - 1 - i) % pas != 0) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(_axe(jours[i].date, n), style: AppType.rowSubtitle().copyWith(fontSize: 10.5)));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(show: n <= 30),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
