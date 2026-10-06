import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/bibliotheque/bibliotheque.dart';
import '../logic/analyse.dart';
import '../logic/editeur.dart';
import '../logic/repos_minuteur.dart';
import 'habillage.dart';
import 'panneaux.dart';
import 'serie_ligne.dart';

/// Couleurs des supersets, prises dans les couleurs de domaine.
const couleursSuperset = [AppTokens.domainCoach, AppTokens.domainSleep, AppTokens.domainHeart, AppTokens.domainWeight, AppTokens.domainTraining];

Color couleurSuperset(String lettre) => couleursSuperset[(lettre.codeUnitAt(0) - 65) % couleursSuperset.length];

/// Repères des séries : la lettre du type, ou 1, 2, 3 pour les séries normales.
/// Les échauffements ne prennent pas de numéro.
List<String> libellesSeries(List<WorkoutSet> series) {
  var n = 0;
  return [
    for (final s in series)
      if (s.type == SetType.echauffement) s.type.short else () {
        n++;
        return s.type == SetType.normale ? '$n' : s.type.short;
      }(),
  ];
}

/// Série de la dernière fois qui correspond (échauffements entre eux, travail entre eux).
WorkoutSet? precedentPour(List<WorkoutSet> series, int index, List<WorkoutSet>? avant) {
  if (avant == null || avant.isEmpty) return null;
  final s = series[index];
  final echauf = s.type == SetType.echauffement;
  final rang = series.take(index).where((x) => (x.type == SetType.echauffement) == echauf).length;
  final memes = avant.where((x) => (x.type == SetType.echauffement) == echauf).toList();
  return rang < memes.length ? memes[rang] : null;
}

/// Fourchette prévue pour la série [index] (« 12-15 »), ou null sans fourchette.
String? cibleRepsPour(List<PlannedSet>? plan, int index) {
  if (plan == null || index >= plan.length) return null;
  final p = plan[index];
  if (p.reps == null || p.repsMax == null || p.repsMax == p.reps) return null;
  return '${p.reps}-${p.repsMax}';
}

/// Vrai quand toutes les séries de l'exercice sont validées.
bool exerciceTermine(SessionExercise e) => e.series.isNotEmpty && e.series.every((s) => s.fait);

/// Un exercice de la séance, à plat : une ligne (image, nom, « 1/3 effectués »,
/// menu) qui s'ouvre sur place. Ouvert : note, ligne bleue du minuteur de
/// repos, tableau des séries, « + Ajouter une série ».
class ExerciceCarte extends StatelessWidget {
  const ExerciceCarte({
    super.key,
    required this.editeur,
    required this.se,
    required this.exercise,
    required this.unite,
    required this.onSerieValidee,
    required this.onRemplacer,
    required this.onDisques,
    required this.onReordonner,
    this.precedent,
    this.reperes,
    this.plan,
    this.afficherRpe = false,
    this.effortRir = false,
    this.position = 0,
    this.total = 1,
    this.ouvert = true,
    this.onBascule,
    this.onAnnulable,
  });

  final SeanceEditeur editeur;
  final SessionExercise se;
  final Exercise? exercise;
  final UnitePoids unite;
  final List<WorkoutSet>? precedent;

  /// Records à battre sur cet exercice ; null : aucune ligne dorée.
  final ReperesRecord? reperes;

  /// Séries prévues par la routine, pour montrer la fourchette de répétitions.
  final List<PlannedSet>? plan;
  final bool afficherRpe;
  final bool effortRir;
  final int position;
  final int total;
  final void Function(SessionExercise se, WorkoutSet set) onSerieValidee;
  final VoidCallback onRemplacer;
  final VoidCallback onDisques;
  final VoidCallback onReordonner;

  /// Replié, l'exercice tient sur sa ligne avec son compteur de séries.
  final bool ouvert;

  /// Toucher la ligne : ouvrir ou replier. Sans rappel, l'exercice reste ouvert.
  final VoidCallback? onBascule;

  /// Une action vient d'être faite et peut être annulée : à l'écran de dire
  /// où il l'affiche. Sans rappel, un message passe en bas de l'écran.
  final void Function(String message, VoidCallback annuler)? onAnnulable;

  ExerciseTracking get suivi => exercise?.suivi ?? ExerciseTracking.poidsReps;

  Future<void> _repos(BuildContext context) async {
    final r = await choisirRepos(context, se.reposSec);
    if (r != null) await editeur.repos(se.id, r);
  }

  /// La fiche de l'exercice ; son raccourci « Remplacer » referme la fiche
  /// et ouvre l'écran « Remplacer un exercice » de la séance.
  Future<void> _fiche(BuildContext context) => ouvrirFicheExercice(
        context,
        se.exerciseId,
        onRemplacer: () {
          Navigator.of(context, rootNavigator: true).pop();
          onRemplacer();
        },
      );

