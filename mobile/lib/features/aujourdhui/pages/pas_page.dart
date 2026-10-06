import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/pas_repo.dart';
import '../widgets/actions.dart';
import '../widgets/commun.dart';

/// Pas du jour et de la semaine, saisie et Health Connect.
class PasPage extends StatelessWidget {
  const PasPage({super.key});

  Future<void> _effacer(BuildContext context, PasRepo repo, DateTime jour) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Effacer la saisie ?',
      message: repo.source(jour) == SourcePas.saisie ? 'Le nombre lu dans Health Connect reprendra sa place s\'il existe.' : null,
      confirmLabel: 'Effacer',
      destructive: true,
    );
    if (ok) await repo.effacerSaisie(jour);
  }

  Future<void> _connecter(BuildContext context, PasRepo repo) async {
    final ok = await repo.connecter();
    if (!context.mounted) return;
    if (ok) {
      Toasts.success(context, 'Pas synchronisés depuis Health Connect.');
    } else if (repo.erreur != null) {
      Toasts.error(context, repo.erreur!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = PasRepo.pour(context.read<Store>());
    final santeActive = context.watch<SettingsRepo>().settings.santeConnectee;
    final c = context.colors;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final now = DateTime.now();
        final jour = repo.pas(now);
        final semaine = repo.derniersJours(7);
        final quinze = repo.derniersJours(14).reversed.toList();
        final valeurs = semaine.map((e) => e.pas).whereType<int>().toList();
        final moyenne = valeurs.isEmpty ? null : valeurs.reduce((a, b) => a + b) / valeurs.length;
        final record = valeurs.isEmpty ? null : valeurs.reduce((a, b) => a > b ? a : b);
        final connecte = santeActive || repo.derniereSynchro != null;

        Widget corps;
        if (!repo.charge) {
          corps = const Padding(padding: EdgeInsets.only(top: 12), child: SkeletonList(count: 5));
        } else {
          corps = ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: BigNumber(
                        value: jour == null ? '0' : Fmt.n(jour, decimals: 0),
                        label: 'Pas aujourd\'hui',
                        caption: jour == null
                            ? 'Rien pour l\'instant'
                            : jour >= repo.objectif
                                ? 'Objectif atteint'
                                : 'Encore ${Fmt.n(repo.objectif - jour, decimals: 0)} pour ${Fmt.n(repo.objectif, decimals: 0)}',
                        captionColor: jour != null && jour >= repo.objectif ? c.accent : null,
                        footer: repo.source(now) == null
                            ? null
                            : TagPill(repo.source(now) == SourcePas.saisie ? 'Saisi à la main' : 'Health Connect'),
                      ),
                    ),
                    TickGauge(
                      value: jour == null ? 0 : (jour / repo.objectif).clamp(0.0, 1.0),
                      color: c.heart,
                      width: 110,
                      child: Text('${jour == null ? 0 : (jour / repo.objectif * 100).round()} %', style: AppType.number(18)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                label: '7 derniers jours',
                labelTrailing: AccentLink(label: 'Objectif ${Fmt.n(repo.objectif, decimals: 0)}', onTap: () => choisirObjectifPas(context)),
                child: BarresJours(
                  valeurs: [for (final e in semaine) e.pas?.toDouble()],
                  libelles: [for (final e in semaine) Dates.initiale(e.jour)],
                  etiquettes: [for (final e in semaine) e.pas == null ? '' : '${Fmt.n(e.pas! / 1000)}k'],
                  couleur: c.heart,
                  objectif: repo.objectif.toDouble(),
                  surlignee: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: StatTile(label: 'Moyenne 7 j', value: moyenne == null ? '-' : Fmt.n(moyenne, decimals: 0), compact: true)),
                  const SizedBox(width: 12),
                  Expanded(child: StatTile(label: 'Meilleur jour', value: record == null ? '-' : Fmt.n(record, decimals: 0), compact: true)),
                ],
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconHalo(icon: Icons.sync_rounded, color: c.heart),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Health Connect', style: AppType.rowTitle()),
                              Text(
                                !connecte
                                    ? 'Lis tes pas automatiquement depuis ton téléphone ou ta montre.'
                                    : repo.derniereSynchro == null
                                        ? 'Pas encore synchronisé'
                                        : 'Synchronisé ${Fmt.ilYa(repo.derniereSynchro!)}',
                                style: AppType.rowSubtitle(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (repo.erreur != null) ...[
                      const SizedBox(height: 10),
                      Text(repo.erreur!, style: AppType.rowSubtitle(color: c.error)),
                    ],
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PillButton.secondary(
                        label: connecte ? 'Synchroniser' : 'Connecter',
                        icon: connecte ? Icons.sync_rounded : Icons.link_rounded,
                        loading: repo.synchronisation,
                        onPressed: repo.synchronisation
                            ? null
                            : () => connecte ? repo.synchroniser().then((ok) {
                                  if (!ok && context.mounted && repo.erreur != null) Toasts.error(context, repo.erreur!);
                                }) : _connecter(context, repo),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TileGroup(
                margin: EdgeInsets.zero,
                label: '14 derniers jours',
                children: [
                  for (final e in quinze)
                    ListTileX(
                      dense: true,
                      leading: IconHalo(icon: Icons.directions_walk_rounded, color: c.heart, size: 34, glow: false, off: e.pas == null),
                      title: Fmt.relatif(e.jour),
                      subtitle: switch (repo.source(e.jour)) {
                        SourcePas.saisie => 'Saisi à la main',
                        SourcePas.sante => 'Health Connect',
                        null => 'Toucher pour saisir',
                      },
                      value: e.pas == null ? '-' : Fmt.n(e.pas, decimals: 0),
                      valueColor: e.pas != null && e.pas! >= repo.objectif ? c.accent : null,
                      onTap: () => saisirPas(context, jour: e.jour),
                      onLongPress: repo.source(e.jour) == SourcePas.saisie ? () => _effacer(context, repo, e.jour) : null,
                    ),
                ],
              ),
            ],
          );
        }

        return SousPage(
          title: 'Pas',
          haloColor: c.heart,
          actions: [
            IconButton(tooltip: 'Objectif', onPressed: () => choisirObjectifPas(context), icon: const Icon(Icons.flag_rounded)),
          ],
          bottomBar: PillButton(
            label: 'Saisir mes pas',
            icon: Icons.edit_rounded,
            size: PillSize.large,
            expand: true,
            onPressed: () => saisirPas(context),
          ),
          body: corps,
        );
      },
    );
  }
}
