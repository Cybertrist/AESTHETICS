import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/muscle.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import 'sante_calculs.dart';

/// Marges horizontales communes du module.
const santePad = EdgeInsets.symmetric(horizontal: AppTokens.gutter);

/// Deux colonnes sur le Fold ouvert, une seule fermé.
class SanteColonnes extends StatelessWidget {
  const SanteColonnes({super.key, required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: spacing), children[i]],
          ],
        );
      }
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += 2) {
        if (i > 0) rows.add(SizedBox(height: spacing));
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              SizedBox(width: spacing),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
            ],
          ),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}

/// Deux volets côte à côte sur grand écran (liste et détail), empilés sinon.
class SanteVolets extends StatelessWidget {
  const SanteVolets({super.key, required this.gauche, required this.droite, this.ratio = 0.5});

  final Widget gauche;
  final Widget droite;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 700) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [gauche, droite],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: (ratio * 100).round(), child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [gauche])),
          Expanded(flex: ((1 - ratio) * 100).round(), child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [droite])),
        ],
      );
    });
  }
}

/// Courbe datée (poids, tour de bras, sommeil) avec une seconde courbe
/// facultative (moyenne mobile) et une ligne d'objectif.
class SanteCourbe extends StatelessWidget {
  const SanteCourbe({
    super.key,
    required this.points,
    required this.debut,
    required this.fin,
    required this.color,
    required this.format,
    this.tendance,
    this.objectif,
    this.objectifLabel,
    this.height = 190,
    this.pointsVisibles = true,
  });

  final List<Point> points;
  final List<Point>? tendance;
  final DateTime debut;
  final DateTime fin;
  final Color color;
  final String Function(double v) format;
  final double? objectif;
  final String? objectifLabel;
  final double height;
  final bool pointsVisibles;

  double _x(DateTime d) => d.difference(debut).inMinutes / 1440;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text('Aucune valeur sur cette période', style: AppType.rowSubtitle())),
      );
    }
    final vals = [...points.map((p) => p.v), ...?tendance?.map((p) => p.v), ?objectif];
    var lo = vals.reduce(math.min);
    var hi = vals.reduce(math.max);
    final marge = math.max((hi - lo) * 0.15, hi.abs() * 0.01 + 0.5);
    lo -= marge;
    hi += marge;
    final maxX = math.max(1.0, _x(fin));
    final jours = maxX.round();
    final pas = jours <= 8 ? 1.0 : (jours <= 31 ? 7.0 : (jours <= 100 ? 30.0 : 91.0));
    final fmtAxe = jours <= 8 ? DateFormat('E', 'fr_FR') : (jours <= 100 ? DateFormat('d MMM', 'fr_FR') : DateFormat('MMM', 'fr_FR'));

    LineChartBarData serie(List<Point> pts, Color col, {bool principale = true}) => LineChartBarData(
          spots: [for (final p in pts) FlSpot(_x(p.date), p.v)],
          isCurved: true,
          curveSmoothness: 0.25,
          preventCurveOverShooting: true,
          color: col,
          barWidth: principale ? 2.6 : 2,
          isStrokeCapRound: true,
          dashArray: principale ? null : [5, 4],
          dotData: FlDotData(
            show: principale && pointsVisibles && pts.length <= 40,
            getDotPainter: (s, _, _, _) => FlDotCirclePainter(radius: 2.6, color: col, strokeWidth: 0),
          ),
          belowBarData: BarAreaData(show: false),
        );

    final principale = tendance == null ? serie(points, color) : serie(points, color.withValues(alpha: 0.45), principale: true);
    final bars = [
      principale,
      if (tendance != null) serie(tendance!, color, principale: false).copyWith(dashArray: null, barWidth: 3, belowBarData: BarAreaData(show: false)),
    ];

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: lo,
          maxY: hi,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: c.line, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: objectif == null
              ? const ExtraLinesData()
              : ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: objectif!,
                    color: c.accent.withValues(alpha: 0.7),
                    strokeWidth: 1.2,
                    dashArray: [4, 4],
                    label: HorizontalLineLabel(
                      show: objectifLabel != null,
                      alignment: Alignment.topRight,
                      labelResolver: (_) => objectifLabel ?? '',
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 11, fontWeight: FontWeight.w700, color: c.accent),
                    ),
                  ),
                ]),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (v, meta) {
                  if (v == meta.min || v == meta.max) return const SizedBox();
                  return SideTitleWidget(meta: meta, child: Text(format(v), style: AppType.rowSubtitle().copyWith(fontSize: 10.5)));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: pas,
                getTitlesWidget: (v, meta) {
                  if (v > maxX - pas * 0.5) return const SizedBox();
                  final d = debut.add(Duration(minutes: (v * 1440).round()));
                  return SideTitleWidget(meta: meta, child: Text(fmtAxe.format(d), style: AppType.rowSubtitle().copyWith(fontSize: 10.5)));
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (bar, idx) => [
              for (final _ in idx)
                TouchedSpotIndicatorData(
                  FlLine(color: c.text3, strokeWidth: 1),
                  FlDotData(getDotPainter: (s, _, _, _) => FlDotCirclePainter(radius: 4, color: color, strokeColor: c.bg, strokeWidth: 2)),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surface3,
              tooltipBorderRadius: AppTokens.radius12,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  s.barIndex == 0
                      ? LineTooltipItem(
                          '${format(s.y)}\n',
                          AppType.rowValue(color: c.text).copyWith(fontSize: 13),
                          children: [
                            TextSpan(
                              text: Fmt.jourMois(debut.add(Duration(minutes: (s.x * 1440).round()))),
                              style: AppType.rowSubtitle(),
                            ),
                          ],
                        )
                      : LineTooltipItem('Moyenne ${format(s.y)}', AppType.rowSubtitle(color: color)),
              ],
            ),
          ),
          lineBarsData: bars,
        ),
      ),
    );
  }
}

