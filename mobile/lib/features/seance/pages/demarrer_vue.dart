import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/routines/routines.dart' show routinePrevue;
import '../logic/lancement.dart';
import '../seance_paths.dart';
import '../widgets/habillage.dart';
import '../widgets/pages.dart';

/// Écran « Démarrer une séance » : séance libre, programme, routines, récentes.
class DemarrerVue extends StatelessWidget {
  const DemarrerVue({super.key});

  Future<void> _vide(BuildContext context) async {
    await Lancement.vide(context.read<SessionRepo>());
  }

  Future<void> _routine(BuildContext context, Routine r, {String? programId}) async {
    if (r.exercices.isEmpty) {
      Toasts.show(context, 'Cette routine est vide : la séance démarre sans exercice.');
    }
    final prevue = routinePrevue(context, r, programId: programId);
    await Lancement.routine(context.read<SessionRepo>(), prevue.routine, programId: programId);
  }

  Future<void> _refaire(BuildContext context, WorkoutSession s) async {
    await Lancement.refaire(context.read<SessionRepo>(), s);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final routines = context.watch<RoutineRepo>().routines;
    final prog = context.watch<ProgramRepo>().active;
    final repo = context.watch<SessionRepo>();
    final exos = context.watch<ExerciseRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final prochaineId = prog?.prochaineRoutineId;
    final prochaine = prochaineId == null ? null : context.read<RoutineRepo>().byId(prochaineId);
    final recentes = repo.sessions.take(3).toList();

    String sousTitre(Routine r) {
      final last = repo.lastForRoutine(r.id);
      return [
        Fmt.pluriel(r.exercices.length, 'exercice'),
        if (r.dureeEstimeeMin > 0) '${r.dureeEstimeeMin} min',
        last == null ? 'jamais faite' : Fmt.ilYa(last.debut),
      ].join(' · ');
    }

    final avecProgramme = prog != null && prochaine != null;
    final gris = TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), height: 1.4, color: c.text2, fontFeatures: AppTokens.tabular);
    final titre = TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(16), height: 1.3, fontWeight: FontWeight.w700, color: c.text);
    Widget carte(List<Widget> enfants) => Container(
          padding: EdgeInsets.all(k(14)),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(18))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: enfants),
        );
    final ecart = SizedBox(height: k(18));

    return PageSeance(
      titre: 'Démarrer une séance',
      fin: BoutonRond(label: 'Historique', nu: true, onTap: () => context.push(SeancePaths.historique), child: Trait(IconeSeance.calendrier, size: k(20))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margeSeance, k(6), margeSeance, k(24)),
        children: [
          if (avecProgramme) ...[
            carte([
              Surtitre('Programme · semaine ${prog.semaineCourante + 1} sur ${prog.dureeSemaines}'),
              SizedBox(height: k(6)),
              Text(prochaine.nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: titre.copyWith(fontSize: k(20))),
              Text('${prog.nom} · ${sousTitre(prochaine)}', style: gris),
              SizedBox(height: k(12)),
              ClipRRect(
                borderRadius: AppTokens.radiusPill,
                child: LinearProgressIndicator(value: prog.avancement.clamp(0.0, 1.0), minHeight: k(5), backgroundColor: c.surface3, color: c.text),
              ),
              SizedBox(height: k(14)),
              BoutonSeance(
                label: 'Démarrer ${prochaine.nom}',
                fond: c.bouton,
                encre: c.onBouton,
                onTap: () => _routine(context, prochaine, programId: prog.id),
              ),
            ]),
            SizedBox(height: k(8)),
          ],
          carte([
            Text('Séance libre', style: titre),
            Text('Ajoute tes exercices au fil de l\'eau.', style: gris),
            SizedBox(height: k(12)),
            // Un seul bouton blanc par écran : celui du programme s'il y en a un.
            BoutonSeance(
              label: 'Démarrer une séance vide',
              fond: avecProgramme ? c.surface2 : c.bouton,
              encre: avecProgramme ? c.text : c.onBouton,
              onTap: () => _vide(context),
            ),
          ]),
          ecart,
          const Surtitre('Mes routines'),
          SizedBox(height: k(8)),
          if (routines.isEmpty) ...[
            Text('Aucune routine pour l\'instant. Crée-en une pour relancer tes séances en un geste.', style: gris),
            Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(-k(6), 0),
                child: LienTexte(label: 'Créer une routine', onTap: () => context.go('/entrainer')),
              ),
            ),
          ] else
            for (final r in routines)
              Padding(
                padding: EdgeInsets.only(bottom: k(8)),
                child: LigneCarte(
                  tete: const CarreIcone(child: IconeHaltere()),
                  titre: r.nom,
                  detail: sousTitre(r),
                  onTap: () => context.push(SeancePaths.apercu(r.id)),
                  fin: BoutonRond(
                    label: 'Démarrer ${r.nom}',
                    onTap: () => _routine(context, r),
                    child: Padding(
                      padding: EdgeInsets.only(left: k(2)),
                      child: Trait(IconeSeance.lecture, size: k(14), plein: true),
                    ),
                  ),
                ),
              ),
          if (recentes.isNotEmpty) ...[
            ecart,
            const Surtitre('Refaire une séance'),
            SizedBox(height: k(8)),
            for (final s in recentes)
              Padding(
                padding: EdgeInsets.only(bottom: k(8)),
                child: LigneCarte(
                  tete: PastilleTypeSeance(s.type, taille: k(36)),
                  titre: s.nom,
                  detail: [
                    Fmt.relatif(s.debut),
                    Fmt.pluriel(s.exercices.length, 'exercice'),
                    if (s.volume > 0) volumeSeance(s.volume, unite),
                  ].join(' · '),
                  chevron: false,
                  fin: Padding(
                    padding: EdgeInsets.only(right: k(8)),
                    child: Trait(IconeSeance.refaire, size: k(18), color: c.text2),
                  ),
                  onTap: () => _refaire(context, s),
                ),
              ),
          ],
          if (!exos.loaded) ...[
            SizedBox(height: k(12)),
            Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.text2)),
                SizedBox(width: k(10)),
                Expanded(child: Text('Chargement de la bibliothèque d\'exercices...', style: gris)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
