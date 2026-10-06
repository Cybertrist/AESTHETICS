import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/mensurations.dart';
import '../routes.dart';
import '../widgets/maquette.dart';

/// Mensurations : le corps de face au centre, chaque mesure reliée à sa
/// zone, puis le poids.
class MensurationsPage extends StatelessWidget {
  const MensurationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sante = context.watch<HealthRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final mesures = sante.measurements;
    final etats = {for (final z in ZoneMesure.values) z: Mensurations.etat(mesures, z)};
    // La saisie la plus récente, même si elle ne porte que le poids : la
    // date annoncée est celle du haut de l'historique.
    final derniere = mesures.isEmpty ? null : mesures.reduce((a, b) => b.date.isAfter(a.date) ? b : a);

    return PageMaquette(
      titre: 'Mensurations',
      sousTitre: derniere == null ? 'Aucune saisie pour l\'instant' : 'Dernière saisie : ${Mensurations.jourLong(derniere.date)}',
      action: mesures.isEmpty
          ? null
          : TextButton(
              onPressed: () => context.push(ProfilPaths.historique),
              style: TextButton.styleFrom(
                foregroundColor: c.text,
                padding: EdgeInsets.symmetric(vertical: e(12)),
                minimumSize: Size(0, e(44)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Historique', style: txt(12, FontWeight.w600, c.text)),
            ),
      bas: BoutonPrincipal(label: 'Saisir mes mesures', onPressed: () => context.push(ProfilPaths.saisie())),
      enfants: [
        Bloc(
          child: Column(
            children: [
              CorpsMesures(etats: etats, onZone: (z) => context.push(ProfilPaths.zone(z))),
              Transform.translate(
                offset: Offset(0, -e(4)),
                child: Text('Touche une mesure pour voir son évolution', textAlign: TextAlign.center, style: txt(11, FontWeight.w400, c.text2)),
              ),
            ],
          ),
        ),
        Bloc(child: _CartePoids(mesures: mesures, unite: unite, objectif: context.watch<ProfileRepo>().profile?.objectif)),
      ],
    );
  }
}

/// Le corps de face et ses huit étiquettes, chacune reliée par un trait fin
/// à sa zone.
class CorpsMesures extends StatelessWidget {
  const CorpsMesures({super.key, required this.etats, required this.onZone});

  final Map<ZoneMesure, EtatZone> etats;
  final ValueChanged<ZoneMesure> onZone;

  static const _image = 'assets/body/pack/face_base.webp';
  static const _ratio = 636 / 1500;

  /// Hauteur des étiquettes, de haut en bas (cotes de la maquette).
  static const _hautsGauche = [46.0, 100.0, 154.0, 208.0];
  static const _hautsDroite = [60.0, 114.0, 168.0, 222.0];

  /// Rectangle de l'image du corps dans un cadre de largeur [largeur].
  static Rect cadreCorps(double largeur) {
    final h = e(252);
    final w = h * _ratio;
    return Rect.fromLTWH((largeur - w) / 2, e(12), w, h);
  }

  /// Point visé par une zone, dans le cadre.
  static Offset ancre(ZoneMesure z, double largeur) {
    final r = cadreCorps(largeur);
    return Offset(r.left + z.ancre.dx * r.width, r.top + z.ancre.dy * r.height);
  }

  /// Centre vertical de l'étiquette d'une zone.
  static double hauteur(ZoneMesure z) {
    final i = (z.aGauche ? ZoneMesure.gauche : ZoneMesure.droite).indexOf(z);
    return e((z.aGauche ? _hautsGauche : _hautsDroite)[i]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final largeur = box.maxWidth;
        final corps = cadreCorps(largeur);
        return SizedBox(
          height: e(276),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fromRect(
                rect: corps,
                child: Image.asset(
                  _image,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                  errorBuilder: (context, _, _) => const SizedBox.shrink(),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _TraitsPainter(largeur: largeur, trait: c.text2, point: c.text, bord: c.bg)),
                ),
              ),
              for (final z in ZoneMesure.values)
                Positioned(
                  left: z.aGauche ? 0 : null,
                  right: z.aGauche ? null : 0,
                  top: hauteur(z) - e(34),
                  height: e(68),
                  width: e(70),
                  child: _Etiquette(zone: z, etat: etats[z] ?? const EtatZone(), onTap: () => onZone(z)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Etiquette extends StatelessWidget {
  const _Etiquette({required this.zone, required this.etat, required this.onTap});
  final ZoneMesure zone;
  final EtatZone etat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = etat.derniere?.valeur;
    final ecart = etat.ecart;
    final texteEcart = Mensurations.ecartTexte(Affichage.ecartLongueur(ecart));
    final droite = !zone.aGauche;
    return Semantics(
      button: true,
      label: v == null
          ? '${zone.label}, pas encore mesuré'
          : '${zone.label}, ${Affichage.lg(v)} ${Affichage.longueurNom}${texteEcart == null ? '' : ', $texteEcart depuis la première saisie'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: droite ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(zone.label, maxLines: 1, style: txt(10, FontWeight.w400, c.text2, interligne: 1.25)),
            if (v == null)
              Text('à saisir', style: txt(10, FontWeight.w600, c.text3, interligne: 1.4))
            else
              Text.rich(
                TextSpan(
                  text: Affichage.lg(v),
                  children: [TextSpan(text: ' ${Affichage.longueur}', style: txt(9.5, FontWeight.w600, c.text2, interligne: 1.25))],
                ),
                maxLines: 1,
                style: txt(14, FontWeight.w800, c.text, interligne: 1.25),
              ),
            // Rien quand la mesure n'a pas bougé.
            if (texteEcart != null)
              Text(texteEcart, style: txt(10, FontWeight.w700, ecart! > 0 ? c.success : c.error, interligne: 1.25)),
          ],
        ),
      ),
    );
  }
}

class _TraitsPainter extends CustomPainter {
  _TraitsPainter({required this.largeur, required this.trait, required this.point, required this.bord});
  final double largeur;
  final Color trait;
  final Color point;
  final Color bord;

