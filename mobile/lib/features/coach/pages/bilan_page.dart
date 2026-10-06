import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../logic/coach_engine.dart';
import '../logic/coach_snapshot.dart';
import '../logic/week_report.dart';
import '../widgets/coach_markdown.dart';
import '../widgets/coach_scope.dart';
import 'chat_page.dart';

String _sansUnite(String v) {
  final i = v.lastIndexOf(' ');
  return i < 0 ? v : v.substring(0, i);
}

/// Bilan de la semaine : chiffres, muscles travaillés, records et avis du coach.
class BilanPage extends StatefulWidget {
  const BilanPage({super.key, this.semaine});

  /// Un jour de la semaine à afficher (la semaine en cours par défaut).
  final DateTime? semaine;

  @override
  State<BilanPage> createState() => _BilanPageState();
}

class _BilanPageState extends State<BilanPage> {
  late DateTime _jour = widget.semaine ?? DateTime.now();

  String _libelle(WeekReport r, DateTime now) {
    final courante = Dates.memeJour(r.debut, Dates.debutSemaine(now, premierJour: context.read<SettingsRepo>().settings.premierJourSemaine));
    if (courante) return 'Cette semaine';
    final prec = Dates.memeJour(r.debut.add(const Duration(days: 7)), Dates.debutSemaine(now, premierJour: context.read<SettingsRepo>().settings.premierJourSemaine));
    if (prec) return 'Semaine dernière';
    return 'Du ${Fmt.jourMois(r.debut)} au ${Fmt.jourMois(r.fin)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = context.watch<SettingsRepo>().settings;
    context.watch<SessionRepo>();
    context.watch<NutritionRepo>();
    context.watch<HealthRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final snapshot = CoachSnapshot.read(context);
    final report = WeekReport.build(snapshot, _jour);
    final now = snapshot.now;
    final courante = report.enCours(now);
    final premiere = snapshot.sessions.isEmpty ? null : snapshot.sessions.last.debut;
    final peutReculer = premiere != null && report.debut.isAfter(premiere);

    final selector = StepSelector(
      label: _libelle(report, now),
      onPrevious: peutReculer ? () => setState(() => _jour = report.debut.subtract(const Duration(days: 7))) : null,
      onNext: courante ? null : () => setState(() => _jour = report.debut.add(const Duration(days: 7))),
      previousTooltip: 'Semaine précédente',
      nextTooltip: 'Semaine suivante',
    );

    final stats = GridView.count(
      crossAxisCount: context.isWide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: context.isWide ? 1.35 : 1.25,
      children: [
        StatTile(
          label: 'Séances',
          value: '${report.sessions.length}',
          unit: '/ ${report.objectifSeances}',
          icon: Icons.fitness_center_rounded,
          color: AppTokens.domainTraining,
          caption: report.sessions.length >= report.objectifSeances ? 'Objectif tenu' : 'Objectif ${report.objectifSeances}',
        ),
        StatTile(
          label: 'Volume',
          value: _sansUnite(Fmt.volume(report.volume, unite)),
          unit: Fmt.volume(report.volume, unite).split(' ').last,
          icon: Icons.stacked_bar_chart_rounded,
          color: AppTokens.domainTraining,
          delta: report.variationVolume == null ? null : '${report.variationVolume! >= 0 ? '+' : ''}${Fmt.n(report.variationVolume! * 100, decimals: 0)} %',
          deltaPositive: report.variationVolume == null ? null : report.variationVolume! >= 0,
        ),
        StatTile(
          label: 'Séries',
          value: '${report.series}',
          icon: Icons.repeat_rounded,
          color: AppTokens.domainTraining,
          caption: 'Durée ${Fmt.duree(report.duree)}',
        ),
        StatTile(
          label: 'Records',
          value: '${report.records.length}',
          icon: Icons.emoji_events_rounded,
          color: AppTokens.domainWeight,
          caption: report.records.isEmpty ? 'Aucun cette semaine' : 'Battus cette semaine',
        ),
      ],
    );

    final maxSeries = report.seriesParMuscle.values.fold<double>(0, (a, b) => a > b ? a : b);
    final muscles = report.seriesParMuscle.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final muscleCard = AppCard(
      label: 'Muscles travaillés',
      labelTrailing: LabelCount('séries effectives'),
      child: muscles.isEmpty
          ? Text('Aucune série cette semaine.', style: AppType.rowSubtitle())
          : Column(
              children: [
                BodyMapDual(
                  height: 230,
                  labels: true,
                  intensities: {for (final e in muscles) e.key: (e.value / (maxSeries < 10 ? 10 : maxSeries)).clamp(0.15, 1.0)},
                ),
                const SizedBox(height: 16),
                for (final e in muscles.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ProgressBar(
                      value: (e.value / 20).clamp(0.0, 1.0),
                      label: e.key.label,
                      trailing: Fmt.n(e.value, decimals: 1),
                      color: e.value >= 10 ? c.accent : AppTokens.domainTraining,
                    ),
                  ),
                Text('Repère : 10 à 20 séries par semaine et par grand muscle.', style: AppType.rowSubtitle().copyWith(fontSize: 12.5, color: c.text3)),
              ],
            ),
    );

    final records = report.records.isEmpty
        ? null
        : TileGroup(
            margin: EdgeInsets.zero,
            label: 'Records battus',
            labelTrailing: LabelCount('${report.records.length}'),
            children: [
              for (final r in report.records.take(12))
                ListTileX(
                  leading: IconHalo(icon: Icons.emoji_events_rounded, color: AppTokens.domainWeight, size: 38),
                  title: snapshot.exercises.nameOf(r.exerciseId),
                  subtitle: '${r.type.label}, ${Fmt.relatif(r.date)}',
                  value: report.valeurRecord(r),
                ),
            ],
          );

    final vie = TileGroup(
      margin: EdgeInsets.zero,
      label: 'Hygiène de vie',
      children: [
        ListTileX(
          leading: IconHalo.domain(AppDomain.nutrition, size: 38),
          title: 'Calories',
          subtitle: report.nutrition == null ? 'Aucun repas noté' : 'Moyenne sur ${Fmt.pluriel(report.joursNutrition, 'jour')}',
          value: report.nutrition == null ? '-' : '${Fmt.n(report.nutrition!.kcal, decimals: 0)} / ${Fmt.n(report.objectifKcal, decimals: 0)}',
        ),
        ListTileX(
          leading: IconHalo.domain(AppDomain.nutrition, icon: Icons.egg_alt_rounded, size: 38),
          title: 'Protéines',
          subtitle: report.nutrition == null ? 'Aucun repas noté' : 'Par jour, objectif ${Fmt.n(report.objectifProteines, decimals: 0)} g',
          value: report.nutrition == null ? '-' : '${Fmt.n(report.nutrition!.proteines, decimals: 0)} g',
          valueColor: report.nutrition != null && report.nutrition!.proteines >= report.objectifProteines * 0.9 ? c.accent : null,
        ),
        ListTileX(
          leading: IconHalo.domain(AppDomain.sommeil, size: 38),
          title: 'Sommeil',
          subtitle: report.sommeil == null ? 'Aucune nuit notée' : 'Moyenne sur ${Fmt.pluriel(report.nuits, 'nuit')}',
          value: report.sommeil == null ? '-' : Fmt.sommeil(report.sommeil!),
        ),
        ListTileX(
          leading: IconHalo.domain(AppDomain.poids, size: 38),
          title: 'Poids',
          subtitle: report.variationPoids == null ? 'Deux pesées nécessaires' : '${Fmt.poids(report.poidsDebut, unite)} puis ${Fmt.poids(report.poidsFin, unite)}',
          value: report.variationPoids == null
              ? '-'
              : '${report.variationPoids! >= 0 ? '+' : '-'}${Fmt.poids(report.variationPoids!.abs(), unite)}',
        ),
      ],
    );

    final avis = CoachListen(builder: (context, prefs, engine) {
      final key = CoachEngine.cle(settings);
      final texte = prefs.bilans[report.cle];
      final enCours = engine.bilanEnCours(report.cle);
      final erreur = engine.bilanErreur(report.cle);
      Widget contenu;
      if (enCours) {
        contenu = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                const SizedBox(width: 10),
                Text('Le coach rédige ton bilan…', style: AppType.rowSubtitle()),
              ],
            ),
            const SizedBox(height: 14),
            const Skeleton(height: 12),
            const SizedBox(height: 8),
            const Skeleton(height: 12, width: 220),
            const SizedBox(height: 8),
            const Skeleton(height: 12, width: 260),
          ],
        );
      } else if (texte != null) {
        contenu = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoachMarkdown(texte, selectable: true),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (key != null)
                  PillButton.ghost(
                    label: 'Réécrire',
                    icon: Icons.refresh_rounded,
                    size: PillSize.small,
                    onPressed: () => engine.redigerBilan(report: report, snapshot: snapshot, settings: settings),
                  ),
              ],
            ),
          ],
        );
      } else {
        contenu = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoachMarkdown(report.texteHorsLigne()),
            if (erreur != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 18, color: c.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(erreur, style: AppType.rowSubtitle(color: c.error))),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (key != null && !report.vide)
              PillButton(
                label: erreur == null ? 'Rédiger avec le coach' : 'Réessayer',
                icon: Icons.auto_awesome_rounded,
                size: PillSize.small,
                onPressed: () => engine.redigerBilan(report: report, snapshot: snapshot, settings: settings),
              )
            else if (key == null)
              PillButton.link(
                label: 'Ajouter une clé pour un bilan rédigé',
                size: PillSize.small,
                onPressed: () => context.push('/coach/reglages/cle'),
              ),
          ],
        );
      }
      return AppCard(
        label: texte != null ? 'L\'avis du coach' : 'En résumé',
        labelTrailing: texte != null ? const LabelCount('rédigé par le coach') : null,
        child: contenu,
      );
    });

    const gap = SizedBox(height: 14);
    final left = <Widget>[stats, gap, avis];
    final right = <Widget>[muscleCard, gap, if (records != null) ...[records, gap], vie];

    return SubPageScaffold(
      title: 'Bilan de la semaine',
      subtitle: 'Du ${Fmt.jourMois(report.debut)} au ${Fmt.jourMois(report.fin)}',
      maxContentWidth: context.isExpanded ? 1180 : Breakpoints.content,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 32),
        children: [
          selector,
          const SizedBox(height: 14),
          if (report.vide)
            EmptyState(
              icon: Icons.insights_rounded,
              iconColor: AppTokens.domainCoach,
              title: courante ? 'Semaine encore vide' : 'Rien d\'enregistré cette semaine',
              message: 'Une séance, un repas ou une nuit suffisent pour que le bilan prenne forme.',
              actionLabel: 'Aller à l\'entraînement',
              onAction: () => context.go('/entrainer'),
              compact: true,
            )
          else if (context.isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
              ],
            )
          else ...[
            ...left,
            gap,
            ...right,
          ],
          const SizedBox(height: 18),
          PillButton.secondary(
            label: 'En parler avec le coach',
            icon: Icons.forum_rounded,
            expand: true,
            chevron: true,
            onPressed: () => openCoachChat(
              context,
              question: 'Fais le point sur ma semaine du ${Fmt.jourMois(report.debut)} au ${Fmt.jourMois(report.fin)} '
                  'et donne-moi trois objectifs concrets pour la suivante.',
            ),
          ),
        ],
      ),
    );
  }
}
