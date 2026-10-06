import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../data/coach_prefs.dart';
import '../logic/coach_engine.dart';

extension CoachContextX on BuildContext {
  CoachPrefsController get coachPrefs => CoachPrefsController.of(read<Store>());
  CoachEngine get coachEngine => CoachEngine.of(read<Store>());
}

/// Reconstruit quand les réglages du coach ou le moteur changent.
class CoachListen extends StatelessWidget {
  const CoachListen({super.key, required this.builder});

  final Widget Function(BuildContext context, CoachPrefs prefs, CoachEngine engine) builder;

  @override
  Widget build(BuildContext context) {
    final prefs = context.coachPrefs;
    final engine = context.coachEngine;
    return ListenableBuilder(
      listenable: Listenable.merge([prefs, engine]),
      builder: (context, _) => builder(context, prefs.prefs, engine),
    );
  }
}

/// Barre d'actions fixée sous le contenu d'une sous-page (au-dessus du clavier).
class CoachBottomBar extends StatelessWidget {
  const CoachBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 10, AppTokens.gutter, 10), child: child),
      ),
    );
  }
}
