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

/// Le bandeau bleu : la roue des réglages dans le coin en haut à droite,
/// la photo, le prénom et la phrase libre en bas ; dessous, la pastille de
/// l'objectif. Le bandeau prend la hauteur qu'on lui donne.
class _Entete extends StatelessWidget {
  const _Entete({required this.profil});
  final UserProfile profil;

  /// Longueur maximale de la phrase du profil.
  static const longueurPhrase = 140;

  Future<void> _ecrirePhrase(BuildContext context) async {
    final repo = context.read<ProfileRepo>();
    final texte = await showPanneauBas<String>(
      context,
      titre: 'Ta phrase',
      builder: (context) => _SaisiePhrase(initiale: profil.phrase),
    );
    if (texte != null) await repo.update((p) => p.copyWith(phrase: texte.trim()));
  }

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
              borderRadius: BorderRadius.circular(e(20)),
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
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.8)]),
                    ),
                  ),
                ),
                _contenuBandeau(context, c, avecPhoto: avecPhoto, photo: photo, sansPrenom: sansPrenom, cote: cote, phrase: phrase),
                Positioned(
                  top: e(8),
                  right: e(8),
                  child: BoutonRond(trace: Trace.reglages, label: 'Réglages', taille: 36, tailleIcone: e(17), fond: Colors.black.withValues(alpha: 0.35), onTap: () => context.push(Paths.reglages)),
                ),
              ],
            ),
          ),
        ),
        ..._sousBandeau(context, c),
      ],
    );
  }

  Widget _contenuBandeau(BuildContext context, AppColors c, {required bool avecPhoto, required String? photo, required bool sansPrenom, required double cote, required String phrase}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(e(12), e(10), e(10), e(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      border: Border.all(color: Colors.black, width: e(2.5), strokeAlign: BorderSide.strokeAlignOutside),
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
              SizedBox(width: e(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Le prénom laisse la place de la roue à droite : sur un
                    // écran court, le bandeau est bas et la roue arrive à sa hauteur.
                    Padding(
                      padding: EdgeInsets.only(right: e(38)),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push('${Paths.profil}/modifier'),
                        child: Text(sansPrenom ? 'Mon profil' : profil.prenom.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(21, FontWeight.w800, Colors.white, espacement: -0.01)),
                      ),
                    ),
                    // La phrase libre : la tienne, ou une invitation discrète à l'écrire.
                    Semantics(
                      button: true,
                      label: phrase.isEmpty ? 'Ajouter une phrase' : 'Modifier ta phrase : $phrase',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _ecrirePhrase(context),
                        child: Text(
                          phrase.isEmpty ? 'Ajoute une phrase : ta devise, ton but.' : phrase,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: txt(11.5, FontWeight.w400, Colors.white.withValues(alpha: phrase.isEmpty ? 0.6 : 0.9), interligne: 1.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _sousBandeau(BuildContext context, AppColors c) => [
    SizedBox(height: e(9)),
    Material(
      color: c.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('${Paths.profil}/modifier?section=objectif'),
        child: Padding(
          padding: EdgeInsets.fromLTRB(e(12), e(6), e(9), e(6)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${profil.objectif.label} · ${Fmt.pluriel(profil.joursParSemaine, 'séance par semaine', 'séances par semaine')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: txt(11.5, FontWeight.w600, c.text),
                ),
              ),
              SizedBox(width: e(5)),
              IconeTrait(Trace.chevron, taille: e(11), couleur: c.text2),
            ],
          ),
        ),
      ),
    ),
    SizedBox(height: e(6)),
  ];
}

/// Champ de saisie de la phrase du profil, dans le panneau du bas.
class _SaisiePhrase extends StatefulWidget {
  const _SaisiePhrase({required this.initiale});
  final String initiale;

  @override
  State<_SaisiePhrase> createState() => _SaisiePhraseState();
}

class _SaisiePhraseState extends State<_SaisiePhrase> {
  late final _ctrl = TextEditingController(text: widget.initiale);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      // Le panneau remonte avec le clavier.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: _Entete.longueurPhrase,
            textCapitalization: TextCapitalization.sentences,
            style: txt(13, FontWeight.w400, c.text, interligne: 1.4),
            cursorColor: c.text,
            decoration: InputDecoration(
              hintText: 'La douleur est temporaire, la fierté dure toute une vie.',
              hintStyle: txt(13, FontWeight.w400, c.text3, interligne: 1.4),
              counterStyle: txt(10, FontWeight.w400, c.text2),
              filled: true,
              fillColor: AppTokens.surface3,
              contentPadding: EdgeInsets.all(e(12)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(e(14)), borderSide: BorderSide.none),
            ),
          ),
          SizedBox(height: e(10)),
          BoutonPrincipal(label: 'Enregistrer', onPressed: () => Navigator.pop(context, _ctrl.text)),
          if (widget.initiale.trim().isNotEmpty) ...[
            SizedBox(height: e(4)),
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text('Retirer la phrase', style: txt(12, FontWeight.w600, c.text2)),
            ),
          ],
        ],
      ),
    );
  }
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
