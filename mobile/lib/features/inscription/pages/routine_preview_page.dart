import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../data/program_generator.dart';
import '../data/proposition.dart';

/// Vignette carrée d'un exercice sur fond clair, jamais étirée.
class ExoVignette extends StatelessWidget {
  const ExoVignette({super.key, required this.exercise, this.size = 52});

  final Exercise? exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final src = exercise?.media.thumbnail;
    Widget repli() => Icon(Icons.fitness_center_rounded, color: c.text3, size: size * 0.45);
    Widget image;
    if (src == null) {
      image = repli();
    } else if (src.startsWith('http')) {
      image = CachedNetworkImage(imageUrl: src, fit: BoxFit.contain, errorWidget: (_, _, _) => repli(), placeholder: (_, _) => const SizedBox.shrink());
    } else {
      image = Image.asset(src, fit: BoxFit.contain, errorBuilder: (_, _, _) => repli());
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.surface2, borderRadius: AppTokens.radius8),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: image,
    );
  }
}

String resumeSeries(RoutineExercise e) {
  if (e.series.isEmpty) return 'Aucune série';
  final s = e.series.first;
  final n = Fmt.pluriel(e.series.length, 'série');
  final cible = s.dureeSec != null ? Fmt.repos(s.dureeSec!) : (s.reps == null ? '' : '${s.repsLabel} reps');
  return [n, if (cible.isNotEmpty) cible, 'repos ${Fmt.repos(e.reposSec)}'].join(' · ');
}

/// Une séance du programme proposé : exercices, réglages, remplacements.
class RoutinePreviewPage extends StatelessWidget {
  const RoutinePreviewPage({super.key, required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: propositionCourante,
      builder: (context, _) {
        final p = propositionCourante.proposal;
        if (p == null || index < 0 || index >= p.seances.length) {
          return SubPageScaffold(
            title: 'Séance',
            body: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Séance introuvable',
              message: 'Le programme proposé a été recalculé ou fermé.',
              actionLabel: 'Revoir le programme',
              onAction: () => context.go('/bienvenue/programme'),
            ),
          );
        }
        return _Seance(index: index, seance: p.seances[index]);
      },
    );
  }
}

class _Seance extends StatelessWidget {
  const _Seance({required this.index, required this.seance});
  final int index;
  final ProposedRoutine seance;

  Future<void> _renommer(BuildContext context) async {
    final nom = await showTextInputDialog(context, title: 'Nom de la séance', initial: seance.nom, maxLength: 40);
    if (nom == null || nom.trim().isEmpty) return;
    propositionCourante.modifierSeance(index, (r) => r.nom = nom.trim());
  }

  Future<void> _actions(BuildContext context, int j) async {
    final n = seance.exercices.length;
    final choix = await showChoiceDialog<String>(
      context,
      title: context.read<ExerciseRepo>().nameOf(seance.exercices[j].exerciseId),
      options: [
        ('regler', 'Régler les séries et le repos'),
        ('remplacer', 'Remplacer par un autre exercice'),
        if (j > 0) ('monter', 'Monter'),
        if (j < n - 1) ('descendre', 'Descendre'),
        ('retirer', 'Retirer de la séance'),
      ],
    );
    if (choix == null || !context.mounted) return;
    switch (choix) {
      case 'regler':
        await _regler(context, j);
      case 'remplacer':
        await context.push('/bienvenue/programme/seance/$index/exercice/$j');
      case 'monter' || 'descendre':
        propositionCourante.modifierSeance(index, (r) {
          final l = [...r.exercices];
          final k = choix == 'monter' ? j - 1 : j + 1;
          final t = l[j];
          l[j] = l[k];
          l[k] = t;
          r.exercices = l;
        });
      case 'retirer':
        final ok = await showConfirmDialog(context, title: 'Retirer cet exercice ?', confirmLabel: 'Retirer', destructive: true);
        if (ok) propositionCourante.modifierSeance(index, (r) => r.exercices = [...r.exercices]..removeAt(j));
    }
  }

