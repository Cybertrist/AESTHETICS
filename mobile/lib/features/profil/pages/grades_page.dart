import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/career.dart';
import '../data/grades.dart';
import '../widgets/ecusson.dart';
import '../widgets/maquette.dart';
import '../../progres/logic/objectifs.dart';
import '../../progres/ui/objectifs_section.dart';

/// Les grades de l'historique en cours (séances, routines, objectif du profil).
Grades gradesDe(BuildContext context, {CareerStats? stats}) {
  final sessions = context.watch<SessionRepo>().sessions;
  return Grades.from(
    sessions,
    nbRoutines: context.watch<RoutineRepo>().routines.length,
    nbRecords: (stats ?? CareerStats.from(sessions)).nbRecords,
    objectifSemaine: context.watch<ProfileRepo>().profile?.joursParSemaine ?? 4,
    premierJour: context.watch<SettingsRepo>().settings.premierJourSemaine,
  );
}

/// Profil > Grades : tous les grades en écussons, puis les étapes de séances.
class GradesPage extends StatelessWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final grades = gradesDe(context);
    final etape = grades.etape;
    // Les étapes atteintes les plus récentes, puis les trois suivantes.
    final debut = (etape.niveau - 3).clamp(0, Grades.etapes.length);
    final fin = (etape.niveau + 3).clamp(0, Grades.etapes.length);

    return PageMaquette(
      titre: 'Badges',
      sousTitre: '${grades.gagnes} sur ${Grade.values.length} gagnés',
      enfants: [
        Bloc(
          haut: 6,
          child: _Grille(
            enfants: [
              for (final g in Grade.values)
                _Case(
                  ecusson: Ecusson.grade(g, grades.de(g)),
                  nom: g.nom,
                  detail: grades.de(g).gagne ? '${grades.de(g).niveau} sur ${g.paliers.length}' : 'à gagner',
                  gagne: grades.de(g).gagne,
                  onTap: () => montrerGrade(context, g, grades.de(g)),
                ),
            ],
          ),
        ),
        const _Secrets(),
        Bloc(haut: 12, bas: 4, child: Text('Étapes importantes', style: txt(15, FontWeight.w700, c.text))),
        Bloc(
          haut: 6,
          child: _Grille(
            enfants: [
              for (var i = debut; i < fin; i++)
                _Case(
                  ecusson: Ecusson.etape(Grades.etapes[i], i, gagne: i < etape.niveau),
                  nom: Fmt.pluriel(Grades.etapes[i], 'séance'),
                  detail: i < etape.niveau ? 'atteint' : (i == etape.niveau ? 'encore ${Grades.etapes[i] - grades.seances}' : 'à venir'),
                  gagne: i < etape.niveau,
                  onTap: () => montrerEtape(context, i, etape),
                ),
            ],
          ),
        ),
        SizedBox(height: e(18)),
      ],
    );
  }
}

/// Les six badges secrets : un par type d'objectif tenu, « Doublé » (deux
/// séances le même jour) et « Retour gagnant » (reprise après trente jours).
/// Cachés sous « ??? » tant qu'ils ne sont pas gagnés.
class _Secrets extends StatefulWidget {
  const _Secrets();

  @override
  State<_Secrets> createState() => _SecretsState();
}