  @override
  void paint(Canvas canvas, Size size) {
    final ligne = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = e(1)
      ..strokeJoin = StrokeJoin.round
      ..color = trait;
    for (final z in ZoneMesure.values) {
      final y = CorpsMesures.hauteur(z);
      final a = CorpsMesures.ancre(z, size.width);
      // Départ au bord de l'étiquette, petit palier, puis droit vers la zone.
      final x0 = z.aGauche ? e(58) : size.width - e(58);
      final x1 = z.aGauche ? e(76) : size.width - e(76);
      canvas.drawPath(
        Path()
          ..moveTo(x0, y)
          ..lineTo(x1, y)
          ..lineTo(a.dx, a.dy),
        ligne,
      );
    }
    for (final z in ZoneMesure.values) {
      final a = CorpsMesures.ancre(z, size.width);
      canvas.drawCircle(a, e(2.5) + e(0.4), Paint()..color = bord);
      canvas.drawCircle(a, e(2.5), Paint()..color = point);
    }
  }

  @override
  bool shouldRepaint(_TraitsPainter old) => old.largeur != largeur || old.trait != trait;
}

class _CartePoids extends StatelessWidget {
  const _CartePoids({required this.mesures, required this.unite, this.objectif});

  /// Objectif du profil : il décide si prendre du poids est une bonne nouvelle.
  final Objectif? objectif;
  final List<BodyMeasurement> mesures;
  final UnitePoids unite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final serie = Mensurations.seriePoids(mesures);
    if (serie.isEmpty) {
      return Carte(
        padding: EdgeInsets.symmetric(horizontal: e(14), vertical: e(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Surtitre('Poids'),
            SizedBox(height: e(3)),
            Text('Aucune pesée pour l\'instant', style: txt(12, FontWeight.w400, c.text2)),
          ],
        ),
      );
    }
    final gras = Mensurations.serieGras(mesures);

    // Une colonne : titre, valeur, et l'écart depuis la première saisie dès
    // qu'il y en a deux. Pas de courbe ici : juste les chiffres.
    Widget colonne(String titre, String valeur, List<PointMesure> points, {required String Function(double) ecartTexte, required bool? monterEstBien}) {
      final ecart = points.length < 2 ? null : Mensurations.ecart(points.first.valeur, points.last.valeur);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Surtitre(titre),
          SizedBox(height: e(2)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valeur, maxLines: 1, style: txt(17, FontWeight.w800, c.text)),
          ),
          if (points.length > 1)
            Text(
              ecart == null ? 'stable depuis ${Mensurations.moisDe(points.first.date)}' : '${ecart > 0 ? '+' : '−'}${ecartTexte(ecart.abs())} depuis ${Mensurations.moisDe(points.first.date)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: txt(10.5, FontWeight.w600, ecart == null || monterEstBien == null ? c.text2 : ((ecart > 0) == monterEstBien ? c.success : c.error)),
            ),
        ],
      );
    }

    return Carte(
      padding: EdgeInsets.symmetric(horizontal: e(14), vertical: e(11)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: colonne(
              'Poids',
              Fmt.poids(serie.last.valeur, unite),
              serie,
              ecartTexte: (d) => '${Fmt.n(Fmt.poidsAffiche(d, unite))} ${unite.label}',
              // Vert quand le poids va dans le sens de l'objectif : en baisse
              // pour sécher, en hausse pour prendre du muscle ou de la force.
              // Sans sens voulu (recomposition, forme), l'écart reste gris.
              monterEstBien: switch (objectif) {
                Objectif.secher => false,
                Objectif.prendreDuMuscle || Objectif.force => true,
                Objectif.recomposition || Objectif.forme || null => null,
              },
            ),
          ),
          SizedBox(width: e(14)),
          Expanded(
            child: colonne(
              'Taux de gras',
              gras.isEmpty ? 'à saisir' : '${Fmt.n(gras.last.valeur)} %',
              gras,
              ecartTexte: (d) => '${Fmt.n(d)} %',
              monterEstBien: false,
            ),
          ),
        ],
      ),
    );
  }
}
