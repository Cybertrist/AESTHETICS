import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../sante/recuperation/recup_calcul.dart';
import '../logic/tableau.dart';
import '../progres_paths.dart';
import 'calendrier_widgets.dart';
import 'communs.dart';
import 'objectifs_section.dart';
import 'torse_ruban.dart';

/// Page d'entrée de l'onglet Progrès. La période choisie (semaine, mois,
/// année) commande tout le haut de la page, et les flèches remontent dans
/// le temps. Le bas ne dépend pas de la période : tout depuis le début, le
/// corps, les objectifs, les repères.
class ProgresPage extends StatefulWidget {
  const ProgresPage({super.key, this.maintenant});

  /// Date du jour, pour les tests.
  final DateTime? maintenant;

  @override
  State<ProgresPage> createState() => _ProgresPageState();
}

class _ProgresPageState extends State<ProgresPage> {
  PeriodeProgres _periode = PeriodeProgres.semaine;

  /// Nombre de périodes en arrière (0 : la période en cours, -1 : la précédente).
  int _decalage = 0;

  final _defilement = ScrollController();

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  /// Un jour de la période montrée.
  DateTime _ancre(DateTime now) => switch (_periode) {
        PeriodeProgres.semaine => DateTime(now.year, now.month, now.day + 7 * _decalage),
        PeriodeProgres.mois => _decalage == 0 ? now : DateTime(now.year, now.month + _decalage),
        PeriodeProgres.annee => _decalage == 0 ? now : DateTime(now.year + _decalage),
      };

