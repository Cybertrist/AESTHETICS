import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/pages/exercise_browser.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:aesthetic/features/entrainer/commun/carte_jour.dart';
import 'package:aesthetic/features/entrainer/commun/elements.dart' show Medaille, PuceAction;
import 'package:aesthetic/features/entrainer/commun/palette.dart';
import 'package:aesthetic/features/entrainer/routines/logic/suggestion.dart';
import 'package:aesthetic/features/entrainer/routines/logic/vignettes.dart';
import 'package:aesthetic/features/entrainer/routines/widgets/couverture.dart';
import 'package:aesthetic/features/entrainer/routines/widgets/ligne_routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils.dart';

/// Rendus de l'onglet Entraîner, écran par écran, à comparer aux captures
/// 29 à 40 de la maquette. Images dans build/rendus/routines et
/// build/rendus/bibliotheque.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  final maintenant = DateTime.now();

  testWidgets('29 à 33 : programmes, idées, programme, actions, vignette', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer');

    // 29 : toujours la bibliothèque.
    expect(find.text('Entraînement'), findsWidgets);
    expect(find.text('Créer un programme'), findsOneWidget);
    expect(find.text('Favoris'), findsOneWidget);
    expect(find.text('0 routine'), findsOneWidget);
    expect(find.text('DT COACH Tristan V3'), findsOneWidget);
    expect(find.text('8 routines'), findsOneWidget);
    expect(find.text('9 routines'), findsNWidgets(2));
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('V3'), findsOneWidget);
    expect(find.text('Voir des idées de programmes'), findsOneWidget);
    // Le programme en cours vient en premier.
    expect(t.getTopLeft(find.text('DT COACH Tristan V3')).dy, lessThan(t.getTopLeft(find.text('DTCOACH Tristan V2')).dy));
    await capturer(t, 'routines', '29-programmes');

    // 30 : les idées.
    await t.tap(find.text('Voir des idées de programmes'));
    await attendre(t, 6);
    expect(find.text('Idées de programmes'), findsOneWidget);
    expect(find.text('Les classiques'), findsOneWidget);
    expect(find.text('Recommandé pour toi'), findsOneWidget);
    expect(find.text('FULL BODY'), findsOneWidget);
    expect(find.text('PUSH · PULL · LEGS'), findsOneWidget);
    expect(find.byType(CouvertureIdee), findsWidgets);
    expect(find.byType(AppBottomNav), findsOneWidget, reason: 'les idées restent dans l\'onglet');
    await capturer(t, 'routines', '30-idees');

    // La recherche remplace les rangées par une grille de résultats.
    await t.enterText(find.byType(TextField), 'maison');
    await attendre(t, 2);
    expect(find.text('À LA MAISON'), findsOneWidget);
    expect(find.text('FULL BODY'), findsNothing);
    await t.enterText(find.byType(TextField), '');
    await attendre(t, 2);

    // Une idée s'ouvre et s'ajoute à la bibliothèque.
    await t.tap(find.text('FULL BODY'));
    await attendre(t, 6);
    expect(find.text('Ajouter à ma bibliothèque'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Les séances'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Les séances'), findsOneWidget);
    await capturer(t, 'routines', '30-idee-detail');
    final avant = data.programs.programs.length;
    await t.tap(find.text('Ajouter à ma bibliothèque'));
    await attendre(t, 3);
    expect(find.textContaining('Le suivre maintenant', findRichText: true), findsOneWidget);
    await capturer(t, 'routines', '30-idee-ajout');
    await t.tap(find.textContaining('L’ajouter sans le suivre', findRichText: true));
    await t.pump();
    await t.tap(find.text('Ajouter à ma bibliothèque').last);
    await attendre(t, 6);
    expect(data.programs.programs.length, avant + 1);
    expect(data.programs.active?.id, 'p-v3', reason: 'ajouté sans le suivre : le programme en cours ne change pas');
    final ajoute = data.programs.programs.firstWhere((p) => p.nom == 'Full body 3 jours');
    expect(ajoute.routineIds, hasLength(3));
    expect(find.text('Ajouter une routine au programme'), findsOneWidget, reason: 'on arrive sur la page du programme');
    await data.programs.delete(ajoute.id);
    for (final id in ajoute.routineIds) {
      await data.routines.delete(id);
    }

    // 31 : le programme.
    routeur(t).go('/entrainer/programmes/p-v3');
    await attendre(t, 6);
    expect(find.text('VOIR PLUS'), findsOneWidget);
    expect(find.text('DT COACH'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Ajouter une routine au programme'), findsOneWidget);
    expect(find.text('PECS / TRICEPS'), findsOneWidget);
    expect(find.text('2 exercices'), findsOneWidget);
    expect(find.text('Il y a 3 jours'), findsOneWidget);
    expect(find.text('Avant-hier'), findsOneWidget);
    expect(find.text('Lun'), findsOneWidget);
    expect(find.text('Mar'), findsOneWidget);
    expect(find.byType(CarteJour), findsWidgets);
    expect(find.byType(AppBottomNav), findsNothing, reason: 'le programme s\'ouvre en plein écran');
    expect(t.getTopLeft(find.text('Ajouter une routine au programme')).dy, lessThan(t.getTopLeft(find.text('PECS / TRICEPS')).dy));
    await capturer(t, 'routines', '31-programme');

    await t.tap(find.text('VOIR PLUS'));
    await attendre(t, 2);
    expect(find.text('VOIR MOINS'), findsOneWidget);
    expect(find.text('Rythme'), findsOneWidget);
    await capturer(t, 'routines', '31-programme-voir-plus');
    await t.tap(find.text('VOIR MOINS'));
    await attendre(t, 2);

    // Lancer une routine ouvre « Lancer la séance » du module séance.
    await t.tap(find.bySemanticsLabel('Lancer PECS / TRICEPS'));
    await attendre(t, 3);
    expect(find.text('apercu r-pecs-triceps'), findsOneWidget);
    routeur(t).pop();
    await attendre(t, 3);

    // 32 : les actions sur une routine.
    await t.tap(find.bySemanticsLabel('Actions sur PECS / TRICEPS'));
    await attendre(t, 4);
    for (final a in ['Modifier', 'Changer l’image', 'Dupliquer', 'Déplacer dans un autre programme', 'Partager', 'Supprimer']) {
      expect(find.text(a), findsOneWidget, reason: a);
    }
    expect(find.byType(LigneAction), findsNWidgets(7));
    await capturer(t, 'routines', '32-actions');

    // Favori depuis le panneau.
    await t.tap(find.text('Ajouter aux favoris'));
    await attendre(t, 3);
    expect(RoutinePrefs.of(data.store).estFavori('r-pecs-triceps'), isTrue);

    // 33 : la vignette.
    await t.tap(find.bySemanticsLabel('Actions sur PECS / TRICEPS'));
    await attendre(t, 3);
    expect(find.text('Retirer des favoris'), findsOneWidget);
    await t.tap(find.text('Changer l’image'));
    await attendre(t, 4);
    expect(find.text('Vignette de la routine'), findsOneWidget);
    expect(find.text('JOURS DE LA SEMAINE'), findsOneWidget);
    expect(find.text('Choisir « Lun »'), findsOneWidget);
    for (final j in joursAbreges) {
      expect(find.descendant(of: find.byType(PanneauBas), matching: find.text(j)), findsOneWidget, reason: j);
    }
    expect(find.bySemanticsLabel('Choisir une photo'), findsOneWidget);
    await capturer(t, 'routines', '33-vignette');
    await t.tap(find.descendant(of: find.byType(PanneauBas), matching: find.text('Sam')));
    await t.pump();
    expect(find.text('Choisir « Sam »'), findsOneWidget);
    await t.tap(find.text('Choisir « Sam »'));
    await attendre(t, 3);
    expect(RoutinePrefs.of(data.store).vignetteDe('r-pecs-triceps')?.jour, 6);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Lun'), findsNothing);
    await RoutinePrefs.of(data.store).choisirJour('r-pecs-triceps', 1);

    // Favoris : la routine y est.
    routeur(t).go('/entrainer');
    await attendre(t, 3);
    expect(find.text('1 routine'), findsOneWidget);
    await t.tap(find.text('Favoris'));
    await attendre(t, 3);
    expect(find.byType(LigneRoutine), findsOneWidget);
    expect(find.text('PECS / TRICEPS'), findsOneWidget);
    await capturer(t, 'routines', '29-favoris');
  });

  testWidgets('34 et 35 : routines, avec puis sans suggestion', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer?onglet=routines');
    await attendre(t, 2);

    final s = suggererRoutine(maintenant: maintenant, seances: data.sessions.sessions)!;
    expect(s.routineId, 'r-pecs-epaules');
    expect(find.text(titreSuggestion(maintenant.weekday).toUpperCase()), findsOneWidget);
    expect(find.text('PECS / ÉPAULES', skipOffstage: false), findsNWidgets(2), reason: 'dans la carte et dans la liste');
    expect(find.text('DT COACH Tristan V3'), findsOneWidget);
    expect(find.textContaining(RegExp(r' · $')), findsNothing, reason: 'aucune ligne ne finit par un point médian');
    expect(find.text('7 exercices · ${_duree(data)}'), findsOneWidget);
    expect(find.text(raisonSuggestion(s)), findsOneWidget);
    expect(raisonSuggestion(s), startsWith('Tu as fait cette séance 6 des 8 derniers ${joursEntiers[maintenant.weekday - 1]}s. Dernière fois : le '));
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Une autre'), findsOneWidget);
    expect(find.text('Nouvel entraînement'), findsOneWidget);
    expect(find.text('TES ROUTINES'), findsOneWidget);
    await capturer(t, 'routines', '34-routines-suggestion');

    // Commencer ouvre « Lancer la séance » avec le programme.
    await t.tap(find.text('Commencer'));
    await attendre(t, 3);
    expect(find.text('apercu r-pecs-epaules'), findsOneWidget);
    routeur(t).pop();
    await attendre(t, 3);

    // Une autre : la routine suivante la plus plausible prend la place.
    final file = suggestionsRoutines(
      maintenant: maintenant,
      seances: data.sessions.sessions,
      routines: [for (final r in data.routines.routines) r.id],
      cycle: data.programs.active!.routineIds,
    );
    expect(file.first.routineId, 'r-pecs-epaules');
    await t.tap(find.text('Une autre'));
    await attendre(t, 3);
    final suivante = file[1];
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text(raisonSuggestion(suivante)), findsOneWidget);
    expect(find.text(data.routines.byId(suivante.routineId)!.nom, skipOffstage: false), findsNWidgets(2));
    expect(find.text(raisonSuggestion(s)), findsNothing);
    await capturer(t, 'routines', '34-routines-une-autre');

    // Jusqu'au bout de la file : une ligne le dit, le bloc ne disparaît pas sans un mot.
    for (var k = 1; k < file.length; k++) {
      await t.tap(find.text('Une autre'));
      await attendre(t, 2);
    }
    expect(find.text('Commencer'), findsNothing);
    expect(find.text('Une autre'), findsNothing);
    expect(find.text(plusDeSuggestion), findsOneWidget);
    expect(find.textContaining('SUGGÉRÉ'), findsNothing);
    expect(find.text('Nouvel entraînement'), findsOneWidget);
    expect(find.text('PECS / TRICEPS'), findsOneWidget);
    expect(find.text('CARDIO'), findsOneWidget);
    await capturer(t, 'routines', '35-routines-sans-suggestion');

    await t.tap(find.text('Nouvel entraînement'));
    await attendre(t, 3);
    expect(find.text('/seance/vide'), findsOneWidget);
  });

  testWidgets('pas de suggestion sans habitude nette, volets vides', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await lancer(t, data, '/entrainer?onglet=routines');
    expect(find.textContaining('SUGGÉRÉ'), findsNothing);
    expect(find.text('Nouvel entraînement'), findsOneWidget);
    expect(find.text('Créer une routine'), findsOneWidget);
    await capturer(t, 'routines', '35-routines-vide');
    await t.tap(find.text('Programmes'));
    await attendre(t, 2);
    expect(find.text('Créer un programme'), findsOneWidget);
    expect(find.text('Voir des idées de programmes'), findsOneWidget);
    await capturer(t, 'routines', '29-programmes-vide');
  });

  testWidgets('36 bis : tuiles Cardio et Étirements au bout de la rangée', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer?onglet=exercices', taille: const Size(380, 1345));
    await attendre(t, 8);
    // Les deux tuiles sont au bout de la rangée, après les muscles.
    await t.dragFrom(t.getCenter(find.text('Pecs')), const Offset(-2000, 0));
    await attendre(t, 2);
    expect(find.text('Cardio'), findsOneWidget);

    await t.tap(find.text('Cardio'));
    await attendre(t, 4);
    final cardio = t.widgetList<CarteExercice>(find.byType(CarteExercice)).map((c) => c.exercise).toList();
    expect(cardio, isNotEmpty);
    expect(cardio.every((e) => e.categorie == 'cardio'), isTrue);
    expect(find.bySemanticsLabel('Retirer le filtre Cardio'), findsNothing, reason: 'la tuile allumée suffit');
    await capturer(t, 'bibliotheque', '36-cardio');

    // Les étirements remplacent le cardio, un second appui retire le filtre.
    await t.tap(find.text('Étirements'));
    await attendre(t, 4);
    expect(t.widgetList<CarteExercice>(find.byType(CarteExercice)).every((c) => c.exercise.categorie == 'etirements'), isTrue);
    await capturer(t, 'bibliotheque', '36-etirements');
    await t.tap(find.text('Étirements'));
    await attendre(t, 4);
    expect(find.textContaining('Tous les exercices', findRichText: true), findsOneWidget);
  });

  testWidgets('36 ter : « Matériel », un panneau du bas où cocher plusieurs familles', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer?onglet=exercices', taille: const Size(412, 1100));
    await attendre(t, 6);
    // Les muscles se choisissent par les tuiles : plus de puce « Muscles ».
    expect(find.widgetWithText(PuceAction, 'Muscles'), findsNothing);
    await t.tap(find.text('Matériel'));
    await attendre(t, 8);
    expect(find.byType(FiltreMateriel), findsOneWidget);
    expect(find.text('Filtrer'), findsOneWidget);
    for (final x in ['Barre', 'Haltères', 'Poids du corps', 'Kettlebell', 'Poulie', 'Machine', 'Presse', 'Barre de traction', 'Mini-bande']) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
    expect(t.takeException(), isNull);
    await capturer(t, 'bibliotheque', '36-materiel');

    // Deux familles cochées : le bouton annonce le nombre, rien n'est appliqué
    // avant de valider.
    await t.tap(find.text('Kettlebell'));
    await t.tap(find.text('Barre EZ'));
    await attendre(t, 4);
    expect(find.byType(FiltreMateriel), findsOneWidget);
    expect(find.textContaining('Afficher '), findsOneWidget);
    expect(t.takeException(), isNull);
    await capturer(t, 'bibliotheque', '36-materiel-choix');
    await t.tap(find.textContaining('Afficher '));
    await attendre(t, 6);
    expect(find.byType(FiltreMateriel), findsNothing);
    final cartes = t.widgetList<CarteExercice>(find.byType(CarteExercice)).map((c) => c.exercise).toList();
    expect(cartes, isNotEmpty);
    expect(cartes.every((e) => e.equipement == 'kettlebell' || e.equipement == 'barre ez'), isTrue);

    // « Tout effacer » puis valider : toute la liste revient.
    await t.tap(find.text('Matériel'));
    await attendre(t, 8);
    await t.tap(find.text('Tout effacer'));
    await attendre(t, 2);
    await t.tap(find.textContaining('Afficher '));
    await attendre(t, 6);
    expect(find.textContaining('Tous les exercices', findRichText: true), findsOneWidget);
  });

  testWidgets('36 : bibliothèque en grille et ses filtres', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer?onglet=exercices', taille: const Size(380, 1345));
    await attendre(t, 8);
    expect(find.text('Rechercher un exercice'), findsOneWidget);
    for (final x in ['Favoris', 'Pecs', 'Abdos', 'Biceps', 'Récents', 'Effectués']) {
      expect(find.text(x), findsWidgets, reason: x);
    }
    // Tri par défaut : les plus faits d'abord, puis l'alphabet.
    expect(t.widget<CarteExercice>(find.byType(CarteExercice).first).exercise.id, 'developpe-militaire');
    expect(find.textContaining('Tous les exercices', findRichText: true), findsOneWidget);
    expect(find.textContaining('${data.exercises.all.length}', findRichText: true), findsOneWidget);
    expect(find.byType(CarteExercice), findsWidgets);
    expect(find.bySemanticsLabel('Trier'), findsOneWidget);
    expect(find.bySemanticsLabel('Afficher en liste'), findsOneWidget);
    expect(find.bySemanticsLabel('Créer un exercice'), findsOneWidget);
    await capturer(t, 'bibliotheque', '36-grille');

    // Recherche.
    await t.enterText(find.byType(TextField), 'developpe couche');
    await attendre(t, 3);
    expect(find.text('Développé couché'), findsWidgets);
    expect(find.textContaining('Résultats', findRichText: true), findsOneWidget);
    await capturer(t, 'bibliotheque', '36-recherche');
    // « dos » : les exercices du dos d'abord, pas le shrug « derrière le dos ».
    await t.enterText(find.byType(TextField), 'dos');
    await attendre(t, 3);
    expect(t.widget<CarteExercice>(find.byType(CarteExercice).first).exercise.nom, isNot(contains('Shrug')));
    await capturer(t, 'bibliotheque', 'chasse-recherche-dos');
    await t.enterText(find.byType(TextField), '');
    await attendre(t, 2);

    // Raccourci par muscle : la grille se limite au groupe.
    await t.tap(find.text('Biceps').first);
    await attendre(t, 3);
    final biceps = t.widgetList<CarteExercice>(find.byType(CarteExercice)).toList();
    expect(biceps, isNotEmpty);
    expect(biceps.every((c) => c.sousTitre.contains('Biceps')), isTrue);
    await capturer(t, 'bibliotheque', '36-raccourci-biceps');
    await t.tap(find.text('Biceps').first);
    await attendre(t, 2);

    // Raccourcis des jambes : vignettes resserrées sur le muscle.
    await t.drag(find.text('Biceps').first, const Offset(-420, 0));
    await attendre(t, 1);
    await t.drag(find.text('Avant-bras').first, const Offset(-420, 0));
    await attendre(t, 2);
    expect(find.text('Mollets'), findsOneWidget);
    await capturer(t, 'bibliotheque', '36-raccourcis-jambes');
    await t.drag(find.text('Mollets').first, const Offset(1200, 0));
    await attendre(t, 2);

    // Favori par le signet d'une carte, puis filtre Favoris.
    final premiere = t.widget<CarteExercice>(find.byType(CarteExercice).first).exercise;
    await t.tap(find.descendant(of: find.byType(CarteExercice).first, matching: find.byTooltip('Ajouter aux favoris')));
    await attendre(t, 2);
    expect(data.exercises.isFavori(premiere.id), isTrue);
    await t.tap(find.text('Favoris'));
    await attendre(t, 2);
    expect(find.byType(CarteExercice), findsOneWidget);
    await t.tap(find.text('Favoris').first);
    await attendre(t, 2);

    // Récents : seulement ce qui a été fait.
    await t.tap(find.text('Récents'));
    await attendre(t, 3);
    final recents = t.widgetList<CarteExercice>(find.byType(CarteExercice)).map((c) => c.exercise.id).toSet();
    expect(recents, contains('elevations-laterales'));
    expect(recents.length, lessThan(20));
    await t.tap(find.text('Récents').first);
    await attendre(t, 2);

    // Liste.
    await t.tap(find.bySemanticsLabel('Afficher en liste'));
    await attendre(t, 3);
    expect(find.byType(LigneExercice), findsWidgets);
    await capturer(t, 'bibliotheque', '36-liste');
    await t.tap(find.bySemanticsLabel('Afficher en grille'));
    await attendre(t, 2);

    // Trier : panneau du bas.
    await t.tap(find.bySemanticsLabel('Trier'));
    await attendre(t, 3);
    expect(find.text('Trier par'), findsOneWidget);
    expect(find.text('Les plus faits'), findsOneWidget);
    await capturer(t, 'bibliotheque', '36-trier');
    await t.tap(find.text('Les plus faits'));
    await attendre(t, 3);
    expect(t.widget<CarteExercice>(find.byType(CarteExercice).first).exercise.id, 'developpe-militaire');
    await capturer(t, 'bibliotheque', '36-plus-faits');
  });

  testWidgets('37 à 39 : la fiche et ses onglets', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer?onglet=exercices');
    await attendre(t, 2);
    await t.enterText(find.byType(TextField), 'elevations laterales');
    await attendre(t, 3);
    await t.tap(find.text('Élévations latérales').first);
    await attendre(t, 6);

    // 37 : à propos.
    for (final o in ['À propos', 'Historique', 'Progrès', 'Records']) {
      expect(find.text(o), findsOneWidget, reason: o);
    }
    expect(find.text('Classement'), findsNothing);
    for (final p in ['Favoris', 'Partager', 'Note']) {
      expect(find.text(p), findsOneWidget, reason: p);
    }
    // Le quatrième raccourci dépasse de l'écran, comme sur la maquette.
    expect(find.text('Remplacer', skipOffstage: false), findsOneWidget);
    expect(find.text('Muscles ciblés'), findsOneWidget);
    expect(find.bySemanticsLabel('Mettre l’animation en pause'), findsOneWidget);
    expect(find.bySemanticsLabel('Plein écran'), findsOneWidget);
    await capturer(t, 'bibliotheque', '37-fiche-a-propos');

    // Toute la page, d'un seul tenant, pour la comparer à la maquette.
    t.view.physicalSize = const Size(380, 1560);
    await attendre(t, 6);
    expect(find.text('Principal'), findsOneWidget);
    expect(find.text('Deltoïdes latéraux'), findsOneWidget);
    expect(find.text('Secondaire'), findsOneWidget);
    expect(find.text('Comment faire'), findsOneWidget);
    expect(find.text('Exercices alternatifs'), findsOneWidget);
    await capturer(t, 'bibliotheque', '37-fiche-a-propos-entiere');

    // Pause : l'image s'arrête, le bouton propose de relancer.
    await t.tap(find.bySemanticsLabel('Mettre l’animation en pause'));
    await attendre(t, 2);
    expect(find.bySemanticsLabel('Relancer l’animation'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Plein écran'));
    await attendre(t, 4);
    expect(find.bySemanticsLabel('Fermer'), findsOneWidget);
    await capturer(t, 'bibliotheque', '37-plein-ecran');
    await t.tap(find.bySemanticsLabel('Fermer'));
    await attendre(t, 3);

    // Favori par le raccourci.
    await t.tap(find.text('Favoris'));
    await attendre(t, 2);
    expect(data.exercises.isFavori('elevations-laterales'), isTrue);
    t.view.physicalSize = tailleMaquette;
    await attendre(t, 2);

    // 38 : historique.
    await t.tap(find.text('Historique'));
    await attendre(t, 4);
    expect(find.text('ÉPAULES'), findsNWidgets(2));
    expect(find.text('Séries réalisées'), findsNWidgets(2));
    expect(find.text('1RM'), findsNWidgets(2));
    expect(find.text('12 kg × 12'), findsOneWidget);
    expect(find.text('10 kg × 15'), findsNWidgets(2));
    expect(find.text('17'), findsOneWidget);
    expect(find.text('Record · Poids'), findsOneWidget);
    expect(find.text('Ancien record · Poids'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Medaille && w.record), findsOneWidget, reason: 'médaille dorée sur la séance du record');
    expect(find.byWidgetPredicate((w) => w is Medaille && !w.record), findsOneWidget, reason: 'médaille grise sur un ancien record');
    await capturer(t, 'bibliotheque', '38-fiche-historique');

    // Progrès.
    await t.tap(find.text('Progrès'));
    await attendre(t, 4);
    expect(find.text('1RM estimé'), findsOneWidget);
    expect(find.text('3 mois'), findsOneWidget);
    await capturer(t, 'bibliotheque', '38-fiche-progres');

    // 39 : records.
    await t.tap(find.text('Records'));
    await attendre(t, 4);
    expect(find.text('Records personnels'), findsOneWidget);
    for (final r in ['1RM estimé', 'Poids maximal', 'Max. rép', 'Volume de séance maximal', 'Volume maximal en une série']) {
      expect(find.text(r), findsOneWidget, reason: r);
    }
    expect(find.text('17 kg'), findsOneWidget);
    expect(find.text('12 kg'), findsOneWidget);
    expect(find.text('554 kg'), findsOneWidget);
    expect(find.text('150 kg'), findsOneWidget);
    expect(find.text('4 séries'), findsOneWidget);
    expect(find.text('Voir l’historique des records'), findsOneWidget);
    await capturer(t, 'bibliotheque', '39-fiche-records');

    await t.tap(find.text('Voir l’historique des records'));
    await attendre(t, 4);
    expect(find.text('Historique des records'), findsOneWidget);
    expect(find.text('Record en cours'), findsWidgets);
    expect(find.text('Ancien record'), findsWidgets);
    await capturer(t, 'bibliotheque', '39-historique-des-records');
  });

  testWidgets('la fiche s\'ouvre par son adresse, onglet compris', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer/exercices/elevations-laterales?onglet=records');
    await attendre(t, 3);
    expect(find.text('Records personnels'), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing, reason: 'la fiche couvre la barre des onglets');
    routeur(t).go('/entrainer/exercices/exercice-inconnu');
    await attendre(t, 3);
    expect(find.text('Exercice introuvable'), findsOneWidget);
    // Un exercice jamais fait : états vides des trois onglets.
    routeur(t).go('/entrainer/exercices/pistol-squat?onglet=historique');
    await attendre(t, 3);
    expect(find.text('Pas encore d’historique'), findsOneWidget);
    await capturer(t, 'bibliotheque', '38-fiche-historique-vide');
  });

  testWidgets('40 : explorateur de muscles', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer/muscles?muscle=biceps');
    await attendre(t, 6);
    expect(find.text('Muscles'), findsOneWidget);
    expect(find.text('Touche un muscle'), findsOneWidget);
    expect(find.text('Biceps'), findsNWidgets(2));
    expect(find.text('Avant-bras'), findsOneWidget);
    // « série » au singulier quand la séance de biceps d'il y a deux jours tombe dans la semaine d'avant (un lundi ou un mardi).
    expect(find.textContaining('cette sem.'), findsOneWidget);
    expect(find.text('dernier travail'), findsOneWidget);
    expect(find.text('récupéré'), findsOneWidget);
    expect(find.textContaining('exercices'), findsOneWidget);
    expect(find.byType(LigneExercice), findsWidgets);
    expect(find.byType(AppBottomNav), findsOneWidget);
    await capturer(t, 'bibliotheque', '40-muscles');

    // Un autre muscle par la rangée.
    await t.tap(find.text('Triceps'));
    await attendre(t, 4);
    expect(find.text('Triceps'), findsNWidgets(2));
    await capturer(t, 'bibliotheque', '40-muscles-triceps');

    // Un exercice ouvre sa fiche.
    await t.tap(find.byType(LigneExercice).first);
    await attendre(t, 4);
    expect(find.text('À propos'), findsOneWidget);
  });

  testWidgets('Fold ouvert : volets et fiche', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer?onglet=exercices', taille: const Size(884, 1000));
    await attendre(t, 4);
    expect(find.byType(CarteExercice), findsWidgets);
    await capturer(t, 'bibliotheque', 'large-exercices');
    routeur(t).go('/entrainer?onglet=routines');
    await attendre(t, 3);
    expect(find.text('Nouvel entraînement'), findsOneWidget);
    await capturer(t, 'routines', 'large-routines');
    routeur(t).go('/entrainer/exercices/elevations-laterales');
    await attendre(t, 5);
    expect(find.text('Muscles ciblés'), findsOneWidget);
    await capturer(t, 'bibliotheque', 'large-fiche');
  });
}

String _duree(AppData data) {
  final r = data.routines.byId('r-pecs-epaules')!;
  final m = r.dureeEstimeeMin;
  return m >= 60 ? '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}' : '$m min';
}
