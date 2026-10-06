import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/chrono.dart';
import '../logic/repos_minuteur.dart';
import '../widgets/habillage.dart';
import '../widgets/panneaux.dart';

/// Minuteur de repos en plein écran (maquettes « Repos : compte à rebours »
/// et « Repos : régler la durée ») : l'anneau bleu qui se vide, −10 / +10,
/// « Arrêter » ; sans repos en cours, deux roues et des durées toutes prêtes ;
/// en bas, on bascule vers le chronomètre.
class ReposPage extends StatefulWidget {
  const ReposPage({super.key});

  @override
  State<ReposPage> createState() => _ReposPageState();
}

class _ReposPageState extends State<ReposPage> {
  bool _chrono = false;
  late Duration _duree;

  @override
  void initState() {
    super.initState();
    _duree = Duration(seconds: _dureeDepart());
    ChronoLibre.instance.pourSeance(context.read<SessionRepo>().active?.id);
  }

  /// Le repos de l'exercice en cours, sinon celui des réglages.
  int _dureeDepart() {
    final s = context.read<SessionRepo>().active;
    if (s != null) {
      for (final e in s.exercices) {
        if (e.series.any((x) => !x.fait) && e.reposSec > 0) return e.reposSec;
      }
    }
    final defaut = context.read<SettingsRepo>().settings.reposParDefautSec;
    return defaut > 0 ? defaut : 120;
  }

