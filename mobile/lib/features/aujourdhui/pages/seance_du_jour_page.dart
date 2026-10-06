import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/routines/logic/suggestion.dart' show rangDansCycle;
import '../logic/resume_jour.dart';
import '../routes.dart';
import '../widgets/actions.dart';
import '../widgets/commun.dart';

/// Détail de la séance du jour : muscles, exercices, programme, et choix
/// d'une autre routine.
class SeanceDuJourPage extends StatefulWidget {
  const SeanceDuJourPage({super.key});

  @override
  State<SeanceDuJourPage> createState() => _SeanceDuJourPageState();
}

class _SeanceDuJourPageState extends State<SeanceDuJourPage> {
  String? _choisieId;

  @override
  Widget build(BuildContext context) {
    final routines = context.watch<RoutineRepo>();
    final programs = context.watch<ProgramRepo>();
    final sessions = context.watch<SessionRepo>();
    final ex = context.watch<ExerciseRepo>();
    final prop = proposerSeance(routines: routines, programs: programs, sessions: sessions, exercises: ex);
    final choisie = (_choisieId == null ? null : routines.byId(_choisieId!)) ?? prop?.routine;

    if (choisie == null) {
      return SubPageScaffold(
        title: 'Séance du jour',
        body: Center(
          child: EmptyState(
            icon: Icons.fitness_center_rounded,
            iconColor: context.colors.training,
            title: 'Rien de prévu pour l\'instant',
            message: 'Crée une routine pour que l\'appli te propose ta séance chaque jour, ou lance une séance libre.',
            actionLabel: 'Créer une routine',
            onAction: () => context.push(AujourdhuiPaths.nouvelleRoutine),
            secondaryLabel: 'Séance libre',
            onSecondary: () => demarrerSeanceLibre(context),
          ),
        ),
      );
    }

    final estProposee = choisie.id == prop?.routine.id;
    final programme = programs.active;
    final programId = estProposee && prop?.origine == OrigineProposition.programme ? programme?.id : null;
    final muscles = musclesRoutine(choisie, ex);
    final large = context.isWide;

    final tete = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (muscles.isNotEmpty) ...[
            Center(child: CorpsDouble(intensities: muscles, height: large ? 300 : 240, labels: true, spacing: 16)),
            const SizedBox(height: 16),
          ],
          Text(choisie.nom, style: AppType.screenTitle()),
          const SizedBox(height: 4),
          Text(
            estProposee ? prop!.raison : 'Choisie à la place de la séance proposée',
            style: AppType.rowSubtitle(color: estProposee && programId != null ? context.colors.accent : null),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TagPill(Fmt.pluriel(choisie.exercices.length, 'exercice'), icon: Icons.fitness_center_rounded, color: context.colors.training),
              TagPill(Fmt.pluriel(choisie.nbSeries, 'série'), color: context.colors.training),
              TagPill('${choisie.dureeEstimeeMin} min environ', icon: Icons.schedule_rounded, color: context.colors.training),
              if (sessions.lastForRoutine(choisie.id) case final d?)
                TagPill('Faite ${Fmt.ilYa(d.debut)}', icon: Icons.history_rounded),
            ],
          ),
          if (choisie.notes != null && choisie.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(choisie.notes!, style: AppType.rowSubtitle(color: context.colors.text2)),
          ],
          if (muscles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in muscles.entries.where((e) => e.value >= 1)) TagPill(m.key.label, color: context.colors.muscle),
                for (final m in muscles.entries.where((e) => e.value < 1)) TagPill(m.key.label),
              ],
            ),
          ],
        ],
      ),
    );

    final exercices = TileGroup(
      margin: EdgeInsets.zero,
      label: 'Exercices',
      labelTrailing: LabelCount(Fmt.pluriel(choisie.exercices.length, 'exercice')),
      children: [
        if (choisie.exercices.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text('Cette routine est vide. Ajoute-lui des exercices dans l\'onglet Entraînement.', style: AppType.rowSubtitle()),
          ),
        for (final re in choisie.exercices) _LigneExercice(re: re),
      ],
    );

    final autres = routines.routines.where((r) => r.id != choisie.id && r.exercices.isNotEmpty).toList();
    final cycle = programme == null
        ? const <Routine>[]
        : [for (final id in programme.routineIds) ?routines.byId(id)];
    final prochain = rangDansCycle([for (final r in cycle) r.id], sessions.sessions, depuis: programme?.debuteLe);

    final cote = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (programme != null) ...[
          AppCard(
            label: 'Programme',
            labelTrailing: const ChevronCarte(),
            onTap: () => context.push(AujourdhuiPaths.programmes),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(programme.nom, style: AppType.rowTitle().copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  'Semaine ${(programme.semaineCourante + 1).clamp(1, programme.dureeSemaines)} sur ${programme.dureeSemaines} · ${programme.joursParSemaine} séances par semaine',
                  style: AppType.rowSubtitle(),
                ),
                const SizedBox(height: 12),
                ProgressBar(
                  value: programme.avancement,
                  label: '${programme.seancesFaites} séances faites',
                  trailing: 'sur ${programme.seancesTotal}',
                ),
                if (cycle.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('CYCLE', style: AppType.overline()),
                  const SizedBox(height: 4),
                  for (var i = 0; i < cycle.length; i++)
                    ListTileX(
                      dense: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      leading: IconHalo(
                        icon: i == prochain ? Icons.play_arrow_rounded : Icons.circle_outlined,
                        color: i == prochain ? context.colors.accent : context.colors.training,
                        size: 34,
                        glow: false,
                      ),
                      title: cycle[i].nom,
                      subtitle: i == prochain ? 'Prochaine séance' : '${cycle[i].exercices.length} exercices',
                      subtitleColor: i == prochain ? context.colors.accent : null,
                      selected: cycle[i].id == choisie.id,
                      onTap: () => setState(() => _choisieId = cycle[i].id),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        TileGroup(
          margin: EdgeInsets.zero,
          label: 'Faire une autre séance',
          labelTrailing: AccentLink(label: 'Mes routines', onTap: () => context.go(Paths.entrainer)),
          children: [
            if (!estProposee && prop != null)
              ListTileX(
                leading: IconHalo(icon: Icons.undo_rounded, color: context.colors.accent, size: 38),
                title: 'Revenir à la séance proposée',
                subtitle: prop.routine.nom,
                onTap: () => setState(() => _choisieId = null),
              ),
            for (final r in autres.take(8))
              ListTileX(
                leading: IconHalo.domain(AppDomain.entrainement, icon: Icons.list_alt_rounded, size: 38),
                title: r.nom,
                subtitle: [
                  Fmt.pluriel(r.exercices.length, 'exercice'),
                  if (sessions.lastForRoutine(r.id) case final d?) Fmt.ilYa(d.debut) else 'jamais faite',
                ].join(' · '),
                showChevron: true,
                onTap: () => setState(() => _choisieId = r.id),
              ),
            ListTileX(
              leading: IconHalo(icon: Icons.bolt_rounded, color: context.colors.training, size: 38),
              title: 'Séance libre',
              subtitle: 'Tu ajoutes les exercices au fur et à mesure',
              onTap: () => demarrerSeanceLibre(context),
            ),
          ],
        ),
      ],
    );

    final bouton = PillButton(
      label: sessions.hasActive ? 'Démarrer (une séance est ouverte)' : 'Démarrer ${choisie.nom}',
      icon: Icons.play_arrow_rounded,
      size: PillSize.large,
      expand: true,
      onPressed: choisie.exercices.isEmpty ? null : () => demarrerRoutine(context, choisie, programId: programId),
    );

    return SousPage(
      title: 'Séance du jour',
      subtitle: Fmt.jourCap(DateTime.now()),
      maxContentWidth: large ? 1100 : Breakpoints.content,
      bottomBar: bouton,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (large)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: [tete, const SizedBox(height: 12), exercices])),
                const SizedBox(width: 12),
                Expanded(child: cote),
              ],
            )
          else ...[
            tete,
            const SizedBox(height: 12),
            exercices,
            const SizedBox(height: 12),
            cote,
          ],
        ],
      ),
    );
  }
}

