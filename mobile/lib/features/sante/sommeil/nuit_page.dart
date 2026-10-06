import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../common/sante_calculs.dart';
import '../common/sante_widgets.dart';
import '../services/activite_journal.dart';
import 'sommeil_page.dart';

/// Détail d'une nuit : durée, heures, phases, qualité, notes.
class NuitPage extends StatelessWidget {
  const NuitPage({super.key, required this.id});
  final String id;

  Future<void> _supprimer(BuildContext context, SleepEntry n) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer cette nuit ?',
      message: n.source == 'health connect'
          ? 'Elle reviendra à la prochaine synchronisation si elle est toujours dans Health Connect.'
          : 'La nuit du ${Fmt.jour(n.jour)} sera effacée.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return;
    final repo = context.read<HealthRepo>();
    await repo.deleteSleep(n.id);
    if (!context.mounted) return;
    context.pop();
    Toasts.show(context, 'Nuit supprimée', actionLabel: 'Annuler', onAction: () => repo.saveSleep(n));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final n = repo.sleep.firstWhereOrNull((s) => s.id == id);
    if (n == null) {
      return SubPageScaffold(
        title: 'Nuit',
        haloColor: c.sleep,
        body: Center(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            iconColor: c.sleep,
            title: 'Nuit introuvable',
            message: 'Elle a peut-être été supprimée.',
            actionLabel: 'Retour au sommeil',
            onAction: () => context.go('/sante/sommeil'),
          ),
        ),
      );
    }
    final objectif = ActiviteJournal.of(context.read<Store>()).objectifSommeilMin;
    final dormi = SanteCalc.minutesDormies(n);
    final pct = (n.duree.inMinutes / objectif).clamp(0.0, 1.5);
    final phases = [
      (n.profondMin ?? 0, PhasesCouleurs.profond, 'Sommeil profond', Icons.nights_stay_rounded, 'Réparation musculaire, hormone de croissance'),
      (n.legerMin ?? 0, PhasesCouleurs.leger, 'Sommeil léger', Icons.bedtime_rounded, 'La plus grande partie de la nuit'),
      (n.paradoxalMin ?? 0, PhasesCouleurs.paradoxal, 'Sommeil paradoxal', Icons.auto_awesome_rounded, 'Mémoire et apprentissage moteur'),
      (n.eveilMin ?? 0, PhasesCouleurs.eveil, 'Éveils', Icons.visibility_rounded, 'Réveils brefs pendant la nuit'),
    ];
    final total = phases.fold<int>(0, (a, p) => a + p.$1);

    return SubPageScaffold(
      title: Fmt.jourCap(n.jour),
      subtitle: n.source == 'health connect' ? 'Importée de Health Connect' : 'Saisie à la main',
      haloColor: c.sleep,
      actions: [
        RoundIconButton(
          icon: Icons.edit_rounded,
          filled: false,
          tooltip: 'Modifier',
          onPressed: () => context.push('/sante/sommeil/nuit/${n.id}/modifier'),
        ),
        const SizedBox(width: 6),
        RoundIconButton(
          icon: Icons.delete_outline_rounded,
          filled: false,
          tooltip: 'Supprimer',
          onPressed: () => _supprimer(context, n),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          SanteColonnes(children: [
            Padding(
              padding: santePad,
              child: AppCard(
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    ProgressRing(
                      value: pct,
                      size: 170,
                      stroke: 14,
                      color: c.sleep,
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Fmt.sommeil(n.duree), style: AppType.number(30)),
                          const SizedBox(height: 2),
                          Text('${(n.duree.inMinutes / objectif * 100).round()} % de l\'objectif', style: AppType.rowSubtitle()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: MiniChiffre(label: 'Coucher', value: Fmt.heure(n.coucher), caption: Fmt.jourMois(n.coucher))),
                        Expanded(child: MiniChiffre(label: 'Lever', value: Fmt.heure(n.lever), caption: Fmt.jourMois(n.lever))),
                        Expanded(child: MiniChiffre(label: 'Endormi', value: Fmt.sommeil(Duration(minutes: dormi)), caption: 'sans les éveils')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: santePad,
              child: AppCard(
                label: 'Ressenti',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QualitePicker(
                      value: n.qualite,
                      onChanged: (q) => repo.saveSleep(SleepEntry.fromJson({...n.toJson(), 'qualite': q})),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: AppTokens.radius12,
                      onTap: () async {
                        final t = await showTextInputDialog(context, title: 'Note sur la nuit', initial: n.notes ?? '', hint: 'Café tard, réveil à 3 h, bruit...', maxLines: 4);
                        if (t != null) await repo.saveSleep(SleepEntry.fromJson({...n.toJson(), 'notes': t}));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: c.surface3, borderRadius: AppTokens.radius12),
                        child: Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: c.text3),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                n.notes == null || n.notes!.isEmpty ? 'Ajouter une note' : n.notes!,
                                style: AppType.rowSubtitle(color: n.notes == null || n.notes!.isEmpty ? c.text3 : c.text2).copyWith(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (total > 0) ...[
            AppCard(
              margin: santePad,
              label: 'Phases',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedBar(parts: [for (final p in phases) if (p.$1 > 0) (p.$1.toDouble(), p.$2)], height: 12),
                  const SizedBox(height: 8),
                  for (final p in phases)
                    ListTileX(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      leading: IconHalo(icon: p.$4, color: p.$2, size: 36, glow: false),
                      title: p.$3,
                      subtitle: p.$5,
                      value: Fmt.duree(Duration(minutes: p.$1)),
                      trailing: SizedBox(
                        width: 40,
                        child: Text('${(p.$1 / total * 100).round()} %', textAlign: TextAlign.right, style: AppType.rowSubtitle()),
                      ),
                    ),
                ],
              ),
            ),
          ] else
            AppCard(
              margin: santePad,
              label: 'Phases',
              child: Text(
                'Pas de phases pour cette nuit. Une montre reliée à Health Connect les fournit, ou vous pouvez les saisir en modifiant la nuit.',
                style: AppType.rowSubtitle().copyWith(fontSize: 13.5),
              ),
            ),
        ],
      ),
    );
  }
}
