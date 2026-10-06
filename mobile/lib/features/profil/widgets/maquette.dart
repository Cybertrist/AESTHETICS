import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../core/theme/theme.dart';

/// Cote de la maquette (dessinée sur 320 de large) ramenée au téléphone.
double e(double css) => css * 1.25;

/// Marge latérale des écrans du profil (18 dans la maquette).
final double marge = e(18);

/// Style de texte de la maquette : taille en cotes de la maquette.
TextStyle txt(double css, FontWeight poids, Color couleur, {double? interligne, double? espacement}) => TextStyle(
      fontFamily: AppTokens.fontUi,
      fontSize: e(css),
      fontWeight: poids,
      color: couleur,
      height: interligne ?? 1.35,
      letterSpacing: espacement == null ? null : espacement * e(css),
      fontFeatures: AppTokens.tabular,
    );

/// Tracé d'une icône au trait : chemin SVG, cercles et rectangles arrondis.
class Trace {
  const Trace(this.chemin, {this.cercles = const [], this.rects = const [], this.grille = 22});

  final String chemin;
  final List<(double, double, double)> cercles;
  final List<(double, double, double, double, double)> rects;

  /// Côté de la grille de dessin.
  final double grille;

  /// La roue dentée des réglages.
  static const reglages = Trace(
    'M9.34 4.82L9.73 2.49L12.27 2.49L12.66 4.82L14.20 5.46L16.12 4.09L17.91 5.88L16.54 7.80L17.18 9.34L19.51 9.73L19.51 12.27L17.18 12.66L16.54 14.20L17.91 16.12L16.12 17.91L14.20 16.54L12.66 17.18L12.27 19.51L9.73 19.51L9.34 17.18L7.80 16.54L5.88 17.91L4.09 16.12L5.46 14.20L4.82 12.66L2.49 12.27L2.49 9.73L4.82 9.34L5.46 7.80L4.09 5.88L5.88 4.09L7.80 5.46z',
    cercles: [(11, 11, 2.7)],
  );
  static const cible = Trace('', cercles: [(11, 11, 7.5), (11, 11, 3.5)]);
  static const regle = Trace('M3 14.5L14.5 3l4.5 4.5L7.5 19zM7 10.5l1.8 1.8M10 7.5l1.8 1.8M13 4.8l1.5 1.5');
  static const photo = Trace('M8 5.5l1.2-2h3.6l1.2 2', cercles: [(11, 11.8, 3.2)], rects: [(3, 5.5, 16, 12.5, 2.5)]);
  static const trophee = Trace('M7 3.5h8v5a4 4 0 0 1-8 0zM7 5H4.5v1.5A2.5 2.5 0 0 0 7 9M15 5h2.5v1.5A2.5 2.5 0 0 1 15 9M11 12.5v3.5M7.5 18.5h7');
  static const calendrier = Trace('M3.5 9h15M7.5 2.8v3M14.5 2.8v3', rects: [(3.5, 4.5, 15, 14, 2.5)]);
  static const retour = Trace('M11 3.5L5.5 9l5.5 5.5', grille: 18);
  static const plus = Trace('M9 3.5v11M3.5 9h11', grille: 18);
  static const chevron = Trace('M5 2.5L9.5 7 5 11.5', grille: 14);
  static const crayon = Trace('M4 18l1-4L15 4l3 3L8 17zM13 6l3 3');
  static const silhouette = Trace('M4.5 20c.6-4.6 3-6.8 6.5-6.8s5.9 2.2 6.5 6.8', cercles: [(11, 6.5, 3.2)]);
  static const unites = Trace('M7.5 8.5a5 5 0 0 1 7 0M11 8.5l1.5-2', rects: [(3.5, 3.5, 15, 15, 3.5)]);
  static const chrono = Trace('M11 8.5V12l2.3 1.5M9 2.8h4', cercles: [(11, 12, 6.5)]);
  static const palette = Trace('', cercles: [(11, 11, 7.5), (8, 9, 1), (12, 7.5, 1), (14.8, 11, 1)]);
  static const importer = Trace('M11 3.5v10M7 9.5l4 4 4-4M4 17.5h14');
  static const galerie = Trace('M3.5 15.5l4.5-4.5 3.5 3.5 2.5-2.5 4.5 4.5', cercles: [(8, 8.6, 1.4)], rects: [(3, 4, 16, 14, 2.5)]);
  static const exporter = Trace('M11 13.5v-10M7 7.5l4-4 4 4M4 17.5h14');
  static const info = Trace('M11 10v5M11 7.2v.2', cercles: [(11, 11, 7.5)]);
  static const cloche = Trace('M6 16v-6a5 5 0 0 1 10 0v6l1.5 2h-13zM9.5 19.8h3');
  static const texte = Trace('M5 6.5V5h12v1.5M11 5v12M8.5 17h5');
  static const donnees = Trace(
      'M4.5 6.5c0-1.7 2.9-3 6.5-3s6.5 1.3 6.5 3v9c0 1.7-2.9 3-6.5 3s-6.5-1.3-6.5-3zM4.5 6.5c0 1.7 2.9 3 6.5 3s6.5-1.3 6.5-3M4.5 11c0 1.7 2.9 3 6.5 3s6.5-1.3 6.5-3');
  static const etoile = Trace('M11 3.5l2 5.5 5.5 2-5.5 2-2 5.5-2-5.5-5.5-2 5.5-2z');
  static const coeur = Trace('M11 18s-6.5-3.8-6.5-8.5A3.5 3.5 0 0 1 11 7.7a3.5 3.5 0 0 1 6.5 1.8C17.5 14.2 11 18 11 18z');
  static const poubelle = Trace('M4.5 6.5h13M8.5 6.5v-2h5v2M6.5 6.5l.8 12h7.4l.8-12');
  static const haltere = Trace('M8.2 11h5.6', rects: [(1.8, 8.6, 3, 4.8, 1.3), (4.8, 6, 3.4, 10, 1.5), (13.8, 6, 3.4, 10, 1.5), (17.2, 8.6, 3, 4.8, 1.3)]);
  static const echange = Trace('M4 8h13M13.5 4.5L17 8l-3.5 3.5M18 14H5M8.5 10.5L5 14l3.5 3.5');
  static const lecture = Trace('M9.5 8l4.5 3-4.5 3z', cercles: [(11, 11, 7.5)]);
  static const son = Trace('M4 9h3l4-3.5v11L7 13H4zM14 8.5a3.5 3.5 0 0 1 0 5M16.2 6.2a6.8 6.8 0 0 1 0 9.6');
  static const vibration = Trace('M4 8v6M18 8v6', rects: [(7.5, 4, 7, 14, 2)]);
  static const ecran = Trace('M10 16.5h2', rects: [(6, 2.5, 10, 17, 2.5)]);
  static const jauge = Trace('M4 15a7 7 0 0 1 14 0M11 15l3.5-4.5');
  static const externe = Trace('M9 5H5v12h12v-4M12.5 4.5h5v5M17.5 4.5L10 12');
  static const code = Trace('M8 7l-4 4 4 4M14 7l4 4-4 4');
  static const document = Trace('M6 3.5h7l3.5 3.5v11.5H6zM13 3.5V7h3.5M8.5 11h5M8.5 14.5h5');
  static const horloge = Trace('M11 7v4.5l2.8 1.6', cercles: [(11, 11, 7.5)]);
  static const bouclier = Trace('M11 3l6.5 2.5v5c0 4-2.8 6.8-6.5 8.5-3.7-1.7-6.5-4.5-6.5-8.5v-5zM8 11l2.2 2.2L14.2 9');
  static const disque = Trace('', cercles: [(11, 11, 7.5), (11, 11, 1.6)]);
  static const barre = Trace('M2.5 11h17', rects: [(5, 6.5, 2.6, 9, 1.2), (14.4, 6.5, 2.6, 9, 1.2)]);
  static const alerte = Trace('M11 4l8 14H3zM11 9.5v4M11 15.8v.2');
  static const boite = Trace('M5 8.5V18h12V8.5M9 12h4', rects: [(3.5, 4, 15, 4.5, 1.2)]);
  static const cle = Trace('M9.7 12.3l7.8-7.8M14.5 7.5L17 10', cercles: [(7.5, 14.5, 3)]);
  static const restaurer = Trace('M4.5 11a6.5 6.5 0 1 0 2-4.7M4 4.5V8h3.5M11 8v3.5l2.3 1.4');
  static const coche = Trace('M5 11.5l4 4 8-9');
  static const goutte = Trace('M11 3.5c3 3.8 5 6.3 5 9a5 5 0 0 1-10 0c0-2.7 2-5.2 5-9z');
  static const moins = Trace('M3.5 9h11', grille: 18);
}

