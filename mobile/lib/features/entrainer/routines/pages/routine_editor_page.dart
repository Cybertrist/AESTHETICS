import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/body/body_map.dart';
import '../../../../core/ui/ui.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import '../widgets/formulaire.dart';
import '../widgets/icones_editeur.dart';
import '../widgets/sous_page.dart';
import '../logic/routine_stats.dart';
import '../widgets/biblio.dart';
import '../widgets/dossier_dialog.dart';
import '../widgets/serie_dialog.dart';
import '../widgets/carte_routine.dart';

/// Éditeur plein écran d'une routine. [routineId] null : création.
/// Avec [retour], la page se ferme en rendant l'id enregistré (création
/// depuis l'éditeur de programme) au lieu d'ouvrir l'aperçu.
class RoutineEditorPage extends StatefulWidget {
  const RoutineEditorPage({super.key, this.routineId, this.folderId, this.retour = false});

  final String? routineId;
  final String? folderId;
  final bool retour;

  @override
  State<RoutineEditorPage> createState() => _RoutineEditorPageState();
}

class _RoutineEditorPageState extends State<RoutineEditorPage> {
  final _nom = TextEditingController();
  final _notes = TextEditingController();
  final _nomFocus = FocusNode();

  /// Le nom prend le curseur à l'ouverture d'une nouvelle routine, une seule
  /// fois : sinon, dès qu'il revient à l'écran (une série supprimée plus bas
  /// fait remonter la liste), il le reprendrait.
  bool _curseurAuNom = true;
  Routine? _base;
  List<RoutineExercise> _ex = [];
  String? _folderId;
  bool _introuvable = false;
  bool _dirty = false;
  bool _saving = false;

