import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:path_provider/path_provider.dart';

/// Le cadrage d'une photo de progression : où se tient la personne, et quelle
/// partie de l'image est utile (sans bandes noires). Toutes les photos sont
/// alors montrées à la même échelle et à la même place, quels que soient la
/// pièce, la distance et le cadrage d'origine.
///
/// L'échelle se règle sur le tronc (des épaules aux hanches) : il est
/// toujours dans l'image, ne dépend ni des bras, ni de l'écart des pieds, ni
/// d'une tête penchée, et sa longueur ne change pas quand le poids change.
class Cadrage {
  const Cadrage(this.zone, this.ratio, [this.epaules, this.hanches, this.peau]);

  /// La zone utile, en fractions de l'image (0 à 1).
  final Rect zone;

  /// Largeur sur hauteur de l'image entière.
  final double ratio;

  /// Le milieu des épaules et celui des hanches, en fractions de l'image ;
  /// null quand personne n'a été reconnu.
  final Offset? epaules, hanches;

  /// La couleur médiane du tronc (rouge, vert, bleu, de 0 à 255) : elle dit
  /// sous quelle lumière la photo a été prise.
  final List<double>? peau;

  static const entier = Rect.fromLTRB(0, 0, 1, 1);

  /// Part de la hauteur du cadre que prend le tronc, et hauteur de la ligne
  /// d'épaules : une personne debout tient alors de la tête aux pieds.
  static const partTronc = 0.27, ligneEpaules = 0.215;

  /// À changer quand la façon de cadrer change : les cadrages gardés sur le
  /// téléphone sont alors recalculés.
  static const _version = 4;

  static final _connus = <String, Cadrage>{};
  static final _enCours = <String, Future<Cadrage>>{};
  static Future<void>? _lecture;
  static Future<void> _file = Future.value();
  static File? _fichier;
  static PoseDetector? _detecteur;
  static SelfieSegmenter? _segmenteur;

  /// Pour les tests : oublie les calculs en cours, qu'un test précédent a pu
  /// laisser en suspens.
  @visibleForTesting
  static void oublierEnCours() {
    _enCours.clear();
    _file = Future.value();
    _lecture = null;
  }

  /// Le cadrage déjà calculé pour ce fichier, s'il l'est.
  static Cadrage? connu(String chemin) => _connus[chemin];

  static Future<Cadrage> de(File f) => _enCours[f.path] ??= _calculer(f);

