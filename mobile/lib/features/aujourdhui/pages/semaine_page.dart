import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/resume_jour.dart';
import '../routes.dart';
import '../widgets/cartes.dart';
import '../widgets/commun.dart';

/// Bilan d'une semaine d'entraînement, semaine par semaine.
class SemainePage extends StatefulWidget {
  const SemainePage({super.key});

  @override
  State<SemainePage> createState() => _SemainePageState();
}

class _SemainePageState extends State<SemainePage> {
  int _decalage = 0;

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionRepo>();
    final ex = context.watch<ExerciseRepo>();
    final settings = context.watch<SettingsRepo>().settings;
    final profile = context.watch<ProfileRepo>().profile;
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final objectif = profile?.joursParSemaine ?? 3;
    final now = DateTime.now();
    final ref = DateTime(now.year, now.month, now.day - 7 * _decalage);
    final r = ResumeSemaine.pour(sessions, ref, premierJour: settings.premierJourSemaine, objectif: objectif);
    final prev = ResumeSemaine.pour(sessions, ref.subtract(const Duration(days: 7)), premierJour: settings.premierJourSemaine, objectif: objectif);
    final premiere = sessions.sessions.lastOrNull?.debut;
    final peutReculer = premiere != null && r.debut.isAfter(premiere);
    final label = _decalage == 0
        ? 'Cette semaine'
        : _decalage == 1
            ? 'Semaine dernière'
            : 'Semaine du ${Fmt.jourMois(r.debut)}';
    final parMuscle = Strength.setsParMuscle(r.seances, ex.byId);
    final maxSeries = parMuscle.values.fold(0.0, math.max);
    final muscles = parMuscle.entries.sortedBy<num>((e) => -e.value).toList();
    final large = context.isWide;
    final streak = sessions.streakWeeks();

    String? delta(double a, double b, String Function(double) f) {
      if (prev.nbSeances == 0) return null;
      final d = a - b;
      if (d.abs() < 1e-6) return 'comme la semaine d\'avant';
      return '${d > 0 ? '+' : '-'}${f(d.abs())} vs semaine d\'avant';
    }

