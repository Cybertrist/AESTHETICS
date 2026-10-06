import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/import_flow.dart';
import '../data/repo_extensions.dart';
import '../logic/logic.dart';
import '../widgets/import_widgets.dart';

/// `/import/options` : fusionner ou remplacer, unités, échauffements.
class OptionsPage extends StatelessWidget {
  const OptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = ImportFlow.instance;
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        final p = flow.preview;
        if (p == null) return const SansFichier(titre: 'Options');
        final data = context.read<AppData>();
        final sessions = context.watch<SessionRepo>();
        final c = context.colors;
        final r = p.rapport;
        final total = sessions.sessions.length;
        final importees = sessions.seancesImportees.length;
        final aSupprimer = switch (flow.mode) {
          ImportMode.fusionner => 0,
          ImportMode.remplacerImportees => importees,
          ImportMode.remplacerTout => total,
        };
        final analyse = flow.etat == EtatAnalyse.analyse;
        final series = r.series + (flow.garderEchauffements ? r.seriesEchauffement : 0);

        Future<void> lancer() async {
          if (r.aConfirmer.isNotEmpty) {
            context.push('/import/exercices');
            return;
          }
          if (aSupprimer > 0) {
            final ok = await showConfirmDialog(
              context,
              title: 'Supprimer ${Fmt.pluriel(aSupprimer, 'séance')} ?',
              message: flow.mode == ImportMode.remplacerTout
                  ? 'Tout ton historique actuel sera remplacé par le contenu du fichier. Pense à faire une sauvegarde avant.'
                  : 'Les séances de tes imports précédents seront remplacées par celles du fichier.',
              confirmLabel: 'Remplacer',
              destructive: true,
              icon: Icons.warning_amber_rounded,
            );
            if (!ok || !context.mounted) return;
          }
          context.push('/import/progression');
        }

        return PageImport(
          title: 'Options',
          subtitle: flow.nomFichier,
          bottomBar: PillButton(
            label: r.seances == 0 ? 'Aucune séance à importer' : 'Importer ${Fmt.pluriel(r.seances, 'séance')}',
            icon: Icons.download_done_rounded,
            expand: true,
            size: PillSize.large,
            loading: analyse,
            onPressed: r.seances == 0 || analyse ? null : lancer,
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const EtapesImport(courante: 3),
              const SectionHeader(title: 'Ton historique actuel'),
              padded(Text(
                total == 0
                    ? 'Tu n\'as encore aucune séance : tout le fichier sera ajouté.'
                    : 'Tu as ${Fmt.pluriel(total, 'séance')}${importees > 0 ? ', dont ${Fmt.n(importees, decimals: 0)} importées' : ''}.',
                style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 14),
              )),
              const SizedBox(height: 12),
              padded(Column(
                children: [
                  for (final m in ImportMode.values)
                    if (m != ImportMode.remplacerImportees || importees > 0)
                      CarteChoix(
                        titre: m.label,
                        description: m.description,
                        icon: switch (m) {
                          ImportMode.fusionner => Icons.merge_rounded,
                          ImportMode.remplacerImportees => Icons.find_replace_rounded,
                          ImportMode.remplacerTout => Icons.restart_alt_rounded,
                        },
                        selectionne: flow.mode == m,
                        onTap: () => flow.changerOptions(data, mode: m),
                      ),
                ],
              )),
              if (aSupprimer > 0)
                padded(Encart(
                  ton: TonEncart.attention,
                  titre: '${Fmt.pluriel(aSupprimer, 'séance')} ${aSupprimer > 1 ? 'seront supprimées' : 'sera supprimée'}',
                  texte: 'Tu pourras annuler cet import ensuite, mais les séances supprimées ne reviendront pas. Une sauvegarde avant est plus sûre.',
                  action: PillButton.link(label: 'Faire une sauvegarde', onPressed: () => context.push('/import/sauvegarde')),
                )),
              const SectionHeader(title: 'Charges'),
              padded(SegmentedControl<UniteCharge>(
                segments: const [(UniteCharge.kg, 'Kilos'), (UniteCharge.lb, 'Livres')],
                value: flow.unite,
                onChanged: (u) => flow.changerOptions(data, unite: u),
              )),
              const SizedBox(height: 8),
              padded(Text(
                'Utilisé seulement quand le fichier ne précise pas l\'unité. Tout est converti et enregistré en kilos.',
                style: AppType.rowSubtitle(),
              )),
              const SectionHeader(title: 'Séries'),
              TileGroup(
                children: [
                  SwitchListTile(
                    value: flow.garderEchauffements,
                    onChanged: (v) => flow.changerOptions(data, garderEchauffements: v),
                    title: Text('Garder les échauffements', style: AppType.rowTitle()),
                    subtitle: Text(
                      '${Fmt.pluriel(r.seriesEchauffement, 'série')} d\'échauffement. Elles ne comptent jamais dans le volume ni les records.',
                      style: AppType.rowSubtitle(),
                    ),
                  ),
                  SwitchListTile(
                    value: flow.ignorerSeriesVides,
                    onChanged: (v) => flow.changerOptions(data, ignorerSeriesVides: v),
                    title: Text('Ignorer les séries vides', style: AppType.rowTitle()),
                    subtitle: Text('Sans charge, répétitions, durée ni distance.', style: AppType.rowSubtitle()),
                  ),
                ],
              ),
              const SectionHeader(title: 'Récapitulatif'),
              padded(AppCard(
                child: Column(
                  children: [
                    _ligne('Séances', Fmt.n(r.seances, decimals: 0)),
                    _ligne('Séries', Fmt.n(series, decimals: 0)),
                    _ligne('Exercices', Fmt.n(r.exercicesDistincts, decimals: 0)),
                    _ligne('Exercices perso créés', Fmt.n(r.nouveaux.length, decimals: 0)),
                    if (r.seancesDoublons > 0) _ligne('Doublons ignorés', Fmt.n(r.seancesDoublons, decimals: 0)),
                    _ligne('Période', periode(r.debut, r.fin)),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _ligne(String label, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: AppType.rowSubtitle().copyWith(fontSize: 14))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: Text(valeur, textAlign: TextAlign.right, style: AppType.rowValue().copyWith(fontSize: 14))),
          ],
        ),
      );
}