  Future<void> _regler(BuildContext context, int j) async {
    final e = seance.exercices[j];
    final r = await showDialog<RoutineExercise>(context: context, builder: (_) => _ReglageDialog(exercice: e));
    if (r == null) return;
    propositionCourante.modifierSeance(index, (s) {
      final l = [...s.exercices];
      l[j] = r;
      s.exercices = l;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<ExerciseRepo>();
    final intens = <Muscle, double>{};
    for (final e in seance.exercices) {
      final x = repo.byId(e.exerciseId);
      if (x == null) continue;
      for (final m in x.musclesSecondaires) {
        intens[m] = (intens[m] ?? 0) < 0.45 ? 0.45 : intens[m]!;
      }
      for (final m in x.musclesPrincipaux) {
        intens[m] = 1;
      }
    }
    final wide = context.isExpanded;
    final carte = AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Center(child: BodyMapDual(height: wide ? 420 : 240, labels: true, intensities: intens)),
    );
    final liste = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Exercices', trailing: LabelCount(Fmt.pluriel(seance.nbSeries, 'série'))),
        if (seance.exercices.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.playlist_add_rounded,
            title: 'Séance vide',
            message: 'Ajoute au moins un exercice, ou reviens au programme pour la recalculer.',
          ),
        for (var j = 0; j < seance.exercices.length; j++)
          Builder(builder: (context) {
            final e = seance.exercices[j];
            final x = repo.byId(e.exerciseId);
            return ListTileX(
              leading: ExoVignette(exercise: x),
              title: x?.nom ?? 'Exercice introuvable',
              subtitle: resumeSeries(e),
              subtitleColor: c.text2,
              onTap: () => _regler(context, j),
              trailing: IconButton(
                tooltip: 'Actions',
                icon: Icon(Icons.more_horiz_rounded, color: c.text),
                onPressed: () => _actions(context, j),
              ),
            );
          }),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
          child: PillButton(
            label: 'Ajouter un exercice',
            icon: Icons.add_rounded,
            variant: PillVariant.outline,
            expand: true,
            onPressed: () => context.push('/bienvenue/programme/seance/$index/exercice/ajouter'),
          ),
        ),
      ],
    );
    return SubPageScaffold(
      title: seance.nom,
      subtitle: '${Fmt.pluriel(seance.exercices.length, 'exercice')} · ${seance.dureeEstimeeMin} min environ',
      maxContentWidth: wide ? 1100 : Breakpoints.content,
      actions: [IconButton(tooltip: 'Renommer', icon: const Icon(Icons.edit_rounded), onPressed: () => _renommer(context))],
      body: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 420, child: Padding(padding: const EdgeInsets.all(AppTokens.gutter), child: carte)),
              Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [liste])),
            ])
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [Padding(padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter), child: carte), liste],
            ),
    );
  }
}

class _ReglageDialog extends StatefulWidget {
  const _ReglageDialog({required this.exercice});
  final RoutineExercise exercice;

  @override
  State<_ReglageDialog> createState() => _ReglageDialogState();
}

class _ReglageDialogState extends State<_ReglageDialog> {
  late int series = widget.exercice.series.length.clamp(1, 10);
  late int reps = widget.exercice.series.firstOrNull?.reps ?? 10;
  late int repsMax = widget.exercice.series.firstOrNull?.repsMax ?? reps;
  late int duree = widget.exercice.series.firstOrNull?.dureeSec ?? 0;
  late int repos = widget.exercice.reposSec;

  bool get _enDuree => duree > 0;

