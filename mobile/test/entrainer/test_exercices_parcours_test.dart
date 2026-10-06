import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/bibliotheque.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/exercise_notes.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/pages/exercise_actions.dart' show messageSuppression, retirerDesRoutines;
import 'package:aesthetic/features/entrainer/bibliotheque/pages/exercise_browser.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/pages/fiche/tab_apropos.dart' show exercicesAlternatifs;
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:aesthetic/features/entrainer/commun/corps_colore.dart';
import 'package:aesthetic/features/entrainer/commun/elements.dart' show BoutonNu, poseDe;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils.dart';

/// Zone Exercices : parcours à la main (double appui, retour, exercices
/// perso créés, modifiés, supprimés alors qu'ils servent déjà).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  final n = DateTime.now();

  WorkoutSession seance(String id, String exercice, {int joursAvant = 2}) => WorkoutSession(
        id: id,
        nom: 'Séance $id',
        // Aujourd'hui : jamais dans le futur, quelle que soit l'heure du test.
        debut: joursAvant == 0 ? n.subtract(const Duration(minutes: 2)) : DateTime(n.year, n.month, n.day - joursAvant, 18),
        fin: joursAvant == 0 ? n.subtract(const Duration(minutes: 1)) : DateTime(n.year, n.month, n.day - joursAvant, 19),
        exercices: [
          SessionExercise(id: 'e-$id', exerciseId: exercice, series: [WorkoutSet(id: 's-$id', poids: 50, reps: 8, fait: true)]),
        ],
      );

  Future<void> ouvrirDepuisLaGrille(WidgetTester t, String recherche) async {
    await t.enterText(find.byType(TextField).first, recherche);
    await attendre(t, 3);
    await t.tap(find.byType(CarteExercice).first);
  }

  testWidgets('deux appuis rapprochés n\'ouvrent qu\'une fiche, et le retour ramène à la grille', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await lancer(t, data, '/entrainer?onglet=exercices');
    await t.enterText(find.byType(TextField).first, 'squat');
    await attendre(t, 3);
    final carte = find.byType(CarteExercice).first;
    final centre = t.getCenter(carte);
    await t.tapAt(centre);
    await t.tapAt(centre);
    await attendre(t, 4);
    expect(find.byType(ExerciseDetailPage, skipOffstage: false), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Retour'));
    await attendre(t, 3);
    expect(find.byType(ExerciseDetailPage, skipOffstage: false), findsNothing);
    expect(find.byType(CarteExercice), findsWidgets);
    // La recherche est gardée au retour.
    expect(find.text('squat'), findsOneWidget);
    // La même fiche se rouvre ensuite sans peine.
    await t.tapAt(centre);
    await attendre(t, 4);
    expect(find.byType(ExerciseDetailPage), findsOneWidget);
  });

  testWidgets('une alternative ouvre sa fiche par-dessus, puis la première revient', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await lancer(t, data, '/entrainer?onglet=exercices', taille: const Size(380, 1800));
    await ouvrirDepuisLaGrille(t, 'elevations laterales');
    await attendre(t, 5);
    expect(find.text('Exercices alternatifs'), findsOneWidget);
    final nomAlternative = exercicesAlternatifs(data.exercises.byId('elevations-laterales')!, data.exercises.all).first.nom;
    await t.tap(find.text(nomAlternative).last);
    await attendre(t, 5);
    expect(find.byType(ExerciseDetailPage, skipOffstage: false), findsNWidgets(2));
    await t.tap(find.bySemanticsLabel('Retour').last);
    await attendre(t, 3);
    expect(find.byType(ExerciseDetailPage, skipOffstage: false), findsOneWidget);
    expect(find.text('Élévations latérales'), findsWidgets);
  });

  for (final largeur in [320.0, 360.0, 412.0]) {
    testWidgets('les quatre onglets de la fiche tiennent en $largeur de large', (t) async {
      await t.runAsync(chargerPolices);
      final data = (await t.runAsync(donneesVides))!;
      await lancer(t, data, '/entrainer/exercices/squat', taille: Size(largeur, 800));
      await attendre(t, 3);
      for (final o in ['À propos', 'Historique', 'Progrès', 'Records']) {
        final r = t.getRect(find.text(o));
        expect(r.left, greaterThanOrEqualTo(0), reason: o);
        expect(r.right, lessThanOrEqualTo(largeur), reason: '« $o » dépasse de l\'écran');
      }
      await t.tap(find.text('Records'));
      await attendre(t, 3);
      expect(find.text('Aucun record pour l’instant'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  for (final echelle in [1.3, 1.6]) {
    testWidgets('texte du téléphone agrandi à $echelle : la grille, la liste et la fiche ne débordent pas', (t) async {
      await t.runAsync(chargerPolices);
      final data = (await t.runAsync(donneesVides))!;
      t.platformDispatcher.textScaleFactorTestValue = echelle;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await lancer(t, data, '/entrainer?onglet=exercices', taille: const Size(360, 780));
      await attendre(t, 4);
      expect(find.byType(CarteExercice), findsWidgets);
      expect(t.takeException(), isNull, reason: 'grille');
      await capturer(t, 'exercices', 'texte-$echelle-grille');
      await t.tap(find.bySemanticsLabel('Afficher en liste'));
      await attendre(t, 3);
      expect(t.takeException(), isNull, reason: 'liste');
      await t.tap(find.bySemanticsLabel('Afficher en grille'));
      await attendre(t, 2);
      for (final onglet in ['', '?onglet=historique', '?onglet=progres', '?onglet=records']) {
        routeur(t).go('/entrainer/exercices/squat$onglet');
        await attendre(t, 3);
        expect(t.takeException(), isNull, reason: 'fiche $onglet');
      }
      routeur(t).go('/entrainer/muscles');
      await attendre(t, 4);
      expect(t.takeException(), isNull, reason: 'explorateur');
      await capturer(t, 'exercices', 'texte-$echelle-muscles');
    });
  }

  testWidgets('une pose fixe n\'a pas de bouton pause, une animation en a un', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    expect(data.exercises.byId('gainage')!.media.gif, isNull);
    await lancer(t, data, '/entrainer/exercices/gainage');
    await attendre(t, 3);
        Finder bouton(String label) => find.byWidgetPredicate((w) => w is BoutonNu && w.label == label);
    expect(bouton('Mettre l’animation en pause'), findsNothing);
    expect(bouton('Plein écran'), findsOneWidget);
    routeur(t).go('/entrainer/exercices/squat');
    await attendre(t, 3);
    expect(bouton('Mettre l’animation en pause'), findsOneWidget);
    expect(bouton('Plein écran'), findsOneWidget);
  });

  testWidgets('de l\'historique de la fiche à la séance, et retour sur la fiche', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await t.runAsync(() => data.sessions.addAll([seance('a', 'squat'), seance('b', 'squat', joursAvant: 9)]));
    await lancer(t, data, '/entrainer?onglet=exercices');
    await ouvrirDepuisLaGrille(t, 'squat');
    await attendre(t, 4);
    await t.tap(find.text('Historique'));
    await attendre(t, 3);
    // La plus récente d'abord.
    expect(t.getTopLeft(find.text('Séance a')).dy, lessThan(t.getTopLeft(find.text('Séance b')).dy));
    await t.tap(find.text('Séance a'));
    await attendre(t, 3);
    expect(find.text('seance a'), findsOneWidget);
    routeur(t).pop();
    await attendre(t, 3);
    expect(find.text('Séries réalisées'), findsNWidgets(2), reason: 'retour sur l\'onglet Historique de la fiche');
    await t.tap(find.bySemanticsLabel('Retour'));
    await attendre(t, 3);
    expect(find.byType(CarteExercice), findsWidgets);
  });

  testWidgets('créer un exercice perso, le retrouver, le modifier', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await lancer(t, data, '/entrainer/exercices/nouveau', taille: const Size(380, 2600));
    await attendre(t, 2);
    await t.enterText(find.byType(TextField).first, '  Tirage maison à l\'élastique  ');
    await t.tap(find.text('Muscles principaux'));
    await attendre(t, 3);
    await capturer(t, 'bibliotheque', 'chasse-editeur-muscles');
    await t.tap(find.text('Grand dorsal'));
    await t.pump();
    await t.tap(find.text('Valider'));
    await attendre(t, 3);
    expect(find.byType(AppBar), findsNothing, reason: 'en-tête commun, et non le vieil habillage');
    await capturer(t, 'bibliotheque', 'chasse-editeur-exercice');
    await t.tap(find.text('Créer l\'exercice'));
    await attendre(t, 3);
    await t.pump(const Duration(seconds: 5));
    final cree = data.exercises.perso.single;
    expect(cree.nom, 'Tirage maison à l\'élastique');
    expect(cree.perso, isTrue);
    expect(cree.id, startsWith('perso-'));
    expect(cree.musclesPrincipaux, [Muscle.grandDorsal]);
    expect(cree.categorie, 'dos', reason: 'catégorie déduite du muscle principal');
    expect(cree.creeLe, isNotNull);

    // Il se trouve par la recherche, sans accent, et par « Mes exercices ».
    routeur(t).go('/entrainer/exercices?onglet=perso');
    await attendre(t, 3);
    expect(t.widget<CarteExercice>(find.byType(CarteExercice)).exercise.id, cree.id);
    expect(t.widget<CarteExercice>(find.byType(CarteExercice)).sousTitre, 'Grand dorsal · Perso');
    routeur(t).go('/entrainer/exercices?q=elastique%20tirage');
    await attendre(t, 3);
    expect(t.widget<CarteExercice>(find.byType(CarteExercice).first).exercise.id, cree.id);

    // Modification : même identifiant, même date de création.
    routeur(t).go('/entrainer/exercices/${cree.id}/modifier');
    await attendre(t, 3);
    await t.enterText(find.byType(TextField).first, 'Tirage maison');
    await t.tap(find.text('Enregistrer'));
    await attendre(t, 3);
    await t.pump(const Duration(seconds: 5));
    final modifie = data.exercises.perso.single;
    expect(modifie.id, cree.id);
    expect(modifie.nom, 'Tirage maison');
    expect(modifie.creeLe, cree.creeLe);
    expect(modifie.musclesPrincipaux, [Muscle.grandDorsal]);
    expect(t.takeException(), isNull);
  });

  testWidgets('sans nom ni muscle, rien ne se crée et le champ le dit', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await lancer(t, data, '/entrainer/exercices/nouveau', taille: const Size(380, 2600));
    await attendre(t, 2);
    await t.tap(find.text("Créer l'exercice"));
    await attendre(t, 2);
    expect(data.exercises.perso, isEmpty);
    expect(find.text("Donne un nom à l'exercice"), findsWidgets);
    expect(find.text('Choisis au moins un muscle principal'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('variante d\'un exercice au nom très long : pas de champ en erreur, les poses restent', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    final long = data.exercises.catalogue.reduce((a, b) => a.nom.length >= b.nom.length ? a : b);
    expect(long.nom.length, greaterThan(52));
    await lancer(t, data, '/entrainer/exercices/${long.id}/modifier', taille: const Size(380, 2600));
    await attendre(t, 2);
    expect(find.text('Exercice du catalogue'), findsOneWidget);
    await t.tap(find.text('Créer une variante perso'));
    await attendre(t, 4);
    final champ = t.widget<TextField>(find.byType(TextField).first);
    expect(champ.controller!.text.length, lessThanOrEqualTo(champ.maxLength!), reason: 'le nom de départ dépasse la limite du champ');
    await t.tap(find.text('Enregistrer'));
    await attendre(t, 3);
    await t.pump(const Duration(seconds: 5));
    final copie = data.exercises.perso.single;
    expect(copie.nom, '${long.nom} (perso)');
    expect(copie.media.imagesLocales, long.media.imagesLocales, reason: 'la variante garde les poses du catalogue');
    expect(poseDe(copie), poseDe(long), reason: 'même vignette dans la grille');
    expect(copie.media.images, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('supprimer un exercice perso déjà utilisé : séances gardées, routines nettoyées', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    final perso = (await t.runAsync(() => data.exercises.addCustom(const Exercise(id: '', nom: 'Mon tirage', musclesPrincipaux: [Muscle.grandDorsal], perso: true))))!;
    await t.runAsync(() async {
      await data.exercises.toggleFavori(perso.id);
      await data.sessions.addAll([seance('a', perso.id)]);
      await data.routines.saveAll([
        Routine(id: 'r1', nom: 'DOS', creeLe: n, exercices: [
          RoutineExercise(id: 'x1', exerciseId: perso.id, series: const [PlannedSet(reps: 8)]),
          RoutineExercise(id: 'x2', exerciseId: 'tractions', series: const [PlannedSet(reps: 8)]),
        ]),
        Routine(id: 'r2', nom: 'JAMBES', creeLe: n, exercices: [RoutineExercise(id: 'x3', exerciseId: 'squat', series: const [PlannedSet(reps: 8)])]),
      ]);
      await ExerciseNotes.of(data.store).set(perso.id, 'Prise large');
    });
    await lancer(t, data, '/entrainer/exercices/${perso.id}');
    await attendre(t, 3);
    await t.tap(find.bySemanticsLabel('Plus d’actions'));
    await attendre(t, 3);
    expect(find.text('Modifier'), findsOneWidget);
    await t.tap(find.text('Supprimer'));
    await attendre(t, 3);
    expect(find.textContaining('retiré de la routine qui le contient'), findsOneWidget);
    expect(find.textContaining('1 séance : elle reste'), findsOneWidget);
    await t.tap(find.text('Supprimer').last);
    await attendre(t, 4);
    await t.pump(const Duration(seconds: 5));

    expect(data.exercises.byId(perso.id), isNull);
    expect(data.exercises.isFavori(perso.id), isFalse);
    expect(data.exercises.nameOf(perso.id), 'Exercice supprimé');
    expect(data.sessions.historyFor(perso.id), hasLength(1), reason: 'la séance passée reste');
    expect(data.routines.byId('r1')!.exercices.map((e) => e.exerciseId), ['tractions']);
    expect(data.routines.byId('r2')!.exercices, hasLength(1));
    expect(ExerciseNotes.of(data.store).noteOf(perso.id), isNull);
    // La fiche se referme : on ne reste pas sur « Exercice introuvable ».
    expect(find.text('Exercice introuvable'), findsNothing);
    expect(find.byType(ExerciseDetailPage), findsNothing);
    expect(t.takeException(), isNull);

    // Un exercice du catalogue ne se supprime ni ne se modifie.
    routeur(t).go('/entrainer/exercices/squat');
    await attendre(t, 3);
    await t.tap(find.bySemanticsLabel('Plus d’actions'));
    await attendre(t, 3);
    expect(find.text('Supprimer'), findsNothing);
    expect(find.text('Modifier'), findsNothing);
    expect(find.text('Créer une variante perso'), findsOneWidget);
  });

  test('message de suppression et retrait des routines', () {
    expect(messageSuppression(seances: 0, routines: 0), 'L\'exercice disparaît de la bibliothèque.');
    expect(messageSuppression(seances: 3, routines: 0), contains('3 séances : elles restent'));
    expect(messageSuppression(seances: 0, routines: 2), 'Il sera retiré de tes 2 routines qui le contiennent.');
    final r = Routine(id: 'r', nom: 'R', creeLe: DateTime(2026), exercices: const [
      RoutineExercise(id: 'a', exerciseId: 'p'),
      RoutineExercise(id: 'b', exerciseId: 'q'),
      RoutineExercise(id: 'c', exerciseId: 'p'),
    ]);
    final autre = Routine(id: 's', nom: 'S', creeLe: DateTime(2026), exercices: const [RoutineExercise(id: 'd', exerciseId: 'q')]);
    final out = retirerDesRoutines([r, autre], 'p');
    expect(out.single.id, 'r');
    expect(out.single.exercices.map((e) => e.id), ['b']);
  });

  testWidgets('favoris : gardés après relance', (t) async {
    final data = (await t.runAsync(donneesVides))!;
    await t.runAsync(() => data.exercises.toggleFavori('squat'));
    final relance = ExerciseRepo(data.store);
    await t.runAsync(relance.load);
    expect(relance.favoris, {'squat'});
    await t.runAsync(() => data.exercises.toggleFavori('squat'));
    final relance2 = ExerciseRepo(data.store);
    await t.runAsync(relance2.load);
    expect(relance2.favoris, isEmpty);
  });

  testWidgets('explorateur : toucher le corps choisit le muscle, la liste et les chiffres suivent', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await t.runAsync(() => data.sessions.addAll([seance('a', 'curl-barre', joursAvant: 0)]));
    await lancer(t, data, '/entrainer/muscles?muscle=biceps');
    await attendre(t, 5);
    expect(find.text('Biceps'), findsNWidgets(2));
    expect(find.text('Aujourd\'hui'), findsOneWidget, reason: 'dernier travail');
    expect(find.text('série cette sem.'), findsOneWidget, reason: 'une seule série : singulier');
    // Le plus fait d'abord.
    expect(t.widget<LigneExercice>(find.byType(LigneExercice).first).exercise.id, 'curl-barre');

    // Les pectoraux, sur la vue de face.
    final face = t.getRect(find.byType(CorpsColore).first);
    await t.tapAt(Offset(face.center.dx - face.width * 0.12, face.top + face.height * 0.235));
    await attendre(t, 30);
    expect(find.text('Pectoraux'), findsNWidgets(2), reason: 'la puce et le titre');
    expect(find.text('Jamais'), findsOneWidget);
    final liste = t.widgetList<LigneExercice>(find.byType(LigneExercice)).toList();
    expect(liste, isNotEmpty);
    expect(liste.every((l) => l.exercise.musclesPrincipaux.contains(Muscle.pectoraux)), isTrue);

    // Les fessiers, sur la vue de dos.
    final dos = t.getRect(find.byType(CorpsColore).last);
    await t.tapAt(Offset(dos.center.dx - dos.width * 0.1, dos.top + dos.height * 0.5));
    await attendre(t, 30);
    expect(find.text('Fessiers'), findsNWidgets(2));
    // Toucher hors du corps ne change rien.
    await t.tapAt(Offset(dos.right - 2, dos.bottom - 2));
    await attendre(t, 3);
    expect(find.text('Fessiers'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });
}

