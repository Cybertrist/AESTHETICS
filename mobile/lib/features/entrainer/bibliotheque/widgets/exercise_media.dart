import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';

/// Faux dans les tests : aucune image réseau (pas de cache disque).
@visibleForTesting
bool mediaNetworkEnabled = true;

/// Image d'une adresse quelconque : asset embarqué, URL (cache disque) ou
/// fichier local (photo d'un exercice perso). Jamais étirée.
Widget mediaImage(
  String src, {
  BoxFit fit = BoxFit.contain,
  WidgetBuilder? loading,
  WidgetBuilder? error,
  int? cacheWidth,
}) {
  Widget err(BuildContext c, Object e, StackTrace? s) => error?.call(c) ?? const SizedBox.shrink();
  if (src.startsWith('assets/')) {
    return Image.asset(src, fit: fit, cacheWidth: cacheWidth, errorBuilder: err, gaplessPlayback: true);
  }
  if (src.startsWith('http')) {
    if (!mediaNetworkEnabled) return Builder(builder: (c) => error?.call(c) ?? const SizedBox.shrink());
    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: loading == null ? null : (c, _) => loading(c),
      errorWidget: (c, _, e) => error?.call(c) ?? const SizedBox.shrink(),
    );
  }
  return Image.file(File(src), fit: fit, cacheWidth: cacheWidth, errorBuilder: err, gaplessPlayback: true);
}

/// Fournisseur d'image pour une adresse quelconque (asset, URL, fichier).
ImageProvider? mediaProvider(String? src) {
  if (src == null || src.isEmpty) return null;
  if (src.startsWith('assets/')) return AssetImage(src);
  if (src.startsWith('http')) return mediaNetworkEnabled ? CachedNetworkImageProvider(src) : null;
  return FileImage(File(src));
}

/// Vignette carrée d'un exercice : fond gris arrondi (les images ont un
/// fond transparent), jamais étirée. Sans média : icône à halo.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb(this.exercise, {super.key, this.size = 48});

  final Exercise? exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final src = exercise?.media.thumbnail;
    if (src == null) return IconHalo(icon: Icons.fitness_center_rounded, color: c.training, size: size, glow: false);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: size,
        height: size,
        color: c.surface2,
        padding: EdgeInsets.all(size * 0.04),
        child: mediaImage(
          src,
          cacheWidth: (size * dpr).round(),
          loading: (_) => ColoredBox(color: c.surface2),
          error: (_) => Container(
            color: c.surface3,
            alignment: Alignment.center,
            child: Icon(Icons.fitness_center_rounded, size: size * 0.45, color: c.training),
          ),
        ),
      ),
    );
  }
}

/// Ligne standard d'un exercice dans une liste.
class ExerciseTile extends StatelessWidget {
  const ExerciseTile(
    this.exercise, {
    super.key,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.subtitle,
    this.selected = false,
    this.favori = false,
    this.dense = false,
  });

  final Exercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  /// Par défaut : muscle principal et matériel.
  final String? subtitle;
  final bool selected;
  final bool favori;
  final bool dense;

  static String sousTitre(Exercise e) {
    final muscle = e.musclesPrincipaux.isEmpty ? e.categorieLabel : e.musclesPrincipaux.first.label;
    return '$muscle · ${e.equipementLabel}${e.perso ? ' · Perso' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTileX(
      leading: ExerciseThumbnail(
        image: mediaProvider(exercise.media.thumbnail),
        width: dense ? 40 : 48,
        height: dense ? 60 : 72,
      ),
      title: exercise.nom,
      subtitle: subtitle ?? sousTitre(exercise),
      subtitleMaxLines: 1,
      selected: selected,
      dense: dense,
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: favori || trailing != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (favori) Icon(Icons.bookmark_rounded, size: 18, color: c.text),
                if (favori && trailing != null) const SizedBox(width: 8),
                ?trailing,
              ],
            )
          : null,
    );
  }
}

