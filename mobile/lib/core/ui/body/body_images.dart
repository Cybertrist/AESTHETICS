import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../../models/muscle.dart';

/// Vue du personnage.
enum BodyView {
  front('face'),
  back('dos');

  const BodyView(this.label);
  final String label;
}

/// Cadrage : corps entier, buste (du menton aux hanches) ou jambes (de la taille aux pieds).
enum BodyFraming {
  corps(''),
  buste('_buste'),
  jambes('_jambes');

  const BodyFraming(this.suffix);
  final String suffix;
}

/// Genre du personnage. Le pack n'a qu'un bonhomme : les deux genres
/// partagent ses images pour l'instant.
enum BodyGender {
  homme('assets/body/pack'),
  femme('assets/body/pack');

  const BodyGender(this.dossier);
  final String dossier;
}

/// Images d'une vue : corps gris et calques de muscles disponibles.
class BodyImages {
  BodyImages._(this.gender, this.prefix, this.base, this.size, this.muscles);

  final BodyGender gender;
  final String prefix;
  final ui.Image base;
  final Size size;

  /// Muscles qui ont un calque sur cette vue.
  final Set<Muscle> muscles;

  // Carte réduite des muscles (index + 1, 0 hors muscle), construite au premier toucher.
  Uint8List? _carte;
  int _carteLargeur = 0, _carteHauteur = 0;
}

/// Chargement, cache et lecture des images du personnage : le bonhomme des
/// animations d'exercices (voir tools/repdb/corps.mjs).
abstract final class BodyImageRepository {
  static const _largeurCarte = 190;

  static final Map<BodyGender, Future<Map<String, dynamic>>> _manif = {};
  static final Map<String, Future<BodyImages>> _pending = {};
  static final Map<String, BodyImages> _ready = {};
  static final LinkedHashMap<String, ui.Image> _masques = LinkedHashMap();
  static final Map<String, Future<ui.Image>> _masquesEnCours = {};
  static const _maxMasques = 40;

  static String prefix(BodyView v, BodyFraming f) => '${v.label}${f.suffix}';
  static String _cle(BodyView v, BodyFraming f, BodyGender g) => '${g.name}/${prefix(v, f)}';

  /// Taille de l'image d'un cadrage (connue avant chargement, la même pour les deux genres).
  static Size sizeOf(BodyFraming f) => f == BodyFraming.corps ? const Size(636, 1500) : const Size(636, 636);

  /// Images déjà chargées, sans attendre.
  static BodyImages? peek(BodyView v, BodyFraming f, {BodyGender gender = BodyGender.homme}) => _ready[_cle(v, f, gender)];

  static Future<ui.Image> _decode(AssetBundle bundle, String asset, {int? largeur}) async {
    final data = await bundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: largeur);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<BodyImages> load(BodyView v, BodyFraming f, {AssetBundle? bundle, BodyGender gender = BodyGender.homme}) {
    final p = prefix(v, f);
    final d = gender.dossier;
    return _pending.putIfAbsent(_cle(v, f, gender), () async {
      final b = bundle ?? rootBundle;
      final manif = await (_manif[gender] ??=
          b.loadString('$d/manifeste.json').then((s) => jsonDecode(s) as Map<String, dynamic>));
      final entree = manif[p] as Map<String, dynamic>;
      final muscles = {
        for (final n in (entree['masques'] as List)) ?Muscle.tryParse(n),
      };
      final base = await _decode(b, '$d/${p}_base.webp');
      return _ready[_cle(v, f, gender)] =
          BodyImages._(gender, p, base, Size(base.width.toDouble(), base.height.toDouble()), muscles);
    });
  }

  /// Précharge la face et le dos du corps entier (à appeler au démarrage, facultatif).
  static Future<void> precache({BodyGender gender = BodyGender.homme}) =>
      Future.wait([for (final v in BodyView.values) load(v, BodyFraming.corps, gender: gender)]);

  static String _masque(BodyImages imgs, Muscle m) => '${imgs.gender.dossier}/${imgs.prefix}_${m.name}.webp';

  /// Calque d'un muscle (déjà coloré et ombré, alpha = couverture), décodé à la demande et gardé en cache.
  static ui.Image? peekMask(BodyImages imgs, Muscle m) {
    final k = _masque(imgs, m);
    final hit = _masques.remove(k);
    if (hit != null) _masques[k] = hit;
    return hit;
  }

  static Future<ui.Image> loadMask(BodyImages imgs, Muscle m, {AssetBundle? bundle}) {
    final k = _masque(imgs, m);
    final deja = _masques[k];
    if (deja != null) return Future.value(deja);
    return _masquesEnCours.putIfAbsent(k, () async {
      final img = await _decode(bundle ?? rootBundle, k);
      _masquesEnCours.remove(k);
      _masques[k] = img;
      if (_masques.length > _maxMasques) _masques.remove(_masques.keys.first);
      return img;
    });
  }

  /// Muscle sous un point exprimé en fraction de l'image (0..1), lu dans les masques.
  static Future<Muscle?> hitTest(BodyImages imgs, Offset fraction, {AssetBundle? bundle}) async {
    if (imgs._carte == null) await _construireCarte(imgs, bundle ?? rootBundle);
    final w = imgs._carteLargeur, h = imgs._carteHauteur, carte = imgs._carte!;
    final cx = (fraction.dx * w).floor(), cy = (fraction.dy * h).floor();
    // tolérance de quelques pixels autour du doigt, le plus proche d'abord
    for (var r = 0; r <= 3; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dy.abs() != r) continue;
          final x = cx + dx, y = cy + dy;
          if (x < 0 || y < 0 || x >= w || y >= h) continue;
          final v = carte[y * w + x];
          if (v > 0) return Muscle.values[v - 1];
        }
      }
    }
    return null;
  }

  static Future<void> _construireCarte(BodyImages imgs, AssetBundle bundle) async {
    final w = _largeurCarte;
    final h = (w * imgs.size.height / imgs.size.width).round();
    final carte = Uint8List(w * h);
    final meilleur = Uint8List(w * h);
    for (final m in imgs.muscles) {
      final img = await _decode(bundle, _masque(imgs, m), largeur: w);
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final n = (img.width * img.height).clamp(0, w * h);
      img.dispose();
      if (data == null) continue;
      for (var i = 0; i < n; i++) {
        final a = data.getUint8(i * 4 + 3);
        // les rhomboïdes, sous le trapèze, passent devant lui
        if (a > 48 && (a > meilleur[i] || m == Muscle.rhomboides)) {
          meilleur[i] = a;
          carte[i] = m.index + 1;
        }
      }
    }
    imgs
      .._carte = carte
      .._carteLargeur = w
      .._carteHauteur = h;
  }

  /// Autre couleur que l'orangé du calque : la couleur multipliée par
  /// l'ombrage du calque (sa luminance, ramenée vers 1 au plus clair).
  static List<double> tintMatrix(Color c) {
    const gain = 1 / 0.62;
    const r = 0.299 * gain, g = 0.587 * gain, b = 0.114 * gain;
    return [
      c.r * r, c.r * g, c.r * b, 0, 0,
      c.g * r, c.g * g, c.g * b, 0, 0,
      c.b * r, c.b * g, c.b * b, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}
