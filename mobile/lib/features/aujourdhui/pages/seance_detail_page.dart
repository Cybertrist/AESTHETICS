import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/resume_jour.dart';
import '../widgets/actions.dart';
import '../widgets/commun.dart';

/// Détail d'une séance passée : chiffres, muscles, séries, records.
class SeanceDetailPage extends StatelessWidget {
  const SeanceDetailPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionRepo>();
    final ex = context.watch<ExerciseRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final s = sessions.byId(sessionId);
    if (s == null) {
      return SubPageScaffold(
        title: 'Séance',
        body: Center(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Séance introuvable',
            message: 'Elle a peut-être été supprimée.',
            actionLabel: 'Retour',
            onAction: () => context.pop(),
          ),
        ),
      );
    }
    final records = historiqueRecords(sessions.sessions).where((r) => r.session.id == s.id).toList();
    final muscles = musclesSeance(s, ex);
    final routine = s.routineId == null ? null : context.watch<RoutineRepo>().byId(s.routineId!);

    Widget stat(String label, String v) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: AppType.overline()),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: AppType.number(22))),
            ],
          ),
        );

    return SousPage(
      title: s.nom,
      subtitle: '${Fmt.jourCap(s.debut)} à ${Fmt.heure(s.debut)}',
      haloColor: c.training,
      bottomBar: routine == null || routine.exercices.isEmpty
          ? null
          : PillButton(
              label: 'Refaire cette séance',
              icon: Icons.replay_rounded,
              size: PillSize.large,
              expand: true,
              onPressed: () => demarrerRoutine(context, routine),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    stat('Durée', s.fin == null ? '-' : Fmt.duree(s.duree)),
                    stat('Volume', Fmt.volume(s.volume, u)),
                    stat('Séries', '${s.nbSeriesFaites}'),
                  ],
                ),
                if (muscles.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Center(child: CorpsDouble(intensities: muscles, height: 220, labels: true, spacing: 16)),
                ],
                if (s.ressenti != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('Ressenti', style: AppType.rowSubtitle()),
                      const SizedBox(width: 8),
                      for (var i = 1; i <= 5; i++)
                        Icon(i <= s.ressenti! ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: c.weight),
                    ],
                  ),
                ],
                if (s.notes != null && s.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(s.notes!, style: AppType.rowSubtitle(color: c.text2)),
                ],
              ],
            ),
          ),
          if (records.isNotEmpty) ...[
            const SizedBox(height: 12),
            TileGroup(
              margin: EdgeInsets.zero,
              label: 'Records battus',
              labelTrailing: LabelCount('${records.length}'),
              children: [
                for (final r in records)
                  ListTileX(
                    leading: IconHalo(icon: Icons.emoji_events_rounded, color: c.weight, size: 38),
                    title: ex.nameOf(r.record.exerciseId),
                    subtitle: r.record.type.label,
                    value: valeurRecord(r.record, u),
                    valueColor: c.accent,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          for (final e in s.exercices) ...[
            _CarteExercice(e: e, exercise: ex.byId(e.exerciseId), nom: ex.nameOf(e.exerciseId), unite: u),
            const SizedBox(height: 10),
          ],
          if (s.exercices.isEmpty)
            const EmptyState(compact: true, icon: Icons.fitness_center_rounded, title: 'Aucune série enregistrée'),
        ],
      ),
    );
  }
}

class _CarteExercice extends StatelessWidget {
  const _CarteExercice({required this.e, required this.exercise, required this.nom, required this.unite});

  final SessionExercise e;
  final Exercise? exercise;
  final String nom;
  final UnitePoids unite;

  String _serie(WorkoutSet s) {
    final parts = <String>[];
    if (s.poids != null && s.poids! > 0) parts.add(Fmt.poids(s.poids, unite));
    if (s.reps != null) parts.add('${s.reps} rép.');
    if (s.dureeSec != null) parts.add(Fmt.duree(Duration(seconds: s.dureeSec!)));
    if (s.distanceM != null) parts.add(Affichage.distance(s.distanceM!));
    return parts.isEmpty ? '-' : parts.join(' × ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    var n = 0;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MiniatureExercice(exercise: exercise, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text(nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.rowTitle())),
              if (e.volume > 0) Text(Fmt.volume(e.volume, unite), style: AppType.rowSubtitle()),
            ],
          ),
          const SizedBox(height: 10),
          for (final s in e.series)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      s.type == SetType.normale ? '${++n}' : s.type.short,
                      style: AppType.rowValue(color: s.type == SetType.normale ? c.text3 : c.accent).copyWith(fontSize: 13),
                    ),
                  ),
                  Expanded(child: Text(_serie(s), style: AppType.rowValue().copyWith(fontSize: 14))),
                  if (s.rpe != null) Text('RPE ${Fmt.n(s.rpe)}', style: AppType.rowSubtitle()),
                  if (s.type == SetType.echauffement) ...[const SizedBox(width: 8), Text('échauffement', style: AppType.rowSubtitle())],
                ],
              ),
            ),
          if (e.notes != null && e.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(e.notes!, style: AppType.rowSubtitle(color: c.text2)),
          ],
        ],
      ),
    );
  }
}
