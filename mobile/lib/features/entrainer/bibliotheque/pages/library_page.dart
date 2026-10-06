import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import '../logic/exercise_index.dart';
import 'exercise_browser.dart';
import 'exercise_detail_page.dart';
import 'exercise_edit_page.dart';
import 'muscles_page.dart';

/// Bibliothèque d'exercices en page pleine (ouverte depuis un autre onglet).
/// Sur le Fold ouvert : la liste à gauche, la fiche à droite.
class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({super.key, this.initial = const LibraryFilters(), this.title = 'Exercices'});

  final LibraryFilters initial;
  final String title;

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  String? _selected;

  Future<void> _create(String nom) async {
    final e = await ExerciseEditPage.open(context, initialName: nom);
    if (e == null || !mounted) return;
    if (context.isExpanded) {
      setState(() => _selected = e.id);
    } else {
      await ouvrirFicheExercice(context, e.id);
    }
  }

  void _open(Exercise e) {
    if (context.isExpanded) {
      setState(() => _selected = e.id);
    } else {
      ouvrirFicheExercice(context, e.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<ExerciseRepo>();
    final wide = context.isExpanded;
    final browser = ExerciseBrowser(
      initial: widget.initial,
      config: BrowserConfig(
        onOpen: _open,
        onCreate: _create,
        selectedId: wide ? _selected : null,
        // Page pleine : l'explorateur s'ouvre par-dessus, sur le même navigateur.
        onMuscles: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MusclesPage())),
      ),
    );
    final entete = EnTetePage(titre: widget.title);
    if (!wide) return PageEntrainer(entete: entete, child: browser);

    final e = _selected == null ? null : repo.byId(_selected!);
    final volet = e == null
        ? const Center(
            child: Vide(trait: Trait.corps, titre: 'Choisis un exercice', message: 'Sa fiche s’affiche ici : animation, muscles, historique, courbes et records.'),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EnTetePage(titre: e.nom, retour: false, actions: ficheActions(context, e, onDeleted: () => setState(() => _selected = null))),
              Expanded(child: ExerciseDetailView(key: ValueKey(e.id), exercise: e)),
            ],
          );

    return Scaffold(
      backgroundColor: c.bg,
      body: TexteNet(
        child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 420, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [entete, Expanded(child: browser)])),
            Container(width: 1, color: c.line),
            Expanded(child: volet),
          ],
        ),
        ),
      ),
    );
  }
}
