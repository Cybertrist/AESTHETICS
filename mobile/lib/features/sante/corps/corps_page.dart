import 'dart:io';

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

/// Corps : poids et sa tendance, masse grasse, mensurations, photos.
class CorpsPage extends StatefulWidget {
  const CorpsPage({super.key});

  @override
  State<CorpsPage> createState() => _CorpsPageState();
}

class _CorpsPageState extends State<CorpsPage> {
  Periode _periode = Periode.trimestre;
  Periode _periodeMg = Periode.trimestre;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final profil = context.watch<ProfileRepo>().profile;
    final unite = context.watch<ProfileRepo>().unite;
    final mesures = repo.measurements;
    String kg(double v) => Fmt.n(Fmt.poidsAffiche(v, unite));

    final body = mesures.isEmpty && repo.photos.isEmpty
        ? Center(
            child: EmptyState(
              icon: Icons.monitor_weight_rounded,
              iconColor: c.weight,
              title: 'Rien de mesuré pour l\'instant',
              message: 'Pesez-vous le matin à jeun, notez vos tours au mètre ruban et prenez une photo par mois.',
              actionLabel: 'Première mesure',
              onAction: () => context.push('/sante/corps/mesure'),
              secondaryLabel: 'Prendre une photo',
              onSecondary: () => context.push('/sante/corps/photos'),
            ),
          )
        : _contenu(context, repo, profil, unite, kg);

