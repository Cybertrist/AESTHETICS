import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../../core/ui/body/body_map.dart';
import '../logic/progres_stats.dart';
import 'communs.dart';

/// Nombre court pour les axes : « 12,5 k ».
String nombreCourt(double v) {
  if (v.abs() >= 1000000) return '${Fmt.n(v / 1000000)}M';
  if (v.abs() >= 1000) return '${Fmt.n(v / 1000, decimals: v.abs() >= 10000 ? 0 : 1)}k';
  return Fmt.n(v, decimals: v.abs() < 10 ? 1 : 0);
}

/// Valeur d'un indicateur, mise en forme.
String formatIndicateur(Indicateur i, double v, UnitePoids u) => switch (i) {
      Indicateur.seances => Fmt.pluriel(v.round(), 'séance'),
      Indicateur.volume => Fmt.volume(v, u),
      Indicateur.duree => Fmt.duree(Duration(minutes: v.round())),
      Indicateur.series => Fmt.pluriel(v.round(), 'série'),
    };

String formatIndicateurExercice(IndicateurExercice i, double v, UnitePoids u) => switch (i) {
      IndicateurExercice.unRm || IndicateurExercice.poidsMax => Fmt.poids(v, u),
      IndicateurExercice.volume => Fmt.volume(v, u),
      IndicateurExercice.reps => Fmt.pluriel(v.round(), 'rép.', 'rép.'),
    };

/// Petit texte d'axe.
TextStyle _axe(BuildContext context) => TextStyle(
      fontFamily: AppTokens.fontUi,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: context.colors.text2,
      fontFeatures: AppTokens.tabular,
    );

/// Graphique en barres arrondies, façon SmartBudget : barres pleines de
/// [color], la barre mise en avant plus claire, bande conseillée facultative.
class BarresProgres extends StatelessWidget {
  const BarresProgres({
    super.key,
    required this.values,
    required this.labels,
    required this.format,
    this.color,
    this.height = 180,
    this.highlight,
    this.bande,
    this.moyenne,
    this.onTap,
    this.maxLabels = 6,
  });

  final List<double> values;
  final List<String> labels;
  final String Function(double) format;
  final Color? color;
  final double height;

  /// Indice de la barre mise en avant (la période en cours).
  final int? highlight;

  /// Zone conseillée (10 à 20 séries), en voile.
  final (double, double)? bande;

  /// Ligne pointillée de la moyenne.
  final double? moyenne;
  final ValueChanged<int>? onTap;
  final int maxLabels;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = color ?? c.accent;
    final n = values.length;
    if (n == 0) return SizedBox(height: height);
    var maxV = values.fold<double>(0, math.max);
    if (bande != null) maxV = math.max(maxV, bande!.$2 * 1.1);
    if (maxV <= 0) maxV = 1;
    final pas = (n / maxLabels).ceil().clamp(1, n);
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, box) {
        final largeur = ((box.maxWidth - 40) / n * 0.62).clamp(3.0, 22.0);
        return BarChart(
          BarChartData(
            maxY: maxV * 1.12,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxV / 3,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppTokens.line, strokeWidth: 1),
            ),
            rangeAnnotations: bande == null
                ? const RangeAnnotations()
                : RangeAnnotations(horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(y1: bande!.$1, y2: bande!.$2, color: col.withValues(alpha: 0.07)),
                  ]),
            extraLinesData: moyenne == null || moyenne! <= 0
                ? const ExtraLinesData()
                : ExtraLinesData(horizontalLines: [
                    HorizontalLine(y: moyenne!, color: c.text3.withValues(alpha: 0.7), strokeWidth: 1, dashArray: [4, 4]),
                  ]),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: maxV / 3,
                  getTitlesWidget: (v, meta) {
                    if (v == meta.max) return const SizedBox.shrink();
                    return SideTitleWidget(meta: meta, space: 6, child: Text(nombreCourt(v), style: _axe(context)));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= n) return const SizedBox.shrink();
                    // Toujours la dernière, puis une sur [pas] en partant de la fin.
                    if ((n - 1 - i) % pas != 0) return const SizedBox.shrink();
                    return SideTitleWidget(meta: meta, space: 6, child: Text(labels[i], style: _axe(context)));
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchCallback: onTap == null
                  ? null
                  : (event, resp) {
                      if (event is FlTapUpEvent && resp?.spot != null) onTap!(resp!.spot!.touchedBarGroupIndex);
                    },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => c.surface3,
                tooltipBorderRadius: AppTokens.radius12,
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                  '${labels[group.x]}\n',
                  TextStyle(fontFamily: AppTokens.fontUi, fontSize: 11, color: c.text3, fontWeight: FontWeight.w600),
                  children: [
                    TextSpan(
                      text: format(values[group.x]),
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13, color: c.text, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < n; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: values[i] <= 0 ? 0 : math.max(values[i], maxV * 0.012),
                    width: largeur,
                    color: highlight == null || highlight == i ? col : col.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(math.min(largeur / 2, 6))),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxV * 1.12, color: AppTokens.veil),
                  ),
                ]),
            ],
          ),
          duration: AppTokens.normal,
        );
      }),
    );
  }
}

