import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Petites images de test, fabriquées ici : avec ou sans date de prise de
/// vue, dans plusieurs formats.

/// Vrai JPEG de 8 sur 8, sans EXIF.
final Uint8List jpegNu = base64Decode(
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDABwTFRgVERwYFhgfHRwhKUUtKSYmKVQ8QDJFZFhpZ2JYYF9ufJ6GbnWWd19giruLlqOpsbOxa4TC0MGszp6usar/2wBDAR0fHykkKVEtLVGqcmByqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/wAARCAAIAAgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwBlFFFbmR//2Q==');

/// Le même, enregistré par un autre encodeur avec ses trois dates EXIF :
/// originale le 14 juin 2025 à 18:32:07, numérisée le 15 juin, fichier le
/// 1er juillet. Sert de contrôle indépendant du constructeur ci-dessous.
final Uint8List jpegAutreEncodeur = base64Decode(
    '/9j/4AAQSkZJRgABAQEAYABgAAD/4QCKRXhpZgAATU0AKgAAAAgAAgEyAAIAAAAUAAAAJodpAAQAAAABAAAAOgAAAAAyMDI1OjA3OjAxIDEwOjAwOjAwAAACkAMAAgAAABQAAABYkAQAAgAAABQAAABsAAAAADIwMjU6MDY6MTQgMTg6MzI6MDcAMjAyNTowNjoxNSAwOTowMDowMAAAAP/bAEMAHBMVGBURHBgWGB8dHCEpRS0pJiYpVDxAMkVkWGlnYlhgX258noZudZZ3X2CKu4uWo6mxs7FrhMLQwazOnq6xqv/bAEMBHR8fKSQpUS0tUapyYHKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/AABEIAAgACAMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ04SXxFxgZGiYnKCkqNTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6ery8/T19vf4+fr/2gAMAwEAAhEDEQA/AGUUUVuZH//Z');

Uint8List _texte(String s) => Uint8List.fromList([...ascii.encode(s), 0]);

/// Un répertoire TIFF posé au décalage [base] : ses entrées, puis les
/// valeurs de plus de quatre octets.
Uint8List _repertoire(int base, List<(int cle, int type, int nombre, Uint8List valeur)> entrees, Endian ordre) {
  final tete = 2 + entrees.length * 12 + 4;
  final b = ByteData(tete)..setUint16(0, entrees.length, ordre);
  final suite = BytesBuilder();
  for (final (i, (cle, type, nombre, valeur)) in entrees.indexed) {
    final e = 2 + i * 12;
    b
      ..setUint16(e, cle, ordre)
      ..setUint16(e + 2, type, ordre)
      ..setUint32(e + 4, nombre, ordre);
    if (valeur.length <= 4) {
      for (var k = 0; k < valeur.length; k++) {
        b.setUint8(e + 8 + k, valeur[k]);
      }
    } else {
      b.setUint32(e + 8, base + tete + suite.length, ordre);
      suite.add(valeur);
      if (valeur.length.isOdd) suite.addByte(0);
    }
  }
  return Uint8List.fromList([...b.buffer.asUint8List(), ...suite.takeBytes()]);
}

/// Bloc TIFF d'un EXIF, avec les dates données (textes libres, pour
/// essayer aussi les formats invalides).
Uint8List tiff({String? originale, String? numerisee, String? fichier, Endian ordre = Endian.big}) {
  final avecExif = originale != null || numerisee != null;
  Uint8List premier(int exif) => _repertoire(
        8,
        [
          if (fichier != null) (0x0132, 2, fichier.length + 1, _texte(fichier)),
          if (avecExif) (0x8769, 4, 1, (ByteData(4)..setUint32(0, exif, ordre)).buffer.asUint8List()),
        ],
        ordre,
      );
  final ouExif = 8 + premier(0).length;
  final tete = ByteData(8)
    ..setUint8(0, ordre == Endian.big ? 0x4D : 0x49)
    ..setUint8(1, ordre == Endian.big ? 0x4D : 0x49)
    ..setUint16(2, 42, ordre)
    ..setUint32(4, 8, ordre);
  return Uint8List.fromList([
    ...tete.buffer.asUint8List(),
    ...premier(ouExif),
    if (avecExif)
      ..._repertoire(
        ouExif,
        [
          if (originale != null) (0x9003, 2, originale.length + 1, _texte(originale)),
          if (numerisee != null) (0x9004, 2, numerisee.length + 1, _texte(numerisee)),
        ],
        ordre,
      ),
  ]);
}

/// [jpegNu] avec un segment EXIF glissé après le début du fichier.
Uint8List jpegAvecExif(Uint8List bloc) {
  final taille = bloc.length + 8;
  return Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE1, taille >> 8, taille & 0xFF, ...ascii.encode('Exif'), 0, 0, ...bloc, //
    ...jpegNu.skip(2),
  ]);
}

