import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/data/data.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/body/body_map.dart';
import '../../core/ui/ui.dart';
import 'common/sante_calculs.dart';
import 'common/sante_widgets.dart';
import 'services/activite_journal.dart';

/// Tableau de bord Santé : sommeil, corps, récupération, activité,
/// compléments, photos. Chaque carte ouvre sa page.
class SantePage extends StatelessWidget {
  const SantePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepo>().settings;
    final journal = ActiviteJournal.of(context.read<Store>());
    return SubPageScaffold(
      title: 'Santé',
      subtitle: 'Sommeil, corps, récupération',
      haloColor: context.colors.heart,
      actions: [
        RoundIconButton(
          icon: Icons.sync_rounded,
          filled: false,
          tooltip: 'Health Connect',
          onPressed: () => context.push('/sante/connexion'),
        ),
      ],
      body: ListenableBuilder(
        listenable: journal,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            if (!settings.santeConnectee && journal.vide) ...[
              const _BandeauConnexion(),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: santePad,
              child: SanteColonnes(children: [
                const _CarteSommeil(),
                const _CarteCorps(),
                const _CarteRecuperation(),
                _CarteActivite(journal: journal),
                const _CarteComplements(),
                const _CartePhotos(),
              ]),
            ),
            const SizedBox(height: 12),
            TileGroup(
              label: 'Raccourcis',
              children: [
                ListTileX(
                  leading: IconHalo.domain(AppDomain.sommeil, icon: Icons.add_rounded, size: 38),
                  title: 'Noter ma nuit',
                  subtitle: 'Heures de coucher et de lever, qualité',
                  showChevron: true,
                  onTap: () => context.push('/sante/sommeil/ajouter'),
                ),
                ListTileX(
                  leading: IconHalo.domain(AppDomain.poids, icon: Icons.monitor_weight_rounded, size: 38),
                  title: 'Me peser',
                  subtitle: 'Poids, masse grasse, mensurations',
                  showChevron: true,
                  onTap: () => context.push('/sante/corps/mesure'),
                ),
                ListTileX(
                  leading: IconHalo(icon: Icons.photo_camera_rounded, color: context.colors.weight, size: 38),
                  title: 'Prendre une photo',
                  subtitle: 'Face, profil ou dos',
                  showChevron: true,
                  onTap: () => context.push('/sante/corps/photos'),
                ),
                ListTileX(
                  leading: IconHalo.domain(AppDomain.coeur, icon: Icons.health_and_safety_rounded, size: 38),
                  title: 'Health Connect',
                  subtitle: settings.santeConnectee ? 'Relié, synchronisation manuelle ou à l\'ouverture' : 'Pas encore relié',
                  showChevron: true,
                  onTap: () => context.push('/sante/connexion'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BandeauConnexion extends StatelessWidget {
  const _BandeauConnexion();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      margin: santePad,
      onTap: () => context.push('/sante/connexion'),
      child: Row(
        children: [
          IconHalo.domain(AppDomain.coeur, icon: Icons.favorite_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Relier Health Connect', style: AppType.rowTitle()),
                const SizedBox(height: 3),
                Text('Vos nuits, pesées, pas et fréquence cardiaque arrivent tout seuls.', style: AppType.rowSubtitle()),
                const SizedBox(height: 10),
                PillButton.link(label: 'Relier', size: PillSize.small, onPressed: () => context.push('/sante/connexion')),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: c.text3),
        ],
      ),
    );
  }
}

class _CarteSommeil extends StatelessWidget {
  const _CarteSommeil();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final last = repo.lastSleep;
    final today = Dates.jour(DateTime.now());
    final jours = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final moy = repo.averageSleep();
    return AppCard(
      onTap: () => context.push('/sante/sommeil'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeteCarte(icon: Icons.bedtime_rounded, color: c.sleep, title: 'Sommeil'),
          const SizedBox(height: 16),
          if (last == null)
            Text('Aucune nuit notée. Touchez pour ajouter la dernière.', style: AppType.rowSubtitle())
          else ...[
            BigNumber(
              value: Fmt.sommeil(last.duree),
              size: 34,
              caption: '${Fmt.relatif(last.lever)} · ${SanteCalc.qualite(last.qualite)}',
            ),
            const SizedBox(height: 14),
            MiniBarres(
              valeurs: [for (final d in jours) repo.sleepFor(d)?.duree.inMinutes.toDouble()],
              color: c.sleep,
              objectif: 420,
              etiquettes: [for (final d in jours) Dates.initiale(d)],
            ),
            if (moy != null) ...[
              const SizedBox(height: 10),
              Text('Moyenne sur 7 jours : ${Fmt.sommeil(moy)}', style: AppType.rowSubtitle()),
            ],
          ],
        ],
      ),
    );
  }
}

class _CarteCorps extends StatelessWidget {
  const _CarteCorps();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final serie = repo.weightSeries(since: DateTime.now().subtract(const Duration(days: 90)));
    final last = repo.latestWeightEntry;
    final pts = [for (final p in serie) (date: p.date, v: p.kg)];
    final moy = SanteCalc.moyenneMobile(pts);
    final mois = moy.where((p) => p.date.isAfter(DateTime.now().subtract(const Duration(days: 30)))).toList();
    final delta = SanteCalc.variation(mois);
    final mg = repo.latestBodyFat;
    return AppCard(
      onTap: () => context.push('/sante/corps'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeteCarte(icon: Icons.monitor_weight_rounded, color: c.weight, title: 'Corps'),
          const SizedBox(height: 16),
          if (last == null)
            Text('Aucune pesée. Touchez pour noter votre poids.', style: AppType.rowSubtitle())
          else ...[
            BigNumber(
              value: Fmt.n(Fmt.poidsAffiche(last.poidsKg!, unite)),
              unit: unite.label,
              size: 34,
              caption: [
                if (delta != null) '${signe(Fmt.poidsAffiche(delta, unite))} ${unite.label} en 30 j',
                if (mg != null) '${Fmt.n(mg)} % de masse grasse',
              ].join(' · ').ifEmpty(Fmt.relatif(last.date)),
            ),
            if (moy.length >= 2) ...[
              const SizedBox(height: 14),
              MiniSparkline(values: [for (final p in moy) p.v], height: 44, color: c.weight),
            ],
          ],
        ],
      ),
    );
  }
}

class _CarteRecuperation extends StatelessWidget {
  const _CarteRecuperation();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions;
    final ex = context.watch<ExerciseRepo>();
    final fatigue = Recovery.fatigue(sessions.take(30), ex.byId);
    final fatigues = fatigue.values.where((v) => v > 0.2).length;
    return AppCard(
      onTap: () => context.push('/sante/recuperation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeteCarte(icon: Icons.self_improvement_rounded, color: c.training, title: 'Récupération'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BigNumber(value: '${Muscle.values.length - fatigues}', unit: '/ ${Muscle.values.length}', size: 34),
                    const SizedBox(height: 4),
                    Text(fatigues == 0 ? 'Tous les muscles sont prêts' : 'muscles prêts, $fatigues en récupération', style: AppType.rowSubtitle()),
                  ],
                ),
              ),
              BodyMapDual(intensities: fatigue, height: 118, spacing: 4),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarteActivite extends StatelessWidget {
  const _CarteActivite({required this.journal});
  final ActiviteJournal journal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = journal.jour(DateTime.now());
    final pas = today?.pas;
    return AppCard(
      onTap: () => context.push('/sante/activite'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeteCarte(icon: Icons.directions_walk_rounded, color: c.heart, title: 'Activité'),
          const SizedBox(height: 16),
          if (journal.vide)
            Text('Reliez Health Connect pour voir vos pas, vos calories et votre cœur au repos.', style: AppType.rowSubtitle())
          else
            Row(
              children: [
                ProgressRing(
                  value: (pas ?? 0) / journal.objectifPas,
                  size: 76,
                  stroke: 8,
                  color: c.heart,
                  center: Icon(Icons.directions_walk_rounded, color: c.heart, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MiniChiffre(label: 'Pas aujourd\'hui', value: pas == null ? '-' : Fmt.n(pas, decimals: 0)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: MiniChiffre(label: 'Actives', value: Fmt.n(today?.kcalActives, decimals: 0), unit: 'kcal')),
                          Expanded(child: MiniChiffre(label: 'Au repos', value: Fmt.n(today?.fcRepos ?? journal.jours.firstOrNullWhere((a) => a.fcRepos != null)?.fcRepos, decimals: 0), unit: 'bpm')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CarteComplements extends StatelessWidget {
  const _CarteComplements();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final actifs = repo.activeSupplements;
    final today = DateTime.now();
    final pris = actifs.where((s) => repo.takenOn(s.id, today)).length;
    return AppCard(
      onTap: () => context.push('/sante/complements'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeteCarte(
            icon: Icons.medication_rounded,
            color: c.nutrition,
            title: 'Compléments',
            trailing: actifs.isEmpty ? null : Padding(padding: const EdgeInsets.only(right: 4), child: LabelCount('$pris / ${actifs.length}')),
          ),
          const SizedBox(height: 10),
          if (actifs.isEmpty)
            Text('Créatine, vitamine D, oméga 3 : suivez vos prises et recevez un rappel.', style: AppType.rowSubtitle())
          else
            for (final s in actifs.take(4))
              _CaseComplement(supplement: s, pris: repo.takenOn(s.id, today)),
        ],
      ),
    );
  }
}

class _CaseComplement extends StatelessWidget {
  const _CaseComplement({required this.supplement, required this.pris});
  final Supplement supplement;
  final bool pris;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: AppTokens.radius12,
      onTap: () => context.read<HealthRepo>().toggleIntake(supplement.id, DateTime.now()),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppTokens.fast,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: pris ? c.nutrition : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: pris ? c.nutrition : c.text3, width: 1.6),
              ),
              child: pris ? const Icon(Icons.check_rounded, size: 17, color: Colors.black) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                supplement.nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.rowTitle(color: pris ? c.text2 : c.text).copyWith(fontSize: 14),
              ),
            ),
            Text('${Fmt.n(supplement.dose, decimals: 2)} ${supplement.unite}', style: AppType.rowSubtitle()),
          ],
        ),
      ),
    );
  }
}

class _CartePhotos extends StatelessWidget {
  const _CartePhotos();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final photos = context.watch<HealthRepo>().photos;
    return AppCard(
      onTap: () => context.push('/sante/corps/photos'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeteCarte(
            icon: Icons.photo_library_rounded,
            color: c.weight,
            title: 'Photos d\'évolution',
            trailing: photos.isEmpty ? null : Padding(padding: const EdgeInsets.only(right: 4), child: LabelCount('${photos.length}')),
          ),
          const SizedBox(height: 14),
          if (photos.isEmpty)
            Text('Une photo par mois suffit pour voir le chemin parcouru.', style: AppType.rowSubtitle())
          else
            SizedBox(
              height: 92,
              child: Row(
                children: [
                  for (final p in photos.take(4)) ...[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppTokens.radius12,
                        child: Image.file(
                          File(p.chemin),
                          fit: BoxFit.cover,
                          height: 92,
                          cacheWidth: 240,
                          errorBuilder: (_, _, _) => Container(color: c.surface3, child: Icon(Icons.broken_image_rounded, color: c.text3)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  for (var i = photos.length; i < 4; i++) const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String autre) => isEmpty ? autre : this;
}

extension _Premier<T> on List<T> {
  T? firstOrNullWhere(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
