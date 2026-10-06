import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Une roue de chiffres qui boucle. Brique commune de [RoueDuree] et de
/// [RoueMinSec] ; utilisable seule pour un autre réglage.
class RoueChiffres extends StatefulWidget {
  const RoueChiffres({
    super.key,
    required this.value,
    required this.count,
    required this.onChanged,
    this.extent = 56,
    this.unite,
    this.traits = true,
    this.deuxChiffres = false,
    this.tailleChoisie = 32,
    this.tailleAutre = 27,
    this.poidsChoisi = FontWeight.w700,
    this.couleurAutre = AppTokens.text3,
    this.pas = 1,
  });

  /// Valeur choisie, de 0 à `count * pas - pas`.
  final int value;

  /// Nombre de crans.
  final int count;
  final ValueChanged<int> onChanged;

  /// Hauteur d'un cran. La roue montre trois crans.
  final double extent;

  /// Unité posée à droite de la valeur choisie (« h », « m », « s »).
  final String? unite;

  /// Deux traits autour de la valeur choisie.
  final bool traits;

  /// Affiche « 02 » plutôt que « 2 ».
  final bool deuxChiffres;
  final double tailleChoisie;
  final double tailleAutre;
  final FontWeight poidsChoisi;
  final Color couleurAutre;

  /// Écart entre deux crans (5 pour des secondes de 5 en 5).
  final int pas;

  @override
  State<RoueChiffres> createState() => _RoueChiffresState();
}

class _RoueChiffresState extends State<RoueChiffres> {
  late FixedExtentScrollController _ctrl;
  late int _index;

  int get _cran => (widget.value ~/ widget.pas).clamp(0, widget.count - 1);

  @override
  void initState() {
    super.initState();
    _index = _cran;
    _ctrl = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void didUpdateWidget(RoueChiffres old) {
    super.didUpdateWidget(old);
    final actuel = _index % widget.count;
    if (_cran != actuel) {
      // Valeur changée de l'extérieur : on tourne par le plus court chemin.
      var delta = _cran - actuel;
      if (delta > widget.count / 2) delta -= widget.count;
      if (delta < -widget.count / 2) delta += widget.count;
      _index += delta;
      _ctrl.animateToItem(_index, duration: AppTokens.normal, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _texte(int cran) {
    final v = cran * widget.pas;
    return widget.deuxChiffres ? v.toString().padLeft(2, '0') : '$v';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final choisi = _index % widget.count;
    return Semantics(
      label: widget.unite,
      value: _texte(choisi),
      child: SizedBox(
        height: widget.extent * 3,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.traits)
              IgnorePointer(
                child: Container(
                  height: widget.extent,
                  decoration: BoxDecoration(
                    border: Border.symmetric(horizontal: BorderSide(color: c.text2, width: 1.5)),
                  ),
                ),
              ),
            if (widget.unite != null)
              Positioned(
                right: 8,
                child: Text(
                  widget.unite!,
                  style: TextStyle(
                    fontFamily: AppTokens.fontUi,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: c.text2,
                  ),
                ),
              ),
            ListWheelScrollView.useDelegate(
              controller: _ctrl,
              itemExtent: widget.extent,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 100,
              perspective: 0.0001,
              overAndUnderCenterOpacity: 1,
              onSelectedItemChanged: (i) {
                if (i == _index) return;
                final avant = _index % widget.count;
                setState(() => _index = i);
                final apres = i % widget.count;
                if (apres != avant) {
                  HapticFeedback.selectionClick();
                  if (apres != _cran) widget.onChanged(apres * widget.pas);
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, i) {
                  final cran = i % widget.count;
                  final on = cran == choisi;
                  return Center(
                    child: Text(
                      _texte(cran),
                      style: TextStyle(
                        fontFamily: AppTokens.fontUi,
                        fontSize: on ? widget.tailleChoisie : widget.tailleAutre,
                        height: 1,
                        fontWeight: on ? widget.poidsChoisi : FontWeight.w600,
                        color: on ? c.text : widget.couleurAutre,
                        fontFeatures: AppTokens.tabular,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trois roues séparées, heures, minutes, secondes, la valeur choisie entre
/// deux traits avec son unité (« Corriger la durée »). À poser dans un
/// panneau du bas.
///
/// ```dart
/// RoueDuree(value: duree, onChanged: (d) => setState(() => duree = d))
/// ```
class RoueDuree extends StatelessWidget {
  const RoueDuree({super.key, required this.value, required this.onChanged, this.maxHeures = 23});

  final Duration value;
  final ValueChanged<Duration> onChanged;
  final int maxHeures;

  @override
  Widget build(BuildContext context) {
    final total = value.inSeconds.clamp(0, (maxHeures + 1) * 3600 - 1);
    final h = total ~/ 3600;
    final m = total % 3600 ~/ 60;
    final s = total % 60;
    void change({int? hh, int? mm, int? ss}) =>
        onChanged(Duration(hours: hh ?? h, minutes: mm ?? m, seconds: ss ?? s));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: RoueChiffres(value: h, count: maxHeures + 1, unite: 'h', onChanged: (v) => change(hh: v))),
          const SizedBox(width: 16),
          Expanded(child: RoueChiffres(value: m, count: 60, unite: 'm', onChanged: (v) => change(mm: v))),
          const SizedBox(width: 16),
          Expanded(child: RoueChiffres(value: s, count: 60, unite: 's', onChanged: (v) => change(ss: v))),
        ],
      ),
    );
  }
}

/// Deux grandes roues, minutes et secondes, séparées par deux points
/// (« Repos : régler la durée »). Sans traits : la valeur choisie est
/// blanche, les voisines presque éteintes.
///
/// ```dart
/// RoueMinSec(value: repos, pasSecondes: 5, onChanged: (d) => ...)
/// ```
class RoueMinSec extends StatelessWidget {
  const RoueMinSec({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxMinutes = 59,
    this.pasSecondes = 1,
    this.libelles = true,
  });

  final Duration value;
  final ValueChanged<Duration> onChanged;
  final int maxMinutes;

  /// Écart entre deux crans de secondes (1, 5, 10, 15...).
  final int pasSecondes;

  /// « Minutes » et « Secondes » au-dessus des roues.
  final bool libelles;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = value.inSeconds.clamp(0, maxMinutes * 60 + 59);
    final m = total ~/ 60;
    final s = total % 60;
    const largeur = 120.0;
    Widget roue(int v, int count, int pas, ValueChanged<int> on) => SizedBox(
          width: largeur,
          child: RoueChiffres(
            value: v,
            count: count,
            pas: pas,
            onChanged: on,
            extent: 84,
            traits: false,
            deuxChiffres: true,
            tailleChoisie: 62,
            tailleAutre: 62,
            poidsChoisi: FontWeight.w600,
            couleurAutre: AppTokens.frame,
          ),
        );
    Widget libelle(String t) => SizedBox(
          width: largeur,
          child: Text(
            t,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, color: c.text2),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (libelles) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [libelle('Minutes'), const SizedBox(width: 30), libelle('Secondes')],
          ),
          const SizedBox(height: 4),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            roue(m, maxMinutes + 1, 1, (v) => onChanged(Duration(minutes: v, seconds: s))),
            SizedBox(
              width: 30,
              child: Text(
                ':',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTokens.fontUi,
                  fontSize: 54,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
            roue(s, (60 / pasSecondes).ceil(), pasSecondes, (v) => onChanged(Duration(minutes: m, seconds: v))),
          ],
        ),
      ],
    );
  }
}
