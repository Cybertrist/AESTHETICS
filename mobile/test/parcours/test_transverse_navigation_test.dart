import 'package:aesthetic/app/router.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/aujourdhui/pages/aujourdhui_page.dart';
import 'package:aesthetic/features/entrainer/accueil/entrainer_page.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/pages/exercise_browser.dart';
import 'package:aesthetic/features/profil/pages/profil_page.dart';
import 'package:aesthetic/features/profil/pages/reglages_page.dart';
import 'package:aesthetic/features/progres/ui/bilan/bilan_story_page.dart';
import 'package:aesthetic/features/progres/ui/calendrier_page.dart';
import 'package:aesthetic/features/progres/ui/progres_page.dart';
import 'package:aesthetic/features/seance/pages/seance_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_transverse_banc.dart';

/// Navigation de l'appli entière : bouton retour du téléphone, onglets,
/// pages plein écran, liens profonds, adresse inconnue, barre de la séance
/// en cours.
///
/// Les tests marqués `skip` reproduisent un défaut connu d'un module
/// (décrit dans le motif) : ils échouent tant que le module ne l'a pas
/// corrigé, et sont à réactiver ensuite.
void main() {
  bool visible(Finder f) => f.hitTestable().evaluate().isNotEmpty;

  group('bouton retour du téléphone', () {
    testWidgets('depuis la racine d\'un onglet : retour à l\'accueil, puis sortie', (t) async {
      final b = await Banc.monter(t);
      for (final o in ['Entraînement', 'Progrès', 'Profil']) {
        await b.onglet(o);
        expect(b.ongletActif, o);
        await b.retourSysteme();
        expect(b.sorties, 0, reason: 'le retour depuis $o ne ferme pas l\'appli');
        expect(b.ongletActif, 'Accueil', reason: 'le retour depuis $o ramène à l\'accueil');
        expect(visible(find.byType(AujourdhuiPage)), isTrue);
      }
      await b.retourSysteme();
      expect(b.sorties, 1, reason: 'depuis l\'accueil, le retour ferme l\'appli');
      expect(t.takeException(), isNull);
      await b.fin();
    });

    testWidgets('dépile la sous-page d\'un onglet avant de changer d\'onglet', (t) async {
      final b = await Banc.monter(t);
      await b.onglet('Progrès');
      await b.pousser('/progres/calendrier');
      expect(visible(find.byType(CalendrierPage)), isTrue);
      expect(visible(find.byType(AppBottomNav)), isTrue, reason: 'la barre reste sous une sous-page d\'onglet');
      await b.retourSysteme();
      expect(visible(find.byType(ProgresPage)), isTrue);
      expect(b.ongletActif, 'Progrès');
      expect(b.sorties, 0);
      await b.fin();
    });

    testWidgets('referme une page plein écran et rend l\'onglet d\'origine', (t) async {
      final b = await Banc.monter(t);
      await b.onglet('Profil');
      await b.pousser('/reglages');
      expect(visible(find.byType(ReglagesPage)), isTrue);
      expect(visible(find.byType(AppBottomNav)), isFalse, reason: 'les réglages couvrent la barre');
      await b.retourSysteme();
      expect(visible(find.byType(ProfilPage)), isTrue);
      expect(b.ongletActif, 'Profil');

      await b.onglet('Accueil');
      final hier = DateTime(DateTime.now().year, DateTime.now().month - 1);
      await b.pousser('/progres/bilan?mois=${hier.year}-${hier.month}');
      expect(visible(find.byType(BilanStoryPage)), isTrue);
      await b.retourSysteme();
      expect(visible(find.byType(AujourdhuiPage)), isTrue, reason: 'le bilan ouvert de l\'accueil y revient');
      expect(b.ongletActif, 'Accueil');
      expect(b.sorties, 0);
      expect(t.takeException(), isNull);
      await b.fin();
    });

    testWidgets('une page ouverte seule (lien profond) revient à l\'accueil au lieu de fermer l\'appli', (t) async {
      final b = await Banc.monter(t);
      for (final lien in ['/reglages', '/seance/historique', '/seance/resume/inconnu', '/sante']) {
        await b.aller(lien);
        await b.retourSysteme();
        expect(b.sorties, 0, reason: lien);
        expect(b.lieu, '/', reason: lien);
        expect(visible(find.byType(AujourdhuiPage)), isTrue, reason: lien);
      }
      expect(t.takeException(), isNull);
      await b.fin();
    });
  });

  group('onglets', () {
    testWidgets('chaque onglet garde sa pile et son état ; le retoucher revient à sa racine', (t) async {
      final b = await Banc.monter(t);
      await b.onglet('Entraînement');
      await t.tap(find.descendant(of: find.byType(SelecteurSegmente<VoletEntrainer>), matching: find.text('Exercices')));
      await b.pose();
      expect(visible(find.byType(CarteExercice)), isTrue);
      await b.onglet('Progrès');
      await b.pousser('/progres/calendrier');
      await b.onglet('Entraînement');
      expect(visible(find.byType(CarteExercice)), isTrue, reason: 'le volet Exercices est resté ouvert');
      await b.onglet('Progrès');
      expect(visible(find.byType(CalendrierPage)), isTrue, reason: 'la sous-page de Progrès est restée ouverte');
      await b.onglet('Progrès');
      expect(visible(find.byType(ProgresPage)), isTrue, reason: 'retoucher l\'onglet revient à sa racine');
      expect(visible(find.byType(CalendrierPage)), isFalse);
      expect(t.takeException(), isNull);
      await b.fin();
    });

    testWidgets('sur écran large, le rail remplace la barre et mène aux mêmes onglets', (t) async {
      final b = await Banc.monter(t, taille: const Size(900, 800));
      expect(find.byType(AppNavRail), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);
      for (final (o, page) in [('Entraînement', EntrainerPage), ('Progrès', ProgresPage), ('Profil', ProfilPage), ('Accueil', AujourdhuiPage)]) {
        await b.onglet(o);
        expect(visible(find.byType(page)), isTrue, reason: o);
      }
      await b.capture('rail-900');
      expect(t.takeException(), isNull);
      await b.fin();
    });
  });

  group('adresses', () {
    testWidgets('une adresse inconnue montre une page en français qui ramène à l\'accueil', (t) async {
      final b = await Banc.monter(t);
      for (final lien in ['/nimporte/quoi', '/reglages/inconnu', '/progres/inconnu/x']) {
        await b.aller(lien);
        expect(find.byType(PageIntrouvable), findsOneWidget, reason: lien);
        expect(find.textContaining('Page Not Found'), findsNothing);
        await b.capture('page-introuvable');
        await t.tap(find.text('Revenir à l\'accueil'));
        await b.pose();
        expect(b.lieu, '/');
        await b.aller(lien);
        await b.retourSysteme();
        expect(b.lieu, '/', reason: 'retour du téléphone depuis $lien');
        expect(b.sorties, 0);
      }
      expect(t.takeException(), isNull);
      await b.fin();
    });

    testWidgets('un lien vers un identifiant inconnu ne lève rien et dit ce qui manque', (t) async {
      final b = await Banc.monter(t);
      const liens = {
        '/seance/historique/inconnu': 'Séance introuvable',
        '/seance/resume/inconnu': 'Séance introuvable',
        '/seance/equivalent/inconnu': 'Séance introuvable',
        '/seance/partager/inconnu': 'Séance introuvable',
        '/seance/apercu/inconnu': 'Routine introuvable',
        '/seance/routine/inconnu': 'Impossible de démarrer',
        '/seance/terminer': 'Aucune séance en cours',
        '/entrainer/exercices/inconnu': 'Exercice introuvable',
        '/entrainer/routines/inconnu': 'Routine introuvable',
        '/entrainer/programmes/inconnu': 'Programme introuvable',
        '/progres/seance/inconnu': 'Séance introuvable',
        '/progres/muscles/inconnu': 'Ce muscle n\'existe pas',
        '/profil/photos/voir/inconnu': 'Cette photo n\'existe plus',
        '/profil/mensurations/saisie?id=inconnu': 'Cette saisie n\'existe plus',
      };
      for (final e in liens.entries) {
        await b.aller('/');
        await b.aller(e.key);
        expect(t.takeException(), isNull, reason: e.key);
        expect(find.text(e.value), findsWidgets, reason: e.key);
      }
      // Paramètres illisibles : la page s'ouvre sur sa valeur par défaut.
      for (final lien in ['/progres/bilan?mois=abc', '/progres/calendrier?mois=2026-13&jour=xx', '/entrainer/muscles?muscle=inconnu', '/profil/mensurations/zone/inconnu']) {
        await b.aller('/');
        await b.aller(lien);
        expect(t.takeException(), isNull, reason: lien);
        expect(find.byType(PageIntrouvable), findsNothing, reason: lien);
      }
      await b.fin();
    });

    testWidgets('sans profil, toute adresse mène à l\'inscription et le retour ferme l\'appli', (t) async {
      final b = await Banc.monter(t, profil: false);
      expect(b.lieu, startsWith('/bienvenue'));
      for (final lien in ['/', '/progres', '/reglages', '/seance']) {
        await b.aller(lien);
        expect(b.lieu, startsWith('/bienvenue'), reason: lien);
      }
      await b.retourSysteme();
      expect(b.lieu, startsWith('/bienvenue'));
      expect(t.takeException(), isNull);
      await b.fin();
    });

    testWidgets(
      'revenir d\'une page dont le parent n\'est qu\'une redirection ne casse pas le routeur',
      (t) async {
        final b = await Banc.monter(t);
        // Lien direct vers un programme (page plein écran sous `/entrainer/programmes`).
        await b.aller('/entrainer/programmes/${b.data.programs.programs.first.id}');
        expect(t.takeException(), isNull);
        await b.retourSysteme();
        expect(t.takeException(), isNull);
        expect(visible(find.byType(EntrainerPage)), isTrue);
        await b.fin();
      },
      // DÉFAUT CONNU, module ENTRAÎNER (routines_routes.dart) : `/entrainer/programmes` n'a
      // qu'un `redirect` ; quand son enfant plein écran (`:id`) est dépilé après un `go`,
      // go_router lève « !matchList.last.route.redirectOnly » et l'écran reste cassé. Sans
      // effet tant que la page est ouverte par `push`.
      skip: true,
    );

    testWidgets(
      'Profil > Calendrier puis retour revient au profil',
      (t) async {
        final b = await Banc.monter(t);
        await b.onglet('Profil');
        await t.tap(find.descendant(of: find.byType(ProfilPage), matching: find.text('Calendrier')));
        await b.pose();
        expect(visible(find.byType(CalendrierPage)), isTrue);
        await b.retourSysteme();
        expect(visible(find.byType(ProfilPage)), isTrue);
        await b.fin();
      },
      // DÉFAUT CONNU, module PROFIL (profil_page.dart, lignes Records et Calendrier) :
      // `context.go` change d'onglet, le retour mène à la racine de Progrès, pas au profil.
      skip: true,
    );
  });

  group('texte agrandi du système', () {
    testWidgets('suivi jusqu\'à 1,3, plafonné au-delà', (t) async {
      for (final (systeme, attendu) in [(1.0, 1.0), (1.15, 1.15), (1.3, 1.3), (1.6, 1.3), (2.0, 1.3)]) {
        t.platformDispatcher.textScaleFactorTestValue = systeme;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final b = await Banc.monter(t);
        final facteur = MediaQuery.textScalerOf(t.element(find.byType(AujourdhuiPage))).scale(100) / 100;
        expect(facteur, closeTo(attendu, 0.001), reason: 'système à $systeme');
        expect(t.takeException(), isNull, reason: 'accueil au texte $systeme');
        await b.fin();
      }
    });
  });

  group('barre « Entraînement en cours »', () {
    Future<Banc> avecSeance(WidgetTester t, {Size taille = const Size(412, 915)}) async {
      final b = await Banc.monter(t, taille: taille);
      await t.runAsync(() => b.data.sessions.startFromRoutine(b.data.routines.routines.first));
      await b.pose();
      return b;
    }

    testWidgets('visible sur chaque onglet et leurs sous-pages, au téléphone et sur le Fold ouvert', (t) async {
      for (final taille in const [Size(412, 915), Size(360, 780), Size(900, 800)]) {
        final b = await avecSeance(t, taille: taille);
        for (final o in ['Accueil', 'Entraînement', 'Progrès', 'Profil']) {
          await b.onglet(o);
          expect(visible(find.text('Entraînement en cours')), isTrue, reason: '$o en ${taille.width}');
          expect(visible(find.text('Reprendre')), isTrue, reason: '$o en ${taille.width}');
          expect(visible(find.text('Abandonner')), isTrue, reason: '$o en ${taille.width}');
        }
        await b.capture('mini-barre-${taille.width.round()}');
        await b.onglet('Progrès');
        await b.pousser('/progres/calendrier');
        expect(visible(find.text('Entraînement en cours')), isTrue, reason: 'sous-page d\'onglet');
        expect(t.takeException(), isNull, reason: 'aucun débordement en ${taille.width}');
        await b.fin();
      }
    });

    testWidgets('« Reprendre » rouvre la séance, le retour la réduit sans la perdre', (t) async {
      final b = await avecSeance(t);
      await t.tap(find.text('Reprendre'));
      await b.pose();
      expect(visible(find.byType(SeancePage)), isTrue);
      expect(b.lieu, '/seance');
      await b.retourSysteme();
      expect(visible(find.byType(SeancePage)), isFalse);
      expect(b.data.sessions.active, isNotNull, reason: 'le retour ne ferme pas la séance');
      expect(visible(find.text('Entraînement en cours')), isTrue);
      expect(t.takeException(), isNull);
      await b.fin();
    });

    testWidgets('« Abandonner » demande confirmation, puis la barre disparaît', (t) async {
      final b = await avecSeance(t);
      await t.tap(find.text('Abandonner'));
      await b.pose();
      expect(find.text('Abandonner la séance ?'), findsOneWidget);
      // Retour du téléphone : ferme le dialogue, garde la séance.
      await b.retourSysteme();
      expect(find.text('Abandonner la séance ?'), findsNothing);
      expect(b.data.sessions.active, isNotNull);
      await t.tap(find.text('Abandonner'));
      await b.pose();
      await t.tap(find.text('Abandonner').last);
      await b.pose();
      expect(b.data.sessions.active, isNull);
      expect(find.byType(SeanceMiniBarre), findsOneWidget);
      expect(find.text('Entraînement en cours'), findsNothing);
      expect(t.takeException(), isNull);
      await b.fin();
    });

    testWidgets('un second appui sur « Reprendre » pendant l\'ouverture n\'empile pas deux séances', (t) async {
      final b = await avecSeance(t);
      await t.tap(find.text('Reprendre'));
      await t.pump(const Duration(milliseconds: 40));
      // La page qui s'ouvre capte déjà les gestes : le second appui tombe dessus.
      await t.tapAt(t.getCenter(find.text('Reprendre', skipOffstage: false).first), pointer: 7);
      await b.pose();
      expect(find.byType(SeancePage, skipOffstage: false), findsOneWidget);
      t.takeException();
      await b.fin();
    });

    testWidgets(
      'reste visible par-dessus une page plein écran (réglages, fiche, mensurations)',
      (t) async {
        final b = await avecSeance(t);
        for (final plein in ['/reglages', '/profil/mensurations', '/entrainer/exercices/developpe-couche']) {
          await b.pousser(plein);
          expect(visible(find.text('Entraînement en cours')), isTrue, reason: plein);
          await b.retourSysteme();
        }
        await b.fin();
      },
    );
  });
}
