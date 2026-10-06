import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/coach_engine.dart';
import '../logic/coach_snapshot.dart';
import '../logic/offline_coach.dart';
import '../widgets/coach_cards.dart';
import '../widgets/coach_scope.dart';
import 'chat_page.dart';

/// Onglet central : poser une question, phrase du jour, bilan, conseils et conversations.
class CoachHomePage extends StatefulWidget {
  const CoachHomePage({super.key});

  @override
  State<CoachHomePage> createState() => _CoachHomePageState();
}

class _CoachHomePageState extends State<CoachHomePage> {
  final _question = TextEditingController();

  @override
  void initState() {
    super.initState();
    _question.addListener(() => setState(() {}));
    // Le dimanche, le bilan se rédige tout seul si la clé est là.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.coachPrefs.ready();
      if (!mounted) return;
      context.coachEngine.bilanAuto(snapshot: CoachSnapshot.read(context), settings: context.read<SettingsRepo>().settings);
    });
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _ask([String? q]) {
    final t = (q ?? _question.text).trim();
    if (t.isEmpty) return;
    _question.clear();
    FocusScope.of(context).unfocus();
    openCoachChat(context, question: t);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = context.watch<SettingsRepo>().settings;
    final repo = context.watch<CoachRepo>();
    context.watch<SessionRepo>();
    context.watch<NutritionRepo>();
    context.watch<HealthRepo>();
    final key = CoachEngine.cle(settings);
    final snapshot = CoachSnapshot.read(context);
    final advices = OfflineCoach.advices(snapshot);
    final conversations = repo.conversations;
    final prenom = snapshot.prenom;

    final ask = AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            prenom.isEmpty ? 'Qu\'est-ce que je peux faire pour toi ?' : 'Salut $prenom, on parle de quoi ?',
            style: AppType.rowTitle().copyWith(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            key == null
                ? 'Réponses calculées sur ton téléphone à partir de tes données.'
                : 'Je connais tes séances, tes repas, tes nuits et ta récupération.',
            style: AppType.rowSubtitle(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _question,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _ask(),
                  decoration: InputDecoration(
                    hintText: 'Pose ta question…',
                    filled: true,
                    fillColor: c.surface3,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    border: const OutlineInputBorder(borderRadius: AppTokens.radius26, borderSide: BorderSide.none),
                    enabledBorder: const OutlineInputBorder(borderRadius: AppTokens.radius26, borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: AppTokens.radius26, borderSide: BorderSide(color: c.accentBorder)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RoundIconButton(
                icon: Icons.arrow_upward_rounded,
                tooltip: 'Envoyer',
                size: 48,
                onPressed: _question.text.trim().isEmpty ? null : _ask,
              ),
            ],
          ),
        ],
      ),
    );

    final suggestions = SuggestionChips(
      questions: OfflineCoach.suggestions(snapshot),
      onTap: _ask,
      padding: EdgeInsets.zero,
    );

    final conseils = advices.isEmpty
        ? AppCard(
            label: 'Conseils du moment',
            child: Text('Rien à signaler : tout est au vert.', style: AppType.rowSubtitle()),
          )
        : TileGroup(
            margin: EdgeInsets.zero,
            label: 'Conseils du moment',
            labelTrailing: AccentLink(label: 'Tout voir', onTap: () => context.push('/coach/conseils')),
            children: [
              for (final a in advices.take(3))
                AdviceTile(
                  advice: a,
                  onAsk: a.question == null ? () => context.push('/coach/conseils') : () => _ask(a.question),
                ),
            ],
          );

    final historique = conversations.isEmpty
        ? AppCard(
            label: 'Conversations',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aucune conversation pour l\'instant. Tes échanges avec le coach seront gardés ici.', style: AppType.rowSubtitle()),
                const SizedBox(height: 12),
                PillButton.secondary(
                  label: 'Nouvelle conversation',
                  icon: Icons.add_rounded,
                  size: PillSize.small,
                  onPressed: () => openCoachChat(context),
                ),
              ],
            ),
          )
        : TileGroup(
            margin: EdgeInsets.zero,
            label: 'Conversations',
            labelTrailing: AccentLink(label: 'Historique', onTap: () => context.push('/coach/historique')),
            children: [
              for (final conv in conversations.take(4))
                ListTileX(
                  leading: IconHalo(
                    icon: conv.epinglee ? Icons.push_pin_rounded : Icons.chat_bubble_rounded,
                    color: AppTokens.domainCoach,
                    size: 40,
                  ),
                  title: conv.titre,
                  subtitle: '${Fmt.relatif(conv.derniereActivite)}, ${Fmt.pluriel(conv.messages.length, 'message')}',
                  showChevron: true,
                  onTap: () => openCoachChat(context, id: conv.id),
                ),
              ListTileX(
                leading: IconHalo(icon: Icons.add_rounded, size: 40),
                title: 'Nouvelle conversation',
                onTap: () => openCoachChat(context),
              ),
            ],
          );

    const gap = SizedBox(height: 14);
    final left = <Widget>[
      if (key == null) ...[const OfflineBanner(), gap],
      ask,
      const SizedBox(height: 12),
      suggestions,
      const SizedBox(height: 18),
      const CoachDailyCard(showRefresh: true, onTap: null),
      gap,
      const CoachWeekCard(),
    ];
    final right = <Widget>[conseils, gap, historique];

    return AppScaffold(
      title: 'Coach',
      eyebrow: key == null ? 'Hors ligne' : 'Ton coach personnel',
      maxContentWidth: context.isExpanded ? 1180 : Breakpoints.content,
      actions: [
        IconButton(
          tooltip: 'Historique',
          onPressed: () => context.push('/coach/historique'),
          icon: Icon(Icons.history_rounded, color: c.text),
        ),
        IconButton(
          tooltip: 'Réglages du coach',
          onPressed: () => context.push('/coach/reglages'),
          icon: Icon(Icons.tune_rounded, color: c.text),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 0),
        child: context.isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
                ],
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...left, const SizedBox(height: 18), ...right]),
      ),
    );
  }
}
