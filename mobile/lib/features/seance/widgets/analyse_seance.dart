import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/bibliotheque/widgets/choix_exercice.dart' show RondMuscle;
import '../../progres/logic/bilan_mois.dart' show AxeToile, BilanMois;
import '../../progres/ui/bilan/toile.dart';
import 'habillage.dart';

/// Une zone d'entraînement : une fourchette de répétitions et ce qu'elle
/// travaille surtout.
enum ZoneReps {
  forceMax('Force maximale', 1, 3, Color(0xFF3D6BFF)),
  force('Force', 4, 6, Color(0xFF6C5CFF)),
  hypertrophie('Hypertrophie', 7, 12, Color(0xFF9B59FF)),
  forceEndurance('Force-endurance', 13, 20, Color(0xFFF472B6)),
  endurance('Endurance', 21, 1000, Color(0xFFFF453A));

  const ZoneReps(this.label, this.min, this.max, this.couleur);
  final String label;
  final int min;
  final int max;
  final Color couleur;

  /// « 1 à 3 rép. », « 21 rép. et plus ».
  String get fourchette => max >= 1000 ? '$min rép. et plus' : '$min à $max rép.';

  static ZoneReps? de(int reps) {
    for (final z in values) {
      if (reps >= z.min && reps <= z.max) return z;
    }
    return null;
  }
}

/// Une série faite et comptée, avec son exercice.
typedef SerieFaite = ({SessionExercise se, int rangExercice, int rang, WorkoutSet set});

/// Les chiffres de l'analyse d'une séance.
class ChiffresAnalyse {
  ChiffresAnalyse(this.session, Exercise? Function(String id) lookup)
      : series = [
          for (final (i, e) in session.exercices.indexed)
            for (final (j, x) in e.series.indexed)
              if (x.fait && x.type.counts) (se: e, rangExercice: i, rang: j, set: x),
        ],
        seriesParMuscle = Strength.setsParMuscle([session], lookup),
        volumeParMuscle = Strength.volumeParMuscle([session], lookup);

  final WorkoutSession session;
  final List<SerieFaite> series;
  final Map<Muscle, double> seriesParMuscle;
  final Map<Muscle, double> volumeParMuscle;

  /// Nombre de séries par nombre de répétitions.
  late final Map<int, int> parReps = () {
    final out = <int, int>{};
    for (final s in series) {
      final r = s.set.reps ?? 0;
      if (r > 0) out[r] = (out[r] ?? 0) + 1;
    }
    return out;
  }();

  /// Nombre de séries dans chaque zone.
  late final Map<ZoneReps, int> parZone = () {
    final out = {for (final z in ZoneReps.values) z: 0};
    for (final e in parReps.entries) {
      final z = ZoneReps.de(e.key);
      if (z != null) out[z] = out[z]! + e.value;
    }
    return out;
  }();

  int get seriesAvecReps => parReps.values.fold(0, (a, b) => a + b);

  /// Temps passé sur chaque exercice, dans l'ordre de la séance : de la
  /// série validée juste avant (ou du début de la séance) à sa dernière
  /// série. Vide si les heures des séries ne sont pas connues.
  late final List<(SessionExercise, Duration)> tempsParExercice = () {
    final datees = [for (final s in series) if (s.set.faitLe != null) s]..sort((a, b) => a.set.faitLe!.compareTo(b.set.faitLe!));
    if (datees.isEmpty || datees.length * 2 < series.length) return const <(SessionExercise, Duration)>[];
    final temps = <String, Duration>{};
    var avant = session.debut;
    for (final s in datees) {
      final d = s.set.faitLe!.difference(avant);
      // Une pause de plus de vingt minutes n'est pas du temps d'exercice.
      if (!d.isNegative && d < const Duration(minutes: 20)) temps[s.se.id] = (temps[s.se.id] ?? Duration.zero) + d;
      avant = s.set.faitLe!;
    }
    return [
      for (final e in session.exercices)
        if ((temps[e.id] ?? Duration.zero) > Duration.zero) (e, temps[e.id]!),
    ];
  }();
}

TextStyle _t(double taille, FontWeight poids, Color couleur, {double hauteur = 1.35}) =>
    TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(taille), fontWeight: poids, color: couleur, height: hauteur, fontFeatures: AppTokens.tabular);

/// Couleurs des exercices dans le graphique série par série.
const _palette = [Color(0xFF2456D6), Color(0xFF079DB8), Color(0xFF14A38B), Color(0xFF1FAB55), Color(0xFFC79A0A), Color(0xFFD9641E), Color(0xFFC0407A), Color(0xFF8B55D6)];

