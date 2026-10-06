import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../seance/seance_paths.dart';
import '../logic/tableau.dart';
import 'communs.dart';

/// Calendrier d'entraînement : le mois avec les mêmes repères de jour que
/// l'accueil, la série de semaines, et le détail du jour touché.
class CalendrierPage extends StatefulWidget {
  const CalendrierPage({super.key, this.mois, this.jour, this.maintenant});

  /// Mois ouvert (le mois en cours par défaut).
  final DateTime? mois;

  /// Jour choisi à l'ouverture.
  final DateTime? jour;
  final DateTime? maintenant;

  @override
  State<CalendrierPage> createState() => _CalendrierPageState();
}

class _CalendrierPageState extends State<CalendrierPage> {
  late DateTime _mois;
  DateTime? _jour;

  DateTime get _now => widget.maintenant ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _ouvrir();
  }

  @override
  void didUpdateWidget(CalendrierPage old) {
    super.didUpdateWidget(old);
    // La même page rouverte sur un autre mois ou un autre jour.
    if (old.mois != widget.mois || old.jour != widget.jour) _ouvrir();
  }

  void _ouvrir() {
    final m = widget.mois ?? widget.jour ?? _now;
    final enCours = DateTime(_now.year, _now.month);
    // Une adresse sur un mois à venir ouvre le mois en cours : le calendrier
    // ne va pas plus loin (ni flèche ni glissement n'y mènent).
    _mois = DateTime(m.year, m.month).isAfter(enCours) ? enCours : DateTime(m.year, m.month);
    _jour = widget.jour == null ? null : Dates.jour(widget.jour!);
  }

  void _changer(int pas) {
    final m = DateTime(_mois.year, _mois.month + pas);
    if (m.isAfter(DateTime(_now.year, _now.month))) return;
    setState(() {
      _mois = m;
      _jour = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions;
    final exos = context.watch<ExerciseRepo>();
    final now = _now;
    final premierJour = context.watch<SettingsRepo>().settings.premierJourSemaine;
    final serie = Calculs.serieSemaines(sessions, a: now, premierJour: premierJour);
    final types = Calculs.typesParJour(sessions);
    final duMois = Calculs.entre(sessions, _mois, DateTime(_mois.year, _mois.month + 1)).toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));
    final enCours = _mois.year == now.year && _mois.month == now.month;

    // Sans jour touché : aujourd'hui s'il a une séance, sinon la dernière du mois.
    final jour = _jour ??
        (enCours && types.containsKey(Dates.jour(now))
            ? Dates.jour(now)
            : (duMois.isEmpty ? (enCours ? Dates.jour(now) : _mois) : Dates.jour(duMois.last.debut)));
    final duJour = sessions.where((s) => !s.enCours && Dates.memeJour(s.debut, jour)).toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));

    return PageProgres(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          EnTetePage(titre: Calculs.moisAnnee(_mois), sousTitre: 'Calendrier d\'entraînement'),
          const SizedBox(height: 12.5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
            child: Row(
              children: [
                Expanded(
                  child: TuileChiffre(
                    valeur: '$serie',
                    legende: serie > 1 ? 'semaines de série' : 'semaine de série',
                  ),
                ),
                const SizedBox(width: Cotes.gouttiere),
                Expanded(
                  child: TuileChiffre(
                    valeur: '${duMois.length}',
                    legende: '${duMois.length > 1 ? 'séances' : 'séance'} ${enCours ? 'ce mois' : 'dans le mois'}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Cotes.bloc),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
            child: GestureDetector(
              // Glisser sur la grille change de mois.
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v > 200) _changer(-1);
                if (v < -200) _changer(1);
              },
              child: Carte(
                padding: const EdgeInsets.fromLTRB(12.5, 17.5, 12.5, 17.5),
                child: GrilleMois(
                  mois: _mois,
                  aujourdhui: now,
                  premierJour: premierJour,
                  seance: (j) => types[Dates.jour(j)],
                  onJour: (j) => setState(() {
                    _jour = Dates.jour(j);
                    final m = DateTime(j.year, j.month);
                    if (!m.isAfter(DateTime(now.year, now.month))) _mois = m;
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: Cotes.bloc),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SurTitre(Fmt.jour(jour)),
                const SizedBox(height: 10),
                if (duJour.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(17.5),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Cotes.rTuile)),
                    child: Text('Pas de séance ce jour-là.', style: ts(14.5, FontWeight.w400, c.text2, hauteur: 1.35)),
                  ),
                for (final (i, s) in duJour.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _LigneSeance(
                    session: s,
                    exercice: s.exercices.isEmpty ? null : exos.byId(s.exercices.first.exerciseId),
                    onTap: () => context.push(SeancePaths.detail(s.id)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une séance du jour touché : vignette, nom, durée, séries, volume.
class _LigneSeance extends StatelessWidget {
  const _LigneSeance({required this.session, required this.exercice, required this.onTap});
  final WorkoutSession session;
  final Exercise? exercice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    final detail = [
      if (Calculs.dureeDe(s).inMinutes > 0) Fmt.duree(Calculs.dureeDe(s)),
      Fmt.pluriel(s.nbSeriesFaites, 'série'),
      if (s.volume > 0) '${Fmt.n(s.volume, decimals: 0)} kg',
    ].join(' · ');
    return Carte(
      rayon: Cotes.rTuile,
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      semantique: '${s.nom}, $detail',
      child: Row(
        children: [
          if (s.type == TypeSeance.musculation && VignetteExercice.assetDe(exercice) != null)
            VignetteExercice(exercice: exercice)
          else
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: IconeTypeSeance(s.type, size: 28, color: c.text),
            ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(16, FontWeight.w600, c.text, hauteur: 1.35)),
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Chevron(),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