  /// Mode superset : emplacements cochés.
  Set<String>? _liaison;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _curseurAuNom = false);
    final repo = context.read<RoutineRepo>();
    if (widget.routineId != null) {
      final r = repo.byId(widget.routineId!);
      if (r == null) {
        _introuvable = true;
      } else {
        _base = r;
        _nom.text = r.nom;
        _notes.text = r.notes ?? '';
        _ex = [...r.exercices];
        _folderId = r.folderId;
      }
    } else {
      _folderId = widget.folderId != null && repo.folderById(widget.folderId!) != null ? widget.folderId : null;
    }
    _nom.addListener(_touch);
    _notes.addListener(_touch);
  }

  @override
  void dispose() {
    _nom.dispose();
    _notes.dispose();
    _nomFocus.dispose();
    super.dispose();
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _set(List<RoutineExercise> list) => setState(() {
        _ex = normaliserSupersets(list);
        _dirty = true;
      });

  UnitePoids get _unite => context.read<ProfileRepo>().unite;
  double get _pas => context.read<SettingsRepo>().settings.incrementPoidsKg;

  RoutineExercise _nouvelEmplacement(String exerciseId) {
    final ex = context.read<ExerciseRepo>().byId(exerciseId);
    final suivi = ex?.suivi ?? ExerciseTracking.poidsReps;
    final duree = suivi.usesDuration && !suivi.usesReps;
    final repos = context.read<SettingsRepo>().settings.reposParDefautSec;
    return RoutineExercise(
      id: newId(),
      exerciseId: exerciseId,
      reposSec: repos,
      series: List.filled(3, duree ? const PlannedSet(dureeSec: 45) : const PlannedSet(reps: 8, repsMax: 12)),
    );
  }

  Future<void> _ajouter() async {
    final ids = await pickExercises(context, dejaPresents: _ex.map((e) => e.exerciseId).toSet());
    if (ids == null || ids.isEmpty || !mounted) return;
    _set([..._ex, for (final id in ids) _nouvelEmplacement(id)]);
  }

  Future<void> _remplacer(RoutineExercise re) async {
    final id = await pickExercise(context, titre: 'Remplacer l\'exercice', remplace: re.exerciseId);
    if (id == null || !mounted) return;
    _set([for (final e in _ex) e.id == re.id ? e.copyWith(exerciseId: id) : e]);
  }

  Future<void> _repos(RoutineExercise re) async {
    const choix = [0, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300];
    final v = await showChoiceDialog<int>(
      context,
      title: 'Temps de repos',
      message: re.supersetId != null ? 'Dans un superset, le repos compte après le dernier exercice.' : null,
      selected: re.reposSec,
      options: [for (final s in choix) (s, s == 0 ? 'Pas de repos' : Fmt.repos(s)), (-1, 'Autre durée...')],
    );
    if (v == null || !mounted) return;
    var sec = v;
    if (v == -1) {
      final n = await showNumberInputDialog(context, title: 'Repos en secondes', initial: re.reposSec.toDouble(), unit: 's', decimal: false);
      if (n == null || !mounted) return;
      sec = n.round().clamp(0, 3600);
    }
    _set([for (final e in _ex) e.id == re.id ? e.copyWith(reposSec: sec) : e]);
  }

  Future<void> _note(RoutineExercise re) async {
    final v = await showTextInputDialog(context, title: 'Note sur l\'exercice', initial: re.notes ?? '', hint: 'Réglage de la machine, prise, tempo...', maxLines: 4, maxLength: 300);
    if (v == null || !mounted) return;
    _set([for (final e in _ex) e.id == re.id ? RoutineExercise(id: e.id, exerciseId: e.exerciseId, series: e.series, reposSec: e.reposSec, supersetId: e.supersetId, notes: v.trim().isEmpty ? null : v.trim()) : e]);
  }

  void _effacerNote(RoutineExercise re) => _set([
        for (final e in _ex) e.id == re.id ? RoutineExercise(id: e.id, exerciseId: e.exerciseId, series: e.series, reposSec: e.reposSec, supersetId: e.supersetId) : e,
      ]);

  Future<void> _serie(RoutineExercise re, int index) async {
    if (index < 0) {
      _majSeries(re, [...re.series]..removeAt(-1 - index));
      return;
    }
    final ex = context.read<ExerciseRepo>().byId(re.exerciseId);
    final numero = re.series.take(index + 1).where((s) => s.type == SetType.normale).length;
    final r = await showSerieDialog(
      context,
      serie: re.series[index],
      suivi: ex?.suivi ?? ExerciseTracking.poidsReps,
      unite: _unite,
      numero: numero == 0 ? index + 1 : numero,
      pas: _pas,
      // Un exercice garde au moins une série : sans série, il ne se lance pas.
      peutSupprimer: re.series.length > 1,
    );
    if (r == null || !mounted) return;
    final series = [...re.series];
    if (r.supprimer) {
      series.removeAt(index);
    } else if (r.toutes) {
      final type = re.series[index].type;
      for (var i = 0; i < series.length; i++) {
        if (series[i].type == type || i == index) series[i] = r.serie;
      }
    } else {
      series[index] = r.serie;
    }
    _majSeries(re, series);
  }

  void _majSeries(RoutineExercise re, List<PlannedSet> series) =>
      _set([for (final e in _ex) e.id == re.id ? e.copyWith(series: series) : e]);

  void _ajouterSerie(RoutineExercise re) {
    final last = re.series.isNotEmpty ? re.series.last : const PlannedSet(reps: 8, repsMax: 12);
    _majSeries(re, [...re.series, last.type == SetType.echauffement ? PlannedSet(reps: last.reps ?? 8, repsMax: last.repsMax) : last]);
  }

  void _ajouterEchauffement(RoutineExercise re) {
    final premiereTravail = re.series.indexWhere((s) => s.type != SetType.echauffement);
    final ref = premiereTravail >= 0 ? re.series[premiereTravail] : null;
    final ech = PlannedSet(type: SetType.echauffement, reps: 10, poids: ref?.poids == null ? null : Strength.arrondir(ref!.poids! * 0.5, _pas));
    final i = premiereTravail < 0 ? re.series.length : premiereTravail;
    _majSeries(re, [...re.series]..insert(i, ech));
  }

  void _delier(RoutineExercise re) => _set([for (final e in _ex) e.id == re.id ? e.copyWith(clearSuperset: true) : e]);

  void _validerLiaison() {
    final sel = _liaison ?? {};
    if (sel.length < 2) {
      Toasts.show(context, 'Choisis au moins deux exercices.');
      return;
    }
    final id = newId();
    final lies = [for (final e in _ex) if (sel.contains(e.id)) e.copyWith(supersetId: id)];
    final premier = _ex.indexWhere((e) => sel.contains(e.id));
    final reste = [for (final e in _ex) if (!sel.contains(e.id)) e];
    final avant = _ex.take(premier).where((e) => !sel.contains(e.id)).length;
    reste.insertAll(avant, lies);
    setState(() => _liaison = null);
    _set(reste);
    Toasts.success(context, 'Superset créé : ${lies.length} exercices enchaînés.');
  }

  void _dupliquer(RoutineExercise re) {
    final i = _ex.indexWhere((e) => e.id == re.id);
    final copie = RoutineExercise(id: newId(), exerciseId: re.exerciseId, series: [...re.series], reposSec: re.reposSec, notes: re.notes);
    _set([..._ex]..insert(i + 1, copie));
  }

  Future<void> _supprimer(RoutineExercise re) async {
    final i = _ex.indexWhere((e) => e.id == re.id);
    final avant = [..._ex];
    _set([..._ex]..removeAt(i));
    Toasts.show(context, '${context.read<ExerciseRepo>().nameOf(re.exerciseId)} retiré.', actionLabel: 'Annuler', onAction: () {
      if (mounted) _set(avant);
    });
  }

  void _reordonner(int oldIndex, int newIndex) {
    final list = [..._ex];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    // Un exercice sorti de son groupe perd son superset ; un exercice posé
    // au milieu d'un superset le rejoint.
    final prev = newIndex > 0 ? list[newIndex - 1] : null;
    final next = newIndex < list.length - 1 ? list[newIndex + 1] : null;
    if (prev != null && next != null && prev.supersetId != null && prev.supersetId == next.supersetId) {
      list[newIndex] = item.copyWith(supersetId: prev.supersetId);
    } else if (item.supersetId != null && prev?.supersetId != item.supersetId && next?.supersetId != item.supersetId) {
      list[newIndex] = item.copyWith(clearSuperset: true);
    }
    _set(list);
  }

  Future<void> _choisirDossier() async {
    final id = await choisirDossier(context, actuel: _folderId);
    if (id == null || !mounted) return;
    setState(() {
      _folderId = id.isEmpty ? null : id;
      _dirty = true;
    });
  }

  Routine _courante() => Routine(
        id: _base?.id ?? '',
        nom: _nom.text.trim(),
        folderId: _folderId,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        exercices: _ex,
        creeLe: _base?.creeLe ?? DateTime.now(),
        modifieLe: _base?.modifieLe,
        ordre: _base?.ordre ?? 0,
      );

  Future<void> _enregistrer() async {
    if (_nom.text.trim().isEmpty) {
      _nomFocus.requestFocus();
      Toasts.error(context, 'Donne un nom à la routine.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await context.read<RoutineRepo>().save(_courante());
      if (!mounted) return;
      _dirty = false;
      Toasts.success(context, 'Routine enregistrée.');
      if (widget.retour) {
        context.pop(saved.id);
      } else {
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        Toasts.error(context, 'Enregistrement impossible. Réessaie.');
      }
    }
  }

  Future<void> _quitter() async {
    if (!_dirty) {
      context.pop();
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Abandonner les modifications ?',
      message: 'Ce que tu as changé ne sera pas enregistré.',
      confirmLabel: 'Abandonner',
      destructive: true,
    );
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_introuvable) {
      return SousPage(
        title: 'Routine',
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Routine introuvable',
          message: 'Elle a peut-être été supprimée.',
          actionLabel: 'Retour aux routines',
          onAction: () => context.go('/entrainer?onglet=routines'),
        ),
      );
    }
    final exRepo = context.watch<ExerciseRepo>();
    final wide = context.isExpanded;
    final titre = _base == null ? 'Nouvelle routine' : 'Modifier la routine';

    final liste = _ListeExercices(
      exercices: _ex,
      exRepo: exRepo,
      unite: _unite,
      liaison: _liaison,
      onReorder: _reordonner,
      onToggleLiaison: (id) => setState(() => _liaison!.contains(id) ? _liaison!.remove(id) : _liaison!.add(id)),
      onSerie: _serie,
      onAjouterSerie: _ajouterSerie,
      onAction: (re, a) {
        switch (a) {
          case _Action.remplacer:
            _remplacer(re);
          case _Action.fiche:
            ouvrirFicheExercice(context, re.exerciseId);
          case _Action.lier:
            // On coche ensuite les exercices à enchaîner avec celui-ci.
            if (_ex.length < 2) {
              Toasts.show(context, 'Ajoute un autre exercice pour créer un superset.');
            } else {
              setState(() => _liaison = {re.id});
            }
          case _Action.delier:
            _delier(re);
          case _Action.repos:
            _repos(re);
          case _Action.note:
            _note(re);
          case _Action.effacerNote:
            _effacerNote(re);
          case _Action.echauffement:
            _ajouterEchauffement(re);
          case _Action.dupliquer:
            _dupliquer(re);
          case _Action.supprimer:
            _supprimer(re);
        }
      },
      header: wide ? null : _Entete(this),
      onAjouter: _ajouter,
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quitter();
      },
      child: SousPage(
        title: titre,
        subtitle: _ex.isEmpty ? null : resumeRoutine(_courante()),
        closeIcon: true,
        onBack: _quitter,
        maxContentWidth: wide ? 1180 : Breakpoints.content,
        actions: [
          if (_ex.isNotEmpty)
            BoutonNu(
              trait: Trait.partager,
              label: 'Partager',
              largeur: 46,
              onTap: () => partagerRoutine(context, _courante().copyWith(nom: _nom.text.trim().isEmpty ? 'Routine' : _nom.text.trim())),
            ),
        ],
        bottomBar: _liaison != null
            ? Row(
                children: [
                  Expanded(
                    child: Text(
                      _liaison!.length < 2 ? 'Coche au moins deux exercices à enchaîner.' : '${_liaison!.length} exercices cochés',
                      style: AppType.rowSubtitle(),
                    ),
                  ),
                  PillButton.ghost(label: 'Annuler', onPressed: () => setState(() => _liaison = null)),
                  const SizedBox(width: 8),
                  PillButton(label: 'Lier', icon: Icons.link_rounded, onPressed: _liaison!.length < 2 ? null : _validerLiaison),
                ],
              )
            : Row(
                children: [
                  Expanded(child: BoutonSecondaire(label: 'Exercices', icone: const IconeTrait(Trait.plus, size: 20), onPressed: _ajouter)),
                  const SizedBox(width: 10),
                  Expanded(child: BoutonPrincipal(label: 'Enregistrer', onPressed: _saving ? null : _enregistrer)),
                ],
              ),
        body: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: SingleChildScrollView(child: _Entete(this, large: true))),
                  const SizedBox(width: 8),
                  Expanded(child: liste),
                ],
              )
            : liste,
      ),
    );
  }
}

