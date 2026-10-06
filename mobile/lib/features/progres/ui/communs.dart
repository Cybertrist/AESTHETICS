import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';

/// Cotes de la maquette (dessinée sur 320 de large), portées à l'échelle du
/// téléphone : 1,25 fois le CSS.
abstract final class Cotes {
  /// Marge latérale des pages (18 dans la maquette).
  static const marge = 22.0;

  /// Espace entre deux blocs (deux fois 10 dans la maquette).
  static const bloc = 24.0;

  /// Espace entre deux cartes voisines.
  static const gouttiere = 10.0;

  /// Coins d'une carte, d'une tuile, d'une petite tuile.
  static const rCarte = 20.0;
  static const rTuile = 17.5;
  static const rPetite = 15.0;

  /// Largeur maximale du contenu (écran large : une colonne centrée).
  static const largeurMax = 560.0;
}

/// Style Figtree de la maquette.
TextStyle ts(double taille, FontWeight poids, Color couleur, {double? hauteur, double? espace}) => TextStyle(
      fontFamily: AppTokens.fontUi,
      fontSize: taille,
      fontWeight: poids,
      color: couleur,
      height: hauteur,
      letterSpacing: espace,
      fontFeatures: AppTokens.tabular,
    );

/// Page du module : fond noir, contenu sous la barre d'état, colonne centrée
/// sur écran large.
class PageProgres extends StatelessWidget {
  const PageProgres({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: Cotes.largeurMax), child: child),
        ),
      ),
    );
  }
}

/// Carte grise de la maquette (coins de 20).
class Carte extends StatelessWidget {
  const Carte({super.key, required this.child, this.padding = const EdgeInsets.all(15), this.onTap, this.rayon = Cotes.rCarte, this.semantique});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double rayon;

  /// Libellé lu par les lecteurs d'écran quand la carte est un bouton.
  final String? semantique;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget w = Padding(padding: padding, child: child);
    if (onTap != null) w = InkWell(onTap: onTap, child: w);
    w = Material(color: c.surface, borderRadius: BorderRadius.circular(rayon), clipBehavior: Clip.antiAlias, child: w);
    if (onTap == null) return w;
    return Semantics(button: true, label: semantique, child: w);
  }
}

/// Petite étiquette en capitales espacées (« VOLUME SOULEVÉ »).
class SurTitre extends StatelessWidget {
  const SurTitre(this.texte, {super.key, this.couleur});
  final String texte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Text(
        texte.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ts(12.5, FontWeight.w600, couleur ?? context.colors.text2, espace: 1.5, hauteur: 1.35),
      );
}

/// Titre de bloc (« Ton corps », « Calendrier »).
class TitreBloc extends StatelessWidget {
  const TitreBloc(this.texte, {super.key, this.lien, this.onLien});
  final String texte;
  final String? lien;
  final VoidCallback? onLien;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Cotes.marge, 0, Cotes.marge, 14),
      child: Row(
        children: [
          Expanded(child: Text(texte, style: ts(19, FontWeight.w800, c.text, hauteur: 1.35))),
          if (lien != null)
            InkWell(
              onTap: onLien,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(lien!, style: ts(15, FontWeight.w600, c.text)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chevron au trait de la maquette.
class Chevron extends StatelessWidget {
  const Chevron({super.key, this.taille = 17.5, this.couleur, this.gauche = false, this.epaisseur = 2});
  final double taille;
  final Color? couleur;
  final bool gauche;
  final double epaisseur;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: taille,
        child: CustomPaint(painter: _ChevronPainter(couleur ?? context.colors.text3, gauche, epaisseur)),
      );
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.couleur, this.gauche, this.epaisseur);
  final Color couleur;
  final bool gauche;
  final double epaisseur;

  @override
  void paint(Canvas canvas, Size size) {
    // Tracé de la maquette sur une grille de 14 : M5 2.5 L9.5 7 L5 11.5.
    final k = size.width / 14;
    final p = Path();
    if (gauche) {
      p
        ..moveTo(9 * k, 2.5 * k)
        ..lineTo(4.5 * k, 7 * k)
        ..lineTo(9 * k, 11.5 * k);
    } else {
      p
        ..moveTo(5 * k, 2.5 * k)
        ..lineTo(9.5 * k, 7 * k)
        ..lineTo(5 * k, 11.5 * k);
    }
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = couleur,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.couleur != couleur || old.gauche != gauche || old.epaisseur != epaisseur;
}

/// Bouton rond de retour (55 de large, fond gris, ou sans fond).
class BoutonRetour extends StatelessWidget {
  const BoutonRetour({super.key, this.fond = true, this.onTap});
  final bool fond;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Retour',
      excludeSemantics: true,
      child: Material(
        color: fond ? c.surface2 : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          child: SizedBox.square(
            dimension: 55,
            child: Center(child: Chevron(taille: 22.5, couleur: c.text, gauche: true)),
          ),
        ),
      ),
    );
  }
}