  /// Les cadrages déjà trouvés sont gardés d'un lancement à l'autre.
  static Future<void> _relire() async {
    try {
      final f = _fichier = File('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}cadrages.json');
      if (!f.existsSync()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (j['v'] != _version) return;
      (j['photos'] as Map<String, dynamic>).forEach((chemin, v) {
        final n = [for (final x in v as List) (x as num).toDouble()];
        // Un fichier remplacé ou supprimé depuis : à refaire.
        final photo = File(chemin);
        if (!photo.existsSync() || photo.lengthSync() != n[0]) return;
        final corps = n.length >= 10;
        _connus[chemin] = Cadrage(Rect.fromLTRB(n[1], n[2], n[3], n[4]), n[5], corps ? Offset(n[6], n[7]) : null, corps ? Offset(n[8], n[9]) : null, n.length >= 13 ? n.sublist(10, 13) : null);
        _tailles[chemin] = n[0].toInt();
      });
    } catch (_) {
      // Illisible ou hors de l'appli : tout sera recalculé.
    }
  }

  static final _tailles = <String, int>{};

  static void _garder() {
    final f = _fichier;
    if (f == null) return;
    final contenu = jsonEncode({
      'v': _version,
      'photos': {
        for (final e in _connus.entries)
          if (_tailles[e.key] != null)
            e.key: [
              _tailles[e.key],
              e.value.zone.left,
              e.value.zone.top,
              e.value.zone.right,
              e.value.zone.bottom,
              e.value.ratio,
              if (e.value.epaules != null && e.value.hanches != null) ...[e.value.epaules!.dx, e.value.epaules!.dy, e.value.hanches!.dx, e.value.hanches!.dy, ...?e.value.peau],
            ],
      },
    });
    // Une écriture après l'autre, par un fichier d'à côté : jamais de fichier à moitié écrit.
    _ecriture = _ecriture.then((_) async {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(contenu);
      await tmp.rename(f.path);
    }).catchError((Object _) {});
  }

  static Future<void> _ecriture = Future.value();

  static Future<Cadrage> _calculer(File f) async {
    try {
      await (_lecture ??= _relire());
      final garde = _connus[f.path];
      if (garde != null) return garde;
      // Une photo après l'autre : la détection ne se fait pas en parallèle.
      final tour = _file.then((_) => _analyser(f));
      _file = tour.then((_) {}, onError: (_) {});
      final (c, sur) = await tour;
      _connus[f.path] = c;
      // Une détection en panne n'est pas gardée : elle sera retentée au prochain lancement.
      if (sur) {
        _tailles[f.path] = f.lengthSync();
        _garder();
      }
      return c;
    } finally {
      _enCours.remove(f.path)?.ignore();
    }
  }

  /// Le cadrage, et s'il est sûr (la détection a répondu).
  static Future<(Cadrage, bool)> _analyser(File f) async {
    // Une image réduite suffit, pour les bords comme pour la personne.
    final codec = await ui.instantiateImageCodec(await f.readAsBytes(), targetWidth: 640);
    final image = (await codec.getNextFrame()).image;
    try {
      final l = image.width, h = image.height;
      final donnees = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (donnees == null) return (Cadrage(entier, l / h), false);
      final rgba = donnees.buffer.asUint8List();
      final zone = utile(rgba, l, h);
      if (!Platform.isAndroid && !Platform.isIOS) return (Cadrage(zone, l / h), true);
      try {
        final d = _detecteur ??= PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.single, model: PoseDetectionModel.accurate));
        // Cherche le corps dans une [partie] de l'image, en pixels ; les
        // points reviennent en fractions de l'image entière.
        Future<(Offset, Offset, Map<String, (double, double, double)>)?> chercher(Uint8List pixels, Rect partie) async {
          final pl = partie.width.round(), ph = partie.height.round();
          final poses = await d.processImage(InputImage.fromBitmap(bitmap: pixels, width: pl, height: ph)).timeout(const Duration(seconds: 8));
          if (poses.isEmpty) return null;
          final points = {for (final p in poses.first.landmarks.values) p.type.name: ((partie.left + p.x) / l, (partie.top + p.y) / h, p.likelihood)};
          final t = tronc(points, l / h);
          return t == null ? null : (t.$1, t.$2, points);
        }

        var trouve = await chercher(rgba, Rect.fromLTWH(0, 0, l.toDouble(), h.toDouble()));
        if (trouve == null) {
          // Personne petite au milieu de bandes noires, photo sombre ou à
          // contre-jour : un second essai sur la seule zone utile, éclaircie.
          final partie = Rect.fromLTRB((zone.left * l).roundToDouble(), (zone.top * h).roundToDouble(), (zone.right * l).roundToDouble(), (zone.bottom * h).roundToDouble());
          trouve = await chercher(eclaircie(decoupe(rgba, l, partie)), partie);
        }
        if (trouve == null) {
          // Tête coupée par la photo : la pose ne se trouve pas, la silhouette si.
          final t = troncDeSilhouette(await _silhouette(rgba, l, h), zone);
          if (t != null) return (Cadrage(zone, l / h, t.$1, t.$2), true);
        }
        final corps = trouve == null ? null : (trouve.$1, trouve.$2);
        final points = trouve?.$3;
        if (corps == null) return (Cadrage(zone, l / h), true);
        // Le milieu du tronc, entre les épaules et les hanches, loin des bords.
        final largeur = (points!['leftShoulder']!.$1 - points['rightShoulder']!.$1).abs();
        final axe = (corps.$1.dx + corps.$2.dx) / 2;
        final torse = Rect.fromLTRB(axe - largeur * 0.3, corps.$1.dy, axe + largeur * 0.3, corps.$2.dy);
        return (Cadrage(zone, l / h, corps.$1, corps.$2, mediane(rgba, l, h, torse)), true);
      } catch (_) {
        return (Cadrage(zone, l / h), false);
      }
    } finally {
      image.dispose();
      codec.dispose();
    }
  }

  /// Le milieu des épaules et celui des hanches à partir des points du corps
  /// reconnus (nom, x, y en fractions de l'image, confiance) ; null quand le
  /// tronc n'est pas sûr ou pas plausible. [ratio] : largeur sur hauteur de
  /// l'image.
  static (Offset, Offset)? tronc(Map<String, (double, double, double)> points, double ratio) {
    Offset? milieu(String a, String b) {
      final pa = points[a], pb = points[b];
      if (pa == null || pb == null || pa.$3 < 0.5 || pb.$3 < 0.5) return null;
      return Offset((pa.$1 + pb.$1) / 2, (pa.$2 + pb.$2) / 2);
    }

    final e = milieu('leftShoulder', 'rightShoulder'), h = milieu('leftHip', 'rightHip');
    if (e == null || h == null) return null;
    final dx = (h.dx - e.dx) * ratio, dy = h.dy - e.dy;
    // Un tronc trop petit, à l'envers ou couché : la détection s'est trompée.
    if (dy < 0.08 || dx.abs() > dy * 0.36) return null;
    return (e, h);
  }

  /// La silhouette de la personne : pour chaque ligne de l'image, de haut en
  /// bas, le bord gauche et le bord droit du corps en fractions de la largeur
  /// (null quand la ligne ne touche pas le corps).
  static Future<List<(double, double)?>> _silhouette(Uint8List rgba, int l, int h) async {
    final s = _segmenteur ??= SelfieSegmenter(mode: SegmenterMode.single, enableRawSizeMask: true);
    final masque = await s.processImage(InputImage.fromBitmap(bitmap: rgba, width: l, height: h)).timeout(const Duration(seconds: 8));
    if (masque == null) return const [];
    final ml = masque.width, mh = masque.height;
    return [
      for (var y = 0; y < mh; y++)
        () {
          int? g, d;
          for (var x = 0; x < ml; x++) {
            if (masque.confidences[y * ml + x] >= 0.5) {
              g ??= x;
              d = x;
            }
          }
          return g == null ? null : (g / ml, (d! + 1) / ml);
        }(),
    ];
  }

  /// Les mesures d'une silhouette : première et dernière ligne du corps, ligne
  /// où il atteint sa pleine largeur (les épaules), axe et largeur à cet
  /// endroit, le tout en fractions de l'image. Null sans corps net.
  static ({double haut, double epaules, double bas, double axe, double largeur})? mesures(List<(double, double)?> lignes) {
    final n = lignes.length;
    double large(int y) => lignes[y] == null ? 0 : lignes[y]!.$2 - lignes[y]!.$1;
    final corps = [for (var y = 0; y < n; y++) if (large(y) >= 0.04) y];
    if (corps.length < n * 0.3) return null;
    final haut = corps.first, bas = corps.last;
    // La pleine largeur se cherche dans la moitié haute : bras et buste.
    final moitie = haut + (bas - haut) ~/ 2;
    final largeurs = [for (var y = haut; y <= moitie; y++) large(y)]..sort();
    final pleine = largeurs[(largeurs.length * 0.9).floor().clamp(0, largeurs.length - 1)];
    final epaules = [for (var y = haut; y <= moitie; y++) y].firstWhere((y) => large(y) >= pleine * 0.72);
    // L'axe du corps : le milieu du buste, sous les épaules.
    final buste = [for (var y = epaules; y <= epaules + (bas - epaules) ~/ 3; y++) if (lignes[y] != null) (lignes[y]!.$1 + lignes[y]!.$2) / 2]..sort();
    return (haut: haut / n, epaules: epaules / n, bas: (bas + 1) / n, axe: buste[buste.length ~/ 2], largeur: pleine);
  }

  /// Le milieu des épaules et celui des hanches estimés à partir de la
  /// silhouette, pour une photo où la pose n'est pas trouvée. Il faut voir les
  /// pieds : c'est la distance des épaules au sol qui donne l'échelle.
  static (Offset, Offset)? troncDeSilhouette(List<(double, double)?> lignes, Rect zone) {
    if (lignes.isEmpty) return null;
    final m = mesures(lignes);
    if (m == null) return null;
    // Les pieds touchent le bas de la photo : coupés, pas d'échelle sûre.
    if (m.bas >= zone.bottom - 0.01) return null;
    final sol = m.bas - m.epaules;
    if (sol < 0.3) return null;
    final e = Offset(m.axe, m.epaules + sol * epaulesSousSilhouette);
    return (e, Offset(m.axe, e.dy + sol * troncSurHauteur));
  }

  /// Étalonnés sur les photos où la pose est trouvée : où tombe le milieu des
  /// épaules sous le haut des épaules de la silhouette, et la longueur du
  /// tronc, en parts de la distance des épaules au sol.
  static const epaulesSousSilhouette = 0.01, troncSurHauteur = 0.34;

  /// Pour l'étalonnage : les mesures de la silhouette d'une photo.
  @visibleForTesting
  static Future<({double haut, double epaules, double bas, double axe, double largeur})?> silhouetteDe(File f) async {
    final codec = await ui.instantiateImageCodec(await f.readAsBytes(), targetWidth: 640);
    final image = (await codec.getNextFrame()).image;
    final donnees = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final lignes = await _silhouette(donnees!.buffer.asUint8List(), image.width, image.height);
    return lignes.isEmpty ? null : mesures(lignes);
  }

  /// Une [partie] (en pixels entiers) d'une image RGBA de [l] pixels de large.
  static Uint8List decoupe(Uint8List rgba, int l, Rect partie) {
    final x = partie.left.toInt(), y = partie.top.toInt(), pl = partie.width.toInt(), ph = partie.height.toInt();
    final sortie = Uint8List(pl * ph * 4);
    for (var j = 0; j < ph; j++) {
      sortie.setRange(j * pl * 4, (j + 1) * pl * 4, rgba, ((y + j) * l + x) * 4);
    }
    return sortie;
  }

  /// La même image, les tons sombres relevés (les pixels opaques seulement).
  static Uint8List eclaircie(Uint8List rgba) {
    final table = Uint8List.fromList([for (var v = 0; v < 256; v++) (255 * math.pow(v / 255, 0.5)).round()]);
    final sortie = Uint8List.fromList(rgba);
    for (var i = 0; i < sortie.length; i += 4) {
      sortie[i] = table[sortie[i]];
      sortie[i + 1] = table[sortie[i + 1]];
      sortie[i + 2] = table[sortie[i + 2]];
    }
    return sortie;
  }

  /// La couleur médiane d'une [partie] (en fractions) d'une image RGBA de [l]
  /// sur [h] pixels ; null si la partie est vide. La médiane ignore l'élastique
  /// d'un sous-vêtement, un tatouage ou un reflet.
  static List<double>? mediane(Uint8List rgba, int l, int h, Rect partie) {
    final x0 = (partie.left * l).floor().clamp(0, l - 1), x1 = (partie.right * l).ceil().clamp(0, l);
    final y0 = (partie.top * h).floor().clamp(0, h - 1), y1 = (partie.bottom * h).ceil().clamp(0, h);
    final canaux = [<int>[], <int>[], <int>[]];
    for (var y = y0; y < y1; y += 2) {
      for (var x = x0; x < x1; x += 2) {
        final i = (y * l + x) * 4;
        for (var c = 0; c < 3; c++) {
          canaux[c].add(rgba[i + c]);
        }
      }
    }
    if (canaux[0].length < 20) return null;
    return [
      for (final c in canaux) (c..sort())[c.length ~/ 2].toDouble(),
    ];
  }

  /// La zone sans bandes noires d'une image RGBA de [l] sur [h] pixels. Une
  /// bande est une ligne ou une colonne du bord presque entièrement noire.
  static Rect utile(Uint8List rgba, int l, int h) {
    bool noir(int x, int y) {
      final i = (y * l + x) * 4;
      // Un pixel transparent n'est pas une bande.
      return rgba[i + 3] == 255 && rgba[i] <= 28 && rgba[i + 1] <= 28 && rgba[i + 2] <= 28;
    }

    var g = 0, d = l, haut = 0, bas = h;
    bool colonneNoire(int x) {
      var n = 0;
      for (var y = haut; y < bas; y++) {
        if (noir(x, y)) n++;
      }
      return n >= (bas - haut) * 0.96;
    }

    bool ligneNoire(int y) {
      var n = 0;
      for (var x = g; x < d; x++) {
        if (noir(x, y)) n++;
      }
      return n >= (d - g) * 0.96;
    }

    // Deux passes : une bande sur un côté peut en cacher une sur l'autre.
    for (var passe = 0; passe < 2; passe++) {
      while (g < d - 1 && colonneNoire(g)) {
        g++;
      }
      while (d - 1 > g && colonneNoire(d - 1)) {
        d--;
      }
      while (haut < bas - 1 && ligneNoire(haut)) {
        haut++;
      }
      while (bas - 1 > haut && ligneNoire(bas - 1)) {
        bas--;
      }
    }
    // Presque tout serait rogné : une photo sombre, pas des bandes.
    if (d - g < l * 0.25 || bas - haut < h * 0.25) return entier;
    // Un peu de marge du côté rogné : le bord d'une bande est souvent flou.
    final mx = (l / 100).ceil(), my = (h / 100).ceil();
    if (g > 0) g += mx;
    if (d < l) d -= mx;
    if (haut > 0) haut += my;
    if (bas < h) bas -= my;
    return Rect.fromLTRB(g / l, haut / h, d / l, bas / h);
  }

  /// Où poser l'image entière dans un [cadre] : la zone utile le couvre
  /// toujours en entier, sans bande ni vide.
  ///
  /// Personne reconnue : le tronc prend la même part de la hauteur d'une
  /// photo à l'autre, la ligne d'épaules tombe au même endroit et l'axe du
  /// corps est au milieu. Si l'image est trop étroite ou trop serrée pour
  /// couvrir le cadre à cette échelle, elle est agrandie juste ce qu'il faut.
  ///
  /// Sans personne reconnue, la zone utile couvre le cadre, tenue selon
  /// [alignement].
  Rect place(Size cadre, {Alignment alignement = Alignment.center}) {
    final plein = math.max(cadre.width / (ratio * zone.width), cadre.height / zone.height);
    final e = epaules, h = hanches;
    if (e == null || h == null) {
      final utile = Size(ratio * zone.width * plein, zone.height * plein);
      final reste = alignement.alongSize(Size(cadre.width - utile.width, cadre.height - utile.height));
      return Rect.fromLTWH(reste.dx - zone.left * ratio * plein, reste.dy - zone.top * plein, ratio * plein, plein);
    }
    final tronc = math.sqrt(math.pow((h.dx - e.dx) * ratio, 2) + math.pow(h.dy - e.dy, 2));
    // Hauteur de l'image entière à l'écran.
    final commune = _commune(cadre) / tronc;
    final k = math.max(commune, plein);
    final x = _tenir(cadre.width / 2 - (e.dx + h.dx) / 2 * ratio * k, cadre.width - zone.right * ratio * k, -zone.left * ratio * k);
    final y = _tenir(_ligne(cadre, tronc * k) - e.dy * k, cadre.height - zone.bottom * k, -zone.top * k);
    return Rect.fromLTWH(x, y, ratio * k, k);
  }

  /// [v] entre [min] et [max] ; au milieu quand un arrondi les croise (une
  /// image qui couvre son cadre au pixel près).
  static double _tenir(double v, double min, double max) => min >= max ? (min + max) / 2 : math.min(math.max(v, min), max);

  /// La longueur du tronc à l'écran, la même pour toutes les photos montrées
  /// dans un cadre de cette forme. Dans un cadre étroit (9:16) le corps tient
  /// en entier ; dans un cadre plus large (la grille en 3:4) il est plus gros
  /// et coupé plus haut, mais pareil pour toutes : une photo n'a alors presque
  /// jamais besoin d'être agrandie plus que les autres pour couvrir le cadre.
  static double _commune(Size cadre) => math.max(cadre.height * partTronc, cadre.width * partTronc * 16 / 9);

  /// La hauteur de la ligne d'épaules pour un [tronc] de cette longueur à
  /// l'écran : la tête garde la même place au-dessus, quelle que soit l'échelle.
  static double _ligne(Size cadre, double tronc) => math.min(tronc * ligneEpaules / partTronc, cadre.height * 0.42);

  double get _tronc => math.sqrt(math.pow((hanches!.dx - epaules!.dx) * ratio, 2) + math.pow(hanches!.dy - epaules!.dy, 2));

  double _plein(Size cadre) => math.max(cadre.width / (ratio * zone.width), cadre.height / zone.height);

  /// Où poser cette image quand elle est comparée à [autre] dans un cadre de
  /// même taille : les deux corps sont exactement à la même échelle et les
  /// deux lignes d'épaules à la même hauteur. Si l'une des deux photos doit
  /// être agrandie pour couvrir son cadre, l'autre l'est autant.
  Rect placeAvec(Cadrage autre, Size cadre, {Alignment alignement = Alignment.center}) {
    if (epaules == null || hanches == null || autre.epaules == null || autre.hanches == null) return place(cadre, alignement: alignement);
    double base(Cadrage c) => _commune(cadre) / c._tronc;
    // Le même agrandissement pour les deux, celui de la plus exigeante.
    // Ce que chaque photo montre au-dessus et au-dessous des épaules.
    double dessus(Cadrage c) => (c.epaules!.dy - c.zone.top) * base(c);
    double dessous(Cadrage c) => (c.zone.bottom - c.epaules!.dy) * base(c);
    final plus = [
      1.0,
      _plein(cadre) / base(this),
      autre._plein(cadre) / base(autre),
      // Assez grand pour que les deux lignes d'épaules puissent tomber à la
      // même hauteur : le dessus de l'une et le dessous de l'autre doivent
      // remplir le cadre à eux deux.
      cadre.height / (dessus(this) + dessous(autre)),
      cadre.height / (dessus(autre) + dessous(this)),
    ].reduce(math.max);
    final k = base(this) * plus, ka = base(autre) * plus;
    // Hauteurs possibles de la ligne d'épaules sans découvrir le cadre.
    (double, double) bornes(Cadrage c, double k) => (cadre.height - c.zone.bottom * k + c.epaules!.dy * k, -c.zone.top * k + c.epaules!.dy * k);
    final (bas, haut) = bornes(this, k);
    final (basA, hautA) = bornes(autre, ka);
    final min = math.max(bas, basA), max = math.min(haut, hautA);
    // La hauteur commune : l'agrandissement choisi garantit qu'il en existe une.
    final ligne = _tenir(_ligne(cadre, _tronc * k), min, max);
    final x = _tenir(cadre.width / 2 - (epaules!.dx + hanches!.dx) / 2 * ratio * k, cadre.width - zone.right * ratio * k, -zone.left * ratio * k);
    final y = _tenir(ligne - epaules!.dy * k, cadre.height - zone.bottom * k, -zone.top * k);
    return Rect.fromLTWH(x, y, ratio * k, k);
  }

  /// Où poser cette image quand elle s'enchaîne avec toutes celles du
  /// [groupe] dans un cadre de même taille : même longueur de tronc et, tant
  /// que les photos le permettent, même ligne d'épaules pour toutes. Les
  /// photos trop serrées font agrandir tout le groupe, mais pas au-delà de
  /// [plusMax] : une seule photo mal prise ne gâche pas les autres.
  Rect placeParmi(List<Cadrage> groupe, Size cadre, {double plusMax = 1.3}) {
    if (epaules == null || hanches == null) return place(cadre);
    final corps = [for (final c in groupe) if (c.epaules != null && c.hanches != null) c];
    double base(Cadrage c) => _commune(cadre) / c._tronc;
    double dessus(Cadrage c) => (c.epaules!.dy - c.zone.top) * base(c);
    double dessous(Cadrage c) => (c.zone.bottom - c.epaules!.dy) * base(c);
    final plus = [
      1.0,
      for (final c in corps) c._plein(cadre) / base(c),
      cadre.height / (corps.map(dessus).reduce(math.min) + corps.map(dessous).reduce(math.min)),
    ].reduce(math.max).clamp(1.0, plusMax);
    // Chaque photo couvre au moins son cadre, même au-delà de l'échelle du groupe.
    double echelle(Cadrage c) => math.max(base(c) * plus, c._plein(cadre));
    final k = echelle(this);
    // La ligne d'épaules commune : celle que le plus de photos peuvent tenir.
    final voulue = _ligne(cadre, _commune(cadre) * plus);
    final min = corps.map((c) => cadre.height - (c.zone.bottom - c.epaules!.dy) * echelle(c)).reduce(math.max);
    final max = corps.map((c) => (c.epaules!.dy - c.zone.top) * echelle(c)).reduce(math.min);
    final ligne = min <= max ? _tenir(voulue, min, max) : voulue;
    final x = _tenir(cadre.width / 2 - (epaules!.dx + hanches!.dx) / 2 * ratio * k, cadre.width - zone.right * ratio * k, -zone.left * ratio * k);
    final y = _tenir(ligne - epaules!.dy * k, cadre.height - zone.bottom * k, -zone.top * k);
    return Rect.fromLTWH(x, y, ratio * k, k);
  }

  /// Les gains (rouge, vert, bleu) qui rapprochent la lumière de cette photo
  /// de celle d'[autre] : chacune fait un peu moins de la moitié du chemin,
  /// et la correction est bornée, pour ne changer ni le relief ni un vrai
  /// changement de teint. Null quand il n'y a rien à corriger.
  List<double>? gainsAvec(Cadrage autre) {
    final a = peau, b = autre.peau;
    if (a == null || b == null) return null;
    final g = [
      for (var c = 0; c < 3; c++) math.pow(math.sqrt(math.max(a[c], 1) * math.max(b[c], 1)) / math.max(a[c], 1), 0.7).toDouble(),
    ];
    final lum = ((g[0] + g[1] + g[2]) / 3).clamp(0.78, 1.3);
    final r = (g[0] / g[1]).clamp(0.9, 1.12), bl = (g[2] / g[1]).clamp(0.9, 1.12);
    final v = lum * 3 / (r + 1 + bl);
    final gains = [v * r, v, v * bl];
    return gains.every((x) => (x - 1).abs() < 0.015) ? null : gains;
  }
}

