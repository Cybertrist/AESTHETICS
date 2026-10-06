import 'package:go_router/go_router.dart';

import '../../app/navigation.dart';
import 'pages/api_key_page.dart';
import 'pages/bilan_page.dart';
import 'pages/chat_page.dart';
import 'pages/coach_home_page.dart';
import 'pages/conseils_page.dart';
import 'pages/context_page.dart';
import 'pages/history_page.dart';
import 'pages/model_page.dart';
import 'pages/settings_page.dart';
import 'pages/shared_data_page.dart';

/// Routes du module coach (onglet central).
///
/// - `/coach` : accueil du coach (question, suggestions, phrase du jour, bilan, conseils, conversations)
/// - `/coach/discussion/:id` : conversation (`nouvelle`, avec `?q=` pour poser une question tout de suite)
/// - `/coach/historique` : toutes les conversations
/// - `/coach/bilan` : bilan de la semaine (`?semaine=aaaa-mm-jj`)
/// - `/coach/conseils` : conseils calculés sur le téléphone
/// - `/coach/reglages` (+ `/cle`, `/modele`, `/donnees`, `/contexte`) : réglages du coach
List<RouteBase> coachRoutes() => [
      GoRoute(
        path: '/coach',
        builder: (context, state) => const CoachHomePage(),
        routes: [
          GoRoute(
            path: 'discussion/:id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ChatPage(
                conversationId: id == 'nouvelle' ? null : id,
                question: state.uri.queryParameters['q'],
              );
            },
          ),
          GoRoute(path: 'historique', builder: (context, state) => const HistoryPage()),
          GoRoute(
            path: 'bilan',
            builder: (context, state) => BilanPage(semaine: DateTime.tryParse(state.uri.queryParameters['semaine'] ?? '')),
          ),
          GoRoute(path: 'conseils', builder: (context, state) => const ConseilsPage()),
          GoRoute(
            path: 'reglages',
            builder: (context, state) => const CoachSettingsPage(),
            routes: [
              GoRoute(path: 'cle', builder: (context, state) => const ApiKeyPage()),
              GoRoute(path: 'modele', builder: (context, state) => const ModelPage()),
              GoRoute(path: 'donnees', builder: (context, state) => const SharedDataPage()),
              GoRoute(path: 'contexte', builder: (context, state) => const ContextPage()),
            ],
          ),
        ],
      ),
    ];