final _chemins = <Trace, Path>{};

Path _chemin(Trace t) => _chemins.putIfAbsent(t, () {
      final p = t.chemin.isEmpty ? Path() : parseSvgPathData(t.chemin);
      for (final (x, y, r) in t.cercles) {
        p.addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
      }
      for (final (x, y, w, h, r) in t.rects) {
        p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)));
      }
      return p;
    });

/// Icône au trait de la maquette.
class IconeTrait extends StatelessWidget {
  const IconeTrait(this.trace, {super.key, this.taille = 20, this.couleur, this.epaisseur = 1.7});

  final Trace trace;
  final double taille;
  final Color? couleur;

  /// Épaisseur dans la grille du tracé.
  final double epaisseur;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(taille),
        painter: _TracePainter(trace, couleur ?? IconTheme.of(context).color ?? context.colors.text, epaisseur),
      );
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.trace, this.couleur, this.epaisseur);
  final Trace trace;
  final Color couleur;
  final double epaisseur;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / trace.grille;
    canvas.scale(k);
    canvas.drawPath(
      _chemin(trace),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = couleur,
    );
  }

  @override
  bool shouldRepaint(_TracePainter old) => old.trace != trace || old.couleur != couleur || old.epaisseur != epaisseur;
}

/// Bouton rond de l'en-tête (retour, ajouter, réglages) : disque gris de 44,
/// ou nu avec [plein] à faux.
class BoutonRond extends StatelessWidget {
  const BoutonRond({super.key, required this.trace, required this.label, required this.onTap, this.plein = true, this.tailleIcone, this.fond, this.taille = 44});

