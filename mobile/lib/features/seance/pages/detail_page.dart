import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/bibliotheque/bibliotheque.dart';
import '../logic/analyse.dart';
import '../logic/editeur.dart';
import '../logic/lancement.dart';
import '../seance_paths.dart';
import '../widgets/analyse_seance.dart';
import '../widgets/bilan_blocs.dart';
import '../widgets/exercice_carte.dart';
import '../widgets/habillage.dart';
import '../widgets/pages.dart';
import '../widgets/panneaux.dart';
import '../widgets/serie_ligne.dart';
import 'resume_page.dart';

/// Détail d'une séance de l'historique : chiffres, muscles, records,
/// exercices série par série ; modifier, refaire, partager, supprimer.
class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.sessionId});

  final String sessionId;

  /// Temps laissé pour annuler une suppression avant que les photos et
  /// vidéos de la séance soient effacées du téléphone.
  static const delaiAnnulation = Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<SessionRepo>();
    final exos = context.watch<ExerciseRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final s = repo.byId(sessionId);
    if (s == null || s.enCours) {
      return PageSeance(
        titre: 'Séance',
        body: VideSeance(
          icone: const Trait(IconeSeance.loupe),
          titre: 'Séance introuvable',
          message: 'Elle a peut-être été supprimée.',
          action: 'Retour à l\'historique',
          onAction: () => context.canPop() ? context.pop() : context.go(SeancePaths.historique),
        ),
      );
    }
    final bilan = BilanSeance.calculer(s, repo, exos);
    final ecart = comparerAuPrecedent(s, repo.sessions);
    final records = bilan.records;

    Future<void> refaire() async {
      if (!await Lancement.libererPlace(context)) {
        if (context.mounted) context.push(SeancePaths.enCours);
        return;
      }
      await Lancement.refaire(repo, s);
      if (context.mounted) context.push(SeancePaths.enCours);
    }

    Future<void> supprimer() async {
      final ok = await showConfirmDialog(
        context,
        title: 'Supprimer cette séance ?',
        message: 'Elle disparaîtra de l\'historique, des statistiques et des records. C\'est définitif.',
        confirmLabel: 'Supprimer',
        destructive: true,
        icon: Icons.delete_rounded,
      );
      if (!ok || !context.mounted) return;
      // Les fichiers des photos restent le temps de pouvoir annuler.
      await repo.delete(s.id, garderMedias: true);
      Timer(delaiAnnulation, () => repo.supprimerMedias(s));
      if (!context.mounted) return;
      Toasts.show(context, 'Séance supprimée', actionLabel: 'Annuler', onAction: () => repo.save(s));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(SeancePaths.historique);
      }
    }

    Future<void> menu() async {
      final v = await menuPanneau<String>(
        context,
        titre: s.nom,
        actions: const [
          ActionPanneau('modifier', 'Modifier la séance', Trait(IconeSeance.crayon)),
          ActionPanneau('refaire', 'Refaire cette séance', Trait(IconeSeance.refaire)),
          ActionPanneau('partager', 'Partager', Trait(IconeSeance.partager)),
          ActionPanneau('routine', 'Enregistrer comme routine', Trait(IconeSeance.plus)),
          ActionPanneau('supprimer', 'Supprimer la séance', Trait(IconeSeance.corbeille), destructif: true, filetAvant: true),
        ],
      );
      if (!context.mounted || v == null) return;
      switch (v) {
        case 'modifier':
          context.push(SeancePaths.modifier(s.id));
        case 'refaire':
          await refaire();
        case 'partager':
          await partagerSeance(context, s, bilan.records);
        case 'routine':
          await enregistrerCommeRoutine(context, s);
        case 'supprimer':
          await supprimer();
      }
    }

    final series = s.nbSeriesFaites;
    final gris = TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.4, color: c.text2);
    Widget marge(Widget w, {double haut = 0}) => Padding(padding: EdgeInsets.fromLTRB(margeSeance, haut, margeSeance, 0), child: w);

    return PageSeance(
      titre: s.nom,
      sousTitre: '${s.debut.year == DateTime.now().year ? Fmt.jourMois(s.debut) : Fmt.dateCourte(s.debut)} · ${Fmt.heure(s.debut)} à ${Fmt.heure(s.fin ?? s.debut)}',
      fin: BoutonRond(label: 'Plus d\'actions', nu: true, onTap: menu, child: TroisPoints(size: k(18))),
      bas: Row(
        children: [
          Expanded(child: BoutonSeance(label: 'Modifier', fond: c.surface2, encre: c.text, onTap: () => context.push(SeancePaths.modifier(s.id)))),
          SizedBox(width: k(8)),
          Expanded(child: BoutonSeance(label: 'Refaire', fond: c.bouton, encre: c.onBouton, onTap: refaire)),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(top: k(6), bottom: k(12)),
        children: [
          // Sans charge soulevée (cardio), pas de « 0 kg » : la durée seule.
          marge(Row(
            children: [
              Expanded(child: TuileChiffre(valeur: Fmt.duree(s.duree), label: 'durée')),
              if (s.volume > 0) ...[
                SizedBox(width: k(6)),
                Expanded(child: TuileChiffre(valeur: volumeSeance(s.volume, unite), label: 'volume')),
              ],
              if (series > 0) ...[
                SizedBox(width: k(6)),
                Expanded(child: TuileChiffre(valeur: '$series', label: series > 1 ? 'séries' : 'série')),
              ],
            ],
          )),
          if (ecart != null)
            marge(
              haut: k(8),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: ecart.texte, style: TextStyle(fontWeight: FontWeight.w700, color: ecart.pourcent > 0 ? c.success : c.error)),
                  TextSpan(text: ' de volume par rapport au dernier ${ecart.reference}${ecart.aSeriesEgales ? ', à séries égales' : ''}'),
                ]),
                style: gris.copyWith(fontFeatures: AppTokens.tabular),
              ),
            ),
          if (s.source == 'import') marge(haut: k(8), Text('Séance importée.', style: gris)),
          if (bilan.intensites.isNotEmpty)
            marge(
              haut: k(14),
              Container(
                padding: EdgeInsets.fromLTRB(k(10), k(10), k(10), k(6)),
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(k(18))),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BodyMapDual(intensities: bilan.intensites, highlight: c.accent, height: k(150), spacing: k(26)),
                ),
              ),
            ),
          if (records.isNotEmpty)
            marge(
              haut: k(18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Surtitre(records.length > 1 ? '${records.length} records battus' : 'Un record battu'),
                  for (final r in records)
                    Padding(
                      padding: EdgeInsets.only(top: k(8)),
                      child: LigneRecord(
                        nom: exos.nameOf(r.exerciseId),
                        type: titreRecord(r, unite),
                        valeur: texteRecord(r, unite),
                        gain: texteGainRecord(r, bilan.ancienne(r), unite),
                        medaille: r.type.medaille,
                      ),
                    ),
                ],
              ),
            ),
          if (s.ressenti != null || (s.notes ?? '').isNotEmpty)
            marge(
              haut: k(18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Surtitre('Ressenti et note'),
                  SizedBox(height: k(6)),
                  if (s.ressenti != null && s.ressenti! >= 1 && s.ressenti! <= 5)
                    Text(
                      ressentis[s.ressenti! - 1],
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.4, fontWeight: FontWeight.w600, color: c.text),
                    ),
                  if ((s.notes ?? '').isNotEmpty) Text(s.notes!, style: gris.copyWith(fontSize: k(13))),
                ],
              ),
            ),
          marge(haut: k(18), const Surtitre('Exercices')),
          if (s.exercices.isEmpty)
            marge(haut: k(6), Text('Aucun exercice enregistré.', style: gris))
          else
            for (final e in s.exercices)
              marge(
                haut: k(8),
                _ExerciceDetail(
                  se: e,
                  exos: exos,
                  unite: unite,
                  record: bilan.recordsDe(e.exerciseId).isNotEmpty,
                  lettreSuperset: lettreSupersetDans(s.exercices, e.supersetId),
                ),
              ),
          marge(haut: k(18), AnalyseSeance(session: s, exos: exos, unite: unite)),
          Center(
            child: InkWell(
              borderRadius: AppTokens.radius8,
              onTap: supprimer,
              child: Padding(
                padding: EdgeInsets.fromLTRB(k(10), k(18), k(10), k(8)),
                child: Text(
                  'Supprimer la séance',
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), fontWeight: FontWeight.w600, color: c.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un exercice de la séance, en lecture : vignette, nom, séries une à une.
class _ExerciceDetail extends StatelessWidget {
  const _ExerciceDetail({required this.se, required this.exos, required this.unite, required this.record, this.lettreSuperset});

  final SessionExercise se;
  final ExerciseRepo exos;
  final UnitePoids unite;
  final bool record;
  final String? lettreSuperset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ex = exos.byId(se.exerciseId);
    final suivi = ex?.suivi ?? ExerciseTracking.poidsReps;
    final labels = libellesSeries(se.series);
    final comptees = se.seriesFaites.where((x) => x.type.counts).length;
    final meilleure = se.series.where((x) => x.fait && x.type.counts).fold<WorkoutSet?>(
          null,
          (a, x) => a == null || Strength.setOneRm(x) > Strength.setOneRm(a) ? x : a,
        );
    final valeur = TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.35, fontWeight: FontWeight.w600, fontFeatures: AppTokens.tabular);
    final rayon = BorderRadius.circular(k(14));
    return Material(
      color: c.surface,
      borderRadius: rayon,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ouvrirFicheExercice(context, se.exerciseId),
        child: Padding(
          padding: EdgeInsets.fromLTRB(k(8), k(8), k(12), k(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(k(10)),
                    child: ColoredBox(color: c.surface2, child: ExerciseThumb(ex, size: k(40))),
                  ),
                  SizedBox(width: k(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exos.nameOf(se.exerciseId),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.3, fontWeight: FontWeight.w700, color: c.text),
                        ),
                        Text(
                          [
                            if (comptees > 0) Fmt.pluriel(comptees, 'série'),
                            if (se.volume > 0) volumeSeance(se.volume, unite),
                            if (lettreSuperset != null) 'Superset $lettreSuperset',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), height: 1.35, color: c.text2, fontFeatures: AppTokens.tabular),
                        ),
                      ],
                    ),
                  ),
                  if (record) ...[
                    SizedBox(width: k(8)),
                    Semantics(label: 'Record battu', child: Trait(IconeSeance.coupe, size: k(18), color: c.warning)),
                  ],
                ],
              ),
              SizedBox(height: k(6)),
              for (var i = 0; i < se.series.length; i++)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: k(3)),
                  child: Row(
                    children: [
                      SizedBox(
                        width: k(40),
                        child: Center(child: Text(labels[i], style: valeur.copyWith(color: couleurType(context, se.series[i].type)))),
                      ),
                      SizedBox(width: k(12)),
                      Expanded(child: Text(se.series[i].resume(suivi, unite), style: valeur.copyWith(color: se.series[i].fait ? c.text : c.text3))),
                      if (se.series[i].rpe != null)
                        Text('RPE ${Fmt.n(se.series[i].rpe)}', style: valeur.copyWith(fontSize: k(11), fontWeight: FontWeight.w400, color: c.text2)),
                      if (identical(se.series[i], meilleure) && suivi.usesWeight && suivi.usesReps && Strength.setOneRm(meilleure!) > 0) ...[
                        SizedBox(width: k(8)),
                        Text(
                          '1RM ${Fmt.poids(Strength.setOneRm(meilleure), unite)}',
                          style: valeur.copyWith(fontSize: k(11), fontWeight: FontWeight.w400, color: c.text2),
                        ),
                      ],
                    ],
                  ),
                ),
              if (se.notes != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(k(4), k(4), 0, k(2)),
                  child: Text(se.notes!, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11.5), height: 1.4, color: c.text2)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
