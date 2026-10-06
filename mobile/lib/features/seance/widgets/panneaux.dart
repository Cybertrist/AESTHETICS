import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import 'habillage.dart';

/// Réponse du panneau « Type de série » : un type, ou la suppression.
class ChoixTypeSerie {
  const ChoixTypeSerie.type(SetType this.type) : supprimer = false;
  const ChoixTypeSerie.supprimer()
      : type = null,
        supprimer = true;

  final SetType? type;
  final bool supprimer;
}

/// Panneau « Type de série » : douze types sur deux colonnes, chacun avec sa
/// lettre, sa couleur et un « ? » qui l'explique, puis « Supprimer la série ».
Future<ChoixTypeSerie?> choisirTypeSerie(BuildContext context, {required SetType actuel, bool supprimable = true}) =>
    showPanneauBas<ChoixTypeSerie>(
      context,
      titre: 'Type de série',
      builder: (context) => PanneauTypeSerie(actuel: actuel, supprimable: supprimable),
    );

class PanneauTypeSerie extends StatefulWidget {
  const PanneauTypeSerie({super.key, required this.actuel, this.supprimable = true});

  final SetType actuel;
  final bool supprimable;

  @override
  State<PanneauTypeSerie> createState() => _PanneauTypeSerieState();
}

class _PanneauTypeSerieState extends State<PanneauTypeSerie> {
  SetType? _aide;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final types = SetType.ordrePanneau;
    final ecart = k(7);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < types.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: ecart),
            child: Row(
              children: [
                Expanded(child: _case(types[i])),
                SizedBox(width: ecart),
                Expanded(child: _case(types[i + 1])),
              ],
            ),
          ),
        AnimatedSize(
          duration: AppTokens.fast,
          alignment: Alignment.topCenter,
          child: _aide == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: EdgeInsets.fromLTRB(k(2), k(2), k(2), k(8)),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${_aide!.label} : ', style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
                      TextSpan(text: _aide!.aide),
                    ]),
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), height: 1.4, color: c.text2),
                  ),
                ),
        ),
        if (widget.supprimable) ...[
          SizedBox(height: k(3)),
          _Cadre(
            onTap: () => Navigator.pop(context, const ChoixTypeSerie.supprimer()),
            child: Row(
              children: [
                SizedBox(width: k(3)),
                Trait(IconeSeance.corbeille, size: k(18), color: c.error),
                SizedBox(width: k(8)),
                Text(
                  'Supprimer la série',
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), fontWeight: FontWeight.w600, color: c.error),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _case(SetType t) {
    final c = context.colors;
    return _Cadre(
      retenu: t == widget.actuel,
      onTap: () => Navigator.pop(context, ChoixTypeSerie.type(t)),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: k(20)),
            child: Text(
              t.lettre,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(15), height: 1.2, fontWeight: FontWeight.w800, color: t.couleur),
            ),
          ),
          SizedBox(width: k(6)),
          Expanded(
            // « Échauffement » tient tout juste : on le réduit d'un rien plutôt que de le couper.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(t.label, maxLines: 1, softWrap: false, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), fontWeight: FontWeight.w600, color: c.text)),
            ),
          ),
          if (t != SetType.normale)
            Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              label: 'Expliquer ${t.label}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _aide = _aide == t ? null : t),
                child: SizedBox(
                  width: k(20),
                  height: k(41),
                  child: Center(
                    child: Text(
                      '?',
                      style: TextStyle(
                        fontFamily: AppTokens.fontUi,
                        fontSize: k(12),
                        fontWeight: FontWeight.w600,
                        color: _aide == t ? c.text : c.text3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Case encadrée d'un panneau (`.ty`) : cadre fin, blanc quand elle est retenue.
class _Cadre extends StatelessWidget {
  const _Cadre({required this.child, required this.onTap, this.retenu = false});

  final Widget child;
  final VoidCallback onTap;
  final bool retenu;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rayon = BorderRadius.circular(k(14));
    return Semantics(
      button: true,
      selected: retenu,
      child: InkWell(
        borderRadius: rayon,
        onTap: onTap,
        child: Container(
          height: k(44),
          padding: EdgeInsets.only(left: k(9), right: k(4)),
          decoration: BoxDecoration(borderRadius: rayon, border: Border.all(color: retenu ? c.text : c.frame, width: 1.5)),
          child: child,
        ),
      ),
    );
  }
}

/// Panneau « Type d'activité », musculation cochée par défaut.
Future<TypeSeance?> choisirTypeSeance(BuildContext context, TypeSeance actuel) => showPanneauBas<TypeSeance>(
      context,
      titre: 'Type d\'activité',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in TypeSeance.values)
            ChoixPanneau(
              icone: IconeTypeSeance(t),
              label: t.label,
              selected: t == actuel,
              onTap: () => Navigator.pop(context, t),
            ),
        ],
      ),
    );

/// Panneau « Durée » : trois roues, heures, minutes, secondes.
Future<Duration?> choisirDuree(BuildContext context, Duration actuelle) => showPanneauBas<Duration>(
      context,
      titre: 'Durée',
      builder: (context) => _PanneauDuree(depart: actuelle),
    );

class _PanneauDuree extends StatefulWidget {
  const _PanneauDuree({required this.depart});
  final Duration depart;

  @override
  State<_PanneauDuree> createState() => _PanneauDureeState();
}

class _PanneauDureeState extends State<_PanneauDuree> {
  late Duration _d = widget.depart;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoueDuree(value: _d, onChanged: (d) => setState(() => _d = d)),
          SizedBox(height: k(10)),
          BoutonPrincipal(label: 'Terminé', onPressed: () => Navigator.pop(context, _d)),
        ],
      );
}