  final Trace trace;
  final String label;
  final VoidCallback? onTap;
  final bool plein;
  final double? tailleIcone;

  /// Diamètre du disque, en cotes de la maquette.
  final double taille;

  /// Couleur du disque, à la place du gris (bouton posé sur une image ou un dégradé).
  final Color? fond;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: fond ?? (plein ? c.surface2 : c.surface2.withValues(alpha: 0)),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: e(taille),
              child: Center(child: IconeTrait(trace, taille: tailleIcone ?? e(18), couleur: c.text, epaisseur: trace.grille == 22 ? 1.7 : 2)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran du profil : en-tête de la maquette (retour, titre, précision,
/// action), contenu défilant, zone fixe en bas.
class PageMaquette extends StatelessWidget {
  const PageMaquette({
    super.key,
    required this.titre,
    required this.enfants,
    this.sousTitre,
    this.retourPlein = true,
    this.action,
    this.bas,
    this.onRetour,
  });

  final String titre;
  final String? sousTitre;

  /// Bouton de retour sur disque gris (pages principales) ou nu (pages de
  /// détail).
  final bool retourPlein;
  final Widget? action;
  final List<Widget> enfants;
  final Widget? bas;
  final VoidCallback? onRetour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(marge - (retourPlein ? 0 : e(10)), e(10), marge, e(10)),
                  child: Row(
                    children: [
                      BoutonRond(
                        trace: Trace.retour,
                        label: 'Retour',
                        plein: retourPlein,
                        onTap: onRetour ?? () => Navigator.of(context).maybePop(),
                      ),
                      SizedBox(width: e(8)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(retourPlein ? 16 : 17, FontWeight.w700, c.text)),
                            if (sousTitre != null) Text(sousTitre!, style: txt(11.5, FontWeight.w400, c.text2)),
                          ],
                        ),
                      ),
                      if (action != null) ...[SizedBox(width: e(8)), action!],
                    ],
                  ),
                ),
                Expanded(child: ListView(padding: EdgeInsets.zero, children: enfants)),
                if (bas != null) Padding(padding: EdgeInsets.fromLTRB(marge, e(10), marge, e(18)), child: bas),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloc d'un écran : les marges de la maquette (10 en haut et en bas, 18 sur