/// En-tête d'une sous-page : retour rond, titre, sous-titre, élément à droite.
class EnTetePage extends StatelessWidget {
  const EnTetePage({super.key, required this.titre, this.sousTitre, this.droite, this.retourNu = false, this.tailleTitre = 20});

  final String titre;
  final String? sousTitre;
  final Widget? droite;

  /// Retour sans rond gris, décalé vers le bord (écran « Tous les muscles »).
  final bool retourNu;
  final double tailleTitre;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(retourNu ? Cotes.marge - 12 : Cotes.marge, 12, Cotes.marge, 12),
      child: Row(
        children: [
          BoutonRetour(fond: !retourNu),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Le titre rétrécit plutôt que d'être coupé (« Octobre 2... »)
                // quand l'étiquette de droite est large ou l'écran étroit.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(titre, maxLines: 1, softWrap: false, style: ts(tailleTitre, FontWeight.w700, c.text, hauteur: 1.3)),
                ),
                if (sousTitre != null)
                  Text(sousTitre!, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14.5, FontWeight.w400, c.text2, hauteur: 1.35)),
              ],
            ),
          ),
          if (droite != null) ...[const SizedBox(width: 10), droite!],
        ],
      ),
    );
  }
}

/// Étiquette en pilule aux couleurs libres (dates, écart du mois).
class Etiquette extends StatelessWidget {
  const Etiquette(this.texte, {super.key, required this.fond, required this.encre, this.gras = FontWeight.w600});
  final String texte;
  final Color fond;
  final Color encre;
  final FontWeight gras;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(color: fond, borderRadius: AppTokens.radiusPill),
        child: Text(texte, maxLines: 1, softWrap: false, style: ts(12.5, gras, encre, hauteur: 1.35)),
      );
}

/// Tuile « chiffre et légende » des grilles de deux (kpi de la maquette).
class TuileChiffre extends StatelessWidget {
  const TuileChiffre({super.key, required this.valeur, required this.legende, this.ecart, this.baisse = false});
  final String valeur;
  final String legende;

  /// Écart à droite de la légende (« +2 »), vert ; rouge si [baisse].
  final String? ecart;
  final bool baisse;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Cotes.rTuile)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valeur, maxLines: 1, style: ts(25, FontWeight.w800, c.text, hauteur: 1.35, espace: -0.25)),
          ),
          Text.rich(
            TextSpan(
              text: legende,
              children: [
                if (ecart != null) TextSpan(text: '  $ecart', style: ts(13, FontWeight.w700, baisse ? c.error : c.success)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ts(12.75, FontWeight.w400, c.text2, hauteur: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Petite tuile des rangées de trois (séances, temps, records).
class TuileTrois extends StatelessWidget {
  const TuileTrois({super.key, required this.valeur, required this.legende, this.onTap, this.semantique, this.couleur});

  /// Couleur du chiffre (le blanc par défaut).
  final Color? couleur;
  final String valeur;
  final String legende;

  /// La tuile est un bouton quand [onTap] est donné ; [semantique] dit où
  /// elle mène (« 3 séances, ouvrir le calendrier »).
  final VoidCallback? onTap;
  final String? semantique;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Carte(
      rayon: Cotes.rPetite,
      padding: const EdgeInsets.fromLTRB(12.5, 10, 12.5, 10),
      onTap: onTap,
      semantique: semantique,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valeur, maxLines: 1, style: ts(19, FontWeight.w700, couleur ?? c.text, hauteur: 1.35)),
          ),
          Text(legende, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, FontWeight.w400, c.text2, hauteur: 1.35)),
        ],
      ),
    );
  }
}

