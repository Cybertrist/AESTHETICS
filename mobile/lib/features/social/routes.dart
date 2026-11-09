import 'package:go_router/go_router.dart';

import 'pages/ami_page.dart';
import 'pages/communaute_page.dart';
import 'pages/espace_coach_page.dart';
import 'pages/publication_page.dart';
import 'pages/trouver_page.dart';

/// Chemins de la communauté : mes amis, mon profil public, mon coach. Le
/// fil des séances des amis est sur l'accueil.
abstract final class SocialPaths {
  static const racine = '/communaute';

  static const coach = '$racine/coach';
  static const ajouter = '$racine/ajouter';
  static const contacts = '$racine/contacts';
  static const amis = '$racine/amis';
  static const lien = '$racine/lien';
  static const scanner = '$lien/scanner';

  /// Mon profil comme les autres le voient, ce que j'y écris, et les
  /// réglages de ce qu'il montre.
  static const monProfil = '$racine/mon-profil';
  static const modifierProfil = '$racine/modifier-profil';
  static const confidentialite = '$racine/profil-public';
  static const espaceCoach = '$racine/espace-coach';
  static String ami(String id) => '$racine/ami/$id';

  /// La séance d'un ami et ses commentaires.
  static String publication(String id) => '$racine/seance/$id';
  static String eleve(String id) => '$espaceCoach/$id';
}

/// Les pages de la communauté, en plein écran par-dessus les onglets.
List<RouteBase> socialRoutes() => [
      GoRoute(
        path: SocialPaths.racine,
        builder: (context, state) => const CommunautePage(),
        routes: [
          GoRoute(path: 'ajouter', builder: (context, state) => const AjouterAmiPage()),
          GoRoute(path: 'contacts', builder: (context, state) => const ContactsPage()),
          GoRoute(path: 'amis', builder: (context, state) => const MesAmisPage()),
          GoRoute(
            path: 'lien',
            builder: (context, state) => const LienPage(),
            routes: [GoRoute(path: 'scanner', builder: (context, state) => const ScannerAmiPage())],
          ),
          GoRoute(path: 'coach', builder: (context, state) => const CoachPage()),
          GoRoute(path: 'mon-profil', builder: (context, state) => const MonProfilPublicPage()),
          GoRoute(path: 'modifier-profil', builder: (context, state) => const ModifierProfilPage()),
          GoRoute(path: 'profil-public', builder: (context, state) => const ConfidentialitePage()),
          GoRoute(path: 'seance/:id', builder: (context, state) => PublicationPage(id: state.pathParameters['id']!)),
          GoRoute(path: 'ami/:id', builder: (context, state) => AmiPage(id: state.pathParameters['id']!)),
          GoRoute(
            path: 'espace-coach',
            builder: (context, state) => const EspaceCoachPage(),
            routes: [
              GoRoute(path: ':id', builder: (context, state) => ElevePage(id: state.pathParameters['id']!)),
            ],
          ),
        ],
      ),
    ];
