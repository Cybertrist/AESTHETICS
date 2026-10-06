import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../logic/progres_stats.dart';
import 'communs.dart';
import 'progres_widgets.dart';

enum _Mesure { series, volume }

enum _Tri { series, alpha, region }

/// Volume de la semaine par muscle : personnage, barres et muscles oubliés.
class MusclesPage extends StatefulWidget {
  const MusclesPage({super.key});

  @override
  State<MusclesPage> createState() => _MusclesPageState();
}

class _MusclesPageState extends State<MusclesPage> {
  var _semaine = Dates.debutSemaine(DateTime.now());
  var _mesure = _Mesure.series;
  var _tri = _Tri.series;

  @override
  Widget build(BuildContext context) => ProgresGarde(titre: 'Volume par muscle', builder: _contenu);

  Future<void> _trier() async {
    final t = await choisirDansPanneau<_Tri>(
      context,
      titre: 'Trier les muscles',
      choisi: _tri,
      options: const [(_Tri.series, 'Du plus au moins travaillé'), (_Tri.alpha, 'Par ordre alphabétique'), (_Tri.region, 'Par région du corps')],
    );
    if (t != null && mounted) setState(() => _tri = t);
  }

  Widget _contenu(BuildContext context) {
    final repo = context.watch<SessionRepo>();
    final ex = context.watch<ExerciseRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final courante = Dates.debutSemaine(DateTime.now());
    final i = Intervalle(_semaine, _semaine.add(const Duration(days: 7)));
    final seances = ProgresStats.dans(repo.sessions, i);
    final series = ProgresStats.seriesParMuscle(seances, ex.byId);
    final volumes = Strength.volumeParMuscle(seances, ex.byId);
    final premiere = repo.sessions.isEmpty ? courante : Dates.debutSemaine(repo.sessions.last.debut);

    final muscles = [...Muscle.values];
    switch (_tri) {
      case _Tri.series:
        muscles.sort((a, b) => (series[b] ?? 0).compareTo(series[a] ?? 0));
      case _Tri.alpha:
        muscles.sort((a, b) => a.label.compareTo(b.label));
      case _Tri.region:
        muscles.sort((a, b) => a.region.index != b.region.index ? a.region.index.compareTo(b.region.index) : a.index.compareTo(b.index));
    }
    final negliges = [for (final m in ProgresStats.musclesSuivis) if ((series[m] ?? 0) < ProgresStats.seriesMin) m];
    final dansCible = ProgresStats.musclesSuivis.where((m) => ProgresStats.statut(series[m] ?? 0) == StatutMuscle.cible).length;
    final total = series.values.fold<double>(0, (a, b) => a + b);
    final maxVol = volumes.values.fold<double>(0, (a, b) => a > b ? a : b);
    final maxSeries = series.values.fold<double>(0, (a, b) => a > b ? a : b);
    final texte = ts(14, FontWeight.w400, c.text2, hauteur: 1.4);

    void ouvrir(Muscle m) => context.push('/progres/muscles/${m.name}');

    final personnage = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpsDouble(
            intensities: _mesure == _Mesure.series
                ? ProgresStats.intensites(series)
                : {for (final e in volumes.entries) if (maxVol > 0 && e.value > 0) e.key: (0.2 + 0.8 * e.value / maxVol).clamp(0.0, 1.0)},
            hauteurMax: 300,
            labels: true,
            onTap: ouvrir,
          ),
          const SizedBox(height: 10),
          Text('Touche un muscle pour voir son détail.', textAlign: TextAlign.center, style: texte),
        ],
      ),
    );

    final synthese = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GrandChiffre(
            etiquette: 'Séries effectives',
            valeur: Fmt.n(total),
            unite: total >= 2 ? 'séries' : 'série',
            legende: '${Fmt.pluriel(seances.length, 'séance')} · $dansCible muscles sur ${ProgresStats.musclesSuivis.length} dans la cible',
          ),
          const SizedBox(height: 14),
          SegmentedBar(parts: [
            (dansCible.toDouble(), c.accent),
            (negliges.length.toDouble(), c.text3),
            ((ProgresStats.musclesSuivis.length - dansCible - negliges.length).toDouble(), c.warning),
          ]),
          const SizedBox(height: 10),
          const LegendeCible(),
          const SizedBox(height: 10),
          Text('Un muscle compte une série quand il est travaillé en premier, une demie en second. Entre 10 et 20 séries par semaine, il progresse bien.', style: texte),
        ],
      ),
    );

    final oublis = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitreCarte('Muscles négligés', droite: Fmt.pluriel(negliges.length, 'muscle')),
          const SizedBox(height: 12),
          if (negliges.isEmpty)
            Text('Aucun oubli : chaque muscle a ses 10 séries.', style: texte)
          else
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (final m in negliges)
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => ouvrir(m),
                      // Zone d'appui plus haute que la pastille.
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Pastille('${m.label} · ${Fmt.n(series[m] ?? 0)}'),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );

    final parSeries = _mesure == _Mesure.series;
    final barres = Carte(
      padding: EdgeInsets.fromLTRB(parSeries ? 17.5 : 0, 17.5, parSeries ? 17.5 : 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: parSeries ? 0 : 17.5),
            child: Row(
              children: [
                Expanded(child: SurTitre(parSeries ? 'Séries par muscle' : 'Volume par muscle')),
                InkWell(
                  onTap: _trier,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const IconeTrait(Trait.tri, taille: 17),
                        const SizedBox(width: 6),
                        Text(
                          switch (_tri) { _Tri.series => 'Tri : volume', _Tri.alpha => 'Tri : A à Z', _Tri.region => 'Tri : région' },
                          style: ts(14, FontWeight.w600, c.text, hauteur: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (parSeries) ...[const LegendeCible(), const SizedBox(height: 6)],
          for (final m in muscles)
            if (parSeries)
              BarreMuscle(muscle: m, series: series[m] ?? 0, onTap: () => ouvrir(m))
            else
              MuscleBar(
                name: m.label,
                value: maxVol <= 0 ? 0 : (volumes[m] ?? 0) / maxVol,
                valueLabel: Fmt.volume(volumes[m] ?? 0, u),
                secondary: maxSeries <= 0 ? 0 : (series[m] ?? 0) / maxSeries,
                secondaryLabel: seriesTexte(series[m] ?? 0),
                leading: BodyMap(
                  view: m.side == MuscleSide.dos ? BodyView.back : BodyView.front,
                  intensities: {m: 1},
                  height: 60,
                ),
                onTap: () => ouvrir(m),
              ),
        ],
      ),
    );

    const pad = EdgeInsets.symmetric(horizontal: Cotes.marge);
    return PageProgres(
      child: ListView(
        padding: EdgeInsets.only(bottom: basDePage(context)),
        children: [
          EnTetePage(
            titre: 'Volume par muscle',
            sousTitre: _semaine == courante ? 'Cette semaine' : 'Semaine du ${ProgresStats.semaine(_semaine)}',
          ),
          const SizedBox(height: 8),
          Padding(
            padding: pad,
            child: SelecteurPas(
              label: _semaine == courante ? 'Cette semaine' : ProgresStats.semaine(_semaine),
              avant: 'Semaine précédente',
              apres: 'Semaine suivante',
              onAvant: _semaine.isAfter(premiere) ? () => setState(() => _semaine = Dates.debutSemaine(_semaine.subtract(const Duration(days: 3)))) : null,
              onApres: _semaine.isBefore(courante) ? () => setState(() => _semaine = Dates.debutSemaine(_semaine.add(const Duration(days: 10)))) : null,
              onLabel: _semaine == courante ? null : () => setState(() => _semaine = courante),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: pad,
            child: SelecteurSegmente<_Mesure>(
              segments: const [(_Mesure.series, 'Séries'), (_Mesure.volume, 'Volume')],
              value: _mesure,
              onChanged: (v) => setState(() => _mesure = v),
            ),
          ),
          const SizedBox(height: Cotes.bloc),
          if (seances.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Cotes.marge, 0, Cotes.marge, Cotes.gouttiere),
              child: Carte(
                padding: const EdgeInsets.all(17.5),
                child: EtatVide(
                  dansCarte: true,
                  titre: 'Aucune séance cette semaine',
                  message: 'Tous les muscles sont encore à travailler. Change de semaine pour revoir les précédentes.',
                  action: _semaine == courante ? 'Commencer une séance' : null,
                  onAction: _semaine == courante ? () => context.go('/entrainer') : null,
                ),
              ),
            ),
          for (final (k, bloc) in [personnage, synthese, oublis, barres].indexed)
            Padding(padding: EdgeInsets.fromLTRB(Cotes.marge, k == 0 ? 0 : Cotes.gouttiere, Cotes.marge, 0), child: bloc),
        ],
      ),
    );
  }
}

/// Détail d'un muscle : 12 semaines de séries, exercices qui le travaillent.
class MuscleDetailPage extends StatefulWidget {
  const MuscleDetailPage({super.key, required this.muscle});
  final Muscle muscle;

  @override
  State<MuscleDetailPage> createState() => _MuscleDetailPageState();
}

class _MuscleDetailPageState extends State<MuscleDetailPage> {
  var _semaines = 12;

  @override
  Widget build(BuildContext context) => ProgresGarde(titre: widget.muscle.label, builder: _contenu);

  Widget _contenu(BuildContext context) {
    final m = widget.muscle;
    final repo = context.watch<SessionRepo>();
    final ex = context.watch<ExerciseRepo>();
    final c = context.colors;
    final courante = Dates.debutSemaine(DateTime.now());
    // Par le calendrier : sept jours de 24 heures glissent d'une heure au
    // changement d'heure et décalent les semaines.
    DateTime semaine(int k) => DateTime(courante.year, courante.month, courante.day - 7 * (_semaines - 1 - k));
    final debut = semaine(0);
    final i = Intervalle(debut, semaine(_semaines));
    final seances = ProgresStats.dans(repo.sessions, i);
    final valeurs = <double>[];
    final labels = <String>[];
    for (var k = 0; k < _semaines; k++) {
      final d = semaine(k);
      final sem = ProgresStats.dans(seances, Intervalle(d, semaine(k + 1)));
      valeurs.add(ProgresStats.seriesParMuscle(sem, ex.byId)[m] ?? 0);
      labels.add('${d.day}/${d.month}');
    }
    final cetteSemaine = valeurs.last;
    final moyenne = valeurs.fold<double>(0, (a, b) => a + b) / valeurs.length;
    final exos = ProgresStats.exercicesDuMuscle(seances, m, ex.byId);
    final statut = ProgresStats.statut(cetteSemaine);
    final vue = m.side == MuscleSide.dos ? BodyView.back : BodyView.front;
    final manque = ProgresStats.seriesMin - cetteSemaine;
    final conseil = switch (statut) {
      StatutMuscle.neglige => 'Il manque ${seriesTexte(manque)} cette semaine pour atteindre la cible.',
      StatutMuscle.cible => 'Dans la cible cette semaine : continue comme ça.',
      StatutMuscle.auDessus => 'Au-dessus de 20 séries : surveille la récupération.',
    };
    final texte = ts(14, FontWeight.w400, c.text2, hauteur: 1.4);

    final resume = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Row(
        children: [
          BodyMap(view: vue, intensities: {m: 1}, height: 190),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GrandChiffre(etiquette: 'Cette semaine', valeur: Fmt.n(cetteSemaine), unite: cetteSemaine >= 2 ? 'séries' : 'série'),
                const SizedBox(height: 10),
                Pastille(
                  statut.label,
                  ton: switch (statut) { StatutMuscle.cible => TonPastille.ok, StatutMuscle.auDessus => TonPastille.alerte, StatutMuscle.neglige => TonPastille.neutre },
                ),
                const SizedBox(height: 10),
                Text(conseil, style: texte),
              ],
            ),
          ),
        ],
      ),
    );

    final parSemaine = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitreCarte('Séries par semaine', droite: 'moyenne ${Fmt.n(moyenne)}'),
          const SizedBox(height: 12.5),
          SelecteurSegmente<int>(
            segments: const [(4, '4 sem.'), (12, '12 sem.'), (26, '6 mois')],
            value: _semaines,
            onChanged: (v) => setState(() => _semaines = v),
          ),
          const SizedBox(height: 16),
          BarresProgres(
            values: valeurs,
            labels: labels,
            bande: (ProgresStats.seriesMin, ProgresStats.seriesMax),
            highlight: valeurs.length - 1,
            format: (v) => seriesTexte(v),
            maxLabels: 5,
          ),
          const SizedBox(height: 6),
          Text('La bande claire marque la cible de 10 à 20 séries.', style: texte),
        ],
      ),
    );

    const pad = EdgeInsets.symmetric(horizontal: Cotes.marge);
    return PageProgres(
      child: ListView(
        padding: EdgeInsets.only(bottom: basDePage(context)),
        children: [
          EnTetePage(titre: m.label, sousTitre: m.region.label),
          const SizedBox(height: 8),
          Padding(padding: pad, child: resume),
          const SizedBox(height: Cotes.gouttiere),
          Padding(padding: pad, child: parSemaine),
          const SizedBox(height: Cotes.bloc),
          const TitreBloc('Exercices qui le travaillent'),
          if (exos.isEmpty)
            Padding(
              padding: pad,
              child: Carte(
                padding: const EdgeInsets.all(17.5),
                child: EtatVide(
                  dansCarte: true,
                  titre: 'Aucun exercice sur la période',
                  message: 'Ajoute un exercice pour ce muscle à ta prochaine séance.',
                  action: 'Parcourir les exercices',
                  onAction: () => context.push('/entrainer/exercices'),
                ),
              ),
            )
          else
            Padding(
              padding: pad,
              child: CarteListe(
                lignes: [
                  for (final (k, e) in exos.indexed)
                    LigneListe(
                      filet: k > 0,
                      gauche: iconeExercice(context, e.exerciseId),
                      titre: ex.nameOf(e.exerciseId),
                      sousTitre: e.principal ? 'Muscle principal' : 'Muscle secondaire',
                      valeur: seriesTexte(e.series),
                      onTap: () => context.push('/progres/exercices/${Uri.encodeComponent(e.exerciseId)}'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
