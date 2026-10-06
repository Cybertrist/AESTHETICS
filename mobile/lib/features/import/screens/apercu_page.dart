import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/format.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/import_flow.dart';
import '../logic/logic.dart';
import '../widgets/import_widgets.dart';

/// `/import/apercu` : ce que contient le fichier, avant de continuer.
class ApercuPage extends StatelessWidget {
  const ApercuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = ImportFlow.instance;
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        final p = flow.preview;
        if (p == null) return const SansFichier(titre: 'Aperçu');
        final r = p.rapport;
        final c = context.colors;
        final vol = volumeLisible(r.volumeTotalKg);
        final erreurs = r.messages.where((m) => m.gravite == Gravite.erreur).length;
        final avert = r.messages.length - erreurs;
        final vide = r.seances == 0;

        final gauche = <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: BigNumber(
              label: 'Séances à importer',
              value: Fmt.n(r.seances, decimals: 0),
              caption: periode(r.debut, r.fin),
              footer: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TagPill(r.format.libelle, icon: Icons.verified_rounded, color: c.text),
                  TagPill(flow.nomFichier ?? 'Fichier', icon: Icons.description_outlined, color: c.text2),
                ],
              ),
            ),
          ),
          if (r.seancesDoublons > 0)
            padded(Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Encart(
                ton: TonEncart.info,
                titre: Fmt.pluriel(r.seancesDoublons, 'séance déjà présente', 'séances déjà présentes'),
                texte: 'Elles commencent à la même minute qu\'une séance de ton historique et ne seront pas importées une seconde fois.',
              ),
            )),
          padded(GrilleStats(items: [
            (label: 'Séries', valeur: Fmt.n(r.series, decimals: 0), unite: null, icon: Icons.format_list_numbered_rounded),
            (label: 'Exercices', valeur: Fmt.n(r.exercicesDistincts, decimals: 0), unite: null, icon: Icons.fitness_center_rounded),
            (label: 'Volume soulevé', valeur: vol.valeur, unite: vol.unite, icon: Icons.stacked_bar_chart_rounded),
            (label: 'Durée totale', valeur: r.dureeTotale.inHours.toString(), unite: 'h', icon: Icons.timer_outlined),
            (label: 'Échauffements', valeur: Fmt.n(r.seriesEchauffement, decimals: 0), unite: null, icon: Icons.local_fire_department_rounded),
            (label: 'Lignes lues', valeur: Fmt.n(r.lignesLues, decimals: 0), unite: null, icon: Icons.table_rows_rounded),
          ])),
          const SizedBox(height: 12),
          if (r.seancesParMois.isNotEmpty)
            padded(AppCard(
              label: 'Séances par mois',
              labelTrailing: LabelCount(Fmt.pluriel(r.seancesParMois.length, 'mois', 'mois')),
              child: BarresMois(parMois: r.seancesParMois),
            )),
        ];

        final droite = <Widget>[
          const SizedBox(height: 12),
          padded(_CarteExercices(rapport: r)),
          const SizedBox(height: 12),
          padded(_CarteSeances(seances: p.aImporter)),
          if (r.messages.isNotEmpty) ...[
            const SizedBox(height: 12),
            padded(AppCard(
              onTap: () => context.push('/import/apercu/messages'),
              padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
              child: ListTileX(
                padding: ListTileX.cardPadding,
                leading: IconHalo(icon: erreurs > 0 ? Icons.error_outline_rounded : Icons.info_outline_rounded),
                title: 'Remarques de lecture',
                subtitle: [
                  if (erreurs > 0) Fmt.pluriel(erreurs, 'erreur'),
                  if (avert > 0) Fmt.pluriel(avert, 'remarque'),
                ].join(' · '),
                showChevron: true,
              ),
            )),
          ],
          const SizedBox(height: 12),
          padded(Wrap(
            spacing: 4,
            children: [
              AccentLink(
                label: 'Associer les colonnes à la main',
                icon: Icons.view_column_rounded,
                onTap: () => context.push('/import/colonnes?depuis=apercu'),
              ),
              AccentLink(
                label: 'Changer de fichier',
                icon: Icons.swap_horiz_rounded,
                onTap: () => context.canPop() ? context.pop() : context.go('/import/fichier'),
              ),
            ],
          )),
        ];

        return PageImport(
          title: 'Aperçu',
          subtitle: flow.nomFichier,
          bottomBar: vide
              ? null
              : PillButton(
                  label: r.aConfirmer.isNotEmpty ? 'Vérifier ${Fmt.pluriel(r.aConfirmer.length, 'exercice')}' : 'Continuer',
                  trailingIcon: Icons.arrow_forward_rounded,
                  expand: true,
                  size: PillSize.large,
                  onPressed: () => context.push(r.aConfirmer.isNotEmpty || r.nouveaux.isNotEmpty ? '/import/exercices' : '/import/options'),
                ),
          body: flow.etat == EtatAnalyse.analyse
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 6))
              : vide
                  ? _Vide(messages: r.messages)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        const EtapesImport(courante: 1),
                        DeuxVolets(gauche: gauche, droite: droite),
                      ],
                    ),
        );
      },
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.messages});
  final List<ImportMessage> messages;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 32),
      children: [
        EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Aucune séance à importer',
          message: messages.isNotEmpty
              ? messages.first.toString()
              : 'Toutes les séances du fichier sont déjà dans ton historique.',
          actionLabel: 'Associer les colonnes',
          onAction: () => context.push('/import/colonnes?depuis=apercu'),
          secondaryLabel: 'Choisir un autre fichier',
          onSecondary: () => context.canPop() ? context.pop() : context.go('/import/fichier'),
        ),
        if (messages.length > 1)
          padded(AccentLink(label: 'Voir les ${messages.length} remarques', onTap: () => context.push('/import/apercu/messages'))),
      ],
    );
  }
}

