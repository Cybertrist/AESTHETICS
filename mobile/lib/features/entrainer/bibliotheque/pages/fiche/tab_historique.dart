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
import '../../logic/records.dart';

/// Onglet « Historique » : chaque séance où l'exercice a été fait, ses
/// séries, le 1RM estimé de chacune et une médaille sur la série qui a
/// battu un record ce jour-là (aucune médaille sinon).
class TabHistorique extends StatelessWidget {
  const TabHistorique({super.key, required this.exercise, required this.stats, this.onOpenSession, this.onEntrainer});

  final Exercise exercise;
  final ExerciseStats stats;
  final ValueChanged<WorkoutSession>? onOpenSession;
  final VoidCallback? onEntrainer;

  @override
  Widget build(BuildContext context) {
    final u = context.watch<ProfileRepo>().unite;
    if (stats.vide) {
      return SingleChildScrollView(
        child: Vide(
          trait: Trait.historique,
          titre: 'Pas encore d’historique',
          message: 'Tes séances avec « ${exercise.nom} » apparaîtront ici, série par série.',
          action: onEntrainer == null ? null : 'S’entraîner sur cet exercice',
          onAction: onEntrainer,
        ),
      );
    }
    final points = stats.points.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(margeEcran, 17.5, margeEcran, 36),
      itemCount: points.length,
      itemBuilder: (context, i) {
        final p = points[i];
        return _Seance(
          point: p,
          suivi: exercise.suivi,
          unite: u,
          rang: rangRecord(stats, p, exercise.suivi),
          onTap: onOpenSession == null ? null : () => onOpenSession!(p.session),
        );
      },
    );
  }
}

class _Seance extends StatelessWidget {
  const _Seance({required this.point, required this.suivi, required this.unite, required this.rang, this.onTap});

  final SessionPoint point;
  final ExerciseTracking suivi;
  final UnitePoids unite;

  /// Record en cours (médaille dorée), ancien record (grise) ou simple
  /// meilleure série de la séance (rien).
  final RangRecord rang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = point.session;
    final meilleure = meilleureDeSeance(point, suivi);
    final avecRm = suivi == ExerciseTracking.poidsReps || suivi == ExerciseTracking.poidsDuCorpsLeste;
    final gris = TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, height: 1.35, color: c.text2);
    var n = 0;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 17.5),
        padding: const EdgeInsets.only(bottom: 17.5),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Tuile(taille: 55, child: IconeTypeSeance(s.type, size: 27.5, color: c.text, epaisseur: 1.9)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 19, height: 1.3, fontWeight: FontWeight.w700, color: c.text),
                      ),
                      Text(ExFmt.dateEtHeure(s.debut), maxLines: 1, overflow: TextOverflow.ellipsis, style: gris),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Séries réalisées', style: gris), if (avecRm) Text('1RM', style: gris)],
            ),
            for (final set in point.seriesFaites)
              () {
                final normale = set.type.counts && set.type.short.isEmpty;
                final fort = rang != RangRecord.aucun && meilleure != null && identical(set, meilleure.serie);
                final rm = Strength.setOneRm(set);
                final texte = TextStyle(
                  fontFamily: AppTokens.fontUi,
                  fontSize: 17.5,
                  height: 1.3,
                  fontWeight: fort ? FontWeight.w700 : FontWeight.w400,
                  color: fort ? c.text : c.text2,
                  fontFeatures: AppTokens.tabular,
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 12.5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 35,
                        child: Text(
                          normale ? '${++n}' : set.type.short,
                          style: TextStyle(
                            fontFamily: AppTokens.fontUi,
                            fontSize: 17.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: set.type.counts ? c.minuteur : c.text2,
                            fontFeatures: AppTokens.tabular,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ExFmt.serieFiche(set, suivi, unite), maxLines: 1, overflow: TextOverflow.ellipsis, style: texte),
                            if (fort)
                              Row(
                                children: [
                                  Medaille(record: rang == RangRecord.enCours, taille: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${rang == RangRecord.enCours ? 'Record' : 'Ancien record'} · ${meilleure.label}',
                                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.75, height: 1.3, fontWeight: FontWeight.w500, color: c.text2),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (avecRm && rm > 0) Text(Fmt.n(Fmt.poidsAffiche(rm, unite), decimals: 0), style: texte),
                    ],
                  ),
                );
              }(),
            if (point.exercise.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text(point.exercise.notes!, style: gris.copyWith(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}
