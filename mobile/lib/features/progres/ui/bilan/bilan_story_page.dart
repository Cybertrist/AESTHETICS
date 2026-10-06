import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/theme/theme.dart';
import '../../logic/bilan_mois.dart';
import '../../logic/tableau.dart';
import 'couleurs.dart';
import 'pages.dart';

/// Les dix pages du bilan, dans l'ordre.
enum PageBilan { ouverture, seances, regularite, volume, equivalent, serie, muscles, records, favoris, resume }

/// Bilan du mois façon story : dix pages plein écran qui s'enchaînent au
/// toucher (à droite pour avancer, à gauche pour revenir), la barre de
/// segments en haut, la croix, « Partager » en bas.
class BilanStoryPage extends StatefulWidget {
  const BilanStoryPage({super.key, this.mois, this.annee, this.maintenant, this.pageInitiale = PageBilan.ouverture});

  /// Mois du bilan (le mois précédent par défaut).
  final DateTime? mois;

  /// Année du bilan annuel ; passe devant [mois].
  final int? annee;
  final DateTime? maintenant;
  final PageBilan pageInitiale;

  @override
  State<BilanStoryPage> createState() => _BilanStoryPageState();
}

class _BilanStoryPageState extends State<BilanStoryPage> with SingleTickerProviderStateMixin {
  final _cadre = GlobalKey();
  late int _page = widget.pageInitiale.index;

  /// Le tempo des entrées : chaque page se construit en une seconde et
  /// demie, à chaque fois qu'on y arrive.
  late final _tempo = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

  @override
  void dispose() {
    _tempo.dispose();
    super.dispose();
  }

  /// Pendant l'export, la barre, la croix et « Partager » disparaissent.
  bool _export = false;
  bool _envoi = false;

  DateTime get _now => widget.maintenant ?? DateTime.now();

  /// Le mois demandé, le mois précédent par défaut. Un mois à venir n'a
  /// pas de bilan : on montre le mois en cours.
  DateTime get _mois {
    final m = widget.mois;
    if (m == null) return DateTime(_now.year, _now.month - 1);
    final courant = DateTime(_now.year, _now.month);
    return m.isAfter(courant) ? courant : DateTime(m.year, m.month);
  }

  /// L'année du bilan annuel (jamais une année à venir), ou null pour un mois.
  int? get _annee {
    final a = widget.annee;
    return a == null ? null : (a > _now.year ? _now.year : a);
  }

  @override
  void didUpdateWidget(BilanStoryPage old) {
    super.didUpdateWidget(old);
    // Le même écran rouvert sur une autre page (`?page=`) ou un autre mois.
    if (old.pageInitiale != widget.pageInitiale || old.mois != widget.mois || old.annee != widget.annee) {
      _page = widget.pageInitiale.index;
      _tempo.forward(from: 0);
    }
  }

