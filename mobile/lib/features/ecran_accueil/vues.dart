import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/data.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/body/body_map.dart';
import '../../core/ui/ui.dart';
import '../aujourdhui/logic/resume_jour.dart' show ResumeSemaine;
import '../aujourdhui/pages/serie_page.dart' show Flamme;
import '../aujourdhui/widgets/accueil.dart' show CarteCetteSemaine;
import '../entrainer/routines/logic/suggestion.dart';
import '../entrainer/routines/widgets/ligne_routine.dart' show VignetteRoutineVue;
import '../progres/logic/tableau.dart';
import '../progres/ui/communs.dart' show AnneauRecup;
import '../sante/recuperation/recup_calcul.dart';
import '../seance/seance_paths.dart';

/// Les widgets de l'écran d'accueil du téléphone. L'appli les dessine avec
/// ses propres composants (mêmes icônes, mêmes couleurs), l'atelier les
/// photographie, et Android affiche la photo.
enum WidgetEcran {
  lancer('lancer', 'WidgetLancer', Size(360, 92)),
  semaine('semaine', 'WidgetSemaine', Size(360, 0)),
  serie('serie', 'WidgetSerie', Size(360, 170)),
  recuperation('recup', 'WidgetRecuperation', Size(360, 170)),
  mois('mois', 'WidgetMois', Size(360, 0)),
  record('record', 'WidgetRecord', Size(190, 190)),
  recordLarge('recordl', 'WidgetRecordLarge', Size(370, 180));

  const WidgetEcran(this.cle, this.classe, this.taille);

  /// Préfixe des clés partagées avec le code Android.
  final String cle;

  /// Nom de la classe Android du widget.
  final String classe;

  /// Taille du dessin ; une hauteur de 0 laisse le contenu décider.
  final Size taille;

  /// Widget animé : le personnage y fait l'exercice en boucle. Il n'a pas
  /// une image par jour mais une suite d'images qui défilent.
  bool get anime => this == record || this == recordLarge;
}

const _fond = Color(0xFF0E0E10);
const _rayon = 28.0;

TextStyle _t(double taille, FontWeight graisse, Color couleur, {double? hauteur, double? espace}) =>
    TextStyle(fontFamily: AppTokens.fontUi, fontSize: taille, fontWeight: graisse, color: couleur, height: hauteur, letterSpacing: espace, decoration: TextDecoration.none);

/// Le cadre commun : fond presque noir, grands coins.
class _Cadre extends StatelessWidget {
  const _Cadre({required this.taille, required this.child, this.padding = const EdgeInsets.all(16)});
  final Size taille;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: taille.width,
        height: taille.height == 0 ? null : taille.height,
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: _fond, borderRadius: BorderRadius.circular(_rayon)),
        child: child,
      );
}

/// La routine à lancer un jour donné, et l'adresse qui la démarre.
({Routine? routine, int rang, String chemin}) routineDuJour(BuildContext context, DateTime jour) {
  final routines = context.read<RoutineRepo>();
  final sessions = context.read<SessionRepo>();
  final actif = context.read<ProgramRepo>().active;
  final ids = [for (final r in routines.routines) r.id];
  final aujourdhui = Dates.memeJour(jour, DateTime.now());
  String? id;
  // Aujourd'hui, la routine dont l'appli est sûre (faite ce jour-là six
  // semaines sur huit) passe devant.
  if (aujourdhui) {
    id = suggererRoutine(maintenant: jour, seances: sessions.sessions, routinesConnues: ids.toSet())?.routineId;
  }
  final cycle = [for (final x in actif?.routineIds ?? const <String>[]) if (routines.byId(x) != null) x];
  if (id == null && cycle.isNotEmpty) {
    // Un programme de sept routines suit la semaine ; sinon, la suivante du cycle.
    id = cycle.length == 7 ? cycle[jour.weekday - 1] : cycle[rangDansCycle(cycle, sessions.sessions, depuis: actif!.debuteLe)];
  }
  final routine = id == null ? null : routines.byId(id);
  if (routine == null) return (routine: null, rang: 0, chemin: SeancePaths.vide);
  final dansProgramme = actif != null && actif.routineIds.contains(routine.id);
  return (
    routine: routine,
    rang: dansProgramme ? actif.routineIds.indexOf(routine.id) : ids.indexOf(routine.id),
    chemin: SeancePaths.routine(routine.id, programId: dansProgramme ? actif.id : null),
  );
}

