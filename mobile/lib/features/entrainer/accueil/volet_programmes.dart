import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../commun/elements.dart';
import '../commun/traits.dart';
import '../routines/logic/vignettes.dart';
import '../routines/widgets/photo_programme.dart';

/// Programmes dans l'ordre de la bibliothèque : par nom, sans tenir compte
/// des majuscules ni des accents ; les versions d'un même programme se
/// suivent, la plus récente en tête (« V4 », « V3 », « V2 », « V1 »).
List<Program> programmesTries(List<Program> programmes) => [...programmes]..sort((a, b) {
    final c = comparerNoms(a.nom, b.nom);
    // Même nom : le plus récent d'abord.
    return c != 0 ? c : b.creeLe.compareTo(a.creeLe);
  });

/// Compare deux noms de programme : les lettres dans l'ordre de l'alphabet
/// (sans accents ni casse), chaque suite de chiffres comme un nombre, du
/// plus grand au plus petit.
int comparerNoms(String a, String b) {
  final morceaux = RegExp(r'\d+|\D+');
  final x = morceaux.allMatches(TextSearch.normalize(a)).map((m) => m[0]!).toList();
  final y = morceaux.allMatches(TextSearch.normalize(b)).map((m) => m[0]!).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final nx = int.tryParse(x[i]);
    final ny = int.tryParse(y[i]);
    final c = nx != null && ny != null ? ny.compareTo(nx) : x[i].compareTo(y[i]);
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}

/// Nombre de routines d'un programme qui existent encore.
int nbRoutines(Program p, RoutineRepo routines) => p.routineIds.toSet().where((id) => routines.byId(id) != null).length;

/// Volet Programmes : toujours la bibliothèque. Créer un programme, les
/// favoris, les programmes, puis le bouton des idées.
class VoletProgrammes extends StatelessWidget {
  const VoletProgrammes({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final programmes = context.watch<ProgramRepo>();
    final routines = context.watch<RoutineRepo>();
    final prefs = RoutinePrefs.of(context.read<Store>());

    Widget ligne({required Widget tuile, required String titre, String? detail, Widget? fin, required VoidCallback onTap}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7.5),
            child: Row(
              children: [
                tuile,
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.ligne(context)),
                      if (detail != null) Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.detail(context)),
                    ],
                  ),
                ),
                if (fin != null) ...[const SizedBox(width: 10), fin],
              ],
            ),
          ),
        );
    final chevron = IconeTrait(Trait.chevronDroit, size: 17.5, color: c.text3);

    return ListView(
      padding: const EdgeInsets.fromLTRB(margeEcran, 12.5, margeEcran, 28),
      children: [
        ligne(
          tuile: const Tuile(child: IconeTrait(Trait.plus, size: 25)),
          titre: 'Créer un programme',
          onTap: () => context.push('/entrainer/programmes/nouveau'),
        ),
        ListenableBuilder(
          listenable: prefs,
          builder: (context, _) {
            final n = prefs.favoris.where((id) => routines.byId(id) != null).length;
            return ligne(
              tuile: const Tuile(child: IconeTrait(Trait.signet, size: 25)),
              titre: 'Favoris',
              detail: Fmt.pluriel(n, 'routine'),
              fin: chevron,
              onTap: () => context.push('/entrainer/routines/favoris'),
            );
          },
        ),
        for (final p in programmesTries(programmes.programs))
          ligne(
            tuile: TuileDuProgramme(p),
            titre: p.nom,
            detail: Fmt.pluriel(nbRoutines(p, routines), 'routine'),
            fin: p.actif ? const Pastille('En cours', ton: TonPastille.ok) : chevron,
            onTap: () => context.push('/entrainer/programmes/${p.id}'),
          ),
        const SizedBox(height: 10),
        BoutonSecondaire(label: 'Voir des idées de programmes', onPressed: () => context.push('/entrainer/programmes/idees')),
      ],
    );
  }
}
