import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Les objets 3D embarqués (`assets/objets/`, licence MIT, voir
/// `docs/SOURCES_OBJETS.md`) : équivalents du poids soulevé, médailles.
abstract final class Objets3D {
  static const _d = 'assets/objets';

  static const chat = '$_d/cat_3d.png';
  static const toilettes = '$_d/toilet_3d.png';
  static const burger = '$_d/hamburger_3d.png';
  static const baignoire = '$_d/bathtub_3d.png';
  static const canape = '$_d/couch_and_lamp_3d.png';
  static const tracteur = '$_d/tractor_3d.png';
  static const soucoupe = '$_d/flying_saucer_3d.png';
  static const mammouth = '$_d/mammoth_3d.png';
  static const moai = '$_d/moai_3d.png';
  static const camionPompiers = '$_d/fire_engine_3d.png';
  static const baleine = '$_d/whale_3d.png';
  static const elephant = '$_d/elephant_3d.png';
  static const tRex = '$_d/t-rex_3d.png';
  static const fusee = '$_d/rocket_3d.png';
  static const bus = '$_d/bus_3d.png';
  static const avion = '$_d/airplane_3d.png';
  static const statueLiberte = '$_d/statue_of_liberty_3d.png';
  static const gorille = '$_d/gorilla_3d.png';
  static const vache = '$_d/cow_3d.png';
  static const baguette = '$_d/baguette_bread_3d.png';
  static const voiture = '$_d/automobile_3d.png';
  static const moto = '$_d/motorcycle_3d.png';
  static const girafe = '$_d/giraffe_3d.png';
  static const hippopotame = '$_d/hippopotamus_3d.png';
  static const cheval = '$_d/horse_3d.png';
  static const panda = '$_d/panda_3d.png';
  static const oursPolaire = '$_d/polar_bear_3d.png';
  static const rhinoceros = '$_d/rhinoceros_3d.png';
  static const sauropode = '$_d/sauropod_3d.png';
  static const requin = '$_d/shark_3d.png';
  static const tourTokyo = '$_d/tokyo_tower_3d.png';
  static const trophee = '$_d/trophy_3d.png';
  static const couronne = '$_d/crown_3d.png';
  static const gemme = '$_d/gem_stone_3d.png';
  static const medailleOr = '$_d/1st_place_medal_3d.png';
  static const medailleArgent = '$_d/2nd_place_medal_3d.png';
  static const medailleBronze = '$_d/3rd_place_medal_3d.png';
}

/// La scène « objet 3D » du bilan et des cartes de fin de séance : l'objet
/// au centre, légèrement penché, sur un halo de couleur ; deux copies floues
/// en haut à gauche et en bas à droite ; une pastille blanche « × N ».
///
/// ```dart
/// Objet3D(asset: Objets3D.baleine, multiple: 2, halo: Color(0xFF5AC8FA))
/// ```
class Objet3D extends StatelessWidget {
  const Objet3D({
    super.key,
    required this.asset,
    this.multiple,
    this.etiquette,
    this.halo = const Color(0xFF5AC8FA),
    this.hauteur = 290,
    this.copies = true,
  });

  /// Chemin de l'image, voir [Objets3D].
  final String asset;

  /// Affiche « × N » dans la pastille blanche.
  final int? multiple;

  /// Texte libre de la pastille, à la place de « × N ».
  final String? etiquette;

  /// Couleur du halo derrière l'objet (celle du titre mis en avant).
  final Color halo;
  final double hauteur;

  /// Les deux petites copies floues.
  final bool copies;

  Widget _image(double largeur, {double flou = 0, double ombre = 16}) {
    final img = Image.asset(asset, width: largeur, height: largeur, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ombre portée : la silhouette en noir, floutée, décalée vers le bas.
        Positioned(
          left: 0,
          top: ombre,
          child: Opacity(
            opacity: 0.45,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: ombre * 0.6, sigmaY: ombre * 0.6, tileMode: TileMode.decal),
              child: Image.asset(asset, width: largeur, height: largeur, fit: BoxFit.contain, color: Colors.black),
            ),
          ),
        ),
        if (flou > 0)
          ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: flou, sigmaY: flou, tileMode: TileMode.decal), child: img)
        else
          img,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = hauteur / 236;
    final texte = etiquette ?? (multiple == null ? null : '× $multiple');
    return ExcludeSemantics(
      child: SizedBox(
        height: hauteur,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              left: 22 * k,
              right: 22 * k,
              top: 14 * k,
              bottom: 14 * k,
              // Halo ovale : un dégradé rond étiré à la largeur de la boîte,
              // qui s'éteint exactement au bord (aucune arête visible).
              child: LayoutBuilder(
                builder: (context, box) => Center(
                  child: Transform.scale(
                    scaleX: box.maxHeight <= 0 ? 1 : box.maxWidth / box.maxHeight,
                    child: Container(
                      width: box.maxHeight,
                      height: box.maxHeight,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [halo.withValues(alpha: 0.5), halo.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (copies) ...[
              Positioned(
                left: 0,
                top: 6 * k,
                child: Opacity(
                  opacity: 0.9,
                  child: Transform.rotate(angle: -16 * math.pi / 180, child: _image(86 * k, flou: 1.5 * k, ombre: 8 * k)),
                ),
              ),
              Positioned(
                right: 4 * k,
                bottom: 10 * k,
                child: Opacity(
                  opacity: 0.85,
                  child: Transform.rotate(
                    angle: 14 * math.pi / 180,
                    child: Transform.flip(flipX: true, child: _image(68 * k, flou: 2.2 * k, ombre: 8 * k)),
                  ),
                ),
              ),
            ],
            Center(child: Transform.rotate(angle: -6 * math.pi / 180, child: _image(196 * k, ombre: 16 * k))),
            if (texte != null)
              Positioned(
                right: 8 * k,
                top: 12 * k,
                child: Transform.rotate(
                  angle: 8 * math.pi / 180,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 15 * k, vertical: 7 * k),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTokens.radiusPill,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18 * k, offset: Offset(0, 8 * k)),
                      ],
                    ),
                    child: Text(
                      texte,
                      style: TextStyle(
                        fontFamily: AppTokens.fontBilan,
                        fontSize: 22 * k,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: Colors.black,
                        fontFeatures: AppTokens.tabular,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
