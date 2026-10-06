import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../widgets/actions.dart';
import '../widgets/commun.dart';

const _qualites = ['Très mauvaise', 'Mauvaise', 'Correcte', 'Bonne', 'Excellente'];

/// Sommeil : dernière nuit, semaine, historique.
class SommeilPage extends StatelessWidget {
  const SommeilPage({super.key});

  Future<void> _supprimer(BuildContext context, SleepEntry s) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer cette nuit ?',
      message: '${Fmt.jourCap(s.jour)}, ${Fmt.sommeil(s.duree)}',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final h = context.read<HealthRepo>();
    await h.deleteSleep(s.id);
    if (context.mounted) Toasts.show(context, 'Nuit supprimée.', actionLabel: 'Annuler', onAction: () => h.saveSleep(s));
  }

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HealthRepo>();
    final c = context.colors;
    final now = DateTime.now();
    final nuits = h.sleep;
    final derniere = h.sleepFor(now) ?? h.lastSleep;
    final moy7 = h.averageSleep(days: 7);
    final moy30 = h.averageSleep(days: 30);
    final jours = [for (var i = 6; i >= 0; i--) Dates.jour(now.subtract(Duration(days: i)))];

    if (nuits.isEmpty) {
      return SubPageScaffold(
        title: 'Sommeil',
        haloColor: c.sleep,
        body: Center(
          child: EmptyState(
            icon: Icons.bedtime_rounded,
            iconColor: c.sleep,
            title: 'Aucune nuit notée',
            message: 'Note l\'heure du coucher et du lever pour suivre ton sommeil, ou connecte Health Connect dans le suivi santé.',
            actionLabel: 'Noter ma nuit',
            onAction: () => saisirSommeil(context),
            secondaryLabel: 'Suivi santé',
            onSecondary: () => context.push(Paths.sante),
          ),
        ),
      );
    }

    final d = derniere!;
    final phases = <(String, int?, Color)>[
      ('Profond', d.profondMin, c.sleep),
      ('Léger', d.legerMin, c.sleep.withValues(alpha: 0.55)),
      ('Paradoxal', d.paradoxalMin, c.coach),
      ('Éveil', d.eveilMin, c.warning),
    ];

    return SousPage(
      title: 'Sommeil',
      haloColor: c.sleep,
      actions: [
        IconButton(tooltip: 'Suivi santé', onPressed: () => context.push(Paths.sante), icon: const Icon(Icons.favorite_outline_rounded)),
      ],
      bottomBar: PillButton(
        label: h.sleepFor(now) == null ? 'Noter ma nuit' : 'Modifier la nuit dernière',
        icon: h.sleepFor(now) == null ? Icons.add_rounded : Icons.edit_rounded,
        size: PillSize.large,
        expand: true,
        onPressed: () => saisirSommeil(context, existant: h.sleepFor(now)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            label: Dates.memeJour(d.jour, now) ? 'Nuit dernière' : 'Dernière nuit notée · ${Fmt.relatif(d.jour)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BigNumber(
                  value: Fmt.sommeil(d.duree),
                  caption: '${Fmt.heure(d.coucher)} à ${Fmt.heure(d.lever)}${d.qualite == null ? '' : ' · ${_qualites[(d.qualite! - 1).clamp(0, 4)]}'}',
                  color: c.sleep,
                ),
                if (d.aDesPhases) ...[
                  const SizedBox(height: 16),
                  SegmentedBar(parts: [for (final p in phases) if ((p.$2 ?? 0) > 0) (p.$2!.toDouble(), p.$3)]),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      for (final p in phases)
                        if ((p.$2 ?? 0) > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('${p.$1} ${Fmt.duree(Duration(minutes: p.$2!))}', style: AppType.rowSubtitle(color: c.text2)),
                            ],
                          ),
                    ],
                  ),
                ],
                if (d.notes != null && d.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(d.notes!, style: AppType.rowSubtitle(color: c.text2)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            label: '7 dernières nuits',
            labelTrailing: const LabelCount('repère 8 h'),
            child: BarresJours(
              valeurs: [for (final j in jours) h.sleepFor(j)?.duree.inMinutes.toDouble()],
              libelles: [for (final j in jours) Dates.initiale(j)],
              etiquettes: [
                for (final j in jours)
                  switch (h.sleepFor(j)) {
                    final s? => '${s.duree.inHours}h${(s.duree.inMinutes % 60).toString().padLeft(2, '0')}',
                    null => '',
                  },
              ],
              couleur: c.sleep,
              objectif: 480,
              surlignee: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatTile(label: 'Moyenne 7 j', value: moy7 == null ? '-' : Fmt.sommeil(moy7), compact: true)),
              const SizedBox(width: 12),
              Expanded(child: StatTile(label: 'Moyenne 30 j', value: moy30 == null ? '-' : Fmt.sommeil(moy30), compact: true)),
            ],
          ),
          const SizedBox(height: 12),
          TileGroup(
            margin: EdgeInsets.zero,
            label: 'Historique',
            labelTrailing: LabelCount(Fmt.pluriel(nuits.length, 'nuit')),
            children: [
              for (final s in nuits.take(21))
                ListTileX(
                  leading: IconHalo.domain(AppDomain.sommeil, size: 38, glow: false),
                  title: Fmt.jourCap(s.jour),
                  subtitle: [
                    '${Fmt.heure(s.coucher)} à ${Fmt.heure(s.lever)}',
                    if (s.qualite != null) _qualites[(s.qualite! - 1).clamp(0, 4)],
                    if (s.source != null && s.source != 'manuel') s.source == 'health connect' ? 'Health Connect' : 'importée',
                  ].join(' · '),
                  value: Fmt.sommeil(s.duree),
                  onTap: () => saisirSommeil(context, existant: s),
                  onLongPress: () => _supprimer(context, s),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Touche une nuit pour la modifier, appui long pour la supprimer.', textAlign: TextAlign.center, style: AppType.rowSubtitle()),
        ],
      ),
    );
  }
}
