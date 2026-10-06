import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/data.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../seance/seance_paths.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import '../logic/exercise_notes.dart';
import '../logic/exercise_stats.dart';
import 'exercise_actions.dart';
import 'exercise_edit_page.dart';
import 'fiche/tab_apropos.dart';
import 'fiche/tab_historique.dart';
import 'fiche/tab_progres.dart';
import 'fiche/tab_records.dart';
import 'picker_page.dart';
import 'records_historique_page.dart';

/// Onglets de la fiche.
enum FicheTab {
  apropos('À propos'),
  historique('Historique'),
  progres('Progrès'),
  records('Records');

  const FicheTab(this.label);
  final String label;

  /// Lit `?onglet=` ; les anciens noms restent compris.
  static FicheTab parse(String? s) => switch (s) {
        'historique' => FicheTab.historique,
        'progres' || 'graphiques' => FicheTab.progres,
        'records' => FicheTab.records,
        _ => FicheTab.apropos,
      };
}

/// Ouvre la fiche par-dessus tout (navigateur racine), depuis n'importe où :
/// bibliothèque, routine ou séance en cours. [onRemplacer] branche le
/// raccourci « Remplacer » sur l'écran de celui qui ouvre la fiche (la
/// séance) ; sans lui, la fiche s'en charge.
Future<void> ouvrirFicheExercice(BuildContext context, String exerciseId, {FicheTab tab = FicheTab.apropos, VoidCallback? onRemplacer}) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => ExerciseDetailPage(exerciseId: exerciseId, initialTab: tab, onRemplacer: onRemplacer),
    ));

/// Fiche d'un exercice en page pleine.
class ExerciseDetailPage extends StatelessWidget {
  const ExerciseDetailPage({super.key, required this.exerciseId, this.initialTab = FicheTab.apropos, this.onRemplacer});

  final String exerciseId;
  final FicheTab initialTab;
  final VoidCallback? onRemplacer;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ExerciseRepo>();
    final e = repo.byId(exerciseId);
    if (!repo.loaded) {
      return const PageEntrainer(entete: EnTetePage(titre: 'Exercice'), child: SkeletonList(count: 5));
    }
    if (e == null) {
      return PageEntrainer(
        entete: const EnTetePage(titre: 'Exercice'),
        child: Vide(
          trait: Trait.loupe,
          titre: 'Exercice introuvable',
          message: 'Il a peut-être été supprimé. Ses séances restent dans l’historique.',
          action: 'Retour',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }
    return PageEntrainer(
      entete: EnTetePage(titre: e.nom, actions: ficheActions(context, e)),
      child: ExerciseDetailView(exercise: e, initialTab: initialTab, onRemplacer: onRemplacer),
    );
  }
}

/// Trois points de la fiche (réutilisés par le volet du Fold ouvert).
List<Widget> ficheActions(BuildContext context, Exercise e, {VoidCallback? onDeleted}) => [
      BoutonNu(trait: Trait.points, label: 'Plus d’actions', onTap: () => _menu(context, e, onDeleted)),
    ];

enum _Menu { entrainer, routine, modifier, variante, supprimer }

Future<void> _menu(BuildContext context, Exercise e, VoidCallback? onDeleted) async {
  final enCours = context.read<SessionRepo>().hasActive;
  final r = await showPanneauBas<_Menu>(
    context,
    titre: e.nom,
    builder: (context) {
      Widget ligne(_Menu m, Widget icone, String label, {bool rouge = false}) =>
          LigneAction(icone: icone, label: label, destructif: rouge, onTap: () => Navigator.pop(context, m));
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ligne(_Menu.entrainer, const TraitIcone(AppIcone.haltere, size: 25), enCours ? 'Ajouter à la séance en cours' : 'S’entraîner sur cet exercice'),
          ligne(_Menu.routine, const IconeTrait(Trait.plus, size: 25), 'Ajouter à une routine'),
          if (e.perso) ligne(_Menu.modifier, const IconeTrait(Trait.crayon, size: 25), 'Modifier'),
          ligne(_Menu.variante, const IconeTrait(Trait.dupliquer, size: 25), 'Créer une variante perso'),
          if (e.perso) ligne(_Menu.supprimer, const IconeTrait(Trait.corbeille, size: 25), 'Supprimer', rouge: true),
        ],
      );
    },
  );
  if (!context.mounted || r == null) return;
  switch (r) {
    case _Menu.entrainer:
      await ExerciseActions.entrainer(context, [e.id]);
    case _Menu.routine:
      await ExerciseActions.ajouterARoutine(context, e.id);
    case _Menu.modifier:
      await ExerciseEditPage.open(context, existing: e);
    case _Menu.variante:
      final copie = await ExerciseActions.dupliquer(context, e);
      if (!context.mounted) return;
      final modifiee = await ExerciseEditPage.open(context, existing: copie);
      if (context.mounted) await ouvrirFicheExercice(context, (modifiee ?? copie).id);
    case _Menu.supprimer:
      final ok = await ExerciseActions.supprimer(context, e);
      if (ok && context.mounted) {
        if (onDeleted != null) {
          onDeleted();
        } else {
          Navigator.of(context).maybePop();
        }
      }
  }
}

