import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';

/// Cotes de la maquette (dessinée en 320 de large) portées à l'échelle du
/// téléphone : tout le module passe par [k] pour rester cohérent.
double k(double cssPx) => cssPx * 1.25;

/// Marge latérale des écrans de séance (`.pad` de la maquette).
final double margeSeance = k(18);

/// Icônes au trait de la maquette propres à la séance (grille de 22 ou de 18).
enum IconeSeance {
  chevronBas(18, 'M3.5 6.5L9 12l5.5-5.5'),
  retour(18, 'M11 3.5L5.5 9l5.5 5.5'),
  croix(18, 'M4 4l10 10M14 4L4 14'),
  plus(18, 'M9 3.5v11M3.5 9h11'),
  minuteur(22, 'M11 8.5V12l2.3 1.5M9 2.8h4', cercle: (11, 12, 6.5)),
  minuteurRepos(22, 'M11 8.5V12M9 2.8h4M16.5 6l1 1', cercle: (11, 12, 6.5)),
  partager(22, 'M12.5 4.5L18.5 10l-6 5.5v-3.3c-4 0-6.8 1-8.5 4 0-4.8 2.5-8.3 8.5-8.5z'),
  pause(22, 'M9 8v6M13 8v6', cercle: (11, 11, 7.5)),
  photo(22, 'M8 5.5l1.2-2h3.6l1.2 2', cercle: (11, 11.8, 3.2), rect: (3, 5.5, 16, 12.5, 2.5)),
  crayon(22, 'M4 18l1-4L15 4l3 3L8 17zM13 6l3 3'),
  // La roue dentée, la même que sur le profil.
  reglages(
    22,
    'M9.34 4.82L9.73 2.49L12.27 2.49L12.66 4.82L14.20 5.46L16.12 4.09L17.91 5.88L16.54 7.80L17.18 9.34L19.51 9.73L19.51 12.27L17.18 12.66L16.54 14.20L17.91 16.12L16.12 17.91L14.20 16.54L12.66 17.18L12.27 19.51L9.73 19.51L9.34 17.18L7.80 16.54L5.88 17.91L4.09 16.12L5.46 14.20L4.82 12.66L2.49 12.27L2.49 9.73L4.82 9.34L5.46 7.80L4.09 5.88L5.88 4.09L7.80 5.46z',
    cercle: (11, 11, 2.7),
  ),
  corbeille(22, 'M4.5 6.5h13M9 6.5V4.2h4v2.3M6.5 6.5l.8 11.3h7.4l.8-11.3'),
  calendrier(22, 'M3.5 9h15M7.5 2.8v3M14.5 2.8v3', rect: (3.5, 4.5, 15, 14, 2.5)),
  coupe(22, 'M7 3.5h8v5a4 4 0 0 1-8 0zM7 5H4.5v1.5A2.5 2.5 0 0 0 7 9M15 5h2.5v1.5A2.5 2.5 0 0 1 15 9M11 12.5v3.5M7.5 18.5h7'),
  coche(12, 'M2.5 6.5l2.5 2.5 4.5-5.5'),
  chevronDroit(14, 'M5 2.5L9.5 7 5 11.5'),
  lecture(14, 'M4.5 2.5v9L12 7z'),
  chevronGauche(14, 'M9 2.5L4.5 7 9 11.5'),
  poignee(22, 'M4.5 7.5h13M4.5 11h13M4.5 14.5h13'),
  refaire(22, 'M5 9a6.5 6.5 0 0 1 11.5-2.5M16.5 3.5v3h-3M17 13a6.5 6.5 0 0 1-12 0'),
  loupe(22, 'M14.5 14.5l4 4', cercle: (10, 10, 5.8)),
  alerte(22, 'M11 7v4.5M11 14.6v.2', cercle: (11, 11, 7.5)),
  moins(18, 'M3.5 9h11'),
  ressenti(22, 'M7.6 13c.8 1.3 2 2 3.4 2s2.6-.7 3.4-2M8.4 8.7v.5M13.6 8.7v.5', cercle: (11, 11, 7.5));

  const IconeSeance(this.grille, this.trace, {this.cercle, this.rect});

  final double grille;
  final String trace;
  final (double, double, double)? cercle;
  final (double, double, double, double, double)? rect;
}

final _chemins = <IconeSeance, Path>{};

Path _chemin(IconeSeance i) => _chemins.putIfAbsent(i, () {
      final p = parseSvgPathData(i.trace);
      final c = i.cercle;
      if (c != null) p.addOval(Rect.fromCircle(center: Offset(c.$1, c.$2), radius: c.$3));
      final r = i.rect;
      if (r != null) p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.$1, r.$2, r.$3, r.$4), Radius.circular(r.$5)));
      return p;
    });

/// Dessine une [IconeSeance] : trait rond, couleur du texte par défaut.
class Trait extends StatelessWidget {
  const Trait(this.icone, {super.key, this.size = 22, this.color, this.epaisseur = 1.7, this.plein = false});

