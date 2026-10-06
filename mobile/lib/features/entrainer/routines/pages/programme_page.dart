import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../commun/elements.dart';
import '../../commun/palette.dart';
import '../../commun/traits.dart';
import '../logic/idees.dart' show nomLibre;
import '../logic/program_plan.dart';
import '../logic/routine_stats.dart';
import '../widgets/photo_programme.dart';
import '../widgets/ligne_routine.dart';

/// Routines d'un programme, sans doublon et dans l'ordre du cycle.
List<Routine> routinesDuProgramme(Program p, RoutineRepo repo) => [
      for (final id in p.routineIds.toSet()) ?repo.byId(id),
    ];

/// Page d'un programme : la couverture sur un fond flou, les boutons ronds,
/// « Voir plus », le nom en grand, puis les routines, avec « Ajouter une
/// routine au programme » en première ligne.
class ProgrammePage extends StatefulWidget {
  const ProgrammePage({super.key, required this.programId});
  final String programId;

  @override
  State<ProgrammePage> createState() => _ProgrammePageState();
}

enum _Action { modifier, suivre, pause, recommencer, dupliquer, supprimer }

enum _Ajout { creer, choisir }

class _ProgrammePageState extends State<ProgrammePage> {
  bool _plus = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<ProgramRepo>();
    final routines = context.watch<RoutineRepo>();
    final prog = repo.byId(widget.programId);
    if (prog == null) {
      return PageEntrainer(
        entete: const EnTetePage(titre: 'Programme'),
        child: Vide(
          trait: Trait.loupe,
          titre: 'Programme introuvable',
          message: 'Il a peut-être été supprimé.',
          action: 'Voir les programmes',
          onAction: () => context.go('/entrainer?onglet=programmes'),
        ),
      );
    }
    final liste = routinesDuProgramme(prog, routines);
    final voile = c.bg.withValues(alpha: 0.6);
    final haut = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: c.bg,
      body: TexteNet(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: largeurContenu),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              _Hero(
                child: Padding(
                  padding: EdgeInsets.only(top: haut + 12.5, bottom: 7.5),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          children: [
                            BoutonRond(icone: const IconeTrait(Trait.retour, size: 22.5), label: 'Retour', fond: voile, onTap: () => Navigator.of(context).maybePop()),
                            const Spacer(),
                            BoutonRond(icone: const IconeTrait(Trait.partager, size: 22.5), label: 'Partager', fond: voile, onTap: () => _partager(prog)),
                            const SizedBox(width: 10),
                            BoutonRond(icone: const IconeTrait(Trait.points, size: 22.5), label: 'Actions sur le programme', fond: voile, onTap: () => _menu(prog)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      CouvertureDuProgramme(prog),
                      const SizedBox(height: 10),
                      Semantics(
                        button: true,
                        child: InkWell(
                          onTap: () => setState(() => _plus = !_plus),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
                            child: Column(
                              children: [
                                Text(
                                  _plus ? 'VOIR MOINS' : 'VOIR PLUS',
                                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13, height: 1.35, fontWeight: FontWeight.w700, letterSpacing: 1.05, color: c.text2),
                                ),
                                RotatedBox(quarterTurns: _plus ? 2 : 0, child: IconeTrait(Trait.chevronBas, size: 17.5, color: c.text2)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_plus) _Details(prog: prog),
              Padding(
                padding: const EdgeInsets.fromLTRB(margeEcran, 5, margeEcran, 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        prog.nom,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 25, height: 1.3, fontWeight: FontWeight.w800, color: c.text),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12.5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: margeEcran),
                child: InkWell(
                  onTap: () => _ajouter(prog),
                  borderRadius: BorderRadius.circular(15),
                  child: Row(
                    children: [
                      const Tuile(taille: 68, rayon: 15, child: IconeTrait(Trait.plus, size: 25)),
                      const SizedBox(width: 15),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('Ajouter une routine au programme', maxLines: 1, style: TexteEntrainer.ligne(context).copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final (i, r) in liste.indexed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(margeEcran, 12.5, margeEcran, 0),
                  child: LigneRoutine(routine: r, rang: i, programId: prog.id),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _ajouter(Program p) async {
    final routines = context.read<RoutineRepo>();
    final programmes = context.read<ProgramRepo>();
    final libres = routines.routines.where((r) => !p.routineIds.contains(r.id)).toList();
    var choix = _Ajout.creer;
    if (libres.isNotEmpty) {
      final r = await showPanneauBas<_Ajout>(
        context,
        titre: 'Ajouter une routine',
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LigneAction(icone: const IconeTrait(Trait.plus, size: 25), label: 'Créer une routine', onTap: () => Navigator.pop(context, _Ajout.creer)),
            LigneAction(icone: const IconeTrait(Trait.liste, size: 25), label: 'Choisir une de mes routines', onTap: () => Navigator.pop(context, _Ajout.choisir)),
          ],
        ),
      );
      if (r == null || !mounted) return;
      choix = r;
    }
    String? id;
    if (choix == _Ajout.creer) {
      // L'éditeur rend l'identifiant de la routine créée.
      final cree = await context.push<Object?>('/entrainer/routines/nouvelle?retour=1');
      id = cree is String ? cree : null;
    } else {
      id = await showPanneauBas<String>(
        context,
        titre: 'Mes routines',
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in libres)
              ChoixPanneau(label: r.nom, detail: Fmt.pluriel(r.exercices.length, 'exercice'), onTap: () => Navigator.pop(context, r.id)),
          ],
        ),
      );
    }
    if (id == null || !mounted) return;
    final actuel = programmes.byId(p.id);
    if (actuel == null || actuel.routineIds.contains(id)) return;
    await programmes.save(actuel.copyWith(routineIds: [...actuel.routineIds, id]));
    if (mounted) Toasts.success(context, 'Routine ajoutée au programme.');
  }

  Future<void> _partager(Program p) async {
    final routines = context.read<RoutineRepo>();
    final ex = context.read<ExerciseRepo>();
    final unite = context.read<ProfileRepo>().unite;
    final b = StringBuffer()
      ..writeln(p.nom.toUpperCase())
      ..writeln('${p.dureeSemaines} semaines · ${p.joursParSemaine} séances par semaine');
    if (p.description != null && p.description!.trim().isNotEmpty) b.writeln(p.description);
    for (final r in routinesDuProgramme(p, routines)) {
      b
        ..writeln()
        ..writeln('----------')
        ..writeln(routineEnTexte(r, ex, unite).replaceAll('\n\nPartagé depuis Aesthetics', ''));
    }
    b
      ..writeln()
      ..write('Partagé depuis Aesthetics');
    await SharePlus.instance.share(ShareParams(text: b.toString(), subject: p.nom));
  }

  Future<void> _menu(Program p) async {
    final a = await showPanneauBas<_Action>(
      context,
      titre: p.nom,
      builder: (context) {
        Widget ligne(_Action a, Widget icone, String label, {bool rouge = false}) =>
            LigneAction(icone: icone, label: label, destructif: rouge, onTap: () => Navigator.pop(context, a));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ligne(_Action.modifier, const IconeTrait(Trait.crayon, size: 25), 'Modifier le programme'),
            if (p.actif)
              ligne(_Action.pause, const IconeTrait(Trait.pause, size: 25), 'Mettre en pause')
            else
              ligne(_Action.suivre, const IconeTrait(Trait.lectureCercle, size: 25), 'Suivre ce programme'),
            if (p.seancesFaites > 0) ligne(_Action.recommencer, const IconeTrait(Trait.remplacer, size: 25), 'Recommencer au début'),
            ligne(_Action.dupliquer, const IconeTrait(Trait.dupliquer, size: 25), 'Dupliquer'),
            ligne(_Action.supprimer, const IconeTrait(Trait.corbeille, size: 25), 'Supprimer', rouge: true),
          ],
        );
      },
    );
    if (a == null || !mounted) return;
    final repo = context.read<ProgramRepo>();
    final plans = ProgramPlanRepo.of(context.read<Store>());
    switch (a) {
      case _Action.modifier:
        context.push('/entrainer/programmes/${p.id}/modifier');
      case _Action.suivre:
        final autre = repo.active;
        if (autre != null && autre.id != p.id) {
          final ok = await showConfirmDialog(
            context,
            title: 'Changer de programme ?',
            message: '« ${autre.nom} » sera mis en pause, son avancement est gardé.',
            confirmLabel: 'Suivre « ${p.nom} »',
          );
          if (!ok || !mounted) return;
        }
        await repo.activate(p.id);
        if (mounted) Toasts.success(context, 'Tu suis « ${p.nom} ».');
      case _Action.pause:
        await repo.deactivate(p.id);
        if (mounted) Toasts.show(context, 'Programme en pause.', actionLabel: 'Reprendre', onAction: () => repo.activate(p.id));
      case _Action.recommencer:
        final ok = await showConfirmDialog(
          context,
          title: 'Recommencer au début ?',
          message: 'L’avancement repart à la semaine 1. Tes séances restent dans l’historique.',
          confirmLabel: 'Recommencer',
        );
        if (!ok || !mounted) return;
        await repo.activate(p.id, restart: true);
      case _Action.dupliquer:
        final copie = await repo.save(Program(
          id: '',
          nom: nomLibre('${p.nom} (copie)', {for (final x in repo.programs) x.nom}),
          description: p.description,
          dureeSemaines: p.dureeSemaines,
          joursParSemaine: p.joursParSemaine,
          routineIds: p.routineIds,
          niveau: p.niveau,
          objectif: p.objectif,
          creeLe: DateTime.now(),
        ));
        await plans.save(plans.planFor(p.id).copyWith(programId: copie.id));
        if (!mounted) return;
        context.pushReplacement('/entrainer/programmes/${copie.id}');
      case _Action.supprimer:
        final ok = await showConfirmDialog(
          context,
          title: 'Supprimer « ${p.nom} » ?',
          message: 'Ses routines restent dans le volet Routines et l’historique est conservé.',
          confirmLabel: 'Supprimer',
          destructive: true,
        );
        if (!ok || !mounted) return;
        await repo.delete(p.id);
        await plans.remove(p.id);
        if (!mounted) return;
        Toasts.show(context, 'Programme supprimé.');
        Navigator.of(context).maybePop();
    }
  }
}

/// Fond flou de l'en-tête : des taches douces sur un dégradé vers le noir.
class _Hero extends StatelessWidget {
  const _Hero({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tache(Alignment centre, double rayon, Color couleur, double alpha) => Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: centre, radius: rayon, colors: [couleur.withValues(alpha: alpha), couleur.withValues(alpha: 0)]),
            ),
          ),
        );
    final taches = PaletteEntrainer.heroTaches;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [PaletteEntrainer.heroHaut, c.bg]),
            ),
          ),
        ),
        tache(const Alignment(-0.6, -0.1), 0.62, taches[0], 0.5),
        tache(const Alignment(0.68, -0.24), 0.6, taches[1], 0.55),
        tache(const Alignment(0, -0.84), 0.7, taches[2], 0.5),
        // Le bas se fond dans le noir de la page.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.bg.withValues(alpha: 0), c.bg.withValues(alpha: 0), c.bg],
                stops: const [0, 0.55, 0.92],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// « Voir plus » : la description, le rythme, la progression et l'avancement.
