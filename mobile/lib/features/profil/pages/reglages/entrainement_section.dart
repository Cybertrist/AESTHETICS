import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../seance/logic/repos_minuteur.dart';
import '../../widgets/maquette.dart';
import '../../widgets/setting_rows.dart';

/// Réglages > Paramètres de séance : minuteur (son, volume, vibration), écran,
/// effort (RPE ou RIR), valeurs précédentes, supersets, alerte de record,
/// bouton musique, charges, barres et disques. Le repos par défaut se règle sur la page Réglages ; les séries
/// d'échauffement automatiques n'ont pas de ligne tant que la séance ne les
/// propose pas.
class EntrainementSection extends StatelessWidget {
  const EntrainementSection({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<SettingsRepo>();
    final s = repo.settings;
    final unite = context.watch<ProfileRepo>().unite;
    return PrefsBuilder(
      builder: (context, prefs, prefsRepo) {
        final barre = prefs.barre;
        final nbDisques = prefs.disques.fold(0, (a, d) => a + d.paires * 2);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GroupeTitre(
              premier: true,
              titre: 'Minuteur de repos',
              lignes: [
                LigneBascule(
                  trace: Trace.lecture,
                  titre: 'Minuteur automatique',
                  detail: 'Le repos démarre dès qu\'une série est cochée',
                  valeur: prefs.minuteurAuto,
                  onChanged: (v) => prefsRepo.update((p) => p.copyWith(minuteurAuto: v)),
                ),
                LigneBascule(
                  trace: Trace.son,
                  titre: 'Son en fin de repos',
                  valeur: s.sonMinuteur,
                  onChanged: (v) async {
                    await repo.update((x) => x.copyWith(sonMinuteur: v));
                    if (v) await Bip.charger();
                    if (v) await ReposMinuteur.instance.essayerSon(s.volumeMinuteur);
                  },
                ),
                LigneBascule(
                  trace: Trace.vibration,
                  titre: 'Vibration en fin de repos',
                  valeur: s.vibrationMinuteur,
                  onChanged: (v) async {
                    await repo.update((x) => x.copyWith(vibrationMinuteur: v));
                    if (v) await _vibrer(s.forceVibration);
                  },
                ),
                if (s.sonMinuteur)
                  LigneBascule(
                    trace: Trace.son,
                    titre: 'Décompte vocal',
                    detail: '« Five, four, three, two, one, go » à la place du son',
                    valeur: s.decompteVocal,
                    onChanged: (v) async {
                      await repo.update((x) => x.copyWith(decompteVocal: v));
                      if (v) await ReposMinuteur.instance.essayerVoix(s.volumeMinuteur);
                    },
                  ),
                if (s.sonMinuteur)
                  Ligne(
                    trace: Trace.son,
                    titre: 'Volume du son',
                    valeur: niveaux[s.volumeMinuteur.clamp(0, 2)],
                    onTap: () async {
                      final v = await _choisir(context, 'Volume du son', niveaux, s.volumeMinuteur);
                      if (v == null) return;
                      await repo.update((x) => x.copyWith(volumeMinuteur: v));
                      // On entend tout de suite le volume choisi.
                      await Bip.charger();
                      await ReposMinuteur.instance.essayerSon(v);
                    },
                  ),
                if (s.vibrationMinuteur)
                  Ligne(
                    trace: Trace.vibration,
                    titre: 'Force de la vibration',
                    valeur: forces[s.forceVibration.clamp(0, 2)],
                    onTap: () async {
                      final v = await _choisir(context, 'Force de la vibration', forces, s.forceVibration);
                      if (v == null) return;
                      await repo.update((x) => x.copyWith(forceVibration: v));
                      await _vibrer(v);
                    },
                  ),
              ],
            ),
            GroupeTitre(
              titre: 'Pendant la séance',
              lignes: [
                LigneBascule(
                  trace: Trace.ecran,
                  titre: 'Garder l\'écran allumé',
                  detail: 'Tant qu\'une séance est ouverte',
                  valeur: s.garderEcranAllume,
                  onChanged: (v) => repo.update((x) => x.copyWith(garderEcranAllume: v)),
                ),
                LigneBascule(
                  trace: Trace.jauge,
                  titre: 'Noter l\'effort',
                  detail: 'Une colonne en plus pour chaque série',
                  valeur: s.afficherRpe,
                  onChanged: (v) => repo.update((x) => x.copyWith(afficherRpe: v)),
                ),
                if (s.afficherRpe)
                  Ligne(
                    trace: Trace.jauge,
                    titre: 'RPE ou RIR',
                    valeur: s.effortRir ? 'RIR' : 'RPE',
                    onTap: () async {
                      final v = await _choisir(
                        context,
                        'RPE ou RIR',
                        const ['RPE', 'RIR'],
                        s.effortRir ? 1 : 0,
                        aides: const [
                          'L\'effort ressenti, de 6 à 10. 10 : impossible d\'en faire une de plus. 8 : il en restait deux.',
                          'Les répétitions en réserve : combien il t\'en restait avant l\'échec. 0 : aucune. 2 : il en restait deux.',
                        ],
                      );
                      if (v != null) await repo.update((x) => x.copyWith(effortRir: v == 1));
                    },
                  ),
                Ligne(
                  trace: Trace.horloge,
                  titre: 'Valeurs précédentes',
                  valeur: s.precedentMemeRoutine ? 'Même routine' : 'Toute séance',
                  onTap: () async {
                    final v = await _choisir(
                      context,
                      'Valeurs précédentes',
                      const ['N\'importe quelle séance', 'Même routine'],
                      s.precedentMemeRoutine ? 1 : 0,
                      aides: const [
                        'La colonne « Précédent » reprend la dernière fois où tu as fait l\'exercice, quelle que soit la routine.',
                        'Elle reprend seulement la dernière fois où tu l\'as fait dans la routine en cours.',
                      ],
                    );
                    if (v != null) await repo.update((x) => x.copyWith(precedentMemeRoutine: v == 1));
                  },
                ),
                LigneBascule(
                  trace: Trace.echange,
                  titre: 'Superset automatique',
                  detail: 'Ouvre l’exercice suivant après une série',
                  valeur: s.supersetAuto,
                  onChanged: (v) => repo.update((x) => x.copyWith(supersetAuto: v)),
                ),
              ],
            ),
            GroupeTitre(
              titre: 'Musique',
              lignes: [
                for (final (service, nom) in const [('spotify', 'Spotify'), ('youtube', 'YouTube Music')])
                  LigneBascule(
                    icone: LogoMusique(service, size: e(22)),
                    titre: 'Bouton $nom',
                    detail: 'Ouvre $nom depuis le haut de la séance',
                    valeur: s.musique == service,
                    onChanged: (v) => repo.update((x) => v ? x.copyWith(musique: service) : x.copyWith(sansMusique: true)),
                  ),
              ],
            ),
            GroupeTitre(
              titre: 'Notifications',
              lignes: [
                LigneBascule(
                  trace: Trace.cloche,
                  titre: 'Séance en cours',
                  detail: 'L’exercice et la série en cours, avec « Terminer la série »',
                  valeur: s.notifSeance,
                  onChanged: (v) => repo.update((x) => x.copyWith(notifSeance: v)),
                ),
                LigneBascule(
                  trace: Trace.trophee,
                  titre: 'Alerte de record',
                  detail: 'Dès qu’une série bat ta charge maximale',
                  valeur: s.alerteRecord,
                  onChanged: (v) => repo.update((x) => x.copyWith(alerteRecord: v)),
                ),
              ],
            ),
            GroupeTitre(
              titre: 'Charges',
              lignes: [
                Ligne(
                  trace: Trace.plus,
                  titre: 'Incrément de poids',
                  detail: 'Le pas des boutons + et −',
                  valeur: _poids(s.incrementPoidsKg, unite),
                  onTap: () => _increment(context, repo, unite),
                ),
                Ligne(
                  trace: Trace.haltere,
                  titre: 'Barres et disques',
                  detail: barre == null ? 'Aucune barre choisie' : '${barre.nom} · ${Fmt.pluriel(nbDisques, 'disque')}',
                  onTap: () => context.push('/reglages/entrainement/disques'),
                ),
              ],
              note: 'Les barres et les disques servent au calculateur de charge pendant la séance.',
            ),
          ],
        );
      },
    );
  }

  /// Poids avec deux décimales au besoin (« 1,25 kg »).
  static String _poids(double kg, UnitePoids u) => '${Fmt.n(Fmt.poidsAffiche(kg, u), decimals: 2)} ${u.label}';

  static Future<void> _increment(BuildContext context, SettingsRepo repo, UnitePoids unite) async {
    final choix = unite == UnitePoids.kg
        ? [0.5, 1.0, 1.25, 2.0, 2.5, 5.0]
        : [for (final lb in [1.0, 2.5, 5.0, 10.0]) Fmt.poidsStocke(lb, UnitePoids.lb)];
    final actuel = repo.settings.incrementPoidsKg;
    final v = await showPanneauBas<double>(
      context,
      titre: 'Incrément de poids',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in choix)
            ChoixPanneau(label: _poids(c, unite), selected: (c - actuel).abs() < 0.01, onTap: () => Navigator.pop(context, c)),
        ],
      ),
    );
    if (v != null) await repo.update((x) => x.copyWith(incrementPoidsKg: v));
  }

  static const niveaux = ['Faible', 'Moyen', 'Fort'];
  static const forces = ['Légère', 'Moyenne', 'Forte'];

  /// Un choix dans une liste, en panneau du bas ; rend l'indice retenu.
  /// Avec [aides], chaque choix est une carte : son nom, puis une phrase
  /// qui l'explique.
  static Future<int?> _choisir(BuildContext context, String titre, List<String> choix, int actuel, {List<String>? aides}) => showPanneauBas<int>(
        context,
        titre: titre,
        builder: (context) {
          final c = context.colors;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, nom) in choix.indexed)
                if (aides == null)
                  ChoixPanneau(label: nom, selected: i == actuel, onTap: () => Navigator.pop(context, i))
                else
                  Padding(
                    padding: EdgeInsets.only(bottom: e(7)),
                    child: Material(
                      color: c.surface2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(e(14)),
                        side: BorderSide(color: i == actuel ? c.text : c.surface2, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, i),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(e(13), e(11), e(11), e(11)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nom, style: txt(13.5, FontWeight.w700, c.text)),
                                    SizedBox(height: e(2)),
                                    Text(aides[i], style: txt(11, FontWeight.w400, c.text2, interligne: 1.4)),
                                  ],
                                ),
                              ),
                              if (i == actuel) Padding(padding: EdgeInsets.only(left: e(8)), child: IconeTrait(Trace.coche, taille: e(16), couleur: c.text)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      );

  /// Fait sentir la vibration de fin de repos, à la force choisie.
  static Future<void> _vibrer(int force) async {
    try {
      if (await Vibration.hasVibrator()) await ReposMinuteur.vibrerFin(force);
    } catch (_) {}
  }
}
