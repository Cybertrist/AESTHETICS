import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../seance/seance_paths.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import '../logic/exercise_stats.dart';
import '../logic/records.dart';
import 'fiche/tab_records.dart';

/// Historique des records d'un exercice : pour chaque record, toutes les
/// fois où il a été battu, la plus récente d'abord.
class RecordsHistoriquePage extends StatelessWidget {
  const RecordsHistoriquePage({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final e = context.watch<ExerciseRepo>().byId(exerciseId);
    final sessions = context.watch<SessionRepo>();
    final u = context.watch<ProfileRepo>().unite;
    if (e == null) {
      return const PageEntrainer(
        entete: EnTetePage(titre: 'Historique des records'),
        child: Vide(trait: Trait.loupe, titre: 'Exercice introuvable'),
      );
    }
    final stats = ExerciseStats(sessions.historyFor(e.id));
    final blocs = [
      for (final t in TypeRecord.pour(e.suivi)) (t, progressionRecord(stats, t).reversed.toList()),
    ].where((b) => b.$2.isNotEmpty).toList();
    return PageEntrainer(
      entete: const EnTetePage(titre: 'Historique des records'),
      child: blocs.isEmpty
          ? const SingleChildScrollView(
              child: Vide(trait: Trait.medaille, titre: 'Aucun record pour l’instant', message: 'Chaque record battu s’ajoutera ici, avec sa date.'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(margeEcran, 6, margeEcran, 36),
              children: [
                Text(e.nom, style: TexteEntrainer.detail(context).copyWith(fontSize: 15)),
                for (final (type, lignes) in blocs) ...[
                  const SizedBox(height: 22),
                  Text(type.label, style: TexteEntrainer.titreSection(context)),
                  const SizedBox(height: 2),
                  Text(
                    lignes.length == 1 ? 'Établi une fois' : 'Battu ${lignes.length - 1} fois',
                    style: TexteEntrainer.detail(context),
                  ),
                  const SizedBox(height: 4),
                  for (final (i, r) in lignes.indexed)
                    LigneRecord(
                      record: r,
                      suivi: e.suivi,
                      unite: u,
                      titre: i == 0 ? 'Record en cours' : 'Ancien record',
                      actuel: i == 0,
                      onTap: () => context.push(SeancePaths.detail(r.sessionId)),
                    ),
                ],
              ],
            ),
    );
  }
}
