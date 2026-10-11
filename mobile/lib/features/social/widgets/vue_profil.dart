import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../profil/data/grades.dart';
import '../../profil/widgets/ecusson.dart';
import '../../profil/widgets/maquette.dart' show IconeTrait, Trace;
import '../../progres/ui/communs.dart' show VignetteExercice;
import '../data/social_repo.dart';
import '../pages/communaute_page.dart' show CartePublication;
import 'elements.dart';

/// Le profil public d'une personne, tel que le voit quelqu'un : le même
/// dessin pour un ami, un inconnu, et pour l'aperçu de mon propre profil.
///
/// [ouvert] dit si le profil se montre à celui qui regarde ; fermé, il ne
/// reste que la photo, le prénom et le pseudo. Ouvert, chaque bloc suit ce
/// que la personne a choisi de montrer ([Ami.montre]).
class VueProfil extends StatelessWidget {
  const VueProfil({
    super.key,
    required this.personne,
    required this.ouvert,
    this.publications = const [],
    this.jours = const {},
    this.enCommun = const [],
    this.actions,
    this.maintenant,
  });

  final Ami personne;
  final bool ouvert;
  final List<Publication> publications;

  /// Ses jours d'entraînement, pour le calendrier du mois.
  final Set<DateTime> jours;
  final List<Ami> enCommun;

  /// Les boutons sous l'en-tête (ajouter, accepter…) ; aucun dans l'aperçu.
  final Widget? actions;
  final DateTime? maintenant;

