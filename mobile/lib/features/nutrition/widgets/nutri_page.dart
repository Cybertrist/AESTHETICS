import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';

/// `SubPageScaffold` dont la barre d'actions est posée sous le contenu,
/// en attendant le correctif du noyau (la `bottomBar` y prend toute la
/// hauteur, voir COORDINATION.md).
class NutriSubPage extends StatelessWidget {
  const NutriSubPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.bottomBar,
    this.closeIcon = false,
    this.haloColor,
    this.maxContentWidth = Breakpoints.content,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottomBar;
  final bool closeIcon;
  final Color? haloColor;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bar = bottomBar;
    return SubPageScaffold(
      title: title,
      subtitle: subtitle,
      actions: actions,
      closeIcon: closeIcon,
      haloColor: haloColor,
      maxContentWidth: maxContentWidth,
      body: bar == null
          ? body
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: body),
                DecoratedBox(
                  decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
                  child: Padding(padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 10, AppTokens.gutter, 10), child: bar),
                ),
              ],
            ),
    );
  }
}
