import 'package:go_router/go_router.dart';

import '../../app/navigation.dart';
import 'screens/accueil_page.dart';
import 'screens/aide_page.dart';
import 'screens/apercu_details.dart';
import 'screens/apercu_page.dart';
import 'screens/choisir_exercice_page.dart';
import 'screens/colonnes_page.dart';
import 'screens/exercices_page.dart';
import 'screens/export_page.dart';
import 'screens/fichier_page.dart';
import 'screens/journal_page.dart';
import 'screens/nouvel_exercice_page.dart';
import 'screens/options_page.dart';
import 'screens/progression_page.dart';
import 'screens/resume_page.dart';
import 'screens/sauvegarde_page.dart';

/// Routes du module import / export (plein écran, hors onglets).
List<RouteBase> importRoutes() => [
      GoRoute(
        path: Paths.import,
        builder: (context, state) => ImportAccueilPage(retour: state.uri.queryParameters['retour']),
        routes: [
          GoRoute(path: 'fichier', builder: (context, state) => const FichierPage()),
          GoRoute(
            path: 'aide',
            builder: (context, state) => AidePage(depuisFichier: state.uri.queryParameters['depuis'] == 'fichier'),
          ),
          GoRoute(
            path: 'apercu',
            builder: (context, state) => const ApercuPage(),
            routes: [
              GoRoute(
                path: 'seances',
                builder: (context, state) => const SeancesLuesPage(),
                routes: [
                  GoRoute(
                    path: ':index',
                    builder: (context, state) => SeanceLuePage(index: int.tryParse(state.pathParameters['index'] ?? '') ?? -1),
                  ),
                ],
              ),
              GoRoute(path: 'messages', builder: (context, state) => const MessagesPage()),
            ],
          ),
          GoRoute(
            path: 'colonnes',
            builder: (context, state) => ColonnesPage(depuisApercu: state.uri.queryParameters['depuis'] == 'apercu'),
          ),
          GoRoute(
            path: 'exercices',
            builder: (context, state) => const ExercicesPage(),
            routes: [
              GoRoute(
                path: 'choisir',
                builder: (context, state) => ChoisirExercicePage(nomSource: state.uri.queryParameters['nom'] ?? ''),
              ),
              GoRoute(
                path: 'nouveau',
                builder: (context, state) => NouvelExercicePage(nomSource: state.uri.queryParameters['nom'] ?? ''),
              ),
            ],
          ),
          GoRoute(path: 'options', builder: (context, state) => const OptionsPage()),
          GoRoute(path: 'progression', builder: (context, state) => const ProgressionPage()),
          GoRoute(
            path: 'resume',
            builder: (context, state) => const ResumePage(),
            routes: [
              GoRoute(path: 'records', builder: (context, state) => const RecordsImportPage()),
            ],
          ),
          GoRoute(path: 'export', builder: (context, state) => const ExportPage()),
          GoRoute(
            path: 'sauvegarde',
            builder: (context, state) => const SauvegardePage(),
            routes: [
              GoRoute(path: 'restaurer', builder: (context, state) => const RestaurerPage()),
            ],
          ),
          GoRoute(
            path: 'journal',
            builder: (context, state) => const JournalPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => JournalDetailPage(id: state.pathParameters['id'] ?? ''),
              ),
            ],
          ),
        ],
      ),
    ];
