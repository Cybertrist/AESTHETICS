import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../common/sante_calculs.dart';
import '../common/sante_widgets.dart';
import '../connexion/connexion_page.dart';
import '../services/activite_journal.dart';

/// Activité : pas, calories brûlées, fréquence cardiaque, lus dans Health Connect.
class ActivitePage extends StatefulWidget {
  const ActivitePage({super.key});

  @override
  State<ActivitePage> createState() => _ActivitePageState();
}

class _ActivitePageState extends State<ActivitePage> {
  DateTime _jour = Dates.jour(DateTime.now());
  Periode _pPas = Periode.semaine;
  Periode _pCal = Periode.semaine;
  Periode _pCoeur = Periode.mois;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final journal = ActiviteJournal.of(context.read<Store>());
    return SubPageScaffold(
      title: 'Activité',
      haloColor: c.heart,
      actions: [
        ListenableBuilder(
          listenable: journal,
          builder: (context, _) => RoundIconButton(
            icon: Icons.sync_rounded,
            filled: false,
            tooltip: 'Synchroniser',
            onPressed: journal.synchroEnCours ? null : () => synchroniserSante(context),
          ),
        ),
      ],
      body: ListenableBuilder(
        listenable: journal,
        builder: (context, _) {
          if (!journal.charge) return const Padding(padding: EdgeInsets.only(top: 8), child: SkeletonList(count: 5));
          if (journal.vide) {
            final relie = context.watch<SettingsRepo>().settings.santeConnectee;
            return Center(
              child: EmptyState(
                icon: Icons.directions_walk_rounded,
                iconColor: c.heart,
                title: relie ? 'Pas encore de données' : 'Reliez Health Connect',
                message: relie
                    ? 'Aucune activité lue pour l\'instant. Vérifiez que votre montre ou votre téléphone enregistre vos pas dans Health Connect.'
                    : 'Les pas, les calories brûlées et la fréquence cardiaque viennent de votre téléphone ou de votre montre, par Health Connect.',
                actionLabel: relie ? 'Synchroniser' : 'Relier Health Connect',
                onAction: relie ? () => synchroniserSante(context) : () => context.push('/sante/connexion'),
              ),
            );
          }
          return RefreshIndicator(
            color: c.accent,
            backgroundColor: c.surface3,
            onRefresh: () => synchroniserSante(context),
            child: _contenu(context, journal),
          );
        },
      ),
    );
  }

  Widget _contenu(BuildContext context, ActiviteJournal journal) {
    final c = context.colors;
    final today = Dates.jour(DateTime.now());
    final a = journal.jour(_jour);
    final plusVieux = journal.jours.isEmpty ? today : journal.jours.last.jour;
    List<DateTime> jours(Periode p) => [for (var i = p.jours - 1; i >= 0; i--) today.subtract(Duration(days: i))];
    final jPas = jours(_pPas);
    final jCal = jours(_pCal);
    final coeur = [
      for (final j in journal.jours.reversed)
        if (j.fcRepos != null && !j.jour.isBefore(_pCoeur.debut())) (date: j.jour, v: j.fcRepos!),
    ];
    final moyPas = journal.moyenne((x) => x.pas?.toDouble());
    final atteints = journal.jours.take(7).where((x) => (x.pas ?? 0) >= journal.objectifPas).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        Padding(
          padding: santePad,
          child: StepSelector(
            label: Fmt.relatif(_jour) == 'Aujourd\'hui' ? 'Aujourd\'hui' : Fmt.jourCap(_jour),
            onPrevious: _jour.isAfter(plusVieux) ? () => setState(() => _jour = _jour.subtract(const Duration(days: 1))) : null,
            onNext: _jour.isBefore(today) ? () => setState(() => _jour = DateTime(_jour.year, _jour.month, _jour.day + 1)) : null,
            onTapLabel: () async {
              final d = await choisirDate(context, _jour, first: plusVieux, last: today);
              if (d != null) setState(() => _jour = Dates.jour(d));
            },
          ),
        ),
        const SizedBox(height: 12),
        SanteColonnes(children: [
          Padding(
            padding: santePad,
            child: AppCard(
              child: Column(
                children: [
                  ProgressRing(
                    value: (a?.pas ?? 0) / journal.objectifPas,
                    size: 180,
                    stroke: 14,
                    color: c.heart,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_walk_rounded, color: c.heart),
                        const SizedBox(height: 4),
                        Text(a?.pas == null ? '-' : Fmt.n(a!.pas, decimals: 0), style: AppType.number(32)),
                        Text('sur ${Fmt.n(journal.objectifPas, decimals: 0)} pas', style: AppType.rowSubtitle()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    a?.pas == null
                        ? 'Aucun pas enregistré ce jour-là'
                        : (a!.pas! >= journal.objectifPas ? 'Objectif atteint' : 'Encore ${Fmt.n(journal.objectifPas - a.pas!, decimals: 0)} pas'),
                    style: AppType.rowSubtitle(color: (a?.pas ?? 0) >= journal.objectifPas ? c.heart : null).copyWith(fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: santePad,
            child: AppCard(
              label: 'Ce jour-là',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: MiniChiffre(label: 'Calories actives', value: Fmt.n(a?.kcalActives, decimals: 0), unit: 'kcal', color: c.warning)),
                      Expanded(child: MiniChiffre(label: 'Dépense totale', value: Fmt.n(a?.kcalTotales, decimals: 0), unit: 'kcal')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: MiniChiffre(label: 'Cœur au repos', value: Fmt.n(a?.fcRepos, decimals: 0), unit: 'bpm', color: c.heart)),
                      Expanded(child: MiniChiffre(label: 'Cœur moyen', value: Fmt.n(a?.fcMoyenne, decimals: 0), unit: 'bpm')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: MiniChiffre(label: 'Moyenne 7 j', value: moyPas == null ? '-' : Fmt.n(moyPas, decimals: 0), unit: 'pas')),
                      Expanded(child: MiniChiffre(label: 'Objectif tenu', value: '$atteints', unit: '/ 7 j')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        CarteCourbe(
          label: 'Pas',
          periode: _pPas,
          periodes: const [Periode.semaine, Periode.mois],
          onPeriode: (p) => setState(() => _pPas = p),
          child: SanteBarres(
            jours: jPas,
            valeurs: [for (final d in jPas) journal.jour(d)?.pas?.toDouble()],
            color: c.heart,
            objectif: journal.objectifPas.toDouble(),
            format: (v) => v >= 1000 ? '${Fmt.n(v / 1000)} k' : Fmt.n(v, decimals: 0),
            selection: jPas.contains(_jour) ? jPas.indexOf(_jour) : null,
            onSelect: (i) => setState(() => _jour = jPas[i]),
          ),
        ),
        const SizedBox(height: 12),
        CarteCourbe(
          label: 'Calories actives',
          periode: _pCal,
          periodes: const [Periode.semaine, Periode.mois],
          onPeriode: (p) => setState(() => _pCal = p),
          child: SanteBarres(
            jours: jCal,
            valeurs: [for (final d in jCal) journal.jour(d)?.kcalActives],
            color: c.warning,
            format: (v) => Fmt.n(v, decimals: 0),
            selection: jCal.contains(_jour) ? jCal.indexOf(_jour) : null,
            onSelect: (i) => setState(() => _jour = jCal[i]),
          ),
        ),
        const SizedBox(height: 12),
        CarteCourbe(
          label: 'Fréquence cardiaque au repos',
          periode: _pCoeur,
          periodes: const [Periode.mois, Periode.trimestre],
          onPeriode: (p) => setState(() => _pCoeur = p),
          legende: Text('Une fréquence au repos qui baisse sur plusieurs semaines est un bon signe de forme. Une hausse soudaine peut signaler de la fatigue.', style: AppType.rowSubtitle()),
          child: SanteCourbe(
            points: coeur,
            debut: _pCoeur.debut(),
            fin: today,
            color: c.heart,
            height: 160,
            format: (v) => Fmt.n(v, decimals: 0),
            pointsVisibles: false,
          ),
        ),
        const SizedBox(height: 12),
        TileGroup(
          label: 'Réglages',
          children: [
            ListTileX(
              leading: IconHalo(icon: Icons.flag_rounded, color: c.heart, size: 38),
              title: 'Objectif de pas',
              value: Fmt.n(journal.objectifPas, decimals: 0),
              showChevron: true,
              onTap: () async {
                final v = await showChoiceDialog<int>(
                  context,
                  title: 'Objectif de pas',
                  selected: journal.objectifPas,
                  options: [for (var p = 4000; p <= 20000; p += 1000) (p, '${Fmt.n(p, decimals: 0)} pas')],
                );
                if (v != null) await journal.reglerObjectifs(pas: v);
              },
            ),
            ListTileX(
              leading: IconHalo.domain(AppDomain.coeur, icon: Icons.health_and_safety_rounded, size: 38),
              title: 'Health Connect',
              subtitle: journal.derniereErreur ??
                  (journal.derniereSynchro == null ? 'Jamais synchronisé' : 'Synchronisé ${Fmt.ilYa(journal.derniereSynchro!)}'),
              subtitleColor: journal.derniereErreur == null ? null : c.error,
              showChevron: true,
              onTap: () => context.push('/sante/connexion'),
            ),
          ],
        ),
      ],
    );
  }
}
