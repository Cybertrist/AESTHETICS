import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import '../logic/idees.dart';
import '../logic/program_plan.dart';
import '../logic/program_templates.dart';
import '../logic/routine_stats.dart';
import '../widgets/couverture.dart';

/// Idées de programmes : des programmes prêts à l'emploi à ajouter à la
/// bibliothèque. Les classiques, puis ceux qui collent au profil.
class IdeesPage extends StatefulWidget {
  const IdeesPage({super.key});

  @override
  State<IdeesPage> createState() => _IdeesPageState();
}

class _IdeesPageState extends State<IdeesPage> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final profil = context.watch<ProfileRepo>().profile;
    final actif = context.watch<ProgramRepo>().active;
    final classiques = ideesClassiques().where((i) => ideeCorrespond(i.idee, _recherche)).toList();
    final recommandees = ideesRecommandees(profil: profil, actif: actif).where((i) => ideeCorrespond(i.idee, _recherche)).toList();
    final enRecherche = _recherche.trim().isNotEmpty;
    final trouvees = !enRecherche
        ? const <IdeeClassee>[]
        : [
            for (final i in ideesProgrammes)
              if (ideeCorrespond(i, _recherche)) (idee: i, detail: '${rythmeIdee(i.modele)} · ${i.modele.niveau.label}'),
          ];
    final rayons = [
      for (final r in Rayon.values) (r, ideesDuRayon(r).where((i) => ideeCorrespond(i.idee, _recherche)).toList()),
    ];

    Widget rangee(String titre, List<IdeeClassee> idees) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(margeEcran, 12.5, margeEcran, 15),
              child: Text(titre, style: TexteEntrainer.titreSection(context)),
            ),
            SizedBox(
              height: _CarteIdee.hauteur(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: margeEcran),
                itemCount: idees.length,
                separatorBuilder: (_, _) => const SizedBox(width: 15),
                itemBuilder: (context, i) => _CarteIdee(
                  idee: idees[i],
                  onTap: () => context.push('/entrainer/programmes/modele/${idees[i].idee.modeleId}'),
                ),
              ),
            ),
          ],
        );

    return PageEntrainer(
      entete: const EnTetePage(titre: 'Idées de programmes'),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(margeEcran, 0, margeEcran, 12.5),
            child: RecherchePilule(hint: 'Rechercher un programme', onChanged: (q) => setState(() => _recherche = q)),
          ),
          if (!enRecherche) ...[
            if (classiques.isNotEmpty) rangee('Les classiques', classiques),
            if (recommandees.isNotEmpty) rangee('Recommandé pour toi', recommandees),
            for (final (r, idees) in rayons)
              if (idees.isNotEmpty) rangee(r.label, idees),
          ] else if (trouvees.isNotEmpty)
            // En recherche : une seule grille, chaque programme une fois.
            Padding(
              padding: const EdgeInsets.fromLTRB(margeEcran, 12.5, margeEcran, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Fmt.pluriel(trouvees.length, 'programme'), style: TexteEntrainer.titreSection(context)),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 15,
                    runSpacing: 12,
                    children: [
                      for (final i in trouvees)
                        SizedBox(
                          height: _CarteIdee.hauteur(context),
                          child: _CarteIdee(idee: i, onTap: () => context.push('/entrainer/programmes/modele/${i.idee.modeleId}')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (enRecherche ? trouvees.isEmpty : (classiques.isEmpty && recommandees.isEmpty && rayons.every((r) => r.$2.isEmpty)))
            Vide(trait: Trait.loupe, titre: 'Aucune idée pour « ${_recherche.trim()} »', message: 'Essaie un autre mot : force, maison, split...'),
        ],
      ),
    );
  }
}

class _CarteIdee extends StatelessWidget {
  const _CarteIdee({required this.idee, required this.onTap});

  final IdeeClassee idee;
  final VoidCallback onTap;

  static const _nom = TextStyle(fontFamily: AppTokens.fontUi, fontSize: 16, height: 1.25, fontWeight: FontWeight.w700);
  static TextStyle _detail(BuildContext context) => TexteEntrainer.detail(context).copyWith(fontSize: 13.8, height: 1.35);

  /// Deux lignes de nom et deux lignes de détail, à la taille de police du téléphone.
  static double _hauteurTexte(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) * (2 * 16 * 1.25 + 2 * 13.8 * 1.35) + 4;

