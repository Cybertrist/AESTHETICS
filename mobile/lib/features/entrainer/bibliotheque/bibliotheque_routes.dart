import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/ui/ui.dart';
import '../routines/widgets/sous_page.dart';
import 'logic/exercise_index.dart';
import 'pages/exercise_actions.dart';
import 'pages/exercise_detail_page.dart';
import 'pages/exercise_edit_page.dart';
import 'pages/library_page.dart';
import 'pages/muscles_page.dart';
import 'pages/records_historique_page.dart';

/// Filtres de départ lus dans l'adresse : `?onglet=favoris|perso|recents|effectues`,
/// `&muscle=pectoraux,triceps`, `&q=texte`, `&materiel=barre`.
LibraryFilters _filtres(GoRouterState s) {
  final q = s.uri.queryParameters;
  final muscles = (q['muscle'] ?? '').split(',').map(Muscle.tryParse).whereType<Muscle>().toSet();
  final materiel = (q['materiel'] ?? '').split(',').where((e) => e.isNotEmpty).toSet();
  return LibraryFilters(
    query: q['q'] ?? '',
    scope: LibraryScope.values.firstWhere((e) => e.name == q['onglet'], orElse: () => LibraryScope.tous),
    muscles: muscles,
    principauxSeulement: muscles.isNotEmpty,
    equipements: materiel,
  );
}

/// Sous-routes de `/entrainer` pour la bibliothèque (chemins relatifs).
/// La bibliothèque et la fiche s'ouvrent en plein écran par-dessus la barre
/// des onglets ; l'explorateur de muscles reste dans l'onglet.
List<RouteBase> bibliothequeSubRoutes() => [
      GoRoute(
        path: 'muscles',
        builder: (context, state) => MusclesPage(
          key: ValueKey(state.uri.toString()),
          initial: Muscle.tryParse(state.uri.queryParameters['muscle']),
        ),
      ),
      GoRoute(
        path: 'exercices',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ExerciseLibraryPage(
          key: ValueKey(state.uri.toString()),
          initial: _filtres(state),
          title: state.uri.queryParameters['onglet'] == 'perso' ? 'Mes exercices' : 'Exercices',
        ),
        routes: [
          GoRoute(
            path: 'nouveau',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => ExerciseEditPage(initialName: state.uri.queryParameters['nom'] ?? ''),
          ),
          GoRoute(
            path: ':id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => ExerciseDetailPage(
              key: ValueKey(state.uri.toString()),
              exerciseId: state.pathParameters['id']!,
              initialTab: FicheTab.parse(state.uri.queryParameters['onglet']),
            ),
            routes: [
              GoRoute(
                path: 'records',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => RecordsHistoriquePage(exerciseId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'modifier',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => _EditRoute(id: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
    ];

/// Modification par adresse : seuls les exercices perso se modifient ; pour
/// un exercice du catalogue, on propose d'en faire une variante perso.
class _EditRoute extends StatelessWidget {
  const _EditRoute({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ExerciseRepo>();
    final e = repo.byId(id);
    if (!repo.loaded) return const SousPage(title: 'Modifier', body: SkeletonList(count: 5));
    if (e == null) {
      return SousPage(
        title: 'Modifier',
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Exercice introuvable',
          actionLabel: 'Retour',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }
    if (e.perso) return ExerciseEditPage(existing: e);
    return SousPage(
      title: e.nom,
      body: EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Exercice du catalogue',
        message: 'Il ne se modifie pas, mais tu peux en créer une variante perso à ton goût.',
        actionLabel: 'Créer une variante perso',
        onAction: () async {
          final copie = await ExerciseActions.dupliquer(context, e);
          if (context.mounted) context.pushReplacement('${Paths.entrainer}/exercices/${copie.id}/modifier');
        },
        secondaryLabel: 'Retour',
        onSecondary: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
