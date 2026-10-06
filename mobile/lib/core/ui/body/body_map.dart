import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/muscle.dart';
import '../../theme/app_colors.dart';
import 'body_images.dart';

export 'body_images.dart' show BodyView, BodyFraming, BodyGender, BodyImageRepository;

/// Personnage anatomique gris (le bonhomme des animations d'exercices), muscles travaillés colorés selon leur intensité.
///
/// `intensities` : 0 gris, 1 couleur pleine (l'orangé du dessin par défaut, ou `highlight`).
/// La couleur suit l'ombrage du calque : relief et fibres restent visibles.
/// `selected` : muscles mis en avant avec l'accent du thème (choix d'un filtre, par exemple).
/// `onTap` : rend les muscles touchables (lecture des calques).
/// `framing` : corps entier (par défaut), buste ou jambes.
/// `gender` : homme (par défaut) ou femme.
class BodyMap extends StatefulWidget {
  const BodyMap({
    super.key,
    this.view = BodyView.front,
    this.intensities = const {},
    this.highlight,
    this.selected = const {},
    this.onTap,
    this.height,
    this.framing = BodyFraming.corps,
    this.gender = BodyGender.homme,
  });

  final BodyView view;
  final Map<Muscle, double> intensities;
  final Color? highlight;
  final Set<Muscle> selected;
  final ValueChanged<Muscle>? onTap;
  final double? height;
  final BodyFraming framing;
  final BodyGender gender;

  /// Largeur sur hauteur du corps entier.
  static const double aspectRatio = 636 / 1500;

