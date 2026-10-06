import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../logic/coach_engine.dart';
import '../logic/coach_snapshot.dart';
import '../logic/offline_coach.dart';
import '../widgets/coach_cards.dart';
import 'chat_page.dart';

/// Conseils calculés sur le téléphone : récupération, régularité, progression, nutrition, sommeil.
class ConseilsPage extends StatefulWidget {
  const ConseilsPage({super.key});

  @override
  State<ConseilsPage> createState() => _ConseilsPageState();
}

class _ConseilsPageState extends State<ConseilsPage> {
  ThemeConseil? _filtre;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<SessionRepo>();
    context.watch<NutritionRepo>();
    context.watch<HealthRepo>();
    final key = CoachEngine.cle(context.watch<SettingsRepo>().settings);
    final s = CoachSnapshot.read(context);
    final all = OfflineCoach.advices(s);
    final themes = {for (final a in all) a.theme}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final list = _filtre == null ? all : all.where((a) => a.theme == _filtre).toList();
    final aVoir = list.where((a) => !a.positif).toList();
    final bien = list.where((a) => a.positif).toList();

    Widget groupe(String label, List<CoachAdvice> items) => TileGroup(
          label: label,
          labelTrailing: LabelCount('${items.length}'),
          children: [
            for (final a in items)
              AdviceTile(
                advice: a,
                expanded: true,
                onAsk: a.question == null ? null : () => openCoachChat(context, question: a.question),
              ),
          ],
        );

    final fatigue = s.fatigue;
    final recup = s.sessions.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
            child: AppCard(
              label: 'Récupération estimée',
              labelTrailing: LabelCount(fatigue.values.any((v) => v >= 0.55) ? 'en rouge : encore fatigué' : 'tout est récupéré'),
              child: Column(
                children: [
                  BodyMapDual(height: 240, labels: true, intensities: fatigue),
                  const SizedBox(height: 10),
                  Text(
                    'Plus le rouge est vif, plus le muscle a travaillé récemment. Calcul fait sur tes séances des quatre derniers jours.',
                    textAlign: TextAlign.center,
                    style: AppType.rowSubtitle().copyWith(fontSize: 12.5, color: c.text3),
                  ),
                ],
              ),
            ),
          );

    return SubPageScaffold(
      title: 'Conseils du moment',
      subtitle: 'Calculés sur ton téléphone',
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          if (themes.length > 1) ...[
            ChipFilterBar<ThemeConseil>(
              options: [for (final t in themes) (t, t.label)],
              selected: {?_filtre},
              allLabel: 'Tous',
              onChanged: (v) => setState(() => _filtre = v.isEmpty ? null : v.first),
            ),
            const SizedBox(height: 14),
          ],
          if (_filtre == null || _filtre == ThemeConseil.recuperation) ...[?recup, if (recup != null) const SizedBox(height: 14)],
          if (all.isEmpty)
            const EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Rien à signaler',
              message: 'Ta récupération, ta régularité et ta nutrition sont au vert.',
              compact: true,
            ),
          if (aVoir.isNotEmpty) groupe('À voir', aVoir),
          if (aVoir.isNotEmpty && bien.isNotEmpty) const SizedBox(height: 14),
          if (bien.isNotEmpty) groupe('Ce qui va bien', bien),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
            child: key == null
                ? const OfflineBanner()
                : AppCard(
                    child: Row(
                      children: [
                        IconHalo.domain(AppDomain.coach, size: 40),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Ces règles tournent sans connexion. Pour un avis complet, pose ta question au coach.',
                            style: AppType.rowSubtitle(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PillButton.link(label: 'Demander', size: PillSize.small, onPressed: () => openCoachChat(context)),
                      ],
                    ),
                  ),
          ),
          if (s.vide) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
              child: PillButton.secondary(
                label: 'Importer mon historique',
                icon: Icons.upload_file_rounded,
                expand: true,
                onPressed: () => context.push('/import'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
