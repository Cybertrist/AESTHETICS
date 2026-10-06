import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../seance/seance_paths.dart';
import '../bibliotheque/pages/exercise_browser.dart';
import '../bibliotheque/pages/exercise_detail_page.dart';
import '../bibliotheque/pages/exercise_edit_page.dart';
import '../commun/elements.dart';
import '../commun/traits.dart';
import 'volet_programmes.dart';
import 'volet_routines.dart';

/// Les trois volets de l'onglet.
enum VoletEntrainer {
  programmes('Programmes'),
  routines('Routines'),
  exercices('Exercices');

  const VoletEntrainer(this.label);
  final String label;

  /// Lit `?onglet=` ; « seances » (ancien nom) ouvre les routines.
  static VoletEntrainer parse(String? s) => switch (s) {
        'routines' || 'seances' => VoletEntrainer.routines,
        'exercices' => VoletEntrainer.exercices,
        _ => VoletEntrainer.programmes,
      };
}

/// Racine de l'onglet Entraîner : un sélecteur segmenté et trois volets,
/// Programmes, Routines, Exercices.
class EntrainerPage extends StatefulWidget {
  const EntrainerPage({super.key, this.initial = VoletEntrainer.programmes, this.maintenant});

  /// Volet de départ (`?onglet=programmes|routines|exercices`).
  final VoletEntrainer initial;

  /// Date de référence de la suggestion (les tests figent le jour).
  final DateTime? maintenant;

  @override
  State<EntrainerPage> createState() => _EntrainerPageState();
}

class _EntrainerPageState extends State<EntrainerPage> {
  late VoletEntrainer _volet = widget.initial;
  final _browser = ExerciseBrowserController();

  @override
  void didUpdateWidget(covariant EntrainerPage old) {
    super.didUpdateWidget(old);
    // Une adresse avec un autre `?onglet=` change de volet.
    if (old.initial != widget.initial) _volet = widget.initial;
  }

  @override
  void dispose() {
    _browser.dispose();
    super.dispose();
  }

  Future<void> _creerExercice(String nom) async {
    final e = await ExerciseEditPage.open(context, initialName: nom);
    if (e != null && mounted) await ouvrirFicheExercice(context, e.id);
  }

  /// Le « + » : un panneau du bas avec ce qu'on peut créer.
  Future<void> _ajouter() async {
    final choix = await showPanneauBas<VoletEntrainer>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LigneCreer(
            icone: const IconeTrait(Trait.dossier, size: 26),
            titre: 'Programme',
            detail: 'Crée un programme avec tes routines',
            onTap: () => Navigator.pop(context, VoletEntrainer.programmes),
          ),
          _LigneCreer(
            icone: const TraitIcone(AppIcone.progres, size: 26),
            titre: 'Routine',
            detail: 'Crée une routine d’entraînement réutilisable',
            onTap: () => Navigator.pop(context, VoletEntrainer.routines),
          ),
          _LigneCreer(
            icone: const TraitIcone(AppIcone.haltere, size: 26),
            titre: 'Exercice',
            detail: 'Crée un exercice personnalisé',
            onTap: () => Navigator.pop(context, VoletEntrainer.exercices),
          ),
        ],
      ),
    );
    if (choix == null || !mounted) return;
    switch (choix) {
      case VoletEntrainer.programmes:
        context.push('/entrainer/programmes/nouveau');
      case VoletEntrainer.routines:
        context.push('/entrainer/routines/nouvelle');
      case VoletEntrainer.exercices:
        await _creerExercice('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final plus = BoutonRond(icone: const IconeTrait(Trait.plusFort, size: 22.5), label: 'Ajouter', onTap: _ajouter);
    final action = switch (_volet) {
      VoletEntrainer.programmes => plus,
      VoletEntrainer.routines => plus,
      VoletEntrainer.exercices => BoutonRond(
          icone: const IconeTrait(Trait.historique, size: 22.5),
          label: 'Historique',
          onTap: () => context.push(SeancePaths.historique),
        ),
    };
    final contenu = switch (_volet) {
      VoletEntrainer.programmes => const VoletProgrammes(key: ValueKey('programmes')),
      VoletEntrainer.routines => VoletRoutines(key: const ValueKey('routines'), maintenant: widget.maintenant),
      VoletEntrainer.exercices => ListenableBuilder(
          key: const ValueKey('exercices'),
          listenable: _browser,
          builder: (context, _) => CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              ...exerciseBrowserSlivers(
                context,
                _browser,
                BrowserConfig(
                  onOpen: (e) => ouvrirFicheExercice(context, e.id),
                  onCreate: _creerExercice,
                  onMuscles: () => context.push('/entrainer/muscles'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
    };
    return Scaffold(
      backgroundColor: c.bg,
      body: TexteNet(
        child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            // La grille d'exercices profite de la largeur du Fold ouvert.
            constraints: BoxConstraints(maxWidth: _volet == VoletEntrainer.exercices ? 1100 : largeurContenu),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EnTeteOnglet(titre: 'Entraînement', action: action),
                Padding(
                  padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 12.5),
                  child: SelecteurSegmente<VoletEntrainer>(
                    segments: [for (final v in VoletEntrainer.values) (v, v.label)],
                    value: _volet,
                    onChanged: (v) {
                      setState(() => _volet = v);
                      // L'adresse suit le volet : un lien vers un volet reste suivi
                      // après un changement à la main (l'onglet garde son état).
                      GoRouter.maybeOf(context)?.go('/entrainer?onglet=${v.name}');
                    },
                  ),
                ),
                Expanded(child: contenu),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Ligne du panneau « + » : une icône dans un rond, un titre et ce qu'il crée.
class _LigneCreer extends StatelessWidget {
  const _LigneCreer({required this.icone, required this.titre, required this.detail, required this.onTap});
  final Widget icone;
  final String titre;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$titre. $detail',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTokens.radius16,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.surface3, shape: BoxShape.circle),
                child: IconTheme.merge(data: IconThemeData(color: c.text), child: icone),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.ligneForte(context)),
                    Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: TexteEntrainer.detail(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