/// Barres par jour (sommeil, pas) avec un objectif en pointillé.
class SanteBarres extends StatelessWidget {
  const SanteBarres({
    super.key,
    required this.jours,
    required this.valeurs,
    required this.color,
    required this.format,
    this.objectif,
    this.height = 170,
    this.selection,
    this.onSelect,
  });

  final List<DateTime> jours;
  final List<double?> valeurs;
  final Color color;
  final String Function(double v) format;
  final double? objectif;
  final double height;
  final int? selection;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hi = math.max(objectif ?? 0, valeurs.whereType<double>().fold<double>(0, math.max)) * 1.15;
    final n = jours.length;
    final largeur = n <= 7 ? 18.0 : (n <= 14 ? 12.0 : (n <= 31 ? 6.0 : 3.0));
    final pasEtiquette = n <= 7 ? 1 : (n <= 14 ? 2 : (n <= 31 ? 7 : 30));
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: hi <= 0 ? 1 : hi,
          alignment: BarChartAlignment.spaceBetween,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: c.line, strokeWidth: 1)),
          extraLinesData: objectif == null
              ? const ExtraLinesData()
              : ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: objectif!, color: c.accent.withValues(alpha: 0.7), strokeWidth: 1.2, dashArray: [4, 4]),
                ]),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, meta) {
                  if (v == meta.max) return const SizedBox();
                  return SideTitleWidget(meta: meta, child: Text(format(v), style: AppType.rowSubtitle().copyWith(fontSize: 10.5)));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= n || (n - 1 - i) % pasEtiquette != 0) return const SizedBox();
                  final d = jours[i];
                  final txt = n <= 7 ? Dates.initiale(d) : Fmt.jourMois(d);
                  return SideTitleWidget(meta: meta, child: Text(txt, style: AppType.rowSubtitle().copyWith(fontSize: 10.5)));
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchCallback: (event, resp) {
              if (onSelect != null && event is FlTapUpEvent && resp?.spot != null) onSelect!(resp!.spot!.touchedBarGroupIndex);
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.surface3,
              tooltipBorderRadius: AppTokens.radius12,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (g, _, rod, _) => valeurs[g.x] == null
                  ? null
                  : BarTooltipItem(
                      '${format(rod.toY)}\n',
                      AppType.rowValue().copyWith(fontSize: 13),
                      children: [TextSpan(text: Fmt.jourMois(jours[g.x]), style: AppType.rowSubtitle())],
                    ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < n; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: valeurs[i] ?? 0,
                    width: largeur,
                    color: selection == null || selection == i ? color : color.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(largeur / 2.5),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: hi <= 0 ? 1 : hi, color: c.veil),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'une courbe : étiquette, chiffre du jour, sélecteur de période.
class CarteCourbe extends StatelessWidget {
  const CarteCourbe({
    super.key,
    required this.label,
    required this.periode,
    required this.onPeriode,
    required this.child,
    this.legende,
    this.periodes,
  });

  final String label;
  final Periode periode;
  final ValueChanged<Periode> onPeriode;
  final Widget child;
  final Widget? legende;
  final List<Periode>? periodes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: santePad,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedChips<Periode>(
            segments: [for (final p in periodes ?? Periode.values) (p, p.label)],
            value: periode,
            onChanged: onPeriode,
          ),
          const SizedBox(height: 18),
          child,
          if (legende != null) ...[const SizedBox(height: 12), legende!],
        ],
      ),
    );
  }
}

