import 'dart:typed_data';

/// Lecture de la date de prise de vue d'une photo, sans dépendance : le
/// bloc EXIF d'un JPEG, d'un PNG, d'un WebP ou d'un HEIC, sinon le nom du
/// fichier. La date de modification du fichier n'est jamais utilisée (c'est
/// celle de la copie).
abstract final class DatePhoto {
  /// Année la plus ancienne acceptée : en dessous, l'horloge de l'appareil
  /// n'était pas réglée.
  static const anneeMin = 1990;

  static const _dateOriginale = 0x9003;
  static const _dateNumerisee = 0x9004;
  static const _dateFichier = 0x0132;
  static const _blocExif = 0x8769;

  /// Date de prise de vue lue dans l'EXIF : `DateTimeOriginal`, sinon
  /// `DateTimeDigitized`, sinon `DateTime`. Null si la photo n'en porte
  /// pas, ou si elle est illisible, trop ancienne ou dans le futur.
  static DateTime? exif(Uint8List octets, {DateTime? maintenant}) {
    try {
      for (final tiff in _blocsTiff(octets)) {
        final champs = _champs(tiff);
        for (final cle in [_dateOriginale, _dateNumerisee, _dateFichier]) {
          final d = lire(champs[cle], maintenant: maintenant);
          if (d != null) return d;
        }
      }
    } catch (_) {
      // Fichier tronqué ou bloc abîmé : pas de date.
    }
    return null;
  }

  /// Date d'un texte EXIF (« 2025:06:14 18:32:07 ») ; les séparateurs des
  /// logiciels de retouche sont tolérés. Null si elle n'est pas plausible.
  static DateTime? lire(String? texte, {DateTime? maintenant}) {
    if (texte == null) return null;
    final m = RegExp(r'^(\d{4})[:\-/.](\d{2})[:\-/.](\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?').firstMatch(texte.trim());
    if (m == null) return null;
    int n(int i) => m.group(i) == null ? -1 : int.parse(m.group(i)!);
    var (h, min, s) = (n(4), n(5), n(6));
    if (s < 0) s = 0;
    // Sans heure lisible : midi.
    if (h < 0 || h > 23 || min > 59 || s > 59) (h, min, s) = (12, 0, 0);
    return _plausible(n(1), n(2), n(3), h, min, s, maintenant);
  }

  /// Date portée par le nom du fichier (« IMG_20250614_183207.jpg »,
  /// « IMG-20250614-WA0003.jpg », « Screenshot_2025-06-14-18-32.png »), à
  /// midi. Null si le nom n'en porte pas.
  static DateTime? duNom(String nom, {DateTime? maintenant}) {
    final fichier = nom.split(RegExp(r'[/\\]')).last;
    for (final m in RegExp(r'(?<!\d)((?:19|20)\d{2})([-_.]?)(\d{2})\2(\d{2})(?!\d)').allMatches(fichier)) {
      final d = _plausible(int.parse(m.group(1)!), int.parse(m.group(3)!), int.parse(m.group(4)!), 12, 0, 0, maintenant);
      if (d != null) return d;
    }
    return null;
  }

  static DateTime? _plausible(int a, int mois, int j, int h, int min, int s, DateTime? maintenant) {
    if (a < anneeMin || mois < 1 || mois > 12 || j < 1) return null;
    final d = DateTime(a, mois, j, h, min, s);
    // Un 31 février glisse en mars : refusé.
    if (d.month != mois || d.day != j) return null;
    final now = maintenant ?? DateTime.now();
    if (d.isAfter(now)) {
      // Plus tard aujourd'hui (autre fuseau) : c'est maintenant. Au-delà,
      // l'horloge de l'appareil était fausse.
      if (d.year == now.year && d.month == now.month && d.day == now.day) return now;
      return null;
    }
    return d;
  }

  // Où trouver le bloc TIFF de l'EXIF selon le format.

  static Iterable<Uint8List> _blocsTiff(Uint8List o) sync* {
    if (o.length < 12) return;
    if (o[0] == 0xFF && o[1] == 0xD8) {
      yield* _jpeg(o);
    } else if (o[0] == 0x89 && o[1] == 0x50 && o[2] == 0x4E && o[3] == 0x47) {
      yield* _png(o);
    } else if (_ascii(o, 0, 4) == 'RIFF' && _ascii(o, 8, 4) == 'WEBP') {
      yield* _webp(o);
    } else {
      // HEIC et autres conteneurs : le bloc suit le marqueur « Exif ».
      yield* _marqueur(o);
    }
  }

