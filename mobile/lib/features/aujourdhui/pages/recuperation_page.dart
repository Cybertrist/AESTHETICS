import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../logic/resume_jour.dart';
import '../routes.dart';
import '../widgets/commun.dart';

/// Récupération muscle par muscle sur le personnage.
class RecuperationPage extends StatelessWidget {
  const RecuperationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionRepo>();
    final ex = context.watch<ExerciseRepo>();
    final c = context.colors;
    final recent = sessions.sessions.take(30).toList();
    final fatigue = Recovery.fatigue(recent, ex.byId);
    final enRecup = Muscle.values.where((m) => (fatigue[m] ?? 0) > 0.2).sortedBy<num>((m) => -(fatigue[m] ?? 0)).toList();
    final prets = Muscle.values.where((m) => (fatigue[m] ?? 0) <= 0.2).toList();
    final large = context.isWide;

    void ouvrir(Muscle m) => context.push(AujourdhuiPaths.muscle(m));

    final carte = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigNumber(
            value: '${prets.length}',
            unit: 'sur ${Muscle.values.length}',
            label: 'Muscles prêts à travailler',
            caption: enRecup.isEmpty ? 'Tout ton corps est reposé.' : '${Fmt.pluriel(enRecup.length, 'muscle')} encore en récupération',
          ),
          const SizedBox(height: 18),
          Center(child: CorpsDouble(intensities: fatigue, height: large ? 380 : 300, labels: true, spacing: 16, onTap: ouvrir)),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Reposé', style: AppType.rowSubtitle()),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: AppTokens.radiusPill,
                    gradient: LinearGradient(colors: [c.muscleIdle, c.muscle]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('Tout juste travaillé', style: AppType.rowSubtitle()),
            ],
          ),
          const SizedBox(height: 8),
          Text('Touche un muscle pour voir son détail.', textAlign: TextAlign.center, style: AppType.rowSubtitle()),
        ],
      ),
    );

    final listes = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TileGroup(
          margin: EdgeInsets.zero,
          label: 'En récupération',
          labelTrailing: LabelCount('${enRecup.length}'),
          children: [
            if (enRecup.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: Text(
                  sessions.sessions.isEmpty
                      ? 'Aucune séance pour l\'instant : tous tes muscles sont frais.'
                      : 'Aucun muscle ne demande de repos en ce moment.',
                  style: AppType.rowSubtitle(),
                ),
              ),
            for (final m in enRecup)
              _LigneMuscle(
                muscle: m,
                fatigue: fatigue[m] ?? 0,
                sousTitre: () {
                  final h = heuresAvantPret(m, recent, ex.byId);
                  return h <= 0 ? 'Presque prêt' : 'Prêt dans ${_heures(h)}';
                }(),
                onTap: () => ouvrir(m),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TileGroup(
          margin: EdgeInsets.zero,
          label: 'Prêts',
          labelTrailing: LabelCount('${prets.length}'),
          children: [
            for (final m in prets)
              _LigneMuscle(
                muscle: m,
                fatigue: fatigue[m] ?? 0,
                sousTitre: switch (derniereSeancePour(m, sessions.sessions, ex.byId)) {
                  final s? => 'Travaillé ${Fmt.ilYa(s.debut)}',
                  null => 'Jamais travaillé pour l\'instant',
                },
                onTap: () => ouvrir(m),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          color: c.surface2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: c.text3, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Estimation tirée de tes séances des quatre derniers jours : chaque série compte (à moitié pour un muscle secondaire), '
                  'puis s\'efface en 48 à 72 heures selon la taille du muscle. Un muscle est prêt à 80 %.',
                  style: AppType.rowSubtitle(),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return SubPageScaffold(
      title: 'Récupération',
      haloColor: c.muscle.withValues(alpha: 0.9),
      maxContentWidth: large ? 1100 : Breakpoints.content,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (large)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: carte), const SizedBox(width: 12), Expanded(child: listes)],
            )
          else ...[
            carte,
            const SizedBox(height: 12),
            listes,
          ],
        ],
      ),
    );
  }
}

String _heures(int h) => h < 24 ? '$h h' : (h % 24 == 0 ? Fmt.pluriel(h ~/ 24, 'jour') : '${h ~/ 24} j ${h % 24} h');

class _LigneMuscle extends StatelessWidget {
  const _LigneMuscle({required this.muscle, required this.fatigue, required this.sousTitre, required this.onTap});

  final Muscle muscle;
  final double fatigue;
  final String sousTitre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = ((1 - fatigue) * 100).round();
    return ListTileX(
      leading: IconHalo(
        icon: Icons.accessibility_new_rounded,
        color: fatigue > 0.2 ? c.muscle : c.training,
        size: 38,
      ),
      title: muscle.label,
      subtitle: sousTitre,
      value: '$pct %',
      valueColor: fatigue > 0.2 ? c.text : c.text2,
      showChevron: true,
      onTap: onTap,
    );
  }
}