/// les côtés).
class Bloc extends StatelessWidget {
  const Bloc({super.key, required this.child, this.haut = 10, this.bas = 10});
  final Widget child;
  final double haut;
  final double bas;

  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(marge, e(haut), marge, e(bas)), child: child);
}

/// Petit titre en capitales espacées (« OBJECTIF », « SAISIES »).
class Surtitre extends StatelessWidget {
  const Surtitre(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label.toUpperCase(), style: txt(10, FontWeight.w600, context.colors.text2, espacement: 0.12));
}

/// Carte de la maquette : coins de 16, fond de carte.
class Carte extends StatelessWidget {
  const Carte({super.key, required this.child, this.padding, this.onTap, this.rayon = 16});
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = BorderRadius.circular(e(rayon));
    return Material(
      color: c.surface,
      borderRadius: r,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? EdgeInsets.all(e(12)), child: child),
      ),
    );
  }
}

/// Groupe de lignes : carte aux coins de 14, un filet entre deux lignes.
class Groupe extends StatelessWidget {
  const Groupe({super.key, required this.lignes});
  final List<Widget> lignes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(e(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lignes.length; i++) ...[
            if (i > 0) Container(height: 1, margin: EdgeInsets.symmetric(horizontal: e(12)), color: c.line),
            lignes[i],
          ],
        ],
      ),
    );
  }
}

/// Ligne d'un [Groupe] : tuile d'icône, libellé, précision, valeur, chevron.
class Ligne extends StatelessWidget {
  const Ligne({
    super.key,
    required this.titre,
    this.trace,
    this.icone,
    this.detail,
    this.valeur,
    this.fin,
    this.onTap,
    this.chevron = true,
    this.detailLignes = 1,
    this.couleurTitre,
    this.actif = true,
  });

  /// Lignes laissées à la précision avant de la couper.
  final int detailLignes;

  /// Couleur du libellé (rouge d'une action destructive).
  final Color? couleurTitre;

  /// Ligne grisée et inerte.
  final bool actif;

  final String titre;
  final Trace? trace;

  /// Icône libre à la place de [trace].
  final Widget? icone;

  /// Ligne grise sous le titre.
  final String? detail;

  /// Valeur grise à droite.
  final String? valeur;

  /// Élément libre à droite (pastilles de couleur...), à la place du chevron.
  final Widget? fin;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: actif ? onTap : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: e(46) - 1),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: e(12), vertical: e(4)),
          child: Row(
            children: [
              if (trace != null || icone != null) ...[
                Container(
                  width: e(30),
                  height: e(30),
                  decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(e(9))),
                  alignment: Alignment.center,
                  child: icone ?? IconeTrait(trace!, taille: e(16), couleur: c.text.withValues(alpha: 0.85)),
                ),
                SizedBox(width: e(12)),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(13, FontWeight.w600, (couleurTitre ?? c.text).withValues(alpha: actif ? 1 : 0.4), interligne: 1.25)),
                    if (detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(detail!, maxLines: detailLignes, overflow: TextOverflow.ellipsis, style: txt(12, FontWeight.w400, c.text2)),
                      ),
                  ],
                ),
              ),
              if (valeur != null) ...[
                SizedBox(width: e(8)),
                Text(valeur!, style: txt(12, FontWeight.w400, c.text2)),
              ],
              if (fin != null) ...[SizedBox(width: e(8)), fin!],
              if (fin == null && chevron && onTap != null) ...[
                SizedBox(width: e(12)),
                IconeTrait(Trace.chevron, taille: e(14), couleur: c.text3, epaisseur: 2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile de chiffre clé : valeur en gras, libellé gris dessous.
class TuileChiffre extends StatelessWidget {
  const TuileChiffre({super.key, required this.valeur, required this.label, this.grande = false});
  final String valeur;
  final String label;

  /// Variante de l'historique (chiffre de 20, coins de 14).
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: grande ? EdgeInsets.symmetric(horizontal: e(12), vertical: e(11)) : EdgeInsets.symmetric(horizontal: e(10), vertical: e(8)),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(e(grande ? 14 : 12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valeur, maxLines: 1, style: txt(grande ? 20 : 15, grande ? FontWeight.w800 : FontWeight.w700, c.text, espacement: grande ? -0.01 : null)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, maxLines: 1, style: txt(grande ? 10.5 : 10, FontWeight.w400, c.text2)),
          ),
        ],
      ),
    );
  }
}