    return SubPageScaffold(
      title: 'Corps',
      haloColor: c.weight,
      actions: [
        RoundIconButton(icon: Icons.history_rounded, filled: false, tooltip: 'Historique des mesures', onPressed: () => context.push('/sante/corps/mesures')),
        const SizedBox(width: 6),
        RoundIconButton(icon: Icons.add_rounded, tooltip: 'Nouvelle mesure', onPressed: () => context.push('/sante/corps/mesure')),
      ],
      body: body,
    );
  }

  Widget _contenu(BuildContext context, HealthRepo repo, UserProfile? profil, UnitePoids unite, String Function(double) kg) {
    final c = context.colors;
    final today = Dates.jour(DateTime.now());
    final debut = _periode.debut();
    final tous = [for (final p in repo.weightSeries()) (date: p.date, v: p.kg)];
    final moyTous = SanteCalc.moyenneMobile(tous);
    final pts = tous.where((p) => !p.date.isBefore(debut)).toList();
    final moy = moyTous.where((p) => !p.date.isBefore(debut)).toList();
    final delta = SanteCalc.variation(moy);
    final last = repo.latestWeightEntry;
    final cible = profil?.poidsCibleKg;
    final imc = NutritionCalc.imc(last?.poidsKg, profil?.tailleCm);
    final mg = repo.latestBodyFat;
    final mgPts = [
      for (final m in repo.measurements.reversed)
        if (m.masseGrassePct != null && !m.date.isBefore(_periodeMg.debut())) (date: m.date, v: m.masseGrassePct!),
    ];
    final masseMaigre = last?.poidsKg != null && mg != null ? last!.poidsKg! * (1 - mg / 100) : null;

    // Rythme hebdomadaire sur 4 semaines de moyenne mobile.
    final quatre = moyTous.where((p) => p.date.isAfter(today.subtract(const Duration(days: 28)))).toList();
    final rythme = quatre.length >= 2 ? (quatre.last.v - quatre.first.v) / (quatre.last.date.difference(quatre.first.date).inDays.clamp(1, 28) / 7) : null;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        SanteColonnes(children: [
          Padding(
            padding: santePad,
            child: AppCard(
              label: 'Poids',
              labelTrailing: last == null ? null : Text(Fmt.relatif(last.date), style: AppType.rowSubtitle()),
              child: last == null
                  ? Text('Aucune pesée.', style: AppType.rowSubtitle())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BigNumber(
                          value: kg(last.poidsKg!),
                          unit: unite.label,
                          size: 44,
                          caption: delta == null ? 'Tendance après quelques pesées' : '${signe(Fmt.poidsAffiche(delta, unite))} ${unite.label} sur ${_periode.label}',
                          captionColor: delta == null ? null : c.weight,
                        ),
                        if (cible != null) ...[
                          const SizedBox(height: 16),
                          ProgressBar(
                            value: _avancementCible(tous, cible),
                            color: c.weight,
                            label: 'Objectif ${kg(cible)} ${unite.label}',
                            trailing: '${Fmt.n((Fmt.poidsAffiche((last.poidsKg! - cible).abs(), unite)))} ${unite.label} restants',
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          Padding(
            padding: santePad,
            child: AppCard(
              label: 'Composition',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: MiniChiffre(label: 'Masse grasse', value: mg == null ? '-' : Fmt.n(mg), unit: mg == null ? null : '%')),
                      Expanded(child: MiniChiffre(label: 'Masse maigre', value: masseMaigre == null ? '-' : kg(masseMaigre), unit: masseMaigre == null ? null : unite.label)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: MiniChiffre(label: 'IMC', value: imc == null ? '-' : Fmt.n(imc), caption: imc == null ? 'Taille à renseigner' : _imcTexte(imc))),
                      Expanded(
                        child: MiniChiffre(
                          label: 'Rythme',
                          value: rythme == null ? '-' : signe(Fmt.poidsAffiche(rythme, unite), decimals: 2),
                          unit: rythme == null ? null : '${unite.label} / sem.',
                          caption: 'sur 4 semaines',
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
          label: 'Courbe du poids',
          periode: _periode,
          onPeriode: (p) => setState(() => _periode = p),
          legende: Legende(items: [
            (c.weight.withValues(alpha: 0.5), 'Pesées', false),
            (c.weight, 'Moyenne sur 7 jours', true),
            if (cible != null) (c.accent, 'Objectif', true),
          ]),
          child: SanteCourbe(
            points: pts,
            tendance: moy,
            debut: debut,
            fin: today,
            color: c.weight,
            format: (v) => kg(v),
            objectif: cible,
          ),
        ),
        if (mgPts.isNotEmpty) ...[
          const SizedBox(height: 12),
          CarteCourbe(
            label: 'Masse grasse',
            periode: _periodeMg,
            periodes: const [Periode.mois, Periode.trimestre, Periode.annee],
            onPeriode: (p) => setState(() => _periodeMg = p),
            child: SanteCourbe(
              points: mgPts,
              debut: _periodeMg.debut(),
              fin: today,
              color: c.heart,
              height: 150,
              format: (v) => '${Fmt.n(v)} %',
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Mensurations(mesures: repo.measurements),
        const SizedBox(height: 12),
        _Photos(photos: repo.photos),
        const SizedBox(height: 12),
        TileGroup(
          children: [
            ListTileX(
              leading: IconHalo(icon: Icons.list_alt_rounded, color: c.weight, size: 38),
              title: 'Historique des mesures',
              subtitle: Fmt.pluriel(repo.measurements.length, 'mesure'),
              showChevron: true,
              onTap: () => context.push('/sante/corps/mesures'),
            ),
            ListTileX(
              leading: IconHalo(icon: Icons.sync_rounded, color: c.heart, size: 38),
              title: 'Balance connectée',
              subtitle: 'Importer les pesées depuis Health Connect',
              showChevron: true,
              onTap: () => context.push('/sante/connexion'),
            ),
          ],
        ),
      ],
    );
  }

  static double _avancementCible(List<Point> tous, double cible) {
    if (tous.length < 2) return 0;
    final depart = tous.first.v;
    final ecart = cible - depart;
    if (ecart.abs() < 0.01) return 1;
    return ((tous.last.v - depart) / ecart).clamp(0.0, 1.0);
  }

  static String _imcTexte(double imc) => imc < 18.5
      ? 'Maigreur'
      : imc < 25
          ? 'Normal'
          : imc < 30
              ? 'Surpoids (la masse musculaire compte)'
              : 'Obésité';
}

class _Mensurations extends StatelessWidget {
  const _Mensurations({required this.mesures});
  final List<BodyMeasurement> mesures;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groupes = [for (final g in GroupeTour.values) if (g.serie(mesures).isNotEmpty) g];
    return TileGroup(
      label: 'Mensurations',
      labelTrailing: AccentLink(label: groupes.isEmpty ? 'Mesurer' : 'Tout voir', onTap: () => context.push(groupes.isEmpty ? '/sante/corps/mesure' : '/sante/corps/mensurations')),
      children: groupes.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                child: Text('Bras, poitrine, taille, hanches, cuisses, mollets, cou : notez vos tours pour suivre ce que la balance ne dit pas.', style: AppType.rowSubtitle().copyWith(fontSize: 13.5)),
              ),
            ]
          : [
              for (final g in groupes.take(7))
                LigneTour(groupe: g, serie: g.serie(mesures), color: c.weight),
            ],
    );
  }
}

/// Ligne d'une mensuration : dernière valeur, variation, mini courbe.
class LigneTour extends StatelessWidget {
  const LigneTour({super.key, required this.groupe, required this.serie, required this.color});
  final GroupeTour groupe;
  final List<Point> serie;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final delta = SanteCalc.variation(serie);
    final bien = delta == null || delta == 0 ? null : (groupe.baisserEstBien ? delta < 0 : delta > 0);
    return ListTileX(
      leading: IconHalo(icon: Icons.straighten_rounded, color: color, size: 38, glow: false),
      title: groupe.label,
      subtitle: delta == null ? 'Relevé le ${Fmt.jourMois(serie.last.date)}' : '${signe(delta)} cm en ${ecart(serie.first.date, serie.last.date)}',
      subtitleMaxLines: 1,
      subtitleColor: bien == null ? null : (bien ? c.accent : c.text3),
      trailing: serie.length >= 2 ? SizedBox(width: 56, child: MiniSparkline(values: [for (final p in serie) p.v], height: 24, color: color)) : null,
      value: '${Fmt.n(serie.last.v)} cm',
      showChevron: true,
      onTap: () => context.push('/sante/corps/tour/${groupe.name}'),
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.photos});
  final List<ProgressPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      margin: santePad,
      label: 'Photos d\'évolution',
      labelTrailing: AccentLink(label: photos.isEmpty ? 'Ajouter' : 'Tout voir', onTap: () => context.push('/sante/corps/photos')),
      child: photos.isEmpty
          ? Text('Même lumière, même pose, une fois par mois : la comparaison côte à côte fait le reste.', style: AppType.rowSubtitle().copyWith(fontSize: 13.5))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length.clamp(0, 10),
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final p = photos[i];
                      return GestureDetector(
                        onTap: () => context.push('/sante/corps/photos/${p.id}'),
                        child: ClipRRect(
                          borderRadius: AppTokens.radius12,
                          child: SizedBox(
                            width: 99,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(File(p.chemin), fit: BoxFit.cover, cacheWidth: 260, errorBuilder: (_, _, _) => Container(color: c.surface3)),
                                Positioned(
                                  left: 6,
                                  bottom: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: AppTokens.radiusPill),
                                    child: Text(Fmt.jourMois(p.date), style: AppType.rowSubtitle(color: Colors.white).copyWith(fontSize: 10.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (photos.length >= 2) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PillButton.link(
                      label: 'Comparer avant et après',
                      icon: Icons.compare_rounded,
                      onPressed: () => context.push('/sante/corps/comparer'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