/// Texte partagé depuis la fiche : nom, muscles, étapes.
String exerciceEnTexte(Exercise e) {
  final b = StringBuffer()..writeln(e.nom.toUpperCase());
  if (e.musclesPrincipaux.isNotEmpty) b.writeln('Principal : ${e.musclesPrincipaux.map((m) => m.label).join(', ')}');
  if (e.musclesSecondaires.isNotEmpty) b.writeln('Secondaire : ${e.musclesSecondaires.map((m) => m.label).join(', ')}');
  b.writeln('Matériel : ${e.equipementLabel}');
  if (e.instructions.isNotEmpty) {
    b.writeln();
    for (final (i, t) in e.instructions.indexed) {
      b.writeln('${i + 1}. $t');
    }
  }
  b
    ..writeln()
    ..write('Partagé depuis Aesthetics');
  return b.toString();
}

/// Routines où un exercice est remplacé par un autre ; seules celles qui
/// changent sont rendues.
List<Routine> remplacerDansRoutines(List<Routine> routines, String ancien, String nouveau) => [
      for (final r in routines)
        if (r.exercices.any((x) => x.exerciseId == ancien))
          r.copyWith(exercices: [for (final x in r.exercices) x.exerciseId == ancien ? x.copyWith(exerciseId: nouveau) : x]),
    ];

/// « Remplacer » sans écran appelant : dans la séance en cours si l'exercice
/// y est, sinon dans les routines qui le contiennent.
Future<void> _remplacer(BuildContext context, Exercise e) async {
  final sessions = context.read<SessionRepo>();
  final routines = context.read<RoutineRepo>();
  final exercices = context.read<ExerciseRepo>();
  final dansSeance = sessions.active?.exercices.any((x) => x.exerciseId == e.id) ?? false;
  final concernees = routines.routines.where((r) => r.exercices.any((x) => x.exerciseId == e.id)).toList();
  if (!dansSeance && concernees.isEmpty) {
    Toasts.show(context, 'Cet exercice n’est ni dans ta séance en cours ni dans une routine.');
    return;
  }
  final id = await pickExercise(context, titre: 'Remplacer', remplace: e.id);
  if (id == null || id == e.id || !context.mounted) return;
  final nom = exercices.nameOf(id);
  if (dansSeance) {
    await sessions.mutateActive(
      (s) => s.copyWith(exercices: [for (final x in s.exercices) x.exerciseId == e.id ? x.copyWith(exerciseId: id) : x]),
    );
    if (context.mounted) Toasts.success(context, 'Remplacé par « $nom » dans la séance en cours.');
    return;
  }
  final ok = await showConfirmDialog(
    context,
    title: 'Remplacer dans ${concernees.length > 1 ? 'tes ${concernees.length} routines' : '« ${concernees.first.nom} »'} ?',
    message: '« ${e.nom} » laisse sa place à « $nom ». Tes séances passées ne changent pas.',
    confirmLabel: 'Remplacer',
  );
  if (!ok || !context.mounted) return;
  await routines.saveAll(remplacerDansRoutines(concernees, e.id, id));
  if (context.mounted) Toasts.success(context, 'Remplacé par « $nom ».');
}

