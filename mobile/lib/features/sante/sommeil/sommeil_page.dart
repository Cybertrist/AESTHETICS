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

String heuresCourtes(double h) => h == h.roundToDouble() ? '${h.round()} h' : '${Fmt.n(h)} h';

/// Couleurs des phases de sommeil (nuances du violet du domaine).
abstract final class PhasesCouleurs {
  static const profond = Color(0xFF6C5CE7);
  static const leger = Color(0xFF9D8CFF);
  static const paradoxal = Color(0xFF3CE0FF);
  static const eveil = Color(0xFFFFC857);
}

/// Sommeil : dernière nuit, courbes, régularité, historique.
class SommeilPage extends StatefulWidget {
  const SommeilPage({super.key});

  @override
  State<SommeilPage> createState() => _SommeilPageState();
}

class _SommeilPageState extends State<SommeilPage> {
  Periode _periode = Periode.semaine;
  int? _selection;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final journal = ActiviteJournal.of(context.read<Store>());
    final nuits = repo.sleep;
    return SubPageScaffold(
      title: 'Sommeil',
      haloColor: c.sleep,
      actions: [
        RoundIconButton(icon: Icons.history_rounded, filled: false, tooltip: 'Historique', onPressed: () => context.push('/sante/sommeil/historique')),
        const SizedBox(width: 6),
        RoundIconButton(icon: Icons.add_rounded, tooltip: 'Noter une nuit', onPressed: () => context.push('/sante/sommeil/ajouter')),
      ],
      body: nuits.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.bedtime_rounded,
                iconColor: c.sleep,
                title: 'Aucune nuit pour l\'instant',
                message: 'Notez vos heures de coucher et de lever, ou laissez Health Connect les apporter.',
                actionLabel: 'Noter ma nuit',
                onAction: () => context.push('/sante/sommeil/ajouter'),
                secondaryLabel: 'Relier Health Connect',
                onSecondary: () => context.push('/sante/connexion'),
              ),
            )
          : ListenableBuilder(
              listenable: journal,
              builder: (context, _) => _contenu(context, nuits, journal),
            ),
    );
  }

  Widget _contenu(BuildContext context, List<SleepEntry> nuits, ActiviteJournal journal) {
    final c = context.colors;
    final repo = context.read<HealthRepo>();
    final last = nuits.first;
    final debut = _periode.debut();
    final today = Dates.jour(DateTime.now());
    final dansPeriode = nuits.where((n) => !n.jour.isBefore(debut)).toList();
    final objectifH = journal.objectifSommeilMin / 60;

    Widget graphe;
    if (_periode.jours <= 30) {
      final jours = [for (var i = _periode.jours - 1; i >= 0; i--) today.subtract(Duration(days: i))];
      graphe = SanteBarres(
        jours: jours,
        valeurs: [for (final d in jours) repo.sleepFor(d) == null ? null : repo.sleepFor(d)!.duree.inMinutes / 60],
        color: c.sleep,
        objectif: objectifH,
        format: heuresCourtes,
        selection: _selection,
        onSelect: (i) {
          setState(() => _selection = _selection == i ? null : i);
          final n = repo.sleepFor(jours[i]);
          if (n != null) context.push('/sante/sommeil/nuit/${n.id}');
        },
      );
    } else {
      final pts = [for (final n in dansPeriode.reversed) (date: n.jour, v: n.duree.inMinutes / 60)];
      graphe = SanteCourbe(
        points: pts,
        tendance: SanteCalc.moyenneMobile(pts),
        debut: debut,
        fin: today,
        color: c.sleep,
        format: heuresCourtes,
        objectif: objectifH,
        pointsVisibles: false,
      );
    }

    final moy = dansPeriode.isEmpty ? null : dansPeriode.fold<int>(0, (a, n) => a + n.duree.inMinutes) ~/ dansPeriode.length;
    final notes = dansPeriode.where((n) => n.qualite != null).toList();
    final qualiteMoy = notes.isEmpty ? null : notes.fold<int>(0, (a, n) => a + n.qualite!) / notes.length;
    final ecart = SanteCalc.ecartCoucher(dansPeriode);
    final atteint = dansPeriode.where((n) => n.duree.inMinutes >= journal.objectifSommeilMin).length;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        SanteColonnes(children: [
          Padding(padding: santePad, child: _DerniereNuit(nuit: last)),
          Padding(
            padding: santePad,
            child: AppCard(
              label: 'Sur la période',
              labelTrailing: LabelCount(Fmt.pluriel(dansPeriode.length, 'nuit')),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: MiniChiffre(label: 'Moyenne', value: moy == null ? '-' : Fmt.sommeil(Duration(minutes: moy)))),
                      Expanded(child: MiniChiffre(label: 'Objectif tenu', value: dansPeriode.isEmpty ? '-' : '$atteint', unit: '/ ${dansPeriode.length}')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: MiniChiffre(label: 'Coucher moyen', value: SanteCalc.heureMoyenne([for (final n in dansPeriode) n.coucher]) ?? '-')),
                      Expanded(child: MiniChiffre(label: 'Lever moyen', value: SanteCalc.heureMoyenne([for (final n in dansPeriode) n.lever], coucher: false) ?? '-')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MiniChiffre(
                          label: 'Régularité',
                          value: ecart == null ? '-' : '± $ecart',
                          unit: ecart == null ? null : 'min',
                          caption: ecart == null ? 'Il faut 3 nuits' : (ecart <= 30 ? 'Très régulier' : (ecart <= 60 ? 'Assez régulier' : 'Irrégulier')),
                        ),
                      ),
                      Expanded(
                        child: MiniChiffre(
                          label: 'Qualité',
                          value: qualiteMoy == null ? '-' : Fmt.n(qualiteMoy),
                          unit: qualiteMoy == null ? null : '/ 5',
                          caption: qualiteMoy == null ? 'Aucune note' : SanteCalc.qualite(qualiteMoy.round()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        CarteCourbe(
          label: 'Durée des nuits',
          periode: _periode,
          onPeriode: (p) => setState(() {
            _periode = p;
            _selection = null;
          }),
          legende: Legende(items: [
            (c.sleep, 'Durée', false),
            if (_periode.jours > 30) (c.sleep.withValues(alpha: 0.6), 'Moyenne sur 7 jours', true),
            (c.accent, 'Objectif ${Fmt.sommeil(Duration(minutes: journal.objectifSommeilMin))}', true),
          ]),
          child: graphe,
        ),
        const SizedBox(height: 12),
        TileGroup(
          label: 'Réglages',
          children: [
            ListTileX(
              leading: IconHalo(icon: Icons.flag_rounded, color: c.sleep, size: 38),
              title: 'Objectif de sommeil',
              value: Fmt.sommeil(Duration(minutes: journal.objectifSommeilMin)),
              showChevron: true,
              onTap: () async {
                final v = await showChoiceDialog<int>(
                  context,
                  title: 'Objectif de sommeil',
                  message: 'Entre 7 et 9 heures conviennent à la plupart des adultes qui s\'entraînent.',
                  selected: journal.objectifSommeilMin,
                  options: [for (var m = 360; m <= 600; m += 30) (m, Fmt.sommeil(Duration(minutes: m)))],
                );
                if (v != null) await journal.reglerObjectifs(sommeilMin: v);
              },
            ),
            ListTileX(
              leading: IconHalo(icon: Icons.sync_rounded, color: c.heart, size: 38),
              title: 'Importer depuis Health Connect',
              subtitle: 'Nuits et phases enregistrées par votre montre',
              showChevron: true,
              onTap: () => context.push('/sante/connexion'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TileGroup(
          label: 'Dernières nuits',
          labelTrailing: AccentLink(label: 'Tout voir', onTap: () => context.push('/sante/sommeil/historique')),
          children: [for (final n in nuits.take(7)) LigneNuit(nuit: n, objectifMin: journal.objectifSommeilMin)],
        ),
      ],
    );
  }
}

class _DerniereNuit extends StatelessWidget {
  const _DerniereNuit({required this.nuit});
  final SleepEntry nuit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: () => context.push('/sante/sommeil/nuit/${nuit.id}'),
      label: 'Dernière nuit',
      labelTrailing: Text(Fmt.relatif(nuit.lever), style: AppType.rowSubtitle()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BigNumber(
            value: Fmt.sommeil(nuit.duree),
            size: 40,
            caption: '${Fmt.heure(nuit.coucher)} › ${Fmt.heure(nuit.lever)}',
            footer: nuit.qualite == null ? null : TagPill(SanteCalc.qualite(nuit.qualite), color: c.sleep, icon: Icons.star_rounded),
          ),
          if (nuit.aDesPhases) ...[
            const SizedBox(height: 16),
            BarrePhases(nuit: nuit),
          ],
        ],
      ),
    );
  }
}

/// Barre segmentée des phases et sa légende.
class BarrePhases extends StatelessWidget {
  const BarrePhases({super.key, required this.nuit});
  final SleepEntry nuit;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (nuit.profondMin ?? 0, PhasesCouleurs.profond, 'Profond'),
      (nuit.legerMin ?? 0, PhasesCouleurs.leger, 'Léger'),
      (nuit.paradoxalMin ?? 0, PhasesCouleurs.paradoxal, 'Paradoxal'),
      (nuit.eveilMin ?? 0, PhasesCouleurs.eveil, 'Éveil'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedBar(parts: [for (final p in parts) if (p.$1 > 0) (p.$1.toDouble(), p.$2)]),
        const SizedBox(height: 10),
        Legende(items: [for (final p in parts) if (p.$1 > 0) (p.$2, '${p.$3} ${Fmt.duree(Duration(minutes: p.$1))}', false)]),
      ],
    );
  }
}

/// Ligne d'une nuit dans une liste.
class LigneNuit extends StatelessWidget {
  const LigneNuit({super.key, required this.nuit, required this.objectifMin});
  final SleepEntry nuit;
  final int objectifMin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ok = nuit.duree.inMinutes >= objectifMin;
    return ListTileX(
      leading: IconHalo(
        icon: nuit.qualite == null ? Icons.bedtime_rounded : QualitePicker.icones[nuit.qualite! - 1],
        color: c.sleep,
        size: 38,
        glow: false,
      ),
      title: Fmt.jourCap(nuit.jour),
      subtitle: '${Fmt.heure(nuit.coucher)} › ${Fmt.heure(nuit.lever)}${nuit.source == 'health connect' ? ' · Health Connect' : ''}',
      value: Fmt.sommeil(nuit.duree),
      valueColor: ok ? c.text : c.text2,
      showChevron: true,
      onTap: () => context.push('/sante/sommeil/nuit/${nuit.id}'),
    );
  }
}

/// Toutes les nuits, rangées par mois.
class SommeilHistoriquePage extends StatelessWidget {
  const SommeilHistoriquePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nuits = context.watch<HealthRepo>().sleep;
    final journal = ActiviteJournal.of(context.read<Store>());
    final items = <Object>[];
    DateTime? mois;
    for (final n in nuits) {
      final m = Dates.debutMois(n.jour);
      if (m != mois) {
        mois = m;
        items.add(m);
      }
      items.add(n);
    }
    return SubPageScaffold(
      title: 'Historique du sommeil',
      subtitle: Fmt.pluriel(nuits.length, 'nuit'),
      haloColor: c.sleep,
      actions: [RoundIconButton(icon: Icons.add_rounded, tooltip: 'Noter une nuit', onPressed: () => context.push('/sante/sommeil/ajouter'))],
      body: nuits.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.bedtime_rounded,
                iconColor: c.sleep,
                title: 'Aucune nuit',
                message: 'Les nuits notées ou importées s\'afficheront ici.',
                actionLabel: 'Noter ma nuit',
                onAction: () => context.push('/sante/sommeil/ajouter'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final it = items[i];
                if (it is DateTime) {
                  final duMois = nuits.where((n) => Dates.debutMois(n.jour) == it).toList();
                  final moy = duMois.fold<int>(0, (a, n) => a + n.duree.inMinutes) ~/ duMois.length;
                  return SectionHeader(
                    title: Fmt.mois(it),
                    trailing: LabelCount('moyenne ${Fmt.sommeil(Duration(minutes: moy))}'),
                  );
                }
                return Padding(
                  padding: santePad,
                  child: Material(
                    color: c.surface,
                    borderRadius: AppTokens.radius14,
                    clipBehavior: Clip.antiAlias,
                    child: LigneNuit(nuit: it as SleepEntry, objectifMin: journal.objectifSommeilMin),
                  ),
                ).withGap();
              },
            ),
    );
  }
}

extension on Widget {
  Widget withGap() => Padding(padding: const EdgeInsets.only(bottom: 6), child: this);
}