  /// Hauteur d'une carte : la couverture, puis le texte.
  static double hauteur(BuildContext context) => 172 + 10 + _hauteurTexte(context);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 172,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CouvertureIdee(idee.idee),
              const SizedBox(height: 10),
              // Hauteur réservée : les cartes d'une rangée restent alignées,
              // que le nom tienne sur une ligne ou sur deux.
              SizedBox(
                height: _hauteurTexte(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(idee.idee.titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: _nom.copyWith(color: c.text)),
                    const SizedBox(height: 2),
                    Text(idee.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: _detail(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Détail d'une idée : sa couverture, ce qu'elle contient, et le bouton
/// qui l'ajoute à la bibliothèque.
class ModelePage extends StatelessWidget {
  const ModelePage({super.key, required this.modeleId});
  final String modeleId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = modeleParId(modeleId);
    final idee = ideeParModele(modeleId);
    if (m == null || idee == null) {
      return PageEntrainer(
        entete: const EnTetePage(titre: 'Idée de programme'),
        child: Vide(
          trait: Trait.loupe,
          titre: 'Programme introuvable',
          action: 'Voir les idées',
          onAction: () => context.go('/entrainer/programmes/idees'),
        ),
      );
    }
    final exRepo = context.watch<ExerciseRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    if (!exRepo.loaded) {
      return PageEntrainer(entete: EnTetePage(titre: idee.titre), child: const SkeletonList());
    }
    final routines = [for (final r in m.routines) routineDepuisModele(r, exRepo)];
    final gris = TexteEntrainer.detail(context).copyWith(fontSize: 15);

    return PageEntrainer(
      entete: EnTetePage(titre: idee.titre),
      bas: BoutonPrincipal(label: 'Ajouter à ma bibliothèque', onPressed: () => _ajouter(context, m)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(margeEcran, 6, margeEcran, 20),
        children: [
          Center(child: CouvertureIdee(idee, cote: 215)),
          const SizedBox(height: 20),
          Text(m.nom, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 25, height: 1.25, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 4),
          Text('${m.joursParSemaine} jours par semaine · ${m.semaines} semaines · ${m.niveau.label}', style: gris),
          const SizedBox(height: 14),
          Text(m.description, style: gris.copyWith(color: c.text, height: 1.45)),
          const SizedBox(height: 14),
          Carte(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Surtitre('Progression'),
                const SizedBox(height: 6),
                Text(m.progression.label, style: TexteEntrainer.ligne(context)),
                const SizedBox(height: 2),
                Text(m.progression.description, style: gris.copyWith(fontSize: 13.8)),
                if (m.decharge > 0) ...[
                  const SizedBox(height: 6),
                  Text('Une semaine plus légère toutes les ${m.decharge} semaines.', style: gris.copyWith(fontSize: 13.8)),
                ],
                for (final conseil in m.conseils) ...[
                  const SizedBox(height: 6),
                  Text(conseil, style: gris.copyWith(fontSize: 13.8)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 25),
          Text('Les séances', style: TexteEntrainer.titreSection(context)),
          const SizedBox(height: 12.5),
          for (final r in routines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Carte(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(r.nom, style: TexteEntrainer.ligneForte(context))),
                        Text(Fmt.duree(Duration(minutes: r.dureeEstimeeMin)), style: gris.copyWith(fontSize: 13.8)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final re in r.exercices)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(exRepo.nameOf(re.exerciseId), maxLines: 1, overflow: TextOverflow.ellipsis, style: gris.copyWith(color: c.text)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              resumeSeries(re, exRepo.byId(re.exerciseId), unite).split(' · ').first,
                              style: gris.copyWith(fontFeatures: AppTokens.tabular),
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

  Future<void> _ajouter(BuildContext context, ModeleProgramme m) async {
    final dejaActif = context.read<ProgramRepo>().active;
    final noms = {for (final p in context.read<ProgramRepo>().programs) p.nom};
    final nom = nomLibre(m.nom, noms);
    final suivre = await showPanneauBas<bool>(
      context,
      titre: 'Ajouter « ${m.nom} »',
      builder: (context) => _Ajout(modele: m, dejaActif: dejaActif?.nom, copie: nom == m.nom ? null : nom),
    );
    if (suivre == null || !context.mounted) return;
    try {
      final prog = await creerProgrammeDepuisModele(
        modele: m,
        exercices: context.read<ExerciseRepo>(),
        routines: context.read<RoutineRepo>(),
        programmes: context.read<ProgramRepo>(),
        plans: ProgramPlanRepo.of(context.read<Store>()),
        activer: suivre,
        nom: nom,
      );
      if (!context.mounted) return;
      Toasts.success(context, '« ${prog.nom} » est dans ta bibliothèque.');
      context.pushReplacement('/entrainer/programmes/${prog.id}');
    } catch (_) {
      if (context.mounted) Toasts.error(context, 'Impossible d’ajouter le programme.');
    }
  }
}

/// Contenu du panneau d'ajout : ce qui sera créé, et le choix de le suivre.
class _Ajout extends StatefulWidget {
  const _Ajout({required this.modele, this.dejaActif, this.copie});

  final ModeleProgramme modele;
  final String? dejaActif;

  /// Nom donné au programme quand celui du modèle est déjà dans la bibliothèque.
  final String? copie;

  @override
  State<_Ajout> createState() => _AjoutState();
}

class _AjoutState extends State<_Ajout> {
  late bool _suivre = widget.dejaActif == null;

  @override
  Widget build(BuildContext context) {
    final m = widget.modele;
    return TexteNet(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.copie == null
              ? 'Le programme et ses ${m.routines.length} routines seront créés. Tu pourras tout modifier ensuite.'
              : '« ${m.nom} » est déjà dans ta bibliothèque. Un second programme, « ${widget.copie} », sera créé avec ses ${m.routines.length} routines.',
          style: TexteEntrainer.detail(context).copyWith(fontSize: 15),
        ),
        const SizedBox(height: 14),
        ChoixPanneau(
          label: 'Le suivre maintenant',
          detail: widget.dejaActif == null ? null : 'à la place de ${widget.dejaActif}',
          selected: _suivre,
          onTap: () => setState(() => _suivre = true),
        ),
        ChoixPanneau(label: 'L’ajouter sans le suivre', selected: !_suivre, onTap: () => setState(() => _suivre = false)),
        const SizedBox(height: 6),
        BoutonPrincipal(label: 'Ajouter à ma bibliothèque', onPressed: () => Navigator.pop(context, _suivre)),
      ],
      ),
    );
  }
}
