import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../seance/seance_paths.dart';
import '../logic/progres_stats.dart';
import 'communs.dart';
import 'progres_widgets.dart';
import '../../profil/widgets/ecusson.dart';

/// Résumé en lecture d'une séance passée, vue sous l'angle des progrès.
class SeanceResumePage extends StatelessWidget {
  const SeanceResumePage({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) => ProgresGarde(titre: 'Séance', builder: _contenu);

  Widget _contenu(BuildContext context) {
    final repo = context.watch<SessionRepo>();
    final ex = context.watch<ExerciseRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final s = repo.byId(sessionId);
    if (s == null) {
      return PageProgres(
        child: ListView(
          children: [
            const EnTetePage(titre: 'Séance'),
            EtatVide(
              titre: 'Séance introuvable',
              message: 'Elle a peut-être été supprimée.',
              action: 'Retour aux progrès',
              onAction: () => context.go('/progres'),
            ),
          ],
        ),
      );
    }
    final records = ProgresStats.recordsDeSeance(s, repo.sessions);
    final muscles = ProgresStats.seriesParMuscle([s], ex.byId);
    final idsRecords = {for (final r in records) r.exerciseId};
    final texte = ts(14, FontWeight.w400, c.text2, hauteur: 1.4);
    // « 1,2 t » ou « 5 728 kg » : la valeur, puis l'unité.
    final volume = Fmt.volume(s.volume, u).split(' ');
    final sansCharge = s.volume <= 0;

    final entete = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Une séance sans charge (cardio) met sa durée en avant, pas « 0 kg ».
          if (sansCharge)
            GrandChiffre(
              etiquette: 'Durée',
              valeur: s.fin == null ? '-' : Fmt.duree(s.duree),
              legende: '${Fmt.jourCap(s.debut)} ${s.debut.year} à ${Fmt.heure(s.debut)}',
            )
          else
            GrandChiffre(
              etiquette: 'Volume soulevé',
              valeur: volume.sublist(0, volume.length - 1).join(' '),
              unite: volume.last,
              legende: '${Fmt.jourCap(s.debut)} ${s.debut.year} à ${Fmt.heure(s.debut)}',
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (s.fin != null && !sansCharge) Pastille(Fmt.duree(s.duree)),
              if (s.nbSeriesFaites > 0) Pastille(Fmt.pluriel(s.nbSeriesFaites, 'série')),
              if (s.nbReps > 0) Pastille('${Fmt.n(s.nbReps, decimals: 0)} rép.'),
              if (s.ressenti != null) Pastille('Ressenti ${s.ressenti}/5'),
              if (records.isNotEmpty) Pastille(Fmt.pluriel(records.length, 'record'), ton: TonPastille.ok),
            ],
          ),
          if ((s.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(s.notes!.trim(), style: texte),
          ],
        ],
      ),
    );

    final corps = muscles.isEmpty
        ? null
        : Carte(
            padding: const EdgeInsets.all(17.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SurTitre('Muscles travaillés'),
                const SizedBox(height: 12),
                CorpsDouble(
                  intensities: {for (final e in muscles.entries) e.key: (0.25 + 0.75 * e.value / 8).clamp(0.0, 1.0)},
                  hauteurMax: 200,
                  onTap: (m) => context.push('/progres/muscles/${m.name}'),
                ),
              ],
            ),
          );

    final recordsCarte = records.isEmpty
        ? null
        : CarteListe(
            titre: 'Records battus',
            lignes: [
              for (final (i, r) in records.indexed)
                LigneListe(
                  filet: i > 0,
                  gauche: SizedBox(width: 44, child: Center(child: Ecusson.record(largeur: 38, medaille: r.type.medaille))),
                  titre: ex.nameOf(r.exerciseId),
                  sousTitre: r.type == RecordType.repsMax && (r.poids ?? 0) > 0 ? 'Répétitions à ${Fmt.poids(r.poids, u)}' : r.type.label,
                  valeur: switch (r.type) {
                    RecordType.repsMax => '${r.valeur.round()} rép.',
                    RecordType.volumeSerie || RecordType.volumeSeance => Fmt.volume(r.valeur, u),
                    _ => Fmt.poids(r.valeur, u),
                  },
                ),
            ],
          );

    final exos = [
      for (final e in s.exercices)
        if (e.seriesFaites.isNotEmpty)
          Carte(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 11),
            semantique: ex.nameOf(e.exerciseId),
            onTap: () => context.push('/progres/exercices/${Uri.encodeComponent(e.exerciseId)}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    iconeExercice(context, e.exerciseId),
                    const SizedBox(width: 12),
                    Expanded(child: Text(ex.nameOf(e.exerciseId), style: ts(16, FontWeight.w700, c.text, hauteur: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    if (idsRecords.contains(e.exerciseId)) ...[const SizedBox(width: 8), Ecusson.record(largeur: 24)],
                    const SizedBox(width: 6),
                    const Chevron(taille: 16),
                  ],
                ),
                const SizedBox(height: 8),
                for (final (i, w) in e.seriesFaites.indexed)
                  Builder(builder: (context) {
                    final orm = Strength.setOneRm(w);
                    final quoi = (w.poids ?? 0) > 0 || w.reps != null
                        ? Ecrit.serie(w.poids, w.reps, u)
                        : (w.dureeSec != null ? Fmt.duree(Duration(seconds: w.dureeSec!)) : Affichage.distance(w.distanceM ?? 0, decimals: 1));
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              w.type.short.isEmpty ? '${i + 1}' : w.type.short,
                              style: ts(14, FontWeight.w700, w.type == SetType.normale ? c.text2 : c.warning, hauteur: 1.35),
                            ),
                          ),
                          Expanded(flex: 5, child: Text(quoi, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, FontWeight.w600, c.text, hauteur: 1.35))),
                          Expanded(
                            flex: 6,
                            child: Text(
                              [if (w.rpe != null) 'RPE ${Fmt.n(w.rpe)}', if (orm > 0) '1RM ${Fmt.poids(orm, u)}'].join('  ·  '),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: texte,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
    ];

    final blocs = [
      entete,
      ?recordsCarte,
      ?corps,
      if (exos.isEmpty && !sansCharge)
        const Carte(padding: EdgeInsets.all(17.5), child: EtatVide(dansCarte: true, titre: 'Aucune série faite'))
      else
        ...exos,
    ];

    return PageProgres(
      child: ListView(
        padding: EdgeInsets.only(bottom: basDePage(context)),
        children: [
          EnTetePage(
            titre: s.nom,
            sousTitre: Fmt.relatif(s.debut),
            droite: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BoutonRond(trait: Trait.rejouer, label: 'Refaire cette séance', taille: 48, onTap: () => context.push(SeancePaths.refaire(s.id))),
                const SizedBox(width: 8),
                BoutonRond(trait: Trait.crayon, label: 'Modifier, partager ou supprimer', taille: 48, onTap: () => context.push(SeancePaths.detail(s.id))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final (k, bloc) in blocs.indexed)
            Padding(padding: EdgeInsets.fromLTRB(Cotes.marge, k == 0 ? 0 : Cotes.gouttiere, Cotes.marge, 0), child: bloc),
        ],
      ),
    );
  }
}
