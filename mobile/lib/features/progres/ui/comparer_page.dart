import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../logic/progres_stats.dart';
import 'calendrier_widgets.dart';
import 'communs.dart';
import 'progres_widgets.dart';

enum _Preset {
  mois('Ce mois et le précédent', 'Mois'),
  semaines4('4 semaines et les 4 d\'avant', '4 semaines'),
  mois3('3 mois et les 3 d\'avant', '3 mois'),
  annee('Cette année et la précédente', 'Année'),
  perso('Périodes au choix', 'Au choix');

  const _Preset(this.label, this.court);
  final String label;
  final String court;
}

/// Comparaison de deux périodes : chiffres, muscles et exercices.
class ComparerPage extends StatefulWidget {
  const ComparerPage({super.key});

  @override
  State<ComparerPage> createState() => _ComparerPageState();
}

class _ComparerPageState extends State<ComparerPage> {
  var _preset = _Preset.mois;
  late Intervalle _a;
  late Intervalle _b;

  @override
  void initState() {
    super.initState();
    _appliquer(_Preset.mois);
  }

  void _appliquer(_Preset p) {
    final n = DateTime.now();
    final demain = DateTime(n.year, n.month, n.day + 1);
    switch (p) {
      case _Preset.mois:
        _a = Intervalle(DateTime(n.year, n.month), DateTime(n.year, n.month + 1));
        _b = Intervalle(DateTime(n.year, n.month - 1), DateTime(n.year, n.month));
      case _Preset.semaines4:
        final d = Dates.debutSemaine(n).subtract(const Duration(days: 21));
        _a = Intervalle(d, Dates.debutSemaine(n).add(const Duration(days: 7)));
        _b = _a.precedent;
      case _Preset.mois3:
        _a = Intervalle(DateTime(n.year, n.month - 2), DateTime(n.year, n.month + 1));
        _b = Intervalle(DateTime(n.year, n.month - 5), DateTime(n.year, n.month - 2));
      case _Preset.annee:
        _a = Intervalle(DateTime(n.year), DateTime(n.year + 1));
        _b = Intervalle(DateTime(n.year - 1), DateTime(n.year));
      case _Preset.perso:
        if (_preset == _Preset.perso) break;
        _a = Intervalle(DateTime(n.year, n.month), demain);
        _b = Intervalle(DateTime(n.year, n.month - 1), DateTime(n.year, n.month));
    }
    _preset = p;
  }

  Future<void> _choisirPreset() async {
    final p = await choisirDansPanneau<_Preset>(
      context,
      titre: 'Que comparer ?',
      choisi: _preset,
      options: [for (final p in _Preset.values) (p, p.label)],
    );
    if (p == null || !mounted) return;
    setState(() => _appliquer(p));
    if (p == _Preset.perso) await _choisirDates(true);
  }

