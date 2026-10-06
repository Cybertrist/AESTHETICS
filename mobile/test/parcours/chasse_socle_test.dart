import 'package:aesthetic/app/coquille_appli.dart';
import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/app/orientation.dart';
import 'package:aesthetic/features/aujourdhui/pages/aujourdhui_page.dart';
import 'package:aesthetic/features/progres/ui/calendrier_page.dart';
import 'package:aesthetic/features/progres/ui/progres_page.dart';
import 'package:aesthetic/features/progres/ui/semaine_page.dart';
import 'package:aesthetic/features/seance/pages/seance_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_transverse_banc.dart';

/// Défauts de la zone ACCUEIL ET SOCLE relevés sur l'émulateur (CHASSE.md) :
/// retour depuis « Voir plus », barre de la séance par-dessus les pages plein
/// écran, verrou portrait.
void main() {
  bool visible(Finder f) => f.hitTestable().evaluate().isNotEmpty;

  group('retour depuis une page ouverte par l\'accueil (14a)', () {
    testWidgets('« Voir plus » puis retour du téléphone : l\'accueil, pas Progrès', (t) async {
      final b = await Banc.monter(t);
      await t.tap(find.text('Voir plus'));
      await b.pose();
      expect(visible(find.byType(SemainePage)), isTrue);
      expect(b.ongletActif, 'Progrès');
      await b.capture('chasse-voir-plus');
      await b.retourSysteme();
      expect(b.sorties, 0);
      expect(b.ongletActif, 'Accueil');
      expect(visible(find.byType(AujourdhuiPage)), isTrue);
      expect(b.lieu, '/');
      // L'onglet Progrès est revenu à sa racine : pas de page fantôme.
      await b.onglet('Progrès');
      expect(visible(find.byType(ProgresPage)), isTrue);
      expect(find.byType(SemainePage), findsNothing);
      // Et son retour à lui n'a pas changé.
      await b.pousser('/progres/calendrier');
      await b.retourSysteme();
      expect(visible(find.byType(ProgresPage)), isTrue, reason: 'lieu ${b.lieu}, onglet ${b.ongletActif}, origine ${RetourOrigine.origine}, cal ${find.byType(CalendrierPage).evaluate().length}');
      expect(b.ongletActif, 'Progrès');
      expect(t.takeException(), isNull);
      await b.fin();
    });

    testWidgets('la flèche de la page ramène aussi à l\'accueil', (t) async {
      final b = await Banc.monter(t);
      await t.tap(find.text('Voir plus'));
      await b.pose();
      Navigator.of(t.element(find.byType(SemainePage))).maybePop();
      await b.pose();
      expect(b.ongletActif, 'Accueil');
      expect(visible(find.byType(AujourdhuiPage)), isTrue);
      expect(t.takeException(), isNull);
      await b.fin();
    });

    testWidgets('« Historique » puis retour : l\'accueil', (t) async {
      final b = await Banc.monter(t);
      await t.ensureVisible(find.text('Historique'));
      await t.tap(find.text('Historique'));
      await b.pose();
      expect(visible(find.byType(CalendrierPage)), isTrue);
      await b.retourSysteme();
      expect(b.ongletActif, 'Accueil');
      expect(visible(find.byType(AujourdhuiPage)), isTrue);
      expect(b.sorties, 0);
      await b.fin();
    });

    testWidgets('changer d\'onglet soi-même annule ce retour', (t) async {
      final b = await Banc.monter(t);
      await t.tap(find.text('Voir plus'));
      await b.pose();
      await b.onglet('Accueil');
      expect(RetourOrigine.origine, isNull);
      await b.onglet('Progrès');
      expect(visible(find.byType(SemainePage)), isTrue, reason: 'l\'onglet a gardé sa page');
      await b.retourSysteme();
      expect(b.ongletActif, 'Progrès', reason: 'venu par l\'onglet, on reste dans Progrès');
      expect(visible(find.byType(ProgresPage)), isTrue);
      await b.fin();
    });
  });

  group('barre de la séance en cours par-dessus les pages plein écran', () {
    Future<Banc> avecSeance(WidgetTester t, {Size taille = const Size(412, 915)}) async {
      final b = await Banc.monter(t, taille: taille);
      await t.runAsync(() => b.data.sessions.startFromRoutine(b.data.routines.routines.first));
      await b.pose();
      return b;
    }

    test('où la barre a sa place', () {
      for (final oui in [
        '/reglages',
        '/reglages/donnees',
        '/profil/mensurations',
        '/entrainer/exercices/squat',
        '/import',
        '/seance/historique',
        '/seance/historique/x',
      ]) {
        expect(barreSeanceSurPage(oui), isTrue, reason: oui);
      }
      for (final non in [
        '/seance',
        '/seance/repos',
        '/seance/terminer',
        '/seance/disques',
        '/seance/resume/x',
        '/seance/partager/x',
        '/bienvenue',
        '/bienvenue/profil',
        '/progres/bilan',
      ]) {
        expect(barreSeanceSurPage(non), isFalse, reason: non);
      }
      expect(CoquilleAppli.barreVisible(null), isFalse);
      expect(CoquilleAppli.barreVisible(const []), isFalse);
      expect(CoquilleAppli.barreVisible(const ['/reglages', '/reglages/donnees']), isTrue);
      // Une page ouverte depuis la séance : la séance est dessous, pas de barre.
      expect(CoquilleAppli.barreVisible(const ['/seance', '/reglages']), isFalse);
    });

    testWidgets('visible sur les réglages, les mensurations et une fiche, en 360 et sur le Fold ouvert', (t) async {
      for (final taille in const [Size(360, 780), Size(900, 800)]) {
        final b = await avecSeance(t, taille: taille);
        for (final plein in ['/reglages', '/profil/mensurations', '/entrainer/exercices/developpe-couche']) {
          await b.pousser(plein);
          expect(visible(find.text('Entraînement en cours')), isTrue, reason: '$plein en ${taille.width}');
          expect(find.byType(SeanceMiniBarre).hitTestable(), findsOneWidget, reason: 'une seule barre');
          // La barre est sous la page, pas dessus : la page s'arrête où elle commence.
          final barre = t.getRect(find.byType(SeanceMiniBarre).hitTestable());
          final page = t.getRect(find.byType(Scaffold).hitTestable().last);
          expect(page.bottom, lessThanOrEqualTo(barre.top + 0.5), reason: plein);
          if (plein == '/reglages') await b.capture('chasse-barre-reglages-${taille.width.round()}');
          if (plein == '/profil/mensurations') await b.capture('chasse-barre-mensurations-${taille.width.round()}');
          await b.retourSysteme();
        }
        expect(t.takeException(), isNull, reason: 'en ${taille.width}');
        await b.fin();
      }
    });

    testWidgets('sans séance en cours, rien ne s\'ajoute sous les pages plein écran', (t) async {
      final b = await Banc.monter(t);
      await b.pousser('/reglages');
      expect(find.text('Entraînement en cours'), findsNothing);
      expect(find.byType(SeanceMiniBarre).hitTestable(), findsNothing);
      await b.fin();
    });

    testWidgets('absente des écrans de la séance elle-même et du bilan du mois', (t) async {
      final b = await avecSeance(t);
      await b.pousser('/reglages');
      await t.tap(find.text('Reprendre').hitTestable());
      await b.pose();
      expect(visible(find.byType(SeancePage)), isTrue);
      expect(b.lieu, '/seance');
      expect(visible(find.text('Entraînement en cours')), isFalse, reason: 'pas de barre sur la séance');
      await b.retourSysteme();
      expect(visible(find.text('Entraînement en cours')), isTrue, reason: 'de retour sur les réglages');
      await b.retourSysteme();
      final m = DateTime(DateTime.now().year, DateTime.now().month - 1);
      await b.pousser('/progres/bilan?mois=${m.year}-${m.month}');
      expect(visible(find.text('Entraînement en cours')), isFalse, reason: 'le bilan occupe tout l\'écran');
      t.takeException();
      await b.fin();
    });

    testWidgets('« Abandonner » depuis une page plein écran : confirmation au-dessus, puis la barre s\'en va', (t) async {
      final b = await avecSeance(t);
      await b.pousser('/reglages');
      await t.tap(find.text('Abandonner').hitTestable());
      await b.pose();
      expect(find.text('Abandonner la séance ?'), findsOneWidget);
      await b.capture('chasse-barre-abandon');
      await b.retourSysteme();
      expect(find.text('Abandonner la séance ?'), findsNothing);
      expect(b.data.sessions.active, isNotNull);
      expect(b.lieu, '/reglages', reason: 'le retour n\'a fermé que la confirmation');
      await t.tap(find.text('Abandonner').hitTestable());
      await b.pose();
      await t.tap(find.text('Abandonner').last);
      await b.pose();
      expect(b.data.sessions.active, isNull);
      expect(find.text('Entraînement en cours'), findsNothing);
      expect(b.lieu, '/reglages');
      expect(t.takeException(), isNull);
      await b.fin();
    });
  });

  group('verrou portrait', () {
    late List<List<String>> demandes;

    setUp(() {
      demandes = [];
      OrientationEcran.reinitialiser();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (appel) async {
        if (appel.method == 'SystemChrome.setPreferredOrientations') {
          demandes.add([for (final o in appel.arguments as List) '$o']);
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      OrientationEcran.reinitialiser();
    });

    Future<void> monter(WidgetTester t, Size taille) async {
      t.view.physicalSize = taille;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MediaQuery.fromView(view: t.view, child: const VerrouOrientation(child: SizedBox())));
      await t.pump();
    }

    test('le seuil est à 600 de plus petit côté', () {
      expect(OrientationEcran.verrouille(360), isTrue);
      expect(OrientationEcran.verrouille(412), isTrue);
      expect(OrientationEcran.verrouille(599.9), isTrue);
      expect(OrientationEcran.verrouille(600), isFalse);
      expect(OrientationEcran.verrouille(884), isFalse);
      expect(OrientationEcran.verrouille(0), isFalse);
    });

    testWidgets('téléphone : portrait seulement, demandé une seule fois', (t) async {
      await monter(t, const Size(412, 915));
      expect(demandes, [
        ['DeviceOrientation.portraitUp'],
      ]);
      await monter(t, const Size(360, 780));
      expect(demandes.length, 1, reason: 'rien de neuf à dire au système');
    });

    testWidgets('téléphone tenu en paysage au lancement : ramené en portrait', (t) async {
      await monter(t, const Size(915, 412));
      expect(demandes.single, ['DeviceOrientation.portraitUp']);
    });

    testWidgets('Fold : libre une fois ouvert, verrouillé à nouveau une fois fermé', (t) async {
      await monter(t, const Size(373, 841));
      expect(demandes.last, ['DeviceOrientation.portraitUp']);
      await monter(t, const Size(884, 1104));
      expect(demandes.last, isEmpty, reason: 'ouvert : toutes les orientations');
      await monter(t, const Size(1104, 884));
      expect(demandes.length, 2, reason: 'tourner le Fold ouvert ne change rien');
      await monter(t, const Size(373, 841));
      expect(demandes.last, ['DeviceOrientation.portraitUp']);
      expect(demandes.length, 3);
    });

    testWidgets('l\'appli entière porte le verrou', (t) async {
      final b = await Banc.monter(t);
      expect(find.byType(VerrouOrientation), findsOneWidget);
      await b.fin();
    });
  });
}
