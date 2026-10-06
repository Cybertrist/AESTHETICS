import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../seance/seance_paths.dart';
import 'pages/favoris_page.dart';
import 'pages/idees_page.dart';
import 'pages/program_editor_page.dart';
import 'pages/programme_page.dart';
import 'pages/routine_editor_page.dart';

/// Sous-routes relatives de `/entrainer` : routines et programmes.
/// Les listes vivent dans les volets de l'onglet ; les anciennes adresses
/// de liste y renvoient. Les éditeurs et la page d'un programme s'ouvrent
/// en plein écran par-dessus la barre des onglets.
List<RouteBase> routinesSubRoutes() => [
      GoRoute(
        path: 'routines',
        redirect: (context, state) => state.uri.path == '/entrainer/routines' ? '/entrainer?onglet=routines' : null,
        routes: [
          GoRoute(
            path: 'nouvelle',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => RoutineEditorPage(
              folderId: state.uri.queryParameters['dossier'],
              retour: state.uri.queryParameters['retour'] == '1',
            ),
          ),
          GoRoute(path: 'favoris', builder: (context, state) => const FavorisPage()),
          GoRoute(
            path: ':id',
            // Une routine s'ouvre sur « Lancer la séance », du module séance.
            redirect: (context, state) => state.uri.path == '/entrainer/routines/${state.pathParameters['id']}'
                ? SeancePaths.apercu(state.pathParameters['id']!, programId: state.uri.queryParameters['programme'])
                : null,
            routes: [
              GoRoute(
                path: 'modifier',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => RoutineEditorPage(routineId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: 'dossiers/:id', redirect: (context, state) => '/entrainer?onglet=routines'),
      GoRoute(
        path: 'programmes',
        redirect: (context, state) => state.uri.path == '/entrainer/programmes' ? '/entrainer?onglet=programmes' : null,
        routes: [
          GoRoute(path: 'idees', builder: (context, state) => const IdeesPage()),
          GoRoute(
            path: 'modele/:modeleId',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => ModelePage(modeleId: state.pathParameters['modeleId']!),
          ),
          GoRoute(
            path: 'nouveau',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const ProgramEditorPage(),
          ),
          GoRoute(
            path: ':id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => ProgrammePage(programId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'modifier',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => ProgramEditorPage(programId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
    ];