/// L'analyse d'une séance, à la suite de son bilan : zones d'entraînement,
/// toile des muscles, volume série par série, temps par exercice et
/// répartition par muscle.
class AnalyseSeance extends StatelessWidget {
  const AnalyseSeance({super.key, required this.session, required this.exos, required this.unite});
  final WorkoutSession session;
  final ExerciseRepo exos;
  final UnitePoids unite;

  @override
  Widget build(BuildContext context) {
    final a = ChiffresAnalyse(session, exos.byId);
    if (a.series.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    Widget carte(Widget child) => Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: k(8)),
          padding: EdgeInsets.all(k(14)),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(14))),
          child: child,
        );
    final muscles = a.seriesParMuscle.entries.where((e) => e.value > 0).toList()..sort((x, y) => y.value.compareTo(x.value));
    final maxAxe = [for (final m in BilanMois.axes) _axe(a.seriesParMuscle, m)].fold(0.0, math.max);
    final maxTemps = a.tempsParExercice.fold(Duration.zero, (m, e) => e.$2 > m ? e.$2 : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.seriesAvecReps > 0) ...[
          const Surtitre('Zones d’entraînement'),
          carte(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final z in ZoneReps.values)
                  _LigneZone(zone: z, part: a.parZone[z]! / a.seriesAvecReps),
                SizedBox(height: k(6)),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    borderRadius: AppTokens.radius8,
                    onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => RepartitionSeriesPage(chiffres: a))),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: k(4), vertical: k(6)),
                      child: Text('Voir le détail', style: _t(12.5, FontWeight.w700, c.text)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: k(18)),
        ],
        if (maxAxe > 0) ...[
          const Surtitre('Aperçu des muscles'),
          carte(
            Column(
              children: [
                Center(
                  child: ToileMuscles(
                    echelle: 1.05,
                    axes: <AxeToile>[
                      for (final m in BilanMois.axes) (muscle: m, mois: _axe(a.seriesParMuscle, m) / maxAxe, avant: 0),
                    ],
                  ),
                ),
                SizedBox(height: k(8)),
                Text(
                  'Plus la pointe est loin du centre, plus le muscle a fait de séries (${_series(maxAxe)} au plus). '
                  'Un muscle principal compte pour 1 série, un muscle secondaire pour 0,5.',
                  style: _t(11.5, FontWeight.w400, c.text2, hauteur: 1.4),
                ),
              ],
            ),
          ),
          SizedBox(height: k(18)),
        ],
        const Surtitre('Volume série par série'),
        carte(_VolumeSeries(chiffres: a, exos: exos, unite: unite)),
        if (a.tempsParExercice.isNotEmpty) ...[
          SizedBox(height: k(18)),
          const Surtitre('Temps par exercice'),
          carte(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (e, d)) in a.tempsParExercice.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : k(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(exos.nameOf(e.exerciseId), maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(12.5, FontWeight.w600, c.text))),
                            SizedBox(width: k(10)),
                            Text(Fmt.duree(d), style: _t(12.5, FontWeight.w700, c.text)),
                          ],
                        ),
                        SizedBox(height: k(5)),
                        _Barre(part: maxTemps.inSeconds == 0 ? 0 : d.inSeconds / maxTemps.inSeconds, couleur: _palette[session.exercices.indexOf(e) % _palette.length]),
                      ],
                    ),
                  ),
                SizedBox(height: k(10)),
                Text('Repos compris, de la série d’avant à la dernière série de l’exercice.', style: _t(11.5, FontWeight.w400, c.text2, hauteur: 1.4)),
              ],
            ),
          ),
        ],
        if (muscles.isNotEmpty) ...[
          SizedBox(height: k(18)),
          const Surtitre('Répartition musculaire'),
          carte(
            Column(
              children: [
                for (final (i, e) in muscles.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : k(10)),
                    child: Row(
                      children: [
                        RondMuscle.de(e.key, taille: k(42)),
                        SizedBox(width: k(12)),
                        Expanded(child: Text(e.key.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(13, FontWeight.w600, c.text))),
                        SizedBox(width: k(10)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${_series(e.value)} ${e.value >= 2 ? 'séries' : 'série'}', style: _t(12.5, FontWeight.w700, c.text)),
                            if ((a.volumeParMuscle[e.key] ?? 0) > 0) Text(Fmt.volume(a.volumeParMuscle[e.key]!, unite), style: _t(11.5, FontWeight.w400, c.text2)),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Séries d'un axe de la toile : le faisceau le plus travaillé pour les épaules.
  static double _axe(Map<Muscle, double> s, Muscle m) {
    if (m != Muscle.deltoidesLateraux) return s[m] ?? 0;
    return [Muscle.deltoidesAnterieurs, Muscle.deltoidesLateraux, Muscle.deltoidesPosterieurs].map((x) => s[x] ?? 0).fold(0.0, math.max);
  }

  /// « 3 », « 4,5 ».
  static String _series(double n) => Fmt.n(n, decimals: n == n.roundToDouble() ? 0 : 1);
}

/// Barre horizontale pleine sur une piste grise.
class _Barre extends StatelessWidget {
  const _Barre({required this.part, required this.couleur});
  final double part;
  final Color couleur;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(k(4)),
        child: Container(
          height: k(8),
          color: context.colors.surface3,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: part.clamp(0.0, 1.0), child: Container(color: couleur)),
        ),
      );
}

/// Une zone : son nom, sa fourchette, sa barre et sa part des séries.
class _LigneZone extends StatelessWidget {
  const _LigneZone({required this.zone, required this.part});
  final ZoneReps zone;
  final double part;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: k(9)),
      child: Row(
        children: [
          SizedBox(
            width: k(112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(12.5, FontWeight.w600, c.text)),
                Text(zone.fourchette, maxLines: 1, style: _t(10.5, FontWeight.w400, c.text2)),
              ],
            ),
          ),
          SizedBox(width: k(8)),
          Expanded(child: _Barre(part: part, couleur: zone.couleur)),
          SizedBox(width: k(38), child: Text('${(part * 100).round()} %', textAlign: TextAlign.right, style: _t(12.5, FontWeight.w700, c.text))),
        ],
      ),
    );
  }
}

