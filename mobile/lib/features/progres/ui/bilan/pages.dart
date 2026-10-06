import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:path_drawing/path_drawing.dart';

import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../profil/widgets/ecusson.dart';
import '../../logic/bilan_mois.dart';
import '../../logic/tableau.dart';
import '../communs.dart';
import 'couleurs.dart';
import 'toile.dart';

/// « de septembre », « d'août ».
String deMois(DateTime mois) {
  final nom = Calculs.moisNom(mois);
  // avril, août, octobre.
  return nom.startsWith('a') || nom.startsWith('o') ? 'd\'$nom' : 'de $nom';
}

/// Volume en kilos, sans unité : « 66 291 ».
String _kilos(double v) => Fmt.n(v, decimals: 0);

/// Volume d'une ligne de séance : « 5 728 kg » ; rien pour une séance sans
/// charge (cardio), où seule la durée compte.
String _volumeLigne(double v) => v > 0 ? '${_kilos(v)} kg' : '';

/// « 1 h 27 », « 49 min ».
String _duree(Duration d) => d.inMinutes == 0 ? '0 min' : Fmt.duree(d);

/// Grand titre en capitales : « SEPTEMBRE\n2026 », « ANNÉE\n2026 ».
class _TitreMois extends StatelessWidget {
  const _TitreMois(this.titre, {this.taille = 37.5});
  final String titre;
  final double taille;

  @override
  Widget build(BuildContext context) => Text(
        titre,
        style: tb(taille, FontWeight.w800, hauteur: 1, espace: -0.3),
      );
}

/// Écart contre le mois d'avant : triangle, pourcentage, suite en clair.
/// Rien si l'écart est nul ou sans base.
class EcartBilan extends StatelessWidget {
  const EcartBilan({super.key, required this.ecart, required this.suite});
  final int? ecart;
  final String suite;

  @override
  Widget build(BuildContext context) {
    final e = ecart;
    if (e == null) return const SizedBox.shrink();
    final couleur = e < 0 ? CouleursBilan.baisse : CouleursBilan.hausse;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(10, 8), painter: _Triangle(couleur, versLeBas: e < 0)),
        const SizedBox(width: 5),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: '${Fmt.n(e.abs(), decimals: 0)} %',
                style: tb(15.5, FontWeight.w800, couleur: couleur, espace: 0.3),
                children: [TextSpan(text: ' $suite', style: tb(15.5, FontWeight.w600, couleur: CouleursBilan.encre2, espace: 0.3))],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _Triangle extends CustomPainter {
  _Triangle(this.couleur, {required this.versLeBas});
  final Color couleur;
  final bool versLeBas;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (versLeBas) {
      p
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    } else {
      p
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width / 2, 0);
    }
    canvas.drawPath(p..close(), Paint()..color = couleur);
  }

  @override
  bool shouldRepaint(_Triangle old) => old.couleur != couleur || old.versLeBas != versLeBas;
}

/// Icône au trait d'un tracé SVG (grille libre).
class _Trace extends StatelessWidget {
  const _Trace(this.trace, {required this.largeur, required this.hauteur, required this.grille, this.epaisseur = 1.6});
  final String trace;
  final double largeur;
  final double hauteur;
  final Size grille;
  final double epaisseur;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: largeur,
        height: hauteur,
        child: CustomPaint(painter: _TracePainter(trace, grille, epaisseur)),
      );
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.trace, this.grille, this.epaisseur);
  final String trace;
  final Size grille;
  final double epaisseur;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / grille.width, size.height / grille.height);
    canvas.drawPath(
      parseSvgPathData(trace),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = CouleursBilan.encre,
    );
  }

  @override
  bool shouldRepaint(_TracePainter old) => old.trace != trace || old.epaisseur != epaisseur;
}

// ------------------------------------------------------------ entrées

/// Le tempo d'une page du bilan : une animation de 0 à 1, relancée à chaque
/// changement de page. Sans lui (carte partagée, tests d'une page seule),
/// tout s'affiche d'un coup.
class TempoBilan extends InheritedWidget {
  const TempoBilan({super.key, required this.tempo, required super.child});
  final Animation<double> tempo;

