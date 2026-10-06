import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/bibliotheque/bibliotheque.dart';
import '../logic/analyse.dart';
import '../logic/editeur.dart';
import '../widgets/exercice_carte.dart';
import '../widgets/habillage.dart';
import '../widgets/pages.dart';
import '../widgets/panneaux.dart';
import 'disques_page.dart';
import 'reordonner_page.dart';

/// Modification d'une séance passée : infos, exercices, séries. Même
/// habillage que « Terminer la séance » : lignes encadrées, bouton blanc.
class ModifierPage extends StatefulWidget {
  const ModifierPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<ModifierPage> createState() => _ModifierPageState();
}

class _ModifierPageState extends State<ModifierPage> {
  EditeurBrouillon? _ed;
  bool _enregistrement = false;
  bool _quitte = false;

  @override
  void initState() {
    super.initState();
    final repo = context.read<SessionRepo>();
    final s = repo.byId(widget.sessionId);
    if (s != null && !s.enCours) _ed = EditeurBrouillon(repo, s);
  }

  @override
  void dispose() {
    _ed?.dispose();
    super.dispose();
  }

  /// Séries de la dernière fois avant cette séance.
  List<WorkoutSet>? _avant(SessionRepo repo, String exerciseId, DateTime debut) {
    for (final s in repo.sessions) {
      if (s.id == widget.sessionId || !s.debut.isBefore(debut)) continue;
      for (final e in s.exercices) {
        if (e.exerciseId == exerciseId && e.seriesFaites.isNotEmpty) return e.seriesFaites;
      }
    }
    return null;
  }

  /// Copie de [x] avec une note et un ressenti qui peuvent être effacés
  /// (`copyWith` ne sait pas remettre un champ à vide) ; le type d'activité et
  /// les photos sont gardés.
  static WorkoutSession _avec(WorkoutSession x, {required String? notes, required int? ressenti}) => WorkoutSession(
        id: x.id,
        nom: x.nom,
        debut: x.debut,
        fin: x.fin,
        routineId: x.routineId,
        programId: x.programId,
        exercices: x.exercices,
        notes: notes,
        ressenti: ressenti,
        photo: x.photo,
        source: x.source,
        type: x.type,
        medias: x.medias,
      );

  Future<void> _nom(WorkoutSession s) async {
    final t = await showTextInputDialog(context, title: 'Nom de la séance', initial: s.nom, maxLength: 60);
    if (t != null && t.trim().isNotEmpty) await _ed!.mutate((x) => x.copyWith(nom: t.trim()));
  }

  Future<void> _date(WorkoutSession s) async {
    final d = await showDatePicker(
      context: context,
      initialDate: s.debut,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Date de la séance',
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(s.debut), helpText: 'Heure de début');
    if (t == null) return;
    final debut = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    final duree = s.duree;
    await _ed!.mutate((x) => x.copyWith(debut: debut, fin: debut.add(duree)));
  }

  Future<void> _duree(WorkoutSession s) async {
    final d = await choisirDuree(context, s.duree);
    if (d == null || !mounted) return;
    if (d.inSeconds <= 0) {
      Toasts.error(context, 'La durée doit dépasser zéro.');
      return;
    }
    await _ed!.mutate((x) => x.copyWith(fin: x.debut.add(d)));
  }

  Future<void> _type(WorkoutSession s) async {
    final t = await choisirTypeSeance(context, s.type);
    if (t != null) await _ed!.mutate((x) => x.copyWith(type: t));
  }