/// Une barre par série, dans l'ordre de la séance, une couleur par exercice.
/// Toucher une barre dit de quelle série il s'agit.
class _VolumeSeries extends StatefulWidget {
  const _VolumeSeries({required this.chiffres, required this.exos, required this.unite});
  final ChiffresAnalyse chiffres;
  final ExerciseRepo exos;
  final UnitePoids unite;

  @override
  State<_VolumeSeries> createState() => _VolumeSeriesState();
}

class _VolumeSeriesState extends State<_VolumeSeries> {
  int? _choisie;

  /// Hauteur d'une série : son volume, ou ses répétitions sans charge.
  static double _valeur(WorkoutSet x) {
    final v = (x.poids ?? 0) * (x.reps ?? 0);
    return v > 0 ? v : (x.reps ?? 0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final series = widget.chiffres.series;
    // Les séries sans charge ont leur propre échelle : des répétitions ne se comparent pas à des kilos.
    final maxCharge = series.where((s) => (s.set.poids ?? 0) > 0).fold(0.0, (m, s) => math.max(m, _valeur(s.set)));
    final maxSans = series.where((s) => (s.set.poids ?? 0) <= 0).fold(0.0, (m, s) => math.max(m, _valeur(s.set)));
    final i = _choisie;
    final s = i == null ? null : series[i];
    final x = s?.set;
    final texte = s == null
        ? 'Touche une barre pour voir la série.'
        : '${widget.exos.nameOf(s.se.exerciseId)} · série ${s.rang + 1} · '
            '${(x!.poids ?? 0) > 0 ? '${Fmt.poids(x.poids, widget.unite)} × ${x.reps ?? 0}' : Fmt.pluriel(x.reps ?? 0, 'répétition')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: k(110),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (j, e) in series.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Série ${j + 1}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _choisie = _choisie == j ? null : j),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: () {
                            final max = (e.set.poids ?? 0) > 0 ? maxCharge : maxSans;
                            return max <= 0 ? 0.04 : (_valeur(e.set) / max).clamp(0.04, 1.0);
                          }(),
                          widthFactor: series.length > 30 ? 0.86 : 0.8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _palette[e.rangExercice % _palette.length].withValues(alpha: _choisie == null || _choisie == j ? 1 : 0.35),
                              borderRadius: BorderRadius.circular(k(2.5)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: k(10)),
        Text(texte, maxLines: 2, overflow: TextOverflow.ellipsis, style: _t(12, s == null ? FontWeight.w400 : FontWeight.w700, s == null ? c.text2 : c.text, hauteur: 1.4)),
        SizedBox(height: k(2)),
        Text('Une barre par série, dans l’ordre de la séance : sa hauteur est la charge multipliée par les répétitions. Une couleur par exercice.',
            style: _t(11.5, FontWeight.w400, c.text2, hauteur: 1.4)),
      ],
    );
  }
}