  static Animation<double>? de(BuildContext context) => context.getInheritedWidgetOfExactType<TempoBilan>()?.tempo;

  /// Avancement, de 0 à 1 et adouci, de l'élément [rang] parmi [sur] : ils
  /// entrent l'un après l'autre, chacun sur une part [duree] du tempo.
  static double part(double v, int rang, int sur, {double duree = 0.42}) {
    final depart = sur <= 1 ? 0.0 : (rang / (sur - 1)) * (1 - duree);
    return Curves.easeOutCubic.transform(((v - depart) / duree).clamp(0.0, 1.0));
  }

  @override
  bool updateShouldNotify(TempoBilan old) => old.tempo != tempo;
}

/// Reconstruit [builder] à chaque pas du tempo ; à 1 sans tempo.
class AuTempo extends StatelessWidget {
  const AuTempo({super.key, required this.builder});
  final Widget Function(BuildContext context, double v) builder;

  @override
  Widget build(BuildContext context) {
    final tempo = TempoBilan.de(context);
    if (tempo == null) return builder(context, 1);
    return AnimatedBuilder(animation: tempo, builder: (context, _) => builder(context, tempo.value));
  }
}

/// Un élément qui entre à son tour : il monte de quelques points en
/// apparaissant ([grossit] : il grandit au lieu de monter).
class Entree extends StatelessWidget {
  const Entree(this.rang, this.sur, {super.key, required this.child, this.grossit = false});
  final int rang;
  final int sur;
  final Widget child;
  final bool grossit;

