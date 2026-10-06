import 'package:go_router/go_router.dart';

import 'inscription_controller.dart';
import 'pages/edit_pages.dart';
import 'pages/flow_page.dart';
import 'pages/program_page.dart';
import 'pages/routine_preview_page.dart';
import 'pages/welcome_page.dart';

/// Routes du module inscription.
/// - `/bienvenue` : accueil de première ouverture.
/// - `/bienvenue/profil` : parcours des 15 étapes (brouillon sauvé à chaque réponse).
/// - `/bienvenue/programme` : programme conseillé (`?premier=1` juste après l'inscription),
///   `/bienvenue/programme/seance/:i` une séance, `.../exercice/:j` remplacer, `.../exercice/ajouter`.
/// - `/bienvenue/modifier` : toutes les réponses depuis le profil ; `/bienvenue/modifier/:etape` une étape.
List<RouteBase> inscriptionRoutes() => [
      GoRoute(
        path: '/bienvenue',
        builder: (context, state) => const WelcomePage(),
        routes: [
          GoRoute(path: 'profil', builder: (context, state) => const FlowPage()),
          GoRoute(
            path: 'programme',
            builder: (context, state) => ProgramPage(premier: state.uri.queryParameters['premier'] == '1'),
            routes: [
              GoRoute(
                path: 'seance/:i',
                builder: (context, state) => RoutinePreviewPage(index: int.tryParse(state.pathParameters['i'] ?? '') ?? -1),
                routes: [
                  GoRoute(
                    path: 'exercice/:j',
                    builder: (context, state) {
                      final j = state.pathParameters['j'];
                      return ExercicePickerPage(
                        index: int.tryParse(state.pathParameters['i'] ?? '') ?? -1,
                        position: j == 'ajouter' ? null : int.tryParse(j ?? ''),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'modifier',
            builder: (context, state) => const EditHubPage(),
            routes: [
              GoRoute(
                path: ':etape',
                builder: (context, state) => EditStepPage(etape: Etape.fromSlug(state.pathParameters['etape'])),
              ),
            ],
          ),
        ],
      ),
    ];