/// Durées de repos toutes prêtes (secondes).
const reposTousPrets = [60, 90, 120, 150];

/// Pastille ronde d'une durée toute prête (`.rd.p`).
class PastilleDuree extends StatelessWidget {
  const PastilleDuree({super.key, required this.secondes, required this.retenue, required this.onTap});

  final int secondes;
  final bool retenue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = k(60);
    return Semantics(
      button: true,
      selected: retenue,
      child: Material(
        color: c.surface2,
        shape: CircleBorder(side: retenue ? BorderSide(color: c.text, width: 1.5) : BorderSide.none),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: t,
            child: Center(
              child: Text(
                minSec(Duration(seconds: secondes)),
                style: TextStyle(
                  fontFamily: AppTokens.fontUi,
                  fontSize: k(13),
                  fontWeight: FontWeight.w600,
                  color: retenue ? c.text : c.text2,
                  fontFeatures: AppTokens.tabular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panneau du repos d'un exercice (ligne bleue « Minuteur de repos ») : deux
/// roues, des durées toutes prêtes, « Sans minuteur ». Rend des secondes.
Future<int?> choisirRepos(BuildContext context, int actuel) => showPanneauBas<int>(
      context,
      titre: 'Minuteur de repos',
      builder: (context) => _PanneauRepos(depart: actuel),
    );

class _PanneauRepos extends StatefulWidget {
  const _PanneauRepos({required this.depart});
  final int depart;

  @override
  State<_PanneauRepos> createState() => _PanneauReposState();
}

class _PanneauReposState extends State<_PanneauRepos> {
  late int _sec = widget.depart;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoueMinSec(
            value: Duration(seconds: _sec),
            maxMinutes: 15,
            pasSecondes: 5,
            onChanged: (d) => setState(() => _sec = d.inSeconds),
          ),
          SizedBox(height: k(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final s in reposTousPrets) ...[
                if (s != reposTousPrets.first) SizedBox(width: k(10)),
                PastilleDuree(secondes: s, retenue: s == _sec, onTap: () => setState(() => _sec = s)),
              ],
            ],
          ),
          SizedBox(height: k(14)),
          BoutonPrincipal(label: 'Terminé', onPressed: () => Navigator.pop(context, _sec)),
          SizedBox(height: k(8)),
          BoutonSecondaire(label: 'Sans minuteur', fond: AppTokens.surface3, onPressed: () => Navigator.pop(context, 0)),
        ],
      );
}

/// Une action d'un menu en panneau du bas.
class ActionPanneau<T> {
  const ActionPanneau(this.valeur, this.label, this.icone, {this.destructif = false, this.filetAvant = false});

  final T valeur;
  final String label;
  final Widget icone;
  final bool destructif;

  /// Filet de séparation au-dessus de la ligne.
  final bool filetAvant;
}

/// Menu en panneau du bas (`.sheet` et `.act`) : une ligne par action.
Future<T?> menuPanneau<T>(BuildContext context, {String? titre, required List<ActionPanneau<T>> actions}) => showPanneauBas<T>(
      context,
      titre: titre,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in actions) ...[
            if (a.filetAvant) const Divider(height: 1, thickness: 1, color: PanneauBas.filet),
            LigneAction(icone: a.icone, label: a.label, destructif: a.destructif, onTap: () => Navigator.pop(context, a.valeur)),
          ],
        ],
      ),
    );

/// Interrupteur de la maquette (`.tg`) : blanc à bouton noir quand il est actif.
class Interrupteur extends StatelessWidget {
  const Interrupteur({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pastille = k(22);
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: AppTokens.fast,
          width: k(46),
          height: k(28),
          padding: EdgeInsets.all(k(3)),
          decoration: BoxDecoration(color: value ? c.bouton : c.surface3, borderRadius: AppTokens.radiusPill),
          child: AnimatedAlign(
            duration: AppTokens.fast,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: pastille,
              height: pastille,
              decoration: BoxDecoration(color: value ? c.onBouton : c.text2, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