/// La séance terminée ce [jour]-là (la dernière s'il y en a plusieurs), ou null.
WorkoutSession? seanceFaiteLe(BuildContext context, DateTime jour) {
  WorkoutSession? faite;
  for (final s in context.read<SessionRepo>().sessions) {
    if (s.enCours || !Dates.memeJour(s.debut, jour)) continue;
    if (faite == null || s.debut.isAfter(faite.debut)) faite = s;
  }
  return faite;
}

/// « Lancer ma séance » : la routine du jour et son bouton. Une fois la
/// séance du jour faite, il le dit (une coche verte) au lieu de proposer
/// déjà la suivante, qui reviendra le lendemain.
class VueLancer extends StatelessWidget {
  const VueLancer({super.key, required this.jour});
  final DateTime jour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final faite = seanceFaiteLe(context, jour);
    if (faite != null) {
      final routines = context.read<RoutineRepo>();
      final faiteRoutine = faite.routineId == null ? null : routines.byId(faite.routineId!);
      final actif = context.read<ProgramRepo>().active;
      final rang = faiteRoutine == null
          ? 0
          : (actif != null && actif.routineIds.contains(faiteRoutine.id) ? actif.routineIds.indexOf(faiteRoutine.id) : routines.routines.indexWhere((x) => x.id == faiteRoutine.id));
      return _Cadre(
        taille: WidgetEcran.lancer.taille,
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(
          children: [
            if (faiteRoutine != null)
              VignetteRoutineVue(routine: faiteRoutine, rang: rang < 0 ? 0 : rang, taille: 64, fond: _fond)
            else
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(15)),
                child: const Center(child: TraitIcone(AppIcone.haltere, size: 28, color: Colors.white)),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SÉANCE FAITE', maxLines: 1, style: _t(11, FontWeight.w700, c.success, espace: 1.4)),
                  const SizedBox(height: 1),
                  Text(faite.nom.trim().isEmpty ? 'Séance' : faite.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(17.5, FontWeight.w800, c.text, hauteur: 1.25)),
                  Text(
                    '${Fmt.pluriel(faite.exercices.length, 'exercice')} · ${Fmt.duree(faite.duree)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(13, FontWeight.w400, c.text2, hauteur: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: c.success.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: 32, color: c.success),
            ),
          ],
        ),
      );
    }
    final r = routineDuJour(context, jour);
    final routine = r.routine;
    return _Cadre(
      taille: WidgetEcran.lancer.taille,
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(
        children: [
          if (routine != null)
            VignetteRoutineVue(routine: routine, rang: r.rang, taille: 64, fond: _fond)
          else
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(15)),
              child: const Center(child: TraitIcone(AppIcone.haltere, size: 28, color: Colors.white)),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AUJOURD\'HUI', maxLines: 1, style: _t(11, FontWeight.w600, c.text2, espace: 1.4)),
                const SizedBox(height: 1),
                Text(routine?.nom ?? 'Nouvel entraînement', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(17.5, FontWeight.w800, c.text, hauteur: 1.25)),
                Text(
                  routine == null ? 'Séance libre' : Fmt.pluriel(routine.exercices.length, 'exercice'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(13, FontWeight.w400, c.text2, hauteur: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: c.bouton, shape: BoxShape.circle),
            child: Padding(padding: const EdgeInsets.only(left: 3), child: Icon(Icons.play_arrow_rounded, size: 34, color: c.onBouton)),
          ),
        ],
      ),
    );
  }
}

/// « Ma semaine » : la carte « Cette semaine » de l'accueil, telle quelle.
class VueSemaine extends StatelessWidget {
  const VueSemaine({super.key, required this.jour});
  final DateTime jour;

  @override
  Widget build(BuildContext context) => SizedBox(width: WidgetEcran.semaine.taille.width, child: CarteCetteSemaine(maintenant: jour, lien: false));
}

