// Défauts de l'accueil relevés sur l'émulateur (CHASSE.md, zone ACCUEIL ET
// SOCLE) : contenu sous la barre d'état, photos de remplacement, fichier de
// données abîmé.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_images.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/aujourdhui/pages/aujourdhui_page.dart';
import 'package:aesthetic/features/aujourdhui/widgets/accueil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';

var _n = 0;
String _id() => 'c${_n++}';

WorkoutSession _seance(DateTime debut, {List<SessionMedia> medias = const [], String nom = 'Push'}) => WorkoutSession(
      id: _id(),
      nom: nom,
      debut: debut,
      fin: debut.add(const Duration(minutes: 66)),
      exercices: [
        SessionExercise(
          id: _id(),
          exerciseId: 'developpe-couche',
          series: [for (var i = 0; i < 4; i++) WorkoutSet(id: _id(), poids: 70, reps: 6, fait: true)],
        ),
      ],
      medias: medias,
    );

Future<AppData> _donnees(List<WorkoutSession> seances) async {
  final data = AppData(Store.memory(), demo: false);
  await data.loadAll();
  await data.profile.save(UserProfile(id: 'u', prenom: 'Tristan', creeLe: DateTime(2026, 1, 1), poidsKg: 77, tailleCm: 181));
  await data.sessions.addAll(seances);
  return data;
}

