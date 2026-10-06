import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/bibliotheque/pages/exercise_browser.dart' show MuscleGroup, TuileRaccourci, VignetteGroupe;
import '../logic/progres_stats.dart';
import 'communs.dart';
import 'progres_widgets.dart';

enum _TriRecords {
  recents('Records récents'),
  progression('Plus forte progression'),
  charge('Charge la plus lourde'),
  alpha('A à Z');

  const _TriRecords(this.label);
  final String label;
}

enum _Quand {
  tout('Tout'),
  mois1('Ce mois'),
  mois3('3 mois'),
  an1('1 an');

  const _Quand(this.label);
  final String label;
}

/// Tous les records personnels, avec filtres et tri.
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _recherche = TextEditingController();
  var _groupes = <MuscleGroup>{};
  var _tri = _TriRecords.recents;
  var _quand = _Quand.tout;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _trier() async {
    final t = await choisirDansPanneau<_TriRecords>(
      context,
      titre: 'Trier les records',
      choisi: _tri,
      options: [for (final t in _TriRecords.values) (t, t.label)],
    );
    if (t != null && mounted) setState(() => _tri = t);
  }

  @override
  Widget build(BuildContext context) => ProgresGarde(titre: 'Records', builder: _contenu);

  Widget _contenu(BuildContext context) {
    final sessions = context.watch<SessionRepo>().sessions;
    final ex = context.watch<ExerciseRepo>();
    final u = context.watch<ProfileRepo>().unite;
    final c = context.colors;
    final toutes = ProgresStats.records(sessions);
    // La date du dernier record d'un exercice, quelle que soit sa médaille :
    // un record de répétitions de ce mois range l'exercice dans « Ce mois ».
    final dernier = <String, DateTime>{};
    for (final r in Strength.recordsAuFil([...sessions]..sort((a, b) => a.debut.compareTo(b.debut)))) {
      dernier[r.record.exerciseId] = r.record.date;
    }
    DateTime? dateDe(LigneRecord l) {
      final d = dernier[l.exerciseId], p = l.dateRecord;
      return d == null || (p != null && p.isAfter(d)) ? p : d;
    }
    final now = DateTime.now();
    final depuis = switch (_quand) {
      _Quand.tout => null,
      _Quand.mois1 => DateTime(now.year, now.month),
      _Quand.mois3 => now.subtract(const Duration(days: 91)),
      _Quand.an1 => now.subtract(const Duration(days: 365)),
    };
    final q = _recherche.text.trim();
    final lignes = toutes.where((l) {
      final e = ex.byId(l.exerciseId);
      if (q.isNotEmpty) {
        final noms = [ex.nameOf(l.exerciseId), ...?e?.alias];
        if (!TextSearch.matches(q, noms)) return false;
      }
      if (_groupes.isNotEmpty) {
        // Le muscle principal de l'exercice range son record dans un groupe.
        final m = e?.musclesPrincipaux.isEmpty ?? true ? null : e!.musclesPrincipaux.first;
        if (m == null || !_groupes.any((g) => g.muscles.contains(m))) return false;
      }
      if (depuis != null && (dateDe(l) == null || dateDe(l)!.isBefore(depuis))) return false;
      return true;
    }).toList();
    switch (_tri) {
      case _TriRecords.recents:
        lignes.sort((a, b) => (dateDe(b) ?? DateTime(0)).compareTo(dateDe(a) ?? DateTime(0)));
      case _TriRecords.progression:
        lignes.sort((a, b) => (b.gainPct ?? -1e9).compareTo(a.gainPct ?? -1e9));
      case _TriRecords.charge:
        lignes.sort((a, b) => (b.bests.poidsMax?.valeur ?? 0).compareTo(a.bests.poidsMax?.valeur ?? 0));
      case _TriRecords.alpha:
        lignes.sort((a, b) => ex.nameOf(a.exerciseId).toLowerCase().compareTo(ex.nameOf(b.exerciseId).toLowerCase()));
    }

    const pad = EdgeInsets.symmetric(horizontal: Cotes.marge);
    final entete = EnTetePage(
      titre: 'Records',
      sousTitre: Fmt.pluriel(toutes.length, 'exercice suivi', 'exercices suivis'),
      droite: toutes.isEmpty ? null : BoutonRond(trait: Trait.tri, label: 'Trier', onTap: _trier),
    );

    if (toutes.isEmpty) {
      return PageProgres(
        child: ListView(
          children: [
            entete,
            EtatVide(
              titre: 'Aucun record pour l\'instant',
              message: 'Termine une séance avec des charges : chaque exercice aura ses meilleures marques ici.',
              action: 'Aller à l\'entraînement',
              onAction: () => context.go('/entrainer'),
            ),
          ],
        ),
      );
    }

    return PageProgres(
      child: CustomScrollView(
        slivers: [
          SliverList.list(children: [
            entete,
            const SizedBox(height: 8),
            Padding(
              padding: pad,
              child: ChampRecherche(controller: _recherche, indice: 'Chercher un exercice', onChanged: (_) => setState(() {})),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: pad,
              child: SelecteurSegmente<_Quand>(
                segments: [for (final w in _Quand.values) (w, w.label)],
                value: _quand,
                onChanged: (w) => setState(() => _quand = w),
              ),
            ),
            const SizedBox(height: 12),
            // Les mêmes tuiles que dans la liste des exercices : le personnage,
            // le groupe allumé. On peut en choisir plusieurs.
            SizedBox(
              height: TuileRaccourci.hauteur(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: pad,
                itemCount: MuscleGroup.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12.5),
                itemBuilder: (context, i) {
                  final g = MuscleGroup.all[i];
                  final on = _groupes.contains(g);
                  return TuileRaccourci(
                    label: g.label,
                    choisi: on,
                    onTap: () => setState(() => _groupes = on ? ({..._groupes}..remove(g)) : {..._groupes, g}),
                    child: VignetteGroupe(g),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Cotes.marge, 12, Cotes.marge, 10),
              child: Text(
                '${Fmt.pluriel(lignes.length, 'résultat')} · ${_tri.label.toLowerCase()}',
                style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35),
              ),
            ),
            if (lignes.isEmpty)
              EtatVide(
                titre: 'Aucun record ne correspond',
                message: 'Change la recherche ou les filtres.',
                action: 'Effacer les filtres',
                onAction: () => setState(() {
                  _recherche.clear();
                  _groupes = {};
                  _quand = _Quand.tout;
                }),
              ),
          ]),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(Cotes.marge, 0, Cotes.marge, basDePage(context)),
            sliver: SliverList.separated(
              itemCount: lignes.length,
              separatorBuilder: (_, _) => const SizedBox(height: Cotes.gouttiere),
              itemBuilder: (context, i) => _CarteRecord(ligne: lignes[i], unite: u),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteRecord extends StatelessWidget {
  const _CarteRecord({required this.ligne, required this.unite});
  final LigneRecord ligne;
  final UnitePoids unite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = ligne;
    final b = l.bests;
    // Un gain qui s'écrirait « 0 » ne s'affiche pas.
    final gain = (l.gain ?? 0).abs() >= 0.05 ? l.gain : null;
    final nom = nomExercice(context, l.exerciseId);
    final principal = l.sansCharge
        ? (b.repsMax == null ? '-' : '${b.repsMax!.valeur.round()} rép.')
        : Fmt.poids(b.unRm?.valeur, unite);
    return Carte(
      padding: const EdgeInsets.all(15),
      semantique: '$nom, $principal',
      onTap: () => context.push('/progres/exercices/${Uri.encodeComponent(l.exerciseId)}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              iconeExercice(context, l.exerciseId, size: 55),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom, style: ts(17, FontWeight.w700, c.text, hauteur: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      // La date du record est dans les pastilles : ici, elle
                      // était coupée dès que le gain prenait de la place.
                      l.sansCharge ? 'Rép. max' : '1RM estimé',
                      style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(principal, style: ts(17, FontWeight.w700, c.text, hauteur: 1.3)),
                  if (gain != null)
                    Text(
                      '${Ecrit.ecartPoids(gain, unite)} · ${ProgresStats.pct(l.gainPct)}',
                      style: ts(13.5, FontWeight.w700, gain > 0 ? c.success : c.error, hauteur: 1.35),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (l.dateRecord != null) Pastille(Fmt.relatif(l.dateRecord!)),
              if (b.poidsMax != null) Pastille('Charge ${Ecrit.serie(b.poidsMax!.valeur, b.poidsMax!.reps, unite)}'),
              if (b.volumeSerie != null) Pastille('Série ${Ecrit.serie(b.volumeSerie!.poids, b.volumeSerie!.reps, unite)}'),
              if (b.repsMax != null && !l.sansCharge) Pastille('${b.repsMax!.valeur.round()} rép. max'),
              Pastille(Fmt.pluriel(l.nbSeances, 'séance')),
            ],
          ),
        ],
      ),
    );
  }
}