  /// Décalage le plus ancien : la période de la toute première séance.
  int _plusAncien(List<WorkoutSession> sessions, DateTime now, int premierJour) {
    DateTime? premiere;
    for (final s in sessions) {
      if (s.enCours) continue;
      if (premiere == null || s.debut.isBefore(premiere)) premiere = s.debut;
    }
    if (premiere == null) return 0;
    switch (_periode) {
      case PeriodeProgres.semaine:
        final a = Dates.debutSemaine(premiere, premierJour: premierJour);
        final b = Dates.debutSemaine(now, premierJour: premierJour);
        return -((b.difference(a).inHours / 24).round() ~/ 7);
      case PeriodeProgres.mois:
        return -((now.year - premiere.year) * 12 + now.month - premiere.month);
      case PeriodeProgres.annee:
        return -(now.year - premiere.year);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions;
    final exos = context.watch<ExerciseRepo>();
    final sante = context.watch<HealthRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final now = widget.maintenant ?? DateTime.now();
    // Le premier jour de la semaine se règle dans Profil, Réglages.
    final premierJour = context.watch<SettingsRepo>().settings.premierJourSemaine;

    final records = Calculs.records(sessions);
    final ancre = _ancre(now);
    final r = Calculs.resumeDe(_periode, ancre, sessions, exos.byId, now: now, recordsConnus: records, premierJour: premierJour);
    final enCours = _decalage == 0;
    final dans = Calculs.entre(sessions, r.debut, r.fin).toList()..sort((a, b) => a.debut.compareTo(b.debut));
    final debutMois = DateTime(now.year, now.month);
    final recordsDuMois = records.where((x) => !x.session.debut.isBefore(debutMois)).map((x) => x.exerciseId).toSet().length;
    final etats = Recup.etats(sessions, exos.byId, now: now);
    final conseil = Recup.conseil(etats, sessions, exos.byId);
    final finies = sessions.where((s) => !s.enCours).toList();
    final vide = finies.isEmpty;
    final ancien = _plusAncien(sessions, now, premierJour);

    void changer(PeriodeProgres p, [int decalage = 0]) => setState(() {
          _periode = p;
          _decalage = decalage;
        });

    const pad = EdgeInsets.symmetric(horizontal: Cotes.marge);
    return PageProgres(
      child: ListView(
        controller: _defilement,
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Cotes.marge, 14, Cotes.marge, 12),
            child: Text('Progrès', style: ts(25, FontWeight.w700, c.text, hauteur: 1.35)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Cotes.marge, 12, Cotes.marge, 6),
            child: SelecteurSegmente<PeriodeProgres>(
              segments: [for (final p in PeriodeProgres.values) (p, p.label)],
              value: _periode,
              onChanged: changer,
            ),
          ),
          Padding(
            padding: pad,
            child: NavigationPeriode(
              titre: _titre(r.debut),
              detail: _sousTitre(),
              avant: _decalage > ancien ? () => setState(() => _decalage--) : null,
              apres: enCours ? null : () => setState(() => _decalage++),
            ),
          ),
          const SizedBox(height: 6),
          if (vide) ...[
            Padding(padding: pad, child: const _Debut()),
            const SizedBox(height: Cotes.bloc),
          ],
          Padding(
            padding: pad,
            child: _CarteVolume(resume: r, contre: _contre(r.debut, enCours)),
          ),
          // Le résumé façon story de la période : celui de l'année en vue
          // Année ; en vue Mois, celui du mois montré, une fois ce mois fini
          // (le mois en cours ne propose pas le résumé d'un autre mois).
          // Rien en vue Semaine.
          () {
            if (_periode == PeriodeProgres.semaine) return const SizedBox.shrink();
            if (_periode == PeriodeProgres.annee) {
              if (dans.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(Cotes.marge, Cotes.gouttiere, Cotes.marge, 0),
                child: CarteResumeMensuel(
                  titre: 'Résumé annuel',
                  mois: enCours ? '${r.debut.year}, jusqu\'ici' : '${r.debut.year}',
                  onTap: () => context.push(ProgresPaths.bilanAnnee(r.debut.year)),
                ),
              );
            }
            if (enCours) return const SizedBox.shrink();
            final moisFini = r.debut;
            if (Calculs.entre(sessions, moisFini, DateTime(moisFini.year, moisFini.month + 1)).isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(Cotes.marge, Cotes.gouttiere, Cotes.marge, 0),
              child: CarteResumeMensuel(
                titre: 'Résumé mensuel',
                mois: '${Calculs.moisNom(moisFini)} ${moisFini.year}',
                onTap: () => context.push(ProgresPaths.bilan(moisFini)),
              ),
            );
          }(),
          const SizedBox(height: Cotes.gouttiere),
          Padding(
            padding: pad,
            child: _CarteBarres(
              titre: switch (_periode) {
                PeriodeProgres.semaine => 'Volume par jour',
                PeriodeProgres.mois => 'Volume par semaine',
                PeriodeProgres.annee => 'Volume par mois',
              },
              barres: switch (_periode) {
                PeriodeProgres.semaine => Calculs.volumesParJour(r.debut, sessions, now: now),
                PeriodeProgres.mois => Calculs.semainesDuMois(r.debut, sessions, now: now, premierJour: premierJour),
                PeriodeProgres.annee => Calculs.moisDeLAnnee(r.debut.year, sessions, now: now),
              },
              serre: _periode == PeriodeProgres.annee,
            ),
          ),
          // Ce que la période a de propre.
          if (_periode == PeriodeProgres.semaine && dans.isNotEmpty) ...[
            const SizedBox(height: Cotes.gouttiere),
            Padding(padding: pad, child: _CarteSeances(seances: dans)),
          ],
          if (_periode == PeriodeProgres.mois) ...[
            const SizedBox(height: Cotes.gouttiere),
            Padding(
              padding: pad,
              child: _CarteCalendrier(
                mois: r.debut,
                sessions: sessions,
                maintenant: now,
                premierJour: premierJour,
                onDetail: () => context.push(ProgresPaths.calendrierDuMois(r.debut)),
                onJour: (j) => context.push(ProgresPaths.calendrier(j)),
              ),
            ),
          ],
          if (_periode == PeriodeProgres.annee) ...[
            const SizedBox(height: Cotes.gouttiere),
            Padding(
              padding: pad,
              child: _CarteMois(
                annee: r.debut.year,
                sessions: sessions,
                maintenant: now,
                premierJour: premierJour,
                // Le mois s'ouvre par son début : on remonte en haut de la page.
                onMois: (m) {
                  changer(PeriodeProgres.mois, (m.year - now.year) * 12 + m.month - now.month);
                  _defilement.jumpTo(0);
                },
              ),
            ),
          ],
          if (r.groupes.isNotEmpty) ...[
            const SizedBox(height: Cotes.gouttiere),
            Padding(padding: pad, child: _CarteMuscles(groupes: r.groupes)),
          ],
          if (_periode == PeriodeProgres.annee) ...[
            () {
              final gains = Calculs.progressions(dans, exos.byId);
              if (gains.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(Cotes.marge, Cotes.gouttiere, Cotes.marge, 0),
                child: _CarteProgressions(gains: gains, nom: exos.nameOf, unite: unite),
              );
            }(),
          ],

          // Ce qui ne dépend pas de la période.
          const SizedBox(height: 30),
          const Padding(padding: pad, child: Separateur('Depuis le début')),
          const SizedBox(height: 16),
          Padding(padding: pad, child: _DepuisLeDebut(seances: finies, premierJour: premierJour, maintenant: now)),
          const SizedBox(height: Cotes.bloc),
          const TitreBloc('Ton corps'),
          Padding(
            padding: pad,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _TuileCorps(
                      semantique: 'Récupération musculaire',
                      onTap: () => context.push(ProgresPaths.recuperation),
                      haut: AnneauRecup(pourcentage: Recup.global(etats), taille: 92),
                      titre: 'Récupération',
                      detail: Text(
                        Recup.pretPour(conseil.groupe),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35),
                      ),
                    ),
                  ),
                  const SizedBox(width: Cotes.gouttiere),
                  Expanded(
                    child: _TuileCorps(
                      semantique: 'Mensurations',
                      onTap: () => context.push(ProgresPaths.mensurations),
                      haut: const TorseRuban(),
                      titre: 'Mensurations',
                      detail: _poids(context, sante, now),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Cotes.bloc),
          const ObjectifsSection(),
          const SizedBox(height: Cotes.bloc),
          const TitreBloc('Tes repères'),
          Padding(
            padding: pad,
            child: Row(
              children: [
                Expanded(
                  child: _TuileRepere(
                    titre: 'Records',
                    valeur: '${Calculs.exercicesAvecRecord(sessions)}',
                    detail: recordsDuMois > 0 ? 'dont $recordsDuMois ce mois' : 'un par exercice',
                    onTap: () => context.push(ProgresPaths.records),
                  ),
                ),
                const SizedBox(width: Cotes.gouttiere),
                Expanded(
                  child: _TuileRepere(
                    titre: 'Photos',
                    valeur: '${sante.photos.length}',
                    detail: sante.photos.isEmpty ? 'à commencer' : 'depuis ${Calculs.moisNom(sante.photos.last.date)}',
                    onTap: () => context.push(ProgresPaths.photos),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// « 28 sept. au 4 oct. », « Septembre 2026 », « 2026 ».
  String _titre(DateTime debut) => switch (_periode) {
        PeriodeProgres.semaine => Calculs.semaineLibelle(debut),
        PeriodeProgres.mois => Calculs.moisAnnee(debut),
        PeriodeProgres.annee => '${debut.year}',
      };

  String _sousTitre() => switch (_periode) {
        PeriodeProgres.semaine => _decalage == 0
            ? 'cette semaine'
            : _decalage == -1
                ? 'la semaine dernière'
                : 'il y a ${-_decalage} semaines',
        PeriodeProgres.mois => _decalage == 0 ? 'mois en cours' : 'mois terminé',
        PeriodeProgres.annee => _decalage == 0 ? 'année en cours' : 'année terminée',
      };

  /// Suite de l'écart : « vs semaine d'avant », « vs août », « vs 2025 ».
  String _contre(DateTime debut, bool enCours) => switch (_periode) {
        PeriodeProgres.semaine => 'vs semaine d\'avant',
        PeriodeProgres.mois => 'vs ${Calculs.moisNom(DateTime(debut.year, debut.month - 1))}',
        PeriodeProgres.annee => 'vs ${debut.year - 1}${enCours ? ' à la même date' : ''}',
      };

  /// « 76,7 kg · +2,6 » : le dernier poids et l'écart sur trente jours.
  Widget _poids(BuildContext context, HealthRepo sante, DateTime now) {
    final c = context.colors;
    final style = ts(14, FontWeight.w400, c.text2, hauteur: 1.35);
    final serie = sante.weightSeries();
    if (serie.isEmpty) return Text('À renseigner', maxLines: 1, style: style);
    final dernier = serie.last;
    final seuil = dernier.date.subtract(const Duration(days: 30));
    final base = serie.lastWhere((p) => !p.date.isAfter(seuil), orElse: () => serie.first);
    // Arrondi au dixième avant de décider : un écart qui s'écrirait « 0 » ne
    // s'affiche pas.
    final dixiemes = ((dernier.kg - base.kg) * 10).round();
    final ecart = dixiemes / 10;
    final montre = dixiemes != 0;
    return Text.rich(
      TextSpan(
        text: Fmt.poids(dernier.kg),
        children: [
          if (montre) ...[
            const TextSpan(text: ' · '),
            TextSpan(
              text: '${ecart > 0 ? '+' : '-'}${Fmt.n(ecart.abs())}',
              style: ts(14, FontWeight.w700, ecart > 0 ? c.success : c.error, hauteur: 1.35),
            ),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// Invitation quand aucune séance n'est encore enregistrée.
class _Debut extends StatelessWidget {
  const _Debut();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rien à mesurer pour l\'instant', style: ts(17, FontWeight.w700, c.text, hauteur: 1.35)),
          const SizedBox(height: 2),
          Text('Ta première séance remplira cette page.', style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
          const SizedBox(height: 14),
          BoutonPrincipal(label: 'Commencer une séance', petit: true, onPressed: () => context.go('/entrainer')),
        ],
      ),
    );
  }
}

/// La grande carte : volume, écart, étiquettes de muscles, corps face et dos.
class _CarteVolume extends StatelessWidget {
  const _CarteVolume({required this.resume, required this.contre});
  final ResumePeriode resume;
  final String contre;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ecart = resume.ecart;
    final groupes = resume.groupes.take(2).toList();
    return Carte(
      padding: const EdgeInsets.fromLTRB(20, 20, 12.5, 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // En 360 de large, le titre rétrécit au lieu d'être coupé.
                const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: SurTitre('Volume soulevé')),
                const SizedBox(height: 7.5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      text: Fmt.n(resume.volume, decimals: 0),
                      children: [TextSpan(text: ' kg', style: ts(19, FontWeight.w800, c.text))],
                    ),
                    maxLines: 1,
                    style: ts(35, FontWeight.w800, c.text, hauteur: 1.05, espace: -0.7),
                  ),
                ),
                if (ecart != null) ...[
                  const SizedBox(height: 7.5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        text: '${Calculs.signe(ecart)} ',
                        children: [TextSpan(text: contre, style: ts(15, FontWeight.w400, c.text2))],
                      ),
                      maxLines: 1,
                      style: ts(15, FontWeight.w700, ecart > 0 ? c.success : c.error, hauteur: 1.35),
                    ),
                  ),
                ],
                if (groupes.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (i, g) in groupes.indexed)
                        Pastille(Calculs.groupe(g.groupe), ton: i == 0 ? TonPastille.musclePlein : TonPastille.muscle),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 7.5),
          // Sur un écran étroit, le corps rétrécit pour laisser sa place au chiffre.
          CorpsFaceDos(intensites: resume.intensites, hauteur: MediaQuery.sizeOf(context).width < 360 ? 128 : 165),
        ],
      ),
    );
  }
}

/// Les barres de la période : sept jours, les semaines du mois ou les douze
/// mois. La barre en cours est blanche, la plus haute des autres en accent.
class _CarteBarres extends StatelessWidget {
  const _CarteBarres({required this.titre, required this.barres, this.serre = false});
  final String titre;
  final List<BarreVolume> barres;