class _Details extends StatelessWidget {
  const _Details({required this.prog});
  final Program prog;

  @override
  Widget build(BuildContext context) {
    final plans = ProgramPlanRepo.of(context.read<Store>());
    final gris = TexteEntrainer.detail(context).copyWith(fontSize: 15);
    return ListenableBuilder(
      listenable: plans,
      builder: (context, _) {
        final plan = plans.planFor(prog.id);
        final lignes = <(String, String)>[
          ('Rythme', '${prog.joursParSemaine} séances par semaine · ${prog.dureeSemaines} semaines'),
          if (prog.debuteLe != null) ('Avancement', 'Semaine ${(prog.semaineCourante + 1).clamp(1, prog.dureeSemaines < 1 ? 1 : prog.dureeSemaines)} sur ${prog.dureeSemaines} · ${Fmt.pluriel(prog.seancesFaites, 'séance faite', 'séances faites')}'),
          ('Progression', plan.progression.label),
          if (plan.dechargeToutesLes > 0) ('Décharge', 'Une semaine légère toutes les ${plan.dechargeToutesLes} semaines'),
          if (plan.jours.isNotEmpty) ('Jours', plan.jours.map((j) => joursAbreges[(j - 1).clamp(0, 6)]).join(', ')),
          if (prog.objectif != null && prog.objectif!.isNotEmpty) ('Objectif', prog.objectif!),
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(margeEcran, 6, margeEcran, 14),
          child: Carte(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prog.description != null && prog.description!.trim().isNotEmpty) ...[
                  Text(prog.description!.trim(), style: gris.copyWith(color: context.colors.text, height: 1.45)),
                  const SizedBox(height: 12),
                ],
                for (final (titre, valeur) in lignes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 110, child: Text(titre, style: gris)),
                        Expanded(child: Text(valeur, style: gris.copyWith(color: context.colors.text))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