/// Une barre d'un [BarresVolume].
typedef Barre = ({String label, double valeur, Color? couleur});

/// Barres verticales arrondies de la maquette, étiquette dessous.
class BarresVolume extends StatelessWidget {
  const BarresVolume({super.key, required this.barres, this.hauteur = 107.5, this.ecart = 9});

  final List<Barre> barres;
  final double hauteur;
  final double ecart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = barres.fold(0.0, (a, b) => math.max(a, b.valeur));
    // L'étiquette (17) et son écart (6) laissent le reste aux barres ; la
    // plus haute en prend les trois quarts, comme dans la maquette.
    final place = (hauteur - 23) * 0.94;
    return SizedBox(
      height: hauteur,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, b) in barres.indexed) ...[
            if (i > 0) SizedBox(width: ecart),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: max <= 0 ? 4 : math.max(4, place * b.valeur / max),
                    decoration: BoxDecoration(color: b.couleur ?? c.track, borderRadius: BorderRadius.circular(7.5)),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 17,
                    child: Text(b.label, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: ts(12.5, FontWeight.w400, c.text2, hauteur: 1.35)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Barre fine horizontale (6 de haut), remplie en accent.
class BarreFine extends StatelessWidget {
  const BarreFine({super.key, required this.valeur, this.couleur});

  /// De 0 à 1.
  final double valeur;

  /// Couleur du remplissage (l'accent des muscles par défaut).
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: c.surface2,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: valeur.clamp(0.0, 1.0),
          child: Container(decoration: BoxDecoration(color: couleur ?? c.accent, borderRadius: BorderRadius.circular(3))),
        ),
      ),
    );
  }
}

/// Anneau de récupération : piste grise, arc vert aux bouts ronds, le
/// pourcentage au centre.
class AnneauRecup extends StatelessWidget {
  const AnneauRecup({super.key, required this.pourcentage, this.taille = 95, this.couleur});

  /// Couleur de l'arc (vert par défaut).
  final Color? couleur;
  final int pourcentage;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Récupération globale $pourcentage %',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: taille,
        child: CustomPaint(
          painter: _AnneauPainter(pourcentage / 100, c.surface2, couleur ?? c.success),
          child: Center(child: Text('$pourcentage %', style: ts(taille * 0.225, FontWeight.w800, c.text, hauteur: 1))),
        ),
      ),
    );
  }
}

class _AnneauPainter extends CustomPainter {
  _AnneauPainter(this.part, this.piste, this.couleur);
  final double part;
  final Color piste;
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    // Dans la maquette : boîte de 76, rayon 32, trait de 7.
    final k = size.width / 76;
    final centre = size.center(Offset.zero);
    final trait = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centre, 32 * k, trait..color = piste);
    if (part <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: 32 * k),
      -math.pi / 2,
      2 * math.pi * part.clamp(0.0, 1.0),
      false,
      trait..color = couleur,
    );
  }

  @override
  bool shouldRepaint(_AnneauPainter old) => old.part != part || old.piste != piste || old.couleur != couleur;
}

/// Le personnage face et dos, muscles allumés en accent.
class CorpsFaceDos extends StatelessWidget {
  const CorpsFaceDos({super.key, required this.intensites, required this.hauteur, this.ecart = 7.5});
  final Map<Muscle, double> intensites;
  final double hauteur;
  final double ecart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        BodyMap(view: BodyView.front, intensities: intensites, highlight: c.accent, height: hauteur),
        SizedBox(width: ecart),
        BodyMap(view: BodyView.back, intensities: intensites, highlight: c.accent, height: hauteur),
      ],
    );
  }
}

