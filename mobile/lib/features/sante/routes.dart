import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import 'activite/activite_page.dart';
import 'common/sante_calculs.dart';
import 'complements/complement_form_page.dart';
import 'complements/complements_page.dart';
import 'connexion/connexion_page.dart';
import 'corps/comparer_page.dart';
import 'corps/corps_page.dart';
import 'corps/mesure_form_page.dart';
import 'corps/mesures_pages.dart';
import 'corps/photos_pages.dart';
import 'recuperation/muscle_page.dart';
import 'recuperation/recuperation_page.dart';
import 'sante_page.dart';
import 'sommeil/nuit_form_page.dart';
import 'sommeil/nuit_page.dart';
import 'sommeil/sommeil_page.dart';

/// Routes du module Santé (plein écran, hors onglets).
List<RouteBase> santeRoutes() => [
      GoRoute(
        path: '/sante',
        builder: (context, state) => const SantePage(),
        routes: [
          GoRoute(path: 'connexion', builder: (context, state) => const ConnexionPage()),
          // Sommeil
          GoRoute(
            path: 'sommeil',
            builder: (context, state) => const SommeilPage(),
            routes: [
              GoRoute(path: 'ajouter', builder: (context, state) => const NuitFormPage()),
              GoRoute(path: 'historique', builder: (context, state) => const SommeilHistoriquePage()),
              GoRoute(
                path: 'nuit/:id',
                builder: (context, state) => NuitPage(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(path: 'modifier', builder: (context, state) => NuitFormPage(id: state.pathParameters['id'])),
                ],
              ),
            ],
          ),
          // Corps
          GoRoute(
            path: 'corps',
            builder: (context, state) => const CorpsPage(),
            routes: [
              GoRoute(
                path: 'mesure',
                builder: (context, state) => MesureFormPage(
                  id: state.uri.queryParameters['id'],
                  focusTours: state.uri.queryParameters['tours'] == '1',
                ),
              ),
              GoRoute(path: 'mesures', builder: (context, state) => const MesuresPage()),
              GoRoute(path: 'mensurations', builder: (context, state) => const MensurationsPage()),
              GoRoute(
                path: 'tour/:groupe',
                builder: (context, state) => TourPage(
                  groupe: GroupeTour.values.asNameMap()[state.pathParameters['groupe']] ?? GroupeTour.bras,
                ),
              ),
              GoRoute(
                path: 'photos',
                builder: (context, state) => const PhotosPage(),
                routes: [
                  GoRoute(path: ':id', builder: (context, state) => PhotoPage(id: state.pathParameters['id']!)),
                ],
              ),
              GoRoute(
                path: 'comparer',
                builder: (context, state) => ComparerPage(
                  avantId: state.uri.queryParameters['avant'],
                  apresId: state.uri.queryParameters['apres'],
                  vue: PhotoVue.values.asNameMap()[state.uri.queryParameters['vue']],
                ),
              ),
            ],
          ),
          // Récupération
          GoRoute(
            path: 'recuperation',
            builder: (context, state) => const RecuperationPage(),
            routes: [
              GoRoute(
                path: ':muscle',
                redirect: (context, state) =>
                    Muscle.values.asNameMap().containsKey(state.pathParameters['muscle']) ? null : '/sante/recuperation',
                builder: (context, state) => MusclePage(muscle: Muscle.values.byName(state.pathParameters['muscle']!)),
              ),
            ],
          ),
          // Activité
          GoRoute(path: 'activite', builder: (context, state) => const ActivitePage()),
          // Compléments
          GoRoute(
            path: 'complements',
            builder: (context, state) => const ComplementsPage(),
            routes: [
              GoRoute(
                path: 'ajouter',
                builder: (context, state) => ComplementFormPage(modele: state.uri.queryParameters['modele']),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => ComplementPage(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(path: 'modifier', builder: (context, state) => ComplementFormPage(id: state.pathParameters['id'])),
                ],
              ),
            ],
          ),
        ],
      ),
    ];