/// « Série » : la flamme, le nombre de semaines d'affilée, le record, et les
/// sept jours de la semaine (un jour fait devient une braise).
class VueSerie extends StatelessWidget {
  const VueSerie({super.key, required this.jour});
  final DateTime jour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.read<SessionRepo>();
    final premierJour = context.read<SettingsRepo>().settings.premierJourSemaine;
    final serie = repo.streakWeeks(now: jour);
    final record = Calculs.meilleureSerie(repo.sessions, DateTime(1970), DateTime(jour.year, jour.month, jour.day + 1), premierJour: premierJour);
    final semaine = ResumeSemaine.pour(repo, jour, premierJour: premierJour);
    return _Cadre(
      taille: WidgetEcran.serie.taille,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Opacity(opacity: serie == 0 ? 0.35 : 1, child: const Flamme(taille: 50)),
              const SizedBox(width: 8),
              Text('$serie', style: TextStyle(fontFamily: AppTokens.fontBilan, fontSize: 50, fontWeight: FontWeight.w900, color: c.text, height: 1, letterSpacing: -1.5, decoration: TextDecoration.none)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(serie <= 1 ? 'semaine d\'affilée' : 'semaines d\'affilée', maxLines: 1, style: _t(16, FontWeight.w800, c.text, hauteur: 1.25)),
                    Text('record : ${Fmt.pluriel(record < serie ? serie : record, 'semaine')}', maxLines: 1, style: _t(12.5, FontWeight.w400, c.text2, hauteur: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final j in semaine.jours)
                () {
                  final auj = Dates.memeJour(j, jour);
                  final fait = semaine.entraine(j);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][j.weekday - 1], style: _t(10.5, FontWeight.w700, auj ? c.text : c.text2)),
                      const SizedBox(height: 4),
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fait ? null : (auj ? c.bouton : null),
                          gradient: fait ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFC23D), Color(0xFFFF6A1A)]) : null,
                          border: fait || auj ? null : Border.all(color: const Color(0xFF232326), width: 1.5),
                        ),
                        child: fait
                            ? const Icon(Icons.local_fire_department_rounded, size: 20, color: Colors.white)
                            : Text('${j.day}', style: _t(12.5, FontWeight.w700, auj ? c.onBouton : c.text3)),
                      ),
                    ],
                  );
                }(),
            ],
          ),
        ],
      ),
    );
  }
}

