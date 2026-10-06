import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/data/data.dart';
import '../../../../../core/logic/logic.dart';
import '../../../../../core/models/models.dart';
import '../../../../../core/theme/theme.dart';
import '../../../../../core/ui/ui.dart';
import '../../../commun/elements.dart';
import '../../../commun/traits.dart';
import '../../logic/exercise_stats.dart';
import '../../logic/formats.dart';

/// Onglet « Progrès » : une courbe par indicateur, sur une période.
class TabProgres extends StatefulWidget {
  const TabProgres({super.key, required this.exercise, required this.stats, this.onEntrainer});

  final Exercise exercise;
  final ExerciseStats stats;
  final VoidCallback? onEntrainer;

  @override
  State<TabProgres> createState() => _TabProgresState();
}

class _TabProgresState extends State<TabProgres> {
  late List<StatMetric> _metrics = StatMetric.pour(widget.exercise.suivi);
  late StatMetric _metric = _metrics.first;
  StatPeriod _period = StatPeriod.mois3;

  @override
  void didUpdateWidget(covariant TabProgres old) {
    super.didUpdateWidget(old);
    if (old.exercise.suivi != widget.exercise.suivi) {
      _metrics = StatMetric.pour(widget.exercise.suivi);
      if (!_metrics.contains(_metric)) _metric = _metrics.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final u = context.watch<ProfileRepo>().unite;
    final stats = widget.stats;
    if (stats.vide) {
      return SingleChildScrollView(
        child: Vide(
          trait: Trait.trier,
          titre: 'Pas encore de courbe',
          message: 'Fais cet exercice pendant quelques séances pour suivre ta progression.',
          action: widget.onEntrainer == null ? null : 'S’entraîner sur cet exercice',
          onAction: widget.onEntrainer,
        ),
      );
    }
    final pts = stats.dans(_period).where((p) => p.valeur(_metric) > 0).toList();

    final indicateurs = SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: margeEcran),
        children: [
          for (final m in _metrics)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Puce(label: m.label, active: m == _metric, onTap: () => setState(() => _metric = m)),
            ),
        ],
      ),
    );

    Widget contenu;
    if (pts.isEmpty) {
      contenu = Carte(
        child: Column(
          children: [
            Text('Rien sur cette période', style: TexteEntrainer.ligneForte(context)),
            const SizedBox(height: 4),
            Text('Dernière fois : ${Fmt.relatif(stats.derniere!).toLowerCase()}.', style: TexteEntrainer.detail(context)),
            const SizedBox(height: 14),
            BoutonSecondaire(label: 'Tout afficher', petit: true, onPressed: () => setState(() => _period = StatPeriod.tout)),
          ],
        ),
      );
    } else {
      final dernier = pts.last.valeur(_metric);
      final premier = pts.first.valeur(_metric);
      final delta = dernier - premier;
      final meilleur = pts.map((p) => p.valeur(_metric)).reduce(math.max);
      final moyenne = pts.map((p) => p.valeur(_metric)).reduce((a, b) => a + b) / pts.length;
      final pct = premier > 0 ? delta / premier * 100 : 0.0;
      String signe(double v) => v > 0 ? '+' : (v < 0 ? '-' : '');
      // Une valeur inchangée n'affiche rien.
      final evolution = pts.length < 2 || delta == 0
          ? null
          : '${signe(delta)}${ExFmt.metric(_metric, delta.abs(), u)} depuis le ${Fmt.jourMois(pts.first.date)}';

      Widget chiffre(String label, String valeur, {Color? couleur}) => Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12.5, 10, 12.5, 10),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(15)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      valeur,
                      maxLines: 1,
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 19, height: 1.3, fontWeight: FontWeight.w700, color: couleur ?? c.text, fontFeatures: AppTokens.tabular),
                    ),
                  ),
                  Text(label, maxLines: 1, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 12.5, height: 1.35, color: c.text2)),
                ],
              ),
            ),
          );

      contenu = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Carte(
            padding: const EdgeInsets.fromLTRB(17.5, 17.5, 17.5, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Surtitre('${_metric.label} · ${Fmt.jourMois(pts.last.date)}'),
                const SizedBox(height: 6),
                Text(
                  ExFmt.metric(_metric, dernier, u),
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 35, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.text, fontFeatures: AppTokens.tabular),
                ),
                if (evolution != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    evolution,
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.8, fontWeight: FontWeight.w600, color: delta > 0 ? c.success : c.text2, fontFeatures: AppTokens.tabular),
                  ),
                ],
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(height: context.isWide ? 280 : 210, child: _Courbe(points: pts, metric: _metric, unite: u)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7.5),
          Row(children: [
            chiffre('meilleur', ExFmt.metric(_metric, meilleur, u)),
            const SizedBox(width: 7.5),
            chiffre('moyenne', ExFmt.metric(_metric, moyenne, u)),
            const SizedBox(width: 7.5),
            chiffre(pts.length > 1 ? 'séances' : 'séance', Fmt.n(pts.length, decimals: 0)),
          ]),
          if (pts.length >= 2 && pct != 0) ...[
            const SizedBox(height: 14),
            Text(
              '${signe(pct)}${Fmt.n(pct.abs())} % sur la période.',
              style: TexteEntrainer.detail(context).copyWith(color: pct > 0 ? c.success : c.text2, fontWeight: FontWeight.w600),
            ),
          ],
          if (_metric == StatMetric.unRm) ...[
            const SizedBox(height: 10),
            Text(
              'Le 1RM estimé est calculé à partir de ta meilleure série de chaque séance.',
              style: TexteEntrainer.detail(context).copyWith(fontSize: 13, color: c.text3),
            ),
          ],
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 17.5, bottom: 36),
      children: [
        indicateurs,
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: margeEcran),
          child: SelecteurSegmente<StatPeriod>(
            segments: [for (final p in StatPeriod.values) (p, p.label)],
            value: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
        ),
        const SizedBox(height: 14),
        Padding(padding: const EdgeInsets.symmetric(horizontal: margeEcran), child: contenu),
      ],
    );
  }
}