  Future<void> _ressenti(WorkoutSession s) async {
    final r = await showPanneauBas<int>(
      context,
      titre: 'Ressenti',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 5; i >= 1; i--)
            ChoixPanneau(label: ressentis[i - 1], selected: s.ressenti == i, onTap: () => Navigator.pop(context, i)),
          ChoixPanneau(label: 'Non noté', selected: s.ressenti == null, onTap: () => Navigator.pop(context, 0)),
        ],
      ),
    );
    if (r == null) return;
    await _ed!.mutate((x) => _avec(x, notes: x.notes, ressenti: r == 0 ? null : r));
  }

  Future<void> _notes(WorkoutSession s) async {
    final t = await showTextInputDialog(context, title: 'Notes', initial: s.notes ?? '', maxLines: 5, maxLength: 1000);
    if (t == null) return;
    await _ed!.mutate((x) => _avec(x, notes: t.trim().isEmpty ? null : t.trim(), ressenti: x.ressenti));
  }

  Future<void> _ajouter() async {
    final ids = await pickExercises(context, dejaPresents: {for (final e in (_ed?.session.exercices ?? const <SessionExercise>[])) e.exerciseId});
    if (ids == null || ids.isEmpty) return;
    await _ed!.ajouterExercices(ids);
  }

  Future<void> _remplacer(SessionExercise se) async {
    final id = await pickExercise(context, titre: "Remplacer l'exercice", remplace: se.exerciseId);
    if (id == null) return;
    await _ed!.remplacerExercice(se.id, id);
  }

  void _reordonner() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReordonnerPage(editeur: _ed!)));
  }

  Future<void> _enregistrer() async {
    final ed = _ed!;
    // Une séance sans exercice (cardio) se garde telle quelle ; avec des
    // exercices, il faut au moins une série cochée.
    if (ed.session.exercices.isNotEmpty && ed.session.exercices.every((e) => e.seriesFaites.isEmpty)) {
      Toasts.error(context, 'Coche au moins une série pour garder la séance.');
      return;
    }
    setState(() => _enregistrement = true);
    try {
      await ed.enregistrer();
      if (!mounted) return;
      Toasts.success(context, 'Séance mise à jour');
      context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _enregistrement = false);
        Toasts.error(context, 'Échec de l\'enregistrement. Réessaie.');
      }
    }
  }

  Future<bool> _quitter() async {
    if (_ed?.modifie != true) return true;
    return showConfirmDialog(
      context,
      title: 'Abandonner les modifications ?',
      message: 'Tes changements sur cette séance seront perdus.',
      confirmLabel: 'Abandonner',
      cancelLabel: 'Continuer',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ed = _ed;
    if (ed == null) {
      return PageSeance(
        titre: 'Modifier la séance',
        body: VideSeance(
          icone: const Trait(IconeSeance.loupe),
          titre: 'Séance introuvable',
          message: 'Elle a peut-être été supprimée.',
          action: 'Retour',
          onAction: () => context.pop(),
        ),
      );
    }
    final exos = context.watch<ExerciseRepo>();
    final repo = context.read<SessionRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final rpe = context.watch<SettingsRepo>().settings.afficherRpe;
    final c = context.colors;

    return ListenableBuilder(
      listenable: ed,
      builder: (context, _) {
        final s = ed.session;
        final ecart = SizedBox(height: k(8));
        Widget marge(Widget w) => Padding(padding: EdgeInsets.symmetric(horizontal: margeSeance), child: w);
        return PopScope(
          canPop: !ed.modifie || _quitte,
          onPopInvokedWithResult: (pop, _) async {
            if (pop) return;
            if (await _quitter() && context.mounted) {
              setState(() => _quitte = true);
              Navigator.of(context).pop();
            }
          },
          child: PageSeance(
            titre: 'Modifier la séance',
            sousTitre: Fmt.jourCap(s.debut),
            bas: BoutonSeance(
              label: 'Enregistrer',
              fond: c.bouton,
              encre: c.onBouton,
              onTap: _enregistrement ? null : _enregistrer,
            ),
            body: ListView(
              padding: EdgeInsets.only(top: k(10), bottom: k(16)),
              children: [
                marge(LigneCadre(
                  label: s.nom,
                  fin: Trait(IconeSeance.crayon, size: k(18), color: c.text2),
                  onTap: () => _nom(s),
                )),
                ecart,
                marge(LigneCadre(
                  icone: const Trait(IconeSeance.calendrier),
                  label: '${Fmt.jourMois(s.debut)} à ${Fmt.heure(s.debut)}',
                  onTap: () => _date(s),
                )),
                ecart,
                marge(LigneCadre(icone: const Trait(IconeSeance.minuteur), label: dureeLongue(s.duree), onTap: () => _duree(s))),
                ecart,
                marge(LigneCadre(icone: IconeTypeSeance(s.type, size: k(18)), label: s.type.label, onTap: () => _type(s))),
                ecart,
                marge(LigneCadre(
                  icone: const Trait(IconeSeance.ressenti),
                  label: 'Ressenti',
                  valeur: s.ressenti == null ? 'Non noté' : ressentis[(s.ressenti! - 1).clamp(0, 4)],
                  onTap: () => _ressenti(s),
                )),
                ecart,
                marge(LigneCadre(
                  icone: const Trait(IconeSeance.crayon),
                  label: (s.notes ?? '').isEmpty ? 'Ajouter une note' : s.notes!,
                  estompe: (s.notes ?? '').isEmpty,
                  lignes: 3,
                  onTap: () => _notes(s),
                )),
                Padding(
                  padding: EdgeInsets.fromLTRB(margeSeance, k(18), margeSeance - k(6), 0),
                  child: Row(
                    children: [
                      const Expanded(child: Surtitre('Exercices')),
                      if (s.exercices.length > 1) LienTexte(label: 'Réordonner', onTap: _reordonner),
                    ],
                  ),
                ),
                if (s.exercices.isNotEmpty)
                  marge(Text(
                    'Seules les séries cochées sont gardées.',
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11.5), height: 1.35, color: c.text2),
                  )),
                SizedBox(height: k(6)),
                if (s.exercices.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(margeSeance, k(4), margeSeance, k(10)),
                    child: Text(
                      'Aucun exercice dans cette séance.',
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.4, color: c.text2),
                    ),
                  ),
                for (var i = 0; i < s.exercices.length; i++)
                  ExerciceCarte(
                    key: ValueKey(s.exercices[i].id),
                    editeur: ed,
                    se: s.exercices[i],
                    exercise: exos.byId(s.exercices[i].exerciseId),
                    unite: unite,
                    afficherRpe: rpe,
                    effortRir: context.watch<SettingsRepo>().settings.effortRir,
                    precedent: _avant(repo, s.exercices[i].exerciseId, s.debut),
                    position: i,
                    total: s.exercices.length,
                    onSerieValidee: (_, _) {},
                    onRemplacer: () => _remplacer(s.exercices[i]),
                    onDisques: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DisquesPage())),
                    onReordonner: _reordonner,
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(margeSeance, k(6), margeSeance, 0),
                  child: BoutonSeance(label: 'Ajouter un exercice', fond: c.surface2, encre: c.text, onTap: _ajouter),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