void main() {
  setUpAll(preparerAssets);
  final now = DateTime(2026, 10, 2, 12);

  group('zone haute (9)', () {
    testWidgets('le contenu défile sous une bande opaque, pas sous la barre d\'état', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([
            for (var j = 0; j < 5; j++) _seance(DateTime(2026, 10, 1, 18).subtract(Duration(days: j))),
          ])))!;
      t.view.padding = const FakeViewPadding(top: 48);
      addTearDown(t.view.resetPadding);
      await rendreAccueil(t, data, 'chasse-zone-haute-avant', const Size(360, 780), now);

      final bande = find.byKey(const ValueKey('zone-haute'));
      expect(bande, findsOneWidget);
      expect(t.getRect(bande), const Rect.fromLTWH(0, 0, 360, 48));
      expect(t.widget<ColoredBox>(bande).color, AppTokens.bg);

      // Au repos, rien ne commence dans la bande.
      expect(t.getRect(find.byType(EnTeteAccueil)).top, greaterThanOrEqualTo(48));

      await t.drag(find.byType(ListView).first, const Offset(0, -520));
      await t.pumpAndSettle();
      await t.runAsync(() => rendreCapture(t, 'chasse-zone-haute-defile'));
      // Du contenu passe derrière la bande, qui se peint par-dessus.
      final dessous = [for (final e in find.byType(CarteSeance).evaluate()) (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy];
      expect(dessous.any((y) => y < 48), isTrue, reason: 'une carte a défilé plus haut que la bande');
      final pile = t.widget<Stack>(find.ancestor(of: bande, matching: find.byType(Stack)).first);
      expect(pile.children.last, isA<Positioned>(), reason: 'la bande est le dernier enfant, donc au-dessus');
      // Un appui dans la bande ne déclenche rien et ne bloque pas le défilement.
      expect(find.ancestor(of: bande, matching: find.byType(IgnorePointer)), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('sans barre d\'état (rendu de test), la bande ne prend pas de place', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([_seance(DateTime(2026, 10, 1, 18))])))!;
      await rendreAccueil(t, data, 'chasse-zone-haute-zero', const Size(360, 780), now);
      expect(t.getSize(find.byKey(const ValueKey('zone-haute'))).height, 0);
    });
  });

  group('photos de remplacement (10)', () {
    testWidgets('fichier absent : dégradé sombre et pictogramme discret, pas de bloc gris', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([
            _seance(DateTime(2026, 10, 1, 18), medias: const [SessionMedia(chemin: 'absente/seule.jpg')]),
            _seance(DateTime(2026, 9, 30, 18), medias: const [
              SessionMedia(chemin: 'absente/1.jpg'),
              SessionMedia(chemin: 'absente/2.jpg'),
            ]),
          ])))!;
      await rendreAccueil(t, data, 'chasse-photo-absente', const Size(360, 1100), now);
      final picto = find.byType(IconeHaltere);
      expect(picto, findsWidgets);
      for (final e in picto.evaluate()) {
        final w = e.widget as IconeHaltere;
        if (w.size != 34) continue;
        expect(w.color!.a, lessThan(0.7), reason: 'pictogramme en retrait');
      }
      expect(t.takeException(), isNull);
    });

    test('image de la démo : sombre partout, haltère petit et à peine plus clair', () async {
      final dossier = Directory.systemTemp.createTempSync('aesthetic_demo_images_');
      addTearDown(() => dossier.deleteSync(recursive: true));
      final chemin = DemoImages.haltere(dossier, 'demo_seance_0_0');
      if (Platform.environment['RENDUS'] != null) {
        for (var v = 0; v < 3; v++) {
          final f = File(DemoImages.haltere(dossier, 'variante_$v', variante: v));
          (File('build/rendus/aujourdhui/chasse-image-demo-$v.png')..parent.createSync(recursive: true)).writeAsBytesSync(f.readAsBytesSync());
        }
      }
      final codec = await ui.instantiateImageCodec(File(chemin).readAsBytesSync());
      final image = (await codec.getNextFrame()).image;
      expect(image.width, DemoImages.largeur);
      expect(image.height, DemoImages.hauteur);
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int gris(int x, int y) => rgba.getUint8((y * image.width + x) * 4);
      var max = 0;
      var clairs = 0;
      for (var y = 0; y < image.height; y += 4) {
        for (var x = 0; x < image.width; x += 4) {
          final g = gris(x, y);
          if (g > max) max = g;
          if (g > 55) clairs++;
        }
      }
      expect(max, lessThan(80), reason: 'aucun gris clair : l\'ancien dessin montait à 112');
      // Le bas de l'image est presque noir, le haut un peu plus clair.
      expect(gris(270, 700), lessThan(20));
      expect(gris(80, 20), greaterThan(gris(270, 700)));
      // Le pictogramme est au centre et n'occupe qu'une petite part de l'image.
      expect(gris(270, 360), greaterThan(55));
      final part = clairs / ((image.width / 4) * (image.height / 4));
      expect(part, lessThan(0.06));
      expect(part, greaterThan(0.005));
    });

    test('une démo déjà installée voit ses anciennes images redessinées, une seule fois', () {
      final dossier = Directory.systemTemp.createTempSync('aesthetic_demo_refresh_');
      addTearDown(() => dossier.deleteSync(recursive: true));
      final ancienne = File('${dossier.path}${Platform.pathSeparator}demo_seance_1_0.png')..writeAsBytesSync([1, 2, 3]);
      final autre = File('${dossier.path}${Platform.pathSeparator}photo_perso.png')..writeAsBytesSync([9, 9]);
      final silhouette = File('${dossier.path}${Platform.pathSeparator}demo_photo_0.png')..writeAsBytesSync([7]);

      DemoImages.rafraichir(dossier);
      expect(ancienne.lengthSync(), greaterThan(1000), reason: 'redessinée');
      expect(autre.readAsBytesSync(), [9, 9], reason: 'les fichiers de l\'utilisateur ne sont pas touchés');
      expect(silhouette.readAsBytesSync(), [7], reason: 'les photos de progression non plus');

      // Seconde passe : la marque de version évite de tout refaire.
      ancienne.writeAsBytesSync([4]);
      DemoImages.rafraichir(dossier);
      expect(ancienne.readAsBytesSync(), [4]);

      // Dossier absent : rien, pas d'erreur.
      DemoImages.rafraichir(Directory('${dossier.path}${Platform.pathSeparator}absent'));
    });
  });

  group('fichier de données abîmé', () {
    test('la liste réunit les fichiers illisibles et les dépôts en échec', () async {
      final data = AppData(Store.memory());
      await data.loadAll();
      expect(fichiersAbimes(data.store, data), isEmpty);
      data.store.abimes['seances'] = '/data/user/0/app/donnees/seances.json.abime';
      data.store.abimes['routines'] = '';
      data.erreursChargement['seances'] = StateError('x');
      data.erreursChargement['profil'] = StateError('y');
      final liste = fichiersAbimes(data.store, data);
      expect([for (final f in liste) f.nom], ['seances', 'routines', 'profil']);
      expect(liste.first.libelle, 'tes séances');
      expect(liste.first.copie, endsWith('seances.json.abime'));
      expect(const FichierAbime('inconnu', '').libelle, '« inconnu »');
    });

    testWidgets('l\'accueil le dit et montre où est la copie de secours', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([_seance(DateTime(2026, 10, 1, 18))])))!;
      data.store.abimes['seances'] = '/data/user/0/fr.aesthetic/app_flutter/donnees/seances.json.abime';
      data.store.abimes['mesures'] = '/data/user/0/fr.aesthetic/app_flutter/donnees/mesures.json.abime.1759400000000';
      for (final (nom, taille) in [('360', const Size(360, 900)), ('700', const Size(700, 900))]) {
        await rendreAccueil(t, data, 'chasse-fichier-abime-$nom', taille, now);
        expect(find.byType(AlerteDonnees), findsOneWidget);
        expect(find.text('Des fichiers de données sont abîmés'), findsOneWidget);
        expect(find.textContaining('tes séances et tes mensurations'), findsOneWidget);
        expect(find.textContaining('Rien n\'a été effacé'), findsOneWidget);
        final chemins = t.widget<SelectableText>(find.byType(SelectableText)).data!;
        expect(chemins, contains('seances.json.abime'));
        expect(chemins, contains('mesures.json.abime.1759400000000'));
        expect(chemins, contains('Dossier : /data/user/0/fr.aesthetic/app_flutter/donnees'));
        expect(t.takeException(), isNull, reason: 'aucun débordement en $nom');
      }
      // Sous l'en-tête, avant la carte de la semaine.
      expect(t.getRect(find.byType(AlerteDonnees)).top, greaterThan(t.getRect(find.byType(EnTeteAccueil)).bottom));
      expect(t.getRect(find.byType(AlerteDonnees)).bottom, lessThan(t.getRect(find.text('Cette semaine')).top));

      await t.tap(find.text('Compris'));
      await t.pumpAndSettle();
      expect(find.byType(AlerteDonnees), findsNothing);
      expect(find.byType(AujourdhuiPage), findsOneWidget);
    });

    testWidgets('un seul fichier, sans copie possible : le message le dit', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([])))!;
      data.store.abimes['routines'] = '';
      await rendreAccueil(t, data, 'chasse-fichier-abime-sans-copie', const Size(360, 900), now);
      expect(find.text('Un fichier de données est abîmé'), findsOneWidget);
      expect(find.textContaining('tes routines'), findsOneWidget);
      expect(find.textContaining('Aucune copie de secours'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('tout a été lu : aucune alerte', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([_seance(DateTime(2026, 10, 1, 18))])))!;
      await rendreAccueil(t, data, 'chasse-fichier-sain', const Size(360, 900), now);
      expect(find.byType(AlerteDonnees), findsNothing);
    });
  });
}