/// Vignette d'exercice : la pose du personnage sur une tuile grise.
class VignetteExercice extends StatelessWidget {
  const VignetteExercice({super.key, required this.exercice, this.taille = 65, this.fond, this.rayon = 14});
  final Exercise? exercice;
  final double taille;
  final Color? fond;
  final double rayon;

  /// Image embarquée d'un exercice (la pose haute de préférence).
  static String? assetDe(Exercise? e) {
    final l = e?.media.imagesLocales ?? const <String>[];
    if (l.isEmpty) return null;
    return l.last;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final asset = assetDe(exercice);
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: Container(
        width: taille,
        height: taille,
        color: fond ?? c.surface2,
        // Sans image (exercice personnel) : l'haltère au trait.
        child: asset == null
            ? Center(child: IconeHaltere(size: taille * 0.46, color: c.text2))
            : Image.asset(asset, fit: BoxFit.contain, errorBuilder: (context, error, stack) => const SizedBox.shrink()),
      ),
    );
  }
}


// ------------------------------------------------------------ écriture

/// Écriture commune des charges et des écarts dans le module.
abstract final class Ecrit {
  /// « 70 kg × 6 » ; « 6 rép. » sans charge.
  static String serie(double? kg, int? reps, [UnitePoids u = UnitePoids.kg]) =>
      (kg ?? 0) > 0 ? '${Fmt.poids(kg, u)} × ${reps ?? 0}' : '${reps ?? 0} rép.';

  /// « +9,8 kg », « -2 kg ».
  static String ecartPoids(double kg, [UnitePoids u = UnitePoids.kg]) => '${kg > 0 ? '+' : '-'}${Fmt.poids(kg.abs(), u)}';

  /// Vert pour une hausse, rouge pour une baisse, rien pour un écart nul.
  static Color? couleur(BuildContext context, num ecart) =>
      ecart > 0 ? context.colors.success : (ecart < 0 ? context.colors.error : null);
}

// ------------------------------------------------------------ icônes

/// Icônes au trait du module (grille de 22, bouts ronds), dans l'esprit de
/// celles de la maquette.
enum Trait {
  tri('M4 6.5h14M6.5 11h9M9 15.5h4'),
  loupe('M14.2 14.2L18.5 18.5', (9.8, 9.8, 5.8)),
  medaille('M7.2 3.5L11 9.6l3.8-6.1M9.6 3.5L11 5.8l1.4-2.3', (11, 14.2, 4.6)),
  rejouer('M5.2 11a5.8 5.8 0 1 0 1.9-4.3M4.6 3.6v3.6h3.6'),
  crayon('M4 18l.9-3.9L15.1 3.9l3 3L7.9 17.1zM13 6l3 3'),
  reglages('M3.5 7h8M15.5 7h3M3.5 15h3M10.5 15h8M13.5 5v4M8.5 13v4'),
  croix('M6 6l10 10M16 6L6 16'),
  info('M11 10.2v5M11 6.9v.2', (11, 11, 7.5)),
  calendrier('M4.5 6.5h13v11h-13zM4.5 10h13M8 4v3.5M14 4v3.5');

  const Trait(this.trace, [this.cercle]);
  final String trace;

  /// Cercle ajouté au tracé : centre x, centre y, rayon.
  final (double, double, double)? cercle;
}

/// Dessine un [Trait], blanc par défaut.
class IconeTrait extends StatelessWidget {
  const IconeTrait(this.trait, {super.key, this.taille = 22, this.couleur, this.epaisseur = 1.8});
  final Trait trait;
  final double taille;
  final Color? couleur;
  final double epaisseur;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: taille,
          child: CustomPaint(painter: _TraitPainter(trait, couleur ?? context.colors.text, epaisseur)),
        ),
      );
}

class _TraitPainter extends CustomPainter {
  _TraitPainter(this.trait, this.couleur, this.epaisseur);
  final Trait trait;
  final Color couleur;
  final double epaisseur;

