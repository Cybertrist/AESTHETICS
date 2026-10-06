import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/chrono.dart';
import '../logic/repos_minuteur.dart';
import '../seance_paths.dart';
import 'habillage.dart';

/// Abandonne la séance en cours après confirmation. Rend vrai si c'est fait.
Future<bool> abandonnerSeance(BuildContext context, {bool confirmer = true}) async {
  final repo = context.read<SessionRepo>();
  if (confirmer) {
    final ok = await showConfirmDialog(
      context,
      title: 'Abandonner la séance ?',
      message: 'Rien ne sera gardé dans l\'historique.',
      confirmLabel: 'Abandonner',
      destructive: true,
    );
    if (!ok) return false;
  }
  ReposMinuteur.instance.passer();
  PauseSeance.instance.oublier();
  await repo.discardActive();
  return true;
}

/// Barre « Entraînement en cours » (maquette « Séance réduite ») : posée
/// au-dessus de la barre des onglets tant qu'une séance tourne. En haut le
/// titre et le chrono, en bas « Reprendre » (blanc) et « Abandonner » (gris,
/// texte rouge). Invisible sans séance en cours.
class SeanceMiniBarre extends StatefulWidget {
  const SeanceMiniBarre({super.key, this.padding = const EdgeInsets.fromLTRB(12, 0, 12, 8)});

  final EdgeInsetsGeometry padding;

  @override
  State<SeanceMiniBarre> createState() => _SeanceMiniBarreState();
}

class _SeanceMiniBarreState extends State<SeanceMiniBarre> {
  /// Séance pour laquelle la pause laissée sur disque a déjà été relue.
  String? _pauseLuePour;

  @override
  Widget build(BuildContext context) {
    final active = context.watch<SessionRepo>().active;
    // Appli fermée en pleine pause : on la retrouve en revenant.
    if (active != null && _pauseLuePour != active.id) {
      _pauseLuePour = active.id;
      unawaited(PauseSeance.instance.charger(context.read<SessionRepo>()));
    }
    final c = context.colors;
    final titre = TextStyle(
      fontFamily: AppTokens.fontUi,
      fontSize: k(13),
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: c.text,
      fontFeatures: AppTokens.tabular,
    );
    return AnimatedSize(
      duration: AppTokens.normal,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: active == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: widget.padding,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    padding: EdgeInsets.all(k(10)),
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(k(14)),
                      border: Border.all(color: c.surface3),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: k(4)),
                          child: ListenableBuilder(
                            listenable: PauseSeance.instance,
                            builder: (context, _) => Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    PauseSeance.instance.enPause(active) ? 'Entraînement en pause' : 'Entraînement en cours',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: titre,
                                  ),
                                ),
                                TexteVivant(() => chronoSeance(PauseSeance.instance.ecoule(active)), style: titre),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: k(8)),
                        Row(
                          children: [
                            Expanded(
                              child: BoutonSeance(
                                label: 'Reprendre',
                                fond: c.bouton,
                                encre: c.onBouton,
                                hauteur: k(36),
                                taille: k(12.5),
                                rayon: k(10),
                                onTap: () => context.push(SeancePaths.enCours),
                              ),
                            ),
                            SizedBox(width: k(8)),
                            Expanded(
                              child: BoutonSeance(
                                label: 'Abandonner',
                                fond: c.surface3,
                                encre: c.error,
                                hauteur: k(36),
                                taille: k(12.5),
                                rayon: k(10),
                                onTap: () => abandonnerSeance(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