  void _fermer() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/seance');
    }
  }

  void _demarrer() {
    final r = context.read<SettingsRepo>().settings;
    if (_duree.inSeconds <= 0) return;
    ReposMinuteur.instance.demarrer(_duree.inSeconds, son: r.sonMinuteur, vibration: r.vibrationMinuteur, volume: r.volumeMinuteur, force: r.forceVibration, voix: r.decompteVocal);
  }

  Future<void> _menu() async {
    final repo = context.read<SettingsRepo>();
    final r = repo.settings;
    final v = await menuPanneau<String>(
      context,
      titre: 'Minuteur de repos',
      actions: [
        ActionPanneau('son', r.sonMinuteur ? 'Couper le son de fin' : 'Activer le son de fin', Icon(r.sonMinuteur ? Icons.volume_up_outlined : Icons.volume_off_outlined)),
        ActionPanneau('vibration', r.vibrationMinuteur ? 'Couper la vibration' : 'Activer la vibration', const Icon(Icons.vibration_rounded)),
      ],
    );
    if (v == 'son') await repo.update((s) => s.copyWith(sonMinuteur: !s.sonMinuteur));
    if (v == 'vibration') await repo.update((s) => s.copyWith(vibrationMinuteur: !s.vibrationMinuteur));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: margeSeance - k(10), vertical: k(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BoutonRond(label: 'Fermer', nu: true, onTap: _fermer, child: Trait(IconeSeance.croix, size: k(18), epaisseur: 2)),
                      BoutonRond(label: 'Plus d\'actions', nu: true, onTap: _menu, child: TroisPoints(size: k(18))),
                    ],
                  ),
                ),
                Expanded(
                  child: _chrono
                      ? ListenableBuilder(listenable: ChronoLibre.instance, builder: (context, _) => _chronometre(context))
                      : ListenableBuilder(listenable: ReposMinuteur.instance, builder: (context, _) => _compteARebours(context)),
                ),
                _Onglets(
                  chrono: _chrono,
                  onChange: (v) => setState(() => _chrono = v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compteARebours(BuildContext context) {
    final c = context.colors;
    final m = ReposMinuteur.instance;
    if (!m.actif) {
      // Régler la durée : deux roues, des durées toutes prêtes, « Démarrer ».
      return Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: RoueMinSec(value: _duree, maxMinutes: 59, onChanged: (d) => setState(() => _duree = d)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: k(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final s in reposTousPrets) ...[
                  if (s != reposTousPrets.first) SizedBox(width: k(10)),
                  PastilleDuree(secondes: s, retenue: _duree.inSeconds == s, onTap: () => setState(() => _duree = Duration(seconds: s))),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: k(10)),
            child: BoutonSeance(
              label: 'Démarrer',
              fond: c.bouton,
              encre: c.onBouton,
              largeur: k(170),
              onTap: _duree.inSeconds > 0 ? _demarrer : null,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Semantics(
              label: 'Repos, ${minSec(m.restant)} restantes',
              child: AnneauRepos(reste: 1 - m.progression, texte: minSec(m.restant)),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: k(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Rond(label: '−10', semantique: 'Retirer 10 secondes', onTap: () => m.ajuster(-10)),
              SizedBox(width: k(40)),
              _Rond(label: '+10', semantique: 'Ajouter 10 secondes', onTap: () => m.ajuster(10)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: k(10)),
          child: BoutonSeance(label: 'Arrêter', fond: c.surface2, encre: c.error, largeur: k(170), onTap: m.passer),
        ),
      ],
    );
  }

  Widget _chronometre(BuildContext context) {
    final c = context.colors;
    final ch = ChronoLibre.instance;
    final zero = ch.ecoule == Duration.zero;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AnneauRepos(reste: ch.enMarche ? 1 : 0, texte: _chronoTexte(ch.ecoule)),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: k(10)),
          child: Opacity(
            opacity: !ch.enMarche && !zero ? 1 : 0,
            child: IgnorePointer(
              ignoring: ch.enMarche || zero,
              child: _Rond(label: '0:00', semantique: 'Remettre à zéro', onTap: ch.remettreAZero),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: k(10)),
          child: ch.enMarche
              ? BoutonSeance(label: 'Arrêter', fond: c.surface2, encre: c.error, largeur: k(170), onTap: ch.arreter)
              : BoutonSeance(label: zero ? 'Démarrer' : 'Reprendre', fond: c.bouton, encre: c.onBouton, largeur: k(170), onTap: ch.demarrer),
        ),
      ],
    );
  }

  static String _chronoTexte(Duration d) {
    final s = d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// L'anneau de 252 de la maquette : piste grise, arc bleu de ce qui reste,
/// le temps au centre.
class AnneauRepos extends StatelessWidget {
  const AnneauRepos({super.key, required this.reste, required this.texte});

  /// Part restante, de 0 à 1.
  final double reste;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final cote = math.min(k(252), math.min(box.maxWidth, box.maxHeight.isFinite ? box.maxHeight : k(252)));
        final e = cote / k(252);
        return SizedBox.square(
          dimension: cote,
          child: CustomPaint(
            painter: _AnneauPainter(reste: reste.clamp(0.0, 1.0), piste: c.surface2, arc: c.minuteur, epaisseur: k(10) * e, retrait: k(14) * e),
            child: Center(
              child: Text(
                texte,
                style: TextStyle(
                  fontFamily: AppTokens.fontUi,
                  fontSize: k(50) * e,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: c.text,
                  fontFeatures: AppTokens.tabular,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnneauPainter extends CustomPainter {
  _AnneauPainter({required this.reste, required this.piste, required this.arc, required this.epaisseur, required this.retrait});

  final double reste;
  final Color piste;
  final Color arc;
  final double epaisseur;

  /// Distance du bord au milieu du trait (rayon de 112 dans un carré de 252).
  final double retrait;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final rayon = size.width / 2 - retrait;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centre, rayon, p..color = piste);
    if (reste > 0) {
      canvas.drawArc(Rect.fromCircle(center: centre, radius: rayon), -math.pi / 2, 2 * math.pi * reste, false, p..color = arc);
    }
  }

  @override
  bool shouldRepaint(_AnneauPainter old) => old.reste != reste || old.piste != piste || old.arc != arc || old.epaisseur != epaisseur;
}

/// Bouton rond de 52 (`.rd`) : −10, +10.
class _Rond extends StatelessWidget {
  const _Rond({required this.label, required this.semantique, required this.onTap});

  final String label;
  final String semantique;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: semantique,
      excludeSemantics: true,
      child: Material(
        color: c.surface2,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: k(52),
            child: Center(
              child: Text(
                label,
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(14), fontWeight: FontWeight.w700, color: c.text, fontFeatures: AppTokens.tabular),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les deux onglets du bas : « Compte à rebours », « Chronomètre ».
class _Onglets extends StatelessWidget {
  const _Onglets({required this.chrono, required this.onChange});

  final bool chrono;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget onglet(String t, bool actif, VoidCallback onTap) => Semantics(
          button: true,
          selected: actif,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.only(top: k(10), bottom: k(11)),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: actif ? c.text : c.text.withValues(alpha: 0), width: k(2.5))),
              ),
              child: Text(
                t,
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13.5), fontWeight: FontWeight.w600, color: actif ? c.text : c.text2),
              ),
            ),
          ),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: k(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          onglet('Compte à rebours', !chrono, () => onChange(false)),
          SizedBox(width: k(28)),
          onglet('Chronomètre', chrono, () => onChange(true)),
        ],
      ),
    );
  }
}