  /// Douze barres : moins d'écart entre elles.
  final bool serre;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = barres.fold(0.0, (a, b) => math.max(a, b.volume));
    // En tonnes dès que la plus haute barre pèse plus d'une tonne.
    final tonnes = max >= 1000;
    return Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(titre, style: ts(19, FontWeight.w800, c.text, hauteur: 1.35))),
              if (max > 0)
                Text(
                  'max ${tonnes ? '${Fmt.n(max / 1000)} t' : '${Fmt.n(max, decimals: 0)} kg'}',
                  style: ts(13, FontWeight.w400, c.text2, hauteur: 1.35),
                ),
            ],
          ),
          const SizedBox(height: 15),
          BarresVolume(
            ecart: serre ? 6 : 9,
            barres: [
              for (final b in barres)
                (
                  label: b.label,
                  valeur: b.volume,
                  couleur: b.courante
                      ? c.text
                      : (max > 0 && b.volume == max ? c.accent : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Les séances de la semaine, une ligne chacune.
class _CarteSeances extends StatelessWidget {
  const _CarteSeances({required this.seances});
  final List<WorkoutSession> seances;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Carte(
      padding: const EdgeInsets.fromLTRB(0, 17.5, 0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17.5),
            child: Text('Tes séances', style: ts(19, FontWeight.w800, c.text, hauteur: 1.35)),
          ),
          const SizedBox(height: 4),
          for (final (i, s) in seances.indexed) LigneSeance(session: s, filet: i > 0),
        ],
      ),
    );
  }
}

