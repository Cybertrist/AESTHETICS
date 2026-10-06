import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/partage.dart';
import '../seance_paths.dart';
import '../widgets/cartes_partage.dart';

/// Carte « Fin de séance : l'équivalent » (écrans 14 à 23 de la maquette) :
/// le volume de la séance comparé à un objet, juste après l'enregistrement.
class EquivalentPage extends StatelessWidget {
  const EquivalentPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionRepo>().byId(sessionId);
    if (s == null) {
      return Scaffold(
        backgroundColor: context.colors.bg,
        body: SafeArea(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Séance introuvable',
            message: 'Elle a peut-être été supprimée.',
            actionLabel: 'Revenir à l\'accueil',
            onAction: () => context.go('/'),
          ),
        ),
      );
    }
    final unite = context.watch<ProfileRepo>().unite;
    return CarteFinDeSeance(
      nom: s.nom,
      volume: Fmt.n(Fmt.poidsAffiche(s.volume, unite), decimals: 0),
      unite: unite.label,
      equivalent: equivalentDeSeance(s),
      onFermer: () => context.go(SeancePaths.resume(s.id, nouveau: true)),
      onPartager: () => context.push(SeancePaths.partager(s.id, carte: 1)),
    );
  }
}

/// La carte plein écran : dégradé de la couleur de l'objet vers le noir.
class CarteFinDeSeance extends StatelessWidget {
  const CarteFinDeSeance({
    super.key,
    required this.nom,
    required this.volume,
    required this.unite,
    required this.equivalent,
    required this.onFermer,
    required this.onPartager,
  });

  final String nom;

  /// Volume déjà mis en forme, sans unité : « 6 480 ».
  final String volume;
  final String unite;
  final Equivalent equivalent;
  final VoidCallback onFermer;
  final VoidCallback onPartager;

  @override
  Widget build(BuildContext context) {
    final e = equivalent;
    const blanc = Colors.white;
    TextStyle mont(double taille, FontWeight poids, {double? height, double? ls}) => TextStyle(
          fontFamily: AppTokens.fontBilan,
          fontSize: taille * kEchelle,
          fontWeight: poids,
          color: blanc,
          height: height,
          letterSpacing: ls,
          fontFeatures: AppTokens.tabular,
        );
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.68],
            colors: [e.couleur, context.colors.bg],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18 * kEchelle, 2 * kEchelle, 18 * kEchelle, 14 * kEchelle),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: const Offset(-12 * kEchelle, 0),
                    child: BoutonRond(icone: Icons.close_rounded, label: 'Fermer', onTap: onFermer, fond: false),
                  ),
                ),
                Expanded(
                  // Sur un petit écran, l'ensemble rétrécit pour que la phrase
                  // reste entière ; la largeur ne change pas, la phrase passe
                  // donc à la ligne comme sur un grand écran.
                  child: LayoutBuilder(
                    builder: (context, boite) => Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: boite.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${nom.toUpperCase()} · séance terminée',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: mont(13, FontWeight.w700, height: 1.25),
                              ),
                              const SizedBox(height: 10 * kEchelle),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: volume, style: mont(46, FontWeight.w800, height: 0.95, ls: -0.03 * 46 * kEchelle)),
                                    TextSpan(text: '${String.fromCharCode(0x2009)}$unite', style: mont(18, FontWeight.w800, height: 0.95)),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 10 * kEchelle),
                              Objet3D(asset: e.asset, etiquette: e.etiquette, halo: e.accent, hauteur: 236 * kEchelle),
                              const SizedBox(height: 10 * kEchelle),
                              PhraseEquivalent(equivalent: e),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Center(child: MarquePartage(taille: 17)),
                const SizedBox(height: 2 * kEchelle),
                Center(
                  child: Semantics(
                    button: true,
                    child: InkWell(
                      borderRadius: AppTokens.radiusPill,
                      onTap: onPartager,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 44 * kEchelle,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const IconePartager(size: 18 * kEchelle, color: blanc),
                              const SizedBox(width: 7 * kEchelle),
                              Text('Partager', style: mont(15, FontWeight.w600)),
                            ],
                          ),
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
