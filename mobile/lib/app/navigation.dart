import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigateur des pages plein écran : une route déclarée avec
/// `parentNavigatorKey: rootNavigatorKey` s'ouvre par-dessus la barre des
/// onglets. (Il vit dans la coquille de l'appli, qui garde la barre de la
/// séance en cours sous ces pages.)
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'racine');

/// Navigateur le plus haut : les boîtes de dialogue s'y ouvrent, par-dessus
/// tout le reste.
final appNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'appli');

/// Chemins racines des modules.
abstract final class Paths {
  static const bienvenue = '/bienvenue';
  static const aujourdhui = '/';
  static const entrainer = '/entrainer';
  static const seance = '/seance';
  static const coach = '/coach';
  static const nutrition = '/nutrition';
  static const sante = '/sante';
  static const progres = '/progres';
  static const profil = '/profil';
  static const reglages = '/reglages';
  static const import = '/import';
  static const composants = '/dev/composants';
}

/// Une sous-page d'un autre onglet ouverte depuis l'accueil (« Voir plus »,
/// « Historique ») : le retour doit rendre l'accueil, pas la racine de
/// l'onglet où vit la page.
abstract final class RetourOrigine {
  static String? _origine;

  /// Onglet auquel le prochain retour doit ramener, ou null.
  static String? get origine => _origine;

  /// Ouvre [chemin] (sous-page d'un autre onglet) en retenant d'où l'on vient.
  static void ouvrir(BuildContext context, String chemin, {String origine = Paths.aujourdhui}) {
    _origine = origine;
    context.go(chemin);
  }

  /// L'utilisateur a changé d'onglet lui-même : plus rien à rendre.
  static void oublier() => _origine = null;
}

/// À poser sur le navigateur de chaque onglet : quand la sous-page ouverte
/// par [RetourOrigine.ouvrir] se referme (flèche de la page ou bouton retour
/// du téléphone), on revient à l'onglet d'origine.
class ObservateurRetourOrigine extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final origine = RetourOrigine.origine;
    if (origine == null || previousRoute == null || !previousRoute.isFirst) return;
    RetourOrigine.oublier();
    final contexte = navigator?.context;
    if (contexte == null) return;
    // Une image plus tard : le routeur a retiré la page et l'onglet a retenu
    // qu'il est revenu à sa racine (sinon la page y resterait en mémoire).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (contexte.mounted) GoRouter.of(contexte).go(origine);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
