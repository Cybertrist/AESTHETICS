import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../../profil/widgets/ecusson.dart';
import '../logic/partage.dart';

/// Couleurs propres aux cartes de partage et de fin de séance (hors thème,
/// reprises de la maquette).
abstract final class CouleursPartage {
  /// Flamme et libellé de la série de semaines.
  static const flamme = AppTokens.orange;

  /// Les deux gris du damier « Ta photo ici ».
  static const damierClair = Color(0xFF2A2A2E);
  static const damierSombre = Color(0xFF232326);

  /// Cadre fin d'une carte.
  static const cadre = AppTokens.frame;

  /// Voile sous l'autocollant, pour le lire sur une photo claire.
  static const voilePhoto = Color(0x99000000);

  /// Bas du voile, là où se pose le texte de l'autocollant.
  static const voilePhotoBas = Color(0xE6000000);

  /// Ombre du texte de l'autocollant posé sur une photo.
  static const ombrePhoto = Color(0xB3000000);

  /// L'or des records, et la lueur sombre derrière l'écusson.
  static const or = Color(0xFFFFBE0B);
  static const lueurOr = Color(0xFF3A2C05);
}

/// Apostrophes typographiques à l'affichage, comme sur la maquette.
String typo(String t) => t.replaceAll("'", String.fromCharCode(0x2019));

/// Échelle du téléphone par rapport aux cotes CSS de la maquette.
const double kEchelle = 1.25;

TextStyle _mont(double taille, FontWeight poids, {Color color = Colors.white, double? height, double? letterSpacing}) => TextStyle(
      fontFamily: AppTokens.fontBilan,
      fontSize: taille * kEchelle,
      fontWeight: poids,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: AppTokens.tabular,
    );

/// « AESTHETICS », le AE à l'accent du thème, en Montserrat noir.
class MarquePartage extends StatelessWidget {
  const MarquePartage({super.key, this.taille = 16});

  /// Taille en cotes de la maquette.
  final double taille;

  @override
  Widget build(BuildContext context) {
    final st = _mont(taille, FontWeight.w900, letterSpacing: taille * kEchelle * 0.02, height: 1.2);
    return Text('AESTHETICS', style: st);
  }
}

/// La flèche « partager » de la maquette (pleine).
class IconePartager extends StatelessWidget {
  const IconePartager({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _FlechePainter(color ?? IconTheme.of(context).color ?? Colors.white)),
      );
}

class _FlechePainter extends CustomPainter {
  _FlechePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22, size.height / 22);
    final p = Path()
      ..moveTo(12.5, 4.5)
      ..lineTo(18.5, 10)
      ..relativeLineTo(-6, 5.5)
      ..relativeLineTo(0, -3.3)
      ..relativeCubicTo(-4, 0, -6.8, 1, -8.5, 4)
      ..relativeCubicTo(0, -4.8, 2.5, -8.3, 8.5, -8.5)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlechePainter old) => old.color != color;
}

/// La flamme pleine de la série de semaines.
class FlammePleine extends StatelessWidget {
  const FlammePleine({super.key, this.size = 105, this.color = CouleursPartage.flamme});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _FlammePainter(color)));
}

class _FlammePainter extends CustomPainter {
  _FlammePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22, size.height / 22);
    final p = Path()
      ..moveTo(11, 1.5)
      ..relativeCubicTo(.8, 4, 6, 5.8, 6, 11.7)
      ..arcToPoint(const Offset(5, 13.2), radius: const Radius.circular(6))
      ..relativeCubicTo(0, -2.4, 1.1, -3.9, 2.6, -5.2)
      ..relativeCubicTo(.2, 1.5, 1.1, 2.6, 2, 2.8)
      ..cubicTo(9, 7.3, 9.7, 4, 11, 1.5)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlammePainter old) => old.color != color;
}

/// Phrase d'un équivalent, le passage fort dans la couleur de l'objet.
class PhraseEquivalent extends StatelessWidget {
  const PhraseEquivalent({super.key, required this.equivalent, this.taille = 17, this.fort = true});

  final Equivalent equivalent;

  /// Taille en cotes de la maquette.
  final double taille;

  /// Colore le passage mis en avant.
  final bool fort;

