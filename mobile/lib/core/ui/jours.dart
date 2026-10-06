import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../models/workout.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import 'icones.dart';

/// Rend le type de la séance d'un jour, ou null s'il n'y en a pas.
typedef SeanceDuJour = TypeSeance? Function(DateTime jour);

/// Pastille d'un jour, avec les codes validés :
/// - aujourd'hui : disque blanc plein, chiffre noir (ou l'icône en noir si
///   la séance du jour est faite) ;
/// - jour avec séance : cercle gris au contour blanc, icône du type ;
/// - autre jour : la date seule (dans un cercle fin avec [cadre], comme dans
///   la rangée de la semaine ; sans cadre dans un calendrier).
class PastilleJour extends StatelessWidget {
  const PastilleJour({
    super.key,
    required this.jour,
    this.type,
    this.aujourdhui = false,
    this.cadre = true,
    this.estompe = false,
    this.taille = 38,
    this.onTap,
    this.plein = false,
  });

  /// Calendrier à série : un jour de séance est un disque blanc plein à
  /// l'icône sombre, aujourd'hui un simple cercle blanc autour de sa date.
  final bool plein;

  /// Numéro du jour dans le mois.
  final int jour;

  /// Type de la séance faite ce jour, null s'il n'y en a pas.
  final TypeSeance? type;
  final bool aujourdhui;

  /// Cercle fin autour d'un jour sans séance.
  final bool cadre;

  /// Jour hors du mois affiché ou séance seulement prévue : en retrait.
  final bool estompe;
  final double taille;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fait = type != null;
    final Color fond;
    final Color trait;
    final Color encre;
    if (plein && fait) {
      fond = c.bouton;
      trait = c.bouton;
      encre = c.onBouton;
    } else if (plein && aujourdhui) {
      fond = Colors.transparent;
      trait = c.text;
      encre = c.text;
    } else if (aujourdhui) {
      fond = c.bouton;
      trait = c.bouton;
      encre = c.onBouton;
    } else if (fait) {
      fond = c.surface2;
      trait = c.text;
      encre = c.text;
    } else {
      fond = Colors.transparent;
      trait = cadre ? c.surface2 : Colors.transparent;
      encre = estompe ? c.text3 : (cadre ? c.text2 : c.text);
    }
    Widget pastille = Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fond, border: Border.all(color: trait, width: plein && aujourdhui && !fait ? 2 : 1.5)),
      child: fait
          ? IconeTypeSeance(type!, size: taille * 0.53, color: encre, epaisseur: 2)
          : Text(
              '$jour',
              style: TextStyle(
                fontFamily: AppTokens.fontUi,
                fontSize: taille * 0.4,
                height: 1,
                fontWeight: aujourdhui ? FontWeight.w800 : FontWeight.w600,
                color: encre,
                fontFeatures: AppTokens.tabular,
              ),
            ),
    );
    if (estompe && fait && !aujourdhui) pastille = Opacity(opacity: 0.45, child: pastille);
    pastille = Semantics(
      label: '$jour${fait ? ', ${type!.label}' : ''}${aujourdhui ? ', aujourd\'hui' : ''}',
      button: onTap != null,
      excludeSemantics: true,
      child: pastille,
    );
    if (onTap == null) return pastille;
    return InkResponse(onTap: onTap, radius: taille * 0.7, child: pastille);
  }
}

/// Rangée « semaine » : l'initiale de chaque jour et sa [PastilleJour].
///
/// ```dart
/// SemaineJours(
///   jours: resume.jours,
///   seance: (j) => repo.typeDuJour(j),
///   onJour: (j) => ...,
/// )
/// ```
class SemaineJours extends StatelessWidget {
  const SemaineJours({
    super.key,
    required this.jours,
    required this.seance,
    this.aujourdhui,
    this.onJour,
    this.taille = 38,
  });

  /// Les sept jours affichés, dans l'ordre.
  final List<DateTime> jours;
  final SeanceDuJour seance;

  /// Par défaut la date du jour.
  final DateTime? aujourdhui;
  final ValueChanged<DateTime>? onJour;
  final double taille;