int _crc32(List<int> octets) {
  var crc = 0xFFFFFFFF;
  for (final o in octets) {
    crc ^= o;
    for (var k = 0; k < 8; k++) {
      crc = crc.isOdd ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// Un PNG avec un bloc `eXIf` glissé après son en-tête.
Uint8List pngAvecExif(Uint8List png, Uint8List bloc) {
  // Signature (8) puis le bloc IHDR (4 + 4 + 13 + 4).
  const apres = 33;
  final type = ascii.encode('eXIf');
  final taille = ByteData(4)..setUint32(0, bloc.length);
  final crc = ByteData(4)..setUint32(0, _crc32([...type, ...bloc]));
  return Uint8List.fromList([
    ...png.take(apres),
    ...taille.buffer.asUint8List(), ...type, ...bloc, ...crc.buffer.asUint8List(), //
    ...png.skip(apres),
  ]);
}

/// Conteneur WebP réduit à son bloc `EXIF` (assez pour la lecture).
Uint8List webpAvecExif(Uint8List bloc, {bool prefixe = false}) {
  final contenu = [if (prefixe) ...[...ascii.encode('Exif'), 0, 0], ...bloc];
  final corps = [
    ...ascii.encode('WEBP'),
    ...ascii.encode('VP8X'), 10, 0, 0, 0, 8, 0, 0, 0, 7, 0, 0, 7, 0, 0, //
    ...ascii.encode('EXIF'),
    ...(ByteData(4)..setUint32(0, contenu.length, Endian.little)).buffer.asUint8List(),
    ...contenu,
    if (contenu.length.isOdd) 0,
  ];
  return Uint8List.fromList([
    ...ascii.encode('RIFF'),
    ...(ByteData(4)..setUint32(0, corps.length, Endian.little)).buffer.asUint8List(),
    ...corps,
  ]);
}

/// Conteneur à la manière d'un HEIC : le bloc EXIF est quelque part dans
/// le fichier, après le marqueur « Exif ».
Uint8List heicAvecExif(Uint8List bloc) => Uint8List.fromList([
      0, 0, 0, 24, ...ascii.encode('ftypheic'), 0, 0, 0, 0, ...ascii.encode('mif1heic'), //
      ...List.filled(300, 7),
      0, 0, 0, 6, ...ascii.encode('Exif'), 0, 0, ...bloc,
      ...List.filled(40, 9),
    ]);

/// Vrai PNG de 300 sur 400 : un dégradé et une silhouette, pour que les
/// rendus ressemblent à des photos. À appeler dans `runAsync`.
Future<Uint8List> pngPhoto(ui.Color haut, ui.Color bas) async {
  final r = ui.PictureRecorder();
  final c = ui.Canvas(r);
  const cadre = ui.Rect.fromLTWH(0, 0, 300, 400);
  c.drawRect(cadre, ui.Paint()..shader = ui.Gradient.linear(const ui.Offset(0, 0), const ui.Offset(0, 400), [haut, bas]));
  final corps = ui.Paint()..color = const ui.Color(0x55FFFFFF);
  c.drawCircle(const ui.Offset(150, 110), 38, corps);
  c.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(85, 160, 130, 260), const ui.Radius.circular(40)), corps);
  final image = await r.endRecording().toImage(300, 400);
  final octets = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return octets!.buffer.asUint8List();
}
