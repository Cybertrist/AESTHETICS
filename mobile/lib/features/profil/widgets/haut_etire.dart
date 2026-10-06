import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Deux blocs l'un sous l'autre : [bas] prend sa hauteur naturelle, [haut]
/// s'étire pour que l'ensemble atteigne la hauteur minimale donnée par le
/// parent (celle de l'écran), sans jamais descendre sous sa propre hauteur
/// minimale ni s'étirer de plus de [etirementMax].
///
/// À poser dans une zone défilante contrainte en hauteur minimale : sur un
/// écran court, la page défile ; sur un écran haut, elle le remplit.
class HautEtire extends MultiChildRenderObjectWidget {
  HautEtire({super.key, required Widget haut, required Widget bas, this.etirementMax = double.infinity}) : super(children: [haut, bas]);

  final double etirementMax;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenduHautEtire(etirementMax);

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    (renderObject as _RenduHautEtire).etirementMax = etirementMax;
  }
}

class _Place extends ContainerBoxParentData<RenderBox> {}

class _RenduHautEtire extends RenderBox with ContainerRenderObjectMixin<RenderBox, _Place>, RenderBoxContainerDefaultsMixin<RenderBox, _Place> {
  _RenduHautEtire(this._etirementMax);

  double _etirementMax;
  set etirementMax(double v) {
    if (v == _etirementMax) return;
    _etirementMax = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Place) child.parentData = _Place();
  }

  @override
  void performLayout() {
    final haut = firstChild!;
    final bas = childAfter(haut)!;
    final largeur = constraints.maxWidth;
    bas.layout(BoxConstraints.tightFor(width: largeur), parentUsesSize: true);
    final mini = haut.getMinIntrinsicHeight(largeur);
    final reste = constraints.minHeight - bas.size.height;
    final hauteur = math.max(mini, math.min(reste, mini + _etirementMax));
    haut.layout(BoxConstraints.tightFor(width: largeur, height: hauteur), parentUsesSize: true);
    (haut.parentData! as _Place).offset = Offset.zero;
    (bas.parentData! as _Place).offset = Offset(0, hauteur);
    size = constraints.constrain(Size(largeur, hauteur + bas.size.height));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