  @override
  Widget build(BuildContext context) {
    final st = _mont(taille, FontWeight.w800, height: 1.2);
    // Apostrophes typographiques à l'affichage, comme sur la maquette.
    final (avant, milieu, apres) = equivalent.morceaux;

    return Text.rich(
      TextSpan(children: [
        TextSpan(text: typo(avant)),
        TextSpan(text: typo(milieu), style: fort ? TextStyle(color: equivalent.accent) : null),
        TextSpan(text: typo(apres)),
      ]),
      textAlign: TextAlign.center,
      style: st,
    );
  }
}

/// Le corps face et dos, muscles de la séance allumés.
class _Corps extends StatelessWidget {
  const _Corps({required this.intensites, required this.hauteur, this.vertical = false, this.ecart = 22.5});

  final Map<Muscle, double> intensites;
  final double hauteur;
  final bool vertical;
  final double ecart;

  @override
  Widget build(BuildContext context) {
    final vues = [
      BodyMap(view: BodyView.front, intensities: intensites, highlight: context.colors.accent, height: hauteur),
      SizedBox(width: vertical ? 0 : ecart, height: vertical ? ecart : 0),
      BodyMap(view: BodyView.back, intensities: intensites, highlight: context.colors.accent, height: hauteur),
    ];
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: vues)
        : Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: vues);
  }
}

/// Le cadre commun des cartes : coins de 22, filet fin, fond noir.
class CadreCarte extends StatelessWidget {
  const CadreCarte({super.key, required this.child, this.cadre = true, this.fond, this.padding});

  final Widget child;
  final bool cadre;
  final Widget? fond;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    const rayon = BorderRadius.all(Radius.circular(22 * kEchelle));
    return ClipRRect(
      borderRadius: rayon,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: rayon,
          border: cadre ? Border.all(color: CouleursPartage.cadre) : null,
        ),
        child: ColoredBox(
          color: context.colors.bg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ?fond,
              Padding(
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 16 * kEchelle, vertical: 18 * kEchelle),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(this.label, this.valeur);
  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _mont(12.5, FontWeight.w600, height: 1.35)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(valeur, style: _mont(26, FontWeight.w800, letterSpacing: -0.26 * kEchelle, height: 1.3))),
        ],
      );
}

/// Carte 1 : volume, durée, séries et le corps.
class CarteResume extends StatelessWidget {
  const CarteResume({super.key, required this.volume, required this.duree, required this.series, required this.intensites, this.exercices = 0});

  /// Nul sans charge soulevée : le nombre d'exercices prend la place de « 0 kg ».
  final String? volume;
  final int exercices;
  final String duree;
  final int series;
  final Map<Muscle, double> intensites;

  @override
  Widget build(BuildContext context) => CadreCarte(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                volume != null ? _Chiffre('Poids soulevé', volume!) : _Chiffre('Exercices', '$exercices'),
                const SizedBox(height: 12 * kEchelle),
                _Chiffre('Durée', duree),
                const SizedBox(height: 12 * kEchelle),
                _Chiffre('Séries', '$series'),
                const SizedBox(height: 18 * kEchelle),
                _Corps(intensites: intensites, hauteur: 150 * kEchelle, ecart: 18 * kEchelle),
                const SizedBox(height: 12 * kEchelle),
                const MarquePartage(),
              ],
            ),
          ),
        ),
      );
}

/// Carte des records battus pendant la séance. Un seul : l'écusson en grand,
/// l'exercice, la valeur et l'écart avec l'ancien record. Plusieurs : le
/// compte, puis une ligne par record : autant que la carte en contient, [max]
/// au plus, le reste en « + N autres ».
class CarteRecords extends StatelessWidget {
  const CarteRecords({super.key, required this.records, this.max = 5});

  final List<RecordPartage> records;
  final int max;

