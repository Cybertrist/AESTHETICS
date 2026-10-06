import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/progres_stats.dart';
import 'calendrier_widgets.dart';
import 'communs.dart';
import 'progres_widgets.dart';
import '../../profil/widgets/ecusson.dart';

/// Choix de l'exercice dont on veut voir la progression.
class ChoixExercicePage extends StatefulWidget {
  const ChoixExercicePage({super.key});

  @override
  State<ChoixExercicePage> createState() => _ChoixExercicePageState();
}

class _ChoixExercicePageState extends State<ChoixExercicePage> {
  final _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProgresGarde(titre: 'Progression', builder: _contenu);

  Widget _contenu(BuildContext context) {
    final sessions = context.watch<SessionRepo>().sessions;
    final ex = context.watch<ExerciseRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final lignes = ProgresStats.records(sessions)..sort((a, b) => b.derniereFois.compareTo(a.derniereFois));
    final q = _recherche.text.trim();
    final filtres = q.isEmpty
        ? lignes
        : lignes.where((l) => TextSearch.matches(q, [ex.nameOf(l.exerciseId), ...?ex.byId(l.exerciseId)?.alias])).toList();

    const pad = EdgeInsets.symmetric(horizontal: Cotes.marge);
    return PageProgres(
      child: ListView(
        padding: EdgeInsets.only(bottom: basDePage(context)),
        children: [
          const EnTetePage(titre: 'Progression', sousTitre: 'Choisis un exercice déjà fait'),
          if (lignes.isEmpty)
            EtatVide(
              titre: 'Aucun exercice à suivre',
              message: 'Dès ta première séance terminée, chaque exercice aura sa courbe.',
              action: 'Aller à l\'entraînement',
              onAction: () => context.go('/entrainer'),
            )
          else ...[
            const SizedBox(height: 8),
            Padding(
              padding: pad,
              child: ChampRecherche(controller: _recherche, indice: 'Chercher un exercice', onChanged: (_) => setState(() {})),
            ),
            const SizedBox(height: Cotes.bloc),
            if (filtres.isEmpty)
              const EtatVide(titre: 'Aucun exercice trouvé', message: 'Essaie un autre nom.')
            else
              Padding(
                padding: pad,
                child: CarteListe(
                  titre: q.isEmpty ? 'Faits récemment' : 'Résultats',
                  droite: Fmt.pluriel(filtres.length, 'exercice'),
                  lignes: [
                    for (final (i, l) in filtres.indexed)
                      LigneListe(
                        filet: i > 0,
                        gauche: iconeExercice(context, l.exerciseId),
                        titre: ex.nameOf(l.exerciseId),
                        sousTitre: '${Fmt.pluriel(l.nbSeances, 'séance')} · ${Fmt.relatif(l.derniereFois)}',
                        valeur: l.sansCharge
                            ? (l.bests.repsMax == null ? null : '${l.bests.repsMax!.valeur.round()} rép.')
                            : Fmt.poids(l.bests.unRm?.valeur, u),
                        onTap: () => context.push('/progres/exercices/${Uri.encodeComponent(l.exerciseId)}'),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

enum _Duree {
  mois3('3 mois', 91),
  mois6('6 mois', 182),
  an1('1 an', 365),
  tout('Tout', 0);

  const _Duree(this.label, this.jours);
  final String label;
  final int jours;
}

/// Progression d'un exercice : courbe, records, charges conseillées, historique.
class ExerciceProgresPage extends StatefulWidget {
  const ExerciceProgresPage({super.key, required this.exerciseId});
  final String exerciseId;

  @override
  State<ExerciceProgresPage> createState() => _ExerciceProgresPageState();
}

class _ExerciceProgresPageState extends State<ExerciceProgresPage> {
  var _indicateur = IndicateurExercice.unRm;
  var _duree = _Duree.tout;
  var _historiqueComplet = false;

  @override
  Widget build(BuildContext context) => ProgresGarde(titre: 'Progression', builder: _contenu);

  Widget _contenu(BuildContext context) {
    final id = widget.exerciseId;
    final sessions = context.watch<SessionRepo>().sessions;
    final ex = context.watch<ExerciseRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final exo = ex.byId(id);
    final nom = ex.nameOf(id);
    final tous = ProgresStats.progression(id, sessions);
    final sansCharge = tous.every((p) => p.poidsMax <= 0);
    void fiche() => context.push('/entrainer/exercices/${Uri.encodeComponent(id)}');

    if (tous.isEmpty) {
      return PageProgres(
        child: ListView(
          children: [
            EnTetePage(titre: nom, sousTitre: 'Progression'),
            EtatVide(
              titre: 'Pas encore fait',
              message: 'Cet exercice n\'apparaît dans aucune séance terminée.',
              action: exo == null ? null : 'Voir la fiche',
              onAction: exo == null ? null : fiche,
            ),
          ],
        ),
      );
    }

    // Au poids du corps, seules les répétitions et le volume ont du sens.
    final indicateurs = sansCharge ? const [IndicateurExercice.reps] : IndicateurExercice.values;
    final ind = indicateurs.contains(_indicateur) ? _indicateur : indicateurs.first;
    final depuis = _duree.jours == 0 ? null : DateTime.now().subtract(Duration(days: _duree.jours));
    // Une séance sans charge n'a pas de 1RM : elle ne tire pas la courbe à zéro.
    final chargee = ind == IndicateurExercice.unRm || ind == IndicateurExercice.poidsMax;
    final points = [for (final p in tous) if ((depuis == null || !p.date.isBefore(depuis)) && (!chargee || p.valeur(ind) > 0)) p];
    final bests = Strength.bests(id, sessions);
    final premier = points.isEmpty ? null : points.first.valeur(ind);
    final dernier = points.isEmpty ? null : points.last.valeur(ind);
    final meilleur = points.isEmpty ? null : points.map((p) => p.valeur(ind)).reduce((a, b) => a > b ? a : b);
    final gain = premier == null || dernier == null || points.length < 2 ? null : dernier - premier;
    final unRm = bests.unRm?.valeur;
    final texte = ts(14, FontWeight.w400, c.text2, hauteur: 1.4);

    final entete = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              iconeExercice(context, id, size: 65),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exo == null ? 'Exercice' : [exo.equipementLabel, if (exo.musclesPrincipaux.isNotEmpty) exo.musclesPrincipaux.map((m) => m.label).join(', ')].join(' · '),
                      style: texte,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('${Fmt.pluriel(tous.length, 'séance')} depuis le ${Fmt.date(tous.first.date)}', style: texte),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17.5),
          GrandChiffre(
            etiquette: sansCharge ? 'Répétitions maximales' : '1RM estimé',
            valeur: sansCharge ? Fmt.n(bests.repsMax?.valeur ?? 0, decimals: 0) : Fmt.n(Fmt.poidsAffiche(unRm ?? 0, u)),
            unite: sansCharge ? 'rép.' : u.label,
            legende: bests.unRm == null && bests.repsMax == null ? null : 'Record du ${Fmt.date((bests.unRm ?? bests.repsMax)!.date)}',
          ),
          if (exo != null) ...[
            const SizedBox(height: 15),
            BoutonSecondaire(label: 'Fiche de l\'exercice', petit: true, onPressed: fiche),
          ],
        ],
      ),
    );

    final courbe = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitreCarte(
            'Évolution',
            // Écart nul : rien.
            droite: gain == null || gain == 0 ? null : '${gain > 0 ? '+' : '-'}${formatIndicateurExercice(ind, gain.abs(), u)} sur la période',
            couleurDroite: gain == null ? null : Ecrit.couleur(context, gain),
          ),
          const SizedBox(height: 12.5),
          if (indicateurs.length > 1) ...[
            SelecteurSegmente<IndicateurExercice>(
              segments: [for (final x in indicateurs) (x, x.label)],
              value: ind,
              onChanged: (v) => setState(() => _indicateur = v),
            ),
            const SizedBox(height: 8),
          ],
          SelecteurSegmente<_Duree>(
            segments: [for (final d in _Duree.values) (d, d.label)],
            value: _duree,
            onChanged: (d) => setState(() => _duree = d),
          ),
          const SizedBox(height: 18),
          if (points.isEmpty)
            SizedBox(height: 160, child: Center(child: Text('Aucune séance sur cette période.', style: texte)))
          else if (points.length == 1)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'Une seule séance sur la période : ${formatIndicateurExercice(ind, points.first.valeur(ind), u)}.\nIl faut deux séances pour tracer une courbe.',
                  textAlign: TextAlign.center,
                  style: texte,
                ),
              ),
            )
          else
            CourbeProgres(
              points: [for (final p in points) (p.date, ind == IndicateurExercice.volume || ind == IndicateurExercice.reps ? p.valeur(ind) : Fmt.poidsAffiche(p.valeur(ind), u))],
              format: (v) => ind == IndicateurExercice.reps
                  ? '${v.round()} rép.'
                  : (ind == IndicateurExercice.volume ? Fmt.volume(v, u) : '${Fmt.n(v)} ${u.label}'),
              onTap: (k) => ouvrirSeance(context, points[k].session.id),
            ),
          if (meilleur != null && points.length >= 2) ...[
            const SizedBox(height: 10),
            Text('Meilleur : ${formatIndicateurExercice(ind, meilleur, u)} · dernier : ${formatIndicateurExercice(ind, dernier!, u)}', style: texte),
          ],
        ],
      ),
    );

    final records = CarteListe(
      titre: 'Records',
      lignes: [
        for (final (i, r) in bests.all.indexed)
          LigneListe(
            filet: i > 0,
            gauche: SizedBox(width: 44, child: Center(child: Ecusson.record(largeur: 38, medaille: r.type.medaille))),
            titre: r.type.label,
            sousTitre: '${Fmt.jourMois(r.date)} ${r.date.year}',
            valeur: switch (r.type) {
              RecordType.repsMax => '${r.valeur.round()} rép.',
              RecordType.volumeSerie || RecordType.volumeSeance => Fmt.volume(r.valeur, u),
              _ => Fmt.poids(r.valeur, u),
            },
            // La série du record, sous sa valeur.
            sousValeur: r.type != RecordType.volumeSeance && r.type != RecordType.repsMax && (r.poids ?? 0) > 0 ? Ecrit.serie(r.poids, r.reps, u) : null,
            onTap: r.sessionId == null ? null : () => ouvrirSeance(context, r.sessionId!),
          ),
      ],
    );

    final increment = context.read<SettingsRepo>().settings.incrementPoidsKg;
    final charges = unRm == null || unRm <= 0
        ? null
        : Carte(
            padding: const EdgeInsets.all(17.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TitreCarte('Charges conseillées', droite: 'd\'après le 1RM'),
                const SizedBox(height: 6),
                for (final t in Strength.tablePourcentages(unRm).where((t) => const [1, 2, 3, 5, 6, 8, 10, 12].contains(t.reps)))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 62, child: Text('${t.reps} rép.', style: ts(15, FontWeight.w700, c.text, hauteur: 1.35))),
                        Expanded(child: BarreFine(valeur: t.pct, couleur: c.text)),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 76,
                          child: Text(Fmt.poids(Strength.arrondir(t.poids, increment), u), textAlign: TextAlign.right, maxLines: 1, style: ts(15, FontWeight.w700, c.text, hauteur: 1.35)),
                        ),
                        SizedBox(width: 48, child: Text('${(t.pct * 100).round()} %', textAlign: TextAlign.right, maxLines: 1, style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35))),
                      ],
                    ),
                  ),
              ],
            ),
          );

    final hist = tous.reversed.toList();
    final visibles = _historiqueComplet ? hist : hist.take(8).toList();
    final historique = CarteListe(
      titre: 'Historique',
      droite: Fmt.pluriel(hist.length, 'séance'),
      lignes: [
        for (final (i, p) in visibles.indexed)
          LigneListe(
            filet: i > 0,
            titre: p.session.nom,
            sousTitre: '${Fmt.jourCap(p.date)} ${p.date.year} · ${Fmt.pluriel(p.series, 'série')}',
            valeur: p.meilleureSerie == null
                ? null
                : ((p.meilleureSerie!.poids ?? 0) > 0 ? Ecrit.serie(p.meilleureSerie!.poids, p.meilleureSerie!.reps, u) : '${p.repsMax} rép.'),
            onTap: () => _detailSeance(context, p, u),
          ),
        if (hist.length > 8)
          InkWell(
            onTap: () => setState(() => _historiqueComplet = !_historiqueComplet),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17.5, vertical: 14),
              child: Text(_historiqueComplet ? 'Réduire' : 'Voir les ${hist.length} séances', style: ts(15, FontWeight.w600, c.text, hauteur: 1.35)),
            ),
          ),
      ],
    );

    return PageProgres(
      child: ListView(
        padding: EdgeInsets.only(bottom: basDePage(context)),
        children: [
          EnTetePage(titre: nom, sousTitre: 'Progression'),
          const SizedBox(height: 8),
          for (final (i, bloc) in [entete, courbe, ?charges, records, historique].indexed)
            Padding(
              padding: EdgeInsets.fromLTRB(Cotes.marge, i == 0 ? 0 : Cotes.gouttiere, Cotes.marge, 0),
              child: bloc,
            ),
        ],
      ),
    );
  }

  /// Séries de l'exercice dans une séance, dans un panneau du bas.
  Future<void> _detailSeance(BuildContext context, PointExercice p, UnitePoids u) {
    final sets = [
      for (final e in p.session.exercices.where((e) => e.exerciseId == widget.exerciseId))
        for (final s in e.series.where((s) => s.fait)) s,
    ];
    return showPanneauBas<void>(
      context,
      entete: Builder(builder: (context) {
        final c = context.colors;
        return Column(
          children: [
            Text(p.session.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, FontWeight.w700, c.text, hauteur: 1.3)),
            Text('${Fmt.jourCap(p.date)} ${p.date.year}', style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
          ],
        );
      }),
      builder: (panneau) {
        final c = panneau.colors;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < sets.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      // Les numéros de série en bleu, comme dans le tableau de la séance.
                      child: Text(
                        sets[i].type.short.isEmpty ? '${i + 1}' : sets[i].type.short,
                        style: ts(15, FontWeight.w700, sets[i].type == SetType.normale ? AppTokens.minuteur : c.warning, hauteur: 1.35),
                      ),
                    ),
                    Expanded(child: Text(Ecrit.serie(sets[i].poids, sets[i].reps, u), style: ts(16, FontWeight.w600, c.text, hauteur: 1.35))),
                    if (Strength.setOneRm(sets[i]) > 0) Text('1RM ${Fmt.poids(Strength.setOneRm(sets[i]), u)}', style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            BoutonPrincipal(
              label: 'Toute la séance',
              onPressed: () {
                Navigator.of(panneau).pop();
                ouvrirSeance(context, p.session.id);
              },
            ),
          ],
        );
      },
    );
  }
}
