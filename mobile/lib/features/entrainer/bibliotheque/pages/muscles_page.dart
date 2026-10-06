import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../commun/corps_colore.dart';
import '../../commun/elements.dart';
import '../logic/exercise_index.dart';
import 'exercise_browser.dart';
import 'exercise_detail_page.dart';

/// Muscles dans l'ordre de la rangée à choisir.
const musclesExplorateur = <Muscle>[
  Muscle.biceps,
  Muscle.avantBras,
  Muscle.triceps,
  Muscle.pectoraux,
  Muscle.deltoidesAnterieurs,
  Muscle.deltoidesLateraux,
  Muscle.deltoidesPosterieurs,
  Muscle.trapezes,
  Muscle.grandDorsal,
  Muscle.rhomboides,
  Muscle.lombaires,
  Muscle.abdominaux,
  Muscle.obliques,
  Muscle.fessiers,
  Muscle.quadriceps,
  Muscle.ischios,
  Muscle.adducteurs,
  Muscle.abducteurs,
  Muscle.mollets,
  Muscle.cou,
];

/// Chiffres d'un muscle : séries de la semaine, dernier travail, récupération.
class ChiffresMuscle {
  const ChiffresMuscle({required this.seriesSemaine, required this.dernier, required this.recuperation});

  /// Séries effectives depuis lundi (1 en muscle principal, 0,5 en secondaire).
  final double seriesSemaine;

  /// Dernière séance où le muscle a été le muscle principal d'un exercice.
  final DateTime? dernier;

  /// Pourcentage récupéré, de 0 à 100.
  final int recuperation;
}

ChiffresMuscle chiffresDuMuscle(Muscle m, {required List<WorkoutSession> seances, required Exercise? Function(String) lookup, DateTime? maintenant}) {
  final n = maintenant ?? DateTime.now();
  final lundi = Dates.debutSemaine(n);
  final semaine = seances.where((s) => !s.debut.isBefore(lundi) && s.debut.isBefore(lundi.add(const Duration(days: 7))));
  final series = Strength.setsParMuscle(semaine, lookup)[m] ?? 0;
  DateTime? dernier;
  for (final s in seances) {
    if (s.debut.isAfter(n)) continue;
    final touche = s.exercices.any((e) => e.seriesFaites.isNotEmpty && (lookup(e.exerciseId)?.musclesPrincipaux.contains(m) ?? false));
    if (touche && (dernier == null || s.debut.isAfter(dernier))) dernier = s.debut;
  }
  final recup = Recovery.pourcentages(Recovery.fatigue(seances, lookup, now: n))[m] ?? 100;
  return ChiffresMuscle(seriesSemaine: series, dernier: dernier, recuperation: recup);
}

/// Explorateur de muscles : le corps face et dos, le muscle choisi allumé,
/// ses chiffres et ses exercices dessous.
class MusclesPage extends StatefulWidget {
  const MusclesPage({super.key, this.initial});

  /// Muscle de départ (`?muscle=biceps`).
  final Muscle? initial;

  @override
  State<MusclesPage> createState() => _MusclesPageState();
}

class _MusclesPageState extends State<MusclesPage> {
  late Muscle _muscle = widget.initial ?? Muscle.biceps;
  final _cles = {for (final m in Muscle.values) m: GlobalKey()};

  void _choisir(Muscle m) {
    if (m == _muscle) return;
    setState(() => _muscle = m);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cles[m]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.3, duration: AppTokens.normal, curve: Curves.easeOut);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cles[_muscle]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<ExerciseRepo>();
    final sessions = context.watch<SessionRepo>();
    final m = _muscle;
    final freq = frequencesExercices(sessions.sessions);
    // À égalité, l'ordre alphabétique sans accents (« Écarté » avec les E).
    final cles = <String, String>{};
    String cle(Exercise e) => cles[e.id] ??= TextSearch.normalize(e.nom);
    final exercices = repo.all.where((e) => e.musclesPrincipaux.contains(m)).toList()
      ..sort((a, b) {
        final d = (freq[b.id] ?? 0).compareTo(freq[a.id] ?? 0);
        return d != 0 ? d : cle(a).compareTo(cle(b));
      });
    final chiffres = chiffresDuMuscle(m, seances: sessions.sessions, lookup: repo.byId);

    Widget chiffre(String valeur, String label) => Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.fromLTRB(12.5, 10, 10, 10),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(15)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    valeur,
                    maxLines: 1,
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 19, height: 1.35, fontWeight: FontWeight.w700, color: c.text, fontFeatures: AppTokens.tabular),
                  ),
                ),
                Text(label, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 12.5, height: 1.35, color: c.text2)),
              ],
            ),
          ),
        );

    final entete = Padding(
      padding: const EdgeInsets.fromLTRB(margeEcran, 12.5, margeEcran, 0),
      child: Row(
        children: [
          Expanded(child: Text('Muscles', style: TexteEntrainer.titreOnglet(context))),
          Text('Touche un muscle', style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.75, color: c.text2)),
        ],
      ),
    );

    final rangee = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(margeEcran, 10, margeEcran, 12.5),
      child: Row(
        children: [
          for (final x in musclesExplorateur)
            Padding(
              key: _cles[x],
              padding: const EdgeInsets.only(right: 6),
              child: Semantics(
                button: true,
                selected: x == m,
                child: GestureDetector(
                  onTap: () => _choisir(x),
                  child: Pastille(x.label, ton: x == m ? TonPastille.musclePlein : TonPastille.neutre),
                ),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: TexteNet(
        child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: largeurContenu),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                entete,
                rangee,
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(margeEcran, 12.5, margeEcran, 0),
                        sliver: SliverList.list(
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(12.5, 20, 12.5, 15),
                              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(22.5)),
                              child: CorpsFaceDos(couleurs: {m: Teinte.principal}, hauteur: 245, ecart: 35, onTap: _choisir),
                            ),
                            const SizedBox(height: 25),
                            Row(
                              children: [
                                Container(width: 12.5, height: 12.5, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                                const SizedBox(width: 12.5),
                                Expanded(child: Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.titreSection(context))),
                                Text(
                                  Fmt.pluriel(exercices.length, 'exercice'),
                                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.75, color: c.text2, fontFeatures: AppTokens.tabular),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  chiffre('${chiffres.seriesSemaine.round()}', chiffres.seriesSemaine.round() > 1 ? 'séries cette sem.' : 'série cette sem.'),
                                  const SizedBox(width: 7.5),
                                  chiffre(chiffres.dernier == null ? 'Jamais' : Fmt.relatif(chiffres.dernier!), 'dernier travail'),
                                  const SizedBox(width: 7.5),
                                  chiffre('${chiffres.recuperation} %', 'récupéré'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 28),
                        sliver: SliverList.builder(
                          itemCount: exercices.length,
                          itemBuilder: (context, i) {
                            final e = exercices[i];
                            final niveau = switch (e.niveau) { 'debutant' => 'Débutant', 'intermediaire' => 'Intermédiaire', 'avance' => 'Avancé', _ => null };
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: LigneExercice(
                                exercise: e,
                                carte: true,
                                sousTitre: [e.equipementLabel, ?niveau].join(' · '),
                                onTap: () => ouvrirFicheExercice(context, e.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
