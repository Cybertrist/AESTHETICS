import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/mensurations.dart';
import '../routes.dart';
import '../widgets/maquette.dart';

/// Une mesure : sa valeur, son écart sur la période, sa courbe et toutes
/// ses saisies, chacune modifiable.
class MesurePage extends StatefulWidget {
  const MesurePage({super.key, required this.zone});
  final ZoneMesure zone;

  @override
  State<MesurePage> createState() => _MesurePageState();
}

class _MesurePageState extends State<MesurePage> {
  PeriodeMesure _periode = PeriodeMesure.sixMois;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final z = widget.zone;
    final mesures = context.watch<HealthRepo>().measurements;
    final tout = Mensurations.serie(mesures, z);
    final serie = Mensurations.serie(mesures, z, depuis: _periode.debut(DateTime.now()));
    final ecarts = Mensurations.ecartsSuccessifs(tout);
    final ecartDe = {for (var i = 0; i < tout.length; i++) tout[i].id: ecarts[i]};
    final derniere = tout.lastOrNull;
    final ecart = serie.length < 2 ? null : Mensurations.ecart(serie.first.valeur, serie.last.valeur);

    return PageMaquette(
      titre: z.label,
      sousTitre: z.precision,
      bas: BoutonPrincipal(label: 'Ajouter une mesure', onPressed: () => context.push(ProfilPaths.saisie(zone: z))),
      enfants: [
        if (derniere == null)
          const Vide(titre: 'Aucune mesure pour l\'instant', message: 'Ajoute ta première mesure pour suivre son évolution.')
        else ...[
          Bloc(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Affichage.longueurTexte(derniere.valeur), style: txt(28, FontWeight.w800, c.text, interligne: 1.05, espacement: -0.02)),
                      Text('le ${Mensurations.jourLong(derniere.date)}', style: txt(11, FontWeight.w400, c.text2)),
                    ],
                  ),
                ),
                if (ecart != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text((Mensurations.ecartTexte(Affichage.ecartLongueur(ecart), unite: Affichage.longueur) ?? ''), style: txt(15, FontWeight.w700, ecart > 0 ? c.success : c.error)),
                      Text('depuis ${Mensurations.moisDe(serie.first.date)}', style: txt(10.5, FontWeight.w400, c.text2)),
                    ],
                  ),
              ],
            ),
          ),
          Bloc(
            haut: 4,
            bas: 4,
            child: Wrap(
              spacing: e(5),
              children: [
                for (final p in PeriodeMesure.values)
                  Puce(label: p.label, choisie: p == _periode, onTap: () => setState(() => _periode = p)),
              ],
            ),
          ),
          Bloc(child: _CarteCourbe(serie: serie, zone: z)),
          Bloc(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Surtitre('Saisies'),
                SizedBox(height: e(2)),
                if (serie.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: e(14)),
                    child: Text('Aucune saisie sur cette période.', style: txt(12, FontWeight.w400, c.text2)),
                  ),
                for (final (i, p) in serie.reversed.indexed) ...[
                  if (i > 0) Container(height: 1, color: c.line),
                  _LigneSaisie(
                    point: p,
                    ecart: ecartDe[p.id],
                    onModifier: () => context.push(ProfilPaths.saisie(id: p.id, zone: z)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CarteCourbe extends StatelessWidget {
  const _CarteCourbe({required this.serie, required this.zone});
  final List<PointMesure> serie;
  final ZoneMesure zone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (serie.isEmpty) {
      return Carte(
        padding: EdgeInsets.all(e(14)),
        child: Text('Pas de mesure sur cette période.', style: txt(12, FontWeight.w400, c.text2)),
      );
    }
    final min = serie.map((p) => p.valeur).reduce((a, b) => a < b ? a : b);
    final max = serie.map((p) => p.valeur).reduce((a, b) => a > b ? a : b);
    final t0 = serie.first.date.millisecondsSinceEpoch;
    final dt = serie.last.date.millisecondsSinceEpoch - t0;
    final points = [
      for (final p in serie)
        Offset(dt == 0 ? 1 : (p.date.millisecondsSinceEpoch - t0) / dt, max == min ? 0.5 : (p.valeur - min) / (max - min)),
    ];
    // Repères de mois : le début, la fin et deux dates intermédiaires.
    final reperes = <String>[];
    if (dt > 0) {
      final memeAnnee = serie.first.date.year == serie.last.date.year;
      for (var i = 0; i < 4; i++) {
        final d = DateTime.fromMillisecondsSinceEpoch(t0 + (dt * i / 3).round());
        final s = DateFormat(memeAnnee ? 'MMM' : 'MMM yy', 'fr_FR').format(d);
        if (reperes.isEmpty || reperes.last != s) reperes.add(s);
      }
    } else {
      reperes.add(DateFormat('MMM', 'fr_FR').format(serie.first.date));
    }
    return Carte(
      padding: EdgeInsets.fromLTRB(e(12), e(14), e(12), e(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CourbeAire(
            points: points,
            hauteur: e(64),
            pastilles: true,
            margeBas: e(10),
            label: 'Courbe du tour de ${zone.label.toLowerCase()}, de ${Affichage.lg(serie.first.valeur)} à ${Affichage.lg(serie.last.valeur)} ${Affichage.longueurNom}',
          ),
          SizedBox(height: e(4)),
          Row(
            mainAxisAlignment: reperes.length == 1 ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
            children: [for (final r in reperes) Text(r, style: txt(10, FontWeight.w400, c.text2))],
          ),
        ],
      ),
    );
  }
}

class _LigneSaisie extends StatelessWidget {
  const _LigneSaisie({required this.point, required this.ecart, required this.onModifier});
  final PointMesure point;
  final double? ecart;
  final VoidCallback onModifier;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final texte = Mensurations.ecartTexte(Affichage.ecartLongueur(ecart));
    return SizedBox(
      height: e(46) - 1,
      child: Row(
        children: [
          Expanded(child: Text(Mensurations.jourCourt(point.date), style: txt(12, FontWeight.w400, c.text2))),
          Text(Affichage.longueurTexte(point.valeur), style: txt(13, FontWeight.w700, c.text)),
          SizedBox(width: e(10)),
          SizedBox(
            width: e(34),
            // Rien quand la mesure n'a pas bougé.
            child: texte == null
                ? null
                : Text(texte, textAlign: TextAlign.right, maxLines: 1, style: txt(11.5, FontWeight.w700, ecart! > 0 ? c.success : c.error)),
          ),
          SizedBox(width: e(10)),
          Semantics(
            button: true,
            label: 'Modifier la mesure du ${Mensurations.jourLong(point.date)}',
            excludeSemantics: true,
            child: InkResponse(
              onTap: onModifier,
              radius: e(22),
              child: SizedBox.square(
                dimension: e(44),
                child: Center(child: IconeTrait(Trace.crayon, taille: e(16), couleur: c.text2, epaisseur: 1.8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