  static final _chemins = <Trait, Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22);
    final p = _chemins.putIfAbsent(trait, () {
      final p = parseSvgPathData(trait.trace);
      final c = trait.cercle;
      if (c != null) p.addOval(Rect.fromCircle(center: Offset(c.$1, c.$2), radius: c.$3));
      return p;
    });
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = couleur,
    );
  }

  @override
  bool shouldRepaint(_TraitPainter old) => old.trait != trait || old.couleur != couleur || old.epaisseur != epaisseur;
}

/// Icône blanche au trait dans un carré gris arrondi (ligne de liste).
class CarreIcone extends StatelessWidget {
  const CarreIcone(this.trait, {super.key, this.taille = 44, this.fond});
  final Trait trait;
  final double taille;
  final Color? fond;

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fond ?? context.colors.surface2, borderRadius: BorderRadius.circular(taille * 0.3)),
        child: IconeTrait(trait, taille: taille * 0.5),
      );
}

/// Bouton rond gris d'en-tête (trier, régler), de la taille du retour.
class BoutonRond extends StatelessWidget {
  const BoutonRond({super.key, required this.trait, required this.label, required this.onTap, this.taille = 55});
  final Trait trait;

  /// Ce que fait le bouton, pour les lecteurs d'écran et l'infobulle.
  final String label;
  final VoidCallback? onTap;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: c.surface2,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(dimension: taille, child: Center(child: IconeTrait(trait, taille: taille * 0.42))),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ saisie et choix

/// Champ de recherche : pilule grise, loupe au trait, croix pour effacer.
class ChampRecherche extends StatelessWidget {
  const ChampRecherche({super.key, required this.controller, required this.indice, required this.onChanged});
  final TextEditingController controller;
  final String indice;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 17),
      decoration: BoxDecoration(color: c.surface2, borderRadius: AppTokens.radiusPill),
      child: Row(
        children: [
          IconeTrait(Trait.loupe, taille: 22, couleur: c.text2),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: c.text,
              style: ts(16, FontWeight.w500, c.text),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: indice,
                hintStyle: ts(16, FontWeight.w400, c.text2),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            Semantics(
              button: true,
              label: 'Effacer la recherche',
              excludeSemantics: true,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: SizedBox.square(dimension: 52, child: Center(child: IconeTrait(Trait.croix, taille: 18, couleur: c.text2))),
              ),
            )
          else
            const SizedBox(width: 17),
        ],
      ),
    );
  }
}

/// Puce de filtre : blanche quand elle est choisie, grise sinon.
class PuceChoix extends StatelessWidget {
  const PuceChoix({super.key, required this.label, required this.choisi, required this.onTap});
  final String label;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: choisi,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // La zone d'appui dépasse la puce de 5 en haut et en bas (48 en tout).
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: AnimatedContainer(
            duration: AppTokens.fast,
            height: 38,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: choisi ? c.bouton : c.surface2, borderRadius: AppTokens.radiusPill),
            child: Text(label, maxLines: 1, softWrap: false, style: ts(14.5, FontWeight.w600, choisi ? c.onBouton : c.text2, hauteur: 1.2)),
          ),
        ),
      ),
    );
  }
}

/// Rangée de puces qui défile, alignée sur la marge de la page.
class RangeePuces extends StatelessWidget {
  const RangeePuces({super.key, required this.puces});
  final List<Widget> puces;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
        child: Row(
          children: [
            for (final (i, p) in puces.indexed) ...[if (i > 0) const SizedBox(width: 7.5), p],
          ],
        ),
      );
}

/// Choix court dans un panneau du bas (tri, périodes).
Future<T?> choisirDansPanneau<T>(BuildContext context, {required String titre, required T choisi, required List<(T, String)> options}) =>
    showPanneauBas<T>(
      context,
      titre: titre,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in options) ChoixPanneau(label: label, selected: v == choisi, onTap: () => Navigator.pop(context, v)),
        ],
      ),
    );

// ------------------------------------------------------------ blocs

