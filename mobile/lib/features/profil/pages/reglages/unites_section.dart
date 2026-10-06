import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../widgets/maquette.dart';

/// Réglages > Unités : poids, distance et mesures du corps. Tout reste
/// enregistré en kilogrammes, mètres et centimètres ; seul l'affichage suit.
class UnitesSection extends StatelessWidget {
  const UnitesSection({super.key});

  static const _noms = {UnitePoids.kg: 'Kilogrammes', UnitePoids.lb: 'Livres'};

  @override
  Widget build(BuildContext context) {
    final profileRepo = context.watch<ProfileRepo>();
    final unite = profileRepo.unite;
    final pouces = profileRepo.profile?.pouces ?? false;
    final miles = profileRepo.profile?.miles ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupeTitre(
          premier: true,
          titre: 'Poids',
          lignes: [
            for (final u in UnitePoids.values)
              LigneChoix(
                trace: Trace.unites,
                titre: _noms[u] ?? u.label,
                detail: 'Exemple : ${Fmt.poids(80, u)}',
                choisie: u == unite,
                onTap: () => profileRepo.update((p) => p.copyWith(unitePoids: u)),
              ),
          ],
        ),
        GroupeTitre(
          titre: 'Distance',
          lignes: [
            for (final (mi, nom, exemple) in const [(false, 'Kilomètres', '5 km'), (true, 'Miles', '3,11 mi')])
              LigneChoix(
                trace: Trace.chrono,
                titre: nom,
                detail: 'Exemple : $exemple',
                choisie: mi == miles,
                onTap: () => profileRepo.update((p) => p.copyWith(miles: mi)),
              ),
          ],
        ),
        GroupeTitre(
          titre: 'Mesures du corps',
          lignes: [
            for (final (po, nom, exemple) in const [(false, 'Centimètres', '38 cm'), (true, 'Pouces', '15 po')])
              LigneChoix(
                trace: Trace.regle,
                titre: nom,
                detail: 'Exemple : $exemple',
                choisie: po == pouces,
                onTap: () => profileRepo.update((p) => p.copyWith(pouces: po)),
              ),
          ],
          note: 'Tes données restent enregistrées en kilogrammes, mètres et centimètres : changer d\'unité ne modifie rien, seul l\'affichage suit.',
        ),
      ],
    );
  }
}
