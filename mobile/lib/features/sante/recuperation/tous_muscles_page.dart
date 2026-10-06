import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../progres/progres_paths.dart';
import '../../progres/ui/communs.dart';
import 'recup_calcul.dart';
import 'recuperation_page.dart';

enum _Filtre { tous, recup, prets }

/// Tous les muscles, du moins au plus récupéré, avec un filtre.
class TousLesMusclesPage extends StatefulWidget {
  const TousLesMusclesPage({super.key, this.maintenant});
  final DateTime? maintenant;

  @override
  State<TousLesMusclesPage> createState() => _TousLesMusclesPageState();
}

class _TousLesMusclesPageState extends State<TousLesMusclesPage> {
  _Filtre _filtre = _Filtre.tous;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions;
    final exos = context.watch<ExerciseRepo>();
    final tries = Recup.tries(Recup.etats(sessions, exos.byId, now: widget.maintenant));
    final nbPrets = tries.where((e) => e.pret).length;
    final nbRecup = tries.length - nbPrets;
    final liste = [
      for (final e in tries)
        if (_filtre == _Filtre.tous || (_filtre == _Filtre.prets) == e.pret) (Recup.label(e.muscle), e),
    ];

    return PageProgres(
      child: ListView(
        padding: EdgeInsets.only(bottom: basDePage(context)),
        children: [
          const EnTetePage(titre: 'Tous les muscles', sousTitre: 'Du moins au plus récupéré', retourNu: true, tailleTitre: 21),
          Padding(
            padding: const EdgeInsets.fromLTRB(Cotes.marge, 12.5, Cotes.marge, 12.5),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Puce(
                  label: 'Tous',
                  choisi: _filtre == _Filtre.tous,
                  fond: c.surface2,
                  encre: c.text2,
                  onTap: () => setState(() => _filtre = _Filtre.tous),
                ),
                _Puce(
                  label: 'En récupération · $nbRecup',
                  choisi: _filtre == _Filtre.recup,
                  fond: c.warning.withValues(alpha: 0.14),
                  encre: c.warning,
                  onTap: () => setState(() => _filtre = _filtre == _Filtre.recup ? _Filtre.tous : _Filtre.recup),
                ),
                _Puce(
                  label: 'Prêts · $nbPrets',
                  choisi: _filtre == _Filtre.prets,
                  fond: c.success.withValues(alpha: 0.14),
                  encre: c.success,
                  onTap: () => setState(() => _filtre = _filtre == _Filtre.prets ? _Filtre.tous : _Filtre.prets),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.5),
          if (liste.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Cotes.marge, vertical: 30),
              child: Text(
                _filtre == _Filtre.recup ? 'Aucun muscle en récupération : tout est prêt.' : 'Aucun muscle prêt pour l\'instant.',
                textAlign: TextAlign.center,
                style: ts(15, FontWeight.w400, c.text2, hauteur: 1.35),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
              child: GrilleMuscles(vignettes: liste, onMuscle: (m) => context.go(ProgresPaths.explorateur(m.name))),
            ),
        ],
      ),
    );
  }
}

/// Puce de filtre : blanche quand elle est choisie, à sa couleur sinon.
class _Puce extends StatelessWidget {
  const _Puce({required this.label, required this.choisi, required this.fond, required this.encre, required this.onTap});
  final String label;
  final bool choisi;
  final Color fond;
  final Color encre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: choisi,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Zone de toucher confortable autour d'une puce basse.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedContainer(
            duration: AppTokens.fast,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(color: choisi ? c.bouton : fond, borderRadius: AppTokens.radiusPill),
            child: Text(label, maxLines: 1, softWrap: false, style: ts(12.5, FontWeight.w600, choisi ? c.onBouton : encre, hauteur: 1.35)),
          ),
        ),
      ),
    );
  }
}
