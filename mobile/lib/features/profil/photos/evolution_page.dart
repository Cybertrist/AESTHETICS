import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/mensurations.dart';
import '../widgets/maquette.dart';
import 'cadrage.dart';

/// L'évolution d'un angle : toutes ses photos enchaînées en fondu, de la plus
/// ancienne à la plus récente, cadrées pareil, avec la date et le poids. Elle
/// se partage en vidéo.
class EvolutionPage extends StatefulWidget {
  const EvolutionPage({super.key, required this.vue});
  final PhotoVue vue;

  static Future<void> ouvrir(BuildContext context, PhotoVue vue) => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => EvolutionPage(vue: vue)),
      );

  @override
  State<EvolutionPage> createState() => _EvolutionPageState();
}

class _EvolutionPageState extends State<EvolutionPage> with SingleTickerProviderStateMixin {
  static const _canal = MethodChannel('aesthetics/video');
  static const _ips = 24;

  /// Secondes par photo : elle tient, puis fond vers la suivante.
  static const _tenue = 0.55, _fondu = 0.45;

  /// La dernière photo reste à l'écran avant que la boucle reprenne.
  static const _fin = 1.6;
  static const _cadre = Size(360, 640);

  final _cle = GlobalKey();
  late final AnimationController _anim = AnimationController(vsync: this);
  List<ProgressPhoto> _photos = const [];
  List<double?> _poids = const [];
  List<Cadrage>? _cadrages;
  double? _export;

  double get _duree => _photos.length * (_tenue + _fondu) - _fondu + _fin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cadrages != null || _photos.isNotEmpty) return;
    final sante = context.read<HealthRepo>();
    // De la plus ancienne à la plus récente ; les fichiers disparus sont passés.
    _photos = Mensurations.photosDe(sante.photos, widget.vue).reversed.where((p) => File(p.chemin).existsSync()).toList();
    _poids = [for (final p in _photos) Mensurations.poidsPhoto(p, sante.measurements)];
    if (_photos.length < 2) return;
    // Tous les cadrages d'abord : les photos s'enchaînent sans sauter.
    Future.wait([
      for (final p in _photos) Cadrage.de(File(p.chemin)).then<Cadrage?>((c) => c, onError: (Object _) => null),
    ]).then((r) {
      if (!mounted) return;
      final lisibles = [for (var i = 0; i < r.length; i++) if (r[i] != null) i];
      setState(() {
        _photos = [for (final i in lisibles) _photos[i]];
        _poids = [for (final i in lisibles) _poids[i]];
        _cadrages = [for (final i in lisibles) r[i]!];
      });
      if (_photos.length < 2) return;
      _anim
        ..duration = Duration(milliseconds: (_duree * 1000).round())
        ..repeat();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Filme l'animation image par image, puis ouvre le partage.
  Future<void> _partager() async {
    if (_export != null) return;
    setState(() => _export = 0);
    _anim.stop();
    var ouvert = false;
    try {
      final f = File('${Directory.systemTemp.path}${Platform.pathSeparator}evolution.mp4');
      await _canal.invokeMethod<void>('ouvrir', {'chemin': f.path, 'largeur': 720, 'hauteur': 1280, 'ips': _ips});
      ouvert = true;
      final images = (_duree * _ips).ceil();
      for (var i = 0; i < images; i++) {
        _anim.value = i / _ips / _duree;
        setState(() => _export = i / images);
        await WidgetsBinding.instance.endOfFrame;
        // À l'arrivée d'une photo, le temps qu'elle soit décodée.
        if (i % ((_tenue + _fondu) * _ips).round() == 0) await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        final ro = _cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await ro.toImage(pixelRatio: 720 / _cadre.width);
        final octets = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        await _canal.invokeMethod<void>('image', octets!.buffer.asUint8List());
      }
      await _canal.invokeMethod<void>('fermer');
      ouvert = false;
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'video/mp4', name: 'evolution.mp4')]));
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
  Widget build(BuildContext context) {
    final c = context.colors;
    final pret = _cadrages != null && _photos.length >= 2;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(e(8), e(4), e(16), e(4)),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.maybePop(context), icon: Icon(Icons.close_rounded, color: c.text), tooltip: 'Fermer'),
                  SizedBox(width: e(4)),
                  Text('Évolution · ${widget.vue.label.toLowerCase()}', style: txt(17, FontWeight.w700, c.text)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: e(16)),
                child: !pret
                    ? Center(
                        child: Text(
                          _photos.length < 2 ? 'Il faut au moins deux photos de cet angle.' : 'Préparation des photos…',
                          textAlign: TextAlign.center,
                          style: txt(14, FontWeight.w400, c.text2),
                        ),
                      )
                    : FittedBox(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: RepaintBoundary(
                            key: _cle,
                            child: SizedBox.fromSize(
                              size: _cadre,
                              child: ExcludeSemantics(
                                child: AnimatedBuilder(animation: _anim, builder: (context, _) => _dessin(_anim.value * _duree)),
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
                onPressed: !pret || _export != null || !Platform.isAndroid ? null : _partager,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(int i, double opacite) {
    final place = _cadrages![i].placeParmi(_cadrages!, _cadre);
    return Positioned.fromRect(
      rect: place,
      child: Opacity(
        opacity: opacite,
        child: Image.file(
          File(_photos[i].chemin),
          fit: BoxFit.fill,
          cacheWidth: ((place.width * 2 / 256).ceil() * 256).clamp(256, 2048),
          gaplessPlayback: true,
          errorBuilder: (context, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _dessin(double t) {
    final n = _photos.length;
    const pas = _tenue + _fondu;
    final i = (t / pas).floor().clamp(0, n - 1);
    // Part du fondu vers la photo suivante, de 0 à 1.
    final vers = i == n - 1 ? 0.0 : Curves.easeInOut.transform(((t - i * pas - _tenue) / _fondu).clamp(0.0, 1.0));
    // La date et le poids basculent au milieu du fondu.
    final j = vers > 0.5 ? i + 1 : i;
    final unite = context.read<ProfileRepo>().unite;
    final poids = _poids[j];
    const ombre = [Shadow(color: Color(0xCC000000), blurRadius: 14, offset: Offset(0, 2))];
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF1C1C1E))),
        _photo(i, 1),
        if (i + 1 < n) _photo(i + 1, vers),
        // La photo d'après est décodée d'avance, invisible.
        if (i + 2 < n) _photo(i + 2, 0),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 190,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xD9000000)])),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 44,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Mensurations.jourLong(_photos[j].date),
                style: const TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white, shadows: ombre),
              ),
              if (poids != null)
                Text.rich(
                  TextSpan(
                    text: Fmt.poidsAffiche(poids, unite).toStringAsFixed(1).replaceAll('.', ','),
                    children: [
                      TextSpan(
                        text: ' ${unite.label}',
                        style: const TextStyle(fontFamily: AppTokens.fontUi, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0, color: Color(0xFFE6E6EA)),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontFamily: AppTokens.fontBilan,
                    fontSize: 44,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.4,
                    color: Colors.white,
                    fontFeatures: AppTokens.tabular,
                    shadows: ombre,
                  ),
                ),
            ],
          ),
        ),
        // L'avancement dans la série.
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ((i + vers) / (n - 1)).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: const Color(0x40FFFFFF),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
