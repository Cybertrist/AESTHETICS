import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';

/// Contenu avec une barre d'actions fixée en bas (au-dessus du clavier).
/// Remplace `SubPageScaffold(bottomBar:)` tant que celle-ci prend toute la
/// hauteur de l'écran (demande faite à la fondation).
class AvecBarre extends StatelessWidget {
  const AvecBarre({super.key, required this.body, required this.bar});

  final Widget body;
  final Widget? bar;

  @override
  Widget build(BuildContext context) {
    if (bar == null) return body;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        DecoratedBox(
          decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 10, AppTokens.gutter, 10),
              child: bar,
            ),
          ),
        ),
      ],
    );
  }
}
