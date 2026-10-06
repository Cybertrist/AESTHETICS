import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/coach_prompt.dart';
import '../logic/coach_snapshot.dart';
import '../widgets/coach_scope.dart';

/// Le résumé exact des données envoyé au coach avec chaque question.
class ContextPage extends StatelessWidget {
  const ContextPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<SessionRepo>();
    context.watch<NutritionRepo>();
    context.watch<HealthRepo>();
    context.watch<ProfileRepo>();
    return CoachListen(builder: (context, prefs, engine) {
      final texte = CoachContext.build(CoachSnapshot.read(context), prefs);
      // Environ 3,6 caractères par jeton en français.
      final jetons = (texte.length / 3.6).round();
      return SubPageScaffold(
        title: 'Ce que voit le coach',
        subtitle: 'Environ ${Fmt.n(jetons, decimals: 0)} jetons',
        actions: [
          IconButton(
            tooltip: 'Copier',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: texte));
              if (context.mounted) Toasts.success(context, 'Résumé copié.');
            },
            icon: Icon(Icons.copy_rounded, color: c.text),
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 32),
          children: [
            Text(
              'Voici, mot pour mot, le résumé de tes données joint à chaque question, avec les consignes du coach. '
              'Il est recalculé à chaque envoi.',
              style: AppType.rowSubtitle(),
            ),
            const SizedBox(height: 14),
            AppCard(
              color: c.surface2,
              border: true,
              child: SelectableText(
                texte,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.5, color: c.text2),
              ),
            ),
            const SizedBox(height: 18),
            PillButton.secondary(
              label: 'Choisir les données partagées',
              icon: Icons.shield_rounded,
              chevron: true,
              expand: true,
              onPressed: () => context.push('/coach/reglages/donnees'),
            ),
          ],
        ),
      );
    });
  }
}
