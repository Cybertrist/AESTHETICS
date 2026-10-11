import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../progres/logic/tableau.dart';
import '../../social/data/social_repo.dart';
import '../../social/routes.dart';
import '../data/career.dart';
import '../data/photo_profil.dart';
import '../routes.dart';
import '../widgets/haut_etire.dart';
import '../widgets/maquette.dart';
import 'grades_page.dart';

/// Onglet Profil : ta photo, ton prénom et ta phrase, ton objectif, le calendrier du mois et tes
/// grades. Mensurations, photos, records et séances sont dans Progrès. Les
/// réglages s'ouvrent par la roue dentée.
class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<ProfileRepo>();
    final p = repo.profile;
    if (!repo.loaded) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const SafeArea(child: SkeletonList(count: 6)),
      );
    }
    if (p == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(marge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Vide(titre: 'Pas encore de profil', message: 'Quelques questions pour adapter l\'appli à toi.'),
                  BoutonPrincipal(label: 'Créer mon profil', onPressed: () => context.go(Paths.bienvenue)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final sessions = context.watch<SessionRepo>().sessions;
    final stats = CareerStats.from(sessions);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            // Le bandeau du haut s'étire : la page remplit l'écran, les
            // badges en bas, sans vide ni coupure. Sur un écran trop court,
            // le bandeau garde sa hauteur minimale et la page défile.
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: HautEtire(
                    etirementMax: e(110),
                    haut: Bloc(haut: 8, bas: 2, child: _Entete(profil: p)),
                    bas: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Bloc(
                          haut: 4,
                          bas: 6,
                          child: _Mois(sessions: sessions, serie: stats.semainesConsecutives),
                        ),
                        Bloc(
                          haut: 6,
                          bas: 6,
                          child: VitrineGrades(
                            grades: gradesDe(context, stats: stats),
                            largeur: e(56),
                            onTout: () => context.push(ProfilPaths.grades),
                          ),
                        ),
                        SizedBox(height: e(10)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le bandeau : la photo à gauche ; à sa droite le prénom et la roue des
/// réglages sur une ligne, puis une ligne « 458 séances · 4 amis » ; dessous,
/// la phrase libre sur toute la largeur. Ni pastille ni objectif : il se
/// change dans les réglages. Le bandeau prend la hauteur qu'on lui donne.
class _Entete extends StatelessWidget {
  const _Entete({required this.profil});
  final UserProfile profil;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final photo = profil.photo;
    final avecPhoto = photo != null && File(photo).existsSync();
    final sansPrenom = profil.prenom.trim().isEmpty;
    final cote = e(60);
    final phrase = profil.phrase.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Le bandeau : la photo de profil en grand et floutée, comme une
        // couverture ; sans photo, un bleu lumineux qui s'assombrit vers les
        // bords. Par-dessus, un voile noir vers le bas pour le texte.
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(e(24)),
              gradient: const RadialGradient(center: Alignment(-0.4, -0.5), radius: 1.25, colors: [Color(0xFF8FC2E3), Color(0xFF2C5676), Color(0xFF0D1A24)], stops: [0, 0.6, 1]),
            ),
            child: Stack(
              // Le contenu reçoit la hauteur du bandeau : il se cale en bas.
              fit: StackFit.passthrough,
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
                _contenuBandeau(context, c, avecPhoto: avecPhoto, photo: photo, sansPrenom: sansPrenom, cote: cote, phrase: phrase),
              ],
            ),
          ),
        ),
        ..._sousBandeau(context, c),
      ],
    );
  }

  Widget _contenuBandeau(BuildContext context, AppColors c, {required bool avecPhoto, required String? photo, required bool sansPrenom, required double cote, required String phrase}) {
    final social = context.watch<SocialRepo?>();
    final seances = context.watch<SessionRepo>().sessions.where((s) => !s.enCours).length;
    final ombre = [Shadow(blurRadius: 10, offset: const Offset(0, 1), color: Colors.black.withValues(alpha: 0.35))];
    final mot = txt(13, FontWeight.w500, Colors.white.withValues(alpha: 0.75), interligne: 1.2);
    final chiffre = txt(13, FontWeight.w700, Colors.white, interligne: 1.2);

    // Une donnée de la ligne : son icône, son chiffre en gras, son mot.
    Widget donnee(Trace trace, int n, String singulier, {VoidCallback? onTap}) {
      final libelle = n > 1 ? '${singulier}s' : singulier;
      final contenu = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconeTrait(trace, taille: e(14), couleur: Colors.white.withValues(alpha: 0.8)),
          SizedBox(width: e(5)),
          Text('$n', style: chiffre),
          SizedBox(width: e(3.5)),
          Text(libelle, style: mot),
          if (onTap != null) ...[SizedBox(width: e(3)), IconeTrait(Trace.chevron, taille: e(9), couleur: Colors.white.withValues(alpha: 0.5))],
        ],
      );
      return Semantics(
        button: onTap != null,
        label: '$n $libelle',
        excludeSemantics: true,
        child: onTap == null ? contenu : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: contenu),
      );
    }

    return Padding(
      padding: EdgeInsets.all(e(14.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: 'Changer la photo de profil',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => changerPhotoProfil(context, context.read<ProfileRepo>(), context.read<Store>()),
                  child: Container(
                    width: cote,
                    height: cote,
                    decoration: BoxDecoration(
                      color: c.surface2,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withValues(alpha: 0.55), width: e(2), strokeAlign: BorderSide.strokeAlignOutside),
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: avecPhoto
                        ? Image.file(File(photo!), fit: BoxFit.cover, width: cote, height: cote)
                        // Sans prénom : une silhouette, pas un point d'interrogation.
                        : sansPrenom
                        ? IconeTrait(Trace.silhouette, taille: e(28), couleur: c.text2)
                        : Text(profil.initiales, style: txt(24, FontWeight.w800, c.text, interligne: 1)),
                  ),
                ),
              ),
              SizedBox(width: e(11)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Le prénom et la roue partagent une ligne : chacun sa
                    // place, rien ne passe sous la roue. Un nom long rétrécit
                    // un peu, puis se coupe.
                    SizedBox(
                      height: e(36),
                      child: Row(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) => GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => context.push(social == null ? '${Paths.profil}/modifier' : SocialPaths.modifierProfil),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: box.maxWidth * 1.3),
                                    child: Text(
                                      sansPrenom ? 'Mon profil' : profil.prenom.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: txt(19, FontWeight.w800, Colors.white, interligne: 1.25, espacement: -0.01).copyWith(shadows: ombre),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: e(7)),
                          BoutonRond(trace: Trace.reglages, label: 'Réglages', taille: 36, tailleIcone: e(17), fond: Colors.black.withValues(alpha: 0.34), onTap: () => context.push(Paths.reglages)),
                        ],
                      ),
                    ),
                    SizedBox(height: e(5.5)),
                    // Mes séances et mes amis, en une ligne ; les amis se touchent.
                    SizedBox(
                      height: e(18),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            donnee(Trace.haltere, seances, 'séance'),
                            if (social != null) ...[
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: e(7)),
                                child: Text('·', style: txt(13, FontWeight.w700, Colors.white.withValues(alpha: 0.4), interligne: 1.2)),
                              ),
                              donnee(Trace.silhouette, social.amis.length, 'ami', onTap: () => context.push(SocialPaths.amis)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // La phrase libre, sur toute la largeur. Elle ne se touche pas : elle
          // se change dans « Modifier le profil », pas par un appui malheureux.
          if (phrase.isNotEmpty) ...[
            SizedBox(height: e(12.5)),
            Text(phrase, maxLines: 4, overflow: TextOverflow.ellipsis, style: txt(12.6, FontWeight.w400, Colors.white.withValues(alpha: 0.86), interligne: 1.43)),
          ],
        ],
      ),
    );
  }

  /// Sous le bandeau, avec la communauté : modifier mon profil, et le voir
  /// comme les autres le voient.
  List<Widget> _sousBandeau(BuildContext context, AppColors c) => [
    if (context.watch<SocialRepo?>() != null) ...[
      SizedBox(height: e(10)),
      Row(
        children: [
          Expanded(child: _bouton(c, 'Modifier le profil', () => context.push(SocialPaths.modifierProfil))),
          SizedBox(width: e(8)),
          Expanded(child: _bouton(c, 'Mon profil public', () => context.push(SocialPaths.monProfil))),
        ],
      ),
    ],
    SizedBox(height: e(6)),
  ];

  Widget _bouton(AppColors c, String texte, VoidCallback onTap) => Material(
        color: c.surface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: e(42),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: e(10)),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(texte, maxLines: 1, style: txt(13.5, FontWeight.w600, c.text))),
          ),
        ),
      );
}