  Future<void> _menu(BuildContext context) async {
    final lettre = editeur.lettreSuperset(se.supersetId);
    final dernier = position >= total - 1;
    final v = await menuPanneau<String>(
      context,
      titre: exercise?.nom ?? 'Exercice',
      actions: [
        ActionPanneau('fiche', 'Voir la fiche de l\'exercice', const Icon(Icons.play_circle_outline_rounded)),
        ActionPanneau('remplacer', 'Remplacer l\'exercice', const Icon(Icons.swap_horiz_rounded)),
        if (suivi.usesWeight && suivi != ExerciseTracking.poidsDuCorpsAssiste)
          ActionPanneau('disques', 'Disques et échauffement', const Icon(Icons.calculate_outlined)),
        if (!dernier && (lettre == null || editeur.finDeSuperset(se.id)))
          ActionPanneau('superset', 'Superset avec l\'exercice suivant', const Icon(Icons.link_rounded)),
        if (lettre != null) ActionPanneau('sortir', 'Retirer du superset', const Icon(Icons.link_off_rounded)),
        if (position > 0) ActionPanneau('monter', 'Monter', const Icon(Icons.arrow_upward_rounded), filetAvant: true),
        if (!dernier) ActionPanneau('descendre', 'Descendre', const Icon(Icons.arrow_downward_rounded), filetAvant: position == 0),
        if (total > 2) ActionPanneau('ordre', 'Réordonner les exercices', const Icon(Icons.reorder_rounded)),
        ActionPanneau('supprimer', 'Retirer de la séance', const Trait(IconeSeance.corbeille), destructif: true, filetAvant: true),
      ],
    );
    if (!context.mounted || v == null) return;
    switch (v) {
      case 'fiche':
        await _fiche(context);
      case 'remplacer':
        onRemplacer();
      case 'disques':
        onDisques();
      case 'superset':
        await editeur.lierAuSuivant(se.id);
      case 'sortir':
        await editeur.sortirDuSuperset(se.id);
      case 'monter':
        await editeur.deplacer(se.id, -1);
      case 'descendre':
        await editeur.deplacer(se.id, 1);
      case 'ordre':
        onReordonner();
      case 'supprimer':
        final faites = se.seriesFaites.length;
        final ok = faites == 0 ||
            await showConfirmDialog(
              context,
              title: 'Retirer cet exercice ?',
              message: faites > 1 ? '$faites séries validées seront perdues.' : 'Une série validée sera perdue.',
              confirmLabel: 'Retirer',
              destructive: true,
            );
        if (ok) await editeur.supprimerExercice(se.id);
    }
  }

  Future<void> _typeSerie(BuildContext context, WorkoutSet s, int index) async {
    final v = await choisirTypeSerie(context, actuel: s.type);
    if (!context.mounted || v == null) return;
    if (v.supprimer) {
      await _supprimerSerie(context, s, index);
    } else if (v.type != null && v.type != s.type) {
      await editeur.changerType(se.id, s.id, v.type!);
    }
  }