class _SecretsState extends State<_Secrets> {
  late final Future<ObjectifsRepo> _repo = ObjectifsRepo.ensure(context.read<Store>());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions;
    return FutureBuilder<ObjectifsRepo>(
      future: _repo,
      builder: (context, snap) {
        final parType = Objectifs.atteintsParType(snap.data?.liste ?? const []);
        final secrets = <({String nom, Color couleur, PictoGrade picto, int n, String unite, String comment, String indice})>[
          for (final t in [TypeObjectif.poids, TypeObjectif.charge, TypeObjectif.seances, TypeObjectif.mensuration])
            (
              nom: badgeObjectif(t).nom,
              couleur: badgeObjectif(t).couleur,
              picto: badgeObjectif(t).picto,
              n: parType[t] ?? 0,
              unite: 'objectif',
              comment: switch (t) {
                TypeObjectif.poids => 'Tu t’es fixé un poids de corps dans Progrès > Objectifs, et tu l’as atteint.',
                TypeObjectif.charge => 'Tu t’es fixé une charge sur un exercice dans Progrès > Objectifs, et tu l’as soulevée.',
                TypeObjectif.seances => 'Tu t’es fixé un nombre de séances par semaine dans Progrès > Objectifs, et tu l’as tenu.',
                TypeObjectif.mensuration => 'Tu t’es fixé une mensuration dans Progrès > Objectifs, et tu l’as atteinte.',
              },
              indice: 'Il se gagne en tenant un objectif que tu t’es fixé toi-même.',
            ),
          (nom: 'Doublé', couleur: const Color(0xFF2FCF55), picto: PictoGrade.epee, n: Objectifs.joursDoubles(sessions), unite: 'jour', comment: 'Deux séances le même jour. Chaque jour où tu doubles compte pour un.', indice: 'Une seule séance par jour ne suffit pas.'),
          (nom: 'Retour gagnant', couleur: const Color(0xFF1FA8FF), picto: PictoGrade.aube, n: Objectifs.retours(sessions), unite: 'reprise', comment: 'Une séance après au moins trente jours sans t’entraîner. Chaque reprise compte pour une.', indice: 'Il récompense ceux qui reviennent après une longue pause.'),
        ];
        final gagnes = secrets.where((x) => x.n > 0).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Bloc(
              haut: 12,
              bas: 4,
              child: Row(
                children: [
                  Expanded(child: Text('Secrets', style: txt(15, FontWeight.w700, c.text))),
                  Text('$gagnes sur ${secrets.length}', style: txt(11.5, FontWeight.w600, c.text2)),
                ],
              ),
            ),
            Bloc(
              haut: 6,
              child: _Grille(
                enfants: [
                  for (final x in secrets)
                    _Case(
                      ecusson: Ecusson(couleur: x.couleur, picto: x.picto, nombre: x.n, gagne: x.n > 0),
                      nom: x.n > 0 ? x.nom : '???',
                      detail: x.n > 0 ? Fmt.pluriel(x.n, x.unite) : 'secret',
                      gagne: x.n > 0,
                      // Gagné : comment il l'a été. Verrouillé : un indice seulement.
                      onTap: () => showPanneauBas<void>(
                        context,
                        titre: x.n > 0 ? x.nom : 'Badge secret',
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Ecusson(couleur: x.couleur, picto: x.picto, nombre: x.n, gagne: x.n > 0, largeur: e(132)),
                            SizedBox(height: e(6)),
                            if (x.n > 0) ...[
                              Text(Fmt.pluriel(x.n, x.unite), style: txt(13, FontWeight.w700, c.text)),
                              SizedBox(height: e(6)),
                            ],
                            Text(x.n > 0 ? x.comment : 'Indice : ${x.indice}', textAlign: TextAlign.center, style: txt(11.5, FontWeight.w400, c.text2, interligne: 1.45)),
                            SizedBox(height: e(10)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Trois écussons par rangée.
class _Grille extends StatelessWidget {
  const _Grille({required this.enfants});
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, contraintes) {
          final largeur = contraintes.maxWidth / 3;
          return Wrap(
            runSpacing: e(14),
            children: [for (final w in enfants) SizedBox(width: largeur, child: w)],
          );
        },
      );
}

class _Case extends StatelessWidget {
  const _Case({required this.ecusson, required this.nom, required this.detail, required this.gagne, this.onTap});
  final Widget ecusson;
  final String nom;
  final String detail;
  final bool gagne;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      label: '$nom, $detail',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ecusson,
            SizedBox(height: e(2)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: e(3)),
              child: Text(nom, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(10.5, FontWeight.w700, gagne ? c.text : c.text2, interligne: 1.2)),
            ),
            Text(detail, style: txt(9.5, FontWeight.w600, c.text2)),
          ],
        ),
      ),
    );
  }
}

/// Le détail d'un grade : son écusson en grand, ce qu'il récompense,
/// l'avancée vers le niveau suivant et ses paliers.
Future<void> montrerGrade(BuildContext context, Grade g, Avancee a) {
  return showPanneauBas<void>(
    context,
    titre: g.nom,
    builder: (context) {
      final c = context.colors;
      final prochain = a.prochain;
      final compte = Fmt.pluriel(a.valeur, g.unite);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ecusson.grade(g, a, largeur: e(132)),
          SizedBox(height: e(6)),
          Text(g.description, textAlign: TextAlign.center, style: txt(11.5, FontWeight.w400, c.text2)),
          SizedBox(height: e(12)),
          Text(a.gagne ? 'Niveau ${a.niveau} · $compte' : compte, style: txt(13, FontWeight.w700, c.text)),
          SizedBox(height: e(7)),
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(e(4)),
              child: LinearProgressIndicator(value: a.part, minHeight: e(6.5), backgroundColor: PanneauBas.filet, color: c.text),
            ),
          ),
          SizedBox(height: e(6)),
          Text(
            prochain == null ? 'Niveau maximum atteint' : 'Encore ${Fmt.pluriel(prochain - a.valeur, g.unite)} pour le niveau ${a.niveau + 1}',
            style: txt(10.5, FontWeight.w400, c.text2),
          ),
          SizedBox(height: e(12)),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: e(5),
            runSpacing: e(5),
            children: [
              for (final p in g.paliers)
                Container(
                  width: e(34),
                  padding: EdgeInsets.symmetric(vertical: e(5.5)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: a.valeur >= p ? c.bouton : PanneauBas.filet, borderRadius: BorderRadius.circular(e(10))),
                  child: Text('$p', style: txt(10, FontWeight.w700, a.valeur >= p ? c.onBouton : c.text2)),
                ),
            ],
          ),
          SizedBox(height: e(6)),
        ],
      );
    },
  );
}