  @override
  Widget build(BuildContext context) {
    final tempo = TempoBilan.de(context);
    if (tempo == null) return child;
    return AnimatedBuilder(
      animation: tempo,
      child: child,
      builder: (context, c) {
        final t = TempoBilan.part(tempo.value, rang, sur);
        return Opacity(
          opacity: t,
          child: grossit ? Transform.scale(scale: 0.7 + 0.3 * t, child: c) : Transform.translate(offset: Offset(0, 16 * (1 - t)), child: c),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- 1

/// Ouverture : de grandes barres et le titre, sur fond noir.
class PageOuverture extends StatelessWidget {
  const PageOuverture({super.key, this.annuel = false});

  /// Résumé d'une année entière.
  final bool annuel;

  static const _hauteurs = [0.35, 0.55, 0.45, 0.72, 0.60, 0.85, 1.0];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 250,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, h) in _hauteurs.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: AuTempo(
                    builder: (context, v) => Container(
                      height: 250 * h * TempoBilan.part(v, i, _hauteurs.length + 3),
                      decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(7.5)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 30),
        Entree(1, 2, child: Text(annuel ? 'Résumé\nannuel' : 'Résumé\nmensuel', textAlign: TextAlign.center, style: tb(37.5, FontWeight.w800, hauteur: 1.35))),
      ],
    );
  }
}

// ---------------------------------------------------------------- 2

/// Toutes les séances : le mois en titre, chaque séance avec sa durée et
/// son volume, et le total.
class PageSeances extends StatelessWidget {
  const PageSeances({super.key, required this.bilan, this.hauteur = double.infinity});
  final BilanMois bilan;

  /// Hauteur offerte à la page : au-delà, la liste se resserre puis se
  /// résume, plutôt que de rétrécir toute la page jusqu'à l'illisible.
  final double hauteur;

  static const _tailleMax = 13.75;
  static const _tailleMin = 10.0;
  static const _interligne = 1.42;

  /// Titre du mois (deux lignes de 37,5), son écart, et celui du total.
  static const _fixe = 75 + 17.5 + 10;

  /// Taille du texte et nombre de séances montrées pour [n] séances dans
  /// [hauteur] : toutes si elles tiennent à 10 de corps au moins, sinon les
  /// premières, les autres regroupées sur une ligne.
  static (double, int) mesure(int n, double hauteur) {
    if (!hauteur.isFinite) return (_tailleMax, n);
    final place = hauteur - _fixe - 1;
    final taille = (place / (_interligne * (n + 1))).clamp(_tailleMin, _tailleMax);
    final lignes = (place / (_interligne * taille)).floor();
    if (n + 1 <= lignes || n <= 1) return (taille, n);
    // Une ligne pour le total, une pour « et N autres ».
    return (taille, (lignes - 2).clamp(1, n - 1));
  }

  @override
  Widget build(BuildContext context) {
    final (taille, montrees) = mesure(bilan.seances.length, hauteur);
    final reste = bilan.seances.skip(montrees).toList();
    final style = tb(taille, FontWeight.w800, hauteur: _interligne);
    // Les lignes arrivent l'une après l'autre, le total en dernier.
    final nbLignes = montrees + (reste.isEmpty ? 0 : 1) + 1;
    var rang = 0;
    TableRow ligne(String nom, String duree, String volume, {double haut = 0}) {
      final r = rang++;
      return TableRow(children: [
        Padding(padding: EdgeInsets.only(top: haut), child: Entree(r, nbLignes, child: Text(nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: style))),
        Padding(padding: EdgeInsets.only(top: haut, left: 15), child: Entree(r, nbLignes, child: Text(duree, maxLines: 1, textAlign: TextAlign.right, style: style))),
        Padding(padding: EdgeInsets.only(top: haut, left: 15), child: Entree(r, nbLignes, child: Text(volume, maxLines: 1, textAlign: TextAlign.right, style: style))),
      ]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitreMois(bilan.titre),
        const SizedBox(height: 17.5),
        if (bilan.vide)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('Aucune séance ${bilan.cettePeriode}.', style: tb(15, FontWeight.w600, couleur: CouleursBilan.encre2, hauteur: 1.35)),
          ),
        Table(
          columnWidths: const {0: FlexColumnWidth(), 1: IntrinsicColumnWidth(), 2: IntrinsicColumnWidth()},
          children: [
            for (final s in bilan.seances.take(montrees))
              ligne(s.nom.trim().isEmpty ? 'SÉANCE' : s.nom.toUpperCase(), _duree(s.duree), _volumeLigne(s.volume)),
            if (reste.isNotEmpty)
              ligne(
                bilan.annuel ? 'ET ${reste.length} AUTRES MOIS' : 'ET ${reste.length} AUTRES SÉANCES',
                _duree(reste.fold(Duration.zero, (a, s) => a + s.duree)),
                _volumeLigne(reste.fold(0.0, (a, s) => a + s.volume)),
              ),
            ligne('TOTAL', _duree(bilan.dureeTotale), '${_kilos(bilan.volume)} kg', haut: 10),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 3

/// Régularité : le nombre de séances, l'écart, et le calendrier du mois
/// (pour une année, ses douze mois de carrés).
class PageRegularite extends StatelessWidget {
  const PageRegularite({super.key, required this.bilan});
  final BilanMois bilan;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Entraînements ${bilan.enPeriode}', textAlign: TextAlign.center, style: tb(20, FontWeight.w700, hauteur: 1.25)),
        const SizedBox(height: 17.5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconeHaltere(size: 57.5, color: CouleursBilan.encre, epaisseur: 1.8),
            const SizedBox(width: 12.5),
            Text('${bilan.nbSeances}', style: tb(75, FontWeight.w800, hauteur: 0.95, espace: -2.2)),
          ],
        ),
        if (bilan.ecartSeances != null) ...[
          const SizedBox(height: 17.5),
          EcartBilan(ecart: bilan.ecartSeances, suite: bilan.contreAvant),
        ],
        SizedBox(height: bilan.annuel ? 17.5 : 30),
        // Le bilan d'un mois ne montre que ce mois ; celui d'une année, ses
        // douze mois en quatre rangées.
        if (!bilan.annuel)
          _MoisCalendrier(bilan.regularite.last)
        else
          for (var l = 0; l < (bilan.regularite.length / 3).ceil(); l++)
            Padding(
              padding: EdgeInsets.only(top: l == 0 ? 0 : 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = l * 3; i < l * 3 + 3; i++) ...[
                    if (i > l * 3) const SizedBox(width: 17.5),
                    Expanded(child: _MoisCases(bilan.regularite[i])),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}

/// Le calendrier d'un seul mois : les initiales des jours, puis une case
/// par jour avec son numéro, verte les jours d'entraînement.
class _MoisCalendrier extends StatelessWidget {
  const _MoisCalendrier(this.m);
  final MoisRegularite m;

  @override
  Widget build(BuildContext context) {
    final cases = <int?>[for (var i = 0; i < m.decalage; i++) null, for (var j = 1; j <= m.jours.length; j++) j];
    final lignes = (cases.length / 7).ceil();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: LayoutBuilder(builder: (context, box) {
        const ecart = 7.0;
        final cote = (box.maxWidth - 6 * ecart) / 7;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final (i, l) in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'].indexed) ...[
                  if (i > 0) const SizedBox(width: ecart),
                  SizedBox(width: cote, child: Text(l, textAlign: TextAlign.center, style: tb(12.5, FontWeight.w700, couleur: CouleursBilan.encre2, hauteur: 1.3))),
                ],
              ],
            ),
            const SizedBox(height: 9),
            for (var l = 0; l < lignes; l++)
              Padding(
                padding: EdgeInsets.only(top: l == 0 ? 0 : ecart),
                child: Row(
                  children: [
                    for (var i = l * 7; i < l * 7 + 7; i++) ...[
                      if (i > l * 7) const SizedBox(width: ecart),
                      if (i >= cases.length || cases[i] == null)
                        SizedBox(width: cote, height: cote)
                      else
                        AuTempo(
                          builder: (context, v) {
                            final jour = cases[i]!;
                            // Un jour d'entraînement s'allume à son tour, avec un petit rebond.
                            final t = m.jours[jour - 1] ? TempoBilan.part(v, jour - 1, m.jours.length, duree: 0.25) : 0.0;
                            return Transform.scale(
                              scale: 1 + 0.18 * math.sin(t * math.pi),
                              child: Container(
                                width: cote,
                                height: cote,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Color.lerp(CouleursBilan.caseVide, CouleursBilan.caseFaite, t),
                                  borderRadius: BorderRadius.circular(cote * 0.26),
                                ),
                                child: Text(
                                  '$jour',
                                  style: tb(cote * 0.36, FontWeight.w700, couleur: Color.lerp(CouleursBilan.encre2, CouleursBilan.noir, t)!, hauteur: 1),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _MoisCases extends StatelessWidget {
  const _MoisCases(this.m);
  final MoisRegularite m;

  @override
  Widget build(BuildContext context) {
    final cases = <bool?>[for (var i = 0; i < m.decalage; i++) null, ...m.jours];
    final lignes = (cases.length / 7).ceil();
    return Column(
      children: [
        Text(Calculs.moisCourt(m.mois), style: tb(13.75, FontWeight.w700, hauteur: 1.35)),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, box) {
          const ecart = 3.0;
          final cote = (box.maxWidth - 6 * ecart) / 7;
          return Column(
            children: [
              for (var l = 0; l < lignes; l++)
                Padding(
                  padding: EdgeInsets.only(top: l == 0 ? 0 : ecart),
                  child: Row(
                    children: [
                      for (var i = l * 7; i < l * 7 + 7; i++) ...[
                        if (i > l * 7) const SizedBox(width: ecart),
                        Container(
                          width: cote,
                          height: cote,
                          decoration: BoxDecoration(
                            color: i >= cases.length || cases[i] == null
                                ? null
                                : (cases[i]! ? CouleursBilan.caseFaite : CouleursBilan.caseVide),
                            borderRadius: BorderRadius.circular(3.75),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------- 4

/// Volume : le poids soulevé, l'écart, et douze mois en barres.
class PageVolume extends StatelessWidget {
  const PageVolume({super.key, required this.bilan});
  final BilanMois bilan;

  @override
  Widget build(BuildContext context) {
    final max = bilan.volumes.fold(0.0, (a, b) => math.max(a, b.volume));
    final iMax = bilan.volumes.indexWhere((b) => b.volume == max);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Poids soulevé ${bilan.enPeriode}', textAlign: TextAlign.center, style: tb(20, FontWeight.w700, hauteur: 1.25)),
        const SizedBox(height: 17.5),
        _GrandVolume(bilan.volume),
        if (bilan.ecartVolume != null) ...[
          const SizedBox(height: 17.5),
          EcartBilan(ecart: bilan.ecartVolume, suite: bilan.contreAvant),
        ],
        const SizedBox(height: 17.5),
        for (final (i, b) in bilan.volumes.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 7.5),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    b.debut.year == bilan.mois.year ? b.label : '${b.label} ${b.debut.year % 100}',
                    maxLines: 1,
                    style: tb(15, b.courante ? FontWeight.w700 : FontWeight.w600, hauteur: 1.35),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AuTempo(
                      builder: (context, v) => FractionallySizedBox(
                      widthFactor: math.max(0.015, (max <= 0 ? 0.015 : (b.volume / max).clamp(0.015, 1.0)) * TempoBilan.part(v, i, bilan.volumes.length)),
                      child: Container(
                        height: 27.5,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 7.5),
                        decoration: BoxDecoration(
                          color: b.courante ? CouleursBilan.encre : CouleursBilan.barre,
                          borderRadius: BorderRadius.circular(3.75),
                        ),
                        // Le chiffre du plus gros mois, dans sa barre, une fois la barre arrivée.
                        child: i == iMax && max > 0 && TempoBilan.part(v, i, bilan.volumes.length) > 0.95
                            ? Text('${_kilos(b.volume)} kg', maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: tb(12.5, FontWeight.w700, couleur: CouleursBilan.noir))
                            : null,
                      ),
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// « 66 291 kg » en très grand.
class _GrandVolume extends StatelessWidget {
  const _GrandVolume(this.kg, {this.taille = 75});
  final double kg;
  final double taille;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text.rich(
          TextSpan(
            text: _kilos(kg),
            children: [TextSpan(text: ' kg', style: tb(taille * 0.4, FontWeight.w800, espace: 0))],
          ),
          maxLines: 1,
          style: tb(taille, FontWeight.w800, hauteur: 0.95, espace: -taille * 0.03),
        ),
      );
}

// ---------------------------------------------------------------- 5

/// L'équivalent : le poids du mois comparé à un objet en 3D.
class PageEquivalent extends StatelessWidget {
  const PageEquivalent({super.key, required this.bilan, required this.equivalent});
  final BilanMois bilan;
  final Equivalent equivalent;

  @override
  Widget build(BuildContext context) {
    final (avant, fort, apres) = equivalent.morceaux;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Poids soulevé ${bilan.enPeriode}', textAlign: TextAlign.center, style: tb(16.25, FontWeight.w700, hauteur: 1.25)),
        const SizedBox(height: 12.5),
        _GrandVolume(bilan.volume, taille: 57.5),
        const SizedBox(height: 12.5),
        Entree(0, 3, grossit: true, child: Objet3D(asset: equivalent.asset, etiquette: equivalent.etiquette, halo: equivalent.accent, hauteur: 295)),
        const SizedBox(height: 12.5),
        Entree(
          2,
          3,
          child: Text.rich(
          TextSpan(
            text: avant,
            children: [
              TextSpan(text: fort, style: TextStyle(color: equivalent.accent)),
              TextSpan(text: apres),
            ],
          ),
          textAlign: TextAlign.center,
          style: tb(22.5, FontWeight.w800, hauteur: 1.2),
        ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 6

/// Série de semaines : la flamme et le nombre, en très grand.
class PageSerie extends StatelessWidget {
  const PageSerie({super.key, required this.bilan});
  final BilanMois bilan;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Entree(
            0,
            3,
            grossit: true,
            child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Trace(
                  'M11 2.5c.6 3.4 5 5 5 10a5 5 0 0 1-10 0c0-2 .9-3.3 2.2-4.4.2 1.3.9 2.2 1.7 2.4C9.3 7.5 9.9 4.7 11 2.5z',
                  largeur: 97.5,
                  hauteur: 97.5,
                  grille: Size(22, 22),
                  epaisseur: 1.5,
                ),
                const SizedBox(width: 7.5),
                Text('${bilan.serieSemaines}', style: tb(130, FontWeight.w800, hauteur: 0.95, espace: -3.9)),
              ],
            ),
          ),
          ),
          const SizedBox(height: 17.5),
          Entree(
            2,
            3,
            child: Text(
            switch (bilan.serieSemaines) {
              0 => bilan.annuel ? 'Pas de série\ncette année' : 'Pas de série\nen cours',
              1 => 'Semaine\nde série',
              _ => bilan.annuel ? 'Semaines de suite,\nton record de l\'année' : 'Série\nhebdomadaire !',
            },
            textAlign: TextAlign.center,
            style: tb(30, FontWeight.w800, hauteur: 1.15),
          ),
          ),
        ],
      );
}

// ---------------------------------------------------------------- 7

/// Muscles travaillés : la toile du mois devant, celle d'avant en gris.
class PageMuscles extends StatelessWidget {
  const PageMuscles({super.key, required this.bilan});
  final BilanMois bilan;

  @override
  Widget build(BuildContext context) {
    Widget legende(String nom, Color point, Color encre) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: point, shape: BoxShape.circle)),
            const SizedBox(width: 7.5),
            Text(nom, style: tb(17.5, FontWeight.w700, couleur: encre)),
          ],
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Entree(0, 3, grossit: true, child: ToileMuscles(axes: bilan.toile)),
        const SizedBox(height: 17.5),
        Entree(
          2,
          3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              legende(bilan.nomPeriode, CouleursBilan.toileMois, CouleursBilan.encre),
              if (!bilan.avantVide) ...[
                const SizedBox(width: 22.5),
                legende(bilan.nomAvant, CouleursBilan.toileAvant, CouleursBilan.encre2),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 8

/// Records : la médaille, le nombre de records, la meilleure série de chacun.
class PageRecords extends StatelessWidget {
  const PageRecords({super.key, required this.bilan, required this.nomDe});
  final BilanMois bilan;
  final String Function(String id) nomDe;

  @override
  Widget build(BuildContext context) {
    final n = bilan.nbRecords;
    final titre = n == 0 ? 'Aucun record ${bilan.cettePeriode}' : (n == 1 ? '1 nouveau record' : '$n nouveaux records');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitreMois(bilan.titre),
        const SizedBox(height: 17.5),
        Row(
          children: [
            Ecusson.record(largeur: 54),
            const SizedBox(width: 12.5),
            Expanded(child: Text(titre, style: tb(28.75, FontWeight.w800, hauteur: 1.35))),
          ],
        ),
        const SizedBox(height: 17.5),
        Container(width: 137.5, height: 2.5, color: CouleursBilan.encre),
        const SizedBox(height: 17.5),
        if (bilan.records.isEmpty)
          Text('Le prochain n\'est pas loin.', style: tb(15, FontWeight.w600, couleur: CouleursBilan.encre2, hauteur: 1.35))
        else ...[
          Row(
            children: [
              Expanded(child: Text('Exercice', style: tb(17.5, FontWeight.w800, hauteur: 1.35))),
              Text('Meilleure série', style: tb(17.5, FontWeight.w800, hauteur: 1.35)),
            ],
          ),
          for (final (i, r) in bilan.records.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Entree(
                i,
                bilan.records.length,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(nomDe(r.exerciseId), maxLines: 1, overflow: TextOverflow.ellipsis, style: tb(15, FontWeight.w800, hauteur: 1.35)),
                    ),
                    const SizedBox(width: 12.5),
                    Text(Calculs.serieTexte(r.serie), maxLines: 1, style: tb(15, FontWeight.w600, hauteur: 1.35)),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- 9

/// Exercices favoris : un bandeau penché, puis les cinq plus pratiqués.
class PageFavoris extends StatelessWidget {
  const PageFavoris({super.key, required this.bilan, required this.exerciceDe, required this.nomDe});
  final BilanMois bilan;
  final Exercise? Function(String id) exerciceDe;
  final String Function(String id) nomDe;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Le bandeau déborde un peu de la page, comme dans la maquette.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewY(-8 * math.pi / 180),
            child: OverflowBox(
              maxWidth: double.infinity,
              fit: OverflowBoxFit.deferToChild,
              child: Container(
                color: CouleursBilan.bandeau,
                padding: const EdgeInsets.symmetric(horizontal: 17.5, vertical: 25),
                child: Text(
                  'TOP EXERCICES ${bilan.dePeriode.toUpperCase()}',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: tb(17.5, FontWeight.w800, couleur: CouleursBilan.bandeauEncre, espace: 0.35),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 17.5),
        if (bilan.favoris.isEmpty)
          Text(
            'Aucun exercice ${bilan.cettePeriode}.',
            textAlign: TextAlign.center,
            style: tb(15, FontWeight.w600, couleur: CouleursBilan.encre2, hauteur: 1.35),
          ),
        for (final (i, f) in bilan.favoris.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 11),
            child: Entree(
              i,
              bilan.favoris.length,
              child: Row(
              children: [
                SizedBox(width: 20, child: Text('${i + 1}', textAlign: TextAlign.center, style: tb(25, FontWeight.w800))),
                const SizedBox(width: 15),
                VignetteExercice(exercice: exerciceDe(f.exerciseId), taille: 67.5, fond: CouleursBilan.bandeau),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nomDe(f.exerciseId), maxLines: 1, overflow: TextOverflow.ellipsis, style: tb(17, FontWeight.w700, hauteur: 1.35)),
                      Text(Fmt.pluriel(f.series, 'série'), style: tb(13.75, FontWeight.w600, couleur: CouleursBilan.encre2, hauteur: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 10

/// Le résumé à partager : tout le mois sur une page.
class PageResume extends StatelessWidget {
  const PageResume({super.key, required this.bilan});
  final BilanMois bilan;

  Widget _bloc(String titre, String valeur, {String? unite, Widget? dessous}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titre, style: tb(16.25, FontWeight.w800, hauteur: 1.35)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: valeur,
                children: [if (unite != null) TextSpan(text: ' $unite', style: tb(20, FontWeight.w800, espace: 0))],
              ),
              maxLines: 1,
              style: tb(42.5, FontWeight.w800, hauteur: 1.05, espace: -0.85),
            ),
          ),
          if (dessous != null) Padding(padding: const EdgeInsets.only(top: 2.5), child: dessous),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconeHaltere(size: 50, color: CouleursBilan.encre, epaisseur: 1.8),
            const SizedBox(width: 12.5),
            _TitreMois(bilan.titre, taille: 31.25),
          ],
        ),
        const SizedBox(height: 17.5),
        Entree(
          0,
          4,
          child: _bloc(
            'Entraînements',
            '${bilan.nbSeances}',
            dessous: bilan.ecartSeances == null ? null : EcartBilan(ecart: bilan.ecartSeances, suite: bilan.duDernier),
          ),
        ),
        const SizedBox(height: 16),
        Entree(
          1,
          4,
          child: _bloc(
            'Volume',
            _kilos(bilan.volume),
            unite: 'kg',
            dessous: bilan.ecartVolume == null ? null : EcartBilan(ecart: bilan.ecartVolume, suite: bilan.duDernier),
          ),
        ),
        const SizedBox(height: 16),
        // Sous une heure, les minutes : « 0 heure » ne dit rien d'une séance de 49 minutes.
        Entree(
          2,
          4,
          child: bilan.heures == 0 && bilan.dureeTotale.inMinutes > 0
              ? _bloc('Temps', '${bilan.dureeTotale.inMinutes}', unite: 'min')
              : _bloc('Temps', '${bilan.heures}', unite: bilan.heures >= 2 ? 'heures' : 'heure'),
        ),
        const SizedBox(height: 16),
        Entree(
          3,
          4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _bloc('Records', '${bilan.nbRecords}')),
              Expanded(child: _bloc('Série', '${bilan.serieSemaines}', unite: 'sem.')),
            ],
          ),
        ),
      ],
    );
  }
}