/// État vide d'une page ou d'une carte : un titre, une phrase, un bouton
/// blanc facultatif.
class EtatVide extends StatelessWidget {
  const EtatVide({super.key, required this.titre, this.message, this.action, this.onAction, this.dansCarte = false});
  final String titre;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  /// Aligné à gauche, sans marge, pour tenir dans une [Carte].
  final bool dansCarte;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final centre = !dansCarte;
    return Padding(
      padding: dansCarte ? EdgeInsets.zero : const EdgeInsets.fromLTRB(Cotes.marge + 8, 60, Cotes.marge + 8, 24),
      child: Column(
        crossAxisAlignment: centre ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titre, textAlign: centre ? TextAlign.center : TextAlign.start, style: ts(centre ? 19 : 17, FontWeight.w700, c.text, hauteur: 1.35)),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, textAlign: centre ? TextAlign.center : TextAlign.start, style: ts(14.5, FontWeight.w400, c.text2, hauteur: 1.4)),
          ],
          if (action != null && onAction != null) ...[
            SizedBox(height: centre ? 20 : 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: BoutonPrincipal(label: action!, petit: true, onPressed: onAction),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grand chiffre d'une carte : étiquette, valeur et unité séparées d'une
/// espace (« 26,9 kg »), légende.
class GrandChiffre extends StatelessWidget {
  const GrandChiffre({super.key, required this.etiquette, required this.valeur, this.unite, this.legende, this.taille = 35});
  final String etiquette;
  final String valeur;
  final String? unite;
  final String? legende;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SurTitre(etiquette),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: valeur,
              children: [if (unite != null) TextSpan(text: ' $unite', style: ts(taille * 0.54, FontWeight.w800, c.text))],
            ),
            maxLines: 1,
            style: ts(taille, FontWeight.w800, c.text, hauteur: 1.05, espace: -0.7),
          ),
        ),
        if (legende != null) ...[
          const SizedBox(height: 6),
          Text(legende!, style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
        ],
      ],
    );
  }
}

/// Titre d'une carte et précision à droite (« Évolution », « +1,3 kg »).
class TitreCarte extends StatelessWidget {
  const TitreCarte(this.titre, {super.key, this.droite, this.couleurDroite});
  final String titre;
  final String? droite;
  final Color? couleurDroite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(child: SurTitre(titre)),
        if (droite != null) ...[
          const SizedBox(width: 10),
          Text(droite!, maxLines: 1, style: ts(13, couleurDroite == null ? FontWeight.w400 : FontWeight.w700, couleurDroite ?? c.text2, hauteur: 1.35)),
        ],
      ],
    );
  }
}

/// Ligne d'une liste dans une [Carte] : élément à gauche, titre, sous-titre,
/// valeur à droite, chevron si elle ouvre quelque chose.
class LigneListe extends StatelessWidget {
  const LigneListe({super.key, this.gauche, required this.titre, this.sousTitre, this.valeur, this.sousValeur, this.couleurValeur, this.onTap, this.filet = true});
  final Widget? gauche;
  final String titre;
  final String? sousTitre;
  final String? valeur;
  final String? sousValeur;
  final Color? couleurValeur;
  final VoidCallback? onTap;

  /// Filet au-dessus (à retirer sur la première ligne).
  final bool filet;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ligne = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17.5, vertical: 11),
      child: Row(
        children: [
          if (gauche != null) ...[gauche!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(16, FontWeight.w700, c.text, hauteur: 1.3)),
                if (sousTitre != null) Text(sousTitre!, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
              ],
            ),
          ),
          if (valeur != null || sousValeur != null) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (valeur != null) Text(valeur!, maxLines: 1, style: ts(16, FontWeight.w700, couleurValeur ?? c.text, hauteur: 1.3)),
                if (sousValeur != null) Text(sousValeur!, maxLines: 1, style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
              ],
            ),
          ],
          if (onTap != null) ...[const SizedBox(width: 6), const Chevron(taille: 16)],
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filet) Padding(padding: const EdgeInsets.symmetric(horizontal: 17.5), child: Container(height: 1, color: c.line)),
        if (onTap == null) ligne else Semantics(button: true, child: InkWell(onTap: onTap, child: ligne)),
      ],
    );
  }
}

