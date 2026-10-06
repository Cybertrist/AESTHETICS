import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/logic/text_search.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/import_flow.dart';
import '../data/import_journal.dart';
import '../logic/logic.dart';
import '../widgets/import_widgets.dart';

/// Historique des séances (module Séance, voir SeancePaths.historique).
const cheminHistorique = '/seance/historique';

/// `/import/resume` : ce qui a été importé.
class ResumePage extends StatelessWidget {
  const ResumePage({super.key});

  void _terminer(BuildContext context) {
    final flow = ImportFlow.instance;
    final retour = flow.retour;
    if (retour != null && retour.isNotEmpty) {
      context.go(retour);
    } else if (context.read<ProfileRepo>().hasProfile) {
      context.go(cheminHistorique);
    } else {
      context.go('/bienvenue');
    }
  }

  Future<void> _annuler(BuildContext context, ImportResult r) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Annuler cet import ?',
      message: 'Les ${Fmt.pluriel(r.seances, 'séance importée', 'séances importées')} seront supprimées'
          '${r.exercicesCrees > 0 ? ', ainsi que les exercices perso créés pour elles' : ''}.'
          '${r.remplacees > 0 ? ' Les séances remplacées ne reviendront pas.' : ''}',
      confirmLabel: 'Annuler l\'import',
      cancelLabel: 'Garder',
      destructive: true,
      icon: Icons.undo_rounded,
    );
    if (!ok || !context.mounted) return;
    final data = context.read<AppData>();
    final journal = await ImportJournal.lire(data.store);
    final e = journal.where((x) => x.id == r.journalId).firstOrNull;
    if (e == null) {
      if (context.mounted) Toasts.error(context, 'Cet import a déjà été annulé.');
      return;
    }
    final res = await ImportFlow.annulerImport(data, e);
    ImportFlow.instance.resultat = null;
    if (!context.mounted) return;
    Toasts.success(context, Fmt.pluriel(res.seances, 'séance supprimée', 'séances supprimées'));
    context.go('/import');
  }

  @override
  Widget build(BuildContext context) {
    final flow = ImportFlow.instance;
    final r = flow.resultat;
    if (r == null) {
      return PageImport(
        title: 'Résumé',
        body: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Aucun import récent',
          message: 'Les imports passés restent consultables dans le journal.',
          actionLabel: 'Voir les imports',
          onAction: () => context.go('/import/journal'),
        ),
      );
    }
    final vol = volumeLisible(r.volumeKg);
    final top = [...r.records]..sort((a, b) => b.unRmEstime.compareTo(a.unRmEstime));
    final avecRetour = flow.retour != null && flow.retour!.isNotEmpty;
    final sansProfil = !context.watch<ProfileRepo>().hasProfile;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _terminer(context);
      },
      child: PageImport(
        title: 'Import terminé',
        subtitle: flow.nomFichier,
        closeIcon: true,
        onBack: () => _terminer(context),
        bottomBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PillButton(
              label: avecRetour || sansProfil ? 'Continuer' : 'Voir mon historique',
              trailingIcon: Icons.arrow_forward_rounded,
              expand: true,
              size: PillSize.large,
              onPressed: () => _terminer(context),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PillButton.ghost(
                    label: 'Autre fichier',
                    size: PillSize.small,
                    onPressed: () {
                      flow.demarrer(flow.source, retour: flow.retour);
                      context.pushReplacement('/import/fichier');
                    },
                  ),
                ),
                Expanded(
                  child: PillButton.ghost(
                    label: 'Annuler l\'import',
                    size: PillSize.small,
                    onPressed: () => _annuler(context, r),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const SizedBox(height: 8),
            Center(child: IconHalo(icon: Icons.check_rounded, size: 64)),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: BigNumber(
                label: 'Séances importées',
                value: Fmt.n(r.seances, decimals: 0),
                caption: periode(r.debut, r.fin),
              ),
            ),
            const SizedBox(height: 16),
            DeuxVolets(
              gauche: [
                padded(GrilleStats(items: [
                  (label: 'Séries', valeur: Fmt.n(r.series, decimals: 0), unite: null, icon: Icons.format_list_numbered_rounded),
                  (label: 'Exercices', valeur: Fmt.n(r.exercicesUtilises, decimals: 0), unite: null, icon: Icons.fitness_center_rounded),
                  (label: 'Volume', valeur: vol.valeur, unite: vol.unite, icon: Icons.stacked_bar_chart_rounded),
                  (label: 'Perso créés', valeur: Fmt.n(r.exercicesCrees, decimals: 0), unite: null, icon: Icons.add_circle_outline_rounded),
                  if (r.echauffements > 0)
                    (label: 'Échauffements', valeur: Fmt.n(r.echauffements, decimals: 0), unite: null, icon: Icons.local_fire_department_rounded),
                  if (r.doublons > 0)
                    (label: 'Doublons ignorés', valeur: Fmt.n(r.doublons, decimals: 0), unite: null, icon: Icons.content_copy_rounded),
                  if (r.remplacees > 0)
                    (label: 'Séances remplacées', valeur: Fmt.n(r.remplacees, decimals: 0), unite: null, icon: Icons.find_replace_rounded),
                ])),
              ],
              droite: [
                const SizedBox(height: 12),
                padded(AppCard(
                  label: 'Records recréés',
                  labelTrailing: top.isEmpty ? null : AccentLink(label: 'Tout voir', onTap: () => context.push('/import/resume/records')),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: top.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('Aucune série avec charge ni répétitions.', style: AppType.rowSubtitle()),
                        )
                      : Column(children: [for (final x in top.take(5)) LigneRecord(record: x)]),
                )),
                const SizedBox(height: 12),
                padded(Text(
                  'Tes records, ta progression et la récupération musculaire tiennent compte de l\'historique importé.',
                  style: AppType.rowSubtitle(),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne de record : charge max et 1RM estimé.
class LigneRecord extends StatelessWidget {
  const LigneRecord({super.key, required this.record});
  final RecordExercice record;

  @override
  Widget build(BuildContext context) {
    final x = record;
    final detail = <String>[
      if (x.chargeMax > 0) '${Fmt.n(x.chargeMax)} kg × ${x.repsALaChargeMax}',
      if (x.chargeMax <= 0 && x.repsMax > 0) '${x.repsMax} reps',
      Fmt.pluriel(x.seances, 'séance'),
    ].join(' · ');
    return ListTileX(
      padding: ListTileX.cardPadding,
      leading: IconHalo(icon: Icons.emoji_events_rounded, size: 36),
      title: x.nom,
      subtitle: detail,
      value: x.unRmEstime > 0 ? '${Fmt.n(x.unRmEstime, decimals: 0)} kg' : null,
    );
  }
}

/// `/import/resume/records` : tous les records recréés par l'import.
class RecordsImportPage extends StatefulWidget {
  const RecordsImportPage({super.key});

  @override
  State<RecordsImportPage> createState() => _RecordsImportPageState();
}

class _RecordsImportPageState extends State<RecordsImportPage> {
  final _ctrl = TextEditingController();
  String _q = '';
  bool _parRm = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = ImportFlow.instance.resultat;
    if (r == null) {
      return PageImport(
        title: 'Records',
        body: EmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'Aucun import récent',
          message: 'Les records apparaissent ici juste après un import.',
          actionLabel: 'Retour à l\'import',
          onAction: () => context.go('/import'),
        ),
      );
    }
    final list = [
      for (final x in r.records)
        if (_q.isEmpty || TextSearch.score(_q, x.nom) > 0) x,
    ]..sort((a, b) => _parRm ? b.unRmEstime.compareTo(a.unRmEstime) : b.seances.compareTo(a.seances));
    return PageImport(
      title: 'Records recréés',
      subtitle: Fmt.pluriel(r.records.length, 'exercice'),
      body: Column(
        children: [
          padded(SearchField(controller: _ctrl, hint: 'Exercice', onChanged: (v) => setState(() => _q = v.trim()))),
          const SizedBox(height: 10),
          padded(SegmentedChips<bool>(
            segments: const [(true, '1RM estimé'), (false, 'Plus pratiqués')],
            value: _parRm,
            onChanged: (v) => setState(() => _parRm = v),
          )),
          const SizedBox(height: 6),
          Expanded(
            child: list.isEmpty
                ? EmptyState(icon: Icons.search_off_rounded, title: 'Aucun exercice', message: 'Rien pour « $_q ».', compact: true)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 4, AppTokens.gutter, 32),
                    itemCount: list.length,
                    itemBuilder: (context, i) => LigneRecord(record: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
