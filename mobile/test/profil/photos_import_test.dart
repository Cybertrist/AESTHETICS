import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/profil/data/mensurations.dart';
import 'package:aesthetic/features/profil/photos/exif.dart';
import 'package:aesthetic/features/profil/photos/import_photos.dart';
import 'package:aesthetic/features/profil/photos/photos_page.dart';
import 'package:aesthetic/features/profil/routes.dart';
import 'package:aesthetic/features/profil/widgets/maquette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'images_photos.dart';
import 'test_profil_banc.dart';

/// Ajout d'anciennes photos depuis la galerie : date lue dans la photo,
/// écran de confirmation, tri par date de prise de vue, correction de la
/// date et de l'angle d'une photo enregistrée.
void main() {
  final now = DateTime(2026, 10, 2, 15);
  DateTime? exif(Uint8List o) => DatePhoto.exif(o, maintenant: now);

  group('date de prise de vue lue dans la photo', () {
    test('les images de test sont de vraies images', () async {
      for (final o in [jpegNu, jpegAutreEncodeur, jpegAvecExif(tiff(originale: '2025:06:14 18:32:07'))]) {
        final codec = await ui.instantiateImageCodec(o);
        final image = (await codec.getNextFrame()).image;
        expect((image.width, image.height), (8, 8));
        image.dispose();
        codec.dispose();
      }
    });

    test('date originale, sinon numérisée, sinon celle du fichier', () {
      const o = '2025:06:14 18:32:07', n = '2025:06:15 09:00:00', f = '2025:07:01 10:00:00';
      for (final ordre in [Endian.big, Endian.little]) {
        expect(exif(jpegAvecExif(tiff(originale: o, numerisee: n, fichier: f, ordre: ordre))), DateTime(2025, 6, 14, 18, 32, 7));
        expect(exif(jpegAvecExif(tiff(numerisee: n, fichier: f, ordre: ordre))), DateTime(2025, 6, 15, 9));
        expect(exif(jpegAvecExif(tiff(fichier: f, ordre: ordre))), DateTime(2025, 7, 1, 10));
        expect(exif(jpegAvecExif(tiff(originale: o, ordre: ordre))), DateTime(2025, 6, 14, 18, 32, 7));
      }
      // Fichier écrit par un autre encodeur que celui du test.
      expect(exif(jpegAutreEncodeur), DateTime(2025, 6, 14, 18, 32, 7));
    });

    test('sans EXIF : pas de date', () {
      expect(exif(jpegNu), isNull);
      expect(exif(Uint8List(0)), isNull);
      expect(exif(Uint8List.fromList([0xFF, 0xD8])), isNull);
      expect(exif(Uint8List.fromList(List.filled(64, 0))), isNull);
      // Un bloc EXIF sans aucune date.
      expect(exif(jpegAvecExif(tiff())), isNull);
    });

    test('formats de date variés', () {
      DateTime? d(String s) => exif(jpegAvecExif(tiff(originale: s)));
      expect(d('2025:06:14 18:32:07'), DateTime(2025, 6, 14, 18, 32, 7));
      expect(d('2025-06-14 18:32:07'), DateTime(2025, 6, 14, 18, 32, 7));
      expect(d('2025/06/14 18:32:07'), DateTime(2025, 6, 14, 18, 32, 7));
      expect(d('2025-06-14T18:32:07+02:00'), DateTime(2025, 6, 14, 18, 32, 7));
      expect(d('2025:06:14 18:32'), DateTime(2025, 6, 14, 18, 32));
      // Sans heure, ou heure illisible : midi.
      expect(d('2025:06:14'), DateTime(2025, 6, 14, 12));
      expect(d('2025:06:14 25:61:00'), DateTime(2025, 6, 14, 12));
      // Bissextile.
      expect(d('2024:02:29 08:00:00'), DateTime(2024, 2, 29, 8));
      // Plus tard aujourd'hui (autre fuseau) : ramenée à maintenant.
      expect(d('2026:10:02 23:00:00'), now);
    });

    test('dates invalides : refusées, la suivante est essayée', () {
      const invalides = [
        '0000:00:00 00:00:00',
        '    :  :     :  :  ',
        '',
        'hier',
        '2025:13:01 10:00:00',
        '2025:02:30 10:00:00',
        '2025:00:10 10:00:00',
        '2023:02:29 10:00:00',
        '1970:01:01 00:00:00',
        // Demain et au-delà : l'horloge de l'appareil était fausse.
        '2026:10:03 00:00:01',
        '2031:01:01 12:00:00',
        '14/06/2025',
        '20250614',
      ];
      for (final s in invalides) {
        expect(exif(jpegAvecExif(tiff(originale: s))), isNull, reason: '« $s » accepté');
        expect(DatePhoto.lire(s, maintenant: now), isNull, reason: '« $s » accepté');
        expect(exif(jpegAvecExif(tiff(originale: s, numerisee: '2025:06:15 09:00:00'))), DateTime(2025, 6, 15, 9), reason: s);
        expect(exif(jpegAvecExif(tiff(originale: s, numerisee: s, fichier: '2025:07:01 10:00:00'))), DateTime(2025, 7, 1, 10), reason: s);
      }
    });

    test('fichier tronqué ou abîmé : pas de date, pas de plantage', () {
      final bon = jpegAvecExif(tiff(originale: '2025:06:14 18:32:07', fichier: '2025:07:01 10:00:00'));
      for (var n = 0; n < bon.length; n++) {
        final d = exif(Uint8List.sublistView(bon, 0, n));
        expect(d == null || d == DateTime(2025, 6, 14, 18, 32, 7) || d == DateTime(2025, 7, 1, 10), isTrue, reason: 'coupé à $n');
      }
      // Chaque octet du bloc abîmé tour à tour : jamais d'exception.
      for (var i = 0; i < 160; i++) {
        final abime = Uint8List.fromList(bon)..[i] = 0xFF;
        expect(() => exif(abime), returnsNormally, reason: 'octet $i');
      }
    });

    test('PNG, WebP et HEIC', () async {
      final bloc = tiff(originale: '2025:06:14 18:32:07', ordre: Endian.little);
      final png = await pngPhoto(const Color(0xFF334455), const Color(0xFF112233));
      expect(exif(png), isNull);
      final date = pngAvecExif(png, bloc);
      expect(exif(date), DateTime(2025, 6, 14, 18, 32, 7));
      // Le PNG daté reste une vraie image.
      final codec = await ui.instantiateImageCodec(date);
      expect((await codec.getNextFrame()).image.width, 300);
      codec.dispose();
      expect(exif(webpAvecExif(bloc)), DateTime(2025, 6, 14, 18, 32, 7));
      expect(exif(webpAvecExif(bloc, prefixe: true)), DateTime(2025, 6, 14, 18, 32, 7));
      expect(exif(heicAvecExif(bloc)), DateTime(2025, 6, 14, 18, 32, 7));
      expect(exif(heicAvecExif(tiff(fichier: '2024:01:05 07:00:00'))), DateTime(2024, 1, 5, 7));
    });

    test('date portée par le nom du fichier', () {
      DateTime? d(String s) => DatePhoto.duNom(s, maintenant: now);
      expect(d('IMG_20250614_183207.jpg'), DateTime(2025, 6, 14, 12));
      expect(d('IMG-20240302-WA0007.jpg'), DateTime(2024, 3, 2, 12));
      expect(d('PXL_20230101_101010123.jpg'), DateTime(2023, 1, 1, 12));
      expect(d('Screenshot_2025-06-14-18-32-07.png'), DateTime(2025, 6, 14, 12));
      expect(d('/cache/abc/20250614_183207.jpg'), DateTime(2025, 6, 14, 12));
      expect(d('/cache/20250614/photo.jpg'), isNull);
      expect(d('photo.jpg'), isNull);
      expect(d('1000012345.jpg'), isNull);
      expect(d('1718372212345.jpg'), isNull);
      expect(d('IMG_20251345_1.jpg'), isNull);
      expect(d('IMG_20270101_1.jpg'), isNull);
      expect(d('image_picker_2025.jpg'), isNull);
    });
  });

  group('photos choisies dans la galerie', () {
    late Directory dossier;
    late Store store;
    late HealthRepo sante;

    setUp(() async {
      dossier = Directory.systemTemp.createTempSync('aesthetic-import-');
      store = Store.memory();
      (await store.mediaDir()).createSync(recursive: true);
      sante = HealthRepo(store);
      addTearDown(() async {
        for (final p in [...sante.photos]) {
          await sante.deletePhoto(p.id);
        }
        if (dossier.existsSync()) dossier.deleteSync(recursive: true);
      });
    });

    FichierPhoto fichier(String nom, Uint8List octets) {
      final f = File('${dossier.path}${Platform.pathSeparator}$nom')..writeAsBytesSync(octets);
      // La date du fichier ne doit jamais servir.
      f.setLastModifiedSync(DateTime(2019, 5, 5));
      return (chemin: f.path, nom: nom);
    }

    Future<ImportPhotos> lot() => ImportPhotos.lire(
          [
            fichier('a.jpg', jpegAvecExif(tiff(originale: '2025:06:14 18:32:07'))),
            fichier('IMG-20240302-WA0007.jpg', jpegNu),
            fichier('sans-date.jpg', jpegNu),
            fichier('b.jpg', jpegAutreEncodeur),
          ],
          vue: PhotoVue.profil,
          maintenant: now,
        );

    test('date lue dans la photo, dans le nom, ou inconnue ; jamais celle du fichier', () async {
      final i = await lot();
      expect(i.photos.map((p) => p.date), [DateTime(2025, 6, 14, 18, 32, 7), DateTime(2024, 3, 2, 12), null, DateTime(2025, 6, 14, 18, 32, 7)]);
      expect(i.photos.map((p) => p.origine), [OrigineDate.photo, OrigineDate.nom, OrigineDate.aucune, OrigineDate.photo]);
      expect(OrigineDate.photo.mention, 'date lue dans la photo');
      // L'angle de l'onglet courant par défaut.
      expect(i.photos.every((p) => p.vue == PhotoVue.profil), isTrue);
      // Fichier disparu : date inconnue, pas de plantage.
      final perdu = await ImportPhotos.lire([(chemin: '${dossier.path}/absent.jpg', nom: 'absent.jpg')], vue: PhotoVue.face, maintenant: now);
      expect(perdu.photos.single.date, isNull);
    });

    test('un gros JPEG : la date est lue dans son en-tête', () async {
      final gros = Uint8List.fromList([...jpegAvecExif(tiff(originale: '2025:06:14 18:32:07')), ...List.filled(600 * 1024, 0)]);
      final i = await ImportPhotos.lire([fichier('gros.jpg', gros)], vue: PhotoVue.face, maintenant: now);
      expect(i.photos.single.date, DateTime(2025, 6, 14, 18, 32, 7));
      // Un gros fichier d'un autre format est lu en entier.
      final heic = Uint8List.fromList([...List.filled(600 * 1024, 1), ...heicAvecExif(tiff(originale: '2025:06:14 18:32:07'))]);
      final j = await ImportPhotos.lire([fichier('gros.heic', heic)], vue: PhotoVue.face, maintenant: now);
      expect(j.photos.single.date, DateTime(2025, 6, 14, 18, 32, 7));
    });

    test('une date manquante bloque l\'ajout ; la choisir le débloque', () async {
      final i = await lot();
      expect(i.sansDate, 1);
      expect(i.pret, isFalse);
      expect(await i.enregistrer(sante), isEmpty);
      expect(sante.photos, isEmpty);
      final inconnue = i.photos[2];
      // Date future refusée, rien ne change.
      expect(i.fixerDate(inconnue, DateTime(2026, 10, 3), maintenant: now), isFalse);
      expect(inconnue.date, isNull);
      expect(i.pret, isFalse);
      expect(i.fixerDate(inconnue, DateTime(2022, 12, 31), maintenant: now), isTrue);
      expect(inconnue.date, DateTime(2022, 12, 31, 12));
      expect(inconnue.origine, OrigineDate.choisie);
      expect(i.pret, isTrue);
      expect(ImportPhotos([]).pret, isFalse);
    });

    test('corriger une date lue : le jour change, l\'heure reste', () async {
      final i = await lot();
      final p = i.photos.first;
      expect(i.fixerDate(p, DateTime(2025, 6, 10), maintenant: now), isTrue);
      expect(p.date, DateTime(2025, 6, 10, 18, 32, 7));
      expect(p.origine, OrigineDate.choisie);
      // Le même jour : rien ne change, la mention non plus.
      final q = i.photos.last;
      expect(i.fixerDate(q, DateTime(2025, 6, 14), maintenant: now), isTrue);
      expect(q.origine, OrigineDate.photo);
      // Aujourd'hui avec une heure plus tardive que maintenant : maintenant.
      expect(i.fixerDate(p, DateTime(2026, 10, 2), maintenant: now), isTrue);
      expect(p.date, now);
      expect(dateAuJour(null, DateTime(2026, 10, 2), maintenant: DateTime(2026, 10, 2, 9)), DateTime(2026, 10, 2, 9));
      expect(dateAuJour(null, DateTime(2026, 10, 3), maintenant: now), isNull);
    });

    test('angle par photo, puis appliqué à toutes', () async {
      final i = await lot();
      expect(i.anglesDifferents, isFalse);
      i.fixerVue(i.photos[1], PhotoVue.dos);
      expect(i.photos.map((p) => p.vue), [PhotoVue.profil, PhotoVue.dos, PhotoVue.profil, PhotoVue.profil]);
      expect(i.anglesDifferents, isTrue);
      i.appliquerATous(PhotoVue.dos);
      expect(i.photos.every((p) => p.vue == PhotoVue.dos), isTrue);
      expect(i.anglesDifferents, isFalse);
      i.retirer(i.photos[2]);
      expect(i.photos.length, 3);
      expect(i.pret, isTrue);
    });

    test('enregistrées dans le dossier de l\'appli, rangées par date de prise de vue', () async {
      // Une photo prise aujourd'hui est déjà là.
      await sante.savePhoto(ProgressPhoto(id: 'auj', date: now, chemin: 'x.jpg', vue: PhotoVue.profil, poidsKg: 80));
      final i = await lot();
      i.fixerDate(i.photos[2], DateTime(2025, 1, 20), maintenant: now);
      i.fixerVue(i.photos[3], PhotoVue.face);
      final sources = [for (final p in i.photos) p.chemin];
      final faites = await i.enregistrer(sante);
      expect(faites.length, 4);
      expect(i.photos, isEmpty);
      final medias = (await store.mediaDir()).path;
      for (final p in faites) {
        expect(File(p.chemin).parent.path, medias);
        expect(File(p.chemin).existsSync(), isTrue);
        // Aucun poids noté : c'est la pesée la plus proche qui s'affiche.
        expect(p.poidsKg, isNull);
      }
      // Les originaux ne sont pas touchés, et la copie garde son EXIF.
      expect(sources.every((s) => File(s).existsSync()), isTrue);
      expect(exif(File(faites.first.chemin).readAsBytesSync()), DateTime(2025, 6, 14, 18, 32, 7));
      // Ordre d'ajout : 14 juin 2025, 2 mars 2024, 20 janvier 2025.
      // Ordre affiché : la plus récente d'abord, par date de prise de vue.
      expect(sante.photos.map((p) => p.date), [now, DateTime(2025, 6, 14, 18, 32, 7), DateTime(2025, 6, 14, 18, 32, 7), DateTime(2025, 1, 20, 12), DateTime(2024, 3, 2, 12)]);
      expect(Mensurations.photosDe(sante.photos, PhotoVue.profil).map((p) => p.date), [now, DateTime(2025, 6, 14, 18, 32, 7), DateTime(2025, 1, 20, 12), DateTime(2024, 3, 2, 12)]);
      expect(Mensurations.photosDe(sante.photos, PhotoVue.face).single.date, DateTime(2025, 6, 14, 18, 32, 7));
    });

    test('modifier la date ou l\'angle d\'une photo enregistrée', () async {
      await sante.savePhoto(ProgressPhoto(id: 'a', date: DateTime(2026, 9, 28, 9, 30), chemin: 'a.jpg', poidsKg: 76.7, note: 'matin'));
      await sante.savePhoto(ProgressPhoto(id: 'b', date: DateTime(2026, 9, 1, 9), chemin: 'b.jpg'));
      ProgressPhoto a() => sante.photos.firstWhere((p) => p.id == 'a');
      // Date future refusée.
      expect(await changerDatePhoto(sante, a(), DateTime(2026, 10, 3), maintenant: now), isFalse);
      expect(a().date, DateTime(2026, 9, 28, 9, 30));
      // Même jour : rien ne change, le poids noté reste.
      expect(await changerDatePhoto(sante, a(), DateTime(2026, 9, 28), maintenant: now), isTrue);
      expect(a().poidsKg, 76.7);
      // Autre jour : l'heure reste, le poids noté ce jour-là ne vaut plus.
      expect(await changerDatePhoto(sante, a(), DateTime(2024, 8, 15), maintenant: now), isTrue);
      expect(a().date, DateTime(2024, 8, 15, 9, 30));
      expect(a().poidsKg, isNull);
      expect(a().note, 'matin');
      expect(a().chemin, 'a.jpg');
      // Le rang suit la nouvelle date.
      expect(sante.photos.map((p) => p.id), ['b', 'a']);
      expect(sante.photos.length, 2);
      await changerVuePhoto(sante, a(), PhotoVue.dos);
      expect(a().vue, PhotoVue.dos);
      expect(a().date, DateTime(2024, 8, 15, 9, 30));
      expect(Mensurations.photosDe(sante.photos, PhotoVue.face).map((p) => p.id), ['b']);
    });
  });

  group('poids à côté d\'une photo', () {
    BodyMeasurement m(String id, DateTime d, double? kg) => BodyMeasurement(id: id, date: d, poidsKg: kg);
    final ms = [
      m('a', DateTime(2025, 6, 1, 8), 74),
      m('b', DateTime(2025, 6, 10, 8), 75),
      m('c', DateTime(2025, 6, 20, 8), 76),
      m('sans', DateTime(2025, 6, 14, 8), null),
      m('d', DateTime(2026, 9, 28, 8), 80),
    ];

    test('la pesée la plus proche, avant ou après', () {
      expect(Mensurations.joursPoidsPhoto, 7);
      expect(Mensurations.poidsProche(ms, DateTime(2025, 6, 14, 18)), 75);
      expect(Mensurations.poidsProche(ms, DateTime(2025, 6, 17, 23)), 76);
      expect(Mensurations.poidsProche(ms, DateTime(2025, 6, 10, 23, 59)), 75);
      // À écart égal (cinq jours de chaque côté) : la pesée d'avant.
      expect(Mensurations.poidsProche(ms, DateTime(2025, 6, 15)), 75);
      // Avant la toute première pesée, à moins d'une semaine.
      expect(Mensurations.poidsProche(ms, DateTime(2025, 5, 27)), 74);
    });

    test('rien si aucune pesée à sept jours ou moins', () {
      expect(Mensurations.poidsProche(ms, DateTime(2025, 6, 27, 20)), 76);
      expect(Mensurations.poidsProche(ms, DateTime(2025, 6, 28, 1)), isNull);
      expect(Mensurations.poidsProche(ms, DateTime(2025, 5, 24)), isNull);
      expect(Mensurations.poidsProche(ms, DateTime(2020, 1, 1)), isNull);
      expect(Mensurations.poidsProche(const [], DateTime(2025, 6, 14)), isNull);
    });

    test('le poids noté sur la photo prime ; une photo ancienne sans pesée n\'en montre pas', () {
      final ancienne = ProgressPhoto(id: 'x', date: DateTime(2023, 3, 3), chemin: '');
      final datee = ProgressPhoto(id: 'y', date: DateTime(2025, 6, 14, 18), chemin: '');
      final notee = ProgressPhoto(id: 'z', date: DateTime(2023, 3, 3), chemin: '', poidsKg: 71.5);
      expect(Mensurations.poidsPhoto(ancienne, ms), isNull);
      expect(Mensurations.poidsPhoto(datee, ms), 75);
      expect(Mensurations.poidsPhoto(notee, ms), 71.5);
      final c = Mensurations.comparer(ancienne, datee, ms);
      expect(c.poidsAvant, isNull);
      expect(c.poidsApres, 75);
      expect(c.ecartKg, isNull);
    });
  });

  group('écrans', () {
    late Directory dossier;
    setUp(() {
      dossier = Directory.systemTemp.createTempSync('aesthetic-galerie-');
      addTearDown(() {
        SelecteurPhotos.reinitialiser();
        try {
          if (dossier.existsSync()) dossier.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows garde parfois l'image ouverte un instant : sans gravité.
        }
      });
    });

    Future<void> rendu(WidgetTester t, String nom) => t.runAsync(() async {
          final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cleBanc));
          final img = await ro.toImage(pixelRatio: 2);
          final octets = await img.toByteData(format: ui.ImageByteFormat.png);
          (File('build/rendus/profil/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(octets!.buffer.asUint8List());
        });

    /// Trois photos : datée par son EXIF, datée par son nom, sans date.
    Future<List<FichierPhoto>> galerie(WidgetTester t) async {
      late List<FichierPhoto> out;
      await t.runAsync(() async {
        FichierPhoto f(String nom, Uint8List o) {
          File('${dossier.path}${Platform.pathSeparator}$nom').writeAsBytesSync(o);
          return (chemin: '${dossier.path}${Platform.pathSeparator}$nom', nom: nom);
        }

        final bloc = tiff(originale: '2025:06:14 18:32:07');
        out = [
          f('IMG_0412.png', pngAvecExif(await pngPhoto(const Color(0xFF56708C), const Color(0xFF1B2430)), bloc)),
          f('IMG-20240302-WA0007.png', await pngPhoto(const Color(0xFF7A6652), const Color(0xFF2A211A))),
          f('scan.png', await pngPhoto(const Color(0xFF5E7A5E), const Color(0xFF1C261C))),
        ];
      });
      return out;
    }

    Future<AppData> depart(WidgetTester t, double largeur) async {
      await polices(t);
      ecran(t, largeur: largeur);
      final data = await donnees(t);
      await t.runAsync(() async {
        (await data.store.mediaDir()).createSync(recursive: true);
        // Pesées autour du 14 juin 2025 seulement.
        await data.health.saveMeasurement(BodyMeasurement(id: 'p1', date: DateTime(2025, 6, 12, 8), poidsKg: 72.4, source: 'manuel'));
      });
      addTearDown(() async {
        for (final p in [...data.health.photos]) {
          try {
            File(p.chemin).deleteSync();
          } on FileSystemException {
            // Déjà parti.
          }
        }
      });
      return data;
    }

    Future<void> jour(WidgetTester t, String numero) async {
      await t.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text(numero)));
      await t.pump();
      await t.tap(find.text('Valider'));
      await attendre(t, 2);
    }

    bool actif(WidgetTester t) => t.widget<BoutonPrincipal>(find.widgetWithText(BoutonPrincipal, 'Ajouter')).onPressed != null;

    for (final largeur in [360.0, 412.0]) {
      final l = largeur.round();
      testWidgets('ajouter d\'anciennes photos depuis la galerie, en $l', (t) async {
        final data = await depart(t, largeur);
        final fichiers = await galerie(t);
        var ouvertures = 0;
        SelecteurPhotos.galerie = () async {
          ouvertures++;
          return fichiers;
        };
        SelecteurPhotos.appareil = () async => fail('appareil photo ouvert');
        await monter(t, data, ProfilPaths.photos);

        // Le bouton d'ajout propose les deux sources.
        await t.tap(find.bySemanticsLabel('Ajouter une photo'));
        await attendre(t, 2);
        expect(find.widgetWithText(LigneAction, 'Prendre une photo'), findsOneWidget);
        expect(find.widgetWithText(LigneAction, 'Choisir dans la galerie'), findsOneWidget);
        await rendu(t, 'photos-ajout-panneau-$l');
        await t.tap(find.text('Choisir dans la galerie'));
        await attendre(t, 16);
        expect(ouvertures, 1);

        // Confirmation : une ligne par photo.
        expect(find.text('Ajouter 3 photos'), findsOneWidget);
        expect(find.text('1 photo sans date'), findsOneWidget);
        expect(find.text('Prise le 14 juin 2025'), findsOneWidget);
        expect(find.text('date lue dans la photo'), findsOneWidget);
        expect(find.text('Prise le 2 mars 2024'), findsOneWidget);
        expect(find.text('date lue dans le nom du fichier'), findsOneWidget);
        expect(find.text('Date inconnue'), findsOneWidget);
        expect(find.text('Choisir la date'), findsOneWidget);
        // L'angle de l'onglet courant (face) partout.
        expect(t.widgetList<Puce>(find.widgetWithText(Puce, 'Face')).every((p) => p.choisie), isTrue);
        expect(find.text('Appliquer à toutes'), findsNothing);
        // Vignettes décodées à leur taille d'affichage.
        final images = t.widgetList<Image>(find.byType(Image)).toList();
        expect(images.length, 3);
        for (final i in images) {
          expect(i.image, isA<ResizeImage>());
          expect((i.image as ResizeImage).width, lessThan(400));
        }
        expect(t.takeException(), isNull);
        await rendu(t, 'photos-ajout-date-inconnue-$l');

        // Une date manque : le bouton reste inactif.
        expect(actif(t), isFalse);
        await t.tap(find.text('Ajouter'));
        await attendre(t, 2);
        expect(data.health.photos, isEmpty);
        expect(find.text('Ajouter 3 photos'), findsOneWidget);

        // Le calendrier ne propose aucun jour futur.
        await t.tap(find.text('Choisir la date'));
        await attendre(t, 2);
        expect(find.text('Date de la photo'), findsOneWidget);
        final calendrier = t.widget<DatePickerDialog>(find.byType(DatePickerDialog));
        expect(calendrier.lastDate.isAfter(DateTime.now()), isFalse);
        await rendu(t, 'photos-ajout-calendrier-$l');
        await jour(t, '1');
        expect(find.text('Date inconnue'), findsNothing);
        expect(find.text('date choisie'), findsOneWidget);
        expect(find.text('Vérifie la date et l\'angle'), findsOneWidget);
        expect(actif(t), isTrue);

        // Corriger une date lue : le calendrier s'ouvre sur juin 2025.
        await t.tap(find.text('Prise le 14 juin 2025'));
        await attendre(t, 2);
        expect(find.text('juin 2025'), findsOneWidget);
        await jour(t, '20');
        expect(find.text('Prise le 20 juin 2025'), findsOneWidget);
        expect(find.text('date lue dans la photo'), findsNothing);
        await t.tap(find.text('Prise le 20 juin 2025'));
        await attendre(t, 2);
        await jour(t, '14');
        expect(find.text('Prise le 14 juin 2025'), findsOneWidget);

        // Angle d'une photo, puis de toutes.
        await t.tap(find.widgetWithText(Puce, 'Dos').at(1));
        await attendre(t, 1);
        expect(t.widgetList<Puce>(find.widgetWithText(Puce, 'Dos')).map((p) => p.choisie), [false, true, false]);
        expect(find.text('Appliquer à toutes'), findsOneWidget);
        await attendre(t, 2);
        await rendu(t, 'photos-ajout-pret-$l');
        await t.tap(find.text('Appliquer à toutes'));
        await attendre(t, 1);
        expect(t.widgetList<Puce>(find.widgetWithText(Puce, 'Dos')).every((p) => p.choisie), isTrue);
        expect(find.text('Appliquer à toutes'), findsNothing);
        await t.tap(find.widgetWithText(Puce, 'Face').first);
        await attendre(t, 1);
        expect(t.takeException(), isNull);

        await t.tap(find.text('Ajouter'));
        await attendre(t, 16);
        expect(t.takeException(), isNull);
        final photos = data.health.photos;
        expect(photos.length, 3);
        final now = DateTime.now();
        // De la plus récente à la plus ancienne : le 1er du mois en cours,
        // le 14 juin 2025, le 2 mars 2024.
        expect([for (final p in photos) (p.date.year, p.date.month, p.date.day)], [(now.year, now.month, 1), (2025, 6, 14), (2024, 3, 2)]);
        expect(photos[1].date, DateTime(2025, 6, 14, 18, 32, 7));
        expect(photos.map((p) => p.vue), [PhotoVue.dos, PhotoVue.face, PhotoVue.dos]);
        final medias = await t.runAsync(() => data.store.mediaDir());
        expect(photos.every((p) => File(p.chemin).parent.path == medias!.path && File(p.chemin).existsSync()), isTrue);

        // Retour sur la grille, onglet Face (une des photos y est).
        expect(find.text('Photos'), findsOneWidget);
        expect(find.textContaining('3 photos depuis mars 2024'), findsOneWidget);
        expect(find.byType(VignettePhoto), findsOneWidget);
        await t.tap(find.text('Dos'));
        await attendre(t, 8);
        expect(find.byType(VignettePhoto), findsNWidgets(2));
        // La plus récente d'abord.
        expect(t.getSemantics(find.byType(VignettePhoto).last).label, contains('2 mars 2024'));
        await rendu(t, 'photos-grille-apres-ajout-$l');
        await t.pump(const Duration(seconds: 5));
        expect(t.takeException(), isNull);
      });

      testWidgets('une photo enregistrée : changer sa date et son angle, en $l', (t) async {
        final data = await depart(t, largeur);
        final fichiers = await galerie(t);
        await t.runAsync(() async {
          await data.health.addPhoto(fichiers[0].chemin, date: DateTime(2025, 6, 14, 18, 32, 7));
          await data.health.addPhoto(fichiers[1].chemin, date: DateTime(2024, 3, 2, 12));
        });
        final id = data.health.photos.first.id;
        ProgressPhoto p() => data.health.photos.firstWhere((x) => x.id == id);
        final router = await monter(t, data, ProfilPaths.photos);
        router.push(ProfilPaths.photo(id));
        await attendre(t, 8);
        // La pesée du 12 juin 2025 est à deux jours de la photo.
        expect(find.text('14 juin 2025'), findsNWidgets(2));
        expect(find.text('Face · 72,4 kg'), findsOneWidget);
        await rendu(t, 'photo-modifier-$l');

        await t.scrollUntilVisible(find.text('Angle'), 80, scrollable: find.byType(Scrollable).first);
        await t.tap(find.text('Date'));
        await attendre(t, 2);
        expect(find.text('juin 2025'), findsOneWidget);
        await rendu(t, 'photo-modifier-calendrier-$l');
        await jour(t, '30');
        expect(p().date, DateTime(2025, 6, 30, 18, 32, 7));
        expect(find.text('30 juin 2025'), findsNWidgets(2));
        // Plus aucune pesée à sept jours : le poids disparaît.
        expect(find.text('Face'), findsNWidgets(2));
        expect(find.textContaining('72,4'), findsNothing);

        await t.tap(find.text('Angle'));
        await attendre(t, 2);
        expect(find.text('Angle de la photo'), findsOneWidget);
        await rendu(t, 'photo-modifier-angle-$l');
        await t.tap(find.widgetWithText(ChoixPanneau, 'Profil'));
        await attendre(t, 2);
        expect(p().vue, PhotoVue.profil);
        expect(p().date, DateTime(2025, 6, 30, 18, 32, 7));
        expect(find.text('Profil'), findsNWidgets(2));
        // La suppression est toujours là.
        expect(find.bySemanticsLabel('Supprimer la photo'), findsOneWidget);
        expect(data.health.photos.length, 2);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('prendre une photo : enregistrée tout de suite, datée de maintenant', (t) async {
      final data = await depart(t, 412);
      final fichiers = await galerie(t);
      SelecteurPhotos.appareil = () async => fichiers[2];
      SelecteurPhotos.galerie = () async => fail('galerie ouverte');
      await monter(t, data, ProfilPaths.photos);
      await t.tap(find.text('Profil'));
      await attendre(t, 1);
      await t.tap(find.bySemanticsLabel('Ajouter une photo'));
      await attendre(t, 2);
      await t.tap(find.text('Prendre une photo'));
      await attendre(t, 16);
      final p = data.health.photos.single;
      expect(p.vue, PhotoVue.profil);
      expect(DateTime.now().difference(p.date).inMinutes, 0);
      expect(find.textContaining('Ajouter 1 photo'), findsNothing);
      await t.pump(const Duration(seconds: 5));
      expect(t.takeException(), isNull);
    });

    testWidgets('galerie : rien de choisi, une seule photo, photo retirée', (t) async {
      final data = await depart(t, 360);
      final fichiers = await galerie(t);
      var choix = <FichierPhoto>[];
      SelecteurPhotos.galerie = () async => choix;
      await monter(t, data, ProfilPaths.photos);

      Future<void> ouvrir() async {
        await t.tap(find.bySemanticsLabel('Ajouter une photo'));
        await attendre(t, 2);
        await t.tap(find.text('Choisir dans la galerie'));
        await attendre(t, 16);
      }

      // Sélecteur fermé sans rien choisir : on reste sur la grille.
      await ouvrir();
      expect(find.text('Photos'), findsOneWidget);
      expect(find.textContaining('Ajouter 0'), findsNothing);

      // Une seule photo : pas de « Appliquer à toutes », pas de retrait.
      choix = [fichiers[0]];
      await ouvrir();
      expect(find.text('Ajouter 1 photo'), findsOneWidget);
      await t.tap(find.widgetWithText(Puce, 'Dos'));
      await attendre(t, 1);
      expect(find.text('Appliquer à toutes'), findsNothing);
      expect(find.bySemanticsLabel('Retirer cette photo'), findsNothing);
      // Retour : rien n'est ajouté.
      await t.tap(find.bySemanticsLabel('Retour'));
      await attendre(t, 2);
      expect(data.health.photos, isEmpty);
      expect(find.text('Photos'), findsOneWidget);

      // Retirer la photo sans date débloque l'ajout.
      choix = fichiers;
      await ouvrir();
      expect(actif(t), isFalse);
      await t.tap(find.bySemanticsLabel('Retirer cette photo').last);
      await attendre(t, 1);
      expect(find.text('Ajouter 2 photos'), findsOneWidget);
      expect(find.text('Date inconnue'), findsNothing);
      expect(actif(t), isTrue);
      await t.tap(find.text('Ajouter'));
      await attendre(t, 16);
      expect(data.health.photos.length, 2);
      expect(find.text('Photos'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      expect(t.takeException(), isNull);
    });
  });
}