/// Aperçu d'un exercice par-dessus la liste : grande carte haute arrondie
/// avec l'animation seule ; dessous, le nom et un accès à la fiche complète.
Future<void> showExerciseApercu(BuildContext context, Exercise e, {VoidCallback? onFiche}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: AppTokens.normal,
    transitionBuilder: (context, anim, _, child) {
      final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: t, child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(t), child: child));
    },
    pageBuilder: (context, _, _) {
      final c = context.colors;
      final taille = MediaQuery.sizeOf(context);
      final largeur = (taille.width - 56).clamp(240.0, 440.0);
      final src = e.media.gif ?? e.media.gifSecours ?? e.media.thumbnail;
      return SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grande carte haute, bord clair, lumière douce au centre : seule l'animation.
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: largeur,
                    height: (largeur / 0.74).clamp(0.0, taille.height * 0.68),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: AppTokens.radius26,
                      border: Border.all(color: c.text3, width: 1.5),
                      gradient: RadialGradient(radius: 0.75, colors: [c.surface3, c.surface]),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: src == null
                        ? Icon(Icons.fitness_center_rounded, size: 72, color: c.text3)
                        : mediaImage(src, error: (_) => Icon(Icons.fitness_center_rounded, size: 72, color: c.text3)),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      Text(e.nom, textAlign: TextAlign.center, style: AppType.rowTitle().copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(ExerciseTile.sousTitre(e), textAlign: TextAlign.center, style: AppType.rowSubtitle(color: c.text2)),
                      if (onFiche != null) ...[
                        const SizedBox(height: 14),
                        PillButton.secondary(
                          label: 'Fiche complète',
                          icon: Icons.menu_book_rounded,
                          onPressed: () {
                            Navigator.of(context).pop();
                            onFiche();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Animation de l'exercice en grand : animation, puis animation de secours,
/// puis poses locales (alternées s'il y en a deux), puis photos en ligne. La vidéo
/// d'un exercice perso se lit sous le cadre ou s'ouvre à l'extérieur.
class ExerciseMediaView extends StatefulWidget {
  const ExerciseMediaView(this.exercise, {super.key, this.maxSize = 320, this.showCredit = true});

  final Exercise exercise;
  final double maxSize;
  final bool showCredit;

  @override
  State<ExerciseMediaView> createState() => _ExerciseMediaViewState();
}

class _ExerciseMediaViewState extends State<ExerciseMediaView> {
  static const _locales = '#locales';
  List<String> _sources = const [];
  int _index = 0;
  int _photo = 0;
  Timer? _timer;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant ExerciseMediaView old) {
    super.didUpdateWidget(old);
    if (old.exercise.id != widget.exercise.id || !identical(old.exercise.media, widget.exercise.media)) {
      _index = 0;
      _photo = 0;
      _prepare();
    }
  }

  void _prepare() {
    final m = widget.exercise.media;
    _sources = [
      ?m.gif,
      ?m.gifSecours,
      if (m.imagesLocales.isNotEmpty) _locales,
      ...m.images,
    ];
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    final locales = widget.exercise.media.imagesLocales;
    if (_index < _sources.length && _sources[_index] == _locales && locales.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
        if (mounted) setState(() => _photo = (_photo + 1) % locales.length);
      });
    }
  }

  /// Source en échec : on passe à la suivante après l'image courante.
  void _next() {
    if (_advancing) return;
    _advancing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _advancing = false;
      if (!mounted || _index >= _sources.length) return;
      setState(() => _index++);
      _syncTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = widget.exercise.media;
    final video = m.mp4;
    final local = m.imagesLocales;

    Widget frame;
    if (_index >= _sources.length) {
      frame = _Unavailable(
        hasSources: _sources.isNotEmpty,
        onRetry: _sources.isEmpty
            ? null
            : () {
                setState(() => _index = 0);
                _syncTimer();
              },
      );
    } else {
      final src = _sources[_index];
      final placeholder = local.isNotEmpty
          ? mediaImage(local.first)
          : Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.training)));
      if (src == _locales) {
        frame = mediaImage(local[_photo % local.length], error: (_) {
          _next();
          return const SizedBox.shrink();
        });
      } else {
        frame = mediaImage(
          src,
          loading: (_) => placeholder,
          error: (_) {
            _next();
            return placeholder;
          },
        );
      }
      frame = Container(color: c.surface2, padding: const EdgeInsets.all(8), child: frame);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxSize),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(borderRadius: AppTokens.radius18, child: frame),
            ),
          ),
        ),
        if (video != null && video.isNotEmpty) ...[
          const SizedBox(height: 12),
          ExerciseVideo(url: video, maxSize: widget.maxSize),
        ],
        if (widget.showCredit && m.credit != null) ...[
          const SizedBox(height: 8),
          Text(m.credit!, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.text3)),
        ],
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.hasSources, this.onRetry});

  final bool hasSources;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.surface2,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconHalo(icon: hasSources ? Icons.wifi_off_rounded : Icons.image_not_supported_rounded, color: c.training, size: 52),
          const SizedBox(height: 14),
          Text(hasSources ? 'Animation indisponible' : 'Pas d\'image pour cet exercice',
              textAlign: TextAlign.center, style: AppType.rowTitle()),
          const SizedBox(height: 4),
          Text(hasSources ? 'Vérifie ta connexion, puis réessaie.' : 'Ajoute une photo ou une vidéo en modifiant l\'exercice.',
              textAlign: TextAlign.center, style: AppType.rowSubtitle()),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            PillButton.secondary(label: 'Réessayer', icon: Icons.refresh_rounded, size: PillSize.small, onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

/// Vrai pour un fichier vidéo (local ou adresse directe), faux pour une page web.
bool isDirectVideo(String url) {
  final u = url.toLowerCase().split('?').first;
  return !u.startsWith('http') || u.endsWith('.mp4') || u.endsWith('.webm') || u.endsWith('.mov') || u.endsWith('.m4v');
}

/// Vidéo d'un exercice perso : lecture en boucle, sans son, pour un fichier
/// vidéo ; bouton d'ouverture pour un lien vers une page de vidéo.
class ExerciseVideo extends StatefulWidget {
  const ExerciseVideo({super.key, required this.url, this.maxSize = 320});

  final String url;
  final double maxSize;

  @override
  State<ExerciseVideo> createState() => _ExerciseVideoState();
}

class _ExerciseVideoState extends State<ExerciseVideo> {
  VideoPlayerController? _ctrl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (isDirectVideo(widget.url)) _init();
  }

  Future<void> _init() async {
    final ctrl = widget.url.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(widget.url))
        : VideoPlayerController.file(File(widget.url));
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0);
      await ctrl.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.url);
    var ok = false;
    try {
      ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) Toasts.error(context, 'Impossible d\'ouvrir ce lien');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = _ctrl;
    if (ctrl == null || _failed) {
      if (!widget.url.startsWith('http')) {
        return Text('Vidéo introuvable sur le téléphone', style: AppType.rowSubtitle());
      }
      return PillButton.secondary(label: 'Regarder la vidéo', icon: Icons.play_circle_rounded, chevron: true, onPressed: _open);
    }
    if (!ctrl.value.isInitialized) {
      return SizedBox(
        height: 60,
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: c.training))),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxSize),
      child: ClipRRect(
        borderRadius: AppTokens.radius18,
        child: GestureDetector(
          onTap: () => setState(() => ctrl.value.isPlaying ? ctrl.pause() : ctrl.play()),
          child: AspectRatio(aspectRatio: ctrl.value.aspectRatio, child: VideoPlayer(ctrl)),
        ),
      ),
    );
  }
}