/// Puce de période (« 3 mois », « 6 mois »...) : grise, blanche quand elle
/// est choisie.
class Puce extends StatelessWidget {
  const Puce({super.key, required this.label, required this.choisie, required this.onTap});
  final String label;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: choisie,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Zone de toucher plus haute que la puce.
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: e(6)),
          child: AnimatedContainer(
            duration: AppTokens.fast,
            padding: EdgeInsets.symmetric(horizontal: e(9), vertical: e(3)),
            decoration: BoxDecoration(color: choisie ? c.bouton : c.surface2, borderRadius: AppTokens.radiusPill),
            child: Text(label, style: txt(10, FontWeight.w600, choisie ? c.onBouton : c.text2)),
          ),
        ),
      ),
    );
  }
}

/// Courbe blanche sur aire grise. [points] : x et y entre 0 et 1, y vers le
/// haut.
class CourbeAire extends StatelessWidget {
  const CourbeAire({super.key, required this.points, required this.hauteur, this.pastilles = false, this.margeBas = 0.0, this.label});

  final List<Offset> points;
  final double hauteur;

  /// Un point blanc sur chaque valeur (le dernier est toujours marqué).
  final bool pastilles;

  /// Hauteur d'aire sous le point le plus bas.
  final double margeBas;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        image: true,
        child: CustomPaint(
          size: Size(double.infinity, hauteur),
          painter: _CourbePainter(points, context.colors.text, pastilles, margeBas),
        ),
      );
}

class _CourbePainter extends CustomPainter {
  _CourbePainter(this.points, this.couleur, this.pastilles, this.margeBas);
  final List<Offset> points;
  final Color couleur;
  final bool pastilles;
  final double margeBas;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final r = e(pastilles ? 4 : 3.5);
    // La courbe garde la place du dernier point, plus gros.
    final zone = Rect.fromLTRB(pastilles ? r : 0, r, size.width - r, size.height - margeBas - (pastilles ? 0 : e(6)));
    Offset pos(Offset p) => Offset(zone.left + p.dx * zone.width, zone.bottom - p.dy * zone.height);
    final pts = [for (final p in points) pos(p)];
    if (pts.length > 1) {
      final aire = Path()..moveTo(pts.first.dx, size.height);
      for (final p in pts) {
        aire.lineTo(p.dx, p.dy);
      }
      aire
        ..lineTo(pts.last.dx, size.height)
        ..close();
      canvas.drawPath(aire, Paint()..color = couleur.withValues(alpha: 0.07));
      final ligne = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        ligne.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        ligne,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = e(2)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = couleur,
      );
    }
    final plein = Paint()..color = couleur;
    if (pastilles) {
      for (final p in pts.take(pts.length - 1)) {
        canvas.drawCircle(p, e(2.5), plein);
      }
    }
    canvas.drawCircle(pts.last, r, plein);
  }

  @override
  bool shouldRepaint(_CourbePainter old) => old.points != points || old.couleur != couleur || old.pastilles != pastilles;
}

/// Message d'un écran sans donnée.
class Vide extends StatelessWidget {
  const Vide({super.key, required this.titre, required this.message});
  final String titre;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: marge, vertical: e(36)),
      child: Column(
        children: [
          Text(titre, textAlign: TextAlign.center, style: txt(14, FontWeight.w700, c.text)),
          SizedBox(height: e(4)),
          Text(message, textAlign: TextAlign.center, style: txt(12, FontWeight.w400, c.text2)),
        ],
      ),
    );
  }
}