/// Pastille de légende : un trait coloré et un texte.
class Legende extends StatelessWidget {
  const Legende({super.key, required this.items});

  final List<(Color, String, bool)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final (col, txt, pointille) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: pointille ? 3 : 8,
                decoration: BoxDecoration(color: col, borderRadius: AppTokens.radiusPill),
              ),
              const SizedBox(width: 6),
              Text(txt, style: AppType.rowSubtitle()),
            ],
          ),
      ],
    );
  }
}

/// Choix de la qualité d'une nuit, de 1 à 5.
class QualitePicker extends StatelessWidget {
  const QualitePicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  static const icones = [
    Icons.sentiment_very_dissatisfied_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_satisfied_rounded,
    Icons.sentiment_very_satisfied_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 1; i <= 5; i++) ...[
              if (i > 1) const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: value == i,
                  label: SanteCalc.qualite(i),
                  child: Material(
                    color: value == i ? c.sleep.withValues(alpha: 0.16) : c.surface3,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTokens.radius14,
                      side: BorderSide(color: value == i ? c.sleep.withValues(alpha: 0.5) : Colors.transparent),
                    ),
                    child: InkWell(
                      customBorder: const RoundedRectangleBorder(borderRadius: AppTokens.radius14),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onChanged(value == i ? null : i);
                      },
                      child: SizedBox(
                        height: 54,
                        child: Icon(icones[i - 1], color: value == i ? c.sleep : c.text3, size: 26),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value == null ? 'Touchez pour noter la nuit' : SanteCalc.qualite(value),
          textAlign: TextAlign.center,
          style: AppType.rowSubtitle(color: value == null ? c.text3 : c.sleep),
        ),
      ],
    );
  }
}

/// Champ numérique libellé (virgule acceptée).
class ChampNombre extends StatelessWidget {
  const ChampNombre({
    super.key,
    required this.controller,
    required this.label,
    this.unite,
    this.hint,
    this.decimal = true,
    this.error,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? unite;
  final String? hint;
  final bool decimal;
  final String? error;
  final ValueChanged<String>? onChanged;

  static double? lire(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.').replaceAll(' ', '');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  static String ecrire(double? v, {int decimals = 1}) {
    if (v == null) return '';
    final f = v.toStringAsFixed(decimals);
    return (f.contains('.') ? f.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : f).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
      style: AppType.rowValue().copyWith(fontSize: 17),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, hintText: hint ?? '0', suffixText: unite, errorText: error),
    );
  }
}

/// Ligne de réglage qui ouvre un sélecteur (date, heure).
class LigneChoix extends StatelessWidget {
  const LigneChoix({super.key, required this.icon, required this.label, required this.value, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTileX(
      leading: IconHalo(icon: icon, color: color, size: 38),
      title: label,
      value: value,
      showChevron: true,
      onTap: onTap,
    );
  }
}

/// Petit chiffre avec son étiquette (dans une carte de synthèse).
class MiniChiffre extends StatelessWidget {
  const MiniChiffre({super.key, required this.label, required this.value, this.unit, this.color, this.caption});

  final String label;
  final String value;
  final String? unit;
  final Color? color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.overline(color: c.text3).copyWith(fontSize: 10.5)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppType.number(22, color: color)),
              if (unit != null) ...[const SizedBox(width: 3), Text(unit!, style: AppType.number(12, color: c.text2))],
            ],
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 3),
          Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle()),
        ],
      ],
    );
  }
}