/// Le mois en grille, avec la flamme de chaque semaine tenue.
class _CarteCalendrier extends StatelessWidget {
  const _CarteCalendrier({required this.mois, required this.sessions, required this.maintenant, required this.premierJour, required this.onDetail, required this.onJour});
  final DateTime mois;
  final List<WorkoutSession> sessions;
  final DateTime maintenant;
  final int premierJour;
  final VoidCallback onDetail;
  final ValueChanged<DateTime> onJour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final types = Calculs.typesParJour(sessions);
    final cette = Dates.debutSemaine(maintenant, premierJour: premierJour);
    return Carte(
      padding: const EdgeInsets.fromLTRB(12.5, 17.5, 10, 17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              children: [
                Expanded(child: Text('Calendrier', style: ts(19, FontWeight.w800, c.text, hauteur: 1.35))),
                InkWell(
                  onTap: onDetail,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text('Détail', style: ts(15, FontWeight.w600, c.text)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.5),
          GrilleMois(
            mois: mois,
            aujourdhui: maintenant,
            premierJour: premierJour,
            seance: (j) => types[Dates.jour(j)],
            onJour: onJour,
            // Un point orange par semaine tenue, un rond vide sinon. La
            // flamme et son chiffre ne sont que sur la dernière semaine de
            // la série en cours : un mois passé n'en a pas.
            flamme: (debut) {
              if (debut.isAfter(cette)) return null;
              bool tenue(DateTime d) => Calculs.entre(sessions, d, DateTime(d.year, d.month, d.day + 7)).isNotEmpty;
              if (!tenue(debut)) return 0;
              final avant = DateTime(cette.year, cette.month, cette.day - 7);
              final porteuse = tenue(cette) ? cette : (tenue(avant) ? avant : null);
              if (debut != porteuse) return -1;
              return Calculs.serieSemaines(sessions, a: maintenant, premierJour: premierJour);
            },
          ),
        ],
      ),
    );
  }
}

