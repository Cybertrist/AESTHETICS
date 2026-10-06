import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/coach_engine.dart';
import '../logic/coach_snapshot.dart';
import '../logic/offline_coach.dart';
import '../logic/week_report.dart';
import 'coach_scope.dart';

/// Phrase du jour du coach. Carte autonome, utilisable sur l'écran d'accueil :
/// `const CoachDailyCard()`. Un toucher ouvre le coach.
class CoachDailyCard extends StatelessWidget {
  const CoachDailyCard({super.key, this.onTap, this.showRefresh = false});

  /// Par défaut, ouvre l'onglet Coach.
  final VoidCallback? onTap;

  /// Bouton pour demander une nouvelle phrase au coach en ligne.
  final bool showRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Les données qui nourrissent la phrase.
    context.watch<SessionRepo>();
    context.watch<NutritionRepo>();
    context.watch<HealthRepo>();
    final settings = context.watch<SettingsRepo>().settings;
    return CoachListen(builder: (context, prefs, engine) {
      final snapshot = CoachSnapshot.read(context);
      final phrase = engine.phraseDuJour(snapshot: snapshot, settings: settings);
      final ia = CoachEngine.cle(settings) != null && prefs.phraseIa;
      final parIa = prefs.phraseDate == CoachEngine.jourCle(snapshot.now) && prefs.phraseParIa;
      return AppCard(
        onTap: onTap ?? () => context.go('/coach'),
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconHalo.domain(AppDomain.coach, icon: Icons.format_quote_rounded, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PHRASE DU JOUR', style: AppType.overline(color: c.text3)),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: AppTokens.normal,
                    child: Text(
                      phrase,
                      key: ValueKey(phrase),
                      style: AppType.rowTitle().copyWith(fontSize: 16.5, fontWeight: FontWeight.w700, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (engine.phraseEnCours) ...[
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: c.text3)),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          engine.phraseEnCours
                              ? 'Le coach rédige la phrase du jour…'
                              : parIa
                                  ? 'Rédigée par le coach à partir de tes données'
                                  : 'Calculée sur ton téléphone',
                          style: AppType.rowSubtitle().copyWith(fontSize: 12.5, color: c.text3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showRefresh && ia)
              IconButton(
                tooltip: 'Nouvelle phrase',
                onPressed: engine.phraseEnCours
                    ? null
                    : () => engine.phraseDuJour(snapshot: snapshot, settings: settings, rafraichir: true),
                icon: Icon(Icons.refresh_rounded, color: c.text2, size: 20),
              ),
          ],
        ),
      );
    });
  }
}

/// Bilan de la semaine en une carte (à mettre en avant le dimanche).
class CoachWeekCard extends StatelessWidget {
  const CoachWeekCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<SessionRepo>();
    return CoachListen(builder: (context, prefs, engine) {
      final s = CoachSnapshot.read(context);
      final report = WeekReport.build(s, s.now);
      final dimanche = s.now.weekday == DateTime.sunday;
      final redige = prefs.bilans.containsKey(report.cle);
      final enCours = engine.bilanEnCours(report.cle);
      return AppCard(
        onTap: () => context.push('/coach/bilan'),
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: Row(
          children: [
            IconHalo.domain(AppDomain.coach, icon: Icons.insights_rounded, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dimanche ? (redige ? 'Ton bilan de la semaine est prêt' : 'C\'est dimanche : l\'heure du bilan') : 'Bilan de la semaine',
                    style: AppType.rowTitle().copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    enCours
                        ? 'Le coach rédige ton bilan…'
                        : '${report.sessions.length} sur ${report.objectifSeances} séances, ${report.records.length} record${report.records.length > 1 ? 's' : ''}',
                    style: AppType.rowSubtitle(),
                  ),
                ],
              ),
            ),
            if (enCours)
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
            else
              Icon(Icons.chevron_right_rounded, color: c.text3),
          ],
        ),
      );
    });
  }
}

/// Bandeau du mode hors ligne : invitation claire à ajouter une clé.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      border: true,
      borderColor: c.accentBorder,
      color: c.accentFaint,
      padding: EdgeInsets.fromLTRB(16, compact ? 12 : 16, 16, compact ? 12 : 16),
      child: Row(
        crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          IconHalo(icon: Icons.cloud_off_rounded, size: compact ? 34 : 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode hors ligne', style: AppType.rowTitle().copyWith(fontWeight: FontWeight.w800)),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tes conseils sont calculés sur le téléphone. Ajoute une clé API pour discuter vraiment avec le coach, '
                    'générer des routines et recevoir des bilans rédigés.',
                    style: AppType.rowSubtitle(),
                  ),
                  const SizedBox(height: 12),
                  PillButton(
                    label: 'Ajouter une clé',
                    icon: Icons.key_rounded,
                    size: PillSize.small,
                    onPressed: () => context.push('/coach/reglages/cle'),
                  ),
                ] else
                  Text('Réponses calculées sur le téléphone', style: AppType.rowSubtitle().copyWith(fontSize: 13)),
              ],
            ),
          ),
          if (compact)
            PillButton.link(label: 'Clé', size: PillSize.small, onPressed: () => context.push('/coach/reglages/cle')),
        ],
      ),
    );
  }
}

/// Ligne d'un conseil hors ligne.
class AdviceTile extends StatelessWidget {
  const AdviceTile({super.key, required this.advice, this.onAsk, this.expanded = false});

  final CoachAdvice advice;
  final VoidCallback? onAsk;

  /// Texte complet et bouton « Demander au coach ».
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!expanded) {
      return ListTileX(
        leading: IconHalo.domain(advice.domain, icon: advice.icon, size: 40),
        title: advice.titre,
        subtitle: advice.texte,
        subtitleMaxLines: 2,
        onTap: onAsk,
        showChevron: onAsk != null,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconHalo.domain(advice.domain, icon: advice.icon, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(advice.titre, style: AppType.rowTitle().copyWith(fontWeight: FontWeight.w700))),
                    if (advice.positif) Icon(Icons.thumb_up_alt_rounded, size: 16, color: c.accent),
                  ],
                ),
                const SizedBox(height: 4),
                Text(advice.texte, style: AppType.rowSubtitle().copyWith(height: 1.45)),
                if (onAsk != null && advice.question != null) ...[
                  const SizedBox(height: 10),
                  PillButton.link(label: 'Demander au coach', size: PillSize.small, onPressed: onAsk),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggestions de questions en puces qui défilent.
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({super.key, required this.questions, required this.onTap, this.wrap = false, this.padding});

  final List<String> questions;
  final ValueChanged<String> onTap;

  /// Sur plusieurs lignes plutôt qu'en défilement horizontal.
  final bool wrap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final q in questions)
        ActionChip(
          label: Text(q),
          avatar: Icon(Icons.auto_awesome_rounded, size: 16, color: context.colors.accent),
          onPressed: () => onTap(q),
        ),
    ];
    if (wrap) {
      return Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      );
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}