  Future<void> _choisirDates(bool premiere) async {
    final sessions = context.read<SessionRepo>().sessions;
    final n = DateTime.now();
    final aujourdhui = DateTime(n.year, n.month, n.day);
    final cible = premiere ? _a : _b;
    final premierJour = sessions.isEmpty ? DateTime(n.year - 1) : DateTime(sessions.last.debut.year, sessions.last.debut.month);
    // Les bornes proposées restent dans ce que le calendrier accepte : une
    // période d'avant la première séance ferait échouer son ouverture.
    DateTime borne(DateTime d) => d.isBefore(premierJour) ? premierJour : (d.isAfter(aujourdhui) ? aujourdhui : d);
    final debut = borne(cible.debut);
    final fin = borne(cible.fin.subtract(const Duration(days: 1)));
    final r = await showDateRangePicker(
      context: context,
      firstDate: premierJour,
      lastDate: aujourdhui,
      initialDateRange: DateTimeRange(start: debut, end: fin.isBefore(debut) ? debut : fin),
      helpText: premiere ? 'Première période' : 'Deuxième période',
      saveText: 'Valider',
    );
    if (r == null || !mounted) return;
    setState(() {
      _preset = _Preset.perso;
      final i = Intervalle(r.start, DateTime(r.end.year, r.end.month, r.end.day + 1));
      if (premiere) {
        _a = i;
      } else {
        _b = i;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ProgresGarde(titre: 'Comparer', builder: _contenu);

  Widget _contenu(BuildContext context) {
    final sessions = context.watch<SessionRepo>().sessions;
    final ex = context.watch<ExerciseRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final sa = ProgresStats.dans(sessions, _a);
    final sb = ProgresStats.dans(sessions, _b);
    final ra = ProgresStats.resume(sa, semaines: _a.semaines);
    final rb = ProgresStats.resume(sb, semaines: _b.semaines);
    final ma = ProgresStats.seriesParMuscle(sa, ex.byId);
    final mb = ProgresStats.seriesParMuscle(sb, ex.byId);
    // Séries hebdomadaires moyennes, pour comparer des périodes de durées différentes.
    double parSemaine(Map<Muscle, double> m, Muscle x, Intervalle i) => (m[x] ?? 0) / i.semaines;
    final muscles = [...ProgresStats.musclesSuivis]
      ..sort((x, y) => (parSemaine(ma, y, _a) + parSemaine(mb, y, _b)).compareTo(parSemaine(ma, x, _a) + parSemaine(mb, x, _b)));

    // Exercices faits dans les deux périodes : meilleur 1RM de chacune.
    final idsA = {for (final s in sa) for (final e in s.exercices) e.exerciseId};
    final idsB = {for (final s in sb) for (final e in s.exercices) e.exerciseId};
    final communs = [
      for (final id in idsA.intersection(idsB))
        (id: id, a: ProgresStats.meilleur1Rm(id, sa), b: ProgresStats.meilleur1Rm(id, sb)),
    ].where((x) => x.a > 0 && x.b > 0).toList()
      ..sort((x, y) => ((y.a - y.b) / y.b).compareTo((x.a - x.b) / x.b));
    final texte = ts(14, FontWeight.w400, c.text2, hauteur: 1.4);

    // « 0 min » plutôt que « 0 s » pour une période sans séance.
    String duree(Duration d) => d.inMinutes == 0 ? '0 min' : Fmt.duree(d);

    Widget carteP(String titre, Intervalle i, bool premiere) => Expanded(
          child: Carte(
            padding: const EdgeInsets.all(15),
            semantique: '$titre, ${i.libelle}, changer les dates',
            onTap: () => _choisirDates(premiere),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: premiere ? c.text : c.text2, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Expanded(child: SurTitre(titre)),
                    IconeTrait(Trait.calendrier, taille: 17, couleur: c.text2),
                  ],
                ),
                const SizedBox(height: 8),
                Text(i.libelle, style: ts(16, FontWeight.w700, c.text, hauteur: 1.3), maxLines: 2),
                Text(Fmt.pluriel(i.jours, 'jour'), style: texte),
              ],
            ),
          ),
        );

    Widget ligne(String label, String va, String vb, num a, num b, {bool filet = true}) {
      final v = ProgresStats.variation(a, b);
      // Hausse en vert, baisse en rouge, écart nul ou sans base : rien.
      final montre = v != null && v.abs() >= 0.5;
      return Column(
        children: [
          if (filet) Padding(padding: const EdgeInsets.symmetric(horizontal: 17.5), child: Container(height: 1, color: c.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17.5, vertical: 11),
            child: Row(
              children: [
                Expanded(flex: 5, child: Text(label, style: ts(15, FontWeight.w600, c.text, hauteur: 1.3), maxLines: 2)),
                Expanded(flex: 4, child: Text(va, textAlign: TextAlign.right, maxLines: 1, style: ts(15, FontWeight.w700, c.text, hauteur: 1.3))),
                Expanded(flex: 4, child: Text(vb, textAlign: TextAlign.right, maxLines: 1, style: ts(15, FontWeight.w600, c.text2, hauteur: 1.3))),
                SizedBox(
                  width: 62,
                  child: Text(
                    montre ? ProgresStats.pct(v) : '',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: ts(13.5, FontWeight.w700, montre && v > 0 ? c.success : c.error, hauteur: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final chiffres = CarteListe(
      titre: 'En chiffres',
      droite: '1re, 2e, écart',
      lignes: [
        ligne('Séances', Fmt.n(ra.seances, decimals: 0), Fmt.n(rb.seances, decimals: 0), ra.seances, rb.seances, filet: false),
        ligne('Par semaine', Fmt.n(ra.seancesParSemaine), Fmt.n(rb.seancesParSemaine), ra.seancesParSemaine, rb.seancesParSemaine),
        ligne('Jours actifs', Fmt.n(ra.joursActifs, decimals: 0), Fmt.n(rb.joursActifs, decimals: 0), ra.joursActifs, rb.joursActifs),
        ligne('Volume', Fmt.volume(ra.volume, u), Fmt.volume(rb.volume, u), ra.volume, rb.volume),
        ligne('Volume par séance', Fmt.volume(ra.volumeMoyen, u), Fmt.volume(rb.volumeMoyen, u), ra.volumeMoyen, rb.volumeMoyen),
        ligne('Durée totale', duree(ra.duree), duree(rb.duree), ra.duree.inMinutes, rb.duree.inMinutes),
        ligne('Durée moyenne', duree(ra.dureeMoyenne), duree(rb.dureeMoyenne), ra.dureeMoyenne.inMinutes, rb.dureeMoyenne.inMinutes),
        ligne('Séries', Fmt.n(ra.series, decimals: 0), Fmt.n(rb.series, decimals: 0), ra.series, rb.series),
        ligne('Répétitions', Fmt.n(ra.reps, decimals: 0), Fmt.n(rb.reps, decimals: 0), ra.reps, rb.reps),
      ],
    );

    final musclesCarte = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SurTitre('Séries par muscle et par semaine'),
          const SizedBox(height: 6),
          Text('Barre de couleur : 1re période. Barre grise : 2e période.', style: texte),
          const SizedBox(height: 6),
          for (final m in muscles)
            if (parSemaine(ma, m, _a) > 0 || parSemaine(mb, m, _b) > 0)
              BarreMuscle(
                muscle: m,
                series: parSemaine(ma, m, _a),
                comparaison: parSemaine(mb, m, _b),
                onTap: () => context.push('/progres/muscles/${m.name}'),
              ),
          if (ma.isEmpty && mb.isEmpty) Text('Aucune série sur ces deux périodes.', style: texte),
        ],
      ),
    );

    final exos = CarteListe(
      titre: 'Force, exercices communs',
      droite: Fmt.pluriel(communs.length, 'exercice'),
      lignes: [
        if (communs.isEmpty)
          const LigneListe(
            filet: false,
            gauche: CarreIcone(Trait.info),
            titre: 'Aucun exercice en commun',
            sousTitre: 'Les deux périodes n\'ont pas d\'exercice chargé identique.',
          )
        else
          for (final (k, x) in communs.take(12).indexed)
            LigneListe(
              filet: k > 0,
              gauche: iconeExercice(context, x.id),
              titre: ex.nameOf(x.id),
              sousTitre: '${Fmt.poids(x.a, u)} contre ${Fmt.poids(x.b, u)}',
              valeur: ((x.a - x.b) / x.b * 100).abs() < 0.5 ? null : ProgresStats.pct(ProgresStats.variation(x.a, x.b)),
              couleurValeur: x.a > x.b ? c.success : c.error,
              onTap: () => context.push('/progres/exercices/${Uri.encodeComponent(x.id)}'),
            ),
      ],
    );

    const pad = EdgeInsets.symmetric(horizontal: Cotes.marge);
    return PageProgres(
      child: ListView(
        padding: EdgeInsets.only(bottom: basDePage(context)),
        children: [
          EnTetePage(
            titre: 'Comparer',
            sousTitre: _preset.label,
            droite: BoutonRond(trait: Trait.reglages, label: 'Changer les périodes', onTap: _choisirPreset),
          ),
          const SizedBox(height: 3),
          RangeePuces(puces: [
            for (final p in _Preset.values)
              PuceChoix(
                label: p.court,
                choisi: _preset == p,
                onTap: () async {
                  setState(() => _appliquer(p));
                  if (p == _Preset.perso) await _choisirDates(true);
                },
              ),
          ]),
          const SizedBox(height: 7),
          Padding(
            padding: pad,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  carteP('1re période', _a, true),
                  const SizedBox(width: Cotes.gouttiere),
                  carteP('2e période', _b, false),
                ],
              ),
            ),
          ),
          const SizedBox(height: Cotes.gouttiere),
          if (sa.isEmpty && sb.isEmpty)
            Padding(
              padding: pad,
              child: Carte(
                padding: const EdgeInsets.all(17.5),
                child: EtatVide(
                  dansCarte: true,
                  titre: 'Rien à comparer',
                  message: 'Aucune séance sur ces deux périodes. Touche une période pour changer ses dates.',
                  action: 'Choisir les périodes',
                  onAction: _choisirPreset,
                ),
              ),
            )
          else
            for (final (k, bloc) in [
              chiffres,
              if (sa.isNotEmpty)
                CarteListe(
                  titre: 'Séances de la 1re période',
                  lignes: [
                    for (final (j, s) in sa.take(3).indexed) LigneSeance(session: s, dateComplete: true, filet: j > 0),
                    if (sa.length > 3)
                      InkWell(
                        onTap: () => showSeancesDialog(context, titre: '1re période', seances: sa),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17.5, vertical: 14),
                          child: Text('Voir les ${sa.length} séances', style: ts(15, FontWeight.w600, c.text, hauteur: 1.35)),
                        ),
                      ),
                  ],
                ),
              musclesCarte,
              exos,
            ].indexed)
              Padding(padding: EdgeInsets.fromLTRB(Cotes.marge, k == 0 ? 0 : Cotes.gouttiere, Cotes.marge, 0), child: bloc),
        ],
      ),
    );
  }
}
