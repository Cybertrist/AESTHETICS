import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../entrainer/bibliotheque/bibliotheque.dart';
import '../logic/editeur.dart';
import '../widgets/habillage.dart';
import '../widgets/pages.dart';

/// Réordonner les exercices par glisser-déposer.
class ReordonnerPage extends StatefulWidget {
  const ReordonnerPage({super.key, required this.editeur});

  final SeanceEditeur editeur;

  @override
  State<ReordonnerPage> createState() => _ReordonnerPageState();
}

class _ReordonnerPageState extends State<ReordonnerPage> {
  late List<String> _ids = widget.editeur.session?.exercices.map((e) => e.id).toList() ?? [];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final exos = context.watch<ExerciseRepo>();
    final s = widget.editeur.session;
    final par = <String, SessionExercise>{for (final e in s?.exercices ?? const <SessionExercise>[]) e.id: e};
    _ids = _ids.where(par.containsKey).toList();
    return PageSeance(
      titre: 'Réordonner',
      sousTitre: 'Maintiens puis glisse un exercice',
      bas: _ids.isEmpty
          ? null
          : BoutonSeance(
              label: 'Valider l\'ordre',
              fond: c.bouton,
              encre: c.onBouton,
              onTap: () async {
                await widget.editeur.reordonner(_ids);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
      body: _ids.isEmpty
          ? const VideSeance(icone: Trait(IconeSeance.poignee), titre: 'Aucun exercice', message: 'Ajoute des exercices pour pouvoir les réordonner.')
          : ReorderableListView.builder(
              padding: EdgeInsets.fromLTRB(margeSeance, k(6), margeSeance, k(16)),
              itemCount: _ids.length,
              proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
              onReorderItem: (a, b) => setState(() {
                _ids.insert(b, _ids.removeAt(a));
              }),
              itemBuilder: (context, i) {
                final se = par[_ids[i]]!;
                final lettre = widget.editeur.lettreSuperset(se.supersetId);
                return Padding(
                  key: ValueKey(se.id),
                  padding: EdgeInsets.only(bottom: k(8)),
                  child: LigneCarte(
                    tete: ClipRRect(
                      borderRadius: BorderRadius.circular(k(10)),
                      child: ColoredBox(color: c.surface2, child: ExerciseThumb(exos.byId(se.exerciseId), size: k(40))),
                    ),
                    titre: exos.nameOf(se.exerciseId),
                    detail: [
                      se.series.isEmpty ? 'Aucune série' : Fmt.pluriel(se.series.length, 'série'),
                      if (lettre != null) 'Superset $lettre',
                    ].join(' · '),
                    fin: ReorderableDragStartListener(
                      index: i,
                      child: Semantics(
                        label: 'Déplacer',
                        child: Padding(
                          padding: EdgeInsets.all(k(9)),
                          child: Trait(IconeSeance.poignee, size: k(20), color: c.text2),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Réordonner la séance en cours (route `/seance/reordonner`).
class ReordonnerRoute extends StatefulWidget {
  const ReordonnerRoute({super.key});

  @override
  State<ReordonnerRoute> createState() => _ReordonnerRouteState();
}

class _ReordonnerRouteState extends State<ReordonnerRoute> {
  late final EditeurDirect _ed = EditeurDirect(context.read<SessionRepo>());

  @override
  void dispose() {
    _ed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ReordonnerPage(editeur: _ed);
}
