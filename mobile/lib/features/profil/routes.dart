import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../app/navigation.dart';
import '../../core/models/models.dart';
import 'data/mensurations.dart';
import 'mensurations/historique_page.dart';
import 'mensurations/mensurations_page.dart';
import 'mensurations/mesure_page.dart';
import 'mensurations/saisie_page.dart';
import 'pages/grades_page.dart';
import 'pages/profil_page.dart';
import 'pages/reglages/dev_page.dart';
import 'pages/reglages/disques_page.dart';
import 'pages/reglages/effacer_page.dart';
import 'pages/reglages/sauvegardes_page.dart';
import 'pages/reglages_page.dart';
import 'photos/comparer_page.dart';
import 'photos/photos_page.dart';

/// Chemins du module, pour les autres modules aussi.
abstract final class ProfilPaths {
  /// Mensurations : le corps et ses huit mesures.
  static const mensurations = '/profil/mensurations';

  /// Historique des saisies.
  static const historique = '/profil/mensurations/historique';

  /// Photos de progression.
  static const photos = '/profil/photos';

  /// Écrans du module Progrès ouverts depuis le profil.
  static const grades = '/profil/grades';
  static const records = '/progres/records';
  static const calendrier = '/progres/calendrier';

  /// Une mesure : sa courbe et ses saisies.
  static String zone(ZoneMesure z) => '$mensurations/zone/${z.name}';

  /// Nouvelle saisie, ou correction de la saisie [id].
  static String saisie({String? id, ZoneMesure? zone}) => Uri(
        path: '$mensurations/saisie',
        queryParameters: id == null && zone == null ? null : {'id': ?id, 'zone': ?zone?.name},
      ).toString();

  /// Une photo en grand.
  static String photo(String id) => '$photos/voir/$id';

  /// Comparer deux photos d'un angle.
  static String comparer({PhotoVue? vue, String? avant, String? apres}) => Uri(
        path: '$photos/comparer',
        queryParameters: vue == null && avant == null && apres == null ? null : {'vue': ?vue?.name, 'avant': ?avant, 'apres': ?apres},
      ).toString();
}

/// Routes du module profil : `/profil` (racine de l'onglet), ses sous-pages
/// en plein écran, et `/reglages...`.
List<RouteBase> profilRoutes() => [
      GoRoute(
        path: Paths.profil,
        builder: (context, state) => const ProfilPage(),
        routes: [
          // L'édition du profil réutilise les pages de l'inscription.
          GoRoute(
            path: 'modifier',
            redirect: (context, state) {
              final etape = switch (state.uri.queryParameters['section']) {
                'identite' => '/prenom',
                'corps' => '/taille',
                'objectif' => '/objectif',
                'entrainement' => '/frequence',
                'materiel' => '/materiel',
                _ => '',
              };
              return '${Paths.bienvenue}/modifier$etape';
            },
          ),
          // Les sous-pages s'ouvrent par-dessus la barre des onglets.
          GoRoute(
            path: 'mensurations',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const MensurationsPage(),
            routes: [
              GoRoute(
                path: 'historique',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const HistoriquePage(),
              ),
              GoRoute(
                path: 'saisie',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => SaisiePage(
                  key: ValueKey(state.uri.toString()),
                  id: state.uri.queryParameters['id'],
                  zone: ZoneMesure.parNom(state.uri.queryParameters['zone']),
                ),
              ),
              GoRoute(
                path: 'zone/:zone',
                parentNavigatorKey: rootNavigatorKey,
                redirect: (context, state) => ZoneMesure.parNom(state.pathParameters['zone']) == null ? ProfilPaths.mensurations : null,
                builder: (context, state) => MesurePage(zone: ZoneMesure.parNom(state.pathParameters['zone']) ?? ZoneMesure.biceps),
              ),
            ],
          ),
          GoRoute(
            path: 'grades',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const GradesPage(),
          ),
          GoRoute(
            path: 'photos',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const PhotosPage(),
            routes: [
              GoRoute(
                path: 'comparer',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => ComparerPhotosPage(
                  // Un autre lien (autres photos) repart d'un écran neuf.
                  key: ValueKey(state.uri.toString()),
                  vue: PhotoVue.values.asNameMap()[state.uri.queryParameters['vue']],
                  avantId: state.uri.queryParameters['avant'],
                  apresId: state.uri.queryParameters['apres'],
                ),
              ),
              GoRoute(
                path: 'voir/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => PhotoPage(id: state.pathParameters['id'] ?? ''),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Paths.reglages,
        builder: (context, state) => const ReglagesPage(),
        routes: [
          for (final s in ReglagesSection.values)
            GoRoute(
              path: s.slug,
              builder: (context, state) => ReglagesSectionPage(section: s),
              routes: [
                if (s == ReglagesSection.entrainement)
                  GoRoute(path: 'disques', builder: (context, state) => const DisquesPage()),
                if (s == ReglagesSection.donnees) ...[
                  GoRoute(path: 'sauvegardes', builder: (context, state) => const SauvegardesPage()),
                  GoRoute(path: 'effacer', builder: (context, state) => const EffacerPage()),
                ],
              ],
            ),
          GoRoute(
            path: 'dev',
            builder: (context, state) => const DevPage(),
            routes: [
              GoRoute(
                path: 'collection/:nom',
                builder: (context, state) => DevCollectionPage(nom: state.pathParameters['nom'] ?? ''),
              ),
            ],
          ),
        ],
      ),
    ];
