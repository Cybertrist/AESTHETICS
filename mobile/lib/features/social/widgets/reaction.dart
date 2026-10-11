import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme.dart';
import '../data/social_repo.dart';
import 'elements.dart';

extension ReactionImage on Reaction {
  /// Émojis Fluent 3D de Microsoft (licence MIT), dans `assets/reactions/`.
  String get asset => 'assets/reactions/$name.png';

  String get nom => switch (this) {
        Reaction.coeur => 'J\'aime',
        Reaction.feu => 'En feu',
        Reaction.biceps => 'Costaud',
        Reaction.bravo => 'Bravo',
        Reaction.etoiles => 'Impressionnant',
      };

  /// La couleur des éclats quand on la donne.
  Color get eclat => switch (this) {
        Reaction.coeur => const Color(0xFFFF4D6A),
        Reaction.feu => const Color(0xFFFF9F1C),
        Reaction.biceps => const Color(0xFFFFC83D),
        Reaction.bravo => const Color(0xFFFFC83D),
        Reaction.etoiles => const Color(0xFFFFD84D),
      };
}

/// Le bouton de réaction d'une séance : un appui donne un cœur (ou le
/// reprend), un appui long ouvre le choix des cinq réactions. L'émoji
/// rebondit et jette des éclats quand on la donne.
class BoutonReaction extends StatefulWidget {
  const BoutonReaction(this.p, {super.key, this.actif = true});
  final Publication p;

  /// Faux dans l'aperçu de mon profil : le bouton ne fait rien.
  final bool actif;

  @override
  State<BoutonReaction> createState() => BoutonReactionState();
}

class BoutonReactionState extends State<BoutonReaction> with SingleTickerProviderStateMixin {
  late final _saut = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
  final _ancre = LayerLink();
  OverlayEntry? _choix;

  static final _echelle = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.45).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 34),
    TweenSequenceItem(tween: Tween(begin: 1.45, end: 0.9).chain(CurveTween(curve: Curves.easeInOut)), weight: 26),
    TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
  ]);

  @override
  void dispose() {
    _fermer();
    _saut.dispose();
    super.dispose();
  }

  /// Ma réaction au dernier dessin : quand elle change, l'émoji saute.
  Reaction? _vue;
  bool _premier = true;

  /// Donne [r], ou la reprend si c'est déjà la mienne.
  void donner(Reaction r) {
    final repo = context.read<SocialRepo>();
    repo.reagir(widget.p.id, repo.reaction(widget.p.id) == r ? null : r);
  }

  void _fermer() {
    _choix?.remove();
    _choix = null;
  }

  void _ouvrir() {
    if (_choix != null) return;
    HapticFeedback.selectionClick();
    final c = context.colors;
    final mienne = context.read<SocialRepo>().reaction(widget.p.id);
    _choix = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Un appui ailleurs referme le choix.
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _fermer)),
          CompositedTransformFollower(
            link: _ancre,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(-6, -10),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                builder: (context, t, _) => Material(
                  color: c.surface3,
                  elevation: 6,
                  shadowColor: Colors.black,
                  shape: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, r) in Reaction.values.indexed)
                          // Chaque émoji monte à son tour, de gauche à droite.
                          Builder(builder: (context) {
                            final u = Curves.easeOutBack.transform(((t - i * 0.11) / 0.56).clamp(0.0, 1.0));
                            return Semantics(
                              button: true,
                              label: r.nom,
                              selected: r == mienne,
                              excludeSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _fermer();
                                  donner(r);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: r == mienne ? Colors.white.withValues(alpha: 0.14) : Colors.transparent),
                                  child: Transform.translate(
                                    offset: Offset(0, 14 * (1 - u)),
                                    child: Transform.scale(scale: u.clamp(0.0, 1.3), child: Image.asset(r.asset, width: 38, height: 38)),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_choix!);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    final mienne = repo.reaction(widget.p.id);
    final n = repo.bravos(widget.p);
    final plein = mienne != null;
    if (mienne != _vue && mienne != null && !_premier) {
      HapticFeedback.lightImpact();
      _saut.forward(from: 0);
    }
    _vue = mienne;
    _premier = false;
    return CompositedTransformTarget(
      link: _ancre,
      child: Semantics(
        button: true,
        label: plein ? '${mienne.nom}, ta réaction. $n au total' : (n == 0 ? 'Réagir' : 'Réagir, $n réactions'),
        excludeSemantics: true,
        child: Material(
          color: plein ? Color.lerp(c.surface2, mienne.eclat, 0.16) : c.surface2,
          shape: const StadiumBorder(),
          clipBehavior: Clip.none,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: widget.actif ? () => donner(mienne ?? Reaction.coeur) : () {},
            onLongPress: widget.actif ? _ouvrir : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 15, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: AnimatedBuilder(
                      animation: _saut,
                      builder: (context, _) => CustomPaint(
                        painter: _saut.isAnimating && plein ? _Eclats(_saut.value, mienne.eclat) : null,
                        child: Transform.scale(
                          scale: _saut.isAnimating ? _echelle.evaluate(_saut) : 1,
                          child: plein ? Image.asset(mienne.asset, width: 24, height: 24) : Icon(Icons.favorite_border_rounded, size: 22, color: c.text),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(n == 0 ? 'Réagir' : '$n', style: ts(14.5, FontWeight.w700, c.text, hauteur: 1.2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les éclats qui partent de l'émoji : huit traits qui s'écartent et s'effacent.
class _Eclats extends CustomPainter {
  const _Eclats(this.t, this.couleur);
  final double t;
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final u = Curves.easeOutCubic.transform((t / 0.7).clamp(0.0, 1.0));
    final opacite = (1 - (t - 0.35) / 0.5).clamp(0.0, 1.0);
    if (opacite == 0) return;
    final centre = size.center(Offset.zero);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      final de = 13 + 9 * u, a2 = de + 5 * (1 - u) + 1.5;
      final trait = Paint()
        ..color = (i.isEven ? couleur : Colors.white).withValues(alpha: opacite)
        ..strokeWidth = 2.4 * (1 - u * 0.5)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(centre + Offset(math.cos(a), math.sin(a)) * de, centre + Offset(math.cos(a), math.sin(a)) * a2, trait);
    }
  }

  @override
  bool shouldRepaint(_Eclats ancien) => ancien.t != t || ancien.couleur != couleur;
}