/// « Récupération » : le personnage de face et de dos, le groupe conseillé
/// allumé en vert, l'anneau global et le conseil du jour.
class VueRecuperation extends StatelessWidget {
  const VueRecuperation({super.key, required this.maintenant});
  final DateTime maintenant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.read<SessionRepo>().sessions;
    final exos = context.read<ExerciseRepo>();
    final etats = Recup.etats(sessions, exos.byId, now: maintenant);
    final conseil = Recup.conseil(etats, sessions, exos.byId);
    // Les muscles prêts en vert plein, les autres plus pâles selon leur récupération.
    final intensites = {for (final e in etats.values) e.muscle: e.pret ? 1.0 : 0.0};
    return _Cadre(
      taille: WidgetEcran.recuperation.taille,
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Row(
        children: [
          BodyMap(view: BodyView.front, intensities: intensites, highlight: c.success, height: 146),
          const SizedBox(width: 4),
          BodyMap(view: BodyView.back, intensities: intensites, highlight: c.success, height: 146),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnneauRecup(pourcentage: Recup.global(etats), taille: 58),
                const SizedBox(height: 10),
                Text('CONSEILLÉ', maxLines: 1, style: _t(10.5, FontWeight.w600, c.text2, espace: 1.3)),
                Text(Recup.groupeLabel(conseil.groupe), maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(18, FontWeight.w800, c.text, hauteur: 1.25)),
                Text('muscles prêts en vert', maxLines: 1, style: _t(11.5, FontWeight.w400, c.text2, hauteur: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « Mon mois » : le calendrier du profil, avec la flamme de la série.
class VueMois extends StatelessWidget {
  const VueMois({super.key, required this.jour});
  final DateTime jour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.read<SessionRepo>();
    final sessions = repo.sessions;
    final types = Calculs.typesParJour(sessions);
    final ceMois = sessions.where((s) => !s.enCours && s.debut.year == jour.year && s.debut.month == jour.month).length;
    final serie = repo.streakWeeks(now: jour);
    return _Cadre(
      taille: WidgetEcran.mois.taille,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 0, 2, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Calculs.moisCap(jour), style: _t(18, FontWeight.w800, c.text, hauteur: 1.25)),
                      Text(ceMois == 0 ? 'Aucune séance ce mois-ci' : '${Fmt.pluriel(ceMois, 'séance')} ce mois-ci', style: _t(12.5, FontWeight.w400, c.text2, hauteur: 1.3)),
                    ],
                  ),
                ),
                if (serie > 0)
                  Container(
                    padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
                    decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(99)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TraitIcone(AppIcone.flamme, size: 17, color: Color(0xFFFFBE0B)),
                        const SizedBox(width: 5),
                        Text('$serie sem.', style: _t(13, FontWeight.w700, c.text)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          GrilleMois(
            mois: jour,
            aujourdhui: jour,
            premierJour: context.read<SettingsRepo>().settings.premierJourSemaine,
            seance: (j) => types[Dates.jour(j)],
            taille: 34,
          ),
        ],
      ),
    );
  }
}

/// Le dernier record, et le média de son exercice (animation du pack, sinon
/// sa pose).
({RecordBattu? record, Exercise? exercice, String? media}) dernierRecord(BuildContext context) {
  final records = Calculs.records(context.read<SessionRepo>().sessions);
  if (records.isEmpty) return (record: null, exercice: null, media: null);
  final r = records.last;
  final e = context.read<ExerciseRepo>().byId(r.exerciseId);
  final gif = e?.media.gif;
  final locales = e?.media.imagesLocales ?? const <String>[];
  final media = gif != null && gif.startsWith('assets/') ? gif : (locales.isEmpty ? null : locales.last);
  return (record: r, exercice: e, media: media);
}

/// La pastille dorée « PR ».
class _PastillePr extends StatelessWidget {
  const _PastillePr();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD24A), Color(0xFFF5A800)]),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, size: 13, color: Color(0xFF2A1C00)),
            const SizedBox(width: 4),
            Text('PR', style: _t(11, FontWeight.w800, const Color(0xFF2A1C00), espace: 0.6, hauteur: 1.2)),
          ],
        ),
      );
}

/// « Mon dernier record » : le personnage du pack fait l'exercice du record
/// en boucle. [image] est l'image de l'animation à montrer ; sans elle, la
/// pose de l'exercice.
///
/// En carré, le personnage occupe tout le widget et le texte se pose sur un
/// voile sombre. En large, il est au centre, l'exercice à gauche et le
/// chiffre à droite, une lueur dorée dans le coin de la pastille « PR ».
class VueRecord extends StatelessWidget {
  const VueRecord({super.key, this.large = false, this.image});
  final bool large;
  final ui.Image? image;

