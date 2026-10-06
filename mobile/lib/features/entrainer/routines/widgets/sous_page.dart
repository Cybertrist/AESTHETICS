import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../commun/elements.dart';

/// Page d'édition de l'onglet : l'en-tête commun (bouton rond gris, titre en
/// gras), le contenu, et une barre d'actions fixée en bas qui reste au-dessus
/// du clavier et de la barre de gestes du téléphone.
class SousPage extends StatelessWidget {
  const SousPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.bottomBar,
    this.maxContentWidth = Breakpoints.content,
    this.onBack,
    this.closeIcon = false,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottomBar;
  final double maxContentWidth;
  final VoidCallback? onBack;
  final bool closeIcon;

  @override
  Widget build(BuildContext context) => PageEntrainer(
        entete: EnTetePage(titre: title, sousTitre: subtitle, actions: actions, onBack: onBack, fermer: closeIcon, marge: AppTokens.gutter),
        largeur: maxContentWidth,
        filetBas: true,
        marge: AppTokens.gutter,
        bas: bottomBar,
        child: body,
      );
}
