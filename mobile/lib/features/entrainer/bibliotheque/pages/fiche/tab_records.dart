import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/data/data.dart';
import '../../../../../core/models/models.dart';
import '../../../../../core/theme/theme.dart';
import '../../../../../core/ui/ui.dart';
import '../../../commun/elements.dart';
import '../../../commun/traits.dart';
import '../../logic/exercise_stats.dart';
import '../../logic/formats.dart';
import '../../logic/records.dart';

/// Une ligne de record : médaille, intitulé, date, valeur et série.
class LigneRecord extends StatelessWidget {
  const LigneRecord({super.key, required this.record, required this.suivi, required this.unite, this.titre, this.actuel = true, this.onTap});

  final RecordFiche record;
  final ExerciseTracking suivi;
  final UnitePoids unite;

  /// Intitulé (celui du type de record par défaut).
  final String? titre;

  /// Record en cours : médaille dorée. Ancien record : grise.
  final bool actuel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fort = TextStyle(fontFamily: AppTokens.fontUi, fontSize: 17, height: 1.35, fontWeight: FontWeight.w700, color: c.text);
    final gris = TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.8, height: 1.35, color: c.text2, fontFeatures: AppTokens.tabular);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13.75),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
        child: Row(
          children: [
            Medaille(record: actuel, taille: 27),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre ?? record.type.label, style: fort),
                  Text(ExFmt.dateAbregee(record.date), style: gris),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(record.valeurTexte(unite), style: fort.copyWith(fontFeatures: AppTokens.tabular)),
                Text(record.detail(suivi, unite), style: gris),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Onglet « Records » : les meilleures performances, avec la date et la
/// série qui les a établies.
class TabRecords extends StatelessWidget {
  const TabRecords({super.key, required this.exercise, required this.stats, required this.onHistorique, this.onEntrainer});

  final Exercise exercise;
  final ExerciseStats stats;

  /// « Voir l'historique des records ».
  final VoidCallback onHistorique;
  final VoidCallback? onEntrainer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final u = context.watch<ProfileRepo>().unite;
    final records = recordsDe(stats, exercise.suivi);
    if (records.isEmpty) {
      return SingleChildScrollView(
        child: Vide(
          trait: Trait.medaille,
          titre: 'Aucun record pour l’instant',
          message: 'Tes meilleures performances seront gardées ici avec leur date.',
          action: onEntrainer == null ? null : 'S’entraîner sur cet exercice',
          onAction: onEntrainer,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(margeEcran, 20, margeEcran, 12),
            children: [
              Text(
                'Records personnels',
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 22.5, height: 1.3, fontWeight: FontWeight.w800, color: c.text),
              ),
              const SizedBox(height: 4),
              Text('Tes meilleures performances sur cet exercice', style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, height: 1.35, color: c.text2)),
              const SizedBox(height: 10),
              for (final r in records) LigneRecord(record: r, suivi: exercise.suivi, unite: u),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(margeEcran, 12.5, margeEcran, 22.5),
            child: BoutonPrincipal(label: 'Voir l’historique des records', onPressed: onHistorique),
          ),
        ),
      ],
    );
  }
}
