import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import 'package:go_router/go_router.dart';

import '../logic/tableau.dart';
import '../progres_paths.dart';
import 'communs.dart';

/// Statistiques du mois : séances, volume, temps, records, puis le volume
/// par semaine et la part de chaque groupe.
class MoisPage extends StatelessWidget {
  const MoisPage({super.key, this.mois, this.maintenant});

  /// Mois affiché (le mois en cours par défaut).
  final DateTime? mois;
  final DateTime? maintenant;

  /// « 112 t » au-delà de dix tonnes, « 8 420 kg » sinon.
  static String volumeCourt(double kg) => kg >= 10000 ? '${Fmt.n(kg / 1000, decimals: 0)} t' : '${Fmt.n(kg, decimals: 0)} kg';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions;
    final exos = context.watch<ExerciseRepo>();
    final now = maintenant ?? DateTime.now();
    final m = mois ?? now;
    final debut = DateTime(m.year, m.month);
    final fin = DateTime(m.year, m.month + 1);
    final avantDebut = DateTime(m.year, m.month - 1);

    final premierJour = context.watch<SettingsRepo>().settings.premierJourSemaine;
    final dans = Calculs.entre(sessions, debut, fin).toList();
    // Un mois fini se compare au mois d'avant entier ; le mois en cours aux
    // mêmes jours du mois d'avant (sinon le 2 afficherait « -93 % »).
    final enCours = !now.isBefore(debut) && now.isBefore(fin);
    final finAvant = enCours ? Calculs.memePoint(PeriodeProgres.mois, debut, avantDebut, now) : debut;
    final avant = Calculs.entre(sessions, avantDebut, finAvant).toList();
    final volume = Calculs.volumeDe(dans);
    final ecartVolume = Calculs.ecart(volume, Calculs.volumeDe(avant));
    final ecartSeances = avant.isEmpty ? 0 : dans.length - avant.length;
    final duree = dans.fold(Duration.zero, (a, s) => a + Calculs.dureeDe(s));
    final records = Calculs.records(sessions)
        .where((r) => !r.session.debut.isBefore(debut) && r.session.debut.isBefore(fin))
        .map((r) => r.exerciseId)
        .toSet()
        .length;
    final semaines = Calculs.semainesDuMois(debut, sessions, now: now, premierJour: premierJour);
    final meilleure = semaines.fold(0.0, (a, b) => math.max(a, b.volume));
    final groupes = Calculs.parGroupe(dans, exos.byId).take(5).toList();
    final partMax = groupes.isEmpty ? 0.0 : groupes.first.part;
    // En tonnes quand le mois pèse lourd, en kilos sinon.
    final tonnes = meilleure >= 1000;

    return PageProgres(
      child: ListView(
        padding: EdgeInsets.only(bottom: basDePage(context)),
        children: [
          EnTetePage(
            titre: 'Bilan du mois',
            sousTitre: enCours ? 'mois en cours' : 'mois terminé',
            droite: ecartVolume == null
                ? null
                : Etiquette(
                    // Le mois en abrégé : « vs septembre » coupait le titre.
                    '${Calculs.signe(ecartVolume)} vs ${Calculs.moisCourt(avantDebut)}',
                    // Hausse en vert, baisse en rouge (un écart nul ne s'affiche pas).
                    fond: (ecartVolume > 0 ? c.success : c.error).withValues(alpha: 0.14),
                    encre: ecartVolume > 0 ? c.success : c.error,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
            child: NavigationPeriode(
              titre: Calculs.moisAnnee(debut),
              detail: dans.isEmpty ? 'aucune séance' : Fmt.pluriel(dans.length, 'séance'),
              // On remonte tant qu'il reste une séance plus ancienne.
              avant: sessions.any((s) => !s.enCours && s.debut.isBefore(debut)) ? () => context.pushReplacement(ProgresPaths.mois(avantDebut)) : null,
              apres: enCours || debut.isAfter(now) ? null : () => context.pushReplacement(ProgresPaths.mois(fin)),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TuileChiffre(
                        valeur: '${dans.length}',
                        legende: dans.length >= 2 ? 'séances' : 'séance',
                        ecart: ecartSeances == 0 ? null : '${ecartSeances > 0 ? '+' : '-'}${ecartSeances.abs()}',
                        baisse: ecartSeances < 0,
                      ),
                    ),
                    const SizedBox(width: Cotes.gouttiere),
                    Expanded(
                      child: TuileChiffre(
                        valeur: volumeCourt(volume),
                        legende: 'volume',
                        ecart: ecartVolume == null ? null : Calculs.signe(ecartVolume),
                        baisse: (ecartVolume ?? 0) < 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Cotes.gouttiere),
                Row(
                  children: [
                    Expanded(child: TuileChiffre(valeur: duree.inMinutes == 0 ? '0 min' : Fmt.duree(duree), legende: 'temps d\'entraînement')),
                    const SizedBox(width: Cotes.gouttiere),
                    Expanded(child: TuileChiffre(valeur: '$records', legende: records >= 2 ? 'records battus' : 'record battu')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Cotes.bloc),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
            child: Carte(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: SurTitre('Volume par semaine')),
                      Text(tonnes ? 'en tonnes' : 'en kilos', style: ts(13, FontWeight.w400, c.text2, hauteur: 1.35)),
                    ],
                  ),
                  const SizedBox(height: 12.5),
                  BarresVolume(
                    hauteur: 105,
                    ecart: 12.5,
                    barres: [
                      for (final s in semaines)
                        (label: s.label, valeur: s.volume, couleur: meilleure > 0 && s.volume == meilleure ? c.accent : null),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Cotes.bloc),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
            child: Carte(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SurTitre('Répartition'),
                  if (groupes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 11),
                      child: Text('Aucune séance ce mois.', style: ts(14.5, FontWeight.w400, c.text2)),
                    ),
                  for (final g in groupes)
                    Padding(
                      padding: const EdgeInsets.only(top: 11),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 97,
                            child: Text(Calculs.groupe(g.groupe), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14.5, FontWeight.w700, c.text, hauteur: 1.35)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: BarreFine(valeur: partMax <= 0 ? 0 : g.part / partMax)),
                          const SizedBox(width: 10),
                          // Assez large pour « 100 % » sur une ligne (un seul groupe dans le mois).
                          SizedBox(
                            width: 50,
                            child: Text('${(g.part * 100).round()} %', textAlign: TextAlign.right, maxLines: 1, softWrap: false, style: ts(14.5, FontWeight.w400, c.text2, hauteur: 1.35)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