    final tete = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigNumber(
            value: '${r.nbSeances}',
            unit: '/ ${r.objectif} séances',
            label: '${Fmt.jourMois(r.debut)} au ${Fmt.jourMois(r.fin.subtract(const Duration(days: 1)))}',
            caption: r.nbSeances >= r.objectif && r.objectif > 0 ? 'Objectif de la semaine atteint' : null,
            captionColor: c.accent,
          ),
          const SizedBox(height: 12),
          ProgressBar(value: r.avancement),
          const SizedBox(height: 16),
          JoursSemaine(
            resume: r,
            onJour: (j) {
              final s = r.seances.firstWhereOrNull((s) => Dates.memeJour(s.debut, j));
              if (s != null) context.push(AujourdhuiPaths.seanceDetail(s.id));
            },
          ),
        ],
      ),
    );

    final chiffres = Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Volume',
                value: Fmt.volume(r.volume, u),
                compact: true,
                delta: delta(r.volume, prev.volume, (d) => Fmt.volume(d, u)),
                deltaPositive: prev.nbSeances == 0 ? null : r.volume >= prev.volume,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Durée',
                value: Fmt.duree(r.duree),
                compact: true,
                delta: delta(r.duree.inMinutes.toDouble(), prev.duree.inMinutes.toDouble(), (d) => Fmt.duree(Duration(minutes: d.round()))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Séries',
                value: '${r.series}',
                compact: true,
                delta: delta(r.series.toDouble(), prev.series.toDouble(), (d) => Fmt.n(d, decimals: 0)),
                deltaPositive: prev.nbSeances == 0 ? null : r.series >= prev.series,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Série en cours',
                value: '$streak',
                unit: streak > 1 ? 'semaines' : 'semaine',
                compact: true,
                caption: 'd\'affilée avec au moins une séance',
              ),
            ),
          ],
        ),
      ],
    );

    final volumeJours = AppCard(
      label: 'Volume par jour',
      child: BarresJours(
        valeurs: [
          for (final j in r.jours)
            () {
              final v = r.seances.where((s) => Dates.memeJour(s.debut, j)).fold(0.0, (a, s) => a + s.volume);
              return v == 0 ? null : v;
            }(),
        ],
        libelles: [for (final j in r.jours) Dates.initiale(j)],
        couleur: c.training,
        surlignee: _decalage == 0 ? r.jours.indexWhere((j) => Dates.memeJour(j, now)) : null,
      ),
    );

    final parMuscles = AppCard(
      label: 'Séries par muscle',
      labelTrailing: const LabelCount('secondaires à moitié'),
      child: muscles.isEmpty
          ? Text('Aucune série cette semaine.', style: AppType.rowSubtitle())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CorpsDouble(
                    intensities: {for (final e in muscles) e.key: maxSeries == 0 ? 0 : e.value / maxSeries},
                    height: 220,
                    labels: true,
                    spacing: 16,
                  ),
                ),
                const SizedBox(height: 16),
                for (final e in muscles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ProgressBar(
                      value: e.value / math.max(20, maxSeries),
                      label: e.key.label,
                      trailing: Fmt.n(e.value),
                      color: e.value < 10 ? c.training.withValues(alpha: 0.6) : c.training,
                    ),
                  ),
                Text('Repère courant : 10 à 20 séries par muscle et par semaine.', style: AppType.rowSubtitle()),
              ],
            ),
    );

    final liste = TileGroup(
      margin: EdgeInsets.zero,
      label: 'Séances',
      labelTrailing: LabelCount(Fmt.pluriel(r.nbSeances, 'séance')),
      children: [
        if (r.seances.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aucune séance cette semaine.', style: AppType.rowSubtitle()),
                if (_decalage == 0) ...[
                  const SizedBox(height: 10),
                  PillButton.link(label: 'Voir la séance du jour', onPressed: () => context.push(AujourdhuiPaths.seanceDuJour)),
                ],
              ],
            ),
          ),
        for (final s in r.seances)
          ListTileX(
            leading: IconHalo.domain(AppDomain.entrainement, size: 38),
            title: s.nom,
            subtitle: '${Fmt.jourCap(s.debut)} · ${Fmt.duree(s.duree)} · ${Fmt.pluriel(s.nbSeriesFaites, 'série')}',
            value: Fmt.volume(s.volume, u),
            showChevron: true,
            onTap: () => context.push(AujourdhuiPaths.seanceDetail(s.id)),
          ),
      ],
    );

    return SubPageScaffold(
      title: 'Semaine',
      haloColor: c.training,
      maxContentWidth: large ? 1100 : Breakpoints.content,
      actions: [
        IconButton(
          tooltip: 'Historique complet',
          onPressed: () => context.go(Paths.progres),
          icon: const Icon(Icons.insights_rounded),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          StepSelector(
            label: label,
            previousTooltip: 'Semaine précédente',
            nextTooltip: 'Semaine suivante',
            onPrevious: peutReculer || _decalage == 0 && premiere != null ? () => setState(() => _decalage++) : null,
            onNext: _decalage == 0 ? null : () => setState(() => _decalage--),
            onTapLabel: _decalage == 0 ? null : () => setState(() => _decalage = 0),
          ),
          const SizedBox(height: 12),
          if (large)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: [tete, const SizedBox(height: 12), chiffres, const SizedBox(height: 12), volumeJours])),
                const SizedBox(width: 12),
                Expanded(child: Column(children: [liste, const SizedBox(height: 12), parMuscles])),
              ],
            )
          else ...[
            tete,
            const SizedBox(height: 12),
            chiffres,
            const SizedBox(height: 12),
            liste,
            const SizedBox(height: 12),
            volumeJours,
            const SizedBox(height: 12),
            parMuscles,
          ],
        ],
      ),
    );
  }
}