/// Courbe dans le temps (dates en abscisse), remplissage en dégradé. Blanche
/// par défaut : ni le bleu du minuteur ni le corail des muscles.
class CourbeProgres extends StatelessWidget {
  const CourbeProgres({
    super.key,
    required this.points,
    required this.format,
    this.color,
    this.height = 200,
    this.onTap,
  });

  final List<(DateTime, double)> points;
  final String Function(double) format;
  final Color? color;
  final double height;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = color ?? c.text;
    if (points.isEmpty) return SizedBox(height: height);
    final t0 = points.first.$1;
    double x(DateTime d) => d.difference(t0).inHours / 24;
    final spots = [for (final p in points) FlSpot(x(p.$1), p.$2)];
    var minY = points.map((p) => p.$2).reduce(math.min);
    var maxY = points.map((p) => p.$2).reduce(math.max);
    if (maxY - minY < 1) {
      minY -= 1;
      maxY += 1;
    }
    final marge = (maxY - minY) * 0.15;
    minY = math.max(0, minY - marge);
    maxY = maxY + marge;
    final maxX = math.max(1.0, spots.last.x);
    final pasX = maxX / 4;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 3,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppTokens.line, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: (maxY - minY) / 3,
                getTitlesWidget: (v, meta) {
                  if (v == meta.max || v == meta.min) return const SizedBox.shrink();
                  return SideTitleWidget(meta: meta, space: 6, child: Text(nombreCourt(v), style: _axe(context)));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: pasX,
                getTitlesWidget: (v, meta) {
                  final d = t0.add(Duration(hours: (v * 24).round()));
                  final txt = maxX > 330 ? '${ProgresStats.moisCourt(d)} ${d.year % 100}' : '${d.day} ${ProgresStats.moisCourt(d)}';
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                    child: Text(txt, style: _axe(context)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchCallback: onTap == null
                ? null
                : (event, resp) {
                    final s = resp?.lineBarSpots;
                    if (event is FlTapUpEvent && s != null && s.isNotEmpty) onTap!(s.first.spotIndex);
                  },
            getTouchedSpotIndicator: (bar, idx) => [
              for (final _ in idx)
                TouchedSpotIndicatorData(
                  FlLine(color: col.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [3, 3]),
                  FlDotData(getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 5, color: col, strokeWidth: 2, strokeColor: c.bg)),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surface3,
              tooltipBorderRadius: AppTokens.radius12,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: 160,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${Fmt.jourMois(points[s.spotIndex].$1)}\n',
                    TextStyle(fontFamily: AppTokens.fontUi, fontSize: 11, color: c.text3, fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: format(s.y),
                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13, color: c.text, fontWeight: FontWeight.w800),
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
              color: col,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: spots.length <= 24,
                getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 2.8, color: col, strokeWidth: 0, strokeColor: col),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [col.withValues(alpha: 0.22), col.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
        duration: AppTokens.normal,
      ),
    );
  }
}

/// Barre horizontale d'un muscle : séries faites, repères 10 et 20.
class BarreMuscle extends StatelessWidget {
  const BarreMuscle({super.key, required this.muscle, required this.series, this.onTap, this.comparaison});

