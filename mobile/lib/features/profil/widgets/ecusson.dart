import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../core/models/models.dart' show MedailleRecord;
import '../data/grades.dart';

/// Pictogrammes pleins des écussons (Phosphor Icons, licence MIT), dans un
/// carré de 256.
const _traces = <String, String>{
  'cible': 'M221.87,83.16A104.1,104.1,0,1,1,195.67,49l22.67-22.68a8,8,0,0,1,11.32,11.32L167.6,99.71h0l-37.71,37.71-23.95,23.95a40,40,0,0,0,62-35.67,8,8,0,1,1,16-.9,56,56,0,0,1-95.5,42.79h0a56,56,0,0,1,73.13-84.43L184.3,60.39a87.88,87.88,0,1,0,23.13,29.67,8,8,0,0,1,14.44-6.9Z',
  'aube': 'M248,160a8,8,0,0,1-8,8H16a8,8,0,0,1,0-16H56.45a73.54,73.54,0,0,1-.45-8,72,72,0,0,1,144,0,73.54,73.54,0,0,1-.45,8H240A8,8,0,0,1,248,160Zm-40,32H48a8,8,0,0,0,0,16H208a8,8,0,0,0,0-16ZM80.84,59.58a8,8,0,0,0,14.32-7.16l-8-16a8,8,0,0,0-14.32,7.16ZM20.42,103.16l16,8a8,8,0,1,0,7.16-14.31l-16-8a8,8,0,1,0-7.16,14.31ZM216,112a8,8,0,0,0,3.57-.84l16-8a8,8,0,1,0-7.16-14.31l-16,8A8,8,0,0,0,216,112ZM164.42,63.16a8,8,0,0,0,10.74-3.58l8-16a8,8,0,0,0-14.32-7.16l-8,16A8,8,0,0,0,164.42,63.16Z',
  'lune': 'M240,96a8,8,0,0,1-8,8H216v16a8,8,0,0,1-16,0V104H184a8,8,0,0,1,0-16h16V72a8,8,0,0,1,16,0V88h16A8,8,0,0,1,240,96ZM144,56h8v8a8,8,0,0,0,16,0V56h8a8,8,0,0,0,0-16h-8V32a8,8,0,0,0-16,0v8h-8a8,8,0,0,0,0,16Zm65.14,94.33A88.07,88.07,0,0,1,105.67,46.86a8,8,0,0,0-10.6-9.06A96,96,0,1,0,218.2,160.93a8,8,0,0,0-9.06-10.6Z',
  'epee': 'M216,32H152a8,8,0,0,0-6.34,3.12l-64,83.21L72,108.69a16,16,0,0,0-22.64,0l-8.69,8.7a16,16,0,0,0,0,22.63l22,22-32,32a16,16,0,0,0,0,22.63l8.69,8.68a16,16,0,0,0,22.62,0l32-32,22,22a16,16,0,0,0,22.64,0l8.69-8.7a16,16,0,0,0,0-22.63l-9.64-9.64,83.21-64A8,8,0,0,0,224,104V40A8,8,0,0,0,216,32Zm-8,68.06-81.74,62.88L115.32,152l50.34-50.34a8,8,0,0,0-11.32-11.31L104,140.68,93.07,129.74,155.94,48H208Z',
  'flamme': 'M143.38,17.85a8,8,0,0,0-12.63,3.41l-22,60.41L84.59,58.26a8,8,0,0,0-11.93.89C51,87.53,40,116.08,40,144a88,88,0,0,0,176,0C216,84.55,165.21,36,143.38,17.85Zm40.51,135.49a57.6,57.6,0,0,1-46.56,46.55A7.65,7.65,0,0,1,136,200a8,8,0,0,1-1.32-15.89c16.57-2.79,30.63-16.85,33.44-33.45a8,8,0,0,1,15.78,2.68Z',
  'fiole': 'M221.69,199.77,160,96.92V40h8a8,8,0,0,0,0-16H88a8,8,0,0,0,0,16h8V96.92L34.31,199.77A16,16,0,0,0,48,224H208a16,16,0,0,0,13.72-24.23Zm-90.08-42.91c-15.91-8.05-31.05-12.32-45.22-12.81l24.47-40.8A7.93,7.93,0,0,0,112,99.14V40h32V99.14a7.93,7.93,0,0,0,1.14,4.11L183.36,167C171.4,169.34,154.29,168.34,131.61,156.86Z',
  'cartes': 'M200,88V200a16,16,0,0,1-16,16H40a16,16,0,0,1-16-16V88A16,16,0,0,1,40,72H184A16,16,0,0,1,200,88Zm16-48H64a8,8,0,0,0,0,16H216V176a8,8,0,0,0,16,0V56A16,16,0,0,0,216,40Z',
  'trophee': 'M232,64H208V48a8,8,0,0,0-8-8H56a8,8,0,0,0-8,8V64H24A16,16,0,0,0,8,80V96a40,40,0,0,0,40,40h3.65A80.13,80.13,0,0,0,120,191.61V216H96a8,8,0,0,0,0,16h64a8,8,0,0,0,0-16H136V191.58c31.94-3.23,58.44-25.64,68.08-55.58H208a40,40,0,0,0,40-40V80A16,16,0,0,0,232,64ZM48,120A24,24,0,0,1,24,96V80H48v32q0,4,.39,8ZM232,96a24,24,0,0,1-24,24h-.5a81.81,81.81,0,0,0,.5-8.9V80h24Z',
  'chrono': 'M128,40a96,96,0,1,0,96,96A96.11,96.11,0,0,0,128,40Zm45.66,61.66-40,40a8,8,0,0,1-11.32-11.32l40-40a8,8,0,0,1,11.32,11.32ZM96,16a8,8,0,0,1,8-8h48a8,8,0,0,1,0,16H104A8,8,0,0,1,96,16Z',
  'regle': 'M235.32,96,96,235.31a16,16,0,0,1-22.63,0L20.68,182.63a16,16,0,0,1,0-22.63l29.17-29.17a4,4,0,0,1,5.66,0l34.83,34.83a8,8,0,0,0,11.71-.43,8.18,8.18,0,0,0-.6-11.09L66.82,119.51a4,4,0,0,1,0-5.65l15-15a4,4,0,0,1,5.66,0l34.83,34.83a8,8,0,0,0,11.71-.43,8.18,8.18,0,0,0-.6-11.09L98.83,87.51a4,4,0,0,1,0-5.65l15-15a4,4,0,0,1,5.65,0l34.83,34.83a8,8,0,0,0,11.72-.43,8.18,8.18,0,0,0-.61-11.09L130.83,55.51a4,4,0,0,1,0-5.65L160,20.69a16,16,0,0,1,22.63,0l52.69,52.68A16,16,0,0,1,235.32,96Z',
  'appareil': 'M208,56H180.28L166.65,35.56A8,8,0,0,0,160,32H96a8,8,0,0,0-6.65,3.56L75.71,56H48A24,24,0,0,0,24,80V192a24,24,0,0,0,24,24H208a24,24,0,0,0,24-24V80A24,24,0,0,0,208,56Zm-44,76a36,36,0,1,1-36-36A36,36,0,0,1,164,132Z',
  'haltere': 'M200,64V192a16,16,0,0,1-16,16H168a16,16,0,0,1-16-16V136H104v56a16,16,0,0,1-16,16H72a16,16,0,0,1-16-16V64A16,16,0,0,1,72,48H88a16,16,0,0,1,16,16v56h48V64a16,16,0,0,1,16-16h16A16,16,0,0,1,200,64ZM36,72H32A16,16,0,0,0,16,88v32H8.27A8.18,8.18,0,0,0,0,127.47,8,8,0,0,0,8,136h8v32a16,16,0,0,0,16,16h4a4,4,0,0,0,4-4V76A4,4,0,0,0,36,72Zm220,55.47a8.18,8.18,0,0,0-8.25-7.47H240V88a16,16,0,0,0-16-16h-4a4,4,0,0,0-4,4V180a4,4,0,0,0,4,4h4a16,16,0,0,0,16-16V136h8A8,8,0,0,0,256,127.47Z',
  'cadenas': 'M208,80H176V56a48,48,0,0,0-96,0V80H48A16,16,0,0,0,32,96V208a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V96A16,16,0,0,0,208,80ZM96,56a32,32,0,0,1,64,0V80H96Z',
};

