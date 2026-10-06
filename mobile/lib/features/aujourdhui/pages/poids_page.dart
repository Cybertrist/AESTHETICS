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

enum _Periode { mois, trimestre, an }

/// Poids : dernière pesée, courbe, objectif, historique.
class PoidsPage extends StatefulWidget {
  const PoidsPage({super.key});

  @override
  State<PoidsPage> createState() => _PoidsPageState();
}

class _PoidsPageState extends State<PoidsPage> {
  _Periode _periode = _Periode.trimestre;

  Future<void> _supprimer(BodyMeasurement m) async {
    final u = context.read<ProfileRepo>().unite;
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer cette pesée ?',
      message: '${Fmt.jourCap(m.date)}, ${Fmt.poids(m.poidsKg, u)}',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final h = context.read<HealthRepo>();
    if (m.tours.isNotEmpty || m.masseGrassePct != null) {
      // La mesure garde ses tours : on retire seulement le poids.
      await h.saveMeasurement(BodyMeasurement(
        id: m.id,
        date: m.date,
        masseGrassePct: m.masseGrassePct,
        masseMusculaireKg: m.masseMusculaireKg,
        tours: m.tours,
        source: m.source,
      ));
    } else {
      await h.deleteMeasurement(m.id);
    }
    if (mounted) Toasts.show(context, 'Pesée supprimée.', actionLabel: 'Annuler', onAction: () => h.saveMeasurement(m));
  }

  Future<void> _objectif() async {
    final p = context.read<ProfileRepo>();
    final u = p.unite;
    final cible = p.profile?.poidsCibleKg;
    final v = await showNumberInputDialog(
      context,
      title: 'Poids visé',
      initial: cible == null ? null : double.parse(Fmt.poidsAffiche(cible, u).toStringAsFixed(1)),
      unit: u.label,
    );
    if (v == null || !mounted) return;
    final kg = Fmt.poidsStocke(v, u);
    if (kg < 25 || kg > 350) {
      Toasts.error(context, 'Ce poids semble incorrect.');
      return;
    }
    await p.update((x) => x.copyWith(poidsCibleKg: kg));
  }

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HealthRepo>();
    final profile = context.watch<ProfileRepo>().profile;
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final pesees = h.measurements.where((m) => m.poidsKg != null).toList();
    final now = DateTime.now();

    if (pesees.isEmpty) {
      return SubPageScaffold(
        title: 'Poids',
        haloColor: c.weight,
        body: Center(
          child: EmptyState(
            icon: Icons.monitor_weight_rounded,
            iconColor: c.weight,
            title: 'Aucune pesée',
            message: 'Pèse-toi le matin, à jeun, pour une courbe fiable. Une pesée tous les deux ou trois jours suffit.',
            actionLabel: 'Ajouter une pesée',
            onAction: () => saisirPoids(context),
          ),
        ),
      );
    }

    final last = pesees.first;
    final jours = switch (_periode) { _Periode.mois => 30, _Periode.trimestre => 91, _Periode.an => 365 };
    final serie = h.weightSeries(since: now.subtract(Duration(days: jours)));
    double? ecart(int j) {
      final s = h.weightSeries(since: now.subtract(Duration(days: j)));
      return s.length < 2 ? null : s.last.kg - s.first.kg;
    }

    final d7 = ecart(7), d30 = ecart(30);
    String signe(double d) => '${d >= 0 ? '+' : '-'}${Fmt.poids(d.abs(), u)}';
    final recents = h.weightSeries(since: now.subtract(const Duration(days: 7)));
    final moy7 = recents.isEmpty ? null : recents.map((e) => e.kg).reduce((a, b) => a + b) / recents.length;
    final cible = profile?.poidsCibleKg;
    final imc = NutritionCalc.imc(last.poidsKg, profile?.tailleCm);
    final mini = serie.isEmpty ? null : serie.map((e) => e.kg).reduce((a, b) => a < b ? a : b);
    final maxi = serie.isEmpty ? null : serie.map((e) => e.kg).reduce((a, b) => a > b ? a : b);

