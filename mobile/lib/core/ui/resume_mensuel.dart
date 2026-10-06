import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// La carte bleue « Résumé mensuel » : titre en Montserrat, mois dessous,
/// rond blanc de lecture à droite. Sur l'accueil du 1er au 3 du mois
/// suivant seulement ; tout le mois dans Progrès.
///
/// ```dart
/// CarteResumeMensuel(mois: 'septembre 2026', onTap: () => context.push(...))
/// ```
class CarteResumeMensuel extends StatelessWidget {
  const CarteResumeMensuel({super.key, required this.mois, this.onTap, this.titre = 'Résumé mensuel'});

  /// Ligne sous le titre (« septembre 2026 »).
  final String mois;
  final VoidCallback? onTap;
  final String titre;

  /// Bleu clair de la ligne du mois.
  static const sousTitre = Color(0xFFC3DCF6);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ouvrir le $titre de $mois',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: const _FondBilan(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 108,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Jamais coupé : sur un écran étroit, le titre
                          // rétrécit pour tenir sur sa ligne.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              titre,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontFamily: AppTokens.fontBilan,
                                fontSize: 24,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            mois,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTokens.fontBilan,
                              fontSize: 15.5,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: sousTitre,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fond de la carte : bleu profond et taches de lumière (les mêmes dégradés
/// radiaux que la maquette, du dernier au premier).
class _FondBilan extends CustomPainter {
  const _FondBilan();

  // (centre x, centre y, rayon x, rayon y, couleur) en fractions de la carte.
  static const _taches = <(double, double, double, double, Color)>[
    (0.35, 1.05, 0.50, 0.60, Color(0xFF021338)),
    (0.80, 0.00, 0.60, 0.80, Color(0xFF03102E)),
    (0.12, 0.18, 0.55, 0.70, Color(0xFF0B4A94)),
    (0.88, 0.78, 0.45, 0.60, Color(0x735A78AA)),
    (0.62, 0.62, 0.60, 0.55, Color(0xD93A7AB0)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF07307A));
    for (final (cx, cy, rx, ry, couleur) in _taches) {
      canvas.save();
      canvas.translate(cx * size.width, cy * size.height);
      canvas.scale(rx * size.width, ry * size.height);
      canvas.drawCircle(
        Offset.zero,
        1,
        Paint()..shader = ui.Gradient.radial(Offset.zero, 1, [couleur, couleur.withValues(alpha: 0)]),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FondBilan old) => false;
}