final _chemins = <String, Path>{};

Path _picto(String cle) => _chemins.putIfAbsent(cle, () => parseSvgPathData(_traces[cle]!));

/// Forme d'un écusson : l'hexagone des grades ou le bouclier des étapes.
enum FormeEcusson { hexagone, bouclier }

/// Écusson en relief : rebord sombre, face en dégradé, reflet, pictogramme
/// blanc et palier en gros chiffre cerné. Gris avec un cadenas tant qu'il
/// n'est pas gagné.
class Ecusson extends StatelessWidget {
  const Ecusson({
    super.key,
    required this.couleur,
    this.picto,
    this.nombre,
    this.texte,
    this.gagne = true,
    this.forme = FormeEcusson.hexagone,
    this.largeur = 100,
  });

  /// Écusson d'une rubrique (tuiles du profil) : le pictogramme seul, centré.
  const Ecusson.rubrique(this.picto, this.couleur, {super.key, this.largeur = 100})
      : nombre = null,
        texte = null,
        gagne = true,
        forme = FormeEcusson.hexagone;

  /// L'écusson d'un record personnel : la coupe et « PR », en or, en argent
  /// ou en bronze selon la [medaille].
  Ecusson.record({super.key, this.largeur = 100, MedailleRecord medaille = MedailleRecord.or})
      : couleur = Color(medaille.couleur),
        picto = PictoGrade.trophee,
        nombre = null,
        texte = 'PR',
        gagne = true,
        forme = FormeEcusson.hexagone;