  /// Les sept jours de la semaine de [date].
  static List<DateTime> semaineDe(DateTime date, {int premierJour = DateTime.monday}) =>
      Dates.joursSemaine(date, premierJour: premierJour);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auj = aujourdhui ?? DateTime.now();
    return Row(
      children: [
        for (final j in jours)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Dates.initiale(j),
                  style: TextStyle(
                    fontFamily: AppTokens.fontUi,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Dates.memeJour(j, auj) ? c.text : c.text2,
                  ),
                ),
                const SizedBox(height: 7),
                PastilleJour(
                  jour: j.day,
                  type: seance(j),
                  aujourdhui: Dates.memeJour(j, auj),
                  taille: taille,
                  onTap: onJour == null ? null : () => onJour!(j),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Grille d'un mois, mêmes codes que la semaine (Progrès et Calendrier).
/// Les jours des mois voisins complètent la première et la dernière ligne,
/// en retrait. À poser dans une carte.
///
/// ```dart
/// GrilleMois(mois: DateTime(2026, 9), seance: (j) => types[j], onJour: ...)
/// ```
class GrilleMois extends StatelessWidget {
  const GrilleMois({
    super.key,
    required this.mois,
    required this.seance,
    this.aujourdhui,
    this.onJour,
    this.premierJour = DateTime.monday,
    this.enTetes = true,
    this.taille = 40,
    this.flamme,
  });

  /// N'importe quel jour du mois à afficher.
  final DateTime mois;
  final SeanceDuJour seance;
  final DateTime? aujourdhui;
  final ValueChanged<DateTime>? onJour;

  /// Premier jour de la semaine (`DateTime.monday` par défaut).
  final int premierJour;

  /// Ligne L M M J V S D au-dessus.
  final bool enTetes;

  /// Diamètre maximal d'une pastille (elle rétrécit si la place manque).
  final double taille;

  /// Colonne de droite, une case par semaine (son premier jour est passé),
  /// reliées par un trait : un nombre positif dessine la flamme avec la
  /// série de semaines (une seule semaine la porte, la dernière de la
  /// série), un nombre négatif un point orange (semaine tenue), zéro ou null
  /// un rond vide. Sans cette fonction, pas de colonne.
  final int? Function(DateTime debutSemaine)? flamme;

  /// Largeur de la colonne des flammes.
  static const largeurFlamme = 58.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auj = aujourdhui ?? DateTime.now();
    final premier = DateTime(mois.year, mois.month, 1);
    final debut = Dates.debutSemaine(premier, premierJour: premierJour);
    final dernier = DateTime(mois.year, mois.month + 1, 0);
    final nbJours = (dernier.difference(debut).inHours / 24).round() + 1;
    final lignes = (nbJours / 7).ceil();
    DateTime jourA(int i) => DateTime(debut.year, debut.month, debut.day + i);

    return LayoutBuilder(builder: (context, box) {
      final d = ((box.maxWidth - (flamme == null ? 0 : largeurFlamme)) / 7 - 4).clamp(24.0, taille);
      final grille = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enTetes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Text(
                        Dates.initiale(jourA(i)),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTokens.fontUi,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.text2,
                        ),
                      ),
                    ),
                  if (flamme != null) const SizedBox(width: largeurFlamme),
                ],
              ),
            ),
          for (var l = 0; l < lignes; l++)
            Padding(
              padding: EdgeInsets.only(top: l == 0 ? 0 : 5),
              child: Row(
                children: [
                  for (var i = l * 7; i < l * 7 + 7; i++)
                    Expanded(
                      child: Center(
                        child: PastilleJour(
                          jour: jourA(i).day,
                          type: seance(jourA(i)),
                          aujourdhui: Dates.memeJour(jourA(i), auj),
                          cadre: false,
                          estompe: jourA(i).month != mois.month,
                          taille: d,
                          onTap: onJour == null ? null : () => onJour!(jourA(i)),
                        ),
                      ),
                    ),
                  if (flamme != null) const SizedBox(width: largeurFlamme),
                ],
              ),
            ),
        ],
      );
      final f = flamme;
      if (f == null) return grille;
      return Stack(
        children: [
          grille,
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: largeurFlamme,
            child: ColonneSerie(
              // La semaine d'avant la première ligne, puis une valeur par ligne.
              semaines: [for (var l = -1; l < lignes; l++) f(jourA(l * 7))],
              pastille: d,
            ),
          ),
        ],
      );
    });
  }
}

/// La flamme de la série (grille de 22), celle de l'accueil.
const traceFlamme = 'M11 2c.7 3.7 5.5 5.4 5.5 10.8a5.5 5.5 0 0 1-11 0c0-2.2 1-3.6 2.4-4.8.2 1.4 1 2.4 1.9 2.6C9.1 7.4 9.8 4.4 11 2z';

/// La colonne de la série, à droite d'une [GrilleMois] : un trait continu
/// qui relie les semaines, orange tant que la série tient, gris ensuite ; un
/// point orange par semaine tenue, un rond vide sinon, et la flamme avec son
/// chiffre sur la seule semaine qui la porte.
class ColonneSerie extends StatelessWidget {
  const ColonneSerie({super.key, required this.semaines, required this.pastille});

  /// La semaine d'avant la première ligne, puis une valeur par ligne :
  /// positif, la flamme et son chiffre ; négatif, une semaine tenue ; 0 ou
  /// null, pas de séance.
  final List<int?> semaines;

