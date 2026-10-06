import 'package:go_router/go_router.dart';

import 'accueil/entrainer_page.dart';
import 'bibliotheque/bibliotheque_routes.dart';
import 'routines/routines_routes.dart';

/// Routes de l'onglet Entraîner : la page racine à trois volets
/// (`?onglet=programmes|routines|exercices`), puis les routines et
/// programmes et la bibliothèque d'exercices.
List<RouteBase> entrainerRoutes() => [
      GoRoute(
        path: '/entrainer',
        builder: (context, state) => EntrainerPage(initial: VoletEntrainer.parse(state.uri.queryParameters['onglet'])),
        routes: [
          ...routinesSubRoutes(),
          ...bibliothequeSubRoutes(),
          // L'historique vit dans le module séance.
          GoRoute(
            path: 'historique',
            redirect: (context, state) {
              if (state.uri.path != '/entrainer/historique') return null;
              final id = state.uri.queryParameters['id'];
              return id == null ? '/seance/historique' : '/seance/historique/$id';
            },
            routes: [
              GoRoute(path: ':sessionId', redirect: (context, state) => '/seance/historique/${state.pathParameters['sessionId']}'),
            ],
          ),
        ],
      ),
    ];
