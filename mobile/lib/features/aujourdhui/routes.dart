import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import 'pages/aujourdhui_page.dart';
import 'pages/nutrition_jour_page.dart';
import 'pages/pas_page.dart';
import 'pages/poids_page.dart';
import 'pages/records_page.dart';
import 'pages/recuperation_page.dart';
import 'pages/seance_detail_page.dart';
import 'pages/seance_du_jour_page.dart';
import 'pages/semaine_page.dart';
import 'pages/serie_page.dart';
import 'pages/sommeil_page.dart';

/// Chemins du module Aujourd'hui (sous l'onglet d'accueil, barre du bas visible).
abstract final class AujourdhuiPaths {
  static const base = '/aujourdhui';
  static const seanceDuJour = '$base/seance-du-jour';
  static const recuperation = '$base/recuperation';
  static String muscle(Muscle m) => '$recuperation/${m.name}';
  static const nutrition = '$base/nutrition';
  static const sommeil = '$base/sommeil';
  static const pas = '$base/pas';
  static const poids = '$base/poids';
  static const semaine = '$base/semaine';
  static const records = '$base/records';

  /// La flamme : semaines d'affilée et calendrier de la série.
  static const serie = '$base/serie';
  static String seanceDetail(String id) => '$base/seance/$id';

  // Chemins annoncés par le module Entraîner (voir COORDINATION).
  static String ficheExercice(String id) => '/entrainer/exercices/$id';
  static const nouvelleRoutine = '/entrainer/routines/nouvelle';
  static String routine(String id) => '/entrainer/routines/$id';
  static const programmes = '/entrainer/programmes';
  static const entrainer = '/entrainer';

  // Chemins du module Séance (plein écran).
  static String bilanSeance(String id) => '/seance/resume/$id';
  static String refaireSeance(String id) => '/seance/refaire/$id';
  static String modifierSeance(String id) => '/seance/historique/$id/modifier';

  // Chemins du module Progrès. Le bilan est en plein écran : l'ouvrir par
  // `context.push`, la croix rend alors la main à l'accueil. [mois] au
  // format « 2026-9 ».
  static String bilanMois(String mois) => '/progres/bilan?mois=$mois';

  /// La flamme : la page « série de semaines » du bilan du mois en cours.
  static String bilanSerie(DateTime jour) => '/progres/bilan?mois=${jour.year}-${jour.month}&page=serie';
  static const calendrier = '/progres/calendrier';

  /// « Voir plus » de la carte de la semaine : le bilan de la semaine, dans
  /// l'onglet Progrès (`context.go`).
  static const bilanSemaine = '/progres/semaine';
}

/// Routes du module Aujourd'hui.
List<RouteBase> aujourdhuiRoutes() => [
      GoRoute(
        path: '/',
        builder: (context, state) => const AujourdhuiPage(),
        routes: [
          GoRoute(path: 'aujourdhui/seance-du-jour', builder: (context, state) => const SeanceDuJourPage()),
          GoRoute(
            path: 'aujourdhui/recuperation',
            builder: (context, state) => const RecuperationPage(),
            routes: [
              GoRoute(
                path: ':muscle',
                builder: (context, state) {
                  final m = Muscle.values.where((m) => m.name == state.pathParameters['muscle']).firstOrNull;
                  return m == null ? const RecuperationPage() : MuscleRecuperationPage(muscle: m);
                },
              ),
            ],
          ),
          GoRoute(path: 'aujourdhui/nutrition', builder: (context, state) => const NutritionJourPage()),
          GoRoute(path: 'aujourdhui/sommeil', builder: (context, state) => const SommeilPage()),
          GoRoute(path: 'aujourdhui/pas', builder: (context, state) => const PasPage()),
          GoRoute(path: 'aujourdhui/poids', builder: (context, state) => const PoidsPage()),
          GoRoute(path: 'aujourdhui/semaine', builder: (context, state) => const SemainePage()),
          GoRoute(path: 'aujourdhui/records', builder: (context, state) => const RecordsPage()),
          GoRoute(path: 'aujourdhui/serie', builder: (context, state) => const SeriePage()),
          GoRoute(
            path: 'aujourdhui/seance/:id',
            builder: (context, state) => SeanceDetailPage(sessionId: state.pathParameters['id'] ?? ''),
          ),
        ],
      ),
    ];
