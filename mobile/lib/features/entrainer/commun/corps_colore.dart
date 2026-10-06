import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/ui/body/body_images.dart';

/// Teinte d'un muscle allumé. Les calques du personnage sont orangés ; on
/// tourne leur couleur comme la maquette, ce qui garde leur relief et
/// laisse intactes les parties grises du calque.
enum Teinte {
  /// Rouge des muscles principaux.
  principal(-18, 1.2, 1),

  /// Bleu des muscles secondaires.
  secondaire(222, 0.85, 1.25);

  const Teinte(this.rotation, this.saturation, this.luminosite);

  /// Rotation de la teinte, en degrés.
  final double rotation;
  final double saturation;
  final double luminosite;

  static final _matrices = <Teinte, List<double>>{};

  /// Matrice de couleur : rotation de teinte, saturation puis luminosité.
  List<double> get matrice => _matrices.putIfAbsent(this, () {
        final a = rotation * math.pi / 180;
        final c = math.cos(a), s = math.sin(a);
        final h = [
          0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928,
          0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283,
          0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072,
        ];
        final k = saturation;
        final t = [
          0.213 + 0.787 * k, 0.715 - 0.715 * k, 0.072 - 0.072 * k,
          0.213 - 0.213 * k, 0.715 + 0.285 * k, 0.072 - 0.072 * k,
          0.213 - 0.213 * k, 0.715 - 0.715 * k, 0.072 + 0.928 * k,
        ];
        double m(int i, int j) => luminosite * (t[i * 3] * h[j] + t[i * 3 + 1] * h[3 + j] + t[i * 3 + 2] * h[6 + j]);
        return [
          m(0, 0), m(0, 1), m(0, 2), 0, 0,
          m(1, 0), m(1, 1), m(1, 2), 0, 0,
          m(2, 0), m(2, 1), m(2, 2), 0, 0,
          0, 0, 0, 1, 0,
        ];
      });
}

/// Le personnage avec une couleur par muscle (principal en rouge,
/// secondaire en bleu...). Le noyau n'offre qu'une couleur à la fois ; ce
/// widget relit les mêmes images et les mêmes calques.
class CorpsColore extends StatefulWidget {
  const CorpsColore({
    super.key,
    this.view = BodyView.front,
    this.couleurs = const {},
    this.framing = BodyFraming.corps,
    this.height,
    this.onTap,
  });

  final BodyView view;

  /// Teinte de chaque muscle allumé ; les autres restent gris.
  final Map<Muscle, Teinte> couleurs;
  final BodyFraming framing;
  final double? height;
  final ValueChanged<Muscle>? onTap;

  static double rapport(BodyFraming f) {
    final s = BodyImageRepository.sizeOf(f);
    return s.width / s.height;
  }

  @override
  State<CorpsColore> createState() => _CorpsColoreState();
}

class _CorpsColoreState extends State<CorpsColore> {
  BodyImages? _imgs;
  Map<Muscle, ui.Image> _calques = const {};
  int _jeton = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void didUpdateWidget(CorpsColore old) {
    super.didUpdateWidget(old);
    if (old.view != widget.view || old.framing != widget.framing) {
      _imgs = null;
      _calques = const {};
      _charger();
    } else if (!_memesMuscles(old.couleurs, widget.couleurs)) {
      _chargerCalques();
    }
  }

  static bool _memesMuscles(Map<Muscle, Teinte> a, Map<Muscle, Teinte> b) => a.length == b.length && a.keys.every(b.containsKey);

  Future<void> _charger() async {
    final j = ++_jeton;
    final deja = BodyImageRepository.peek(widget.view, widget.framing);
    if (deja != null) {
      _imgs = deja;
      _calques = _prets(deja);
    }
    final imgs = deja ?? await BodyImageRepository.load(widget.view, widget.framing);
    if (!mounted || j != _jeton) return;
    if (deja == null) setState(() => _imgs = imgs);
    await _chargerCalques();
  }

  Map<Muscle, ui.Image> _prets(BodyImages imgs) {
    final out = <Muscle, ui.Image>{};
    for (final m in widget.couleurs.keys) {
      if (!imgs.muscles.contains(m)) continue;
      final img = BodyImageRepository.peekMask(imgs, m);
      if (img != null) out[m] = img;
    }
    return out;
  }