/// Sélecteurs de date et d'heure, en français et au thème.
Future<DateTime?> choisirDate(BuildContext context, DateTime initial, {DateTime? first, DateTime? last}) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime(2000),
      lastDate: last ?? DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('fr', 'FR'),
      helpText: 'Choisir la date',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

Future<TimeOfDay?> choisirHeure(BuildContext context, TimeOfDay initial, {String titre = 'Choisir l\'heure'}) => showTimePicker(
      context: context,
      initialTime: initial,
      helpText: titre,
      cancelText: 'Annuler',
      confirmText: 'Valider',
      hourLabelText: 'Heure',
      minuteLabelText: 'Minute',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

/// Signe et valeur d'une variation (« +1,2 », « -0,4 »).
String signe(double v, {int decimals = 1}) => '${v > 0 ? '+' : (v < 0 ? '-' : '')}${Fmt.n(v.abs(), decimals: decimals)}';

/// Petites barres sans axe (aperçu des 7 dernières nuits, des pas).
class MiniBarres extends StatelessWidget {
  const MiniBarres({super.key, required this.valeurs, required this.color, this.height = 44, this.objectif, this.etiquettes});

  final List<double?> valeurs;
  final Color color;
  final double height;
  final double? objectif;
  final List<String>? etiquettes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hi = math.max(objectif ?? 0, valeurs.whereType<double>().fold<double>(0, math.max));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < valeurs.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: Container(
                    height: hi <= 0 || valeurs[i] == null ? 4 : math.max(4, height * valeurs[i]! / hi),
                    decoration: BoxDecoration(
                      color: valeurs[i] == null
                          ? c.veil2
                          : (objectif != null && valeurs[i]! < objectif! ? color.withValues(alpha: 0.45) : color),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (etiquettes != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < etiquettes!.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(child: Text(etiquettes![i], textAlign: TextAlign.center, style: AppType.rowSubtitle().copyWith(fontSize: 10.5))),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// En-tête d'une carte de synthèse : icône de domaine, titre, chevron.
class TeteCarte extends StatelessWidget {
  const TeteCarte({super.key, required this.icon, required this.color, required this.title, this.trailing});

  final IconData icon;
  final Color color;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        IconHalo(icon: icon, color: color, size: 34),
        const SizedBox(width: 12),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle())),
        ?trailing,
        Icon(Icons.chevron_right_rounded, color: c.text3, size: 20),
      ],
    );
  }
}

/// Bloc d'erreur avec un bouton pour réessayer.
class ErreurBloc extends StatelessWidget {
  const ErreurBloc({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return EmptyState(
      icon: Icons.error_outline_rounded,
      iconColor: c.error,
      title: 'Un souci est survenu',
      message: message,
      actionLabel: onRetry == null ? null : 'Réessayer',
      onAction: onRetry,
    );
  }
}

/// Contenu défilant et barre d'action fixée dessous (bouton Enregistrer).
/// Remplace `bottomBar` de `SubPageScaffold` tant que celle-ci prend toute
/// la hauteur (demande à la fondation dans COORDINATION.md).
class AvecBarre extends StatelessWidget {
  const AvecBarre({super.key, required this.child, required this.barre});
  final Widget child;
  final Widget barre;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Expanded(child: child),
        DecoratedBox(
          decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
          child: Padding(padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 10, AppTokens.gutter, 10), child: barre),
        ),
      ],
    );
  }
}

/// Personnage face et dos qui tient toujours dans la largeur disponible.
class CorpsDouble extends StatelessWidget {
  const CorpsDouble({super.key, required this.intensities, required this.hauteurMax, this.selected = const {}, this.onTap, this.labels = false, this.spacing = 8});

  final Map<Muscle, double> intensities;
  final double hauteurMax;
  final Set<Muscle> selected;
  final ValueChanged<Muscle>? onTap;
  final bool labels;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final largeur = box.maxWidth.isFinite ? box.maxWidth : hauteurMax;
      final h = math.min(hauteurMax, (largeur - spacing) / 2 / BodyMap.aspectRatio);
      return BodyMapDual(intensities: intensities, selected: selected, onTap: onTap, labels: labels, spacing: spacing, height: h);
    });
  }
}