  /// L'écusson d'un grade, à son palier atteint.
  Ecusson.grade(Grade g, Avancee a, {super.key, this.largeur = 100})
      : couleur = Color(g.couleur),
        picto = g.picto,
        nombre = a.palier,
        texte = null,
        gagne = a.gagne,
        forme = FormeEcusson.hexagone;

  /// Le bouclier d'une étape de [seances] séances, à son rang dans la liste.
  Ecusson.etape(int seances, int rang, {super.key, this.gagne = true, this.largeur = 100})
      : couleur = Color(Grades.arcEnCiel[(rang + 3) % Grades.arcEnCiel.length]),
        picto = null,
        nombre = seances,
        texte = null,
        forme = FormeEcusson.bouclier;

  final Color couleur;
  final PictoGrade? picto;
  final int? nombre;

  /// Texte à la place du palier (« PR »).
  final String? texte;
  final bool gagne;
  final FormeEcusson forme;
  final double largeur;

  /// Hauteur d'un écusson pour une largeur donnée.
  static double hauteurPour(double largeur) => largeur * 134 / 120;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: largeur,
          height: hauteurPour(largeur),
          child: CustomPaint(painter: _EcussonPainter(gagne ? couleur : const Color(0xFF2C3640), picto, texte ?? nombre?.toString(), gagne, forme)),
        ),
      );
}

class _EcussonPainter extends CustomPainter {
  _EcussonPainter(this.couleur, this.picto, this.nombre, this.gagne, this.forme);

  final Color couleur;
  final PictoGrade? picto;

  /// Palier ou texte court posé en bas de l'écusson.
  final String? nombre;
  final bool gagne;
  final FormeEcusson forme;

