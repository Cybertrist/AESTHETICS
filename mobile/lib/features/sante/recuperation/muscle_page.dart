import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../../progres/ui/communs.dart';
import '../common/sante_calculs.dart';

/// Détail d'un muscle : récupération, dernière séance, volume sur 7 jours.
class MusclePage extends StatelessWidget {
  const MusclePage({super.key, required this.muscle});
  final Muscle muscle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions;
    final exos = context.watch<ExerciseRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final e = RecupCalc.calculer(sessions, exos.byId)[muscle]!;
    final derniere = e.derniere;
    final suggestions = exos
        .search(muscles: {muscle}, principauxSeulement: true)
        .where((x) => !x.perso)
        .take(40)
        .toList()
      ..sort((a, b) => (a.mecanique == 'polyarticulaire' ? 0 : 1).compareTo(b.mecanique == 'polyarticulaire' ? 0 : 1));
    final texte = ts(14, FontWeight.w400, c.text2, hauteur: 1.4);
    // Vert s'il est prêt, orange sinon, comme les vignettes de la récupération.
    final couleur = e.pret ? c.success : AppTokens.orange;

    final corps = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        children: [
          muscle.side == MuscleSide.lesDeux
              ? CorpsFaceDos(intensites: {muscle: 1}, hauteur: 250, ecart: 16)
              : BodyMap(view: muscle.side == MuscleSide.dos ? BodyView.back : BodyView.front, intensities: {muscle: 1}, height: 250),
          const SizedBox(height: 10),
          Text('${muscle.region.label} · ${muscle.side == MuscleSide.dos ? 'vue de dos' : (muscle.side == MuscleSide.face ? 'vue de face' : 'face et dos')}', style: texte),
        ],
      ),
    );

    final etat = Carte(
      padding: const EdgeInsets.all(17.5),
      child: Row(
        children: [
          AnneauRecup(pourcentage: e.pourcentage, taille: 92, couleur: couleur),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SurTitre('Récupération'),
                const SizedBox(height: 4),
                Text(RecupCalc.pretDans(e.heuresAvantPret), style: ts(17, FontWeight.w700, c.text, hauteur: 1.3)),
                const SizedBox(height: 4),
                Text(
                  e.pret
                      ? (derniere == null ? 'Jamais travaillé dans l\'appli.' : 'Tu peux le travailler à pleine intensité.')
                      : 'Récupéré à 80 % dans ${Fmt.pluriel(e.heuresAvantPret, 'heure')}. Un travail léger reste possible.',
                  style: texte,
                ),
                const SizedBox(height: 6),
                Text('Temps de récupération type : ${Recovery.heuresRecuperation(muscle).round()} h', style: texte),
              ],
            ),
          ),
        ],
      ),
    );

    final semaine = Row(
      children: [
        Expanded(child: TuileTrois(valeur: Fmt.n(e.series7j), legende: 'séries, 7 jours')),
        const SizedBox(width: 7.5),
        Expanded(child: TuileTrois(valeur: Fmt.volume(e.volume7j, unite), legende: 'volume')),
        const SizedBox(width: 7.5),
        Expanded(child: TuileTrois(valeur: '${e.seances7j}', legende: e.seances7j >= 2 ? 'séances' : 'séance')),
      ],
    );

    final blocs = [
      corps,
      etat,
      semaine,
      CarteListe(
        titre: 'Dernière séance',
        lignes: [
          if (derniere == null)
            const LigneListe(filet: false, titre: 'Aucune séance', sousTitre: 'Ce muscle n\'a pas encore été travaillé.')
          else
            LigneListe(
              filet: false,
              gauche: PastilleTypeSeance(derniere.type),
              titre: derniere.nom,
              sousTitre: '${Fmt.jourCap(derniere.debut)} · ${Fmt.ilYa(derniere.fin ?? derniere.debut)}',
              onTap: () => context.push('/seance/historique/${derniere.id}'),
            ),
        ],
      ),
      if (e.exercices7j.isNotEmpty)
        CarteListe(
          titre: 'Exercices de la semaine',
          lignes: [
            for (final (i, x) in (e.exercices7j.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).indexed)
              LigneListe(
                filet: i > 0,
                gauche: VignetteExercice(exercice: exos.byId(x.key), taille: 48),
                titre: exos.nameOf(x.key),
                valeur: Fmt.pluriel(x.value, 'série'),
                onTap: () => context.push('/entrainer/exercices/${Uri.encodeComponent(x.key)}'),
              ),
          ],
        ),
      if (suggestions.isNotEmpty)
        CarteListe(
          titre: 'Pour le travailler',
          lignes: [
            for (final (i, x) in suggestions.take(5).indexed)
              LigneListe(
                filet: i > 0,
                gauche: VignetteExercice(exercice: x, taille: 48),
                titre: x.nom,
                sousTitre: '${x.equipementLabel}${x.mecanique == null ? '' : ' · ${x.mecanique}'}',
                onTap: () => context.push('/entrainer/exercices/${Uri.encodeComponent(x.id)}'),
              ),
          ],
        ),
    ];

    return PageProgres(
      child: ListView(
        padding: EdgeInsets.only(bottom: basDePage(context)),
        children: [
          EnTetePage(titre: muscle.label, sousTitre: '${e.pourcentage} % récupéré'),
          const SizedBox(height: 8),
          for (final (k, bloc) in blocs.indexed)
            Padding(padding: EdgeInsets.fromLTRB(Cotes.marge, k == 0 ? 0 : Cotes.gouttiere, Cotes.marge, 0), child: bloc),
        ],
      ),
    );
  }
}
