import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/accueil.dart';
import '../logic/resume_jour.dart';
import '../routes.dart';
import '../../profil/widgets/ecusson.dart';

/// Cotes de l'accueil (maquette en 320 de large, livrée à 1,25).
abstract final class CotesAccueil {
  static const marge = 22.0;
  static const rayonCarte = 20.0;
  static const bouton = 55.0;
}

TextStyle _txt(double taille, FontWeight poids, Color couleur, {double? hauteur, double? espacement}) => TextStyle(
      fontFamily: AppTokens.fontUi,
      fontSize: taille,
      height: hauteur ?? 1.3,
      fontWeight: poids,
      color: couleur,
      letterSpacing: espacement,
      fontFeatures: AppTokens.tabular,
    );

// Tracés de la maquette (grille de 22).
const _traceFlamme = traceFlamme;
const _traceCloche = 'M5.5 15.5V10a5.5 5.5 0 0 1 11 0v5.5l1.5 1.5H4zM9 19a2.2 2.2 0 0 0 4 0';

enum _Dessin { flamme, cloche }

final _chemins = <_Dessin, Path>{};

Path _chemin(_Dessin d) => _chemins.putIfAbsent(d, () {
      switch (d) {
        case _Dessin.flamme:
          return parseSvgPathData(_traceFlamme);
        case _Dessin.cloche:
          return parseSvgPathData(_traceCloche);
      }
    });

class _Trace extends StatelessWidget {
  const _Trace(this.dessin, {required this.largeur, required this.couleur, this.plein = false});

  final _Dessin dessin;
  final double largeur;
  final Color couleur;
  final bool plein;

  /// Épaisseur du trait.
  static const epaisseur = 1.7;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: largeur,
          height: largeur,
          child: CustomPaint(painter: _TracePainter(dessin, couleur, epaisseur, plein)),
        ),
      );
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.dessin, this.couleur, this.epaisseur, this.plein);

  final _Dessin dessin;
  final Color couleur;
  final double epaisseur;
  final bool plein;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22);
    final p = Paint()
      ..color = couleur
      ..style = plein ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = epaisseur
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_chemin(dessin), p);
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.dessin != dessin || old.couleur != couleur || old.epaisseur != epaisseur || old.plein != plein;
}

/// Ouvre une séance terminée (bilan de séance du module Séance).
void ouvrirSeance(BuildContext context, String id) => context.push(AujourdhuiPaths.bilanSeance(id));

/// En-tête : le titre de l'onglet à gauche, la flamme de la série et la cloche
/// à droite.
class EnTeteAccueil extends StatelessWidget {
  const EnTeteAccueil({super.key, required this.maintenant});