/// Contenu à onglets de la fiche (page pleine ou volet de droite).
class ExerciseDetailView extends StatefulWidget {
  const ExerciseDetailView({super.key, required this.exercise, this.initialTab = FicheTab.apropos, this.onRemplacer});

  final Exercise exercise;
  final FicheTab initialTab;
  final VoidCallback? onRemplacer;

  @override
  State<ExerciseDetailView> createState() => _ExerciseDetailViewState();
}

class _ExerciseDetailViewState extends State<ExerciseDetailView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: FicheTab.values.length, vsync: this, initialIndex: widget.initialTab.index);
  List<WorkoutSession>? _ref;
  String? _refId;
  ExerciseStats? _stats;

  @override
  void didUpdateWidget(covariant ExerciseDetailView old) {
    super.didUpdateWidget(old);
    if (old.exercise.id != widget.exercise.id) _tabs.index = widget.initialTab.index;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  ExerciseStats _statsFor(SessionRepo sessions) {
    if (!identical(sessions.sessions, _ref) || _refId != widget.exercise.id || _stats == null) {
      _ref = sessions.sessions;
      _refId = widget.exercise.id;
      _stats = ExerciseStats(sessions.historyFor(widget.exercise.id));
    }
    return _stats!;
  }

  Future<void> _note() async {
    final e = widget.exercise;
    final notes = ExerciseNotes.of(context.read<Store>());
    final t = await showTextInputDialog(
      context,
      title: 'Ma note',
      initial: notes.noteOf(e.id) ?? '',
      hint: 'Réglage du siège, prise, sensations...',
      maxLines: 5,
      maxLength: 500,
    );
    if (t != null) await notes.set(e.id, t);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final stats = _statsFor(context.watch<SessionRepo>());
    void entrainer() => ExerciseActions.entrainer(context, [e.id]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OngletsFiche(controller: _tabs),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              TabAPropos(
                exercise: e,
                onPartager: () => SharePlus.instance.share(ShareParams(text: exerciceEnTexte(e), subject: e.nom)),
                onNote: _note,
                onRemplacer: widget.onRemplacer ?? () => _remplacer(context, e),
                onExercice: (x) => ouvrirFicheExercice(context, x.id),
              ),
              TabHistorique(exercise: e, stats: stats, onOpenSession: (s) => context.push(SeancePaths.detail(s.id)), onEntrainer: entrainer),
              TabProgres(exercise: e, stats: stats, onEntrainer: entrainer),
              TabRecords(
                exercise: e,
                stats: stats,
                onEntrainer: entrainer,
                onHistorique: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                  builder: (_) => RecordsHistoriquePage(exerciseId: e.id),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Onglets en texte de la fiche : l'actif en blanc, souligné de blanc.
class OngletsFiche extends StatelessWidget {
  const OngletsFiche({super.key, required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
        // Les quatre onglets tiennent toujours dans la largeur : sur un
        // écran étroit, ils se resserrent au lieu de couper « Records ».
        padding: const EdgeInsets.symmetric(horizontal: margeEcran),
        alignment: Alignment.bottomLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in FicheTab.values)
                Padding(
                  padding: EdgeInsets.only(right: t == FicheTab.values.last ? 0 : 22),
                  child: Semantics(
                    button: true,
                    selected: controller.index == t.index,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.animateTo(t.index),
                      child: Container(
                        padding: const EdgeInsets.only(top: 12.5, bottom: 11),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: controller.index == t.index ? c.text : c.text.withValues(alpha: 0), width: 3)),
                        ),
                        child: Text(
                          t.label,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppTokens.fontUi,
                            fontSize: 17,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: controller.index == t.index ? c.text : c.text2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