  /// Lueur dorée en haut de la carte, comme sur le record du bilan.
  Widget _lueur(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.55),
            radius: 0.85,
            colors: [CouleursPartage.lueurOr, context.colors.bg],
          ),
        ),
      );

  List<Widget> _seul(BuildContext context) {
    final c = context.colors;
    final r = records.first;
    return [
      Ecusson.record(largeur: 128 * kEchelle, medaille: r.medaille),
      const SizedBox(height: 6 * kEchelle),
      Text('NOUVEAU RECORD', style: _mont(11, FontWeight.w700, color: CouleursPartage.or, letterSpacing: 1.6 * kEchelle, height: 1.3)),
      const SizedBox(height: 12 * kEchelle),
      Text(typo(r.nom), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: _mont(19, FontWeight.w800, height: 1.2)),
      const SizedBox(height: 6 * kEchelle),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(r.valeur, maxLines: 1, style: _mont(40, FontWeight.w900, letterSpacing: -0.8 * kEchelle, height: 1.15)),
      ),
      if (r.gain != null) ...[
        const SizedBox(height: 4 * kEchelle),
        Text('${r.gain} sur mon ancien record', textAlign: TextAlign.center, style: _mont(12.5, FontWeight.w700, color: c.success, height: 1.35)),
      ],
      const SizedBox(height: 6 * kEchelle),
      Text(r.type, textAlign: TextAlign.center, style: _mont(12, FontWeight.w600, color: c.text2, height: 1.35)),
    ];
  }

  Widget _ligne(BuildContext context, RecordPartage r) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8 * kEchelle),
      padding: const EdgeInsets.fromLTRB(10 * kEchelle, 7 * kEchelle, 14 * kEchelle, 7 * kEchelle),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14 * kEchelle)),
      child: Row(
        children: [
          Ecusson.record(largeur: 38 * kEchelle, medaille: r.medaille),
          const SizedBox(width: 14 * kEchelle),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typo(r.nom),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13 * kEchelle, height: 1.25, fontWeight: FontWeight.w600, color: c.text),
                ),
                const SizedBox(height: 1 * kEchelle),
                // La valeur puis l'écart ; à l'étroit, l'écart passe dessous.
                Wrap(
                  spacing: 8 * kEchelle,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      r.valeur,
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14 * kEchelle, height: 1.3, fontWeight: FontWeight.w800, color: c.text, fontFeatures: AppTokens.tabular),
                    ),
                    if (r.gain != null)
                      Text(
                        r.gain!,
                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 11.5 * kEchelle, height: 1.3, fontWeight: FontWeight.w700, color: c.success, fontFeatures: AppTokens.tabular),
                      ),
                  ],
                ),
                Text(
                  r.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 11 * kEchelle, height: 1.35, color: c.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hauteurs prévues, pour savoir ce qui tient : le compte et la marque
  /// autour des lignes, une ligne avec sa marge (nom sur une ligne), et le
  /// grand écusson de l'entête.
  static const _autour = 118 * kEchelle;
  static const _pas = 71 * kEchelle;
  static const _grand = 60 * kEchelle;

  /// Nombre de lignes qui tiennent dans une carte haute de [hauteur].
  int _places(double hauteur) => ((hauteur - _autour) / _pas).floor().clamp(2, max);

  List<Widget> _plusieurs(BuildContext context, double hauteur) {
    final places = _places(hauteur);
    // La dernière ligne cède sa place au décompte quand la liste dépasse.
    final montres = records.length <= places ? records : records.take(places - 1).toList();
    final reste = records.length - montres.length;
    // Le grand écusson coiffe la carte tant qu'il ne prend la place d'aucune
    // ligne : chacune porte déjà le sien.
    final coiffe = _autour + Ecusson.hauteurPour(_grand) + (montres.length + (reste > 0 ? 1 : 0)) * _pas <= hauteur;
    return [
      if (coiffe) ...[
        Ecusson.record(largeur: _grand),
        const SizedBox(height: 2 * kEchelle),
      ],
      Text('${records.length}', style: _mont(44, FontWeight.w800, height: 1)),
      const SizedBox(height: 4 * kEchelle),
      Text('records battus', style: _mont(19, FontWeight.w800, color: CouleursPartage.or, height: 1.2)),
      const SizedBox(height: 14 * kEchelle),
      for (final r in montres) _ligne(context, r),
      if (reste > 0)
        Padding(
          padding: const EdgeInsets.only(top: 2 * kEchelle),
          child: Text('+ $reste ${reste > 1 ? 'autres' : 'autre'}', style: _mont(12, FontWeight.w700, color: context.colors.text2, height: 1.35)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => CadreCarte(
        fond: _lueur(context),
        // Sur un petit écran, la carte entière rétrécit plutôt que de déborder ;
        // la largeur reste celle de la carte pour que les lignes la remplissent,
        // sans s'étirer sur un écran large (Fold ouvert).
        child: LayoutBuilder(
          builder: (context, boite) => Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: boite.maxWidth.clamp(0.0, 340 * kEchelle),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...(records.length == 1 ? _seul(context) : _plusieurs(context, boite.maxHeight)),
                    const SizedBox(height: 14 * kEchelle),
                    const MarquePartage(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Carte 2 : le volume comparé à un objet.
class CarteEquivalent extends StatelessWidget {
  const CarteEquivalent({super.key, required this.volume, required this.equivalent});

  final String volume;
  final Equivalent equivalent;

  @override
  Widget build(BuildContext context) => CadreCarte(
        // Sur un petit écran, la carte entière rétrécit plutôt que de déborder ;
        // la largeur reste celle de la carte pour que la phrase passe à la ligne.
        child: LayoutBuilder(
          builder: (context, boite) => Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: boite.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Chiffre('Je viens de soulever', volume),
                    const SizedBox(height: 12 * kEchelle),
                    Objet3D(asset: equivalent.asset, halo: equivalent.accent, hauteur: 190 * kEchelle, copies: false),
                    const SizedBox(height: 12 * kEchelle),
                    PhraseEquivalent(equivalent: equivalent, taille: 16, fort: false),
                    const SizedBox(height: 12 * kEchelle),
                    const MarquePartage(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Carte 3 : la date, le nom, chaque exercice, et le corps à droite.
class CarteDetail extends StatelessWidget {
  const CarteDetail({super.key, required this.date, required this.nom, required this.resume, required this.lignes, required this.intensites});

  final String date;
  final String nom;

  /// « 10 348 kg · 1 h 27 ».
  final String resume;
  final List<String> lignes;
  final Map<Muscle, double> intensites;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CadreCarte(
      child: Row(
        children: [
          Expanded(
            // Nom sur deux lignes et huit exercices : sur un petit écran, le
            // texte rétrécit plutôt que de déborder.
            child: LayoutBuilder(
              builder: (context, boite) => Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: boite.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(date, style: _mont(11, FontWeight.w600, color: c.text2)),
                        const SizedBox(height: 26 * kEchelle),
                        Text(nom.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: _mont(19, FontWeight.w800, height: 1.2)),
                        Text(resume, style: _mont(12, FontWeight.w700, height: 1.5)),
                        const SizedBox(height: 12 * kEchelle),
                        for (final l in lignes)
                          Text(
                            l,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 11.5 * kEchelle, height: 1.65, color: c.text, fontWeight: FontWeight.w500),
                          ),
                        const SizedBox(height: 22 * kEchelle),
                        const MarquePartage(taille: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8 * kEchelle),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _Corps(intensites: intensites, hauteur: 170 * kEchelle, vertical: true, ecart: 8 * kEchelle),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte 4 : la flamme et le nombre de semaines d'affilée.
class CarteSerie extends StatelessWidget {
  const CarteSerie({super.key, required this.semaines, required this.libelle, required this.phrase});

  final int semaines;
  final String libelle;
  final String phrase;

  @override
  Widget build(BuildContext context) => CadreCarte(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FlammePleine(size: 84 * kEchelle),
              const SizedBox(height: 12 * kEchelle),
              Text('$semaines', style: _mont(64, FontWeight.w800, height: 0.95)),
              const SizedBox(height: 12 * kEchelle),
              Text(typo(libelle), style: _mont(19, FontWeight.w800, color: CouleursPartage.flamme, height: 1.2)),
              const SizedBox(height: 12 * kEchelle),
              Text(typo(phrase), textAlign: TextAlign.center, style: _mont(12, FontWeight.w600, color: context.colors.text2, height: 1.35)),
              const SizedBox(height: 12 * kEchelle),
              const MarquePartage(),
            ],
          ),
        ),
      );
}

/// Carte 5 : l'autocollant de la séance posé sur une photo.
class CarteAutocollant extends StatelessWidget {
  const CarteAutocollant({super.key, required this.nom, required this.volume, required this.series, required this.duree, this.photo, this.type = TypeSeance.musculation});

  final String nom;
  final String volume;
  final int series;
  final String duree;

  /// Chemin de la photo ; sans photo, un damier « Ta photo ici ».
  final String? photo;
  final TypeSeance type;

  /// Police à empattement du système (la maquette est en Georgia).
  static const _serif = TextStyle(fontFamily: 'serif', fontFamilyFallback: ['Noto Serif', 'Georgia', 'Times New Roman'], color: Colors.white);

  /// Sur une photo, une ombre garde le texte lisible.
  TextStyle get _texte => photo == null
      ? _serif
      : _serif.copyWith(shadows: const [Shadow(color: CouleursPartage.ombrePhoto, blurRadius: 10, offset: Offset(0, 1))]);

  Widget _valeur(String label, String valeur) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _texte.copyWith(fontSize: 12 * kEchelle, height: 1.35)),
          Text(valeur, style: _texte.copyWith(fontSize: 19 * kEchelle, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, height: 1.3)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final avecPhoto = photo != null;
    return CadreCarte(
      cadre: false,
      fond: avecPhoto
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(photo!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const CustomPaint(painter: _DamierPainter())),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.3, 0.6, 1],
                      colors: [Colors.transparent, CouleursPartage.voilePhoto, CouleursPartage.voilePhotoBas],
                    ),
                  ),
                ),
              ],
            )
          : const CustomPaint(painter: _DamierPainter()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: avecPhoto
                ? const SizedBox()
                : Center(child: Text('Ta photo ici', style: _mont(13, FontWeight.w600, color: context.colors.text2))),
          ),
          IconeTypeSeance(type, size: 24 * kEchelle, color: Colors.white, epaisseur: 1.8),
          const SizedBox(height: 6 * kEchelle),
          Text(
            nom.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _texte.copyWith(fontSize: 24 * kEchelle, fontStyle: FontStyle.italic, height: 1.3),
          ),
          const SizedBox(height: 6 * kEchelle),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_valeur('Volume', volume), const SizedBox(width: 26 * kEchelle), _valeur('Séries', '$series')],
            ),
          ),
          const SizedBox(height: 8 * kEchelle),
          _valeur('Durée', duree),
        ],
      ),
    );
  }
}

class _DamierPainter extends CustomPainter {
  const _DamierPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const pas = 14 * kEchelle;
    canvas.drawRect(Offset.zero & size, Paint()..color = CouleursPartage.damierSombre);
    final clair = Paint()..color = CouleursPartage.damierClair;
    for (var y = 0; y * pas < size.height; y++) {
      for (var x = 0; x * pas < size.width; x++) {
        if ((x + y).isEven) canvas.drawRect(Rect.fromLTWH(x * pas, y * pas, pas, pas), clair);
      }
    }
  }

  @override
  bool shouldRepaint(_DamierPainter old) => false;
}

/// Points de pagination : un point par carte, l'actif allongé et blanc.
class PointsPagination extends StatelessWidget {
  const PointsPagination({super.key, required this.nombre, required this.actif});

  final int nombre;
  final int actif;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < nombre; i++)
            AnimatedContainer(
              duration: AppTokens.fast,
              margin: const EdgeInsets.symmetric(horizontal: 3 * kEchelle),
              width: (i == actif ? 14 : 5) * kEchelle,
              height: 5 * kEchelle,
              decoration: BoxDecoration(
                color: i == actif ? context.colors.text : context.colors.surface2,
                borderRadius: AppTokens.radiusPill,
              ),
            ),
        ],
      );
}

/// Bouton rond gris de l'en-tête (croix, plus).
class BoutonRond extends StatelessWidget {
  const BoutonRond({super.key, required this.icone, required this.label, required this.onTap, this.fond = true});

  final IconData icone;
  final String label;
  final VoidCallback? onTap;
  final bool fond;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: fond ? context.colors.surface2 : Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 44 * kEchelle,
              child: Icon(icone, size: 24, color: Colors.white),
            ),
          ),
        ),
      );
}