  final DateTime maintenant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>();
    final settings = context.watch<SettingsRepo>().settings;
    final objectif = context.watch<ProfileRepo>().profile?.joursParSemaine ?? 3;
    final serie = sessions.streakWeeks(now: maintenant);
    final liste = nouveautes(
      sessions: sessions.sessions,
      now: maintenant,
      objectif: objectif,
      premierJour: settings.premierJourSemaine,
    );
    final cloche = ClocheRepo.pour(context.read<Store>());
    return Row(
      children: [
        Expanded(child: Text('Accueil', maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(25, FontWeight.w700, c.text, hauteur: 1.3))),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: serie <= 1 ? 'Série de $serie semaine' : 'Série de $serie semaines',
          excludeSemantics: true,
          child: Material(
            color: c.surface2,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(AujourdhuiPaths.serie),
              child: Container(
                height: CotesAccueil.bouton,
                padding: const EdgeInsets.only(left: 12.5, right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Trace(_Dessin.flamme, largeur: 22.5, couleur: serie == 0 ? c.text3 : c.orange, plein: true),
                    const SizedBox(width: 6),
                    Text('$serie', style: _txt(17.5, FontWeight.w800, c.text, hauteur: 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12.5),
        ListenableBuilder(
          listenable: cloche,
          builder: (context, _) {
            final nouveau = cloche.aDuNouveau(liste);
            return Semantics(
              button: true,
              label: nouveau ? 'Notifications, du nouveau' : 'Notifications',
              excludeSemantics: true,
              child: Material(
                color: c.surface2,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _ouvrirCloche(context, liste, cloche, maintenant),
                  child: SizedBox.square(
                    dimension: CotesAccueil.bouton,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _Trace(_Dessin.cloche, largeur: 22.5, couleur: c.text),
                        if (nouveau)
                          Positioned(
                            top: 11.5,
                            right: 12.5,
                            child: Container(
                              width: 15,
                              height: 15,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<void> _ouvrirCloche(BuildContext context, List<Nouveaute> liste, ClocheRepo cloche, DateTime maintenant) async {
  final nouvelles = {for (final n in liste) if (cloche.estNouvelle(n)) n};
  cloche.marquerVu(maintenant);
  final choix = await showPanneauBas<Nouveaute>(
    context,
    titre: 'Notifications',
    builder: (context) {
      final c = context.colors;
      if (liste.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'Rien de nouveau pour l\'instant. Tes records et tes bilans arriveront ici.',
            textAlign: TextAlign.center,
            style: _txt(15, FontWeight.w500, c.text2, hauteur: 1.4),
          ),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in liste)
            InkWell(
              borderRadius: AppTokens.radius12,
              onTap: () => Navigator.pop(context, n),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: nouvelles.contains(n) ? c.accent : c.surface3,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: _txt(16, FontWeight.w700, c.text)),
                          const SizedBox(height: 2),
                          Text(n.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(14, FontWeight.w500, c.text2)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: c.text3, size: 22),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  if (choix == null || !context.mounted) return;
  switch (choix.cible) {
    case CibleNouveaute.bilanMois:
      context.push(AujourdhuiPaths.bilanMois(choix.id!));
    case CibleNouveaute.seance:
      ouvrirSeance(context, choix.id!);
    case CibleNouveaute.semaine:
      RetourOrigine.ouvrir(context, AujourdhuiPaths.bilanSemaine);
  }
}

/// Lien blanc à droite d'un titre (« Voir plus », « Historique »).
class _Lien extends StatelessWidget {
  const _Lien(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppTokens.radius8,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(label, maxLines: 1, style: _txt(15, FontWeight.w600, context.colors.text)),
        ),
      );
}

/// Carte compacte « Cette semaine » : une ligne de chiffres et les sept jours.
class CarteCetteSemaine extends StatelessWidget {
  const CarteCetteSemaine({super.key, required this.maintenant, this.lien = true});

  final DateTime maintenant;

  /// « Voir plus » à droite du titre ; sans lui sur le widget de l'écran du
  /// téléphone, où rien ne se touche séparément.
  final bool lien;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>();
    final settings = context.watch<SettingsRepo>().settings;
    final profil = context.watch<ProfileRepo>();
    final r = ResumeSemaine.pour(
      sessions,
      maintenant,
      premierJour: settings.premierJourSemaine,
      objectif: profil.profile?.joursParSemaine ?? 3,
    );
    final gris = _txt(15, FontWeight.w400, c.text2);
    final blanc = _txt(15, FontWeight.w700, c.text);
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(CotesAccueil.rayonCarte)),
      padding: const EdgeInsets.fromLTRB(17.5, 9, 17.5, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Cette semaine', maxLines: 1, overflow: TextOverflow.ellipsis, style: _txt(17.5, FontWeight.w700, c.text)),
              ),
              const SizedBox(width: 8),
              if (lien) _Lien('Voir plus', () => RetourOrigine.ouvrir(context, AujourdhuiPaths.bilanSemaine)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                style: gris,
                children: [
                  TextSpan(text: '${r.nbSeances}', style: blanc),
                  TextSpan(text: ' / ${r.objectif} ${r.objectif >= 2 ? 'séances' : 'séance'}'),
                  if (r.duree > Duration.zero) ...[
                    const TextSpan(text: '  ·  '),
                    TextSpan(text: Fmt.duree(r.duree), style: blanc),
                  ],
                  if (r.volume > 0) ...[
                    const TextSpan(text: '  ·  '),
                    TextSpan(text: Fmt.volume(r.volume, profil.unite), style: blanc),
                  ],
                ],
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 10),
          SemaineJours(
            jours: r.jours,
            aujourdhui: maintenant,
            // La première séance du jour l'emporte, comme dans le calendrier
            // (la liste va de la plus récente à la plus ancienne).
            seance: (j) => r.seances.lastWhereOrNull((s) => Dates.memeJour(s.debut, j))?.type,
            onJour: (j) {
              final s = r.seances.lastWhereOrNull((s) => Dates.memeJour(s.debut, j));
              if (s != null) ouvrirSeance(context, s.id);
            },
          ),
        ],
      ),
    );
  }
}

/// Titre « Dernières séances » et son lien.
class TitreDernieresSeances extends StatelessWidget {
  const TitreDernieresSeances({super.key, this.lien = true});

  final bool lien;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              'Dernières séances',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _txt(18.75, FontWeight.w700, context.colors.text),
            ),
          ),
          if (lien) ...[
            const SizedBox(width: 8),
            _Lien('Historique', () => RetourOrigine.ouvrir(context, AujourdhuiPaths.calendrier)),
          ],
        ],
      );
}

/// Carte d'une séance terminée : type, nom, date, puis ses photos et vidéos
/// ou, à défaut, ses trois premiers exercices.
class CarteSeance extends StatelessWidget {
  const CarteSeance({super.key, required this.session, required this.records, required this.maintenant});

  final WorkoutSession session;
  final int records;
  final DateTime maintenant;

  static const _marge = 17.5;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    final unite = context.watch<ProfileRepo>().unite;
    final exercices = context.watch<ExerciseRepo>();
    final faits = [
      for (final e in s.exercices)
        if (e.series.isNotEmpty) e,
    ];
    final avecMedias = s.medias.isNotEmpty;

    Widget marge(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: _marge), child: child);

    final entete = Padding(
      padding: const EdgeInsets.only(left: _marge, right: 5),
      child: Row(
        children: [
          PastilleTypeSeance(s.type, taille: 45),
          const SizedBox(width: 12.5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomSeance(s).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _txt(20, FontWeight.w800, c.text, hauteur: 1.25, espacement: 0.2),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(dateSeance(s.debut, now: maintenant), maxLines: 1, style: _txt(14.4, FontWeight.w400, c.text2, hauteur: 1.35)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Plus d\'actions',
            constraints: const BoxConstraints.tightFor(width: CotesAccueil.bouton, height: CotesAccueil.bouton),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert_rounded, color: c.text, size: 24),
            onPressed: () => _menu(context, s),
          ),
        ],
      ),
    );

    Widget stat(String label, Widget valeur, {bool droite = false}) => Column(
          crossAxisAlignment: droite ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(label, style: _txt(13, FontWeight.w400, c.text2, hauteur: 1.35)),
            const SizedBox(height: 2.5),
            valeur,
          ],
        );
    final chiffre = _txt(18.75, FontWeight.w700, c.text, hauteur: 1.35);
    final stats = marge(
      Container(
        // Le filet sépare les chiffres des vignettes d'exercices ; avec des
        // médias, rien ne suit les chiffres.
        padding: EdgeInsets.only(bottom: !avecMedias && faits.isNotEmpty ? 15 : 0),
        decoration: !avecMedias && faits.isNotEmpty ? BoxDecoration(border: Border(bottom: BorderSide(color: c.line))) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.fin != null) ...[
              stat('Durée', Text(Fmt.duree(s.duree), maxLines: 1, style: chiffre)),
              const SizedBox(width: 27.5),
            ],
            Expanded(
              child: s.volume > 0
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: stat('Volume', Text(Fmt.volume(s.volume, unite), maxLines: 1, style: chiffre)),
                      ),
                    )
                  // Sans charge soulevée, le nombre de séries plutôt qu'un vide.
                  : s.nbSeriesFaites > 0
                      ? Align(alignment: Alignment.centerLeft, child: stat('Séries', Text('${s.nbSeriesFaites}', maxLines: 1, style: chiffre)))
                      : const SizedBox.shrink(),
            ),
            if (records > 0) const SizedBox(width: 12),
            if (records > 0)
              stat(
                'Records',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Ecusson.record(largeur: 26),
                    const SizedBox(width: 6),
                    Text('$records', style: chiffre),
                  ],
                ),
                droite: true,
              ),
          ],
        ),
      ),
    );

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(CotesAccueil.rayonCarte),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ouvrirSeance(context, s.id),
        child: Padding(
          padding: const EdgeInsets.only(top: 12.5, bottom: _marge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              entete,
              const SizedBox(height: 10),
              if (avecMedias) ...[
                _Medias(medias: s.medias, onTap: () => ouvrirSeance(context, s.id)),
                const SizedBox(height: 15),
                stats,
              ] else ...[
                stats,
                if (faits.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  marge(_Vignettes(exercices: faits, repo: exercices)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, WorkoutSession s) async {
    final choix = await showPanneauBas<String>(
      context,
      titre: nomSeance(s),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LigneAction(
            icone: const Icon(Icons.insights_rounded),
            label: 'Voir le bilan de la séance',
            onTap: () => Navigator.pop(context, 'voir'),
          ),
          LigneAction(
            icone: const Icon(Icons.replay_rounded),
            label: 'Refaire cette séance',
            onTap: () => Navigator.pop(context, 'refaire'),
          ),
          LigneAction(
            icone: const Icon(Icons.edit_outlined),
            label: 'Modifier la séance',
            onTap: () => Navigator.pop(context, 'modifier'),
          ),
          LigneAction(
            icone: const Icon(Icons.delete_outline_rounded),
            label: 'Supprimer la séance',
            destructif: true,
            onTap: () => Navigator.pop(context, 'supprimer'),
          ),
        ],
      ),
    );
    if (choix == null || !context.mounted) return;
    switch (choix) {
      case 'voir':
        ouvrirSeance(context, s.id);
      case 'refaire':
        context.push(AujourdhuiPaths.refaireSeance(s.id));
      case 'modifier':
        context.push(AujourdhuiPaths.modifierSeance(s.id));
      case 'supprimer':
        final ok = await showConfirmDialog(
          context,
          title: 'Supprimer cette séance ?',
          message: '« ${nomSeance(s)} » du ${dateSeance(s.debut, now: maintenant).replaceFirst(' · ', ' à ')} sera retirée de ton historique et de tes records.',
          confirmLabel: 'Supprimer',
          destructive: true,
          icon: Icons.delete_outline_rounded,
        );
        if (!ok || !context.mounted) return;
        await context.read<SessionRepo>().delete(s.id);
        if (context.mounted) Toasts.show(context, 'Séance supprimée.');
    }
  }
}

/// Rangée défilante des photos et vidéos d'une séance, avec ses points.
class _Medias extends StatefulWidget {
  const _Medias({required this.medias, required this.onTap});

  final List<SessionMedia> medias;
  final VoidCallback onTap;

  @override
  State<_Medias> createState() => _MediasState();
}

class _MediasState extends State<_Medias> {
  static const _hauteur = 210.0;
  static const _ecart = 10.0;
  static const _pointsMax = 9;
  final _defilement = ScrollController();
  int _position = 0;
  double _pas = 1;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(_suivre);
  }

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  void _suivre() {
    final p = _defilement.position;
    final dernier = widget.medias.length - 1;
    final i = p.pixels >= p.maxScrollExtent - 1 && p.maxScrollExtent > 0
        ? dernier
        : (p.pixels / _pas).round().clamp(0, dernier);
    if (i != _position) setState(() => _position = i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = widget.medias.length;
    // Au-delà de neuf médias, les points suivent la position dans une
    // fenêtre de neuf : la rangée ne dépasse jamais de la carte.
    final nbPoints = n > _pointsMax ? _pointsMax : n;
    final premier = (_position - _pointsMax ~/ 2).clamp(0, n - nbPoints);
    return Column(
      children: [
        LayoutBuilder(builder: (context, box) {
          final utile = box.maxWidth - 2 * CarteSeance._marge;
          // Un seul média occupe la largeur ; sinon le suivant dépasse à droite.
          final largeur = n == 1 ? utile : (utile * 0.6).clamp(150.0, 260.0);
          _pas = largeur + _ecart;
          return SizedBox(
            height: _hauteur,
            child: ListView.separated(
              controller: _defilement,
              scrollDirection: Axis.horizontal,
              physics: n == 1 ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: CarteSeance._marge),
              itemCount: n,
              separatorBuilder: (_, _) => const SizedBox(width: _ecart),
              itemBuilder: (context, i) => SizedBox(
                width: largeur,
                child: _Media(media: widget.medias[i], rang: i + 1, total: n, onTap: widget.onTap),
              ),
            ),
          );
        }),
        if (n > 1) ...[
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = premier; i < premier + nbPoints; i++)
                AnimatedContainer(
                  key: ValueKey(i),
                  duration: AppTokens.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3.1),
                  width: i == _position ? 17.5 : 6.25,
                  height: 6.25,
                  decoration: BoxDecoration(
                    color: i == _position ? c.text : c.surface2,
                    borderRadius: AppTokens.radiusPill,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({required this.media, required this.rang, required this.total, required this.onTap});

  final SessionMedia media;
  final int rang;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duree = media.dureeSec;
    final etiquette = media.video
        ? (duree == null ? 'Vidéo' : 'Vidéo · ${dureeVideo(duree)}')
        : (total == 1 ? 'Photo' : 'Photo · $rang / $total');
    // Photo absente (fichier supprimé, démo) : un pictogramme discret sur le
    // dégradé sombre, pas un grand bloc gris.
    final attente = Center(child: IconeHaltere(size: 34, color: c.text3.withValues(alpha: 0.6), epaisseur: 1.6));
    return Semantics(
      button: true,
      label: etiquette,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.surface2, c.bg],
                  ),
                ),
              ),
              if (media.video)
                Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: c.bouton, shape: BoxShape.circle),
                    child: Icon(Icons.play_arrow_rounded, color: c.onBouton, size: 28),
                  ),
                )
              else if (media.chemin.isEmpty)
                attente
              else
                Image.file(
                  File(media.chemin),
                  fit: BoxFit.cover,
                  cacheWidth: 640,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => attente,
                ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(9)),
                  child: Text(etiquette, maxLines: 1, style: _txt(12.5, FontWeight.w600, c.text, hauteur: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jusqu'à trois vignettes d'exercices « 3 × Nom », puis le reste en une ligne.
class _Vignettes extends StatelessWidget {
  const _Vignettes({required this.exercices, required this.repo});

  final List<SessionExercise> exercices;
  final ExerciseRepo repo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vus = exercices.take(3).toList();
    final reste = exercices.length - vus.length;
    final gris = _txt(13, FontWeight.w400, c.text2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: i >= vus.length
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          AspectRatio(aspectRatio: 1, child: _Vignette(exercice: repo.byId(vus[i].exerciseId))),
                          const SizedBox(height: 7.5),
                          Text.rich(
                            TextSpan(
                              style: gris,
                              children: [
                                TextSpan(
                                  text: '${_series(vus[i])} × ',
                                  style: _txt(13, FontWeight.w700, c.text),
                                ),
                                TextSpan(text: repo.nameOf(vus[i].exerciseId)),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
            ],
          ],
        ),
        if (reste > 0) ...[
          const SizedBox(height: 12.5),
          Text(
            reste == 1 ? 'et 1 autre exercice' : 'et $reste autres exercices',
            textAlign: TextAlign.center,
            style: gris,
          ),
        ],
      ],
    );
  }

  static int _series(SessionExercise e) => e.seriesFaites.isNotEmpty ? e.seriesFaites.length : e.series.length;
}