class _CarteExercices extends StatelessWidget {
  const _CarteExercices({required this.rapport});
  final ImportReport rapport;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = rapport;
    final total = r.reconnus.length + r.aConfirmer.length + r.nouveaux.length;
    return AppCard(
      label: 'Exercices du fichier',
      labelTrailing: LabelCount(Fmt.pluriel(total, 'nom')),
      onTap: () => context.push('/import/exercices'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedBar(parts: [
            (r.reconnus.length.toDouble(), c.success),
            (r.aConfirmer.length.toDouble(), c.warning),
            (r.nouveaux.length.toDouble(), c.text2),
          ]),
          const SizedBox(height: 14),
          _ligne(context, c.success, 'Reconnus', r.reconnus.length),
          _ligne(context, c.warning, 'À confirmer', r.aConfirmer.length),
          _ligne(context, c.text2, 'Exercices perso à créer', r.nouveaux.length),
          const SizedBox(height: 6),
          PillButton.link(label: r.aConfirmer.isEmpty ? 'Revoir les exercices' : 'Confirmer les exercices', onPressed: () => context.push('/import/exercices')),
        ],
      ),
    );
  }

  Widget _ligne(BuildContext context, Color couleur, String label, int n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppType.rowSubtitle(color: context.colors.text2).copyWith(fontSize: 14))),
            Text('$n', style: AppType.rowValue()),
          ],
        ),
      );
}

class _CarteSeances extends StatelessWidget {
  const _CarteSeances({required this.seances});
  final List<ImportedSession> seances;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final recentes = seances.reversed.take(3).toList();
    return AppCard(
      label: 'Dernières séances',
      labelTrailing: AccentLink(label: 'Tout voir', onTap: () => context.push('/import/apercu/seances')),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        children: [
          for (final s in recentes)
            ListTileX(
              padding: ListTileX.cardPadding,
              leading: IconHalo(icon: Icons.fitness_center_rounded),
              title: s.titre,
              subtitle: '${Fmt.jourCap(s.debut)} · ${Fmt.pluriel(s.exercices.length, 'exercice')}',
              value: '${s.nombreSeries}',
              subtitleColor: c.text3,
              onTap: () => context.push('/import/apercu/seances/${ImportFlow.instance.preview?.seances.indexOf(s) ?? 0}'),
            ),
        ],
      ),
    );
  }
}