  static double aspectOf(BodyFraming f) {
    final s = BodyImageRepository.sizeOf(f);
    return s.width / s.height;
  }

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> {
  BodyImages? _imgs;
  Map<Muscle, ui.Image> _masques = const {};
  int _jeton = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void didUpdateWidget(BodyMap old) {
    super.didUpdateWidget(old);
    if (old.view != widget.view || old.framing != widget.framing || old.gender != widget.gender) {
      _imgs = null;
      _masques = const {};
      _charger();
    } else if (old.intensities != widget.intensities || old.selected != widget.selected) {
      _chargerMasques();
    }
  }

  Set<Muscle> get _actifs => {
        for (final e in widget.intensities.entries)
          if (e.value > 0) e.key,
        ...widget.selected,
      };

  Future<void> _charger() async {
    final j = ++_jeton;
    final deja = BodyImageRepository.peek(widget.view, widget.framing, gender: widget.gender);
    final imgs = deja ?? await BodyImageRepository.load(widget.view, widget.framing, gender: widget.gender);
    if (!mounted || j != _jeton) return;
    setState(() => _imgs = imgs);
    _chargerMasques();
  }

  Future<void> _chargerMasques() async {
    final imgs = _imgs;
    if (imgs == null) return;
    final j = _jeton;
    final voulus = _actifs.where(imgs.muscles.contains).toList();
    // ce qui est déjà en cache s'affiche tout de suite
    final prets = <Muscle, ui.Image>{};
    for (final m in voulus) {
      final img = BodyImageRepository.peekMask(imgs, m);
      if (img != null) prets[m] = img;
    }
    if (prets.length != _masques.length || !prets.keys.every(_masques.containsKey)) {
      setState(() => _masques = prets);
    }
    if (prets.length == voulus.length) return;
    final tous = <Muscle, ui.Image>{};
    for (final m in voulus) {
      tous[m] = await BodyImageRepository.loadMask(imgs, m);
    }
    if (!mounted || j != _jeton || _imgs != imgs) return;
    setState(() => _masques = tous);
  }

  /// Calque, couleur (null : l'orangé du dessin), opacité.
  List<(ui.Image, Color?, double)> _couches(BuildContext context) {
    final out = <Muscle, (Color?, double)>{
      for (final e in widget.intensities.entries)
        if (e.value > 0) e.key: (widget.highlight, e.value.clamp(0.0, 1.0)),
      for (final m in widget.selected) m: (context.colors.accent, 1.0),
    };
    return [
      for (final e in out.entries)
        if (_masques[e.key] != null) (_masques[e.key]!, e.value.$1, e.value.$2),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ratio = BodyMap.aspectOf(widget.framing);
    final imgs = _imgs;
    Widget body = imgs == null
        ? const SizedBox.expand()
        : CustomPaint(
            size: Size.infinite,
            painter: _BodyPainter(imgs, _couches(context)),
          );
    if (widget.onTap != null && imgs != null) {
      // le dessin est capturé avant de réaffecter `body`, sinon le constructeur s'imbrique sans fin
      final dessin = body;
      body = LayoutBuilder(builder: (context, box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) async {
            final r = _BodyPainter.cible(imgs.size, box.biggest);
            final f = Offset((d.localPosition.dx - r.left) / r.width, (d.localPosition.dy - r.top) / r.height);
            if (f.dx < 0 || f.dy < 0 || f.dx > 1 || f.dy > 1) return;
            final m = await BodyImageRepository.hitTest(imgs, f);
            if (m != null && mounted) widget.onTap?.call(m);
          },
          child: dessin,
        );
      });
    }
    return Semantics(
      image: true,
      label: 'Personnage, vue de ${widget.view.label}',
      child: widget.height == null
          ? AspectRatio(aspectRatio: ratio, child: body)
          : SizedBox(height: widget.height, width: widget.height! * ratio, child: body),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.imgs, this.couches);

  final BodyImages imgs;
  final List<(ui.Image, Color?, double)> couches;

  // Rectangle de l'image dans la zone (BoxFit.contain, centré).
  static Rect cible(Size image, Size zone) {
    final s = (zone.width / image.width) < (zone.height / image.height) ? zone.width / image.width : zone.height / image.height;
    final w = image.width * s, h = image.height * s;
    return Rect.fromLTWH((zone.width - w) / 2, (zone.height - h) / 2, w, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dst = cible(imgs.size, size);
    final src = Offset.zero & imgs.size;
    final fin = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(imgs.base, src, dst, fin);
    for (final (calque, couleur, t) in couches) {
      final p = Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, t);
      if (couleur != null) p.colorFilter = ColorFilter.matrix(BodyImageRepository.tintMatrix(couleur));
      canvas.drawImageRect(calque, Offset.zero & Size(calque.width.toDouble(), calque.height.toDouble()), dst, p);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) {
    if (old.imgs != imgs || old.couches.length != couches.length) return true;
    for (var i = 0; i < couches.length; i++) {
      if (old.couches[i] != couches[i]) return true;
    }
    return false;
  }
}

/// Face et dos côte à côte, mêmes réglages.
class BodyMapDual extends StatelessWidget {
  const BodyMapDual({
    super.key,
    this.intensities = const {},
    this.highlight,
    this.selected = const {},
    this.onTap,
    this.height,
    this.spacing = 8,
    this.labels = false,
    this.framing = BodyFraming.corps,
    this.gender = BodyGender.homme,
  });

  final Map<Muscle, double> intensities;
  final Color? highlight;
  final Set<Muscle> selected;
  final ValueChanged<Muscle>? onTap;
  final double? height;
  final double spacing;
  final BodyFraming framing;
  final BodyGender gender;

  /// Affiche « Face » et « Dos » sous chaque vue.
  final bool labels;

  @override
  Widget build(BuildContext context) {
    Widget one(BodyView v) {
      final map = BodyMap(
        view: v,
        intensities: intensities,
        highlight: highlight,
        selected: selected,
        onTap: onTap,
        height: height,
        framing: framing,
        gender: gender,
      );
      if (!labels) return map;
      final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.text3);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        map,
        const SizedBox(height: 6),
        Text(v == BodyView.front ? 'Face' : 'Dos', style: style),
      ]);
    }

    if (height != null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        one(BodyView.front),
        SizedBox(width: spacing),
        one(BodyView.back),
      ]);
    }
    return Row(children: [
      Expanded(child: one(BodyView.front)),
      SizedBox(width: spacing),
      Expanded(child: one(BodyView.back)),
    ]);
  }
}
