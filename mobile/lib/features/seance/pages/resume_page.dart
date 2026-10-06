import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../logic/analyse.dart';
import '../seance_paths.dart';
import '../widgets/analyse_seance.dart';
import '../widgets/bilan_blocs.dart';
import '../widgets/habillage.dart';

/// Ouvre le carrousel de partage d'une séance terminée.
Future<void> partagerSeance(BuildContext context, WorkoutSession s, List<PersonalRecord> records) async {
  await context.push(SeancePaths.partager(s.id));
}

/// Maquette « Bilan de séance » : après l'enregistrement, le volume et sa
/// comparaison avec la dernière fois, les muscles travaillés, les records
/// battus ; plus bas, ce qu'il faut viser la prochaine fois et la mise à jour
/// de la routine.
class ResumePage extends StatelessWidget {
  const ResumePage({super.key, required this.sessionId, this.nouveau = false});

  final String sessionId;

  /// Juste après l'enregistrement : « Séance enregistrée », et « Fermer »
  /// ramène à l'accueil.
  final bool nouveau;

  /// Séances dont les exercices n'étaient plus ceux de la routine.
  static final _changes = <String, bool>{};

  void _fermer(BuildContext context) {
    if (!nouveau && context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<SessionRepo>();
    final exos = context.watch<ExerciseRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final reglages = context.watch<SettingsRepo>().settings;
    final routines = context.watch<RoutineRepo>();
    final c = context.colors;
    final s = repo.byId(sessionId);
    if (s == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              EnTeteSeance(titre: 'Bilan de séance', onRetour: () => _fermer(context)),
              Expanded(
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Séance introuvable',
                  message: 'Elle a peut-être été supprimée.',
                  actionLabel: 'Voir l\'historique',
                  onAction: () => context.pushReplacement(SeancePaths.historique),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final bilan = BilanSeance.calculer(s, repo, exos);
    final routine = s.routineId == null ? null : routines.byId(s.routineId!);
    // Retenu au premier affichage : le bloc ne change pas de place une fois
    // la routine mise à jour.
    final exercicesChanges = _changes[s.id] ??= routine != null && MajRoutine.exercicesChanges(routine, s);
    final sugg = Surcharge.calculer(
      s,
      exos: exos,
      routine: routine,
      increment: reglages.incrementPoidsKg,
      unite: unite,
      avant: repo.sessions.where((x) => x.id != s.id && x.debut.isBefore(s.debut)),
    );
    final ecart = comparerAuPrecedent(s, repo.sessions);
    // Tous les records de la séance, chacun avec sa médaille.
    final records = bilan.records;
    final nb = records.length;
    // Exercices faits (échauffements exclus) et leur meilleure série.
    final faits = [
      for (final e in s.exercices)
        if (e.seriesFaites.any((x) => x.type.counts))
          (
            e.exerciseId,
            exos.nameOf(e.exerciseId),
            e.seriesFaites.where((x) => x.type.counts).length,
            () {
              final comptees = e.seriesFaites.where((x) => x.type.counts).toList()
                ..sort((a, b) {
                  final p = (b.poids ?? 0).compareTo(a.poids ?? 0);
                  return p != 0 ? p : (b.reps ?? 0).compareTo(a.reps ?? 0);
                });
              final m = comptees.first;
              if ((m.reps ?? 0) == 0 && (m.dureeSec ?? 0) > 0) return Fmt.minSec(m.dureeSec!);
              return Fmt.charge(m.poids, m.reps, unite);
            }(),
          ),
    ];
    final chiffres = <(String, String)>[
      if (s.volume > 0) (Fmt.duree(s.duree), 'durée'),
      ('${s.nbSeriesFaites}', s.nbSeriesFaites >= 2 ? 'séries' : 'série'),
      ('${faits.length}', faits.length >= 2 ? 'exercices' : 'exercice'),
      if (s.volume <= 0 && s.nbReps > 0) ('${s.nbReps}', 'répétitions'),
    ];

    return PopScope(
      canPop: !nouveau,
      onPopInvokedWithResult: (pop, _) {
        if (!pop) context.go('/');
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.only(top: k(10)),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: margeSeance, vertical: k(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Surtitre(nouveau ? 'Séance terminée' : Fmt.jour(s.debut), accent: true),
                              SizedBox(height: k(2)),
                              Text(
                                s.nom,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTokens.fontUi,
                                  fontSize: k(20),
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: c.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: margeSeance, vertical: k(10)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      // Sans charge soulevée (cardio), la durée tient lieu de chiffre : pas de « 0 kg ».
                                      s.volume > 0 ? volumeSeance(s.volume, unite) : Fmt.duree(s.duree),
                                      style: TextStyle(
                                        fontFamily: AppTokens.fontUi,
                                        fontSize: k(28),
                                        height: 1.05,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.7,
                                        color: c.text,
                                        fontFeatures: AppTokens.tabular,
                                      ),
                                    ),
                                    Text(
                                      s.volume > 0 ? 'volume soulevé' : 'durée de la séance',
                                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), height: 1.35, color: c.text2),
                                    ),
                                  ],
                                ),
                              ),
                              if (ecart != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      ecart.texte,
                                      style: TextStyle(
                                        fontFamily: AppTokens.fontUi,
                                        fontSize: k(15),
                                        height: 1.35,
                                        fontWeight: FontWeight.w700,
                                        // Hausse en vert, baisse en rouge (un écart nul n'est pas affiché).
                                        color: ecart.pourcent > 0 ? c.success : c.error,
                                        fontFeatures: AppTokens.tabular,
                                      ),
                                    ),
                                    Text(
                                      ecart.legende,
                                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(10.5), height: 1.35, color: c.text2),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (faits.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: margeSeance, vertical: k(6)),
                            child: ChiffresSeance(chiffres: chiffres),
                          ),
                        // Des exercices ont changé : le choix « garder ou mettre à
                        // jour » passe en haut, sous les chiffres.
                        if (routine != null && exercicesChanges)
                          Padding(
                            padding: EdgeInsets.fromLTRB(margeSeance, k(10), margeSeance, k(4)),
                            child: MajRoutineBloc(routine: routine, session: s, suggestions: sugg),
                          ),
                        if (bilan.intensites.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: margeSeance, vertical: k(10)),
                            child: Container(
                              padding: EdgeInsets.fromLTRB(k(10), k(10), k(10), k(6)),
                              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(k(18))),
                              alignment: Alignment.center,
                              child: BodyMapDual(intensities: bilan.intensites, highlight: c.accent, height: k(150), spacing: k(26)),
                            ),
                          ),
                        if (nb > 0)
                          Padding(
                            padding: EdgeInsets.fromLTRB(margeSeance, k(10), margeSeance, k(2)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Un seul record : il a droit à la grande carte.
                                if (nb == 1)
                                  CarteRecord(
                                    nom: exos.nameOf(records.first.exerciseId),
                                    valeur: texteRecord(records.first, unite),
                                    type: titreRecord(records.first, unite),
                                    gain: texteGainRecord(records.first, bilan.ancienne(records.first), unite),
                                    medaille: records.first.type.medaille,
                                  )
                                else ...[
                                  Surtitre('$nb records battus'),
                                  for (final r in records)
                                    Padding(
                                      padding: EdgeInsets.only(top: k(8)),
                                      child: LigneRecord(
                                        nom: exos.nameOf(r.exerciseId),
                                        type: titreRecord(r, unite),
                                        valeur: texteRecord(r, unite),
                                        gain: texteGainRecord(r, bilan.ancienne(r), unite),
                                        medaille: r.type.medaille,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        if (faits.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(margeSeance, k(18), margeSeance, k(2)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Surtitre('Exercices'),
                                for (final (id, nom, series, meilleure) in faits)
                                  Padding(
                                    padding: EdgeInsets.only(top: k(8)),
                                    child: () {
                                      final r = bilan.meilleurDe(id);
                                      return LigneExerciceBilan(
                                        nom: nom,
                                        series: series,
                                        meilleure: meilleure,
                                        // La charge maximale est déjà écrite juste au-dessus (« meilleure ») : on ne la répète pas.
                                        record: r == null ? null : (r.type == RecordType.unRmEstime ? '${r.type.label} ${texteRecord(r, unite)}' : titreRecord(r, unite)),
                                        gain: r == null ? null : texteGainRecord(r, bilan.ancienne(r), unite),
                                        medaille: r?.type.medaille ?? MedailleRecord.or,
                                      );
                                    }(),
                                  ),
                              ],
                            ),
                          ),
                        if (s.notes != null && s.notes!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(margeSeance, k(18), margeSeance, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Surtitre('Note'),
                                SizedBox(height: k(6)),
                                Text(s.notes!, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.4, color: c.text2)),
                              ],
                            ),
                          ),
                        if (sugg.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(margeSeance, k(18), margeSeance, 0),
                            child: ProchaineFois(suggestions: sugg, exos: exos),
                          ),
                        if (routine != null && exercicesChanges)
                          const SizedBox.shrink()
                        else if (routine != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(margeSeance, k(18), margeSeance, 0),
                            child: MajRoutineBloc(routine: routine, session: s, suggestions: sugg),
                          )
                        else if (nouveau && s.exercices.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(margeSeance, k(18), margeSeance, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Surtitre('Routine'),
                                SizedBox(height: k(6)),
                                Text(
                                  'Cette séance te plaît ? Garde-la en routine pour la relancer en un geste.',
                                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.4, color: c.text2),
                                ),
                                SizedBox(height: k(10)),
                                BoutonSecondaire(label: 'Enregistrer comme routine', petit: true, onPressed: () => enregistrerCommeRoutine(context, s)),
                              ],
                            ),
                          ),
                        // L'analyse vient en dernier : elle est longue, et ne doit pas
                        // repousser ce qu'il y a à faire (prochaine fois, routine).
                        Padding(
                          padding: EdgeInsets.fromLTRB(margeSeance, k(18), margeSeance, k(2)),
                          child: AnalyseSeance(session: s, exos: exos, unite: unite),
                        ),
                        SizedBox(height: k(12)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(margeSeance, k(10), margeSeance, k(18)),
                    child: Row(
                      children: [
                        Expanded(
                          child: BoutonSeance(label: 'Partager', fond: c.surface2, encre: c.text, onTap: () => context.push(SeancePaths.partager(s.id))),
                        ),
                        SizedBox(width: k(8)),
                        Expanded(child: BoutonSeance(label: 'Fermer', fond: c.bouton, encre: c.onBouton, onTap: () => _fermer(context))),
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

/// Crée une routine à partir d'une séance.
Future<void> enregistrerCommeRoutine(BuildContext context, WorkoutSession s) async {
  final nom = await showTextInputDialog(context, title: 'Nom de la routine', initial: s.nom, maxLength: 60, confirmLabel: 'Créer');
  if (nom == null || nom.trim().isEmpty || !context.mounted) return;
  final r = await context.read<RoutineRepo>().save(routineDepuisSeance(s, nom.trim()));
  if (context.mounted) Toasts.success(context, 'Routine « ${r.nom} » créée');
}