/// Bouton en pilule pour deux actions côte à côte : le libellé se resserre
/// plutôt que d'être coupé. Blanc par défaut, gris avec [secondaire].
class BoutonDuo extends StatelessWidget {
  const BoutonDuo({super.key, required this.label, required this.onPressed, this.secondaire = false});
  final String label;
  final VoidCallback? onPressed;
  final bool secondaire;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final actif = onPressed != null;
    final fond = secondaire ? c.surface2 : c.bouton;
    final encre = secondaire ? c.text : c.onBouton;
    return Semantics(
      button: true,
      enabled: actif,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: actif ? fond : fond.withValues(alpha: 0.5),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: e(46),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: e(8)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: txt(14, FontWeight.w700, actif ? encre : encre.withValues(alpha: 0.4), interligne: 1.2)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Groupe de réglages : petit titre en capitales, carte de lignes, et une
/// note grise dessous.
class GroupeTitre extends StatelessWidget {
  const GroupeTitre({super.key, this.titre, required this.lignes, this.note, this.fin, this.premier = false});
  final String? titre;
  final List<Widget> lignes;
  final String? note;

  /// Action à droite du titre (« Ajouter »).
  final Widget? fin;

  /// Premier groupe de la page : collé à l'en-tête.
  final bool premier;

  @override
  Widget build(BuildContext context) => Bloc(
        haut: premier ? 2 : 4,
        bas: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titre != null || fin != null) ...[
              Row(
                children: [
                  Expanded(child: Surtitre(titre ?? '')),
                  ?fin,
                ],
              ),
              SizedBox(height: e(6)),
            ],
            Groupe(lignes: lignes),
            if (note != null) Padding(padding: EdgeInsets.fromLTRB(e(2), e(7), e(2), e(2)), child: Note(note!)),
          ],
        ),
      );
}

/// Texte d'explication gris, sous un groupe ou seul.
class Note extends StatelessWidget {
  const Note(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) => Text(texte, style: txt(11, FontWeight.w400, context.colors.text2, interligne: 1.4));
}

/// Ligne de réglage à interrupteur blanc.
class LigneBascule extends StatelessWidget {
  const LigneBascule({super.key, required this.titre, required this.valeur, required this.onChanged, this.trace, this.icone, this.detail, this.actif = true});
  final String titre;
  final Trace? trace;

  /// Image à la place du tracé (logo d'une appli).
  final Widget? icone;
  final String? detail;
  final bool valeur;
  final ValueChanged<bool> onChanged;
  final bool actif;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MergeSemantics(
      child: Ligne(
        trace: trace,
        icone: icone,
        titre: titre,
        detail: detail,
        detailLignes: 2,
        actif: actif,
        onTap: () => onChanged(!valeur),
        fin: Switch(
          value: valeur,
          onChanged: actif ? onChanged : null,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          activeThumbColor: c.onBouton,
          activeTrackColor: c.bouton,
          inactiveThumbColor: c.text2,
          inactiveTrackColor: c.surface2,
          trackOutlineColor: WidgetStatePropertyAll(c.surface2.withValues(alpha: 0)),
        ),
      ),
    );
  }
}

/// Ligne d'un choix exclusif : coche blanche sur le choix retenu.
class LigneChoix extends StatelessWidget {
  const LigneChoix({super.key, required this.titre, required this.choisie, required this.onTap, this.trace, this.icone, this.detail});
  final String titre;
  final Trace? trace;
  final Widget? icone;
  final String? detail;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: choisie,
        child: Ligne(
          trace: trace,
          icone: icone,
          titre: titre,
          detail: detail,
          onTap: onTap,
          fin: SizedBox.square(
            dimension: e(18),
            child: choisie ? IconeTrait(Trace.coche, taille: e(18), couleur: context.colors.text, epaisseur: 2) : null,
          ),
        ),
      );
}

/// Lien discret à droite d'un titre de groupe (« Ajouter ») : texte blanc.
class LienTitre extends StatelessWidget {
  const LienTitre({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTokens.radiusPill,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: e(6), vertical: e(6)),
            child: Text(label, style: txt(12, FontWeight.w600, context.colors.text)),
          ),
        ),
      );
}

