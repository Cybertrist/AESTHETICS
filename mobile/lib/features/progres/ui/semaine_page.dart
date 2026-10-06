import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../logic/tableau.dart';
import 'communs.dart';

/// Bilan de la semaine : le volume, l'écart contre la semaine passée, le
/// corps face et dos allumé selon le volume, et les deux groupes les plus
/// travaillés.
class SemainePage extends StatelessWidget {
  const SemainePage({super.key, this.jour, this.maintenant});

  /// Un jour de la semaine voulue (aujourd'hui par défaut).
  final DateTime? jour;

  /// Date du jour, pour les tests.
  final DateTime? maintenant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions;
    final exos = context.watch<ExerciseRepo>();
    final premierJour = context.watch<SettingsRepo>().settings.premierJourSemaine;
    final now = maintenant ?? DateTime.now();
    final jour = this.jour ?? now;
    final r = Calculs.semaine(jour, sessions, exos.byId, now: now, premierJour: premierJour);
    final forme = Calculs.contreMeilleureSemaine(jour, sessions, exos.byId, premierJour: premierJour);
    final groupes = r.groupes.take(2).toList();
    final ecart = r.ecart;

    return PageProgres(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(Cotes.marge, 12, Cotes.marge, 15),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SurTitre('Bilan hebdo', couleur: c.accent),
                      const SizedBox(height: 2.5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('Résumé d\'entraînement', maxLines: 1, style: ts(19, FontWeight.w700, c.text, hauteur: 1.35)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Etiquette(Calculs.semaineLibelle(r.debut), fond: c.accentSoft, encre: c.accent),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Cotes.marge, 12.5, Cotes.marge, 12.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('${Fmt.n(r.volume, decimals: 0)} kg', maxLines: 1, style: ts(35, FontWeight.w800, c.text, hauteur: 1.05, espace: -0.7)),
                      ),
                      Text('volume total soulevé', style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
                    ],
                  ),
                ),
                if (ecart != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Calculs.signe(ecart), style: ts(19, FontWeight.w700, ecart > 0 ? c.success : c.error, hauteur: 1.35)),
                      Text(PeriodeProgres.semaine.contre, style: ts(13, FontWeight.w400, c.text2, hauteur: 1.35)),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Cotes.marge, vertical: 12.5),
              child: LayoutBuilder(builder: (context, box) {
                // 337 de haut dans la maquette ; moins si l'écran est court.
                final h = box.maxHeight.clamp(120.0, 337.0);
                return Center(child: CorpsFaceDos(intensites: r.intensites, hauteur: h, ecart: 27));
              }),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(Cotes.marge, 12.5, Cotes.marge, 22.5 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: groupes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Aucune séance cette semaine.', textAlign: TextAlign.center, style: ts(15, FontWeight.w400, c.text2)),
                  )
                : Row(
                    children: [
                      for (final (i, g) in groupes.indexed) ...[
                        if (i > 0) const SizedBox(width: Cotes.gouttiere),
                        Expanded(child: _Groupe(nom: Calculs.groupe(g.groupe), pourcentage: forme[g.groupe] ?? 100)),
                      ],
                      if (groupes.length == 1) ...[const SizedBox(width: Cotes.gouttiere), const Spacer()],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Un groupe et son volume, rapporté à sa meilleure semaine récente.
class _Groupe extends StatelessWidget {
  const _Groupe({required this.nom, required this.pourcentage});
  final String nom;
  final int pourcentage;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$nom, $pourcentage % de ta meilleure semaine',
      excludeSemantics: true,
      child: Carte(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, FontWeight.w400, c.text, hauteur: 1.35))),
                Text('$pourcentage %', style: ts(15, FontWeight.w700, c.accent, hauteur: 1.35)),
              ],
            ),
            const SizedBox(height: 10),
            BarreFine(valeur: pourcentage / 100),
          ],
        ),
      ),
    );
  }
}
