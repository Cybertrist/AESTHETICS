import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import 'palette.dart';

/// Carte de jour d'une routine : cadre en dégradé, jour abrégé dans les
/// mêmes couleurs, fond sombre et légère lueur de la première couleur.
class CarteJour extends StatelessWidget {
  const CarteJour({super.key, required this.jour, this.taille = 68, this.fond, this.choisie = false, this.fondAnneau});

  /// 1 = lundi ... 7 = dimanche.
  final int jour;
  final double taille;

  /// Fond de la carte (celui de la page par défaut).
  final Color? fond;

  /// Anneau blanc autour de la carte (choix de la vignette).
  final bool choisie;

  /// Couleur entre la carte et l'anneau (le fond du panneau).
  final Color? fondAnneau;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (a, b) = PaletteEntrainer.jours[(jour - 1).clamp(0, 6)];
    final degrade = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]);
    final rayon = taille * 0.222;
    final bord = taille * 0.037;
    final anneau = fondAnneau ?? c.surface2;
    return Semantics(
      label: joursEntiers[(jour - 1).clamp(0, 6)],
      selected: choisie,
      child: ExcludeSemantics(
        child: Container(
          width: taille,
          height: taille,
          padding: EdgeInsets.all(bord),
          decoration: BoxDecoration(
            gradient: degrade,
            borderRadius: BorderRadius.circular(rayon),
            boxShadow: choisie
                ? [
                    BoxShadow(color: c.text, spreadRadius: 5),
                    BoxShadow(color: anneau, spreadRadius: 2.5),
                  ]
                : [BoxShadow(color: a, blurRadius: 19, spreadRadius: -7.5)],
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: fond ?? c.bg, borderRadius: BorderRadius.circular(rayon - bord)),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => degrade.createShader(r),
              child: Text(
                joursAbreges[(jour - 1).clamp(0, 6)],
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppTokens.fontUi,
                  fontSize: taille * 0.28,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