/// Pilule de choix d'un indicateur : cadre blanc quand elle est retenue.
class _Puce extends StatelessWidget {
  const _Puce({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: c.surface2,
        shape: StadiumBorder(side: active ? BorderSide(color: c.text, width: 1.5) : BorderSide.none),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(label, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14.5, fontWeight: FontWeight.w600, color: active ? c.text : c.text2)),
          ),
        ),
      ),
    );
  }
}

class _Courbe extends StatelessWidget {
  const _Courbe({required this.points, required this.metric, required this.unite});

  final List<SessionPoint> points;
  final StatMetric metric;
  final UnitePoids unite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t0 = points.first.date;
    double x(DateTime d) => d.difference(t0).inHours / 24;
    final spots = [for (final p in points) FlSpot(x(p.date), p.valeur(metric))];
    final ys = spots.map((s) => s.y);
    var minY = ys.reduce(math.min);
    var maxY = ys.reduce(math.max);
    final pad = (maxY - minY) * 0.15;
    minY = math.max(0, minY - (pad == 0 ? maxY * 0.1 : pad));
    maxY = maxY + (pad == 0 ? math.max(1, maxY * 0.1) : pad);
    // Un seul point : au milieu du cadre, avec sa seule date.
    final seul = spots.length == 1;
    final minX = seul ? -1.0 : 0.0;
    final maxX = seul ? 1.0 : math.max(1.0, spots.last.x);
    final fin = metric.estPoids && (maxY - minY) / 4 < 1;
    final trait = c.text;
    final axe = TextStyle(fontFamily: AppTokens.fontUi, fontSize: 11.5, color: c.text2, fontFeatures: AppTokens.tabular);

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        // Pas de découpe : le premier et le dernier point restent ronds.
        clipData: const FlClipData.none(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: c.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: (maxY - minY) / 4,
              getTitlesWidget: (v, meta) {
                if (v == meta.max || v == meta.min) return const SizedBox.shrink();
                return SideTitleWidget(meta: meta, child: Text(ExFmt.axe(metric, v, unite, fin: fin), style: axe));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: seul ? 1 : math.max(1, maxX / 3),
              getTitlesWidget: (v, meta) => seul && v != 0
                  ? const SizedBox.shrink()
                  : SideTitleWidget(
                      meta: meta,
                      child: Text(Fmt.jourMois(t0.add(Duration(hours: (v * 24).round()))), style: axe),
                    ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => c.surface3,
            tooltipBorderRadius: AppTokens.radius12,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${ExFmt.metric(metric, s.y, unite)}\n',
                  TextStyle(fontFamily: AppTokens.fontUi, fontWeight: FontWeight.w800, color: c.text, fontSize: 13),
                  children: [
                    TextSpan(
                      text: Fmt.jourMois(points[s.spotIndex].date),
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontWeight: FontWeight.w500, color: c.text2, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: trait,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: spots.length <= 40,
              getDotPainter: (s, p, bar, i) => FlDotCirclePainter(radius: 3, color: trait, strokeWidth: 2, strokeColor: c.surface),
            ),
          ),
        ],
      ),
    );
  }
}