  /// Diamètre d'une pastille de jour : la hauteur d'une ligne.
  final double pastille;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final serie = semaines.skip(1).firstWhere((n) => (n ?? 0) > 0, orElse: () => null);
    return Semantics(
      label: serie == null ? null : '$serie semaines de suite',
      excludeSemantics: true,
      child: CustomPaint(painter: _SeriePainter(semaines: semaines, pastille: pastille, gris: c.frame, fond: c.surface)),
    );
  }
}

class _SeriePainter extends CustomPainter {
  _SeriePainter({required this.semaines, required this.pastille, required this.gris, required this.fond});
  final List<int?> semaines;
  final double pastille;
  final Color gris;
  final Color fond;

  /// Écart entre deux lignes de la grille.
  static const _entre = 5.0;

  bool _tenue(int i) => (semaines[i] ?? 0) != 0;

  @override
  void paint(Canvas canvas, Size size) {
    final lignes = semaines.length - 1;
    // Collée à droite : un bon espace la sépare des jours.
    final x = size.width - 18;
    // Les lignes occupent le bas ; ce qui reste en haut est la ligne des initiales.
    final haut = size.height - (lignes * pastille + (lignes - 1) * _entre);
    double y(int ligne) => haut + ligne * (pastille + _entre) + pastille / 2;
    Paint trait(bool orange) => Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = orange ? AppTokens.orange : gris;

    // Les traits d'abord : du haut de la carte à la première semaine, puis
    // d'une semaine à la suivante. Orange entre deux semaines tenues.
    canvas.drawLine(Offset(x, 2), Offset(x, y(0)), trait(_tenue(0) && _tenue(1)));
    for (var l = 0; l < lignes - 1; l++) {
      canvas.drawLine(Offset(x, y(l)), Offset(x, y(l + 1)), trait(_tenue(l + 1) && _tenue(l + 2)));
    }
    // Puis les repères, par-dessus.
    for (var l = 0; l < lignes; l++) {
      final n = semaines[l + 1] ?? 0;
      final centre = Offset(x, y(l));
      if (n == 0) {
        final r = pastille * 0.24;
        canvas.drawCircle(centre, r, Paint()..color = fond);
        canvas.drawCircle(
          centre,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = gris,
        );
      } else if (n < 0) {
        canvas.drawCircle(centre, pastille * 0.12, Paint()..color = AppTokens.orange);
      } else {
        _flamme(canvas, centre, math.min(34.0, pastille * 0.78), n);
      }
    }
  }

  /// Une flamme ronde, large de [l], son corps centré sur [centre] : la
  /// pointe monte au-dessus, le chiffre tient au milieu du corps.
  void _flamme(Canvas canvas, Offset centre, double l, int n) {
    final r = l / 2;
    final g = centre.dx - r;
    // Le corps est un cercle de rayon r ; la flamme le coiffe de 0,62 r.
    final t = centre.dy - r * 1.62;
    Offset p(double u, double v) => Offset(g + u * l, t + v * l);
    final forme = Path()
      ..moveTo(p(0.54, 0).dx, p(0.54, 0).dy)
      // La pointe redescend d'un seul geste sur le flanc droit.
      ..cubicTo(p(0.60, 0.16).dx, p(0.60, 0.16).dy, p(1.0, 0.38).dx, p(1.0, 0.38).dy, p(1.0, 0.81).dx, p(1.0, 0.81).dy)
      // Le corps rond.
      ..arcToPoint(p(0, 0.81), radius: Radius.circular(r), clockwise: true)
      // Le flanc gauche remonte jusqu'à une petite pointe, puis l'encoche.
      ..cubicTo(p(0, 0.58).dx, p(0, 0.58).dy, p(0.08, 0.42).dx, p(0.08, 0.42).dy, p(0.19, 0.27).dx, p(0.19, 0.27).dy)
      ..cubicTo(p(0.23, 0.35).dx, p(0.23, 0.35).dy, p(0.29, 0.39).dx, p(0.29, 0.39).dy, p(0.35, 0.36).dx, p(0.35, 0.36).dy)
      ..cubicTo(p(0.37, 0.22).dx, p(0.37, 0.22).dy, p(0.44, 0.09).dx, p(0.44, 0.09).dy, p(0.54, 0).dx, p(0.54, 0).dy)
      ..close();
    // Un liseré de la couleur de la carte détache la flamme du trait.
    canvas.drawPath(
      forme,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = fond,
    );
    canvas.drawPath(forme, Paint()..color = AppTokens.orange);
    final texte = TextPainter(
      text: TextSpan(
        text: '$n',
        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: l * (n >= 100 ? 0.36 : 0.46), height: 1, fontWeight: FontWeight.w800, color: const Color(0xFF1A1200)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texte.paint(canvas, Offset(centre.dx - texte.width / 2, centre.dy + r * 0.06 - texte.height / 2));
  }

  @override
  bool shouldRepaint(_SeriePainter old) => old.pastille != pastille || old.gris != gris || old.fond != fond || !_memes(old.semaines, semaines);

  static bool _memes(List<int?> a, List<int?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