  static Color _ton(Color c, double clarte) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness * clarte).clamp(0.0, 1.0)).toColor();
  }

  static Path _hexagone(double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = (-90 + 60 * i) * math.pi / 180;
      final x = r * math.cos(a), y = r * math.sin(a);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }

  static Path _bouclier(double r) {
    final w = r * 0.92;
    return Path()
      ..moveTo(-w, -r * 0.62)
      ..quadraticBezierTo(0, -r * 1.02, w, -r * 0.62)
      ..lineTo(w, r * 0.12)
      ..quadraticBezierTo(w, r * 0.72, 0, r * 1.04)
      ..quadraticBezierTo(-w, r * 0.72, -w, r * 0.12)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Dessin dans un repère de 120 sur 134, centre de la forme en (60, 60).
    final k = size.width / 120;
    canvas.scale(k);
    canvas.translate(60, 60);

    final hex = forme == FormeEcusson.hexagone;
    final dehors = hex ? _hexagone(44) : _bouclier(47);
    final dedans = hex ? _hexagone(41) : _bouclier(44);
    final epDehors = hex ? 14.0 : 8.0;
    final epDedans = hex ? 9.0 : 3.0;

    final clair = _ton(couleur, 1.16), sombre = _ton(couleur, 0.84), bord = _ton(couleur, 0.56);
    Paint plein(Paint p, double ep) => p
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round;
    void forme2(Path p, Paint peinture, double ep) {
      canvas.drawPath(p, plein(peinture, ep));
      canvas.drawPath(
        p,
        Paint()
          ..shader = peinture.shader
          ..color = peinture.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = ep
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Ombre portée, rebord, face.
    canvas.save();
    canvas.translate(0, 5);
    forme2(dehors, Paint()..color = Colors.black.withValues(alpha: 0.55), epDehors);
    canvas.restore();
    forme2(dehors, Paint()..color = bord, epDehors);
    const cadre = Rect.fromLTRB(-50, -50, 50, 52);
    final degrade = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [clair, couleur, sombre],
      stops: const [0, 0.55, 1],
    ).createShader(cadre);
    forme2(dedans, Paint()..shader = degrade, epDedans);

    // Reflet en haut à gauche, voile en bas, tous deux dans la face.
    canvas.save();
    canvas.clipPath(hex ? _hexagone(45) : _bouclier(45.5));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-18, -48), width: 124, height: 80),
      Paint()..color = Colors.white.withValues(alpha: 0.13),
    );
    canvas.drawRect(const Rect.fromLTRB(-60, 26, 60, 76), Paint()..color = Colors.black.withValues(alpha: 0.12));
    canvas.restore();

    // Liseré clair sur l'arête du haut.
    canvas.drawPath(
      dedans,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0)],
          stops: const [0, 0.5],
        ).createShader(cadre),
    );

    // Pictogramme (ou cadenas), avec son ombre.
    final cle = gagne ? picto?.name : 'cadenas';
    if (cle != null) {
      final echBase = gagne ? (hex ? 0.2 : 0.15) : 0.17;
      // Sans palier dessous, le pictogramme prend toute la face.
      final seul = gagne && nombre == null && hex;
      final ech = seul ? 0.25 : echBase;
      final haut = seul ? -34.0 : (gagne ? (hex ? -31.0 : -40.0) : (hex ? -24.0 : -26.0));
      final opacite = gagne ? 1.0 : 0.28;
      canvas.save();
      canvas.translate(-128 * ech, haut);
      canvas.scale(ech);
      final trace = _picto(cle);
      canvas.drawPath(trace.shift(const Offset(0, 14)), Paint()..color = bord.withValues(alpha: 0.7 * opacite));
      canvas.drawPath(trace, Paint()..color = Colors.white.withValues(alpha: opacite));
      canvas.restore();
    }

    // Palier en gros chiffre cerné.
    final texte = nombre;
    if (gagne && texte != null) {
      final corps = hex ? 33.0 : (texte.length <= 3 ? 30.0 : 24.0);
      TextPainter peindre(Paint p) => TextPainter(
            text: TextSpan(
              text: texte,
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w900, fontSize: corps, letterSpacing: -1.4, height: 1, foreground: p),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
      final cerne = peindre(Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hex ? 8 : 5
        ..strokeJoin = StrokeJoin.round
        ..color = hex ? bord : bord.withValues(alpha: 0.55));
      final blanc = peindre(Paint()..color = Colors.white);
      // Ligne de base à 50 (hexagone) ou 14 (bouclier) sous le centre.
      final base = hex ? 50.0 : 14.0;
      final y = base - cerne.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      // L'approche négative décale le texte d'une demi-approche vers la gauche.
      final x = -cerne.width / 2 + 0.7;
      cerne.paint(canvas, Offset(x, y));
      blanc.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(_EcussonPainter old) =>
      old.couleur != couleur || old.picto != picto || old.nombre != nombre || old.gagne != gagne || old.forme != forme;
}
