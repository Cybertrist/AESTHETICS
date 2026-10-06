import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Images de remplacement de la démo, dessinées ici point par point (aucun
/// fichier embarqué) : une silhouette neutre pour les photos de progression,
/// un haltère pour les photos de séance. Écrites en PNG dans le dossier des
/// médias, en synchrone pour rester utilisables dans les tests.
abstract final class DemoImages {
  static const largeur = 540;
  static const hauteur = 720;

  /// Silhouette de face, de profil ou de dos. [carrure] élargit le haut du
  /// corps (1 = départ) pour que deux dates ne donnent pas la même image.
  static String silhouette(Directory dossier, String nom, {required int vue, double carrure = 1}) =>
      _ecrire(dossier, nom, (x, y) => _silhouette(x, y, vue, carrure), teinte: vue == 2 ? 0.92 : 1);

  /// Version du dessin des images de séance : à augmenter quand il change,
  /// pour que [rafraichir] redessine celles d'une démo déjà installée.
  static const version = 2;

  /// Image de remplacement d'une photo de séance : un dégradé sombre et un
  /// petit haltère à peine plus clair, au centre.
  static String haltere(Directory dossier, String nom, {int variante = 0, bool refaire = false}) => _ecrire(
        dossier,
        nom,
        (x, y) => _haltere(x, y),
        fond: (x, y) => _fondSeance(x, y, variante),
        encre: (_) => 66,
        refaire: refaire,
      );

  /// Redessine les images de séance d'une démo installée avec un ancien
  /// dessin (une fois par version). Sans effet si le dossier n'existe pas.
  static void rafraichir(Directory dossier) {
    try {
      if (!dossier.existsSync()) return;
      final marque = File('${dossier.path}${Platform.pathSeparator}demo_images.version');
      if (marque.existsSync() && marque.readAsStringSync().trim() == '$version') return;
      final motif = RegExp(r'^demo_seance_(\d+)_(\d+)\.png$');
      for (final f in dossier.listSync().whereType<File>()) {
        final m = motif.firstMatch(f.uri.pathSegments.last);
        if (m == null) continue;
        final k = int.parse(m.group(1)!);
        final n = int.parse(m.group(2)!);
        haltere(dossier, 'demo_seance_${k}_$n', variante: (k + n) % 3, refaire: true);
      }
      marque.writeAsStringSync('$version', flush: true);
    } on FileSystemException {
      // Dossier illisible : les anciennes images restent.
    }
  }

  static String _ecrire(
    Directory dossier,
    String nom,
    double Function(double x, double y) forme, {
    double teinte = 1,
    double Function(double x, double y)? fond,
    double Function(double t)? encre,
    bool refaire = false,
  }) {
    final fichier = File('${dossier.path}${Platform.pathSeparator}$nom.png');
    // Déjà dessinée (relance de la démo, tests en parallèle) : on la garde.
    if (!refaire && fichier.existsSync() && fichier.lengthSync() > 0) return fichier.path;
    dossier.createSync(recursive: true);
    final png = _png(largeur, hauteur, _pixels(forme, teinte, fond: fond, encre: encre));
    final temp = File('${fichier.path}.${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp');
    temp.writeAsBytesSync(png, flush: true);
    try {
      // Windows ne renomme pas par-dessus un fichier : on retire l'ancien.
      if (refaire && Platform.isWindows && fichier.existsSync()) fichier.deleteSync();
      temp.renameSync(fichier.path);
    } on FileSystemException {
      // Un autre processus vient de l'écrire : la sienne fait l'affaire.
      if (temp.existsSync()) temp.deleteSync();
    }
    return fichier.path;
  }

  // Distance signée à un rectangle arrondi, en unités de largeur d'image.
  static double _boite(double x, double y, double cx, double cy, double dx, double dy, double r) {
    final qx = (x - cx).abs() - dx + r;
    final qy = (y - cy).abs() - dy + r;
    final ex = math.max(qx, 0.0);
    final ey = math.max(qy, 0.0);
    return math.sqrt(ex * ex + ey * ey) + math.min(math.max(qx, qy), 0.0) - r;
  }

  static double _rond(double x, double y, double cx, double cy, double r) {
    final dx = x - cx;
    final dy = y - cy;
    return math.sqrt(dx * dx + dy * dy) - r;
  }

  // Membre : segment de [x0, y0] à [x1, y1], rayon [r0] puis [r1].
  static double _membre(double x, double y, double x0, double y0, double x1, double y1, double r0, double r1) {
    final vx = x1 - x0;
    final vy = y1 - y0;
    final t = (((x - x0) * vx + (y - y0) * vy) / (vx * vx + vy * vy)).clamp(0.0, 1.0);
    final dx = x - (x0 + vx * t);
    final dy = y - (y0 + vy * t);
    return math.sqrt(dx * dx + dy * dy) - (r0 + (r1 - r0) * t);
  }

  // Tronc : demi-largeur lue sur un profil (hauteur, demi-largeur), adoucie
  // entre deux points.
  static double _tronc(double x, double y, double cx, List<(double, double)> profil) {
    final haut = profil.first.$1;
    final bas = profil.last.$1;
    var w = profil.last.$2;
    for (var i = 1; i < profil.length; i++) {
      if (y <= profil[i].$1) {
        final t = ((y - profil[i - 1].$1) / (profil[i].$1 - profil[i - 1].$1)).clamp(0.0, 1.0);
        w = profil[i - 1].$2 + (profil[i].$2 - profil[i - 1].$2) * t * t * (3 - 2 * t);
        break;
      }
    }
    return math.max((x - cx).abs() - w, math.max(haut - y, y - bas));
  }

  static double _silhouette(double x, double y, int vue, double k) {
    if (vue == 1) {
      // Profil : un seul volume, plus étroit, tête un peu en avant.
      var d = _rond(x, y, 0.52, 0.2, 0.075);
      d = math.min(d, _membre(x, y, 0.505, 0.27, 0.5, 0.36, 0.042, 0.05));
      d = math.min(d, _tronc(x, y, 0.5, [(0.33, 0.05), (0.42, 0.1 * k), (0.56, 0.112 * k), (0.8, 0.086), (0.93, 0.104), (1.04, 0.1)]));
      d = math.min(d, _membre(x, y, 0.5, 1.0, 0.495, 1.45, 0.098, 0.062));
      return d;
    }
    var d = _rond(x, y, 0.5, 0.2, 0.075);
    d = math.min(d, _membre(x, y, 0.5, 0.27, 0.5, 0.36, 0.04, 0.05));
    // Épaules, buste en V, taille, hanches.
    d = math.min(d, _tronc(x, y, 0.5, [(0.33, 0.05), (0.39, 0.15 * k), (0.44, 0.2 * k), (0.5, 0.2 * k), (0.8, 0.128), (0.93, 0.155), (1.04, 0.158)]));
    for (final s in const [-1.0, 1.0]) {
      // Épaule, bras le long du corps, jambe.
      d = math.min(d, _rond(x, y, 0.5 + s * 0.195 * k, 0.43, 0.062 * k));
      d = math.min(d, _membre(x, y, 0.5 + s * 0.215 * k, 0.45, 0.5 + s * (0.235 * k + 0.035), 0.93, 0.05 * k, 0.03));
      d = math.min(d, _membre(x, y, 0.5 + s * 0.08, 1.0, 0.5 + s * 0.085, 1.45, 0.08, 0.052));
    }
    return d;
  }

  // Petit haltère au centre de l'image (un tiers de la largeur).
  static double _haltere(double x, double y) {
    const echelle = 0.42;
    const cy = hauteur / largeur / 2;
    final u = (x - 0.5) / echelle + 0.5;
    final v = (y - cy) / echelle + cy;
    var d = _boite(u, v, 0.5, cy, 0.33, 0.02, 0.02);
    for (final s in const [-1.0, 1.0]) {
      d = math.min(d, _boite(u, v, 0.5 + s * 0.2, cy, 0.038, 0.15, 0.026));
      d = math.min(d, _boite(u, v, 0.5 + s * 0.28, cy, 0.028, 0.105, 0.022));
    }
    return d * echelle;
  }

  // Fond d'une image de séance : presque noir en bas, une lueur grise venue
  // d'un coin du haut (le coin change avec la variante).
  static double _fondSeance(double x, double y, int variante) {
    final ox = const [0.15, 0.85, 0.5][variante % 3];
    final dx = x - ox;
    final dy = y + 0.1;
    final lueur = math.exp(-(dx * dx + dy * dy) / 0.9);
    return 11 + 30 * lueur;
  }

  /// [fond] et [encre] (gris de 0 à 255) remplacent le fond et la forme par
  /// défaut ; [encre] reçoit la hauteur du point, de 0 en haut à 1 en bas.
  static Uint8List _pixels(
    double Function(double x, double y) forme,
    double teinte, {
    double Function(double x, double y)? fond,
    double Function(double t)? encre,
  }) {
    const w = largeur;
    const h = hauteur;
    // Une ligne = un octet de filtre (0) puis trois octets par point.
    final out = Uint8List(h * (1 + w * 3));
    var o = 0;
    for (var py = 0; py < h; py++) {
      out[o++] = 0;
      final t = py / (h - 1);
      // Fond : gris sombre, plus clair en haut.
      var fr = 52 - 29 * t;
      var fb = 58 - 32 * t;
      // Forme : gris moyen, un peu plus clair en haut.
      final c = encre != null ? encre(t) : (112 - 26 * t) * teinte;
      final y = (py + 0.5) / w;
      for (var px = 0; px < w; px++) {
        final x = (px + 0.5) / w;
        if (fond != null) {
          fr = fond(x, y);
          fb = fr * 1.06;
        }
        // Bord adouci sur un point.
        final a = (0.5 - forme(x, y) * w).clamp(0.0, 1.0);
        out[o++] = (fr + (c - fr) * a).round();
        out[o++] = (fr + (c - fr) * a).round();
        out[o++] = (fb + (c * 1.04 - fb) * a).round().clamp(0, 255);
      }
    }
    return out;
  }

  static Uint8List _png(int w, int h, Uint8List lignes) {
    final b = BytesBuilder();
    b.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final entete = ByteData(13)
      ..setUint32(0, w)
      ..setUint32(4, h)
      ..setUint8(8, 8) // huit bits par canal
      ..setUint8(9, 2); // rouge, vert, bleu
    _bloc(b, 'IHDR', entete.buffer.asUint8List());
    _bloc(b, 'IDAT', Uint8List.fromList(ZLibEncoder(level: 6).convert(lignes)));
    _bloc(b, 'IEND', Uint8List(0));
    return b.toBytes();
  }

  static void _bloc(BytesBuilder b, String type, Uint8List donnees) {
    final nom = type.codeUnits;
    b.add((ByteData(4)..setUint32(0, donnees.length)).buffer.asUint8List());
    b.add(nom);
    b.add(donnees);
    final crc = _crc(donnees, _crc(nom, 0xFFFFFFFF)) ^ 0xFFFFFFFF;
    b.add((ByteData(4)..setUint32(0, crc)).buffer.asUint8List());
  }

  static final List<int> _table = [
    for (var n = 0; n < 256; n++)
      () {
        var c = n;
        for (var k = 0; k < 8; k++) {
          c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
        }
        return c;
      }(),
  ];

  static int _crc(List<int> octets, int crc) {
    var c = crc;
    for (final o in octets) {
      c = _table[(c ^ o) & 0xFF] ^ (c >> 8);
    }
    return c;
  }
}