/// Le calendrier de l'année : douze petits mois, un point par jour, plein
/// les jours de séance. Toucher un mois l'ouvre dans la vue Mois.
class _CarteMois extends StatelessWidget {
  const _CarteMois({required this.annee, required this.sessions, required this.maintenant, required this.premierJour, required this.onMois});
  final int annee;
  final List<WorkoutSession> sessions;
  final DateTime maintenant;
  final int premierJour;
  final ValueChanged<DateTime> onMois;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ceMois = DateTime(maintenant.year, maintenant.month);
    final actifs = {
      for (final s in sessions)
        if (!s.enCours && s.debut.year == annee) Dates.jour(s.debut),
    };
    return Carte(
      padding: const EdgeInsets.fromLTRB(12.5, 17.5, 12.5, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              children: [
                Expanded(child: Text('Calendrier', style: ts(19, FontWeight.w800, c.text, hauteur: 1.35))),
                Text(Fmt.pluriel(actifs.length, 'jour d\'entraînement', 'jours d\'entraînement'), style: ts(13, FontWeight.w400, c.text2, hauteur: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var ligne = 0; ligne < 4; ligne++)
            Padding(
              padding: EdgeInsets.only(top: ligne == 0 ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var col = 0; col < 3; col++) ...[
                    if (col > 0) const SizedBox(width: 6),
                    Expanded(
                      child: () {
                        final m = DateTime(annee, ligne * 3 + col + 1);
                        final futur = m.isAfter(ceMois);
                        final n = actifs.where((j) => j.month == m.month).length;
                        return Semantics(
                          button: !futur,
                          label: '${Calculs.moisAnnee(m)}, ${Fmt.pluriel(n, 'séance')}',
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: futur ? null : () => onMois(m),
                            borderRadius: BorderRadius.circular(12.5),
                            child: Opacity(
                              opacity: futur ? 0.35 : 1,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            Calculs.moisCap(m),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: ts(13.5, FontWeight.w700, m == ceMois ? c.accent : c.text, hauteur: 1.35),
                                          ),
                                        ),
                                        if (n > 0) Text('$n', style: ts(12.5, FontWeight.w600, c.text2, hauteur: 1.35)),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    _PetitMois(mois: m, actifs: actifs, aujourdhui: maintenant, premierJour: premierJour),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }(),
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

/// Un mois en tout petit : sept colonnes de points, pleins les jours de séance.
class _PetitMois extends StatelessWidget {
  const _PetitMois({required this.mois, required this.actifs, required this.aujourdhui, required this.premierJour});
  final DateTime mois;
  final Set<DateTime> actifs;
  final DateTime aujourdhui;
  final int premierJour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final decalage = (DateTime(mois.year, mois.month).weekday - premierJour) % 7;
    final nb = DateTime(mois.year, mois.month + 1, 0).day;
    return LayoutBuilder(builder: (context, box) {
      final pas = box.maxWidth / 7;
      final d = pas * 0.72;
      return SizedBox(
        // Six lignes pour tous : les mois d'une rangée restent alignés.
        height: pas * 6,
        child: Stack(
          children: [
            for (var j = 1; j <= nb; j++)
              () {
                final i = decalage + j - 1;
                final jour = DateTime(mois.year, mois.month, j);
                final seance = actifs.contains(jour);
                final auj = Dates.memeJour(jour, aujourdhui);
                return Positioned(
                  left: (i % 7) * pas + (pas - d) / 2,
                  top: (i ~/ 7) * pas + (pas - d) / 2,
                  child: Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: seance ? c.accent : c.surface3,
                      border: auj ? Border.all(color: c.text, width: 1.5) : null,
                    ),
                  ),
                );
              }(),
          ],
        ),
      );
    });
  }
}

/// La part de chaque groupe musculaire dans le volume de la période.
class _CarteMuscles extends StatelessWidget {
  const _CarteMuscles({required this.groupes});
  final List<PartGroupe> groupes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lignes = groupes.take(5).toList();
    final max = lignes.first.part;
    return Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Muscles travaillés', style: ts(19, FontWeight.w800, c.text, hauteur: 1.35))),
              Text('part du volume', style: ts(13, FontWeight.w400, c.text2, hauteur: 1.35)),
            ],
          ),
          const SizedBox(height: 6),
          for (final g in lignes)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Row(
                children: [
                  SizedBox(width: 92, child: Text(Calculs.groupe(g.groupe), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, FontWeight.w600, c.text, hauteur: 1.35))),
                  Expanded(child: BarreFine(valeur: max <= 0 ? 0 : g.part / max)),
                  SizedBox(
                    width: 46,
                    child: Text('${(g.part * 100).round()} %', textAlign: TextAlign.right, style: ts(13, FontWeight.w400, c.text2, hauteur: 1.35)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Les exercices qui ont le plus progressé sur l'année (1RM estimé).
class _CarteProgressions extends StatelessWidget {
  const _CarteProgressions({required this.gains, required this.nom, required this.unite});
  final List<Progression> gains;
  final String Function(String) nom;
  final UnitePoids unite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Carte(
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Meilleures progressions', style: ts(19, FontWeight.w800, c.text, hauteur: 1.35))),
              Text('1RM estimé', style: ts(13, FontWeight.w400, c.text2, hauteur: 1.35)),
            ],
          ),
          const SizedBox(height: 4),
          for (final g in gains)
            InkWell(
              onTap: () => context.push('/progres/exercices/${g.exerciseId}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nom(g.exerciseId), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, FontWeight.w600, c.text, hauteur: 1.35)),
                          Text('${Fmt.poids(g.de, unite)} → ${Fmt.poids(g.a, unite)}', maxLines: 1, style: ts(13, FontWeight.w400, c.text2, hauteur: 1.35)),
                        ],
                      ),
                    ),
                    Text('+${g.pourcent} %', style: ts(15, FontWeight.w700, c.success, hauteur: 1.35)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tout depuis la première séance : séances, volume, temps, meilleure série.
class _DepuisLeDebut extends StatelessWidget {
  const _DepuisLeDebut({required this.seances, required this.premierJour, required this.maintenant});
  final List<WorkoutSession> seances;
  final int premierJour;
  final DateTime maintenant;

  @override
  Widget build(BuildContext context) {
    final volume = Calculs.volumeDe(seances);
    final duree = seances.fold(Duration.zero, (a, s) => a + Calculs.dureeDe(s));
    final serie = seances.isEmpty
        ? 0
        : Calculs.meilleureSerie(seances, DateTime(1970), DateTime(maintenant.year, maintenant.month, maintenant.day + 1), premierJour: premierJour);
    Widget tuile(String valeur, String legende, {VoidCallback? onTap}) => Expanded(
          child: Semantics(
            button: onTap != null,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Cotes.rTuile),
              child: TuileChiffre(valeur: valeur, legende: legende),
            ),
          ),
        );
    return Column(
      children: [
        Row(
          children: [
            tuile(Fmt.n(seances.length, decimals: 0), seances.length >= 2 ? 'séances' : 'séance', onTap: () => context.push('/seance/historique')),
            const SizedBox(width: Cotes.gouttiere),
            tuile(volume >= 10000 ? '${Fmt.n(volume / 1000, decimals: 0)} t' : '${Fmt.n(volume, decimals: 0)} kg', volume >= 2000 ? 'soulevées' : 'soulevés'),
          ],
        ),
        const SizedBox(height: Cotes.gouttiere),
        Row(
          children: [
            tuile(duree.inHours >= 1 ? '${Fmt.n(duree.inHours, decimals: 0)} h' : '${duree.inMinutes} min', 'd\'entraînement'),
            const SizedBox(width: Cotes.gouttiere),
            tuile('$serie sem.', 'meilleure série'),
          ],
        ),
      ],
    );
  }
}

/// Tuile centrée de « Ton corps ».
class _TuileCorps extends StatelessWidget {
  const _TuileCorps({required this.haut, required this.titre, required this.detail, required this.onTap, required this.semantique});
  final Widget haut;
  final String titre;
  final Widget detail;
  final VoidCallback onTap;
  final String semantique;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Carte(
      onTap: onTap,
      semantique: semantique,
      padding: const EdgeInsets.fromLTRB(12.5, 17.5, 12.5, 17.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          haut,
          const SizedBox(height: 10),
          Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, FontWeight.w700, c.text, hauteur: 1.35)),
          detail,
        ],
      ),
    );
  }
}

/// Tuile de « Tes repères » : titre et chevron, grand chiffre, légende.
class _TuileRepere extends StatelessWidget {
  const _TuileRepere({required this.titre, required this.valeur, required this.detail, required this.onTap});
  final String titre;
  final String valeur;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Carte(
      onTap: onTap,
      semantique: titre,
      padding: const EdgeInsets.all(17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(titre, style: ts(17, FontWeight.w700, c.text, hauteur: 1.35))),
              const Chevron(),
            ],
          ),
          const SizedBox(height: 2),
          Text(valeur, style: ts(35, FontWeight.w800, c.text, hauteur: 1.05, espace: -0.7)),
          const SizedBox(height: 2),
          Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
        ],
      ),
    );
  }
}