  static TextStyle _gros(double taille, Color c) =>
      TextStyle(fontFamily: AppTokens.fontBilan, fontSize: taille, fontWeight: FontWeight.w900, color: c, height: 1.08, letterSpacing: -0.4, decoration: TextDecoration.none);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = dernierRecord(context);
    final r = d.record;
    final taille = (large ? WidgetEcran.recordLarge : WidgetEcran.record).taille;
    if (r == null) {
      return _Cadre(
        taille: taille,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _PastillePr(),
            Text('Ton premier record apparaîtra ici.', style: _t(14, FontWeight.w600, c.text2, hauteur: 1.3)),
          ],
        ),
      );
    }
    final unite = context.read<ProfileRepo>().unite;
    final nom = context.read<ExerciseRepo>().nameOf(r.exerciseId);
    final sansCharge = r.serie.poids == null || r.serie.poids == 0;
    final charge = sansCharge ? '${r.serie.reps ?? 0}' : Fmt.poids(r.serie.poids, unite);
    final reps = sansCharge ? 'répétitions' : '× ${r.serie.reps ?? 0}';
    final gain = r.avant < 1 ? null : ((r.valeur / r.avant - 1) * 100).round();
    final media = d.media;
    final Widget perso = image != null
        ? RawImage(image: image, fit: BoxFit.contain, filterQuality: FilterQuality.medium)
        : (media == null ? const SizedBox.shrink() : Image.asset(media, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()));
    final date = Text(Fmt.jourMois(r.session.debut), style: _t(11.5, FontWeight.w400, c.text2));
    final texteGain = gain == null || gain <= 0 ? null : Text('+$gain %', style: _t(12.5, FontWeight.w700, c.success, hauteur: 1.3));

    if (large) {
      return Container(
        width: taille.width,
        height: taille.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_rayon),
          // La lueur dorée part du coin de la pastille « PR ».
          gradient: const RadialGradient(center: Alignment(-1.05, -1.25), radius: 0.95, colors: [Color(0xFF4A3606), _fond], stops: [0, 1]),
        ),
        child: Stack(
          children: [
            // Un peu à gauche du centre : le chiffre tient sur une ligne à droite.
            Positioned(left: 78, top: 2, width: 178, height: 176, child: perso),
            const Positioned(left: 16, top: 16, child: _PastillePr()),
            Positioned(right: 16, top: 18, child: date),
            Positioned(
              left: 16,
              bottom: 14,
              width: 96,
              child: Text(nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: _t(13, FontWeight.w700, c.text, hauteur: 1.2)),
            ),
            Positioned(
              right: 16,
              bottom: 13,
              width: 138,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // La charge et les répétitions sur une seule ligne.
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text('$charge $reps', maxLines: 1, style: _gros(22, c.text))),
                  ?texteGain,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: taille.width,
      height: taille.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: _fond, borderRadius: BorderRadius.circular(_rayon)),
      child: Stack(
        children: [
          // Le personnage en grand, calé en haut.
          Positioned(left: -22, top: 6, width: 234, height: 164, child: perso),
          // Le voile sombre sous le texte.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 104,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x000E0E10), _fond], stops: [0, 0.6])),
            ),
          ),
          const Positioned(left: 12, top: 12, child: _PastillePr()),
          Positioned(right: 13, top: 14, child: date),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('$charge $reps', maxLines: 1, style: _gros(22, c.text))),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Expanded(child: Text(nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(12, FontWeight.w400, const Color(0xFFC9C9CF), hauteur: 1.3))),
                    if (texteGain != null) ...[const SizedBox(width: 6), texteGain],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Construit la vue d'un widget pour un jour donné. Rien ne s'y touche : la
/// vue est photographiée, c'est Android qui reçoit l'appui.
Widget vueEcran(WidgetEcran w, DateTime jour, {ui.Image? image}) => Material(
      type: MaterialType.transparency,
      child: IgnorePointer(
        child: switch (w) {
          WidgetEcran.lancer => VueLancer(jour: jour),
          WidgetEcran.semaine => VueSemaine(jour: jour),
          WidgetEcran.serie => VueSerie(jour: jour),
          WidgetEcran.recuperation => VueRecuperation(maintenant: jour),
          WidgetEcran.mois => VueMois(jour: jour),
          WidgetEcran.record => VueRecord(image: image),
          WidgetEcran.recordLarge => VueRecord(large: true, image: image),
        },
      ),
    );

/// Ce qu'ouvre un appui sur le widget, ce jour-là.
String cheminEcran(BuildContext context, WidgetEcran w, DateTime jour) => switch (w) {
      // Séance du jour déjà faite : l'appui ouvre son détail.
      WidgetEcran.lancer => switch (seanceFaiteLe(context, jour)) {
          final faite? => SeancePaths.detail(faite.id),
          null => routineDuJour(context, jour).chemin,
        },
      WidgetEcran.semaine => '/',
      WidgetEcran.serie => '/aujourdhui/serie',
      WidgetEcran.recuperation => '/progres/recuperation',
      WidgetEcran.mois => '/progres/calendrier',
      WidgetEcran.record || WidgetEcran.recordLarge => '/progres/records',
    };
