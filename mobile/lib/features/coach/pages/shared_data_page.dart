import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/coach_prefs.dart';
import '../widgets/coach_scope.dart';

/// Interrupteurs de ce que le coach a le droit de lire.
class SharedDataPage extends StatelessWidget {
  const SharedDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CoachListen(builder: (context, prefs, engine) {
      final ctrl = context.coachPrefs;
      final tout = prefs.partage.length == CoachPartage.values.length;
      return SubPageScaffold(
        title: 'Données partagées',
        subtitle: '${prefs.partage.length} sur ${CoachPartage.values.length}',
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 0, AppTokens.gutter + 4, 14),
              child: Text(
                'Le coach ne lit que ce que tu autorises ici. Plus il en sait, plus ses conseils sont précis. '
                'Ces réglages valent aussi pour la phrase du jour et le bilan.',
                style: AppType.rowSubtitle(),
              ),
            ),
            TileGroup(
              label: 'Le coach peut lire',
              labelTrailing: AccentLink(
                label: tout ? 'Tout couper' : 'Tout autoriser',
                onTap: () => ctrl.update((p) => p.copyWith(partage: tout ? <CoachPartage>{} : {...CoachPartage.values})),
              ),
              children: [
                for (final d in CoachPartage.values)
                  ListTileX(
                    leading: IconHalo.domain(d.domain, icon: d.icon, size: 40, off: !prefs.peut(d)),
                    title: d.label,
                    subtitle: d.description,
                    trailing: Switch(
                      value: prefs.peut(d),
                      onChanged: (v) => ctrl.update((p) => p.copyWith(partage: v ? {...p.partage, d} : ({...p.partage}..remove(d)))),
                    ),
                    onTap: () => ctrl.update(
                      (p) => p.copyWith(partage: p.peut(d) ? ({...p.partage}..remove(d)) : {...p.partage, d}),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
              label: 'Période d\'historique',
              labelTrailing: LabelCount('${prefs.periodeJours} jours'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedChips<int>(
                    segments: const [(14, '2 semaines'), (30, '1 mois'), (60, '2 mois'), (90, '3 mois')],
                    value: prefs.periodeJours,
                    onChanged: (v) => ctrl.update((p) => p.copyWith(periodeJours: v)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Séances détaillées envoyées au coach. Une période longue donne plus de recul mais des réponses un peu plus coûteuses.',
                    style: AppType.rowSubtitle().copyWith(fontSize: 12.5, color: c.text3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
              child: PillButton.secondary(
                label: 'Voir ce que lit le coach',
                icon: Icons.visibility_rounded,
                chevron: true,
                expand: true,
                onPressed: () => context.push('/coach/reglages/contexte'),
              ),
            ),
          ],
        ),
      );
    });
  }
}