  @override
  Widget build(BuildContext context) {
    final nom = context.read<ExerciseRepo>().nameOf(widget.exercice.exerciseId);
    Widget ligne(String l, Widget w) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [Expanded(child: Text(l, style: AppType.rowTitle())), w]),
        );
    return AlertDialog(
      title: Text(nom),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ligne('Séries', NumberStepper(value: series.toDouble(), min: 1, max: 10, compact: true, onChanged: (v) => setState(() => series = v.round()))),
          if (_enDuree)
            ligne('Durée', NumberStepper(value: duree.toDouble(), min: 10, max: 600, step: 5, unit: 's', compact: true, onChanged: (v) => setState(() => duree = v.round())))
          else ...[
            ligne('Reps minimum', NumberStepper(value: reps.toDouble(), min: 1, max: 50, compact: true, onChanged: (v) => setState(() {
                  reps = v.round();
                  if (repsMax < reps) repsMax = reps;
                }))),
            ligne('Reps maximum', NumberStepper(value: repsMax.toDouble(), min: reps.toDouble(), max: 60, compact: true, onChanged: (v) => setState(() => repsMax = v.round()))),
          ],
          ligne('Repos', NumberStepper(value: repos.toDouble(), min: 0, max: 600, step: 15, unit: 's', compact: true, onChanged: (v) => setState(() => repos = v.round()))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            final s = _enDuree ? PlannedSet(dureeSec: duree) : PlannedSet(reps: reps, repsMax: repsMax == reps ? null : repsMax);
            Navigator.pop(context, widget.exercice.copyWith(series: List.filled(series, s), reposSec: repos));
          },
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

/// Choisir un exercice pour remplacer [position] ou en ajouter un (position nulle).
class ExercicePickerPage extends StatefulWidget {
  const ExercicePickerPage({super.key, required this.index, this.position});
  final int index;
  final int? position;

  @override
  State<ExercicePickerPage> createState() => _ExercicePickerPageState();
}

class _ExercicePickerPageState extends State<ExercicePickerPage> {
  final _recherche = TextEditingController();
  bool _monMateriel = true;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  List<Exercise> _resultats(ExerciseRepo repo, ProposedRoutine s) {
    final materiel = propositionCourante.profil?.materiel ?? const {Materiel.salleComplete};
    final dispo = _monMateriel ? materiel : const {Materiel.salleComplete};
    final q = _recherche.text.trim();
    final dejaLa = s.exercices.map((e) => e.exerciseId).toSet();
    final pos = widget.position;
    if (q.isEmpty && pos != null) {
      return ProgramGenerator(repo).alternatives(s.exercices[pos].exerciseId, dispo, max: 60).where((e) => !dejaLa.contains(e.id)).toList();
    }
    final muscles = q.isEmpty ? s.muscles(repo) : <Muscle>{};
    return repo
        .search(query: q, muscles: muscles, principauxSeulement: true)
        .where((e) => ProgramGenerator.disponible(e, dispo) && !dejaLa.contains(e.id) && e.categorie != 'etirements')
        .take(200)
        .toList();
  }

  void _choisir(Exercise x) {
    final pos = widget.position;
    final profil = propositionCourante.profil;
    propositionCourante.modifierSeance(widget.index, (r) {
      final l = [...r.exercices];
      if (pos != null) {
        final ancien = l[pos];
        l[pos] = RoutineExercise(id: '${ancien.id}-${x.id}', exerciseId: x.id, series: ancien.series, reposSec: ancien.reposSec);
      } else {
        final modele = l.lastOrNull;
        final suivi = x.suivi;
        final serie = suivi == ExerciseTracking.duree ? const PlannedSet(dureeSec: 45) : const PlannedSet(reps: 10, repsMax: 12);
        l.add(RoutineExercise(
          id: 'e${l.length}-${x.id}',
          exerciseId: x.id,
          series: List.filled(profil?.niveau == Niveau.debutant ? 2 : 3, serie),
          reposSec: modele?.reposSec ?? 90,
        ));
      }
      r.exercices = l;
    });
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ExerciseRepo>();
    final p = propositionCourante.proposal;
    if (p == null || widget.index >= p.seances.length || (widget.position != null && widget.position! >= p.seances[widget.index].exercices.length)) {
      return SubPageScaffold(
        title: 'Choisir un exercice',
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Séance introuvable', actionLabel: 'Revoir le programme', onAction: () => context.go('/bienvenue/programme')),
      );
    }
    final s = p.seances[widget.index];
    final res = _resultats(repo, s);
    final pos = widget.position;
    return SubPageScaffold(
      title: pos == null ? 'Ajouter un exercice' : 'Remplacer',
      subtitle: pos == null ? s.nom : repo.nameOf(s.exercices[pos].exerciseId),
      closeIcon: true,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 4, AppTokens.gutter, 8),
          child: SearchField(controller: _recherche, hint: 'Chercher un exercice', onChanged: (_) => setState(() {})),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 0, AppTokens.gutter, 8),
          child: Row(children: [
            ChipFilter(label: 'Mon matériel seulement', icon: Icons.fitness_center_rounded, selected: _monMateriel, onTap: () => setState(() => _monMateriel = !_monMateriel)),
            const Spacer(),
            LabelCount(Fmt.pluriel(res.length, 'résultat')),
          ]),
        ),
        Expanded(
          child: !repo.loaded
              ? const SkeletonList()
              : res.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucun exercice',
                      message: _monMateriel ? 'Rien avec ton matériel. Élargis la recherche à tout le matériel.' : 'Essaie un autre mot.',
                      actionLabel: _monMateriel ? 'Tout le matériel' : null,
                      onAction: _monMateriel ? () => setState(() => _monMateriel = false) : null,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: res.length,
                      itemBuilder: (context, i) {
                        final x = res[i];
                        return ListTileX(
                          leading: ExoVignette(exercise: x),
                          title: x.nom,
                          subtitle: '${x.musclesPrincipaux.map((m) => m.label).join(', ')} · ${x.equipementLabel}',
                          onTap: () => _choisir(x),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