  Future<void> _supprimerSerie(BuildContext context, WorkoutSet s, int index) async {
    await editeur.supprimerSerie(se.id, s.id);
    if (!context.mounted) return;
    void annuler() => editeur.restaurerSerie(se.id, s, index);
    if (onAnnulable != null) {
      onAnnulable!('Série supprimée', annuler);
      return;
    }
    Toasts.show(context, 'Série supprimée', icon: Icons.delete_outline_rounded, actionLabel: 'Annuler', onAction: annuler);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lettre = editeur.lettreSuperset(se.supersetId);
    final labels = libellesSeries(se.series);
    final couleur = lettre == null ? null : couleurSuperset(lettre);
    final vignette = k(52);

    final nom = exercise?.nom ?? 'Exercice supprimé';
    final faites = se.series.where((x) => x.fait).length;
    final ligne = Padding(
      padding: EdgeInsets.fromLTRB(margeSeance, k(8), k(8), k(8)),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Ouvrir la fiche de l\'exercice',
            child: GestureDetector(
              onTap: () => _fiche(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(k(11)),
                child: ColoredBox(color: c.surface2, child: ExerciseThumb(exercise, size: vignette)),
              ),
            ),
          ),
          SizedBox(width: k(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nom,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(15), height: 1.25, fontWeight: FontWeight.w700, color: c.text),
                ),
                if (lettre != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Superset $lettre',
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), fontWeight: FontWeight.w700, color: couleur),
                    ),
                  ),
                // Le compteur ne se montre que sur la ligne repliée.
                if (!ouvert)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      se.series.isEmpty ? 'Aucune série' : '$faites/${se.series.length} effectués',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppTokens.fontUi,
                        fontSize: k(13),
                        height: 1.3,
                        color: exerciceTermine(se) ? c.foret : c.text2,
                        fontFeatures: AppTokens.tabular,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          BoutonRond(label: 'Plus d\'actions', nu: true, onTap: () => _menu(context), child: TroisPoints(size: k(18))),
        ],
      ),
    );

    final contenu = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onBascule == null)
          ligne
        else
          Semantics(
            button: true,
            label: ouvert ? 'Replier $nom' : 'Ouvrir $nom',
            child: InkWell(onTap: onBascule, child: ligne),
          ),
        if (ouvert) ...[
        // Note de l'exercice, écrite directement sur place.
        Padding(
          padding: EdgeInsets.fromLTRB(margeSeance, k(4), margeSeance, k(2)),
          child: ChampNote(key: ValueKey('note-${se.id}'), texte: se.notes, onChange: (t) => editeur.notes(se.id, t)),
        ),
        // Ligne bleue du minuteur de repos, soulignée d'un filet.
        Padding(
          padding: EdgeInsets.fromLTRB(margeSeance, 0, margeSeance, k(4)),
          child: InkWell(
            onTap: () => _repos(context),
            child: Container(
              constraints: BoxConstraints(minHeight: k(44)),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
              child: Row(
                children: [
                  Trait(IconeSeance.minuteurRepos, size: k(17), epaisseur: 1.8, color: c.minuteur),
                  SizedBox(width: k(8)),
                  Text(
                    se.reposSec > 0 ? 'Minuteur de repos : ${reposCourt(se.reposSec)}' : 'Minuteur de repos : aucun',
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13.5), fontWeight: FontWeight.w500, color: c.minuteur),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (se.series.isNotEmpty) EnteteSeries(suivi: suivi, unite: unite, afficherRpe: afficherRpe, effortRir: effortRir),
        for (var i = 0; i < se.series.length; i++)
          Dismissible(
            key: ValueKey('serie-${se.series[i].id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: margeSeance),
              color: c.surface3,
              child: Trait(IconeSeance.corbeille, color: c.error),
            ),
            onDismissed: (_) => _supprimerSerie(context, se.series[i], i),
            child: SerieLigne(
              key: ValueKey('ligne-${se.series[i].id}'),
              set: se.series[i],
              label: labels[i],
              suivi: suivi,
              unite: unite,
              precedent: precedentPour(se.series, i, precedent),
              cibleReps: cibleRepsPour(plan, i),
              repsPrevues: plan != null && i < plan!.length ? plan![i].reps : null,
              afficherRpe: afficherRpe,
              effortRir: effortRir,
              alterne: i.isOdd,
              record: reperes?.recordDe(se.series[i]) != null,
              onChanged: (s) => editeur.majSerie(se.id, s),
              onMenu: () => _typeSerie(context, se.series[i], i),
              onToggle: (s) async {
                // Valeurs et validation partent en une seule écriture : la
                // série est sur le disque dès ce geste, et un double appui
                // ne la dévalide pas.
                final valider = !s.fait;
                final change = await editeur.validerSerie(se.id, s, fait: valider);
                if (!valider) {
                  if (editeur.enDirect) ReposMinuteur.instance.annulerPour(s.id);
                  return;
                }
                if (!change) return;
                final maj = editeur.exercice(se.id);
                final set = maj?.series.where((x) => x.id == s.id).firstOrNull;
                if (maj != null && set != null) onSerieValidee(maj, set);
              },
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(margeSeance, k(12), margeSeance, k(10)),
          child: BoutonSeance(
            label: '+ Ajouter une série',
            fond: c.surface2,
            encre: c.text,
            hauteur: k(42),
            taille: k(13.5),
            onTap: () => editeur.ajouterSerie(se.id),
          ),
        ),
        ],
      ],
    );

    // En superset, un filet de couleur à gauche relie les exercices enchaînés.
    if (couleur == null) return contenu;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(left: BorderSide(color: couleur, width: 3))),
      child: contenu,
    );
  }
}

/// Note d'un exercice saisie sur place, sans fenêtre : enregistrée peu après
/// la frappe, et à la sortie du champ.
class ChampNote extends StatefulWidget {
  const ChampNote({super.key, required this.texte, required this.onChange});

  final String? texte;
  final Future<void> Function(String texte) onChange;

  @override
  State<ChampNote> createState() => _ChampNoteState();
}

class _ChampNoteState extends State<ChampNote> {
  late final _ctrl = TextEditingController(text: widget.texte ?? '');
  final _focus = FocusNode();
  Timer? _attente;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _enregistrer();
    });
  }

  @override
  void didUpdateWidget(ChampNote old) {
    super.didUpdateWidget(old);
    // Changée ailleurs (annulation, autre écran) : suivre, sauf pendant la frappe.
    final t = widget.texte ?? '';
    if (!_focus.hasFocus && t != _ctrl.text.trim()) _ctrl.text = t;
  }

  void _enregistrer() {
    _attente?.cancel();
    final t = _ctrl.text.trim();
    if (t != (widget.texte ?? '')) widget.onChange(t);
  }

  @override
  void dispose() {
    _enregistrer();
    _attente?.cancel();
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.35, color: c.text2);
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      minLines: 1,
      maxLines: 6,
      maxLength: 400,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.multiline,
      style: style,
      cursorColor: c.text,
      onChanged: (_) {
        _attente?.cancel();
        _attente = Timer(const Duration(milliseconds: 600), _enregistrer);
      },
      onTapOutside: (_) => _focus.unfocus(),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: k(6)),
        hintText: 'Ajouter une note…',
        hintStyle: style.copyWith(color: c.text3),
      ),
    );
  }
}