  final IconeSeance icone;
  final double size;
  final Color? color;

  /// Épaisseur du trait dans la grille de l'icône.
  final double epaisseur;

  /// Forme remplie (flèche de partage, triangle de lecture).
  final bool plein;

  @override
  Widget build(BuildContext context) {
    final couleur = color ?? IconTheme.of(context).color ?? context.colors.text;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _TraitPainter(icone, couleur, epaisseur, plein)),
    );
  }
}

class _TraitPainter extends CustomPainter {
  _TraitPainter(this.icone, this.color, this.epaisseur, this.plein);

  final IconeSeance icone;
  final Color color;
  final double epaisseur;
  final bool plein;

  @override
  void paint(Canvas canvas, Size size) {
    final e = size.width / icone.grille;
    canvas.scale(e);
    final p = Paint()
      ..color = color
      ..style = plein ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = epaisseur
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_chemin(icone), p);
  }

  @override
  bool shouldRepaint(_TraitPainter old) => old.icone != icone || old.color != color || old.epaisseur != epaisseur || old.plein != plein;
}

/// Trois points verticaux (« Plus d'actions »).
class TroisPoints extends StatelessWidget {
  const TroisPoints({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _PointsPainter(color ?? context.colors.text)),
      );
}

class _PointsPainter extends CustomPainter {
  _PointsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final e = size.width / 18;
    final p = Paint()..color = color;
    for (final y in [3.8, 9.0, 14.2]) {
      canvas.drawCircle(Offset(9 * e, y * e), 1.5 * e, p);
    }
  }

  @override
  bool shouldRepaint(_PointsPainter old) => old.color != color;
}

/// Bouton rond de 44 de la maquette (`.bk`) : gris, ou nu avec [nu].
class BoutonRond extends StatelessWidget {
  const BoutonRond({super.key, required this.child, required this.onTap, required this.label, this.nu = false});

  final Widget child;
  final VoidCallback? onTap;

  /// Libellé d'accessibilité.
  final String label;
  final bool nu;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = k(44);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: nu ? Colors.transparent : c.surface2,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(dimension: t, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// En-tête des sous-écrans de séance (`.pad.hd`) : retour rond, titre,
/// sous-titre gris, élément à droite.
class EnTeteSeance extends StatelessWidget {
  const EnTeteSeance({super.key, required this.titre, this.sousTitre, this.onRetour, this.fin});

  final String titre;
  final String? sousTitre;
  final VoidCallback? onRetour;
  final Widget? fin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margeSeance, vertical: k(10)),
      child: Row(
        children: [
          BoutonRond(
            label: 'Retour',
            onTap: onRetour ?? () => Navigator.of(context).maybePop(),
            child: Trait(IconeSeance.retour, size: k(18), epaisseur: 2),
          ),
          SizedBox(width: k(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(16), height: 1.35, fontWeight: FontWeight.w700, color: c.text),
                ),
                if (sousTitre != null)
                  Text(
                    sousTitre!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11.5), height: 1.35, color: c.text2, fontFeatures: AppTokens.tabular),
                  ),
              ],
            ),
          ),
          ?fin,
        ],
      ),
    );
  }
}

/// Les trois tuiles de chiffres (`.stats`) : durée, volume, séries.
class TroisChiffres extends StatelessWidget {
  const TroisChiffres({super.key, required this.valeurs});

  /// Trois couples (valeur, libellé) ; la valeur peut être un widget vivant.
  final List<(Widget, String)> valeurs;

  /// Style du chiffre, pour les valeurs fournies en widget.
  static TextStyle chiffre(BuildContext context) => TextStyle(
        fontFamily: AppTokens.fontUi,
        fontSize: k(15),
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: context.colors.text,
        fontFeatures: AppTokens.tabular,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Les trois tuiles gardent la même hauteur, même si un libellé passe sur deux lignes.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < valeurs.length; i++) ...[
            if (i > 0) SizedBox(width: k(6)),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: k(10), vertical: k(8)),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(12))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sur un écran étroit (Fold fermé), le chiffre se réduit plutôt que d'être coupé.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: DefaultTextStyle.merge(style: chiffre(context), maxLines: 1, softWrap: false, child: valeurs[i].$1),
                    ),
                    Text(valeurs[i].$2, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(10), height: 1.35, color: c.text2)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Encadré unique aux bords fins de la séance en cours : libellé au-dessus,
/// valeur dessous, en trois colonnes centrées.
class EncadreChiffres extends StatelessWidget {
  const EncadreChiffres({super.key, required this.valeurs});

  /// Trois couples (libellé, valeur) ; la valeur peut être un widget vivant.
  final List<(String, Widget)> valeurs;

