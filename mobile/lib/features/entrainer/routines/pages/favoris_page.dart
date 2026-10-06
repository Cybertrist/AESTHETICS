import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import '../logic/vignettes.dart';
import '../widgets/ligne_routine.dart';

/// Les routines mises en favori (trois points d'une routine, « Ajouter aux
/// favoris »).
class FavorisPage extends StatelessWidget {
  const FavorisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final routines = context.watch<RoutineRepo>();
    final prefs = RoutinePrefs.of(context.read<Store>());
    return PageEntrainer(
      entete: const EnTetePage(titre: 'Favoris'),
      child: ListenableBuilder(
        listenable: prefs,
        builder: (context, _) {
          final tous = routines.routines;
          final favoris = [
            for (final (i, r) in tous.indexed)
              if (prefs.estFavori(r.id)) (i, r),
          ];
          if (favoris.isEmpty) {
            return const SingleChildScrollView(
              child: Vide(
                trait: Trait.signet,
                titre: 'Aucune routine en favori',
                message: 'Touche les trois points d’une routine, puis « Ajouter aux favoris », pour la retrouver ici.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(margeEcran, 6, margeEcran, 28),
            children: [
              for (final (rang, r) in favoris)
                Padding(padding: const EdgeInsets.only(bottom: 12.5), child: LigneRoutine(routine: r, rang: rang)),
            ],
          );
        },
      ),
    );
  }
}
