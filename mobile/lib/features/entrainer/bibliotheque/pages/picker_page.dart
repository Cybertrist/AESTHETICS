import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../logic/exercise_index.dart';
import '../widgets/exercise_media.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import 'exercise_browser.dart';
import 'exercise_detail_page.dart';
import 'exercise_edit_page.dart';

/// Sélecteur d'exercices plein écran. Rend les id dans l'ordre de
/// sélection (jamais une liste vide), ou null si annulé.
Future<List<String>?> pickExercises(
  BuildContext context, {
  bool multi = true,
  Set<String> dejaPresents = const {},
  String titre = 'Ajouter des exercices',
  String boutonLabel = 'Ajouter',
  Set<Muscle> musclesInitiaux = const {},
}) =>
    Navigator.of(context, rootNavigator: true).push<List<String>>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ExercisePickerPage(
        multi: multi,
        dejaPresents: dejaPresents,
        titre: titre,
        boutonLabel: boutonLabel,
        musclesInitiaux: musclesInitiaux,
      ),
    ));

/// Choix d'un seul exercice. Avec [remplace], la liste part des muscles
/// principaux de l'exercice à remplacer.
Future<String?> pickExercise(BuildContext context, {String titre = 'Choisir un exercice', String? remplace}) async {
  final old = remplace == null ? null : context.read<ExerciseRepo>().byId(remplace);
  final r = await Navigator.of(context, rootNavigator: true).push<List<String>>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ExercisePickerPage(
      multi: false,
      titre: titre,
      sousTitre: old == null ? null : 'À la place de ${old.nom}',
      dejaPresents: {?remplace},
      musclesInitiaux: old?.musclesPrincipaux.toSet() ?? const {},
    ),
  ));
  return r?.firstOrNull;
}

/// Même chose que [pickExercises], avec les noms attendus par le module routines.
Future<List<String>?> choisirExercices(
  BuildContext context, {
  bool multi = true,
  Set<String> dejaChoisis = const {},
  String titre = 'Ajouter des exercices',
}) =>
    pickExercises(context, multi: multi, dejaPresents: dejaChoisis, titre: titre);

class ExercisePickerPage extends StatefulWidget {
  const ExercisePickerPage({
    super.key,
    this.multi = true,
    this.dejaPresents = const {},
    this.titre = 'Ajouter des exercices',
    this.sousTitre,
    this.boutonLabel = 'Ajouter',
    this.musclesInitiaux = const {},
  });

  final bool multi;
  final Set<String> dejaPresents;
  final String titre;
  final String? sousTitre;
  final String boutonLabel;
  final Set<Muscle> musclesInitiaux;

  @override
  State<ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends State<ExercisePickerPage> {
  final List<String> _sel = [];

  void _toggle(Exercise e) {
    if (!widget.multi) {
      Navigator.of(context).pop([e.id]);
      return;
    }
    setState(() => _sel.contains(e.id) ? _sel.remove(e.id) : _sel.add(e.id));
  }

  Future<void> _create(String nom) async {
    final e = await ExerciseEditPage.open(context, initialName: nom);
    if (e == null || !mounted) return;
    if (!widget.multi) {
      Navigator.of(context).pop([e.id]);
      return;
    }
    setState(() => _sel.add(e.id));
  }

  Future<void> _back() async {
    if (_sel.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Abandonner la sélection ?',
      message: '${_sel.length} exercice${_sel.length > 1 ? 's' : ''} choisi${_sel.length > 1 ? 's' : ''} ne seront pas ajoutés.',
      confirmLabel: 'Abandonner',
      cancelLabel: 'Continuer',
      destructive: true,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<ExerciseRepo>();
    final browser = ExerciseBrowser(
      initial: LibraryFilters(muscles: widget.musclesInitiaux, principauxSeulement: widget.musclesInitiaux.isNotEmpty),
      config: BrowserConfig(
        selection: _sel,
        onToggle: _toggle,
        onInfo: (e) => ouvrirFicheExercice(context, e.id),
        dejaPresents: widget.dejaPresents,
        onCreate: _create,
        numbered: widget.multi,
      ),
    );

    Widget? bottom;
    if (widget.multi) {
      bottom = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_sel.isNotEmpty) ...[
            SizedBox(
              height: 48,
              child: ReorderableListView(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                onReorderItem: (a, b) => setState(() => _sel.insert(b, _sel.removeAt(a))),
                children: [
                  for (var i = 0; i < _sel.length; i++)
                    ReorderableDelayedDragStartListener(
                      key: ValueKey(_sel[i]),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _sel.removeAt(i)),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ExerciseThumb(repo.byId(_sel[i]), size: 44),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(color: c.surface3, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 1.5)),
                                  child: Icon(Icons.close_rounded, size: 12, color: c.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          BoutonPrincipal(
            label: _sel.isEmpty ? 'Choisis des exercices' : '${widget.boutonLabel} (${_sel.length})',
            onPressed: _sel.isEmpty ? null : () => Navigator.of(context).pop(List<String>.of(_sel)),
          ),
        ],
      );
    }

    final sousTitre = widget.sousTitre ??
        (widget.multi
            ? (_sel.isEmpty ? 'Touche pour choisir, le « ? » ouvre la fiche' : '${_sel.length} choisi${_sel.length > 1 ? 's' : ''}, dans cet ordre')
            : 'Touche un exercice pour le choisir');

    return PopScope(
      canPop: _sel.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: PageEntrainer(
        entete: Padding(
          padding: const EdgeInsets.fromLTRB(margeEcran - 12, 12, margeEcran, 6),
          child: Row(
            children: [
              BoutonNu(trait: Trait.fermer, label: 'Fermer', onTap: _back),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.titrePage(context)),
                    Text(sousTitre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.detail(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
        bas: bottom,
        child: browser,
      ),
    );
  }
}