/// Carte qui empile des [LigneListe], sous un titre facultatif.
class CarteListe extends StatelessWidget {
  const CarteListe({super.key, this.titre, this.droite, required this.lignes});
  final String? titre;
  final String? droite;
  final List<Widget> lignes;

  @override
  Widget build(BuildContext context) => Carte(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (titre != null) Padding(padding: const EdgeInsets.fromLTRB(17.5, 13, 17.5, 7), child: TitreCarte(titre!, droite: droite)),
            ...lignes,
          ],
        ),
      );
}

/// Sélecteur à flèches (semaine précédente, suivante) : deux ronds gris et
/// le libellé au centre, touchable pour revenir à aujourd'hui.
class SelecteurPas extends StatelessWidget {
  const SelecteurPas({super.key, required this.label, this.onAvant, this.onApres, this.onLabel, required this.avant, required this.apres});
  final String label;
  final VoidCallback? onAvant;
  final VoidCallback? onApres;
  final VoidCallback? onLabel;
  final String avant;
  final String apres;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget fleche(bool gauche, VoidCallback? onTap, String nom) => Semantics(
          button: true,
          enabled: onTap != null,
          label: nom,
          excludeSemantics: true,
          child: Material(
            color: c.surface2,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(dimension: 48, child: Center(child: Chevron(taille: 19, gauche: gauche, couleur: onTap == null ? c.text3 : c.text))),
            ),
          ),
        );
    return Row(
      children: [
        fleche(true, onAvant, avant),
        Expanded(
          child: InkWell(
            onTap: onLabel,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, style: ts(17, FontWeight.w700, c.text, hauteur: 1.3)),
              ),
            ),
          ),
        ),
        fleche(false, onApres, apres),
      ],
    );
  }
}

/// Bas d'une liste : la marge de la page plus la zone système (barre de
/// gestes), quand la page est ouverte hors de la barre d'onglets.
double basDePage(BuildContext context) => 24 + MediaQuery.paddingOf(context).bottom;

/// Les flèches qui remontent dans le temps, la période au milieu.
class NavigationPeriode extends StatelessWidget {
  const NavigationPeriode({super.key, required this.titre, required this.detail, required this.avant, required this.apres});
  final String titre;
  final String detail;
  final VoidCallback? avant;
  final VoidCallback? apres;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget fleche(bool gauche, VoidCallback? onTap) => Semantics(
          button: true,
          enabled: onTap != null,
          label: gauche ? 'Période précédente' : 'Période suivante',
          excludeSemantics: true,
          child: InkResponse(
            onTap: onTap,
            radius: 26,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                  child: Center(child: Chevron(taille: 17.5, gauche: gauche, couleur: onTap == null ? c.text.withValues(alpha: 0.25) : c.text)),
                ),
              ),
            ),
          ),
        );
    return Row(
      children: [
        fleche(true, avant),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(titre, maxLines: 1, style: ts(17, FontWeight.w700, c.text, hauteur: 1.35))),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, FontWeight.w400, c.text2, hauteur: 1.35)),
            ],
          ),
        ),
        fleche(false, apres),
      ],
    );
  }
}

/// Séparateur de la page : un titre centré, un trait qui s'efface de chaque
/// côté. Marque le passage de la période choisie à « tout depuis le début ».
class Separateur extends StatelessWidget {
  const Separateur(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget trait(bool gauche) => Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: gauche ? Alignment.centerLeft : Alignment.centerRight,
                end: gauche ? Alignment.centerRight : Alignment.centerLeft,
                colors: [c.text.withValues(alpha: 0), c.text.withValues(alpha: 0.45)],
              ),
            ),
          ),
        );
    return Semantics(
      header: true,
      child: Row(
        children: [
          trait(true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(texte.toUpperCase(), maxLines: 1, style: ts(13.5, FontWeight.w700, c.text, espace: 2.2, hauteur: 1.35)),
          ),
          trait(false),
        ],
      ),
    );
  }
}
