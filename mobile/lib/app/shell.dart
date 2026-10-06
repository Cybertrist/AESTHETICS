import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/ui/app_bottom_nav.dart';
import '../core/ui/responsive.dart';
import '../features/seance/routes.dart' show SeanceMiniBarre;
import 'navigation.dart';

/// Coquille des onglets : barre du bas sur écran étroit, rail latéral
/// sur écran large, et bandeau de la séance en cours au-dessus.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int i) {
    // Changement d'onglet voulu : le retour ne ramène plus à l'onglet d'avant.
    RetourOrigine.oublier();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Séance réduite, au-dessus de la barre des onglets.
    const banner = SeanceMiniBarre(padding: EdgeInsets.fromLTRB(12, 0, 12, 8));
    if (context.isExpanded) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Row(
          children: [
            AppNavRail(
              currentIndex: shell.currentIndex,
              onTap: _go,
              onAvatarTap: () => _go(AppTab.profil.rang),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: shell),
                  banner,
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: c.bg,
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          banner,
          AppBottomNav(currentIndex: shell.currentIndex, onTap: _go),
        ],
      ),
    );
  }
}