/// Nom, notes, dossier et muscles travaillés.
class _Entete extends StatelessWidget {
  const _Entete(this.s, {this.large = false});
  final _RoutineEditorPageState s;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<RoutineRepo>();
    final exRepo = context.watch<ExerciseRepo>();
    final dossier = s._folderId == null ? null : repo.folderById(s._folderId!);
    final series = seriesParMuscle(s._ex, exRepo.byId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          ChampBord(controller: s._nom, focusNode: s._nomFocus, label: 'Nom de la routine', autofocus: s._base == null && s._curseurAuNom, maxLength: 60),
          const SizedBox(height: 16),
          ChampBord(controller: s._notes, label: 'Notes (facultatif)', maxLength: 500, maxLines: 4),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TagPill(dossier?.nom ?? 'Sans dossier', icon: Icons.folder_outlined, color: c.text, large: true, onTap: s._choisirDossier),
              if (s._ex.isNotEmpty) TagPill('${s._courante().dureeEstimeeMin} min environ', icon: Icons.schedule_rounded, color: c.text2, large: true),
            ],
          ),
          if (large && series.isNotEmpty) ...[
            const SizedBox(height: 16),
            AppCard(
              label: 'Muscles travaillés',
              child: Column(
                children: [
                  BodyMapDual(intensities: intensitesPour(series), labels: true, height: 260),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Action { remplacer, fiche, lier, delier, repos, note, effacerNote, echauffement, dupliquer, supprimer }

class _ListeExercices extends StatelessWidget {
  const _ListeExercices({
    required this.exercices,
    required this.exRepo,
    required this.unite,
    required this.liaison,
    required this.onReorder,
    required this.onToggleLiaison,
    required this.onSerie,
    required this.onAjouterSerie,
    required this.onAction,
    required this.header,
    required this.onAjouter,
  });

  final List<RoutineExercise> exercices;
  final ExerciseRepo exRepo;
  final UnitePoids unite;
  final Set<String>? liaison;
  final ReorderCallback onReorder;
  final ValueChanged<String> onToggleLiaison;
  final void Function(RoutineExercise, int) onSerie;
  final ValueChanged<RoutineExercise> onAjouterSerie;
  final void Function(RoutineExercise, _Action) onAction;
  final Widget? header;
  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) {
    final ss = supersetsDe(exercices);
    final footer = exercices.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            child: EmptyState(
              icon: Icons.playlist_add_rounded,
              title: 'Aucun exercice',
              message: 'Ajoute les exercices de la routine, puis règle leurs séries.',
              actionLabel: 'Ajouter des exercices',
              onAction: onAjouter,
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 4, AppTokens.gutter, 24),
            child: Column(
              children: [
                BoutonSecondaire(label: 'Ajouter des exercices', icone: const IconeTrait(Trait.plus, size: 20), onPressed: onAjouter),
                const SizedBox(height: 10),
                Text('Maintiens un exercice pour le déplacer.', style: AppType.rowSubtitle()),
              ],
            ),
          );
    return ReorderableListView.builder(
      header: header,
      footer: footer,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: exercices.length,
      onReorderItem: onReorder,
      proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
      itemBuilder: (context, i) {
        final re = exercices[i];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(re.id),
          index: i,
          enabled: liaison == null,
          child: _CarteExercice(
            index: i,
            re: re,
            ex: exRepo.byId(re.exerciseId),
            superset: ss[re.supersetId],
            dernier: i == exercices.length - 1,
            suivantMemeSuperset: i < exercices.length - 1 && re.supersetId != null && exercices[i + 1].supersetId == re.supersetId,
            unite: unite,
            coche: liaison?.contains(re.id),
            onToggle: () => onToggleLiaison(re.id),
            onSerie: (k) => onSerie(re, k),
            onAjouterSerie: () => onAjouterSerie(re),
            onAction: (a) => onAction(re, a),
          ),
        );
      },
    );
  }
}

class _CarteExercice extends StatelessWidget {
  const _CarteExercice({
    required this.index,
    required this.re,
    required this.ex,
    required this.superset,
    required this.dernier,
    required this.suivantMemeSuperset,
    required this.unite,
    required this.coche,
    required this.onToggle,
    required this.onSerie,
    required this.onAjouterSerie,
    required this.onAction,
  });

  final int index;
  final RoutineExercise re;
  final Exercise? ex;
  final ({String lettre, Color couleur})? superset;
  final bool dernier;
  final bool suivantMemeSuperset;
  final UnitePoids unite;
  final bool? coche;
  final VoidCallback onToggle;
  final ValueChanged<int> onSerie;
  final VoidCallback onAjouterSerie;
  final ValueChanged<_Action> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final suivi = ex?.suivi ?? ExerciseTracking.poidsReps;
    final ssCol = superset?.couleur;
    var numero = 0;

    final menu = PopupMenuButton<_Action>(
      tooltip: 'Options',
      icon: Icon(Icons.more_vert_rounded, color: c.text2),
      onSelected: onAction,
      itemBuilder: (_) => [
        _item(_Action.remplacer, 'Remplacer', Icons.swap_horiz_rounded),
        if (ex != null) _item(_Action.fiche, 'Voir la fiche', Icons.info_outline_rounded),
        if (superset == null) _item(_Action.lier, 'Ajouter à un superset', Icons.link_rounded),
        if (re.supersetId != null && superset != null) _item(_Action.delier, 'Sortir du superset', Icons.link_off_rounded),
        _item(_Action.repos, 'Temps de repos', Icons.timer_outlined),
        _item(_Action.note, re.notes == null ? 'Ajouter une note' : 'Modifier la note', Icons.sticky_note_2_outlined),
        if (re.notes != null) _item(_Action.effacerNote, 'Effacer la note', Icons.backspace_outlined),
        if (suivi.usesWeight) _item(_Action.echauffement, 'Ajouter un échauffement', Icons.local_fire_department_outlined),
        _item(_Action.dupliquer, 'Dupliquer', Icons.copy_rounded),
        _item(_Action.supprimer, 'Retirer', Icons.delete_outline_rounded, danger: c.error),
      ],
    );

    final colonnes = ['SÉRIE', suivi.usesDuration && !suivi.usesReps ? 'DURÉE' : 'CIBLE', suivi.usesWeight ? unite.label.toUpperCase() : '', 'RPE'];
    final superpose = coche == true;
    return Container(
      margin: EdgeInsets.only(bottom: suivantMemeSuperset ? 0 : 18),
      decoration: BoxDecoration(
        color: superpose ? c.text.withValues(alpha: 0.07) : (ssCol == null ? Colors.transparent : ssCol.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: coche != null ? onToggle : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, 4, 0),
              child: Row(
                children: [
                  if (coche != null)
                    Checkbox(value: coche, onChanged: (_) => onToggle())
                  else
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconePicto(Picto.poignee, size: 22, color: c.text3, epaisseur: 2),
                      ),
                    ),
                  ex == null
                      ? Tuile(taille: 52, child: Icon(Icons.help_outline_rounded, color: c.warning, size: 24))
                      : GestureDetector(onTap: () => onAction(_Action.fiche), child: TuileExercice(ex, taille: 52)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ex?.nom ?? 'Exercice introuvable', style: AppType.rowTitle(color: ex == null ? c.warning : null).copyWith(fontSize: 16.5, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          ex == null ? 'Supprimé de la bibliothèque : remplace-le.' : ex!.musclesPrincipaux.map((m) => m.label).join(', '),
                          style: AppType.rowSubtitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (superset != null) TagPill('Superset ${superset!.lettre}', color: ssCol),
                  if (coche == null) menu,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 10, AppTokens.gutter, 0),
              child: InkWell(
                onTap: () => onAction(_Action.note),
                child: Text(
                  re.notes ?? 'Ajouter une note...',
                  style: AppType.rowSubtitle(color: re.notes == null ? c.text3 : c.text2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter - 4, 6, AppTokens.gutter, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => onAction(_Action.repos),
                    icon: IconeTrait(Trait.horlogeGrande, size: 20, color: c.minuteur),
                    label: Text(re.reposSec == 0 ? 'Minuteur de repos : désactivé' : 'Minuteur de repos : ${Fmt.repos(re.reposSec)}', style: TextStyle(color: c.minuteur, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  if (ex == null) TextButton(onPressed: () => onAction(_Action.remplacer), child: Text('Remplacer', style: TextStyle(color: c.warning))),
                ],
              ),
            ),
            SetTableHeader(labels: colonnes),
            for (var k = 0; k < re.series.length; k++)
              Builder(builder: (context) {
                final s = re.series[k];
                if (s.type == SetType.normale) numero++;
                final cible = suivi.usesDuration && !suivi.usesReps
                    ? (s.dureeSec == null ? 'libre' : Fmt.repos(s.dureeSec!))
                    : (s.reps == null ? 'libres' : s.repsLabel);
                return Dismissible(
                  key: ValueKey('${re.id}-$k-${re.series.length}'),
                  direction: re.series.length > 1 ? DismissDirection.endToStart : DismissDirection.none,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: c.error.withValues(alpha: 0.18),
                    child: Icon(Icons.delete_outline_rounded, color: c.error),
                  ),
                  onDismissed: (_) => onSerie(-1 - k),
                  child: InkWell(
                    onTap: () => onSerie(k),
                    child: _LigneSerie(
                      label: s.type == SetType.normale ? '${numero == 0 ? k + 1 : numero}' : s.type.short,
                      labelColor: s.type == SetType.normale ? null : couleurType(context, s.type),
                      previous: s.type == SetType.normale ? cible : '${s.type.label} · $cible',
                      weight: !suivi.usesWeight ? '' : (s.poids == null ? 'auto' : Fmt.n(Fmt.poidsAffiche(s.poids!, unite))),
                      reps: s.rpe == null ? '-' : Fmt.n(s.rpe),
                      hint: s.poids == null,
                    ),
                  ),
                );
              }),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 0),
              child: BoutonSecondaire(label: 'Ajouter une série', petit: true, icone: const IconeTrait(Trait.plus, size: 18), onPressed: onAjouterSerie),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_Action> _item(_Action v, String label, IconData icon, {Color? danger}) => PopupMenuItem(
        value: v,
        child: Row(children: [Icon(icon, size: 20, color: danger), const SizedBox(width: 12), Text(label, style: TextStyle(color: danger))]),
      );
}

/// Ligne d'une série prévue : mêmes colonnes que le tableau de séance,
/// avec un crayon à la place de la coche.
class _LigneSerie extends StatelessWidget {
  const _LigneSerie({required this.label, this.labelColor, required this.previous, required this.weight, required this.reps, this.hint = false});
  final String label;
  final Color? labelColor;
  final String previous;
  final String weight;
  final String reps;
  final bool hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = AppType.number(17, weight: FontWeight.w500, color: c.text);
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
        child: Row(
          children: [
            Expanded(flex: 10, child: Text(label, style: AppType.number(17, weight: FontWeight.w500, color: labelColor ?? c.minuteur))),
            Expanded(flex: 24, child: Text(previous, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 13.5))),
            Expanded(flex: 16, child: Center(child: Text(weight, style: hint ? v.copyWith(color: c.text3) : v))),
            Expanded(flex: 16, child: Center(child: Text(reps, style: v))),
            Expanded(flex: 10, child: Align(alignment: Alignment.centerRight, child: IconeTrait(Trait.crayon, size: 18, color: c.text3))),
          ],
        ),
      ),
    );
  }
}
