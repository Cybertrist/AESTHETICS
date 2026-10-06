import 'package:go_router/go_router.dart';

import 'pages/apercu_page.dart';
import 'pages/detail_page.dart';
import 'pages/equivalent_page.dart';
import 'pages/partager_page.dart';
import 'pages/disques_page.dart';
import 'pages/historique_page.dart';
import 'pages/lanceur_page.dart';
import 'pages/modifier_page.dart';
import 'pages/reordonner_page.dart';
import 'pages/repos_page.dart';
import 'pages/resume_page.dart';
import 'pages/seance_page.dart';
import 'pages/terminer_page.dart';

export 'seance_paths.dart';
export 'widgets/mini_barre.dart' show SeanceMiniBarre;

/// Routes du module séance, toutes en plein écran (au-dessus des onglets).
/// Chemins listés dans [SeancePaths].
List<RouteBase> seanceRoutes() => [
      GoRoute(path: '/seance', builder: (context, state) => const SeancePage()),
      GoRoute(path: '/seance/vide', builder: (context, state) => const LanceurPage(type: TypeLancement.vide)),
      GoRoute(
        path: '/seance/routine/:id',
        builder: (context, state) => LanceurPage(
          type: TypeLancement.routine,
          id: state.pathParameters['id'],
          programId: state.uri.queryParameters['programme'],
        ),
      ),
      GoRoute(
        path: '/seance/refaire/:id',
        builder: (context, state) => LanceurPage(type: TypeLancement.refaire, id: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/seance/apercu/:id',
        builder: (context, state) => ApercuPage(
          routineId: state.pathParameters['id']!,
          programId: state.uri.queryParameters['programme'],
        ),
      ),
      GoRoute(path: '/seance/repos', builder: (context, state) => const ReposPage()),
      GoRoute(path: '/seance/reordonner', builder: (context, state) => const ReordonnerRoute()),
      GoRoute(
        path: '/seance/disques',
        builder: (context, state) => DisquesPage(
          poidsKg: double.tryParse(state.uri.queryParameters['poids'] ?? ''),
          seId: state.uri.queryParameters['exercice'],
        ),
      ),
      GoRoute(path: '/seance/terminer', builder: (context, state) => const TerminerPage()),
      GoRoute(
        path: '/seance/resume/:id',
        builder: (context, state) => ResumePage(
          sessionId: state.pathParameters['id']!,
          nouveau: state.uri.queryParameters['nouveau'] == '1',
        ),
      ),
      GoRoute(
        path: '/seance/equivalent/:id',
        builder: (context, state) => EquivalentPage(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/seance/partager/:id',
        builder: (context, state) => PartagerPage(
          sessionId: state.pathParameters['id']!,
          carte: int.tryParse(state.uri.queryParameters['carte'] ?? '') ?? 0,
        ),
      ),
      GoRoute(path: '/seance/historique', builder: (context, state) => const HistoriquePage()),
      GoRoute(
        path: '/seance/historique/:id',
        builder: (context, state) => DetailPage(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/seance/historique/:id/modifier',
        builder: (context, state) => ModifierPage(sessionId: state.pathParameters['id']!),
      ),
    ];
