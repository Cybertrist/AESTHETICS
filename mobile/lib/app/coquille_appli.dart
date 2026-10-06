import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/data/data.dart';
import '../core/theme/app_colors.dart';
import '../features/seance/routes.dart' show SeanceMiniBarre;
import 'navigation.dart';

/// Vrai si la barre « Entraînement en cours » a sa place sous la page plein
/// écran [chemin]. Elle n'a rien à faire sur les écrans de la séance
/// elle-même (saisie, repos, fin, partage), sur l'inscription ni sur le
/// bilan du mois, qui occupe tout l'écran.
bool barreSeanceSurPage(String chemin) {
  if (chemin.startsWith(Paths.bienvenue)) return false;
  if (chemin.startsWith('${Paths.progres}/bilan')) return false;
  if (chemin == Paths.seance || chemin.startsWith('${Paths.seance}/')) {
    // Les séances passées ne sont pas la séance en cours.
    return chemin.startsWith('${Paths.seance}/historique');
  }
  return true;
}

/// Coquille de toute l'appli : les pages, et sous les pages plein écran
/// (réglages, mensurations, fiche d'exercice...) la barre de la séance en
/// cours. Sous les onglets, c'est `AppShell` qui la montre.
class CoquilleAppli extends StatelessWidget {
  const CoquilleAppli({super.key, required this.child});

  /// Le navigateur des pages.
  final Widget child;

  /// Adresses des pages plein écran empilées, de la plus ancienne à celle du
  /// dessus ; null quand les onglets sont au premier plan.
  static List<String>? pagesPleinEcran(RouteMatchList configuration) {
    if (configuration.matches.isEmpty) return null;
    var niveau = configuration.matches;
    // La coquille de l'appli enveloppe tout : on regarde dedans.
    final racine = niveau.last;
    if (racine is ShellRouteMatch && racine.route is! StatefulShellRoute) niveau = racine.matches;
    if (niveau.isEmpty || niveau.last is ShellRouteMatch) return null;
    return [
      for (final m in niveau)
        if (m is ImperativeRouteMatch)
          m.matches.uri.path
        else if (m is RouteMatch)
          m.matchedLocation,
    ];
  }

  /// Vrai si la barre doit se montrer pour cette pile de pages.
  static bool barreVisible(List<String>? pages) =>
      pages != null && pages.isNotEmpty && pages.every(barreSeanceSurPage);

  @override
  Widget build(BuildContext context) {
    final enCours = context.select<SessionRepo, bool>((r) => r.hasActive);
    if (!enCours) return child;
    final delegue = GoRouter.of(context).routerDelegate;
    return ListenableBuilder(
      listenable: delegue,
      child: child,
      builder: (context, pages) {
        // Clavier ouvert : la page a besoin de toute la hauteur.
        final clavier = MediaQuery.viewInsetsOf(context).bottom > 0;
        final montrer = !clavier && barreVisible(pagesPleinEcran(delegue.currentConfiguration));
        return Column(
          children: [
            Expanded(
              child: montrer
                  // La barre occupe le bas : la page n'a plus à s'écarter de
                  // la zone des gestes.
                  ? MediaQuery.removePadding(context: context, removeBottom: true, child: pages!)
                  : pages!,
            ),
            if (montrer)
              Material(
                color: context.colors.bg,
                child: const SafeArea(
                  top: false,
                  child: SeanceMiniBarre(padding: EdgeInsets.fromLTRB(12, 8, 12, 8)),
                ),
              ),
          ],
        );
      },
    );
  }
}