/// Une photo cadrée sur la personne, qui remplit tout son cadre.
class PhotoCadree extends StatefulWidget {
  const PhotoCadree({super.key, required this.fichier, this.paire, this.entiere = false, this.alignement = Alignment.center, this.secours = const SizedBox.shrink()});

  final File fichier;

  /// L'autre photo d'une comparaison : les deux sont alors alignées l'une
  /// sur l'autre et leur lumière rapprochée.
  final File? paire;

  /// La photo entière, sans ses bandes noires, plutôt que cadrée sur la personne.
  final bool entiere;

  /// Où garder l'image quand personne n'y est reconnu et qu'elle dépasse du cadre.
  final Alignment alignement;

  /// Affiché quand le fichier ne se lit pas.
  final Widget secours;

  @override
  State<PhotoCadree> createState() => _PhotoCadreeState();
}

class _PhotoCadreeState extends State<PhotoCadree> {
  Cadrage? _cadrage, _autre;
  bool _erreur = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void didUpdateWidget(PhotoCadree ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.fichier.path != widget.fichier.path || ancien.paire?.path != widget.paire?.path) _charger();
  }

  void _charger() {
    final chemin = widget.fichier.path, paire = widget.paire;
    _erreur = false;
    _cadrage = Cadrage.connu(chemin);
    _autre = paire == null ? null : Cadrage.connu(paire.path);
    if (_cadrage != null && (paire == null || _autre != null)) return;
    // Les deux cadrages arrivent ensemble : la photo ne saute pas en deux temps.
    _cadrage = null;
    bool actuel() => mounted && widget.fichier.path == chemin && widget.paire?.path == paire?.path;
    Future.wait([
      Cadrage.de(widget.fichier),
      // L'autre photo illisible n'empêche pas de montrer celle-ci.
      if (paire != null) Cadrage.de(paire).then<Cadrage?>((c) => c, onError: (Object _) => null),
    ]).then((r) {
      if (!actuel()) return;
      setState(() {
        _cadrage = r[0];
        _autre = r.length > 1 ? r[1] : null;
      });
    }, onError: (Object _) {
      if (actuel()) setState(() => _erreur = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _cadrage;
    if (_erreur) return widget.secours;
    if (c == null) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, boite) {
        final cadre = boite.biggest;
        if (!cadre.isFinite || cadre.isEmpty) return const SizedBox.shrink();
        final autre = _autre;
        final place = widget.entiere
            ? Cadrage(c.zone, c.ratio).place(cadre, alignement: widget.alignement)
            : autre == null
                ? c.place(cadre, alignement: widget.alignement)
                : c.placeAvec(autre, cadre, alignement: widget.alignement);
        final g = autre == null ? null : c.gainsAvec(autre);
        // Décodée à la taille affichée (par paliers), pas en pleine
        // résolution : une grille de photos de 12 Mpx tient en mémoire.
        final largeur = ((place.width * MediaQuery.devicePixelRatioOf(context) / 256).ceil() * 256).clamp(256, 2048);
        return ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fromRect(
                rect: place,
                child: Image.file(
                  widget.fichier,
                  fit: BoxFit.fill,
                  cacheWidth: largeur,
                  gaplessPlayback: true,
                  // La lumière rapprochée de celle de l'autre photo.
                  errorBuilder: (context, _, _) => widget.secours,
                  frameBuilder: g == null
                      ? null
                      : (context, enfant, _, _) => ColorFiltered(
                            colorFilter: ColorFilter.matrix([g[0], 0, 0, 0, 0, 0, g[1], 0, 0, 0, 0, 0, g[2], 0, 0, 0, 0, 0, 1, 0]),
                            child: enfant,
                          ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
