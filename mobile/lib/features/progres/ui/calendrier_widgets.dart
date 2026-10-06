import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/progres_stats.dart';
import 'communs.dart';

/// Couleur d'un niveau d'intensité (0 = vide, 4 = plein).
Color couleurNiveau(BuildContext context, int niveau) {
  final a = context.colors.accent;
  return switch (niveau) {
    0 => AppTokens.veil2,
    1 => a.withValues(alpha: 0.28),
    2 => a.withValues(alpha: 0.5),
    3 => a.withValues(alpha: 0.75),
    _ => a,
  };
}

/// Grille de contributions : une colonne par semaine, une ligne par jour,
/// la case teintée d'accent selon les séries du jour.
class GrilleContributions extends StatelessWidget {
  const GrilleContributions({
    super.key,
    required this.jours,
    required this.debut,
    required this.fin,
    required this.niveau,
    this.cell = 13,
    this.gap = 3,
    this.onTapJour,
    this.controller,
    this.etiquettesJours = true,
  });

  /// Séries par jour (clé = minuit).
  final Map<DateTime, double> jours;
  final DateTime debut;

  /// Dernier jour inclus.
  final DateTime fin;
  final int Function(double) niveau;
  final double cell;
  final double gap;
  final ValueChanged<DateTime>? onTapJour;
  final ScrollController? controller;
  final bool etiquettesJours;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lundi = Dates.debutSemaine(debut);
    final aujourdhui = Dates.jour(DateTime.now());
    final semaines = <DateTime>[];
    for (var s = lundi; !s.isAfter(fin); s = DateTime(s.year, s.month, s.day + 7)) {
      semaines.add(s);
    }
    final style = TextStyle(fontFamily: AppTokens.fontUi, fontSize: 10, fontWeight: FontWeight.w600, color: c.text3);

    Widget colonne(DateTime s, int index) {
      // Nom du mois au-dessus de la première semaine qui le contient.
      final premierDuMois = [for (var i = 0; i < 7; i++) DateTime(s.year, s.month, s.day + i)].firstWhere(
        (d) => d.day == 1,
        orElse: () => DateTime(0),
      );
      final etiquette = index == 0 ? ProgresStats.moisCourt(s.day > 24 ? DateTime(s.year, s.month + 1) : s) : (premierDuMois.year == 0 ? null : ProgresStats.moisCourt(premierDuMois));
      return Padding(
        padding: EdgeInsets.only(right: gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 16,
              width: cell,
              child: OverflowBox(
                maxWidth: 60,
                alignment: Alignment.centerLeft,
                child: etiquette == null ? null : Text(etiquette, style: style),
              ),
            ),
            for (var i = 0; i < 7; i++)
              Builder(builder: (context) {
                final d = DateTime(s.year, s.month, s.day + i);
                final dehors = d.isBefore(Dates.jour(debut)) || d.isAfter(fin);
                final v = jours[d] ?? 0;
                final n = niveau(v);
                final estAujourdhui = Dates.memeJour(d, aujourdhui);
                final boite = Container(
                  width: cell,
                  height: cell,
                  margin: EdgeInsets.only(bottom: gap),
                  decoration: BoxDecoration(
                    color: dehors ? Colors.transparent : couleurNiveau(context, n),
                    borderRadius: BorderRadius.circular(cell * 0.28),
                    border: estAujourdhui ? Border.all(color: c.text2, width: 1.2) : null,
                  ),
                );
                if (dehors) return boite;
                return Tooltip(
                  message: v > 0 ? '${Fmt.jourCap(d)} : ${Fmt.pluriel(v.round(), 'série')}' : '${Fmt.jourCap(d)} : repos',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapJour == null ? null : () => onTapJour!(d),
                    child: boite,
                  ),
                );
              }),
          ],
        ),
      );
    }

    final grille = SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (var i = 0; i < semaines.length; i++) colonne(semaines[i], i)],
      ),
    );
    if (!etiquettesJours) return grille;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, right: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 7; i++)
                SizedBox(
                  height: cell + gap,
                  child: Text(i.isEven && i < 6 ? const ['Lun', '', 'Mer', '', 'Ven', '', ''][i] : '', style: style),
                ),
            ],
          ),
        ),
        Expanded(child: grille),
      ],
    );
  }
}

/// Légende « Moins ▢▢▢▢▢ Plus ».
class LegendeNiveaux extends StatelessWidget {
  const LegendeNiveaux({super.key, this.cell = 11});
  final double cell;

  @override
  Widget build(BuildContext context) {
    final style = AppType.rowSubtitle();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Moins', style: style),
        const SizedBox(width: 6),
        for (var n = 0; n <= 4; n++)
          Container(
            width: cell,
            height: cell,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(color: couleurNiveau(context, n), borderRadius: BorderRadius.circular(cell * 0.28)),
          ),
        const SizedBox(width: 3),
        Text('Plus', style: style),
      ],
    );
  }
}

/// Ligne d'une séance : la pastille de son type, nom, date, durée, volume.
/// Ouvre son résumé. Une séance sans charge (cardio) n'affiche pas « 0 kg ».
class LigneSeance extends StatelessWidget {
  const LigneSeance({super.key, required this.session, this.onTap, this.dateComplete = false, this.filet = true});

  final WorkoutSession session;
  final VoidCallback? onTap;
  final bool dateComplete;
  final bool filet;

  @override
  Widget build(BuildContext context) {
    final u = context.watch<ProfileRepo>().unite;
    final s = session;
    final quand = dateComplete ? '${Fmt.jourMois(s.debut)} ${s.debut.year}' : Fmt.relatif(s.debut);
    final duree = s.fin == null ? '' : ' · ${Fmt.duree(s.duree)}';
    return LigneListe(
      filet: filet,
      gauche: PastilleTypeSeance(s.type),
      titre: s.nom,
      sousTitre: '$quand · ${Fmt.heure(s.debut)}$duree',
      valeur: s.volume > 0 ? Fmt.volume(s.volume, u) : null,
      onTap: onTap ?? () => ouvrirSeance(context, s.id),
    );
  }
}

/// Ouvre le résumé d'une séance dans le module Progrès.
void ouvrirSeance(BuildContext context, String id) => context.push('/progres/seance/$id');

/// Panneau du bas listant des séances (un jour, une semaine, une période).
Future<void> showSeancesDialog(BuildContext context, {required String titre, required List<WorkoutSession> seances, String? vide}) {
  return showPanneauBas<void>(
    context,
    titre: titre,
    builder: (panneau) {
      final c = panneau.colors;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            seances.isEmpty ? (vide ?? 'Aucune séance enregistrée.') : Fmt.pluriel(seances.length, 'séance'),
            textAlign: TextAlign.center,
            style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35),
          ),
          const SizedBox(height: 6),
          for (final (i, s) in seances.indexed)
            LigneSeance(
              session: s,
              dateComplete: true,
              filet: i > 0,
              onTap: () {
                Navigator.of(panneau).pop();
                ouvrirSeance(context, s.id);
              },
            ),
        ],
      );
    },
  );
}
