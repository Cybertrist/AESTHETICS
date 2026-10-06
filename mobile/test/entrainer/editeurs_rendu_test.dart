import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:aesthetic/features/entrainer/commun/carte_jour.dart';
import 'package:aesthetic/features/entrainer/routines/logic/objectif.dart';
import 'package:aesthetic/features/entrainer/routines/logic/program_plan.dart';
import 'package:aesthetic/features/entrainer/routines/widgets/formulaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aesthetic/features/entrainer/routines/widgets/icones_editeur.dart';

import 'outils.dart';

/// Rendus et parcours des éditeurs de programme et de routine. Images
/// dans build/rendus/routines (`editeur-...`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  final maintenant = DateTime.now();

  Future<AppData> donnees(WidgetTester t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await t.runAsync(() async {
      final p = data.programs.byId('p-v3')!;
      await data.programs.save(Program(
        id: p.id,
        nom: p.nom,
        description: 'Cinq séances, chaque muscle deux fois. Repos courts et séries de 8 à 15 répétitions.',
        dureeSemaines: 12,
        joursParSemaine: 5,
        routineIds: p.routineIds,
        actif: p.actif,
        debuteLe: p.debuteLe,
        semaineCourante: p.semaineCourante,
        seancesFaites: p.seancesFaites,
        niveau: Niveau.intermediaire.name,
        objectif: 'Hypertrophie',
        creeLe: p.creeLe,
      ));
      final plans = ProgramPlanRepo.of(data.store);
      await plans.load();
      await plans.save(const ProgramPlan(programId: 'p-v3', jours: [1, 2, 4, 5, 6], dechargeToutesLes: 6));
    });
    return data;
  }

  for (final (nom, taille) in [('360', const Size(360, 780)), ('412', const Size(412, 915)), ('large', const Size(1100, 900))]) {
    testWidgets('éditeur de programme en $nom : rien ne déborde, tout est là', (t) async {
      final data = await donnees(t);
      // Une première image à la taille de l'écran, puis toute la page.
      await lancer(t, data, '/entrainer/programmes/p-v3/modifier', taille: taille);
      expect(t.takeException(), isNull);
      await capturer(t, 'routines', 'editeur-programme-$nom-ecran');
      if (nom != 'large') {
        for (var k = 2; k <= 5; k++) {
          await t.drag(find.byType(ListView).first, Offset(0, -taille.height + 190));
          await attendre(t, 2);
          await capturer(t, 'routines', 'editeur-programme-$nom-ecran-$k');
        }
      }

      {
        await lancer(t, data, '/entrainer/programmes/p-v3/modifier', taille: Size(taille.width, nom == 'large' ? 2400 : 3300));
        await capturer(t, 'routines', 'editeur-programme-$nom');
      }
      expect(t.takeException(), isNull);
      expect(find.text('Modifier le programme'), findsOneWidget);
      expect(find.text('Changer la photo').evaluate().length + find.text('Ajouter une photo').evaluate().length, 1);
      for (final titre in ['Niveau', 'Séances par semaine', 'Durée', 'Jours d\'entraînement', 'Objectif', 'Progression', 'Routines du programme']) {
        expect(find.text(titre), findsOneWidget, reason: titre);
      }
      for (final o in ObjectifProgramme.values) {
        expect(find.text(o.label), findsOneWidget);
      }
      expect(find.byType(LigneChoix), findsNWidgets(4));
      expect(find.byType(Radio<Object>), findsNothing);
      expect(find.byType(CarteJour), findsNWidgets(8));
      expect(find.textContaining(' exercices · '), findsNWidgets(7));
      expect(find.text('Ajouter une routine'), findsOneWidget);
      expect(find.text('Nouvelle routine'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('éditeur de routine en $nom : rien ne déborde', (t) async {
      final data = await donnees(t);
      await lancer(t, data, '/entrainer/routines/r-dos-biceps/modifier', taille: taille);
      expect(t.takeException(), isNull);
      expect(find.text('Modifier la routine'), findsOneWidget);
      expect(find.text('Minuteur de repos : 2 min'), findsWidgets);
      await capturer(t, 'routines', 'editeur-routine-$nom');
    });
  }

  testWidgets('routine : toucher ailleurs retire le curseur du nom, il ne revient pas tout seul', (t) async {
    final data = (await t.runAsync(() => donneesMaquette(maintenant)))!;
    await lancer(t, data, '/entrainer/routines/r-dos-biceps/modifier', taille: const Size(412, 915));
    await attendre(t, 4);
    final nom = find.widgetWithText(TextField, 'Nom de la routine');
    await t.tap(nom);
    await attendre(t, 2);
    expect(t.widget<TextField>(nom).focusNode!.hasFocus, isTrue);
    // Un appui hors du champ (le sous-titre de l'en-tête) : plus de curseur.
    await t.tapAt(const Offset(206, 500));
    await attendre(t, 2);
    expect(t.widget<TextField>(nom).focusNode!.hasFocus, isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('nouveau programme : écran vide en 360', (t) async {
    final data = await donnees(t);
    await lancer(t, data, '/entrainer/programmes/nouveau', taille: const Size(360, 3000));
    expect(t.takeException(), isNull);
    expect(find.text('Nouveau programme'), findsOneWidget);
    expect(find.text('Ajouter une photo'), findsOneWidget);
    expect(find.text('Aucune routine'), findsOneWidget);
    expect(find.text('Le suivre dès maintenant'), findsOneWidget);
    await capturer(t, 'routines', 'editeur-programme-nouveau-360');
  });

  testWidgets('programme : les choix sont enregistrés, l\'objectif d\'origine est gardé s\'il n\'est pas touché', (t) async {
    final data = await donnees(t);
    await lancer(t, data, '/entrainer?onglet=programmes', taille: const Size(412, 3300));
    routeur(t).push('/entrainer/programmes/p-v3/modifier');
    await attendre(t, 4);

    // « Hypertrophie » est rapproché de « Prise de muscle », sans être réécrit.
    await t.tap(find.text('Avancé'));
    await t.tap(find.text('3').last);
    await t.tap(find.text('16'));
    await t.tap(find.text('Ondulée par semaine'));
    await t.pump();
    // Cinq jours choisis pour trois séances : on propose d'ajuster.
    expect(find.text('5 jours choisis pour 3 séances.'), findsOneWidget);
    await t.tap(find.text('Ajuster'));
    await t.pump();
    expect(find.text('5 jours choisis pour 3 séances.'), findsNothing);
    await t.tap(find.text('Enregistrer'));
    await attendre(t, 4);
    expect(t.takeException(), isNull);

    var p = data.programs.byId('p-v3')!;
    expect(p.niveau, Niveau.avance.name);
    expect(p.joursParSemaine, 5);
    expect(p.dureeSemaines, 16);
    expect(p.objectif, 'Hypertrophie');
    expect(p.routineIds, hasLength(8));
    final plan = ProgramPlanRepo.of(data.store).planFor('p-v3');
    expect(plan.progression, ProgressionType.ondulee);
    expect(plan.jours, [1, 2, 4, 5, 6]);
    expect(plan.dechargeToutesLes, 6);

    // Un objectif choisi est écrit ; une routine retirée peut revenir.
    routeur(t).push('/entrainer/programmes/p-v3/modifier');
    await attendre(t, 4);
    await t.tap(find.text('Sèche'));
    await t.tap(find.byTooltip('Retirer du programme').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(CarteJour), findsNWidgets(7));
    expect(find.textContaining('retirée du programme.'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await t.pump();
    expect(find.byType(CarteJour), findsNWidgets(8));
    await t.tap(find.byTooltip('Retirer du programme').last);
    // Le message recouvre le bouton le temps de son affichage.
    await t.pump(const Duration(seconds: 4));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Enregistrer'));
    await attendre(t, 4);
    p = data.programs.byId('p-v3')!;
    expect(p.objectif, 'Sèche');
    expect(p.routineIds, hasLength(7));
    expect(p.routineIds.first, 'r-pecs-triceps');
    expect(t.takeException(), isNull);
  });

  testWidgets('programme : sans nom ou sans routine, rien n\'est enregistré', (t) async {
    final data = await donnees(t);
    final avant = data.programs.programs.length;
    await lancer(t, data, '/entrainer?onglet=programmes', taille: const Size(412, 3000));
    routeur(t).push('/entrainer/programmes/nouveau');
    await attendre(t, 4);
    await t.tap(find.text('Enregistrer'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Donne un nom au programme.'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Mon programme');
    await t.pump(const Duration(seconds: 6));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Enregistrer'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Ajoute au moins une routine au programme.'), findsOneWidget);
    expect(data.programs.programs, hasLength(avant));

    // Le dialogue d'ajout : l'ordre des coches donne l'ordre du cycle.
    await t.pump(const Duration(seconds: 6));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Ajouter une routine'));
    await attendre(t, 2);
    expect(find.text('Ajouter des routines'), findsOneWidget);
    await t.tap(find.text('JAMBES'));
    await t.tap(find.text('BRAS'));
    await t.pump();
    await capturer(t, 'routines', 'editeur-programme-ajout');
    await t.tap(find.text('Ajouter (2)'));
    await attendre(t, 2);
    await t.tap(find.text('Enregistrer'));
    await attendre(t, 4);
    expect(data.programs.programs, hasLength(avant + 1));
    final cree = data.programs.programs.firstWhere((p) => p.nom == 'Mon programme');
    expect(cree.routineIds, ['r-jambes', 'r-bras']);
    expect(cree.actif, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('planche des icônes', (t) async {
    t.view.physicalSize = const Size(720, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(RepaintBoundary(key: cleCapture, child: const Directionality(textDirection: TextDirection.ltr, child: PlancheIcones())));
    await capturer(t, 'routines', 'editeur-icones');
  });

  test('objectif : un ancien texte libre est rapproché d\'un choix', () {
    expect(ObjectifProgramme.depuis('Hypertrophie'), ObjectifProgramme.muscle);
    expect(ObjectifProgramme.depuis('Force et masse'), ObjectifProgramme.muscle);
    expect(ObjectifProgramme.depuis('Force'), ObjectifProgramme.force);
    expect(ObjectifProgramme.depuis('Forme et tonus'), ObjectifProgramme.condition);
    expect(ObjectifProgramme.depuis('Sèche'), ObjectifProgramme.seche);
    expect(ObjectifProgramme.depuis(null), isNull);
    expect(ObjectifProgramme.depuis('Autre chose'), isNull);
  });

  test('plan : la photo de couverture est relue, un ancien fichier reste lisible', () {
    const p = ProgramPlan(programId: 'p', photo: '/medias/programme_1.jpg');
    expect(ProgramPlan.fromJson(p.toJson()).photo, '/medias/programme_1.jpg');
    expect(p.copyWith(programId: 'q').photo, '/medias/programme_1.jpg');
    expect(ProgramPlan.fromJson({'programId': 'p'}).photo, isNull);
    expect(const ProgramPlan(programId: 'p').toJson().containsKey('photo'), isFalse);
  });
}

/// Planche des icônes, en grand, pour juger les tracés.
class PlancheIcones extends StatelessWidget {
  const PlancheIcones({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            for (final p in Picto.values) IconePicto(p, size: 120, color: Colors.white, epaisseur: 6),
            for (var n = 1; n <= 3; n++) IconeNiveau(n, size: 120, color: Colors.white),
          ],
        ),
      );
}
