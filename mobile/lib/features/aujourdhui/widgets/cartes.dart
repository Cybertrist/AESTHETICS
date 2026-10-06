
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/pas_repo.dart';
import '../logic/resume_jour.dart';
import '../routes.dart';
import 'actions.dart';
import 'commun.dart';

/// Phrase du coach du jour.
class CarteCoach extends StatelessWidget {
  const CarteCoach({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileRepo>().profile;
    final phrase = phraseDuJour(
      prenom: profile?.prenom ?? '',
      coach: context.watch<CoachRepo>(),
      sessions: context.watch<SessionRepo>(),
      health: context.watch<HealthRepo>(),
      nutrition: context.watch<NutritionRepo>(),
      objectifs: NutritionCalc.effectifs(profile),
    );
    final c = context.colors;
    return AppCard(
      onTap: () => context.go(Paths.coach),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconHalo.domain(AppDomain.coach),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phrase.titre.toUpperCase(), style: AppType.overline()),
                const SizedBox(height: 6),
                Text(
                  phrase.texte,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: c.text),
                ),
                const SizedBox(height: 8),
                Text('Parler au coach ›', style: AppType.rowSubtitle(color: c.coach).copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Récupération muscle par muscle.
class CarteRecuperation extends StatelessWidget {
  const CarteRecuperation({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionRepo>();
    final ex = context.watch<ExerciseRepo>();
    final c = context.colors;
    final fatigue = Recovery.fatigue(sessions.sessions.take(30), ex.byId);
    final prets = Recovery.prets(fatigue).length;
    final enRecup = fatigue.entries.where((e) => e.value > 0.2).sortedBy<num>((e) => -e.value).toList();
    return AppCard(
      label: 'Récupération',
      labelTrailing: const ChevronCarte(),
      onTap: () => context.push(AujourdhuiPaths.recuperation),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: CorpsDouble(intensities: fatigue, height: 172, spacing: 2)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BigNumber(value: '$prets', unit: 'sur ${Muscle.values.length}', size: 36, label: 'Muscles prêts'),
                const SizedBox(height: 12),
                if (enRecup.isEmpty)
                  Text(
                    sessions.sessions.isEmpty
                        ? 'Tout est reposé. Tes séances feront apparaître ici les muscles à laisser souffler.'
                        : 'Tout est reposé, tu peux t\'entraîner sans compter.',
                    style: AppType.rowSubtitle(),
                  )
                else ...[
                  Text('EN RÉCUPÉRATION', style: AppType.overline()),
                  const SizedBox(height: 8),
                  for (final e in enRecup.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ProgressBar(
                        value: 1 - e.value,
                        label: e.key.label,
                        trailing: '${((1 - e.value) * 100).round()} %',
                        color: c.muscle,
                        height: 5,
                      ),
                    ),
                  if (enRecup.length > 3)
                    Text('et ${Fmt.pluriel(enRecup.length - 3, 'autre')}', style: AppType.rowSubtitle()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nutrition du jour : calories restantes, macros, eau.
class CarteNutrition extends StatelessWidget {
  const CarteNutrition({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NutritionRepo>();
    final goals = NutritionCalc.effectifs(context.watch<ProfileRepo>().profile);
    final now = DateTime.now();
    final tot = n.totalsFor(now);
    final vide = n.entriesFor(now).isEmpty;
    final reste = goals.kcal - tot.kcal;
    final eau = n.waterFor(now);
    final c = context.colors;
    Widget macro(String nom, double v, double obj, Color col) => Expanded(
          child: Column(
            children: [
              ProgressRing(
                value: obj <= 0 ? 0 : v / obj,
                size: 62,
                stroke: 7,
                color: col,
                center: Text(Fmt.n(v, decimals: 0), style: AppType.number(15)),
              ),
              const SizedBox(height: 6),
              Text(nom, style: AppType.rowSubtitle(color: c.text2).copyWith(fontWeight: FontWeight.w700)),
              Text('sur ${Fmt.n(obj, decimals: 0)} g', style: AppType.rowSubtitle().copyWith(fontSize: 11)),
            ],
          ),
        );
    return AppCard(
      label: 'Nutrition',
      labelTrailing: const ChevronCarte(),
      onTap: () => context.push(AujourdhuiPaths.nutrition),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigNumber(
            value: Fmt.n(reste.abs(), decimals: 0),
            unit: 'kcal',
            label: reste >= 0 ? 'Restantes aujourd\'hui' : 'Au-dessus de l\'objectif',
            color: reste >= 0 ? null : c.warning,
            caption: vide ? 'Rien noté aujourd\'hui, objectif ${Fmt.kcal(goals.kcal)}' : '${Fmt.kcal(tot.kcal)} consommées sur ${Fmt.kcal(goals.kcal)}',
          ),
          const SizedBox(height: 10),
          ProgressBar(value: goals.kcal <= 0 ? 0 : tot.kcal / goals.kcal, color: c.nutrition),
          const SizedBox(height: 16),
          Row(
            children: [
              macro('Protéines', tot.proteines, goals.proteinesG, CouleursMacros.proteines(context)),
              macro('Glucides', tot.glucides, goals.glucidesG, CouleursMacros.glucides(context)),
              macro('Lipides', tot.lipides, goals.lipidesG, CouleursMacros.lipides(context)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconHalo(icon: Icons.water_drop_rounded, color: CouleursMacros.eau(context), size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: ProgressBar(
                  value: goals.eauMl <= 0 ? 0 : eau / goals.eauMl,
                  label: 'Eau',
                  trailing: '${Fmt.n(eau / 1000, decimals: 2)} / ${Fmt.n(goals.eauMl / 1000, decimals: 1)} L',
                  color: CouleursMacros.eau(context),
                ),
              ),
              const SizedBox(width: 12),
              RoundIconButton(
                icon: Icons.add_rounded,
                size: 38,
                filled: false,
                tooltip: 'Ajouter 250 ml',
                onPressed: () => ajouterEau(context, 250),
              ),
            ],
          ),
          if (vide) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: PillButton.link(label: 'Noter un repas', icon: Icons.restaurant_rounded, onPressed: () => context.go(Paths.nutrition)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Petite carte de santé (sommeil, pas, poids).
class _MiniCarte extends StatelessWidget {
  const _MiniCarte({
    required this.label,
    required this.domaine,
    required this.valeur,
    this.icone,
    this.unite,
    this.legende,
    this.bas,
    this.onTap,
    this.action,
  });

  final String label;
  final Color domaine;
  final IconData? icone;
  final String valeur;
  final String? unite;
  final String? legende;
  final Widget? bas;
  final VoidCallback? onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconHalo(icon: icone ?? Icons.circle, color: domaine, size: 34),
              const Spacer(),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.overline()),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(valeur, style: AppType.number(28)),
                if (unite != null) ...[
                  const SizedBox(width: 4),
                  Text(unite!, style: AppType.rowSubtitle(color: context.colors.text2).copyWith(fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          if (legende != null) ...[
            const SizedBox(height: 2),
            Text(legende!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle()),
          ],
          if (bas != null) ...[const SizedBox(height: 10), bas!],
        ],
      ),
    );
  }
}

class CarteSommeil extends StatelessWidget {
  const CarteSommeil({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HealthRepo>();
    final c = context.colors;
    final nuit = h.sleepFor(DateTime.now());
    final moy = h.averageSleep();
    return _MiniCarte(
      label: 'Sommeil',
      domaine: c.sleep,
      icone: Icons.bedtime_rounded,
      valeur: nuit == null ? '-' : Fmt.sommeil(nuit.duree),
      legende: nuit == null ? 'Pas encore notée' : '${Fmt.heure(nuit.coucher)} à ${Fmt.heure(nuit.lever)}',
      onTap: () => context.push(AujourdhuiPaths.sommeil),
      action: nuit == null
          ? RoundIconButton(icon: Icons.add_rounded, size: 32, filled: false, tooltip: 'Noter ma nuit', onPressed: () => saisirSommeil(context))
          : null,
      bas: ProgressBar(
        value: nuit == null ? 0 : nuit.duree.inMinutes / 480,
        color: c.sleep,
        height: 5,
        trailing: moy == null ? null : 'Moy. ${Fmt.sommeil(moy)}',
      ),
    );
  }
}

class CartePas extends StatelessWidget {
  const CartePas({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = PasRepo.pour(context.read<Store>());
    final c = context.colors;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final pas = repo.pas(DateTime.now());
        return _MiniCarte(
          label: 'Pas',
          domaine: c.heart,
          icone: Icons.directions_walk_rounded,
          valeur: !repo.charge ? '…' : (pas == null ? '-' : Fmt.n(pas, decimals: 0)),
          legende: pas == null ? 'Rien aujourd\'hui' : 'Objectif ${Fmt.n(repo.objectif, decimals: 0)}',
          onTap: () => context.push(AujourdhuiPaths.pas),
          action: repo.synchronisation
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.heart))
              : RoundIconButton(icon: Icons.edit_rounded, size: 32, filled: false, tooltip: 'Saisir mes pas', onPressed: () => saisirPas(context)),
          bas: ProgressBar(value: pas == null ? 0 : pas / repo.objectif, color: c.heart, height: 5),
        );
      },
    );
  }
}

class CartePoids extends StatelessWidget {
  const CartePoids({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HealthRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final last = h.latestWeightEntry;
    final serie = h.weightSeries(since: DateTime.now().subtract(const Duration(days: 30)));
    String? legende;
    if (last == null) {
      legende = 'Aucune pesée';
    } else if (serie.length >= 2) {
      final d = serie.last.kg - serie.first.kg;
      legende = '${d >= 0 ? '+' : '-'}${Fmt.poids(d.abs(), u)} en 30 jours';
    } else {
      legende = Fmt.relatif(last.date);
    }
    return _MiniCarte(
      label: 'Poids',
      domaine: c.weight,
      icone: Icons.monitor_weight_rounded,
      valeur: last == null ? '-' : Fmt.n(Fmt.poidsAffiche(last.poidsKg!, u)),
      unite: last == null ? null : u.label,
      legende: legende,
      onTap: () => context.push(AujourdhuiPaths.poids),
      action: RoundIconButton(icon: Icons.add_rounded, size: 32, filled: false, tooltip: 'Me peser', onPressed: () => saisirPoids(context)),
      bas: serie.length >= 2
          ? MiniSparkline(values: [for (final p in serie) p.kg], height: 22, color: c.weight)
          : ProgressBar(value: 0, color: c.weight, height: 5),
    );
  }
}

/// Sommeil, pas et poids : trois colonnes si la place le permet, sinon deux
/// puis le poids en pleine largeur.
class GrilleSante extends StatelessWidget {
  const GrilleSante({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const gap = 12.0;
      if (box.maxWidth >= 520) {
        return const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: CarteSommeil()),
              SizedBox(width: gap),
              Expanded(child: CartePas()),
              SizedBox(width: gap),
              Expanded(child: CartePoids()),
            ],
          ),
        );
      }
      return const Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: CarteSommeil()),
                SizedBox(width: gap),
                Expanded(child: CartePas()),
              ],
            ),
          ),
          SizedBox(height: gap),
          CartePoids(),
        ],
      );
    });
  }
}

/// Rangée des jours de la semaine : passe par le composant partagé
/// `SemaineJours` (jour fait = contour blanc et icône du type de séance,
/// aujourd'hui = disque blanc).
class JoursSemaine extends StatelessWidget {
  const JoursSemaine({super.key, required this.resume, this.onJour});

  final ResumeSemaine resume;
  final ValueChanged<DateTime>? onJour;

  @override
  Widget build(BuildContext context) => SemaineJours(
        jours: resume.jours,
        seance: (j) => resume.seances.firstWhereOrNull((s) => Dates.memeJour(s.debut, j))?.type,
        onJour: onJour,
      );
}

/// Garde un record par exercice et par séance (charge max d'abord).
List<RecordBattu> recordsPrincipaux(List<RecordBattu> all) {
  const ordre = [RecordType.poidsMax, RecordType.unRmEstime, RecordType.repsMax, RecordType.volumeSeance, RecordType.volumeSerie];
  final vus = <String, RecordBattu>{};
  for (final r in all) {
    final k = '${r.session.id}|${r.record.exerciseId}';
    final prev = vus[k];
    if (prev == null || ordre.indexOf(r.record.type) < ordre.indexOf(prev.record.type)) vus[k] = r;
  }
  return all.where((r) => identical(vus['${r.session.id}|${r.record.exerciseId}'], r)).toList();
}