  /// Style d'une valeur, pour celles fournies en widget.
  static TextStyle chiffre(BuildContext context, {Color? couleur}) => TextStyle(
        fontFamily: AppTokens.fontUi,
        fontSize: k(16),
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: couleur ?? context.colors.text,
        fontFeatures: AppTokens.tabular,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: k(8), vertical: k(11)),
      decoration: BoxDecoration(
        border: Border.all(color: c.frame),
        borderRadius: BorderRadius.circular(k(14)),
      ),
      child: Row(
        children: [
          for (final v in valeurs)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(v.$1, maxLines: 1, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), height: 1.3, color: c.text2)),
                  SizedBox(height: k(3)),
                  // Sur un écran étroit, le chiffre se réduit plutôt que d'être coupé.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DefaultTextStyle.merge(style: chiffre(context), maxLines: 1, softWrap: false, child: v.$2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Texte qui se redessine chaque seconde (chrono de la séance).
class TexteVivant extends StatefulWidget {
  const TexteVivant(this.texte, {super.key, this.style});

  final String Function() texte;
  final TextStyle? style;

  @override
  State<TexteVivant> createState() => _TexteVivantState();
}

class _TexteVivantState extends State<TexteVivant> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.texte(), style: widget.style, maxLines: 1);
}

/// Chrono d'une séance : toujours « 0:32:10 » (heures comprises).
String chronoSeance(Duration d) {
  final n = d.isNegative ? Duration.zero : d;
  String deux(int v) => v.toString().padLeft(2, '0');
  return '${n.inHours}:${deux(n.inMinutes % 60)}:${deux(n.inSeconds % 60)}';
}

/// Volume de la séance, toujours en kilos entiers (« 3 150 kg »).
String volumeSeance(double kg, UnitePoids u) => '${Fmt.n(Fmt.poidsAffiche(kg, u), decimals: 0)} ${u.label}';

/// Durée « 1 h 04 min » (fin de séance), « 45 min », « 30 s ».
String dureeLongue(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} min';
  if (d.inMinutes > 0) return '${d.inMinutes} min';
  return '${d.inSeconds} s';
}

/// Repos de la ligne bleue, en minutes:secondes : « 2:00 », « 2:30 », « 0:45 ».
String reposCourt(int sec) {
  final n = sec < 0 ? 0 : sec;
  return '${n ~/ 60}:${(n % 60).toString().padLeft(2, '0')}';
}

/// Nombre de séries qui comptent (validées, hors échauffement) : la seule
/// règle du module pour « séries », la même que le volume.
int seriesComptees(WorkoutSession s) => s.exercices.fold(0, (a, e) => a + e.series.where((x) => x.fait && x.type.counts).length);

/// Minuteur « 01:56 ».
String minSec(Duration d) {
  final n = d.isNegative ? Duration.zero : d;
  final total = (n.inMilliseconds / 1000).ceil();
  return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
}

/// Bouton en pilule aux cotes libres (la maquette en a de plusieurs tailles :
/// « Terminer » en haut de la séance, « Reprendre » de la barre réduite...).
/// Pour un bouton pleine largeur ordinaire, préférer `BoutonPrincipal`.
class BoutonSeance extends StatelessWidget {
  const BoutonSeance({
    super.key,
    required this.label,
    required this.onTap,
    required this.fond,
    required this.encre,
    this.hauteur,
    this.largeur,
    this.taille,
    this.rayon,
    this.marge,
    this.icone,
  });

  final String label;
  final VoidCallback? onTap;
  final Color fond;
  final Color encre;
  final double? hauteur;

  /// Largeur fixe ; sans elle, le bouton prend la place offerte (ou celle de
  /// son libellé avec [marge]).
  final double? largeur;
  final double? taille;

  /// Rayon des coins ; pilule par défaut.
  final double? rayon;

  /// Marge latérale d'un bouton à la largeur de son libellé.
  final double? marge;
  final Widget? icone;

  @override
  Widget build(BuildContext context) {
    final actif = onTap != null;
    final couleur = actif ? encre : encre.withValues(alpha: 0.4);
    final texte = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: taille ?? k(14), height: 1.2, fontWeight: FontWeight.w700, color: couleur),
    );
    return Semantics(
      button: true,
      enabled: actif,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: actif ? fond : fond.withValues(alpha: 0.5),
        shape: rayon == null ? const StadiumBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayon!)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: hauteur ?? k(46),
            width: largeur ?? (marge == null ? double.infinity : null),
            alignment: marge == null ? Alignment.center : null,
            padding: EdgeInsets.symmetric(horizontal: marge ?? k(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icone != null) ...[
                  IconTheme.merge(data: IconThemeData(color: couleur, size: k(18)), child: icone!),
                  SizedBox(width: k(8)),
                ],
                Flexible(child: texte),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Surtitre en petites capitales espacées (`.over`), gris ou à l'accent.
class Surtitre extends StatelessWidget {
  const Surtitre(this.texte, {super.key, this.accent = false});

  final String texte;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      texte.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppTokens.fontUi,
        fontSize: k(10),
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: k(1.2),
        color: accent ? c.accent : c.text2,
      ),
    );
  }
}
