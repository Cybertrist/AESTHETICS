import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/theme/theme.dart';
import '../../widgets/maquette.dart';

/// Page des réglages du coach, tenue par le module coach.
const routeReglagesCoach = '/coach/reglages';

/// Réglages > Coach : résumé et lien vers les réglages du coach.
class CoachSection extends StatelessWidget {
  const CoachSection({super.key});

  static const _tons = {
    'bienveillant': 'Bienveillant',
    'direct': 'Direct',
    'exigeant': 'Exigeant',
    'pedagogue': 'Pédagogue',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<SettingsRepo>().settings;
    final conversations = context.watch<CoachRepo>().conversations.length;
    final cle = s.coachApiKey != null && s.coachApiKey!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Bloc(
          haut: 2,
          bas: 6,
          child: Carte(
            padding: EdgeInsets.all(e(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Surtitre('Ton coach'),
                SizedBox(height: e(2)),
                Text(cle ? 'Connecté à l\'IA' : 'Mode hors ligne', style: txt(17, FontWeight.w700, c.text)),
                SizedBox(height: e(4)),
                Text(
                  cle
                      ? 'Le coach répond avec ta clé, gardée sur ce téléphone.'
                      : 'Sans clé, le coach calcule ses conseils sur le téléphone. Ajoute une clé pour discuter librement.',
                  style: txt(12, FontWeight.w400, c.text2),
                ),
                SizedBox(height: e(12)),
                BoutonDuo(label: 'Réglages du coach', onPressed: () => context.push(routeReglagesCoach)),
              ],
            ),
          ),
        ),
        GroupeTitre(
          titre: 'En bref',
          lignes: [
            Ligne(trace: Trace.cle, titre: 'Clé', valeur: cle ? 'Enregistrée' : 'Aucune', onTap: () => context.push(routeReglagesCoach)),
            Ligne(trace: Trace.reglages, titre: 'Modèle', valeur: s.coachModele ?? 'Par défaut', onTap: () => context.push(routeReglagesCoach)),
            Ligne(trace: Trace.son, titre: 'Ton', valeur: _tons[s.coachTon] ?? s.coachTon, onTap: () => context.push(routeReglagesCoach)),
            Ligne(trace: Trace.etoile, titre: 'Conversations', valeur: '$conversations', onTap: () => context.go('/coach')),
          ],
          note: 'Ce que le coach peut lire, sa façon de répondre et ses bilans se règlent dans ses propres réglages.',
        ),
      ],
    );
  }
}
