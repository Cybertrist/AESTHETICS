import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/ui/ui.dart';
import '../data/mensurations.dart';
import '../routes.dart';
import '../widgets/maquette.dart';

/// Historique des mesures : une ligne par jour de saisie, la plus récente
/// en haut. Toucher une ligne rouvre la saisie.
class HistoriquePage extends StatelessWidget {
  const HistoriquePage({super.key});

  /// Ce que contient une saisie ; null (pas de ligne vide) si elle ne porte
  /// rien que cet écran sache montrer.
  static String? _detail(BodyMeasurement m, UnitePoids unite) {
    final n = Mensurations.nbMesures(m);
    final d = [
      if (n > 0) Fmt.pluriel(n, 'mesure'),
      if (m.poidsKg != null) Fmt.poids(m.poidsKg, unite),
      if (n == 0 && m.poidsKg == null && m.masseGrassePct != null) '${Fmt.n(m.masseGrassePct)} % de gras',
    ].join(' · ');
    return d.isEmpty ? null : d;
  }

  @override
  Widget build(BuildContext context) {
    final unite = context.watch<ProfileRepo>().unite;
    final saisies = Mensurations.historique(context.watch<HealthRepo>().measurements);
    final ecart = Mensurations.joursEntreSaisies(saisies);

    return PageMaquette(
      titre: 'Historique des mesures',
      bas: BoutonPrincipal(label: 'Nouvelle saisie', onPressed: () => context.push(ProfilPaths.saisie())),
      enfants: [
        if (saisies.isEmpty)
          const Vide(titre: 'Aucune saisie pour l\'instant', message: 'Tes mesures apparaîtront ici, jour par jour.')
        else ...[
          Bloc(
            child: Row(
              children: [
                Expanded(
                  child: TuileChiffre(
                    grande: true,
                    valeur: '${saisies.length}',
                    label: '${saisies.length >= 2 ? 'saisies' : 'saisie'} depuis ${Mensurations.moisDe(saisies.last.date)}',
                  ),
                ),
                if (ecart != null) ...[
                  SizedBox(width: e(8)),
                  Expanded(
                    child: TuileChiffre(grande: true, valeur: Fmt.pluriel(ecart, 'jour'), label: 'entre deux saisies'),
                  ),
                ],
              ],
            ),
          ),
          Bloc(
            child: Groupe(
              lignes: [
                for (final m in saisies)
                  Ligne(
                    trace: Trace.calendrier,
                    titre: DateFormat('d MMMM y', 'fr_FR').format(m.date),
                    detail: _detail(m, unite),
                    onTap: () => context.push(ProfilPaths.saisie(id: m.id)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
