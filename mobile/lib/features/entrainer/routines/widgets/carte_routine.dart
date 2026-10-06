import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../seance/logic/partage.dart';
import '../../commun/elements.dart';
import '../logic/routine_stats.dart';

/// Partage d'une routine : en image, ou en texte.
Future<void> partagerRoutine(BuildContext context, Routine routine) async {
  final exos = context.read<ExerciseRepo>();
  final unite = context.read<ProfileRepo>().unite;
  final images = CarteRoutine.nbCartes(routine);
  final choix = await showPanneauBas<String>(
    context,
    titre: 'Partager la routine',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChoixPanneau(label: 'En image', detail: images > 1 ? '$images images' : 'une image', onTap: () => Navigator.pop(context, 'image')),
        ChoixPanneau(label: 'En texte', detail: 'la liste des exercices', onTap: () => Navigator.pop(context, 'texte')),
      ],
    ),
  );
  if (choix == null || !context.mounted) return;
  if (choix == 'texte') {
    await SharePlus.instance.share(ShareParams(text: routineEnTexte(routine, exos, unite), subject: routine.nom));
    return;
  }
  await showDialog<void>(context: context, useRootNavigator: true, builder: (_) => _ApercuCarte(routine: routine));
}

/// Aperçu des images, avec « Partager ».
class _ApercuCarte extends StatefulWidget {
  const _ApercuCarte({required this.routine});
  final Routine routine;

  @override
  State<_ApercuCarte> createState() => _ApercuCarteState();
}

class _ApercuCarteState extends State<_ApercuCarte> {
  late final int _pages = CarteRoutine.nbCartes(widget.routine);
  late final _cles = [for (var i = 0; i < _pages; i++) GlobalKey()];
  bool _occupe = false;

  Future<void> _partager() async {
    if (_occupe) return;
    setState(() => _occupe = true);
    try {
      final dossier = await getTemporaryDirectory();
      final fichiers = <XFile>[];
      for (final (i, cle) in _cles.indexed) {
        final png = await capturerCarte(cle);
        if (png == null) throw StateError('carte absente');
        final f = File('${dossier.path}/routine-${i + 1}.png');
        await f.writeAsBytes(png, flush: true);
        fichiers.add(XFile(f.path, mimeType: 'image/png'));
      }
      await SharePlus.instance.share(ShareParams(files: fichiers, text: widget.routine.nom));
    } catch (_) {
      if (mounted) Toasts.error(context, 'Le partage n\'est pas disponible.');
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              child: SizedBox(
                width: CarteRoutine.largeur,
                height: CarteRoutine.hauteur,
                // Toutes les images sont dessinées, pour être capturées d'un coup.
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const PageScrollPhysics(),
                  child: Row(
                    children: [
                      for (var i = 0; i < _pages; i++) RepaintBoundary(key: _cles[i], child: CarteRoutine(routine: widget.routine, page: i)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_pages > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('$_pages images · fais glisser pour les voir', style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13, color: c.text2)),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: BoutonSecondaire(label: 'Fermer', onPressed: () => Navigator.pop(context))),
              const SizedBox(width: 10),
              Expanded(child: BoutonPrincipal(label: _occupe ? 'Préparation…' : 'Partager', onPressed: _occupe ? null : _partager)),
            ],
          ),
        ],
      ),
    );
  }
}

/// La routine en image, au format d'une story (360 sur 640) : le nom, trois
/// chiffres, puis les exercices avec le personnage et leurs séries. Huit
/// exercices au plus par image, pour que chaque nom tienne en entier : une
/// routine plus longue donne plusieurs images. Un superset se lit à la barre
/// de couleur qui relie ses exercices, à gauche.
class CarteRoutine extends StatelessWidget {
  const CarteRoutine({super.key, required this.routine, this.page = 0});
  final Routine routine;

  /// Rang de l'image (0 pour la première).
  final int page;

  static const largeur = 360.0;
  static const hauteur = 640.0;
  static const parCarte = 8;

  /// Nombre d'images nécessaires pour la routine.
  static int nbCartes(Routine r) => r.exercices.isEmpty ? 1 : (r.exercices.length / parCarte).ceil();