  bool _montre(Visible v) => ouvert && personne.montre.contains(v);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = personne;
    final unite = context.watch<ProfileRepo?>()?.unite ?? UnitePoids.kg;
    final now = maintenant ?? DateTime.now();
    final lieu = _montre(Visible.lieu) ? [a.ville, a.salle].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ') : '';
    final badges = _montre(Visible.badges)
        ? ([
            for (final e in a.badges.entries)
              if (Avancee(e.value, e.key.paliers).gagne) e.key,
          ]..sort((x, y) => Avancee(a.badges[y]!, y.paliers).niveau.compareTo(Avancee(a.badges[x]!, x.paliers).niveau)))
        : const <Grade>[];
    final charges = _montre(Visible.charges);
    final premierJour = context.watch<SettingsRepo?>()?.settings.premierJourSemaine ?? DateTime.monday;
    final cette = Dates.debutSemaine(now, premierJour: premierJour);
    // Une semaine est tenue dès qu'elle compte une séance.
    bool tenue(DateTime d) => jours.any((j) => !j.isBefore(d) && j.isBefore(DateTime(d.year, d.month, d.day + 7)));
    // La série ne se répète pas ici : elle est sur le calendrier.
    final infos = [
      if (_montre(Visible.heures) && a.heures > 0) _Ligne('À la salle', '${Fmt.n(a.heures, decimals: 0)} h'),
      if (_montre(Visible.objectif) && a.objectif != null) _Ligne('Objectif', a.objectif!, etiquette: true),
      if (_montre(Visible.niveau) && a.niveau != null) _Ligne('Niveau', a.niveau!, etiquette: true),
      if (a.depuis != null) _Ligne('S\'entraîne depuis', '${a.depuis}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Entete(a: a, ouvert: ouvert, lieu: lieu, enCommun: enCommun, actions: actions),
        if (!ouvert)
          _Ferme(a: a)
        else ...[
          if (infos.isNotEmpty) ...[
            const SizedBox(height: 12),
            CarteSociale(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Column(
                children: [
                  for (final (i, l) in infos.indexed) ...[if (i > 0) const SizedBox(height: 11), l],
                ],
              ),
            ),
          ],
          if (_montre(Visible.serie)) ...[
            TitreSection(_cap(Fmt.mois(now).split(' ').first), droite: _ceMois(now)),
            CarteSociale(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: IgnorePointer(
                child: GrilleMois(
                  mois: now,
                  aujourdhui: now,
                  premierJour: premierJour,
                  seance: (j) => jours.contains(DateTime(j.year, j.month, j.day)) ? TypeSeance.musculation : null,
                  taille: 38,
                  // Comme dans Progrès : un point orange par semaine tenue, et
                  // la flamme avec la série sur la dernière semaine tenue.
                  flamme: (debut) {
                    if (debut.isAfter(cette)) return null;
                    if (!tenue(debut)) return 0;
                    final avant = DateTime(cette.year, cette.month, cette.day - 7);
                    final porteuse = tenue(cette) ? cette : (tenue(avant) ? avant : null);
                    return debut == porteuse && a.serieSemaines > 0 ? a.serieSemaines : -1;
                  },
                ),
              ),
            ),
          ],
          if (badges.isNotEmpty) ...[
            TitreSection('Badges', droite: '${badges.length}'),
            CarteSociale(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final g in badges.take(4))
                    Expanded(
                      child: Column(
                        children: [
                          Ecusson.grade(g, Avancee(a.badges[g]!, g.paliers), largeur: 64),
                          const SizedBox(height: 8),
                          Text(g.nom, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: ts(12, FontWeight.w500, c.text2, hauteur: 1.25)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_montre(Visible.records) && a.records.isNotEmpty) ...[
            const TitreSection('Meilleures barres'),
            CarteSociale(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final (i, r) in a.records.take(4).indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 82, color: c.line),
                    _Record(r, charges: charges, unite: unite),
                  ],
                ],
              ),
            ),
            if (!charges)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text('${a.prenom} ne montre pas ses charges.', style: ts(13, FontWeight.w500, c.text3)),
              ),
          ],
          if (_montre(Visible.seances)) ...[
            if (a.fetiches.isNotEmpty) ...[
              const TitreSection('Exercices fétiches'),
              _Fetiches(a.fetiches),
            ],
            const TitreSection('Dernières séances'),
            if (publications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('Aucune séance partagée pour l\'instant.', textAlign: TextAlign.center, style: ts(14.5, FontWeight.w500, c.text2)),
              ),
            for (final p in publications.take(5)) ...[CartePublication(p, auteur: a, avecAuteur: false, charges: charges, actif: actions != null, maintenant: now), const SizedBox(height: 12)],
          ],
        ],
      ],
    );
  }

  String? _ceMois(DateTime now) {
    final n = jours.where((j) => j.year == now.year && j.month == now.month).length;
    return n == 0 ? null : Fmt.pluriel(n, 'séance');
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Le bandeau, le même que sur l'onglet Profil : la photo floutée en fond
/// (ou la couleur de la personne), la photo à gauche, le prénom, une ligne
/// « 458 séances · 4 amis », puis la phrase sur toute la largeur.
class _Entete extends StatelessWidget {
  const _Entete({required this.a, required this.ouvert, required this.lieu, required this.enCommun, this.actions});
  final Ami a;
  final bool ouvert;
  final String lieu;
  final List<Ami> enCommun;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final phrase = ouvert ? (a.phrase ?? '').trim() : '';
    // Un profil fermé ne montre que la photo, le prénom et le pseudo.
    final nbSeances = ouvert && a.montre.contains(Visible.nbSeances), nbAmis = ouvert && a.montre.contains(Visible.nbAmis);
    final photo = a.photo;
    final avecPhoto = photo != null && File(photo).existsSync();
    final couleur = Color(a.couleur);
    final ombre = [Shadow(blurRadius: 10, offset: const Offset(0, 1), color: Colors.black.withValues(alpha: 0.35))];
    final mot = ts(14.5, FontWeight.w500, Colors.white.withValues(alpha: 0.75), hauteur: 1.2);
    final chiffre = ts(14.5, FontWeight.w700, Colors.white, hauteur: 1.2);

    Widget donnee(Trace trace, int n, String singulier) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconeTrait(trace, taille: 17, couleur: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 5),
            Text('$n', style: chiffre),
            const SizedBox(width: 4),
            Text(n > 1 ? '${singulier}s' : singulier, style: mot),
          ],
        );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(couleur, Colors.white, 0.18)!, couleur, Color.lerp(couleur, Colors.black, 0.7)!]),
      ),
      child: Stack(
        children: [
          if (avecPhoto)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22, tileMode: TileMode.mirror),
                // Agrandie : le flou ne laisse pas voir les bords de l'image.
                child: Transform.scale(scale: 1.25, child: Image.file(File(photo), fit: BoxFit.cover, cacheWidth: 240)),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.24), Colors.black.withValues(alpha: 0.84)]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black.withValues(alpha: 0.55), width: 2.5, strokeAlign: BorderSide.strokeAlignOutside)),
                      child: Pastille2(a, taille: 66),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  a.prenom.trim().isEmpty ? 'Sans prénom' : a.prenom,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ts(22, FontWeight.w800, Colors.white, hauteur: 1.2).copyWith(shadows: ombre),
                                ),
                              ),
                              if (a.acces != AccesProfil.tous) ...[
                                const SizedBox(width: 7),
                                Icon(Icons.lock_rounded, size: 15, color: Colors.white.withValues(alpha: 0.7), semanticLabel: a.acces == AccesProfil.amis ? 'Profil réservé aux amis' : 'Profil privé'),
                              ],
                            ],
                          ),
                          if (a.pseudo.isNotEmpty) Text('@${a.pseudo}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13.5, FontWeight.w500, Colors.white.withValues(alpha: 0.7), hauteur: 1.25)),
                          if (nbSeances || nbAmis) ...[
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (nbSeances) donnee(Trace.haltere, a.seances, 'séance'),
                                  if (nbSeances && nbAmis)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('·', style: ts(14.5, FontWeight.w700, Colors.white.withValues(alpha: 0.4), hauteur: 1.2)),
                                    ),
                                  if (nbAmis) donnee(Trace.silhouette, a.amis, 'ami'),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (phrase.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(phrase, maxLines: 4, overflow: TextOverflow.ellipsis, style: ts(14, FontWeight.w400, Colors.white.withValues(alpha: 0.86), hauteur: 1.43)),
                ],
                if (lieu.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 5),
                      Expanded(child: Text(lieu, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(13.5, FontWeight.w500, Colors.white.withValues(alpha: 0.75)))),
                    ],
                  ),
                ],
                if (enCommun.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 26.0 + 17 * (enCommun.take(3).length - 1),
                        height: 26,
                        child: Stack(
                          children: [
                            for (final (i, e) in enCommun.take(3).indexed)
                              Positioned(
                                left: 17.0 * i,
                                child: Container(
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                                  child: Pastille2(e, taille: 22),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(Fmt.pluriel(enCommun.length, 'ami en commun', 'amis en commun'), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13.5, FontWeight.w600, Colors.white))),
                    ],
                  ),
                ],
                if (actions != null) ...[const SizedBox(height: 16), actions!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ce qu'on voit d'un profil qui ne se montre pas à nous.
class _Ferme extends StatelessWidget {
  const _Ferme({required this.a});
  final Ami a;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final prive = a.acces == AccesProfil.personne;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
            child: Icon(Icons.lock_outline_rounded, color: c.text2, size: 28),
          ),
          const SizedBox(height: 16),
          Text(prive ? 'Profil privé' : 'Profil réservé aux amis', textAlign: TextAlign.center, style: ts(19, FontWeight.w700, c.text)),
          const SizedBox(height: 6),
          Text(
            prive ? '${a.prenom} ne montre ni ses séances ni sa série, même à ses amis.' : 'Ses séances, sa série et ses badges se montrent à ses amis.',
            textAlign: TextAlign.center,
            style: ts(14.5, FontWeight.w500, c.text2, hauteur: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Une ligne d'information : le libellé à gauche, la valeur à droite. En
/// [etiquette], la valeur est un mot (« Sécher ») : petites capitales dans
/// une pastille grise.
class _Ligne extends StatelessWidget {
  const _Ligne(this.libelle, this.valeur, {this.etiquette = false});
  final String libelle;
  final String valeur;
  final bool etiquette;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: Row(
        children: [
          Text(libelle, style: ts(14.5, FontWeight.w500, c.text2)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: etiquette
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(99)),
                      child: Text(valeur.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, FontWeight.w700, c.text, hauteur: 1.2).copyWith(letterSpacing: 0.7)),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(valeur, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15.5, FontWeight.w700, c.text)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une meilleure barre : l'exercice, puis « 100 kg × 3 ».
class _Record extends StatelessWidget {
  const _Record(this.r, {required this.charges, required this.unite});
  final RecordAmi r;
  final bool charges;
  final UnitePoids unite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final exos = context.watch<ExerciseRepo>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          VignetteExercice(exercice: exos.byId(r.exerciceId), taille: 54, fond: c.surface2, rayon: 14),
          const SizedBox(width: 14),
          Expanded(child: Text(exos.nameOf(r.exerciceId), maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(15.5, FontWeight.w600, c.text, hauteur: 1.25))),
          const SizedBox(width: 10),
          if (!charges)
            Icon(Icons.visibility_off_outlined, size: 20, color: c.text3, semanticLabel: 'Charge masquée')
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(r.kg > 0 ? Fmt.poids(r.kg, unite) : Fmt.pluriel(r.reps, 'répétition'), style: ts(17, FontWeight.w800, c.text, hauteur: 1.2)),
                if (r.kg > 0) Text(Fmt.pluriel(r.reps, 'répétition'), style: ts(12.5, FontWeight.w500, c.text2)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Ses trois exercices les plus faits, en vignettes.
class _Fetiches extends StatelessWidget {
  const _Fetiches(this.ids);
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final exos = context.watch<ExerciseRepo>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, id) in ids.take(3).indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                AspectRatio(aspectRatio: 1, child: LayoutBuilder(builder: (context, box) => VignetteExercice(exercice: exos.byId(id), taille: box.maxWidth, fond: c.surface, rayon: 18))),
                const SizedBox(height: 7),
                Text(exos.nameOf(id), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: ts(12.5, FontWeight.w500, c.text2, hauteur: 1.25)),
              ],
            ),
          ),
        ],
        // Moins de trois : les vignettes gardent leur taille.
        for (var i = ids.take(3).length; i < 3; i++) ...[const SizedBox(width: 10), const Expanded(child: SizedBox())],
      ],
    );
  }
}