    return SousPage(
      title: 'Poids',
      haloColor: c.weight,
      actions: [
        IconButton(tooltip: 'Mensurations et photos', onPressed: () => context.push(Paths.sante), icon: const Icon(Icons.straighten_rounded)),
      ],
      bottomBar: PillButton(
        label: 'Ajouter une pesée',
        icon: Icons.add_rounded,
        size: PillSize.large,
        expand: true,
        onPressed: () => saisirPoids(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BigNumber(
                  value: Fmt.n(Fmt.poidsAffiche(last.poidsKg!, u)),
                  unit: u.label,
                  label: 'Dernière pesée · ${Fmt.relatif(last.date)}',
                  caption: moy7 == null ? null : 'Moyenne sur 7 jours : ${Fmt.poids(moy7, u)}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (d7 != null) TagPill('${signe(d7)} en 7 jours', color: c.weight),
                    if (d30 != null) TagPill('${signe(d30)} en 30 jours', color: c.weight),
                  ],
                ),
                const SizedBox(height: 16),
                SegmentedChips<_Periode>(
                  segments: const [(_Periode.mois, '1 mois'), (_Periode.trimestre, '3 mois'), (_Periode.an, '1 an')],
                  value: _periode,
                  onChanged: (p) => setState(() => _periode = p),
                ),
                const SizedBox(height: 16),
                if (serie.length < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('Il faut au moins deux pesées sur la période pour tracer la courbe.', textAlign: TextAlign.center, style: AppType.rowSubtitle()),
                  )
                else ...[
                  MiniSparkline(values: [for (final p in serie) Fmt.poidsAffiche(p.kg, u)], height: 140, color: c.weight),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(Fmt.jourMois(serie.first.date), style: AppType.rowSubtitle()),
                      const Spacer(),
                      Text('min ${Fmt.poids(mini, u)} · max ${Fmt.poids(maxi, u)}', style: AppType.rowSubtitle()),
                      const Spacer(),
                      Text(Fmt.jourMois(serie.last.date), style: AppType.rowSubtitle()),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            label: 'Objectif',
            labelTrailing: AccentLink(label: cible == null ? 'Définir' : 'Modifier', onTap: _objectif),
            child: cible == null
                ? Text('Fixe un poids visé pour suivre l\'écart restant.', style: AppType.rowSubtitle())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        (last.poidsKg! - cible).abs() < 0.3
                            ? 'Objectif atteint : ${Fmt.poids(cible, u)}'
                            : 'Encore ${Fmt.poids((last.poidsKg! - cible).abs(), u)} à ${last.poidsKg! > cible ? 'perdre' : 'prendre'} pour ${Fmt.poids(cible, u)}',
                        style: AppType.rowTitle(),
                      ),
                      if (profile?.poidsKg != null && (profile!.poidsKg! - cible).abs() > 0.1) ...[
                        const SizedBox(height: 10),
                        ProgressBar(
                          value: ((profile.poidsKg! - last.poidsKg!) / (profile.poidsKg! - cible)).clamp(0.0, 1.0),
                          color: c.weight,
                          label: 'Départ ${Fmt.poids(profile.poidsKg, u)}',
                          trailing: 'Visé ${Fmt.poids(cible, u)}',
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'IMC',
                  value: imc == null ? '-' : Fmt.n(imc),
                  compact: true,
                  caption: imc == null ? 'taille manquante dans le profil' : 'indicatif, ignore le muscle',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Masse grasse',
                  value: h.latestBodyFat == null ? '-' : Fmt.n(h.latestBodyFat),
                  unit: h.latestBodyFat == null ? null : '%',
                  compact: true,
                  caption: h.latestBodyFat == null ? 'à noter dans le suivi santé' : 'dernière mesure',
                  onTap: () => context.push(Paths.sante),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TileGroup(
            margin: EdgeInsets.zero,
            label: 'Pesées',
            labelTrailing: LabelCount(Fmt.pluriel(pesees.length, 'pesée')),
            children: [
              for (var i = 0; i < pesees.length && i < 30; i++)
                ListTileX(
                  dense: true,
                  leading: IconHalo.domain(AppDomain.poids, size: 34, glow: false),
                  title: Fmt.jourCap(pesees[i].date),
                  subtitle: i + 1 < pesees.length ? signe(pesees[i].poidsKg! - pesees[i + 1].poidsKg!) : 'Première pesée',
                  value: Fmt.poids(pesees[i].poidsKg, u),
                  onTap: () => saisirPoids(context, existant: pesees[i]),
                  onLongPress: () => _supprimer(pesees[i]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Touche une pesée pour la modifier, appui long pour la supprimer.', textAlign: TextAlign.center, style: AppType.rowSubtitle()),
        ],
      ),
    );
  }
}