  @override
  Widget build(BuildContext context) {
    final exos = context.read<ExerciseRepo>();
    final unite = context.read<ProfileRepo>().unite;
    final liste = routine.exercices;
    final n = liste.length;
    final ss = supersetsDe(liste);
    final pages = nbCartes(routine);
    final debut = page * parCarte;
    final fin = (debut + parCarte).clamp(0, n);
    // La hauteur d'une ligne ne dépend pas du nombre d'exercices de l'image :
    // deux images d'une même routine se ressemblent.
    const ligne = 54.0;
    const image = 42.0;
    final muscles = musclesPrincipaux(routine, exos.byId).map((m) => m.label).join(' · ');

    TextStyle t(double taille, FontWeight poids, Color couleur) => TextStyle(fontFamily: AppTokens.fontUi, fontSize: taille, height: 1.2, fontWeight: poids, color: couleur);

    Widget rang(int i) {
      final re = liste[i];
      final ex = exos.byId(re.exerciseId);
      final superset = ss[re.supersetId];
      final suite = superset != null && i + 1 < fin && liste[i + 1].supersetId == re.supersetId;
      final precede = superset != null && i > debut && liste[i - 1].supersetId == re.supersetId;
      return SizedBox(
        height: ligne,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre du superset : elle court d'un exercice à l'autre.
            Container(
              width: 4,
              margin: EdgeInsets.only(top: precede ? 0 : 6, bottom: suite ? 0 : 6),
              decoration: BoxDecoration(
                color: superset?.couleur ?? Colors.transparent,
                borderRadius: BorderRadius.vertical(top: Radius.circular(precede ? 0 : 2), bottom: Radius.circular(suite ? 0 : 2)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 15, child: Center(child: Text('${i + 1}', style: t(11, FontWeight.w800, const Color(0xFF8E8E96))))),
            const SizedBox(width: 7),
            Center(child: TuileExercice(ex, taille: image, fond: const Color(0xFF2B2B30))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Deux lignes au besoin : le nom n'est jamais coupé d'un « … » court.
                  Text(exos.nameOf(re.exerciseId), maxLines: 2, overflow: TextOverflow.ellipsis, style: t(12.5, FontWeight.w700, Colors.white).copyWith(height: 1.15)),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: resumeSeries(re, ex, unite)),
                      if (superset != null) TextSpan(text: '  Superset ${superset.lettre}', style: TextStyle(color: superset.couleur, fontWeight: FontWeight.w700)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t(10.5, FontWeight.w500, const Color(0xFFC9C9D1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget chiffre(String valeur, String label) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(valeur, style: t(16, FontWeight.w800, Colors.white)),
                Text(label, style: t(10.5, FontWeight.w500, const Color(0xFFC9C9D1))),
              ],
            ),
          ),
        );

    return Container(
      width: largeur,
      height: hauteur,
      padding: const EdgeInsets.fromLTRB(13, 16, 15, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomCenter, colors: [Color(0xFF3B0D14), Color(0xFF141416)], stops: [0, 0.34]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 70,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pages > 1 ? 'ROUTINE · ${page + 1} SUR $pages' : 'ROUTINE', style: t(10, FontWeight.w700, const Color(0xFFF1B9BF)).copyWith(letterSpacing: 1.4)),
                  const SizedBox(height: 3),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: Text(
                        routine.nom.trim().isEmpty ? 'ROUTINE' : routine.nom.trim().toUpperCase(),
                        maxLines: 1,
                        style: const TextStyle(fontFamily: 'Montserrat', fontSize: 30, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -0.6, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  chiffre('$n', n >= 2 ? 'exercices' : 'exercice'),
                  chiffre('${routine.nbSeries}', routine.nbSeries >= 2 ? 'séries' : 'série'),
                  chiffre(Fmt.duree(Duration(minutes: routine.dureeEstimeeMin)), 'environ'),
                ],
              ),
            ),
          ),
          Expanded(child: Column(children: [for (var i = debut; i < fin; i++) rang(i)])),
          SizedBox(
            height: 26,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Expanded(child: Text(muscles, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(11, FontWeight.w500, const Color(0xFFB9B9C2)))),
                  const AppWordmark(size: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