/// « Répartition des séries » : combien de séries à chaque nombre de
/// répétitions, ce que travaille chaque zone, et des repères par objectif.
class RepartitionSeriesPage extends StatelessWidget {
  const RepartitionSeriesPage({super.key, required this.chiffres});
  final ChiffresAnalyse chiffres;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parReps = chiffres.parReps;
    // Une ligne par nombre de répétitions jusqu'à 12, puis une par zone.
    final lignes = <(String, int, ZoneReps)>[
      for (var r = 1; r <= 12; r++) ('$r', parReps[r] ?? 0, ZoneReps.de(r)!),
      ('13 à 20', chiffres.parZone[ZoneReps.forceEndurance]!, ZoneReps.forceEndurance),
      ('21 et +', chiffres.parZone[ZoneReps.endurance]!, ZoneReps.endurance),
    ];
    final max = lignes.fold(0, (m, l) => math.max(m, l.$2));
    Widget titre(String t) => Padding(
          padding: EdgeInsets.only(top: k(22), bottom: k(8)),
          child: Text(t, style: _t(17, FontWeight.w700, c.text, hauteur: 1.3)),
        );
    Widget texte(String t) => Text(t, style: _t(13, FontWeight.w400, c.text2, hauteur: 1.45));
    return SubPageScaffold(
      title: 'Répartition des séries',
      body: ListView(
        padding: EdgeInsets.fromLTRB(margeSeance, k(4), margeSeance, k(32)),
        children: [
          titre('Répartition des répétitions'),
          Row(
            children: [
              SizedBox(width: k(70), child: Text('Répétitions', style: _t(11.5, FontWeight.w400, c.text2))),
              const Spacer(),
              Text('Séries', style: _t(11.5, FontWeight.w400, c.text2)),
            ],
          ),
          SizedBox(height: k(6)),
          for (final (label, n, zone) in lignes)
            Padding(
              padding: EdgeInsets.only(bottom: k(7)),
              child: Row(
                children: [
                  Container(width: k(3.5), height: k(18), decoration: BoxDecoration(color: zone.couleur, borderRadius: BorderRadius.circular(k(2)))),
                  SizedBox(width: k(8)),
                  SizedBox(width: k(54), child: Text(label, style: _t(12.5, FontWeight.w600, c.text))),
                  Expanded(child: _Barre(part: max == 0 ? 0 : n / max, couleur: zone.couleur)),
                  SizedBox(width: k(30), child: Text('$n', textAlign: TextAlign.right, style: _t(12.5, FontWeight.w700, c.text))),
                ],
              ),
            ),
          titre('Zones d’entraînement'),
          texte('Chaque zone est une fourchette de répétitions. Ce sont des repères généraux : en pratique, les zones se chevauchent.'),
          SizedBox(height: k(6)),
          for (final z in ZoneReps.values)
            Padding(
              padding: EdgeInsets.only(top: k(10)),
              child: Row(
                children: [
                  Container(width: k(4), height: k(34), decoration: BoxDecoration(color: z.couleur, borderRadius: BorderRadius.circular(k(2)))),
                  SizedBox(width: k(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(z.label, style: _t(13.5, FontWeight.w700, c.text)),
                        Text(z.fourchette, style: _t(12, FontWeight.w400, c.text2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          titre('Repères par objectif'),
          texte('Ces fourchettes sont des repères, pas des règles strictes. On gagne en force et en muscle sur des plages de répétitions variées, à condition de s’entraîner sérieusement et régulièrement.'),
          SizedBox(height: k(4)),
          for (final (objectif, conseil) in const [
            ('Développer la force', 'Privilégier 1 à 6 répétitions avec des charges lourdes.'),
            ('Prendre du muscle', 'Mélanger de 4 à 20 répétitions, en poussant près de l’échec.'),
            ('Forme générale', 'Répartir les séries sur toutes les zones.'),
            ('Ménager les articulations', 'Privilégier 13 répétitions et plus, avec des charges plus légères.'),
          ])
            Container(
              padding: EdgeInsets.symmetric(vertical: k(11)),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.surface3))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: k(112), child: Text(objectif, style: _t(13, FontWeight.w700, c.text))),
                  SizedBox(width: k(10)),
                  Expanded(child: texte(conseil)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