class _Vignette extends StatelessWidget {
  const _Vignette({required this.exercice});

  final Exercise? exercice;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // La pose en contraction quand elle existe, comme sur la maquette.
    final media = exercice?.media;
    final src = media?.imagesLocales.where((p) => p.contains('-peak.')).firstOrNull ?? media?.thumbnail;
    final secours = Center(child: IconeHaltere(size: 30, color: c.text3));
    final Widget image;
    if (src == null) {
      image = secours;
    } else if (src.startsWith('http')) {
      image = CachedNetworkImage(
        imageUrl: src,
        fit: BoxFit.contain,
        errorWidget: (_, _, _) => secours,
        placeholder: (_, _) => const SizedBox.shrink(),
      );
    } else {
      image = Image.asset(src, fit: BoxFit.contain, errorBuilder: (_, _, _) => secours);
    }
    return Container(
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(6),
      child: image,
    );
  }
}

/// Aucune séance : un message et le bouton blanc vers Entraîner.
class AccueilVide extends StatelessWidget {
  const AccueilVide({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(CotesAccueil.rayonCarte)),
      padding: const EdgeInsets.fromLTRB(17.5, 22, 17.5, 17.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: PastilleTypeSeance(TypeSeance.musculation, taille: 45)),
          const SizedBox(height: 14),
          Text(
            'Aucune séance pour l\'instant',
            textAlign: TextAlign.center,
            style: _txt(18.75, FontWeight.w700, c.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Ta première séance s\'affichera ici, avec sa durée, son volume et tes records.',
            textAlign: TextAlign.center,
            style: _txt(15, FontWeight.w400, c.text2, hauteur: 1.4),
          ),
          const SizedBox(height: 18),
          BoutonPrincipal(label: 'Choisir une séance', onPressed: () => context.go(AujourdhuiPaths.entrainer)),
        ],
      ),
    );
  }
}