  void _aller(int pas) {
    final p = _page + pas;
    // Pendant l'export, la page ne change pas sous l'image.
    if (_export || p < 0) return;
    // Après la dernière page, avancer ferme le bilan.
    if (p >= PageBilan.values.length) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _page = p);
    _tempo.forward(from: 0);
  }

  Future<void> _partager() async {
    if (_envoi) return;
    final messager = ScaffoldMessenger.of(context);
    // L'image partagée montre la page entière, pas une entrée en cours.
    _tempo.value = 1;
    setState(() {
      _envoi = true;
      _export = true;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final rendu = _cadre.currentContext?.findRenderObject();
      if (rendu is! RenderRepaintBoundary) return;
      final image = await rendu.toImage(pixelRatio: 3);
      final octets = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (octets == null) return;
      final dossier = await getTemporaryDirectory();
      final annee = _annee;
      final fichier = File('${dossier.path}/bilan-${annee ?? Calculs.cleMois(_mois)}-${PageBilan.values[_page].name}.png');
      await fichier.writeAsBytes(octets.buffer.asUint8List(), flush: true);
      if (mounted) setState(() => _export = false);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(fichier.path, mimeType: 'image/png')],
        subject: annee == null ? 'Mon bilan ${deMois(_mois)} ${_mois.year}' : 'Mon bilan de $annee',
      ));
    } catch (_) {
      messager.showSnackBar(const SnackBar(content: Text('Le partage n\'a pas abouti. Réessaie dans un instant.')));
    } finally {
      if (mounted) {
        setState(() {
          _envoi = false;
          _export = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionRepo>().sessions;
    final exos = context.watch<ExerciseRepo>();
    final annee = _annee;
    final bilan = annee == null ? BilanMois.calculer(_mois, sessions, exos.byId, now: _now) : BilanMois.calculerAnnee(annee, sessions, exos.byId, now: _now);
    // La graine fixe l'objet pour un mois (ou une année) : le même à chaque ouverture.
    final equivalent = equivalentPour(bilan.volume, graine: annee ?? _mois.year * 12 + _mois.month, mois: true);
    final page = PageBilan.values[_page];

    final (haut, bas) = switch (page) {
      PageBilan.ouverture => CouleursBilan.ouverture,
      PageBilan.seances => CouleursBilan.seances,
      PageBilan.regularite => CouleursBilan.regularite,
      PageBilan.volume => CouleursBilan.volume,
      PageBilan.equivalent => (equivalent.couleur, CouleursBilan.noir),
      PageBilan.serie => CouleursBilan.serie,
      PageBilan.muscles => CouleursBilan.muscles,
      PageBilan.records => CouleursBilan.records,
      PageBilan.favoris => CouleursBilan.favoris,
      PageBilan.resume => CouleursBilan.resume,
    };

    final corps = switch (page) {
      PageBilan.ouverture => PageOuverture(annuel: bilan.annuel),
      PageBilan.seances => PageSeances(bilan: bilan),
      PageBilan.regularite => PageRegularite(bilan: bilan),
      PageBilan.volume => PageVolume(bilan: bilan),
      PageBilan.equivalent => PageEquivalent(bilan: bilan, equivalent: equivalent),
      PageBilan.serie => PageSerie(bilan: bilan),
      PageBilan.muscles => PageMuscles(bilan: bilan),
      PageBilan.records => PageRecords(bilan: bilan, nomDe: exos.nameOf),
      PageBilan.favoris => PageFavoris(bilan: bilan, exerciceDe: exos.byId, nomDe: exos.nameOf),
      PageBilan.resume => PageResume(bilan: bilan),
    };

    final chrome = _export ? 0.0 : 1.0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: CouleursBilan.noir,
        body: RepaintBoundary(
          key: _cadre,
          child: AnimatedContainer(
            duration: AppTokens.normal,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [haut, bas],
                stops: const [0, 0.68],
              ),
            ),
            child: Stack(
              children: [
                // Toucher : le tiers gauche revient, le reste avance.
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _aller(d.localPosition.dx < box.maxWidth / 3 ? -1 : 1),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22.5, 8, 22.5, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Opacity(
                              opacity: chrome,
                              child: _Segments(
                                total: PageBilan.values.length,
                                atteint: _page,
                                // Au lecteur d'écran, la dernière page se
                                // ferme par la croix, pas par « suivant ».
                                suivante: _page < PageBilan.values.length - 1 ? () => _aller(1) : null,
                                precedente: _page > 0 ? () => _aller(-1) : null,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Opacity(
                                opacity: chrome,
                                child: Transform.translate(
                                  offset: const Offset(-15, 0),
                                  child: IconButton(
                                    tooltip: 'Fermer le bilan',
                                    onPressed: () => Navigator.of(context).maybePop(),
                                    iconSize: 30,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(width: 55, height: 55),
                                    icon: const _Croix(),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: IgnorePointer(
                                child: LayoutBuilder(
                                  builder: (context, box) => Center(
                                    // La page garde sa largeur et rétrécit
                                    // d'un bloc si l'écran est trop court.
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: SizedBox(
                                        width: box.maxWidth,
                                        // Une affiche, pas un texte courant : la
                                        // taille de police du téléphone n'y
                                        // touche pas (l'image partagée non plus).
                                        child: MediaQuery.withNoTextScaling(
                                          child: TempoBilan(
                                            tempo: _tempo,
                                            child: KeyedSubtree(
                                              key: ValueKey(page),
                                              child: page == PageBilan.seances ? PageSeances(bilan: bilan, hauteur: box.maxHeight) : corps,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const IgnorePointer(child: _Marque()),
                            Opacity(
                              opacity: chrome,
                              child: Center(child: _BoutonPartager(onTap: _envoi ? null : _partager)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre de segments : un par page, blancs jusqu'à la page affichée.
class _Segments extends StatelessWidget {
  const _Segments({required this.total, required this.atteint, this.suivante, this.precedente});
  final int total;
  final int atteint;

  /// Changer de page au lecteur d'écran (le toucher à gauche ou à droite
  /// de l'écran n'a pas de libellé).
  final VoidCallback? suivante;
  final VoidCallback? precedente;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Page ${atteint + 1} sur $total',
        onIncrease: suivante,
        onDecrease: precedente,
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 3.75),
              Expanded(
                child: Container(
                  height: 3.75,
                  decoration: BoxDecoration(
                    color: i <= atteint ? CouleursBilan.encre : CouleursBilan.segment,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _Croix extends StatelessWidget {
  const _Croix();

  @override
  Widget build(BuildContext context) => const SizedBox.square(dimension: 22.5, child: CustomPaint(painter: _CroixPainter()));
}

class _CroixPainter extends CustomPainter {
  const _CroixPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Grille de 18 : de 4 à 14, trait de 2,2.
    final k = size.width / 18;
    final trait = Paint()
      ..strokeWidth = 2.2 * k
      ..strokeCap = StrokeCap.round
      ..color = CouleursBilan.encre;
    canvas.drawLine(Offset(4 * k, 4 * k), Offset(14 * k, 14 * k), trait);
    canvas.drawLine(Offset(14 * k, 4 * k), Offset(4 * k, 14 * k), trait);
  }

  @override
  bool shouldRepaint(_CroixPainter old) => false;
}

/// « AESTHETICS », d'une seule couleur.
class _Marque extends StatelessWidget {
  const _Marque();

  @override
  Widget build(BuildContext context) => Text(
        'AESTHETICS',
        textAlign: TextAlign.center,
        style: tb(21.25, FontWeight.w900, hauteur: 1.35, espace: 0.42).copyWith(color: CouleursBilan.encre),
      );
}

class _BoutonPartager extends StatelessWidget {
  const _BoutonPartager({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Partager cette page',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 55,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(dimension: 22.5, child: CustomPaint(painter: _FlechePainter())),
                  const SizedBox(width: 9),
                  Text('Partager', style: tb(18.75, FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Flèche de partage de la maquette (grille de 22), pleine.
class _FlechePainter extends CustomPainter {
  const _FlechePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22);
    final p = Path()
      ..moveTo(12.5, 4.5)
      ..lineTo(18.5, 10)
      ..lineTo(12.5, 15.5)
      ..lineTo(12.5, 12.2)
      ..cubicTo(8.5, 12.2, 5.7, 13.2, 4, 16.2)
      ..cubicTo(4, 11.4, 6.5, 7.9, 12.5, 7.7)
      ..close();
    canvas.drawPath(p, Paint()..color = CouleursBilan.encre);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeJoin = StrokeJoin.round
        ..color = CouleursBilan.encre,
    );
  }

  @override
  bool shouldRepaint(_FlechePainter old) => false;
}
