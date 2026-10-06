import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/features/progres/logic/tableau.dart';
import 'package:aesthetic/features/progres/progres_paths.dart';
import 'package:aesthetic/features/progres/ui/bilan/bilan_story_page.dart';
import 'package:aesthetic/features/progres/ui/bilan/couleurs.dart';
import 'package:aesthetic/features/progres/ui/bilan/pages.dart';
import 'package:aesthetic/features/progres/ui/bilan/toile.dart';
import 'package:aesthetic/features/progres/ui/progres_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_bilan_banc.dart';
import 'test_bilan_jeux.dart';

Finder _pageN(int n) => find.bySemanticsLabel('Page $n sur 10');

/// Navigation, ouverture directe, export en image et lisibilité du bilan.
void main() {
  group('navigation au toucher', () {
    testWidgets('avancer jusqu\'au bout, reculer jusqu\'au début, les bords ne font rien', (t) async {
      await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan);
      expect(_pageN(1), findsOneWidget);
      // À gauche sur la première page : on y reste.
      await t.tapAt(const Offset(40, 400));
      await t.pump(const Duration(milliseconds: 300));
      expect(_pageN(1), findsOneWidget);
      for (var i = 2; i <= 10; i++) {
        await t.tapAt(const Offset(300, 400));
        await t.pump(const Duration(milliseconds: 300));
        expect(_pageN(i), findsOneWidget);
      }
      // À droite sur la dernière : on y reste, rien ne casse.
      await t.tapAt(const Offset(300, 400));
      await t.pump(const Duration(milliseconds: 300));
      expect(_pageN(10), findsOneWidget);
      expect(find.byType(PageResume), findsOneWidget);
      for (var i = 9; i >= 1; i--) {
        await t.tapAt(const Offset(40, 400));
        await t.pump(const Duration(milliseconds: 300));
        expect(_pageN(i), findsOneWidget);
      }
      expect(find.byType(PageOuverture), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('le tiers gauche recule, le reste avance, sur toute la hauteur', (t) async {
      await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan, page: PageBilan.volume);
      // 360 de large : le tiers s'arrête à 120.
      await t.tapAt(const Offset(121, 300));
      await t.pump(const Duration(milliseconds: 300));
      expect(_pageN(5), findsOneWidget);
      await t.tapAt(const Offset(119, 300));
      await t.pump(const Duration(milliseconds: 300));
      expect(_pageN(4), findsOneWidget);
      // Sur le contenu de la page (les barres) comme dans le vide du haut.
      await t.tapAt(const Offset(200, 500));
      await t.pump(const Duration(milliseconds: 300));
      expect(_pageN(5), findsOneWidget);
      await t.tapAt(const Offset(200, 90));
      await t.pump(const Duration(milliseconds: 300));
      expect(_pageN(6), findsOneWidget);
      // Sur la marque, en bas.
      await t.tap(find.textContaining('STHETIC', findRichText: true), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 300));
      expect(_pageN(7), findsOneWidget);
    });

    testWidgets('appuis très rapprochés : une page par appui, jamais hors bornes', (t) async {
      await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan, page: PageBilan.records);
      for (var i = 0; i < 6; i++) {
        await t.tapAt(const Offset(300, 400));
      }
      await t.pump(const Duration(milliseconds: 400));
      expect(_pageN(10), findsOneWidget);
      for (var i = 0; i < 15; i++) {
        await t.tapAt(const Offset(30, 400));
      }
      await t.pump(const Duration(milliseconds: 400));
      expect(_pageN(1), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('lecteur d\'écran : la barre de segments change de page', (t) async {
      final poignee = t.ensureSemantics();
      await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan, page: PageBilan.volume);
      final avant = t.getSemantics(_pageN(4));
      expect(avant.getSemanticsData().hasAction(ui.SemanticsAction.increase), isTrue);
      expect(avant.getSemanticsData().hasAction(ui.SemanticsAction.decrease), isTrue);
      t.semantics.increase(find.semantics.byLabel('Page 4 sur 10'));
      await t.pump(const Duration(milliseconds: 300));
      expect(_pageN(5), findsOneWidget);
      t.semantics.decrease(find.semantics.byLabel('Page 5 sur 10'));
      await t.pump(const Duration(milliseconds: 300));
      expect(_pageN(4), findsOneWidget);
      // La croix et « Partager » ont un libellé et une cible d'au moins 48.
      expect(find.byTooltip('Fermer le bilan'), findsOneWidget);
      expect(t.getSize(find.byTooltip('Fermer le bilan')).shortestSide, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('Partager cette page'), findsOneWidget);
      expect(t.getSize(find.bySemanticsLabel('Partager cette page')).height, greaterThanOrEqualTo(48));
      poignee.dispose();
    });

    testWidgets('première et dernière page au lecteur d\'écran : pas d\'action impossible', (t) async {
      final poignee = t.ensureSemantics();
      await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan);
      expect(t.getSemantics(_pageN(1)).getSemanticsData().hasAction(ui.SemanticsAction.decrease), isFalse);
      expect(t.getSemantics(_pageN(1)).getSemanticsData().hasAction(ui.SemanticsAction.increase), isTrue);
      await allerA(t, PageBilan.resume);
      expect(t.getSemantics(_pageN(10)).getSemanticsData().hasAction(ui.SemanticsAction.increase), isFalse);
      poignee.dispose();
    });
  });

  group('routes', () {
    testWidgets('la croix rend la main à Progrès', (t) async {
      final banc = await monterRouteur(t, sessions: jeuNormal(), chemin: ProgresPaths.racine, taille: const Size(360, 1700));
      banc.router!.push(ProgresPaths.bilan(moisBilan));
      await poser(t);
      expect(find.byType(BilanStoryPage), findsOneWidget);
      await t.tap(find.byTooltip('Fermer le bilan'));
      await poser(t);
      expect(find.byType(BilanStoryPage), findsNothing);
      expect(find.byType(ProgresPage), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('ouvert directement (lien) : la croix mène à Progrès, pas dans le vide', (t) async {
      await monterRouteur(t, sessions: jeuNormal(), chemin: ProgresPaths.bilan(moisBilan, 'serie'), taille: const Size(360, 1700));
      expect(find.byType(BilanStoryPage), findsOneWidget);
      expect(_pageN(6), findsOneWidget);
      await t.tap(find.byTooltip('Fermer le bilan'));
      await poser(t);
      expect(find.byType(BilanStoryPage), findsNothing);
      expect(find.byType(ProgresPage), findsOneWidget);
    });

    testWidgets('?page= : chaque nom ouvre sa page ; un nom inconnu, vide ou mal écrit ouvre la première', (t) async {
      final banc = await monterRouteur(t, sessions: jeuNormal(), chemin: ProgresPaths.racine, taille: const Size(360, 1700));
      for (final p in PageBilan.values) {
        banc.router!.go(ProgresPaths.bilan(moisBilan, p.name));
        await poser(t, tours: 2);
        expect(_pageN(p.index + 1), findsOneWidget, reason: p.name);
        expect(t.takeException(), isNull, reason: p.name);
      }
      for (final p in ['inconnue', '', 'Serie', '3', 'serie%20']) {
        banc.router!.go('/progres/bilan?mois=2026-09&page=$p');
        await poser(t, tours: 2);
        expect(_pageN(1), findsOneWidget, reason: '« $p »');
      }
    });

    testWidgets('le même écran rouvert sur une autre page change bien de page', (t) async {
      final banc = await monterRouteur(t, sessions: jeuNormal(), chemin: ProgresPaths.bilan(moisBilan, 'volume'));
      expect(_pageN(4), findsOneWidget);
      banc.router!.go(ProgresPaths.bilan(moisBilan, 'serie'));
      await poser(t, tours: 2);
      expect(_pageN(6), findsOneWidget);
    });

    testWidgets('?mois= invalide : le mois précédent ; à venir : le mois en cours ; rien ne lève', (t) async {
      final banc = await monterRouteur(t, sessions: jeuNormal(), chemin: ProgresPaths.racine, taille: const Size(360, 1700));
      final now = DateTime.now();
      final precedent = DateTime(now.year, now.month - 1);
      String titre(DateTime m) => '${Calculs.moisNom(m).toUpperCase()}\n${m.year}';

      for (final m in ['2026-13', 'abc', '', '2026', '2026-00', '999999999-01', '2026-09-01', '-1-5']) {
        banc.router!.go('/progres/bilan?mois=$m&page=seances');
        await poser(t, tours: 2);
        expect(t.takeException(), isNull, reason: '« $m »');
        expect(find.text(titre(precedent)), findsOneWidget, reason: '« $m »');
      }
      // Sans paramètre : le mois précédent aussi.
      banc.router!.go('/progres/bilan?page=seances');
      await poser(t, tours: 2);
      expect(find.text(titre(precedent)), findsOneWidget);

      // Un mois à venir n'a pas de bilan : le mois en cours.
      for (final m in ['${now.year + 4}-01', '9999-12', ProgresPaths.cle(DateTime(now.year, now.month + 1))]) {
        banc.router!.go('/progres/bilan?mois=$m&page=seances');
        await poser(t, tours: 2);
        expect(t.takeException(), isNull, reason: m);
        expect(find.text(titre(DateTime(now.year, now.month))), findsOneWidget, reason: m);
      }

      // Un mois très ancien, sans rien : il s'affiche, vide.
      banc.router!.go('/progres/bilan?mois=1999-2&page=seances');
      await poser(t, tours: 2);
      expect(find.text('FÉVRIER\n1999'), findsOneWidget);
      expect(find.text('Aucune séance ce mois.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('export en image', () {
    late List<MethodCall> partages;
    late Directory dossier;

    void brancher(WidgetTester t, {bool echec = false}) {
      partages = [];
      dossier = Directory.systemTemp.createTempSync('bilan_export');
      addTearDown(() {
        if (dossier.existsSync()) dossier.deleteSync(recursive: true);
      });
      final messager = t.binding.defaultBinaryMessenger;
      messager.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dossier.path);
      messager.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
        partages.add(call);
        if (echec) throw PlatformException(code: 'refus');
        return 'dev.fluttercommunity.plus/share/unavailable';
      });
      addTearDown(() {
        messager.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
        messager.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null);
      });
    }

    Future<void> partager(WidgetTester t) async {
      await t.tap(find.bySemanticsLabel('Partager cette page'));
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 50));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      }
      await t.pump(const Duration(milliseconds: 300));
    }

    /// Pixels RVBA de l'image exportée.
    Future<(ui.Image, ByteData)> lire(WidgetTester t, File f) async {
      late ui.Image image;
      late ByteData octets;
      await t.runAsync(() async {
        final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
        image = (await codec.getNextFrame()).image;
        octets = (await image.toByteData())!;
      });
      return (image, octets);
    }

    /// Nombre de pixels clairs (du blanc de la barre, de la croix, du
    /// bouton) dans un rectangle donné en points logiques.
    int clairs(ui.Image image, ByteData o, Rect r, {int seuil = 215}) {
      var n = 0;
      for (var y = (r.top * 3).round(); y < (r.bottom * 3).round(); y++) {
        for (var x = (r.left * 3).round(); x < (r.right * 3).round(); x++) {
          final i = (y * image.width + x) * 4;
          if (o.getUint8(i) >= seuil && o.getUint8(i + 1) >= seuil && o.getUint8(i + 2) >= seuil) n++;
        }
      }
      return n;
    }

    testWidgets('chaque page : image entière, triple définition, sans barre, ni croix, ni bouton', (t) async {
      brancher(t);
      await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan);
      const taille = Size(360, 760);
      final hautContenu = <String, double>{};
      for (final page in PageBilan.values) {
        await allerA(t, page);
        final barre = t.getRect(_pageN(page.index + 1));
        final croix = t.getRect(find.byTooltip('Fermer le bilan'));
        final bouton = t.getRect(find.bySemanticsLabel('Partager cette page'));
        final marque = t.getRect(find.textContaining('STHETIC', findRichText: true));
        partages.clear();
        await partager(t);
        expect(t.takeException(), isNull, reason: page.name);
        expect(partages.length, 1, reason: page.name);
        final f = File('${dossier.path}/bilan-2026-09-${page.name}.png');
        expect(f.existsSync(), isTrue, reason: 'fichier de ${page.name}');
        expect((partages.single.arguments as Map)['paths'], [f.path]);
        f.copySync((File('build/rendus/bilan/export-${(page.index + 1).toString().padLeft(2, '0')}-${page.name}.png')..parent.createSync(recursive: true)).path);

        final (image, o) = await lire(t, f);
        expect((image.width, image.height), (taille.width * 3, taille.height * 3), reason: page.name);
        // Ni barre de segments, ni croix, ni « Partager ».
        expect(clairs(image, o, barre.inflate(1)), 0, reason: 'barre visible sur ${page.name}');
        expect(clairs(image, o, croix.deflate(12)), 0, reason: 'croix visible sur ${page.name}');
        expect(clairs(image, o, bouton), 0, reason: 'bouton visible sur ${page.name}');
        // La marque reste, et le contenu aussi.
        expect(clairs(image, o, marque), greaterThan(300), reason: 'marque absente sur ${page.name}');
        final contenu = Rect.fromLTRB(0, croix.bottom, taille.width, marque.top);
        expect(clairs(image, o, contenu, seuil: 150), greaterThan(1500), reason: 'contenu absent sur ${page.name}');
        // Rien ne touche les bords gauche et droit (sauf le bandeau penché des favoris).
        if (page != PageBilan.favoris) {
          expect(clairs(image, o, Rect.fromLTWH(0, 0, 6, taille.height), seuil: 150), 0, reason: 'bord gauche de ${page.name}');
          expect(clairs(image, o, Rect.fromLTWH(taille.width - 6, 0, 6, taille.height), seuil: 150), 0, reason: 'bord droit de ${page.name}');
        }
        hautContenu[page.name] = contenu.top;
        image.dispose();

        // Après le partage, la barre et les boutons reviennent.
        expect(t.widget<Opacity>(find.ancestor(of: find.byTooltip('Fermer le bilan'), matching: find.byType(Opacity)).first).opacity, 1);
      }
    });

    testWidgets('double appui sur Partager : un seul partage', (t) async {
      brancher(t);
      await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan, page: PageBilan.serie);
      await t.tap(find.bySemanticsLabel('Partager cette page'));
      await t.tap(find.bySemanticsLabel('Partager cette page'));
      await t.pump(const Duration(milliseconds: 20));
      await t.tap(find.bySemanticsLabel('Partager cette page'), warnIfMissed: false);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 50));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      }
      expect(partages.length, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('toucher l\'écran pendant l\'export ne change pas la page exportée', (t) async {
      brancher(t);
      await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan, page: PageBilan.serie);
      await t.tap(find.bySemanticsLabel('Partager cette page'));
      await t.tapAt(const Offset(300, 300));
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 50));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      }
      expect(File('${dossier.path}/bilan-2026-09-serie.png').existsSync(), isTrue);
      expect(_pageN(6), findsOneWidget);
    });

    testWidgets('partage refusé par le téléphone : un message, la barre et les boutons reviennent', (t) async {
      brancher(t, echec: true);
      await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan, page: PageBilan.volume);
      await partager(t);
      expect(find.textContaining('Le partage n\'a pas abouti'), findsOneWidget);
      expect(t.widget<Opacity>(find.ancestor(of: find.byTooltip('Fermer le bilan'), matching: find.byType(Opacity)).first).opacity, 1);
      // On peut réessayer.
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(find.textContaining('partage n\'a pas abouti'), findsNothing);
      await partager(t);
      expect(partages.length, 2);
      expect(t.takeException(), isNull);
    });

    testWidgets('fermer le bilan pendant l\'export ne lève rien', (t) async {
      brancher(t);
      final banc = await monterRouteur(t, sessions: jeuNormal(), chemin: ProgresPaths.bilan(moisBilan, 'volume'));
      await t.tap(find.bySemanticsLabel('Partager cette page'));
      await t.pump(const Duration(milliseconds: 20));
      banc.router!.go(ProgresPaths.racine);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 50));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      }
      expect(find.byType(BilanStoryPage), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('lisibilité', () {
    double lum(Color c) {
      double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    double contraste(Color a, Color b) {
      final la = lum(a), lb = lum(b);
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    (Color, Color) fond(PageBilan p, Color equivalent) => switch (p) {
          PageBilan.ouverture => CouleursBilan.ouverture,
          PageBilan.seances => CouleursBilan.seances,
          PageBilan.regularite => CouleursBilan.regularite,
          PageBilan.volume => CouleursBilan.volume,
          PageBilan.equivalent => (equivalent, CouleursBilan.noir),
          PageBilan.serie => CouleursBilan.serie,
          PageBilan.muscles => CouleursBilan.muscles,
          PageBilan.records => CouleursBilan.records,
          PageBilan.favoris => CouleursBilan.favoris,
          PageBilan.resume => CouleursBilan.resume,
        };

    for (final jeu in {'normal': jeuNormal, 'extrême': jeuExtreme, 'une séance': jeuUneSeance}.entries) {
      testWidgets('contraste de chaque texte sur son fond, à sa place dans le dégradé (${jeu.key})', (t) async {
        const taille = Size(360, 760);
        final banc = await monterBilan(t, sessions: jeu.value(), exercices: exercicesExtremes(), mois: moisBilan, maintenant: maintenantBilan, taille: taille);
        final volume = Calculs.volumeDe(Calculs.entre(banc.data.sessions.sessions, moisBilan, DateTime(2026, 10)));
        final eq = equivalentPour(volume, graine: 2026 * 12 + 9, mois: true);
        final soucis = <String>[];
        for (final page in PageBilan.values) {
          await allerA(t, page);
          await t.pump(const Duration(seconds: 1));
          final (haut, bas) = fond(page, eq.couleur);
          for (final e in find.descendant(of: find.byType(BilanStoryPage), matching: find.byType(RichText)).evaluate()) {
            final rt = e.widget as RichText;
            final ro = e.renderObject! as RenderBox;
            final r = MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);
            // Le fond le plus clair que touche le texte : son bord haut.
            final f = Color.lerp(haut, bas, (r.top / (taille.height * 0.68)).clamp(0.0, 1.0))!;
            rt.text.visitChildren((span) {
              final s = span.style;
              if (span is! TextSpan || span.text == null || span.text!.trim().isEmpty || s?.color == null) return true;
              // Textes sombres : sur le bandeau clair, la pastille ou une barre, contrôlés à part.
              if (lum(s!.color!) < 0.1) return true;
              final c = Color.alphaBlend(s.color!, f);
              final ratio = contraste(c, f);
              final echelle = r.height / ro.size.height;
              final corps = (s.fontSize ?? 14) * echelle;
              final gras = (s.fontWeight ?? FontWeight.w400).value >= 700;
              final mini = corps >= 24 || (gras && corps >= 18.66) ? 3.0 : 4.5;
              if (ratio < mini) soucis.add('${page.name} : « ${span.text} » ${ratio.toStringAsFixed(2)} < $mini (corps ${corps.toStringAsFixed(1)})');
              return true;
            });
          }
        }
        expect(soucis, isEmpty, reason: soucis.join('\n'));
      });
    }

    test('couleurs fixes : écarts, cases, barres, bandeau, toile', () {
      // Les textes sombres sur leurs fonds clairs.
      expect(contraste(CouleursBilan.bandeauEncre, CouleursBilan.bandeau), greaterThan(7));
      expect(contraste(CouleursBilan.noir, CouleursBilan.encre), greaterThan(7));
      // Le chiffre noir dans une barre grise (blanc à 32 %), au plus sombre du dégradé du volume :
      // 2,7 seulement, sous le seuil de 3. C'est la maquette validée (écran 50) ; signalé, pas changé.
      // Ce garde-fou empêche au moins que ça empire.
      expect(contraste(CouleursBilan.noir, Color.alphaBlend(CouleursBilan.barre, CouleursBilan.noir)), greaterThan(2.6));
      // Dans la barre blanche du mois en cours, aucun souci.
      expect(contraste(CouleursBilan.noir, CouleursBilan.encre), greaterThan(7));
      // Case faite contre case vide, sur le vert du haut et sur le noir du bas.
      for (final f in [CouleursBilan.regularite.$1, CouleursBilan.noir]) {
        final vide = Color.alphaBlend(CouleursBilan.caseVide, f);
        expect(contraste(CouleursBilan.caseFaite, vide), greaterThan(3), reason: '$f');
      }
      // Hausse et baisse sur les fonds où elles s'affichent (au plus clair).
      for (final f in [CouleursBilan.regularite.$1, CouleursBilan.volume.$1, CouleursBilan.resume.$1]) {
        expect(contraste(CouleursBilan.hausse, f), greaterThan(3), reason: 'hausse sur $f');
      }
      // La toile du mois sur le fond bleu nuit.
      expect(contraste(CouleursBilan.toileMois, CouleursBilan.muscles.$1), greaterThan(3));
      expect(contraste(CouleursBilan.toileAvant, CouleursBilan.muscles.$1), greaterThan(3));
    });

    test('équivalents : le blanc et la couleur mise en avant se lisent sur chaque fond', () {
      for (final o in objetsEquivalents) {
        expect(contraste(CouleursBilan.encre, Color(o.couleur)), greaterThan(4.5), reason: 'blanc sur ${o.nom}');
        // La phrase est en bas, sur le noir.
        expect(contraste(Color(o.accent), CouleursBilan.noir), greaterThan(7), reason: 'accent de ${o.nom}');
      }
    });
  });

  group('toile et liste des séances : mises en page', () {
    testWidgets('en 360, la toile tient dans la page : aucun personnage ne touche le bord', (t) async {
      await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan, page: PageBilan.muscles);
      final page = t.getRect(find.byType(PageMuscles));
      final persos = find.descendant(of: find.byType(ToileMuscles), matching: find.byType(Positioned));
      expect(persos, findsNWidgets(10));
      var droite = 0.0, gauche = 1000.0;
      for (final e in persos.evaluate().skip(1)) {
        final r = MatrixUtils.transformRect((e.renderObject! as RenderBox).getTransformTo(null), Offset.zero & (e.renderObject! as RenderBox).size);
        droite = droite < r.right ? r.right : droite;
        gauche = gauche > r.left ? r.left : gauche;
      }
      expect(droite, lessThanOrEqualTo(page.right + 1));
      expect(gauche, greaterThanOrEqualTo(page.left));
    });

    test('liste des séances : pleine taille tant que ça tient, resserrée, puis résumée', () {
      // Maquette : 14 séances dans 600 de haut, corps 13,75.
      expect(PageSeances.mesure(14, 600), (13.75, 14));
      expect(PageSeances.mesure(0, 600), (13.75, 0));
      // 31 séances (une par jour) dans 560 : tout tient, un peu resserré.
      final (taille, n) = PageSeances.mesure(31, 560);
      expect(n, 31);
      expect(taille, inInclusiveRange(10, 13.75));
      // 40 séances dans 560 : les premières, le reste regroupé, jamais sous 10 de corps.
      final (t40, n40) = PageSeances.mesure(40, 560);
      expect(t40, 10);
      expect(n40, lessThan(39));
      expect(n40, greaterThan(20));
      // La hauteur totale tient : titre, lignes montrées, « et N autres », total.
      expect(75 + 17.5 + 10 + (n40 + 2) * 1.42 * t40, lessThanOrEqualTo(560));
      // Sans borne de hauteur : tout, à la taille de la maquette.
      expect(PageSeances.mesure(200, double.infinity), (13.75, 200));
      // Jamais « et 1 autres » : au moins deux séances regroupées.
      for (var k = 1; k < 120; k++) {
        for (final h in [300.0, 420.0, 560.0, 610.0]) {
          final (_, m) = PageSeances.mesure(k, h);
          expect(k - m == 0 || k - m >= 2, isTrue, reason: '$k séances dans $h : $m montrées');
          expect(m, greaterThanOrEqualTo(k == 0 ? 0 : 1));
        }
      }
    });

    testWidgets('quarante séances en 360 : la page garde sa largeur, les autres sont regroupées, les colonnes font le total', (t) async {
      await monterBilan(t, sessions: jeuQuarante(), mois: moisBilan, maintenant: maintenantBilan, page: PageBilan.seances);
      final page = t.getRect(find.byType(PageSeances));
      // Pas de rétrécissement d'un bloc : la page occupe toute la largeur (360 moins les marges).
      expect(page.width, closeTo(315, 0.5));
      final autres = find.textContaining('AUTRES SÉANCES');
      expect(autres, findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      // Le corps du texte ne descend pas sous 10.
      final style = t.widget<Text>(find.text('TOTAL')).style!;
      expect(style.fontSize, greaterThanOrEqualTo(10));
      expect(t.getSize(find.text('TOTAL')).height, greaterThanOrEqualTo(14));
      expect(t.takeException(), isNull);
    });

    testWidgets('police du téléphone agrandie (×1,6) : l\'affiche ne bouge pas, rien n\'est rogné', (t) async {
      final banc = await monterBilan(t, sessions: jeuNormal(), mois: moisBilan, maintenant: maintenantBilan, echelleTexte: 1.6);
      final soucis = <String>[];
      for (final page in PageBilan.values) {
        await allerA(t, page);
        final e = t.takeException();
        if (e != null) soucis.add('${page.name} : $e');
        soucis.addAll(banc.textesRognes(t).map((x) => '${page.name} : rogné « $x »'));
        soucis.addAll(banc.textesHorsEcran(t, sauf: {'TOP EXERCICES'}).map((x) => '${page.name} : hors écran « $x »'));
      }
      expect(soucis, isEmpty, reason: soucis.join('\n'));
    });
  });
}