/// Le détail d'une étape : son bouclier en grand, où tu en es, et la jauge
/// vers la prochaine étape à atteindre.
Future<void> montrerEtape(BuildContext context, int rang, Avancee a) {
  final seances = Grades.etapes[rang];
  final atteinte = rang < a.niveau;
  return showPanneauBas<void>(
    context,
    titre: Fmt.pluriel(seances, 'séance'),
    builder: (context) {
      final c = context.colors;
      final prochain = a.prochain;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ecusson.etape(seances, rang, gagne: atteinte, largeur: e(132)),
          SizedBox(height: e(6)),
          Text(
            atteinte ? 'Étape atteinte' : 'Encore ${Fmt.pluriel(seances - a.valeur, 'séance')} pour cette étape',
            textAlign: TextAlign.center,
            style: txt(11.5, FontWeight.w400, c.text2),
          ),
          SizedBox(height: e(12)),
          Text('${Fmt.pluriel(a.valeur, 'séance')} au total', style: txt(13, FontWeight.w700, c.text)),
          SizedBox(height: e(7)),
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(e(4)),
              child: LinearProgressIndicator(value: a.part, minHeight: e(6.5), backgroundColor: PanneauBas.filet, color: c.text),
            ),
          ),
          SizedBox(height: e(6)),
          Text(
            prochain == null ? 'Toutes les étapes sont atteintes' : 'Encore ${Fmt.pluriel(prochain - a.valeur, 'séance')} pour l’étape des $prochain',
            style: txt(10.5, FontWeight.w400, c.text2),
          ),
          SizedBox(height: e(8)),
        ],
      );
    },
  );
}

/// Carte « Grades » du profil : les trois plus hauts, et l'accès à la page.
class VitrineGrades extends StatelessWidget {
  const VitrineGrades({super.key, required this.grades, required this.onTout, this.largeur});
  final Grades grades;

  /// Largeur d'un écusson (66 de la maquette par défaut).
  final double? largeur;
  final VoidCallback onTout;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vitrine = grades.vitrine();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toute la ligne du titre ouvre la liste, comme la carte en dessous.
        Semantics(
          button: true,
          label: 'Voir tous les badges',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTout,
            borderRadius: BorderRadius.circular(e(8)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(e(2), e(5), e(2), e(7)),
              child: Row(
                children: [
                  Expanded(child: Text('Badges', style: txt(15, FontWeight.w700, c.text))),
                  Text('Voir tout', style: txt(11.5, FontWeight.w600, c.text2)),
                  SizedBox(width: e(3)),
                  IconeTrait(Trace.chevron, taille: e(11), couleur: c.text2),
                ],
              ),
            ),
          ),
        ),
        Carte(
          onTap: onTout,
          padding: EdgeInsets.symmetric(vertical: e(7)),
          child: vitrine.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: e(14), vertical: e(6)),
                  child: Text('Ton premier badge arrive avec ta première séance.', style: txt(11.5, FontWeight.w400, c.text2)),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [for (final g in vitrine) Ecusson.grade(g, grades.de(g), largeur: largeur ?? e(66))],
                ),
        ),
      ],
    );
  }
}
