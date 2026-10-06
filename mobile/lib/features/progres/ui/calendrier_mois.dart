import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/tableau.dart';
import 'communs.dart';

/// Le mois en grand dans une carte : flèches et glissement pour revenir
/// aux mois précédents, trois points en bas.
class CalendrierMois extends StatefulWidget {
  const CalendrierMois({
    super.key,
    required this.sessions,
    this.maintenant,
    this.onJour,
    this.onMois,
    this.moisMax = 24,
    this.premierJour = DateTime.monday,
  });

  /// Premier jour de la semaine (réglage de l'appli).
  final int premierJour;

  final List<WorkoutSession> sessions;
  final DateTime? maintenant;
  final ValueChanged<DateTime>? onJour;

  /// Prévenu quand le mois affiché change.
  final ValueChanged<DateTime>? onMois;

  /// Nombre de mois accessibles au plus.
  final int moisMax;

  @override
  State<CalendrierMois> createState() => _CalendrierMoisState();
}

class _CalendrierMoisState extends State<CalendrierMois> {
  late PageController _pages;
  late int _nb;
  late int _page;

  DateTime get _now => widget.maintenant ?? DateTime.now();

  /// Mois accessibles : depuis la première séance, trois au moins.
  int _compter() {
    final now = _now;
    var premier = DateTime(now.year, now.month - 2);
    for (final s in widget.sessions) {
      if (s.debut.isBefore(premier)) premier = DateTime(s.debut.year, s.debut.month);
    }
    final n = (now.year - premier.year) * 12 + now.month - premier.month + 1;
    return n.clamp(3, widget.moisMax);
  }

  @override
  void initState() {
    super.initState();
    _nb = _compter();
    _page = _nb - 1;
    _pages = PageController(initialPage: _page);
  }

  @override
  void didUpdateWidget(CalendrierMois old) {
    super.didUpdateWidget(old);
    final n = _compter();
    if (n != _nb) {
      // Le dernier mois reste le mois en cours : on garde l'écart à la fin.
      final depuisFin = _nb - 1 - _page;
      _nb = n;
      _page = (_nb - 1 - depuisFin).clamp(0, _nb - 1);
      _pages.dispose();
      _pages = PageController(initialPage: _page);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  DateTime _mois(int page) => DateTime(_now.year, _now.month - (_nb - 1 - page));

  int _lignes(DateTime mois) {
    final debut = Dates.debutSemaine(DateTime(mois.year, mois.month), premierJour: widget.premierJour);
    final dernier = DateTime(mois.year, mois.month + 1, 0);
    return (((dernier.difference(debut).inHours / 24).round() + 1) / 7).ceil();
  }

  void _aller(int page) {
    if (page < 0 || page >= _nb) return;
    _pages.animateToPage(page, duration: AppTokens.normal, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final types = Calculs.typesParJour(widget.sessions);
    final mois = _mois(_page);
    final nbSeances = Calculs.entre(widget.sessions, mois, DateTime(mois.year, mois.month + 1)).length;
    final enCours = _page == _nb - 1;
    final detail = [
      nbSeances == 0 ? 'aucune séance' : Fmt.pluriel(nbSeances, 'séance'),
      if (enCours) 'mois en cours',
    ].join(' · ');

    return Carte(
      padding: const EdgeInsets.fromLTRB(12.5, 15, 12.5, 17.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Fleche(gauche: true, actif: _page > 0, onTap: () => _aller(_page - 1)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Calculs.moisAnnee(mois), maxLines: 1, style: ts(19, FontWeight.w700, c.text, hauteur: 1.35)),
                    Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, FontWeight.w400, c.text2, hauteur: 1.35)),
                  ],
                ),
              ),
              _Fleche(gauche: false, actif: !enCours, onTap: () => _aller(_page + 1)),
            ],
          ),
          const SizedBox(height: 12.5),
          LayoutBuilder(builder: (context, box) {
            // Mêmes cotes que GrilleMois : pastille, 5 entre les lignes, en-têtes.
            final d = (box.maxWidth / 7 - 4).clamp(24.0, 40.0);
            double hauteur(DateTime m) => 28 + _lignes(m) * d + (_lignes(m) - 1) * 5;
            return AnimatedContainer(
              duration: AppTokens.normal,
              curve: Curves.easeOut,
              height: hauteur(mois),
              child: PageView.builder(
                // Une clé par nombre de mois : quand l'historique s'allonge
                // (import, séance ancienne), la vue repart du bon mois au lieu
                // de garder son ancien défilement sous un nouveau titre.
                key: ValueKey(_nb),
                controller: _pages,
                itemCount: _nb,
                onPageChanged: (p) {
                  setState(() => _page = p);
                  widget.onMois?.call(_mois(p));
                },
                itemBuilder: (context, p) => SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: GrilleMois(
                    mois: _mois(p),
                    aujourdhui: _now,
                    premierJour: widget.premierJour,
                    seance: (j) => types[Dates.jour(j)],
                    onJour: widget.onJour,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12.5),
          _Points(actif: (2 - (_nb - 1 - _page)).clamp(0, 2)),
        ],
      ),
    );
  }
}

class _Fleche extends StatelessWidget {
  const _Fleche({required this.gauche, required this.actif, required this.onTap});
  final bool gauche;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: actif,
      label: gauche ? 'Mois précédent' : 'Mois suivant',
      excludeSemantics: true,
      child: InkResponse(
        onTap: actif ? onTap : null,
        radius: 26,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Chevron(taille: 22.5, gauche: gauche, couleur: actif ? c.text : c.text.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }
}

/// Trois points : le mois en cours à droite, les plus anciens à gauche.
class _Points extends StatelessWidget {
  const _Points({required this.actif});
  final int actif;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: AppTokens.fast,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i == actif ? 17.5 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == actif ? c.text : c.surface2, borderRadius: BorderRadius.circular(3)),
          ),
      ],
    );
  }
}