class _LigneExercice extends StatelessWidget {
  const _LigneExercice({required this.re});
  final RoutineExercise re;

  @override
  Widget build(BuildContext context) {
    final ex = context.watch<ExerciseRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final e = ex.byId(re.exerciseId);
    final normales = re.series.where((s) => s.type != SetType.echauffement).toList();
    final reps = normales.map((s) => s.repsLabel).where((s) => s.isNotEmpty).toSet();
    final parts = <String>[
      Fmt.pluriel(normales.length, 'série'),
      if (reps.length == 1) '${reps.first} rép.',
      'repos ${Fmt.repos(re.reposSec)}',
    ];
    final last = context.watch<SessionRepo>().lastFor(re.exerciseId);
    final best = last?.seriesFaites.where((s) => s.type.counts && (s.poids ?? 0) > 0).fold<WorkoutSet?>(
          null,
          (a, s) => a == null || (s.poids ?? 0) > (a.poids ?? 0) ? s : a,
        );
    return ListTileX(
      leading: MiniatureExercice(exercise: e, size: 44),
      title: ex.nameOf(re.exerciseId),
      subtitle: [parts.join(' · '), if (re.supersetId != null) 'superset'].join(' · '),
      value: best == null ? null : '${Fmt.poids(best.poids, u)} × ${best.reps ?? 0}',
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      onTap: () => context.push(AujourdhuiPaths.ficheExercice(re.exerciseId)),
    );
  }
}
