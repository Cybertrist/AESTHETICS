import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/data/app_data.dart';
import '../core/ui/app_bottom_nav.dart';
import '../core/ui/app_scaffold.dart';
import '../core/ui/feedback.dart';
import '../features/aujourdhui/routes.dart';
import '../features/coach/routes.dart';
import '../features/entrainer/routes.dart';
import '../features/import/routes.dart';
import '../features/inscription/routes.dart';
import '../features/nutrition/routes.dart';
import '../features/profil/routes.dart';
import '../features/progres/routes.dart';
import '../features/sante/routes.dart';
import '../features/seance/routes.dart';
import 'coquille_appli.dart';
import 'dev/composants_page.dart';
import 'navigation.dart';
import 'shell.dart';

/// Chemins accessibles sans profil : l'inscription, l'import (proposé à
/// l'inscription) et la page cachée des composants.
bool _libreSansProfil(String loc) =>
    loc.startsWith(Paths.bienvenue) || loc.startsWith(Paths.import) || loc.startsWith('/dev');

List<RouteBase> _routesOnglet(AppTab tab) => switch (tab) {
      AppTab.aujourdhui => aujourdhuiRoutes(),
      AppTab.entrainer => entrainerRoutes(),
      AppTab.coach => coachRoutes(),
      AppTab.nutrition => nutritionRoutes(),
      AppTab.progres => progresRoutes(),
      // L'onglet ne porte que /profil et ses sous-pages ; les réglages
      // restent en plein écran (voir plus bas).
      AppTab.profil => profilRoutes().where(_estProfil).toList(),
    };

bool _estProfil(RouteBase r) => r is GoRoute && r.path == Paths.profil;

GoRouter createRouter(AppData data) => GoRouter(
      navigatorKey: appNavigatorKey,
      initialLocation: Paths.aujourdhui,
      refreshListenable: data.profile,
      // Adresse inconnue (lien périmé, faute de frappe) : une page de l'appli,
      // pas l'écran d'erreur en anglais du routeur.
      errorBuilder: (context, state) => const PageIntrouvable(),
      redirect: (context, state) {
        if (!data.profile.hasProfile && !_libreSansProfil(state.matchedLocation)) {
          return Paths.bienvenue;
        }
        return null;
      },
      routes: [
        // Tout vit dans la coquille de l'appli : son navigateur porte les pages
        // plein écran, et la barre de la séance en cours reste dessous.
        ShellRoute(
          navigatorKey: rootNavigatorKey,
          builder: (context, state, child) => CoquilleAppli(child: child),
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, shell) => AppShell(shell: shell),
              branches: [
                for (final tab in AppTab.visibles)
                  StatefulShellBranch(observers: [ObservateurRetourOrigine()], routes: _routesOnglet(tab)),
              ],
            ),
            // Modules sans onglet pour l'instant : leurs pages restent joignables.
            for (final tab in AppTab.values)
              if (!AppTab.visibles.contains(tab)) ..._routesOnglet(tab),
            ...inscriptionRoutes(),
            ...seanceRoutes(),
            ...santeRoutes(),
            ...profilRoutes().where((r) => !_estProfil(r)),
            ...importRoutes(),
            GoRoute(
              path: Paths.composants,
              builder: (context, state) => const ComposantsPage(),
            ),
          ],
        ),
      ],
    );

/// Page d'une adresse inconnue : un mot et le chemin de l'accueil.
class PageIntrouvable extends StatelessWidget {
  const PageIntrouvable({super.key});

  @override
  Widget build(BuildContext context) => SubPageScaffold(
        title: 'Page introuvable',
        onBack: () => context.go(Paths.aujourdhui),
        body: EmptyState(
          icon: Icons.help_outline_rounded,
          title: 'Cette page n\'existe pas',
          message: 'Le lien est peut-être périmé.',
          actionLabel: 'Revenir à l\'accueil',
          onAction: () => context.go(Paths.aujourdhui),
        ),
      );
}

/// Bouton retour du téléphone. Le routeur ne sait que dépiler : à la racine
/// d'un onglet, ou sur une page ouverte seule (lien profond, fin de séance),
/// il rendait la main au système, qui fermait l'appli. Ici, quand il n'y a
/// plus rien à dépiler, on revient d'abord à l'accueil ; l'appli ne se ferme
/// que depuis l'accueil.
class RetourTelephone extends RootBackButtonDispatcher {
  RetourTelephone(this.router, this.data);

  final GoRouter router;
  final AppData data;

  @override
  Future<bool> didPopRoute() async {
    var traite = false;
    try {
      traite = await super.didPopRoute();
    } on StateError {
      // Page introuvable : la pile du routeur est vide.
    }
    if (traite) return true;
    // Sans profil, tout ramène à l'inscription : on laisse l'appli se fermer.
    if (!data.profile.hasProfile) return false;
    final ici = router.routerDelegate.currentConfiguration;
    if (ici.isNotEmpty && ici.uri.path == Paths.aujourdhui) return false;
    router.go(Paths.aujourdhui);
    return true;
  }
}
