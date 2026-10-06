import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../seance/seance_paths.dart';
import '../../commun/carte_jour.dart';
import '../../commun/elements.dart';
import '../../commun/palette.dart';
import '../../commun/traits.dart';
import '../logic/idees.dart' show sigleProgramme;
import '../logic/suggestion.dart';
import '../logic/vignettes.dart';
import 'carte_routine.dart';

/// Ouvre « Lancer la séance » du module séance pour cette routine.
void lancerRoutine(BuildContext context, Routine routine, {String? programId}) =>
    context.push(SeancePaths.apercu(routine.id, programId: programId));

/// Vignette d'une routine : sa carte de jour ou sa photo.
class VignetteRoutineVue extends StatelessWidget {
  const VignetteRoutineVue({super.key, required this.routine, required this.rang, this.taille = 68, this.fond, this.jour});

  final Routine routine;

  /// Rang dans la liste, pour la carte par défaut.
  final int rang;
  final double taille;
  final Color? fond;

  /// Force un jour (la suggestion montre le jour d'aujourd'hui).
  final int? jour;

  @override
  Widget build(BuildContext context) {
    final prefs = RoutinePrefs.of(context.read<Store>());
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final v = prefs.vignetteDe(routine.id);
        // Sans image : une tuile neutre, le sigle de la routine dessus.
        if (v != null && v.sans && jour == null) {
          return Tuile(
            taille: taille,
            fond: fond,
            rayon: taille * 0.222,
            child: Text(
              sigleProgramme(routine.nom),
              maxLines: 1,
              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: taille * 0.3, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: context.colors.text),
            ),
          );
        }
        final photo = v?.photo;
        if (photo != null && jour == null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(taille * 0.222),
            child: Image.file(
              File(photo),
              width: taille,
              height: taille,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => CarteJour(jour: jourDeVignette(null, rang), taille: taille, fond: fond),
            ),
          );
        }
        return CarteJour(jour: jour ?? jourDeVignette(v, rang), taille: taille, fond: fond);
      },
    );
  }
}

/// Ligne d'une routine : carte de jour, nom, nombre d'exercices, dernière
/// fois, bouton rond pour lancer et trois points.
class LigneRoutine extends StatelessWidget {
  const LigneRoutine({super.key, required this.routine, required this.rang, this.programId});

  final Routine routine;
  final int rang;