/// Le mois en cours, avec les mêmes pastilles que le calendrier de Progrès ;
/// la série de semaines en haut à droite. Un appui ouvre le calendrier.
class _Mois extends StatelessWidget {
  const _Mois({required this.sessions, required this.serie});
  final List<WorkoutSession> sessions;
  final int serie;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final types = Calculs.typesParJour(sessions);
    final ceMois = sessions.where((s) => !s.enCours && s.debut.year == now.year && s.debut.month == now.month).length;
    final nom = Fmt.mois(now).split(' ').first;
    return Carte(
      onTap: () => context.push(ProfilPaths.calendrier),
      padding: EdgeInsets.fromLTRB(e(10), e(10), e(10), e(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(e(4), 0, e(2), e(6)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom, style: txt(15, FontWeight.w800, c.text)),
                      Text(ceMois == 0 ? 'Aucune séance ce mois-ci' : '${Fmt.pluriel(ceMois, 'séance')} ce mois-ci', style: txt(11, FontWeight.w400, c.text2)),
                    ],
                  ),
                ),
                if (serie > 0)
                  Container(
                    padding: EdgeInsets.fromLTRB(e(7), e(5), e(10), e(5)),
                    decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(e(99))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TraitIcone(AppIcone.flamme, size: e(15), color: const Color(0xFFFFBE0B), semanticLabel: 'Série'),
                        SizedBox(width: e(4)),
                        Text('$serie sem.', style: txt(11.5, FontWeight.w700, c.text)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Les appuis vont à la carte : tout le mois ouvre le calendrier.
          IgnorePointer(
            child: GrilleMois(mois: now, aujourdhui: now, premierJour: context.watch<SettingsRepo>().settings.premierJourSemaine, seance: (j) => types[Dates.jour(j)], taille: 30),
          ),
        ],
      ),
    );
  }
}