/// Détail d'un muscle : récupération, charge de la semaine, séances et exercices.
class MuscleRecuperationPage extends StatelessWidget {
  const MuscleRecuperationPage({super.key, required this.muscle});

  final Muscle muscle;

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionRepo>();
    final ex = context.watch<ExerciseRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final recent = sessions.sessions.take(30).toList();
    final f = Recovery.fatigue(recent, ex.byId)[muscle] ?? 0;
    final pct = ((1 - f) * 100).round();
    final h = f > 0.2 ? heuresAvantPret(muscle, recent, ex.byId) : 0;
    final now = DateTime.now();
    final semaine = sessions.sessionsBetween(now.subtract(const Duration(days: 7)), now.add(const Duration(minutes: 1)));
    final series = Strength.setsParMuscle(semaine, ex.byId)[muscle] ?? 0;
    final volume = Strength.volumeParMuscle(semaine, ex.byId)[muscle] ?? 0;

    final touchees = <WorkoutSession>[];
    final compte = <String, int>{};
    for (final s in sessions.sessions) {
      var touche = false;
      for (final e in s.exercices) {
        final x = ex.byId(e.exerciseId);
        if (x == null || !x.tousMuscles.contains(muscle) || e.seriesFaites.isEmpty) continue;
        touche = true;
        compte[e.exerciseId] = (compte[e.exerciseId] ?? 0) + 1;
      }
      if (touche) touchees.add(s);
    }
    final favoris = compte.entries.sortedBy<num>((e) => -e.value).take(5).toList();
    final vue = muscle.side == MuscleSide.dos ? BodyView.back : BodyView.front;

    return SubPageScaffold(
      title: muscle.label,
      subtitle: muscle.region.label,
      haloColor: c.muscle.withValues(alpha: 0.9),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BigNumber(
                        value: '$pct',
                        unit: '%',
                        label: 'Récupération',
                        caption: f <= 0.2 ? 'Prêt à travailler' : 'Prêt dans ${_heures(h)}',
                        captionColor: f <= 0.2 ? c.accent : null,
                      ),
                      const SizedBox(height: 12),
                      ProgressBar(value: pct / 100, color: f > 0.2 ? c.muscle : c.accent),
                      const SizedBox(height: 16),
                      Text(
                        switch (touchees.firstOrNull) {
                          final s? => 'Dernière fois ${Fmt.ilYa(s.debut)}, ${s.nom}',
                          null => 'Pas encore travaillé',
                        },
                        style: AppType.rowSubtitle(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: BodyMap(view: vue, intensities: {muscle: f > 0.2 ? f : 0}, selected: f > 0.2 ? const {} : {muscle}, height: 220))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatTile(label: 'Séries (7 j)', value: Fmt.n(series), compact: true, caption: _conseilSeries(series))),
              const SizedBox(width: 12),
              Expanded(child: StatTile(label: 'Volume (7 j)', value: Fmt.volume(volume, u), compact: true, caption: 'secondaires à moitié')),
            ],
          ),
          const SizedBox(height: 12),
          TileGroup(
            margin: EdgeInsets.zero,
            label: 'Exercices les plus faits',
            children: [
              if (favoris.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: Text('Aucun exercice ne l\'a encore travaillé.', style: AppType.rowSubtitle()),
                ),
              for (final e in favoris)
                ListTileX(
                  leading: MiniatureExercice(exercise: ex.byId(e.key), size: 42),
                  title: ex.nameOf(e.key),
                  subtitle: (ex.byId(e.key)?.musclesPrincipaux.contains(muscle) ?? false) ? 'Muscle principal' : 'Muscle secondaire',
                  value: Fmt.pluriel(e.value, 'fois', 'fois'),
                  onTap: () => context.push(AujourdhuiPaths.ficheExercice(e.key)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TileGroup(
            margin: EdgeInsets.zero,
            label: 'Séances récentes',
            children: [
              if (touchees.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: Text('Aucune séance pour ce muscle.', style: AppType.rowSubtitle()),
                ),
              for (final s in touchees.take(6))
                ListTileX(
                  leading: IconHalo.domain(AppDomain.entrainement, size: 38),
                  title: s.nom,
                  subtitle: '${Fmt.relatif(s.debut)} · ${Fmt.duree(s.duree)}',
                  value: Fmt.volume(s.volume, u),
                  showChevron: true,
                  onTap: () => context.push(AujourdhuiPaths.seanceDetail(s.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _conseilSeries(double s) {
  if (s == 0) return 'rien cette semaine';
  if (s < 10) return 'visée : 10 à 20 par semaine';
  if (s <= 20) return 'dans la bonne zone';
  return 'beaucoup, surveille la fatigue';
}
