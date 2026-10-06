import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/navigation.dart';
import '../../core/models/models.dart';

import '../sante/recuperation/recuperation_page.dart';
import '../sante/recuperation/tous_muscles_page.dart';
import 'logic/tableau.dart';
import 'ui/bilan/bilan_story_page.dart';
import 'ui/calendrier_page.dart';
import 'ui/communs.dart';
import 'ui/comparer_page.dart';
import 'ui/exercice_page.dart';
import 'ui/mois_page.dart';
import 'ui/muscles_page.dart';
import 'ui/progres_page.dart';
import 'ui/records_page.dart';
import 'ui/seance_resume_page.dart';
import 'ui/semaine_page.dart';

/// « 2026-10-02 » en date ; null si ce n'en est pas une.
DateTime? _jour(String? s) => s == null ? null : DateTime.tryParse(s);

/// Routes du module Progrès. Les chemins sont dans `progres_paths.dart`.
///
/// Tout s'affiche dans l'onglet (barre du bas visible), sauf le bilan du
/// mois, en plein écran par-dessus la barre.
List<RouteBase> progresRoutes() => [
      GoRoute(
        path: '/progres',
        builder: (context, state) => const ProgresPage(),
        routes: [
          GoRoute(
            path: 'semaine',
            builder: (context, state) => SemainePage(jour: _jour(state.uri.queryParameters['jour'])),
          ),
          GoRoute(
            path: 'mois',
            builder: (context, state) => MoisPage(mois: Calculs.lireMois(state.uri.queryParameters['mois'])),
          ),
          GoRoute(
            path: 'calendrier',
            builder: (context, state) => CalendrierPage(
              mois: Calculs.lireMois(state.uri.queryParameters['mois']),
              jour: _jour(state.uri.queryParameters['jour']),
            ),
          ),
          GoRoute(
            path: 'recuperation',
            builder: (context, state) => const RecuperationPage(),
            routes: [
              GoRoute(path: 'muscles', builder: (context, state) => const TousLesMusclesPage()),
            ],
          ),
          GoRoute(
            path: 'bilan',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => BilanStoryPage(
              mois: Calculs.lireMois(state.uri.queryParameters['mois']),
              annee: int.tryParse(state.uri.queryParameters['annee'] ?? ''),
              pageInitiale: PageBilan.values.asNameMap()[state.uri.queryParameters['page']] ?? PageBilan.ouverture,
            ),
          ),
          GoRoute(path: 'records', builder: (context, state) => const RecordsPage()),
          GoRoute(
            path: 'exercices',
            builder: (context, state) => const ChoixExercicePage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => ExerciceProgresPage(exerciseId: state.pathParameters['id'] ?? ''),
              ),
            ],
          ),
          GoRoute(
            path: 'seance/:id',
            builder: (context, state) => SeanceResumePage(sessionId: state.pathParameters['id'] ?? ''),
          ),
          // Pages d'analyse plus anciennes, gardées joignables.
          GoRoute(
            path: 'muscles',
            builder: (context, state) => const MusclesPage(),
            routes: [
              GoRoute(
                path: ':muscle',
                builder: (context, state) {
                  final m = Muscle.tryParse(state.pathParameters['muscle']);
                  return m == null ? const _Introuvable() : MuscleDetailPage(muscle: m);
                },
              ),
            ],
          ),
          GoRoute(path: 'comparer', builder: (context, state) => const ComparerPage()),
        ],
      ),
    ];

class _Introuvable extends StatelessWidget {
  const _Introuvable();

  @override
  Widget build(BuildContext context) => PageProgres(
        child: ListView(
          children: [
            const EnTetePage(titre: 'Muscle inconnu'),
            EtatVide(
              titre: 'Ce muscle n\'existe pas',
              action: 'Voir tous les muscles',
              onAction: () => context.go('/progres/muscles'),
            ),
          ],
        ),
      );
}
