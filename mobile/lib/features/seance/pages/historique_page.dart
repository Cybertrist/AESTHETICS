import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/lancement.dart';
import '../seance_paths.dart';
import '../widgets/habillage.dart';
import '../widgets/pages.dart';

/// Historique des séances, mois par mois : chiffres du mois, calendrier aux
/// codes de la maquette (cercle et icône du type les jours de séance, disque
/// blanc aujourd'hui), puis les séances du mois ou du jour touché.
class HistoriquePage extends StatefulWidget {
  const HistoriquePage({super.key, this.maintenant});

  /// Date du jour, remplaçable dans les tests.
  final DateTime? maintenant;

  @override
  State<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  late DateTime _mois = DateTime(_auj.year, _auj.month);
  DateTime? _jour;

  DateTime get _auj => widget.maintenant ?? DateTime.now();

  Future<void> _demarrer() async {
    final repo = context.read<SessionRepo>();
    if (!repo.hasActive) await Lancement.vide(repo);
    if (mounted) context.push(SeancePaths.enCours);
  }

  void _allerA(DateTime mois) => setState(() {
        _mois = DateTime(mois.year, mois.month);
        _jour = null;
      });

  /// Ligne de détail d'une séance : le jour et la durée dans la liste du
  /// mois, la durée et les séries pour un jour choisi. Le volume est à
  /// droite de la ligne ; une séance sans charge (cardio) n'en montre pas.
  static String detail(WorkoutSession s, {DateTime? now, bool avecDate = true}) => [
        if (avecDate) Fmt.relatif(s.debut, now: now),
        Fmt.duree(s.duree),
        if (!avecDate && s.nbSeriesFaites > 0) Fmt.pluriel(s.nbSeriesFaites, 'série'),
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<SessionRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final premier = context.watch<SettingsRepo>().settings.premierJourSemaine;
    final c = context.colors;
    final toutes = repo.sessions;

    if (toutes.isEmpty) {
      return PageSeance(
        titre: 'Historique',
        body: VideSeance(
          icone: const IconeHaltere(),
          titre: 'Aucune séance pour l\'instant',
          message: 'Tes séances terminées apparaîtront ici, jour par jour.',
          action: repo.hasActive ? 'Reprendre la séance en cours' : 'Démarrer une séance',
          onAction: _demarrer,
        ),
      );
    }

    final fin = DateTime(_mois.year, _mois.month + 1);
    final duMois = repo.sessionsBetween(_mois, fin);
    final liste = _jour == null ? duMois : duMois.where((s) => Dates.memeJour(s.debut, _jour!)).toList();
    final plusAncienne = toutes.last.debut;
    final volume = duMois.fold(0.0, (a, s) => a + s.volume);
    final duree = duMois.fold(Duration.zero, (a, s) => a + s.duree);
    final peutReculer = _mois.isAfter(DateTime(plusAncienne.year, plusAncienne.month));
    final peutAvancer = _mois.isBefore(DateTime(_auj.year, _auj.month));
    final large = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;

    // Le type de la première séance du jour décide de l'icône.
    final parJour = <int, TypeSeance>{};
    for (final s in duMois.reversed) {
      parJour.putIfAbsent(s.debut.day, () => s.type);
    }

    Widget fleche(IconeSeance icone, String label, VoidCallback? onTap) => Opacity(
          opacity: onTap == null ? 0.3 : 1,
          child: BoutonRond(label: label, nu: true, onTap: onTap, child: Trait(icone, size: k(16), epaisseur: 2)),
        );

    final calendrier = <Widget>[
      Row(
        children: [
          Expanded(child: TuileChiffre(valeur: '${duMois.length}', label: duMois.length > 1 ? 'séances' : 'séance')),
          SizedBox(width: k(6)),
          Expanded(child: TuileChiffre(valeur: volume > 0 ? Fmt.volume(volume, unite) : '-', label: 'volume')),
          SizedBox(width: k(6)),
          Expanded(child: TuileChiffre(valeur: duMois.isEmpty ? '-' : Fmt.duree(duree), label: 'temps')),
        ],
      ),
      SizedBox(height: k(10)),
      Container(
        padding: EdgeInsets.fromLTRB(k(8), k(6), k(8), k(12)),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(18))),
        child: Column(
          children: [
            Row(
              children: [
                fleche(IconeSeance.chevronGauche, 'Mois précédent', peutReculer ? () => _allerA(DateTime(_mois.year, _mois.month - 1)) : null),
                Expanded(
                  child: Text(
                    Fmt.mois(_mois),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(14), fontWeight: FontWeight.w700, color: c.text),
                  ),
                ),
                fleche(IconeSeance.chevronDroit, 'Mois suivant', peutAvancer ? () => _allerA(DateTime(_mois.year, _mois.month + 1)) : null),
              ],
            ),
            SizedBox(height: k(6)),
            GrilleMois(
          mois: _mois,
          premierJour: premier,
          aujourdhui: _auj,
          seance: (j) => j.month == _mois.month && j.year == _mois.year ? parJour[j.day] : null,
          onJour: (j) {
            // Un jour d'un mois voisin (en retrait) mène à ce mois, sans dépasser aujourd'hui.
            if (j.month != _mois.month) {
              final m = DateTime(j.year, j.month);
              if (!m.isAfter(DateTime(_auj.year, _auj.month)) && !m.isBefore(DateTime(plusAncienne.year, plusAncienne.month))) _allerA(m);
              return;
            }
            setState(() => _jour = _jour != null && Dates.memeJour(_jour!, j) ? null : j);
          },
            ),
          ],
        ),
      ),
    ];

    final seances = <Widget>[
      Row(
        children: [
          Expanded(child: Surtitre(_jour == null ? 'Séances du mois' : Fmt.jour(_jour!))),
          if (_jour != null) LienTexte(label: 'Tout le mois', onTap: () => setState(() => _jour = null)),
        ],
      ),
      SizedBox(height: k(_jour == null ? 8 : 2)),
      if (liste.isEmpty)
        Container(
          padding: EdgeInsets.symmetric(horizontal: k(14), vertical: k(14)),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(14))),
          child: Text(
            _jour == null ? 'Aucune séance ce mois-ci.' : 'Pas de séance ce jour-là.',
            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.4, color: c.text2),
          ),
        )
      else
        for (final s in liste)
          Padding(
            padding: EdgeInsets.only(bottom: k(8)),
            child: LigneCarte(
              tete: PastilleTypeSeance(s.type, taille: k(36)),
              titre: s.nom,
              detail: detail(s, now: _auj, avecDate: _jour == null),
              // Le volume à droite, pour que le détail tienne sur sa ligne.
              fin: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.volume > 0)
                    Text(
                      volumeSeance(s.volume, unite),
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), fontWeight: FontWeight.w700, color: c.text, fontFeatures: AppTokens.tabular),
                    ),
                  SizedBox(width: k(6)),
                  Trait(IconeSeance.chevronDroit, size: k(14), epaisseur: 2, color: c.text3),
                  SizedBox(width: k(4)),
                ],
              ),
              onTap: () => context.push(SeancePaths.detail(s.id)),
            ),
          ),
    ];

    return PageSeance(
      titre: 'Historique',
      sousTitre: '${Fmt.pluriel(toutes.length, 'séance')} au total',
      largeurMax: large ? 1100 : 640,
      body: large
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 420, child: ListView(padding: EdgeInsets.fromLTRB(margeSeance, k(6), k(8), k(24)), children: calendrier)),
                Expanded(child: ListView(padding: EdgeInsets.fromLTRB(k(8), k(6), margeSeance, k(24)), children: seances)),
              ],
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(margeSeance, k(6), margeSeance, k(24)),
              children: [...calendrier, SizedBox(height: k(18)), ...seances],
            ),
    );
  }
}