  final Muscle muscle;
  final double series;

  /// Deuxième valeur, en gris, sous la première (comparaison de périodes).
  final double? comparaison;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final statut = ProgresStats.statut(series);
    final echelle = math.max(ProgresStats.seriesMax * 1.25, math.max(series, comparaison ?? 0));
    final col = switch (statut) {
      StatutMuscle.neglige => c.text3,
      StatutMuscle.cible => c.muscleBar,
      StatutMuscle.auDessus => c.warning,
    };
    Widget barre(double v, Color couleur, double h) => LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          return SizedBox(
            height: h,
            child: Stack(
              children: [
                Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: AppTokens.track, borderRadius: AppTokens.radiusPill))),
                // Zone conseillée de 10 à 20 séries.
                Positioned(
                  left: w * ProgresStats.seriesMin / echelle,
                  width: w * (ProgresStats.seriesMax - ProgresStats.seriesMin) / echelle,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(decoration: BoxDecoration(color: c.text.withValues(alpha: 0.08))),
                ),
                AnimatedContainer(
                  duration: AppTokens.normal,
                  width: v <= 0 ? 0 : math.max(h, w * (v / echelle).clamp(0.0, 1.0)),
                  decoration: BoxDecoration(color: couleur, borderRadius: AppTokens.radiusPill),
                ),
              ],
            ),
          );
        });
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.radius12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(muscle.label, style: AppType.rowTitle(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(
                  comparaison == null ? Fmt.n(series) : '${Fmt.n(series)}  /  ${Fmt.n(comparaison)}',
                  style: AppType.rowValue(color: comparaison == null ? col : c.text),
                ),
                if (comparaison == null) Text('  séries', style: AppType.rowSubtitle()),
                if (onTap != null) const Padding(padding: EdgeInsets.only(left: 4), child: Chevron(taille: 15)),
              ],
            ),
            const SizedBox(height: 7),
            barre(series, comparaison == null ? col : c.accent, 8),
            if (comparaison != null) ...[const SizedBox(height: 4), barre(comparaison!, c.text3.withValues(alpha: 0.6), 6)],
          ],
        ),
      ),
    );
  }
}

/// Légende : zone conseillée.
class LegendeCible extends StatelessWidget {
  const LegendeCible({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget pastille(Color col, String txt) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: col, borderRadius: AppTokens.radiusPill)),
            const SizedBox(width: 6),
            Text(txt, style: AppType.rowSubtitle()),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        pastille(c.text3, 'Moins de 10'),
        pastille(c.muscleBar, '10 à 20 séries'),
        pastille(c.warning, 'Plus de 20'),
      ],
    );
  }
}

/// Garde commune : chargement du catalogue, puis erreur de calcul éventuelle.
class ProgresGarde extends StatefulWidget {
  const ProgresGarde({super.key, required this.builder, this.titre});

  final Widget Function(BuildContext context) builder;

  /// Titre de la sous-page pendant le chargement ou l'erreur (null = racine).
  final String? titre;

  @override
  State<ProgresGarde> createState() => _ProgresGardeState();
}

class _ProgresGardeState extends State<ProgresGarde> {
  var _essai = 0;

  @override
  Widget build(BuildContext context) {
    final ex = context.watch<ExerciseRepo>();
    Widget cadre(Widget body) => PageProgres(
          child: ListView(
            padding: EdgeInsets.only(bottom: basDePage(context)),
            children: [EnTetePage(titre: widget.titre ?? 'Progrès'), body],
          ),
        );
    if (!ex.loaded) {
      return cadre(const Padding(
        padding: EdgeInsets.fromLTRB(Cotes.marge, 8, Cotes.marge, 0),
        child: ChargementProgres(),
      ));
    }
    try {
      return KeyedSubtree(key: ValueKey(_essai), child: widget.builder(context));
    } catch (e) {
      return cadre(EtatVide(
        titre: 'Calcul impossible',
        message: 'Une donnée de ton historique n\'a pas pu être lue. Réessaie, ou vérifie la séance concernée.',
        action: 'Réessayer',
        onAction: () => setState(() => _essai++),
      ));
    }
  }
}

