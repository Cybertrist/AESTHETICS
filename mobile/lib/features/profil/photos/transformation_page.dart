import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/mensurations.dart';
import '../widgets/maquette.dart';
import 'cadrage.dart';

/// Le poids perdu compté en burgers.
abstract final class BurgersPerdus {
  /// Poids d'un burger, le même que dans les équivalents du bilan.
  static const kgBurger = 0.25;

  static int nombre(double kg) => math.max(1, (kg / kgBurger).round());
}

/// L'animation de transformation : les burgers surgissent autour de la
/// photo d'avant pendant que le poids descend, un éclat fait place à la
/// photo d'après, puis tout file vers le gros burger du bas. Elle se partage
/// en vidéo.
class TransformationPage extends StatefulWidget {
  const TransformationPage({
    super.key,
    required this.avant,
    required this.apres,
    required this.poidsAvant,
    required this.poidsApres,
    required this.unite,
    required this.ecart,
  });

  final ProgressPhoto avant;
  final ProgressPhoto apres;
  final double poidsAvant;
  final double poidsApres;
  final UnitePoids unite;

  /// « −17 kg en 15 semaines ».
  final String ecart;

  @override
  State<TransformationPage> createState() => _TransformationPageState();
}

class _TransformationPageState extends State<TransformationPage> with SingleTickerProviderStateMixin {
  static const _duree = 10.5;
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 10500))..repeat();
  static const _canal = MethodChannel('aesthetics/video');
  static const _ips = 30;

  /// La vidéo s'arrête là : tout est en place depuis deux secondes.
  static const _secondesVideo = 8;
  final _cle = GlobalKey();
  late final _scene = _Scene(BurgersPerdus.nombre(widget.poidsAvant - widget.poidsApres));

  /// Avancement de l'export, de 0 à 1 ; null quand rien n'est en cours.
  double? _export;

  /// Filme l'animation image par image, puis ouvre le partage.
  Future<void> _partager() async {
    if (_export != null) return;
    setState(() => _export = 0);
    _anim.stop();
    var ouvert = false;
    try {
      final f = File('${Directory.systemTemp.path}${Platform.pathSeparator}transformation.mp4');
      await _canal.invokeMethod<void>('ouvrir', {'chemin': f.path, 'largeur': 720, 'hauteur': 1280, 'ips': _ips});
      ouvert = true;
      const images = _secondesVideo * _ips;
      for (var i = 0; i < images; i++) {
        _anim.value = i / _ips / _duree;
        setState(() => _export = i / images);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final ro = _cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await ro.toImage(pixelRatio: 720 / _Scene.l);
        final octets = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        await _canal.invokeMethod<void>('image', octets!.buffer.asUint8List());
      }
      await _canal.invokeMethod<void>('fermer');
      ouvert = false;
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'video/mp4', name: 'transformation.mp4')], text: widget.ecart));
    } catch (_) {
      if (mounted) Toasts.error(context, 'Partage impossible pour l\'instant.');
    } finally {
      if (ouvert) _canal.invokeMethod<void>('annuler').ignore();
      if (mounted) {
        setState(() => _export = null);
        _anim.repeat();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(Objets3D.burger), context);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  String get _phrase => '${Fmt.pluriel(_scene.nombre, 'burger')} de moins à porter.\nSans les frites.';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(e(8), e(4), e(16), e(4)),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(Icons.close_rounded, color: c.text),
                    tooltip: 'Fermer',
                  ),
                  SizedBox(width: e(4)),
                  Text('Transformation', style: txt(17, FontWeight.w700, c.text)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: e(16)),
                child: FittedBox(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: RepaintBoundary(
                      key: _cle,
                      child: SizedBox(
                        width: _Scene.l,
                        height: _Scene.h,
                        child: ExcludeSemantics(
                          child: AnimatedBuilder(
                            animation: _anim,
                            builder: (context, _) => _dessin(_anim.value * _duree),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(e(16), e(12), e(16), e(12)),
              child: BoutonPrincipal(
                label: _export == null ? 'Partager la vidéo' : 'Préparation de la vidéo… ${(_export! * 100).round()} %',
                onPressed: _export != null || !Platform.isAndroid ? null : _partager,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle _gros(double taille, {Color couleur = Colors.white}) => TextStyle(
        fontFamily: AppTokens.fontBilan,
        fontSize: taille,
        height: 1,
        fontWeight: FontWeight.w900,
        color: couleur,
        fontFeatures: AppTokens.tabular,
      );

  static const _creme = Color(0xFFF1DFD0);
  static const _ombreTexte = [Shadow(color: Color(0xCC000000), blurRadius: 14, offset: Offset(0, 2))];

  Widget _photo(ProgressPhoto p, ProgressPhoto autre) => PhotoCadree(
        fichier: File(p.chemin),
        paire: File(autre.chemin),
        alignement: Alignment.topCenter,
        secours: const ColoredBox(color: Color(0xFF1C1C1E)),
      );

  Widget _pose(double x, double y, double angle, double echelle, Widget enfant) => Transform(
        transform: Matrix4.translationValues(x, y, 0)
          ..rotateZ(angle * math.pi / 180)
          ..scaleByDouble(echelle, echelle, 1, 1),
        alignment: Alignment.center,
        child: enfant,
      );

  Widget _halo(double cote, Color couleur) => Container(
        width: cote,
        height: cote,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [couleur, couleur.withValues(alpha: 0)])),
      );

  Widget _pastille(String texte, double taille) => Container(
        padding: EdgeInsets.symmetric(horizontal: taille * 0.7, vertical: taille * 0.35),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTokens.radiusPill,
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 5))],
        ),
        child: Text(texte, style: _gros(taille, couleur: Colors.black).copyWith(height: 1.2)),
      );

  Widget _dessin(double t) {
    final s = _scene;
    _Objet? dernier;
    final burgers = <Widget>[];
    for (final o in s.ordre) {
      final pop = _seg(t, o.depart, o.depart + .28);
      if (t >= o.depart && (dernier == null || o.depart > dernier.depart)) dernier = o;
      // Tous filent ensuite vers le bas.
      final lin = _seg(t, 3.9 + o.fond * .35, 4.6 + o.fond * .35);
      final va = math.pow(lin, 2.2).toDouble();
      if (pop == 0 || va >= 1) continue;
      final x = _lerp(o.x, 180, va), y = _lerp(o.y, 488, va) - 26 * math.sin(math.pi * va);
      burgers.add(Positioned(
        left: -32,
        top: -32,
        child: _pose(
          x,
          y + 3 * math.sin(t * 2.2 + o.bal),
          o.angle + 5 * math.sin(t * 1.7 + o.bal) + 200 * va,
          _ressort(pop) * o.echelle * _lerp(1, .35, va),
          Image.asset(
            Objets3D.burger,
            width: 64,
            height: 64,
            opacity: AlwaysStoppedAnimation(_lerp(.55, 1, o.fond) * (1 - _seg(va, .85, 1))),
          ),
        ),
      ));
    }

    final entree = _sortie(_seg(t, 0, .7));
    // La carte tressaute à chaque burger qui sort.
    final coup = dernier != null && t < 3.4 ? 1 - _seg(t, dernier.depart, dernier.depart + .12) : 0.0;
    final apres = t > 2.5;
    final poids = widget.poidsAvant - (widget.poidsAvant - widget.poidsApres) * (dernier?.cumul ?? 0);
    final chiffre = Fmt.poidsAffiche(poids, widget.unite).toStringAsFixed(1).replaceAll('.', ',');
    final phrase = _seg(t, 5.4, 5.9);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF7A4316), Color(0xFF3A1D0A), Color(0xFF0C0603), Colors.black],
                stops: [0, .45, .82, 1],
              ),
            ),
          ),
        ),
        // La lueur chaude du haut.
        Positioned(left: -30, top: -120, child: Transform.scale(scaleX: 1.2, child: _halo(420, const Color(0x8CFFBE6E)))),
        ...burgers,
        Positioned(
          left: 84,
          top: 34,
          child: Opacity(
            opacity: entree,
            child: _pose(
              0,
              _lerp(40, 0, entree),
              0,
              1 + .02 * coup,
              Container(
                width: 192,
                height: 288,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, 16))],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _photo(widget.avant, widget.apres),
                    // Les deux photos restent décodées : la bascule est nette.
                    Opacity(opacity: apres ? 1 : 0, child: _photo(widget.apres, widget.avant)),
                    if (apres) ColoredBox(color: Colors.white.withValues(alpha: .9 * (1 - _seg(t, 2.5, 3)))),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0x80000000), borderRadius: BorderRadius.circular(7)),
                        child: Text(
                          Mensurations.jourLong((apres ? widget.apres : widget.avant).date),
                          style: const TextStyle(fontFamily: AppTokens.fontUi, fontSize: 12, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 336,
          child: Opacity(
            opacity: entree,
            child: Transform.scale(
              scale: 1 + .05 * coup,
              child: Text.rich(
                TextSpan(
                  text: chiffre,
                  children: [
                    TextSpan(
                      text: ' ${widget.unite.label}',
                      style: const TextStyle(fontFamily: AppTokens.fontUi, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0, color: _creme),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: _gros(52).copyWith(letterSpacing: -1.8, shadows: _ombreTexte),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 392,
          child: Opacity(
            opacity: _seg(t, 3.5, 3.9),
            child: Text(
              widget.ecart,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14, height: 1.2, fontWeight: FontWeight.w700, color: _creme, shadows: _ombreTexte),
            ),
          ),
        ),
        Positioned(
          left: 80,
          top: 404,
          child: Opacity(
            opacity: _seg(t, 4.5, 5.1),
            child: Transform.scale(scale: _lerp(.4, 1, _sortie(_seg(t, 4.5, 5.1))) + .04 * math.sin(t * 2), child: _halo(200, const Color(0x99FFAA46))),
          ),
        ),
        Positioned(
          left: 120,
          top: 428,
          child: _pose(0, 0, -12, _ressort(_seg(t, 4.5, 5.1)), Image.asset(Objets3D.burger, width: 120, height: 120)),
        ),
        Positioned(
          left: 204,
          top: 506,
          child: _pose(0, 0, -6, _ressort(_seg(t, 5.1, 5.4)), _pastille('× ${s.nombre}', 17)),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 568,
          child: Opacity(
            opacity: phrase,
            child: Transform.translate(
              offset: Offset(0, _lerp(10, 0, _sortie(phrase))),
              child: Text(
                _phrase,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: AppTokens.fontUi, fontSize: 16, height: 1.3, fontWeight: FontWeight.w700, color: Colors.white, shadows: _ombreTexte),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _sortie(double x) => 1 - math.pow(1 - x, 3).toDouble();

/// Arrive en dépassant un peu sa taille, puis revient ; 0 tant que rien n'a commencé.
double _ressort(double x) {
  if (x <= 0) return 0;
  const c = 1.9;
  return 1 + (c + 1) * math.pow(x - 1, 3) + c * math.pow(x - 1, 2);
}

class _Objet {
  _Objet({required this.x, required this.y, required this.angle, required this.echelle, required this.fond, required this.bal});
  final double x, y, angle, echelle, fond, bal;
  double depart = 0;

  /// Part du poids perdu une fois ce burger sorti.
  double cumul = 0;
}

/// Où et quand sort chaque burger : le tirage est fixe, la scène se rejoue
/// toujours à l'identique.
class _Scene {
  _Scene(this.nombre) {
    final alea = math.Random(7);
    // Au plus [_max] burgers à l'écran, même quand le compte en annonce plus.
    final n = math.min(nombre, _max);
    final objets = <_Objet>[];
    while (objets.length < n) {
      final x = -6 + alea.nextDouble() * (l + 12), y = 6 + alea.nextDouble() * (h - 60);
      // Jamais sur la photo.
      if (x > 104 && x < 256 && y > 54 && y < 302) continue;
      final fond = alea.nextDouble();
      objets.add(_Objet(x: x, y: y, angle: -30 + alea.nextDouble() * 60, echelle: _lerp(.5, 1.05, fond), fond: fond, bal: alea.nextDouble() * 6));
    }
    // Ils sortent de plus en plus vite ; le poids descend d'un cran à chacun.
    for (var i = 0; i < n; i++) {
      objets[i].depart = 1 + 2.3 * math.pow(n == 1 ? 1 : i / (n - 1), .62);
      objets[i].cumul = (i + 1) / n;
    }
    // Les plus petits derrière, les plus gros devant.
    ordre = [...objets]..sort((a, b) => a.echelle.compareTo(b.echelle));
  }

  static const l = 360.0, h = 640.0;
  static const _max = 96;

  /// Nombre de burgers perdus, celui de la pastille.
  final int nombre;
  late final List<_Objet> ordre;
}