  /// Programme d'où la routine est lancée (progression, avancement).
  final String? programId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final derniere = context.watch<SessionRepo>().lastForRoutine(routine.id);
    return InkWell(
      onTap: () => lancerRoutine(context, routine, programId: programId),
      borderRadius: BorderRadius.circular(15),
      child: Row(
        children: [
          VignetteRoutineVue(routine: routine, rang: rang),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(routine.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.ligneForte(context)),
                Text(Fmt.pluriel(routine.exercices.length, 'exercice'), maxLines: 1, style: TexteEntrainer.detail(context)),
                if (derniere != null)
                  Row(
                    children: [
                      IconeTrait(Trait.horloge, size: 14, color: c.text2),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(derniereFois(derniere.debut), maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.detail(context)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          BoutonLancer(label: 'Lancer ${routine.nom}', onTap: () => lancerRoutine(context, routine, programId: programId)),
          const SizedBox(width: 5),
          Transform.translate(
            offset: const Offset(10, 0),
            child: BoutonNu(
              trait: Trait.points,
              label: 'Actions sur ${routine.nom}',
              largeur: 40,
              onTap: () => montrerActionsRoutine(context, routine, rang: rang, programId: programId),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Action { modifier, image, favori, dupliquer, deplacer, partager, supprimer }

/// Panneau du bas : les actions sur une routine.
Future<void> montrerActionsRoutine(BuildContext context, Routine routine, {required int rang, String? programId}) async {
  final exercices = context.read<ExerciseRepo>();
  final prefs = RoutinePrefs.of(context.read<Store>());
  final favori = prefs.estFavori(routine.id);
  final premier = routine.exercices.isEmpty ? null : exercices.byId(routine.exercices.first.exerciseId);
  final choix = await showPanneauBas<_Action>(
    context,
    entete: TexteNet(
      child: Row(
      children: [
        TuileExercice(premier, fond: context.colors.surface3),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(routine.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.ligneForte(context)),
              Text(Fmt.pluriel(routine.exercices.length, 'exercice'), style: TexteEntrainer.detail(context)),
            ],
          ),
        ),
      ],
      ),
    ),
    builder: (context) {
      Widget ligne(_Action a, Trait t, String label, {bool rouge = false, Widget? icone}) => LigneAction(
            icone: icone ?? IconeTrait(t, size: 25),
            label: label,
            destructif: rouge,
            onTap: () => Navigator.pop(context, a),
          );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ligne(_Action.modifier, Trait.crayon, 'Modifier'),
          ligne(_Action.image, Trait.image, 'Changer l’image'),
          ligne(_Action.favori, Trait.signet, favori ? 'Retirer des favoris' : 'Ajouter aux favoris', icone: Signet(plein: favori, taille: 25)),
          ligne(_Action.dupliquer, Trait.dupliquer, 'Dupliquer'),
          ligne(_Action.deplacer, Trait.deplacer, 'Déplacer dans un autre programme'),
          ligne(_Action.partager, Trait.partager, 'Partager'),
          ligne(_Action.supprimer, Trait.corbeille, 'Supprimer', rouge: true),
        ],
      );
    },
  );
  if (choix == null || !context.mounted) return;
  final repo = context.read<RoutineRepo>();
  final programmes = context.read<ProgramRepo>();
  switch (choix) {
    case _Action.modifier:
      context.push('/entrainer/routines/${routine.id}/modifier');
    case _Action.image:
      await montrerVignetteRoutine(context, routine, rang: rang);
    case _Action.favori:
      await prefs.basculerFavori(routine.id);
      if (context.mounted) Toasts.show(context, favori ? 'Retirée des favoris.' : 'Ajoutée aux favoris.');
    case _Action.dupliquer:
      final copie = await repo.duplicate(routine.id);
      await prefs.copier(routine.id, copie.id);
      // La copie rejoint les programmes de l'originale, juste après elle.
      for (final p in programmes.programs.where((p) => p.routineIds.contains(routine.id))) {
        final ids = [...p.routineIds]..insert(p.routineIds.lastIndexOf(routine.id) + 1, copie.id);
        await programmes.save(p.copyWith(routineIds: ids));
      }
      if (context.mounted) Toasts.success(context, '« ${copie.nom} » créée.');
    case _Action.deplacer:
      await _deplacer(context, routine);
    case _Action.partager:
      await partagerRoutine(context, routine);
    case _Action.supprimer:
      await _supprimer(context, routine);
  }
}

/// Programmes après le passage d'une routine dans [cible] : elle quitte les
/// autres et s'ajoute à la fin de celui-ci. Rend seulement ceux qui changent.
List<Program> deplacerRoutine(List<Program> programmes, String routineId, String cible) => [
      for (final p in programmes)
        if (p.id == cible && !p.routineIds.contains(routineId))
          p.copyWith(routineIds: [...p.routineIds, routineId])
        else if (p.id != cible && p.routineIds.contains(routineId))
          p.copyWith(routineIds: p.routineIds.where((id) => id != routineId).toList()),
    ];

Future<void> _deplacer(BuildContext context, Routine routine) async {
  final programmes = context.read<ProgramRepo>();
  final repo = context.read<RoutineRepo>();
  final liste = programmes.programs;
  if (liste.isEmpty) {
    Toasts.show(context, 'Crée d’abord un programme pour y ranger tes routines.');
    return;
  }
  final cible = await showPanneauBas<String>(
    context,
    titre: 'Déplacer « ${routine.nom} »',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in liste)
          ChoixPanneau(
            label: p.nom,
            detail: Fmt.pluriel(p.routineIds.toSet().where((id) => repo.byId(id) != null).length, 'routine'),
            selected: p.routineIds.contains(routine.id),
            onTap: () => Navigator.pop(context, p.id),
          ),
      ],
    ),
  );
  if (cible == null || !context.mounted) return;
  final changes = deplacerRoutine(liste, routine.id, cible);
  for (final p in changes) {
    await programmes.save(p);
  }
  if (context.mounted) {
    Toasts.show(context, changes.isEmpty ? 'Elle y est déjà.' : 'Routine déplacée dans « ${programmes.byId(cible)?.nom ?? 'le programme'} ».');
  }
}

Future<void> _supprimer(BuildContext context, Routine routine) async {
  final repo = context.read<RoutineRepo>();
  final programmes = context.read<ProgramRepo>();
  final prefs = RoutinePrefs.of(context.read<Store>());
  final touches = programmes.programs.where((p) => p.routineIds.contains(routine.id)).toList();
  final ok = await showConfirmDialog(
    context,
    title: 'Supprimer « ${routine.nom} » ?',
    message: touches.isEmpty
        ? 'L’historique de tes séances est conservé.'
        : 'Elle sera retirée de ${touches.map((p) => '« ${p.nom} »').join(', ')}. L’historique de tes séances est conservé.',
    confirmLabel: 'Supprimer',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  final vignette = prefs.vignetteDe(routine.id);
  final favori = prefs.estFavori(routine.id);
  await repo.delete(routine.id);
  for (final p in touches) {
    await programmes.save(p.copyWith(routineIds: p.routineIds.where((id) => id != routine.id).toList()));
  }
  await prefs.oublier(routine.id);
  if (!context.mounted) return;
  Toasts.show(
    context,
    'Routine supprimée.',
    actionLabel: 'Annuler',
    onAction: () async {
      await repo.saveAll([routine]);
      for (final p in touches) {
        await programmes.save(p);
      }
      if (vignette?.jour != null) await prefs.choisirJour(routine.id, vignette!.jour!);
      if (vignette?.photo != null) await prefs.choisirPhoto(routine.id, vignette!.photo!);
      if (favori) await prefs.basculerFavori(routine.id);
    },
  );
}

/// Panneau du bas : choisir la vignette d'une routine, une des sept cartes
/// de jour ou une photo personnelle.
Future<void> montrerVignetteRoutine(BuildContext context, Routine routine, {required int rang}) {
  final prefs = RoutinePrefs.of(context.read<Store>());
  return showPanneauBas<void>(
    context,
    titre: 'Vignette de la routine',
    builder: (context) => _ChoixVignette(routine: routine, prefs: prefs, depart: jourDeVignette(prefs.vignetteDe(routine.id), rang)),
  );
}

class _ChoixVignette extends StatefulWidget {
  const _ChoixVignette({required this.routine, required this.prefs, required this.depart});

  final Routine routine;
  final RoutinePrefs prefs;
  final int depart;

  @override
  State<_ChoixVignette> createState() => _ChoixVignetteState();
}

class _ChoixVignetteState extends State<_ChoixVignette> {
  late int _jour = widget.depart;

  Future<void> _photo() async {
    final nav = Navigator.of(context);
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
      if (f == null) return;
      // La photo est recopiée dans le dossier de l'appli pour survivre au ménage de la galerie.
      final dossier = await widget.prefs.store.mediaDir();
      final cible = '${dossier.path}${Platform.pathSeparator}routine_${widget.routine.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(f.path).copy(cible);
      await widget.prefs.choisirPhoto(widget.routine.id, cible);
      nav.pop();
    } catch (_) {
      if (mounted) Toasts.error(context, 'Impossible d’ouvrir tes photos.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TexteNet(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Surtitre('Jours de la semaine'),
        const SizedBox(height: 12.5),
        LayoutBuilder(builder: (context, box) {
          const ecart = 12.5;
          final cote = (box.maxWidth - 3 * ecart) / 4;
          return Wrap(
            spacing: ecart,
            runSpacing: ecart,
            children: [
              for (var j = 1; j <= 7; j++)
                GestureDetector(
                  onTap: () => setState(() => _jour = j),
                  child: CarteJour(jour: j, taille: cote, fond: c.surface2, choisie: j == _jour, fondAnneau: c.surface2),
                ),
              Tooltip(
                message: 'Choisir une photo',
                child: Semantics(
                  button: true,
                  label: 'Choisir une photo',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: _photo,
                    child: Tuile(taille: cote, fond: c.surface3, rayon: cote * 0.222, child: IconeTrait(Trait.appareil, size: 27.5, color: c.text)),
                  ),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 14),
        Text('La dernière case ouvre tes photos pour mettre ta propre image.', style: TexteEntrainer.detail(context)),
        const SizedBox(height: 14),
        BoutonPrincipal(
          label: 'Choisir « ${joursAbreges[_jour - 1]} »',
          onPressed: () async {
            final nav = Navigator.of(context);
            await widget.prefs.choisirJour(widget.routine.id, _jour);
            nav.pop();
          },
        ),
        // Ni photo ni jour : la routine garde une tuile neutre à son sigle.
        const SizedBox(height: 10),
        BoutonSecondaire(
          label: 'Aucune image',
          fond: c.surface3,
          onPressed: () async {
            final nav = Navigator.of(context);
            await widget.prefs.choisirSansImage(widget.routine.id);
            nav.pop();
          },
        ),
      ],
      ),
    );
  }
}