/// Squelette de chargement d'une page de statistiques.
class ChargementProgres extends StatelessWidget {
  const ChargementProgres({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(width: 220, height: 40, radius: 20),
        SizedBox(height: 20),
        Skeleton(width: 160, height: 44),
        SizedBox(height: 20),
        Row(children: [
          Expanded(child: Skeleton(height: 96, radius: 16)),
          SizedBox(width: 12),
          Expanded(child: Skeleton(height: 96, radius: 16)),
        ]),
        SizedBox(height: 12),
        Skeleton(height: 220, radius: 16),
        SizedBox(height: 12),
        SkeletonList(count: 3),
      ],
    );
  }
}

/// Deux colonnes sur le Fold ouvert, une seule sur l'écran étroit.
class DeuxColonnes extends StatelessWidget {
  const DeuxColonnes({super.key, required this.gauche, required this.droite, this.seuil = 720, this.espace = 12});

  final List<Widget> gauche;
  final List<Widget> droite;
  final double seuil;
  final double espace;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < seuil) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _espaces([...gauche, ...droite]));
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _espaces(gauche))),
          SizedBox(width: espace),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _espaces(droite))),
        ],
      );
    });
  }

  List<Widget> _espaces(List<Widget> l) => [
        for (var i = 0; i < l.length; i++) ...[if (i > 0) SizedBox(height: espace), l[i]],
      ];
}

/// Grille de tuiles qui passe de 2 à 4 colonnes selon la largeur.
class GrilleTuiles extends StatelessWidget {
  const GrilleTuiles({super.key, required this.children, this.largeurMin = 150, this.espace = 12});

  final List<Widget> children;
  final double largeurMin;
  final double espace;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = (box.maxWidth / largeurMin).floor().clamp(2, 4);
      final w = (box.maxWidth - espace * (cols - 1)) / cols;
      return Wrap(
        spacing: espace,
        runSpacing: espace,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

/// Variation affichée sous un chiffre : vrai si hausse.
({String texte, bool? positif}) delta(num actuel, num avant, {String Function(num)? absolu}) {
  final v = ProgresStats.variation(actuel, avant);
  if (v == null) return (texte: actuel == 0 ? 'stable' : 'nouveau', positif: actuel == 0 ? null : true);
  final pct = ProgresStats.pct(v);
  return (texte: absolu == null ? pct : '$pct (${absolu(actuel - avant)})', positif: v.abs() < 0.5 ? null : v > 0);
}

/// Nom d'un exercice, même disparu.
String nomExercice(BuildContext context, String id) => context.read<ExerciseRepo>().nameOf(id);

/// Vignette d'un exercice : la pose du personnage sur une tuile grise.
Widget iconeExercice(BuildContext context, String id, {double size = 48}) =>
    VignetteExercice(exercice: context.read<ExerciseRepo>().byId(id), taille: size, rayon: size * 0.26);

/// « 7,5 séries », « 1 série » (les séries secondaires comptent pour une demie).
String seriesTexte(double v) => '${Fmt.n(v)} ${v >= 2 ? 'séries' : 'série'}';

/// Face et dos côte à côte, à la plus grande hauteur qui tient dans la largeur.
class CorpsDouble extends StatelessWidget {
  const CorpsDouble({super.key, required this.intensities, this.hauteurMax = 260, this.onTap, this.labels = false});

  final Map<Muscle, double> intensities;
  final double hauteurMax;
  final ValueChanged<Muscle>? onTap;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final parVue = (box.maxWidth - 8) / 2;
      final h = math.min(hauteurMax, parVue / BodyMap.aspectRatio);
      return Center(child: BodyMapDual(intensities: intensities, height: h, onTap: onTap, labels: labels));
    });
  }
}