  Future<void> _chargerCalques() async {
    final imgs = _imgs;
    if (imgs == null) return;
    final j = _jeton;
    final voulus = widget.couleurs.keys.where(imgs.muscles.contains).toList();
    final prets = _prets(imgs);
    if (mounted) setState(() => _calques = prets);
    if (prets.length == voulus.length) return;
    // Tous les calques d'un coup : l'ordre des couleurs est gardé.
    final images = await Future.wait([for (final m in voulus) BodyImageRepository.loadMask(imgs, m)]);
    final tous = <Muscle, ui.Image>{for (final (i, m) in voulus.indexed) m: images[i]};
    if (!mounted || j != _jeton || _imgs != imgs) return;
    setState(() => _calques = tous);
  }

  @override
  Widget build(BuildContext context) {
    final imgs = _imgs;
    Widget dessin = imgs == null
        ? const SizedBox.expand()
        : CustomPaint(
            size: Size.infinite,
            painter: _Peintre(imgs, [
              for (final e in widget.couleurs.entries)
                if (_calques[e.key] != null) (_calques[e.key]!, e.value),
            ]),
          );
    if (widget.onTap != null && imgs != null) {
      final fond = dessin;
      dessin = LayoutBuilder(
        builder: (context, box) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) async {
            final r = _Peintre.cible(imgs.size, box.biggest);
            final f = Offset((d.localPosition.dx - r.left) / r.width, (d.localPosition.dy - r.top) / r.height);
            if (f.dx < 0 || f.dy < 0 || f.dx > 1 || f.dy > 1) return;
            final m = await BodyImageRepository.hitTest(imgs, f);
            if (m != null && mounted) widget.onTap?.call(m);
          },
          child: fond,
        ),
      );
    }
    final ratio = CorpsColore.rapport(widget.framing);
    return Semantics(
      image: true,
      label: 'Personnage, vue de ${widget.view.label}',
      child: widget.height == null
          ? AspectRatio(aspectRatio: ratio, child: dessin)
          : SizedBox(height: widget.height, width: widget.height! * ratio, child: dessin),
    );
  }
}

class _Peintre extends CustomPainter {
  _Peintre(this.imgs, this.calques);

  final BodyImages imgs;
  final List<(ui.Image, Teinte)> calques;

  static Rect cible(Size image, Size zone) {
    final s = (zone.width / image.width) < (zone.height / image.height) ? zone.width / image.width : zone.height / image.height;
    final w = image.width * s, h = image.height * s;
    return Rect.fromLTWH((zone.width - w) / 2, (zone.height - h) / 2, w, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dst = cible(imgs.size, size);
    canvas.drawImageRect(imgs.base, Offset.zero & imgs.size, dst, Paint()..filterQuality = FilterQuality.medium);
    for (final (calque, couleur) in calques) {
      final p = Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.matrix(couleur.matrice);
      canvas.drawImageRect(calque, Offset.zero & Size(calque.width.toDouble(), calque.height.toDouble()), dst, p);
    }
  }

  @override
  bool shouldRepaint(_Peintre old) {
    if (old.imgs != imgs || old.calques.length != calques.length) return true;
    for (var i = 0; i < calques.length; i++) {
      if (old.calques[i] != calques[i]) return true;
    }
    return false;
  }
}

/// Face et dos côte à côte, à la même hauteur.
class CorpsFaceDos extends StatelessWidget {
  const CorpsFaceDos({super.key, required this.couleurs, required this.hauteur, this.ecart = 42, this.onTap});

  final Map<Muscle, Teinte> couleurs;
  final double hauteur;
  final double ecart;
  final ValueChanged<Muscle>? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        // Deux corps et leur écart doivent tenir dans la largeur offerte.
        final max = box.maxWidth.isFinite ? (box.maxWidth - ecart) / 2 / CorpsColore.rapport(BodyFraming.corps) : hauteur;
        final h = hauteur < max ? hauteur : max;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CorpsColore(view: BodyView.front, couleurs: couleurs, height: h, onTap: onTap),
            SizedBox(width: ecart),
            CorpsColore(view: BodyView.back, couleurs: couleurs, height: h, onTap: onTap),
          ],
        );
      });
}

/// Couleurs « muscles allumés » d'un ensemble de muscles.
Map<Muscle, Teinte> allumer(Iterable<Muscle> muscles) => {for (final m in muscles) m: Teinte.principal};