  static Iterable<Uint8List> _jpeg(Uint8List o) sync* {
    var i = 2;
    while (i + 4 <= o.length) {
      if (o[i] != 0xFF) return;
      final marqueur = o[i + 1];
      // Octets de remplissage.
      if (marqueur == 0xFF) {
        i++;
        continue;
      }
      // Début de l'image ou fin du fichier : plus d'en-tête après.
      if (marqueur == 0xDA || marqueur == 0xD9) return;
      final taille = (o[i + 2] << 8) | o[i + 3];
      if (taille < 2) return;
      final debut = i + 4;
      final fin = i + 2 + taille > o.length ? o.length : i + 2 + taille;
      if (marqueur == 0xE1 && fin - debut > 6 && _estExif(o, debut)) {
        yield Uint8List.sublistView(o, debut + 6, fin);
      }
      i += 2 + taille;
    }
  }

  static Iterable<Uint8List> _png(Uint8List o) sync* {
    var i = 8;
    while (i + 12 <= o.length) {
      final taille = ByteData.sublistView(o, i, i + 4).getUint32(0);
      final type = _ascii(o, i + 4, 4);
      final debut = i + 8;
      if (debut + taille > o.length) return;
      if (type == 'eXIf') yield Uint8List.sublistView(o, debut, debut + taille);
      if (type == 'IEND') return;
      i = debut + taille + 4;
    }
  }

  static Iterable<Uint8List> _webp(Uint8List o) sync* {
    var i = 12;
    while (i + 8 <= o.length) {
      final type = _ascii(o, i, 4);
      final taille = ByteData.sublistView(o, i + 4, i + 8).getUint32(0, Endian.little);
      final debut = i + 8;
      if (debut + taille > o.length) return;
      if (type == 'EXIF') {
        final saut = taille > 6 && _estExif(o, debut) ? 6 : 0;
        yield Uint8List.sublistView(o, debut + saut, debut + taille);
      }
      i = debut + taille + (taille.isOdd ? 1 : 0);
    }
  }

  static Iterable<Uint8List> _marqueur(Uint8List o) sync* {
    for (var i = 0; i + 14 <= o.length; i++) {
      if (o[i] != 0x45 || !_estExif(o, i)) continue;
      final t = i + 6;
      final petit = o[t] == 0x49 && o[t + 1] == 0x49 && o[t + 2] == 0x2A && o[t + 3] == 0;
      final grand = o[t] == 0x4D && o[t + 1] == 0x4D && o[t + 2] == 0 && o[t + 3] == 0x2A;
      if (petit || grand) yield Uint8List.sublistView(o, t);
    }
  }

  /// « Exif » suivi de deux octets nuls.
  static bool _estExif(Uint8List o, int i) =>
      i + 6 <= o.length && o[i] == 0x45 && o[i + 1] == 0x78 && o[i + 2] == 0x69 && o[i + 3] == 0x66 && o[i + 4] == 0 && o[i + 5] == 0;

  static String _ascii(Uint8List o, int debut, int taille) => String.fromCharCodes(o, debut, debut + taille);

  /// Les trois dates d'un bloc TIFF : celle du premier répertoire et les
  /// deux du répertoire EXIF.
  static Map<int, String> _champs(Uint8List t) {
    final out = <int, String>{};
    if (t.length < 8) return out;
    final Endian ordre;
    if (t[0] == 0x49 && t[1] == 0x49) {
      ordre = Endian.little;
    } else if (t[0] == 0x4D && t[1] == 0x4D) {
      ordre = Endian.big;
    } else {
      return out;
    }
    final d = ByteData.sublistView(t);
    if (d.getUint16(2, ordre) != 42) return out;

    /// Lit un répertoire ; rend le décalage du répertoire EXIF s'il y est.
    int? repertoire(int debut, Set<int> cles) {
      int? exif;
      if (debut < 8 || debut + 2 > t.length) return null;
      final n = d.getUint16(debut, ordre);
      for (var k = 0; k < n; k++) {
        final e = debut + 2 + k * 12;
        if (e + 12 > t.length) break;
        final cle = d.getUint16(e, ordre);
        final type = d.getUint16(e + 2, ordre);
        final nb = d.getUint32(e + 4, ordre);
        if (cle == _blocExif && (type == 4 || type == 13)) {
          exif = d.getUint32(e + 8, ordre);
        } else if (cles.contains(cle) && type == 2 && nb > 0 && nb <= 64) {
          final ou = nb <= 4 ? e + 8 : d.getUint32(e + 8, ordre);
          if (ou + nb > t.length) continue;
          final brut = t.sublist(ou, ou + nb).takeWhile((c) => c != 0).where((c) => c < 0x80);
          out[cle] = String.fromCharCodes(brut);
        }
      }
      return exif;
    }

    final exif = repertoire(d.getUint32(4, ordre), {_dateFichier});
    if (exif != null) repertoire(exif, {_dateOriginale, _dateNumerisee});
    return out;
  }
}
