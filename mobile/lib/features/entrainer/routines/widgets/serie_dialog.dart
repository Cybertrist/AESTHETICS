import 'package:flutter/material.dart';

import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import 'formulaire.dart';

/// Couleur d'un type de série (pastille à la place du numéro).
Color couleurType(BuildContext context, SetType t) => switch (t) {
  SetType.echauffement => context.colors.warning,
  SetType.degressive => AppTokens.domainSleep,
  SetType.echec => context.colors.error,
  SetType.normale => context.colors.text,
  // Les types ajoutés le 2 octobre portent leur propre couleur.
  _ => t.couleur,
};

/// Pastille de série : numéro, ou lettre du type.
class SerieBadge extends StatelessWidget {
  const SerieBadge({super.key, required this.type, required this.numero, this.onTap, this.size = 32});

  final SetType type;
  final int numero;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final col = couleurType(context, type);
    final label = type == SetType.normale ? '$numero' : type.short;
    return Tooltip(
      message: type.label,
      child: Material(
        color: type == SetType.normale ? AppTokens.veil2 : col.withValues(alpha: 0.14),
        borderRadius: AppTokens.radius8,
        child: InkWell(
          borderRadius: AppTokens.radius8,
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Text(
                label,
                style: AppType.number(13).copyWith(color: col, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Résultat de la boîte d'édition d'une série.
class SerieEditee {
  const SerieEditee(this.serie, {this.toutes = false, this.supprimer = false});
  final PlannedSet serie;

  /// Appliquer à toutes les séries de travail de l'exercice.
  final bool toutes;
  final bool supprimer;
}

/// Panneau du bas pour régler une série prévue : une carte par réglage
/// (répétitions, charge, type, effort), chacune avec son « ? ».
Future<SerieEditee?> showSerieDialog(
  BuildContext context, {
  required PlannedSet serie,
  required ExerciseTracking suivi,
  required UnitePoids unite,
  required int numero,
  double pas = 2.5,
  bool peutSupprimer = true,
}) {
  return showModalBottomSheet<SerieEditee>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => _SerieDialog(serie: serie, suivi: suivi, unite: unite, numero: numero, pas: pas, peutSupprimer: peutSupprimer),
  );
}

class _SerieDialog extends StatefulWidget {
  const _SerieDialog({required this.serie, required this.suivi, required this.unite, required this.numero, required this.pas, required this.peutSupprimer});
  final PlannedSet serie;
  final ExerciseTracking suivi;
  final UnitePoids unite;
  final int numero;
  final double pas;
  final bool peutSupprimer;

  @override
  State<_SerieDialog> createState() => _SerieDialogState();
}

/// Façon de viser les répétitions d'une série prévue.
enum _Reps { fixes, fourchette, libres }

class _SerieDialogState extends State<_SerieDialog> {
  late SetType _type = widget.serie.type;
  late bool _repsLibres = widget.serie.reps == null;
  late double _reps = (widget.serie.reps ?? 8).toDouble();
  late bool _plage = widget.serie.repsMax != null && widget.serie.repsMax != widget.serie.reps;
  late double _repsMax = (widget.serie.repsMax ?? (widget.serie.reps ?? 8) + 4).toDouble();
  late bool _chargeLibre = widget.serie.poids == null;
  late double _poids = widget.serie.poids == null ? 20 : Fmt.poidsAffiche(widget.serie.poids!, widget.unite);
  late bool _dureeLibre = widget.serie.dureeSec == null;
  late double _duree = (widget.serie.dureeSec ?? 45).toDouble();
  late double? _distanceKm = widget.serie.distanceM == null ? null : Affichage.distanceAffichee(widget.serie.distanceM!);
  late double? _rpe = widget.serie.rpe;
  bool _toutes = false;

  /// Carte dont l'explication est dépliée, et listes ouvertes.
  bool _types = false;
  bool _effort = false;

  bool get _reps0 => widget.suivi.usesReps || (!widget.suivi.usesDuration);

  PlannedSet _resultat() => PlannedSet(
    type: _type,
    reps: _reps0 && !_repsLibres ? _reps.round() : null,
    repsMax: _reps0 && !_repsLibres && _plage && _repsMax.round() > _reps.round() ? _repsMax.round() : null,
    poids: widget.suivi.usesWeight && !_chargeLibre ? Fmt.poidsStocke(_poids, widget.unite) : null,
    dureeSec: widget.suivi.usesDuration && !_dureeLibre ? _duree.round() : null,
    distanceM: widget.suivi.usesDistance && _distanceKm != null ? Affichage.distanceStockee(_distanceKm!) : null,
    rpe: _rpe,
  );

  /// Une carte : son titre, une phrase qui explique le choix retenu, puis le réglage.
  Widget _carte(String titre, List<Widget> children, {String? aide}) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titre, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
          // Ce que fait le choix retenu, en une phrase.
          if (aide != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(aide, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13, height: 1.4, color: c.text.withValues(alpha: 0.72))),
            ),
          const SizedBox(height: 11),
          ...children,
        ],
      ),
    );
  }

  /// Une carte repliée en une ligne (« Type de série : Normale ») qui
  /// s'ouvre sur [contenu].
  Widget _carteLigne(String titre, String valeur, bool ouverte, VoidCallback basculer, Widget contenu) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            child: InkWell(
              onTap: basculer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        titre,
                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
                      ),
                    ),
                    Text(
                      valeur,
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14, color: c.text2),
                    ),
                    const SizedBox(width: 4),
                    Icon(ouverte ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20, color: c.text2),
                  ],
                ),
              ),
            ),
          ),
          if (ouverte) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12), child: contenu),
        ],
      ),
    );
  }

  /// Le réglage sous un sélecteur : centré, à hauteur constante pour que la
  /// fenêtre ne saute pas d'un choix à l'autre.
  Widget _reglage(Widget child) => child is SizedBox
      // Rien à régler pour ce choix : la carte se referme sur son explication.
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(child: child),
        );


  Widget _pilule({required String label, required bool choisie, required VoidCallback onTap, String? lettre, Color? couleur}) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: choisie,
      child: Material(
        color: c.surface2,
        shape: StadiumBorder(side: BorderSide(color: choisie ? c.text : c.surface2, width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 46),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (lettre != null) ...[
                  Text(
                    lettre,
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14.5, height: 1.2, fontWeight: FontWeight.w800, color: couleur),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14.5, height: 1.2, fontWeight: FontWeight.w600, color: choisie ? c.text : c.text2, fontFeatures: AppTokens.tabular),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final libelleCharge = switch (widget.suivi) {
      ExerciseTracking.poidsDuCorpsLeste => 'Lest',
      ExerciseTracking.poidsDuCorpsAssiste => 'Assistance',
      _ => 'Charge',
    };
    final reps = _repsLibres ? _Reps.libres : (_plage ? _Reps.fourchette : _Reps.fixes);
    return Padding(
      // Le panneau laisse voir le haut de l'écran et remonte avec le clavier.
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 24, bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.r26)),
        clipBehavior: Clip.antiAlias,
        child: TexteNet(
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 9, bottom: 8),
                      child: Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(color: c.text3, borderRadius: BorderRadius.circular(9)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _type == SetType.normale ? 'Série ${widget.numero}' : '${_type.label} · série ${widget.numero}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 20, fontWeight: FontWeight.w800, color: c.text),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fermer',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: IconeTrait(Trait.fermer, size: 20, color: c.text2),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_reps0)
                              _carte(
                                'Répétitions',
                                aide: switch (reps) {
                                  _Reps.fixes => 'Le même nombre à chaque fois.',
                                  _Reps.fourchette => 'Un minimum et un maximum à viser.',
                                  _Reps.libres => 'Rien de prévu : tu les notes pendant la séance.',
                                },
                                [
                                  SelecteurSegmente<_Reps>(
                                    segments: const [(_Reps.fixes, 'Nombre fixe'), (_Reps.fourchette, 'Fourchette'), (_Reps.libres, 'Libre')],
                                    value: reps,
                                    onChanged: (v) => setState(() {
                                      _repsLibres = v == _Reps.libres;
                                      _plage = v == _Reps.fourchette;
                                      if (_plage && _repsMax <= _reps) _repsMax = _reps + 1;
                                    }),
                                  ),
                                  _reglage(
                                    _repsLibres
                                        ? const SizedBox.shrink()
                                        : FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                NumberStepper(
                                                  value: _reps,
                                                  min: 1,
                                                  max: 100,
                                                  compact: true,
                                                  label: 'Répétitions',
                                                  onChanged: (v) => setState(() {
                                                    _reps = v;
                                                    if (_repsMax <= v) _repsMax = v + 1;
                                                  }),
                                                ),
                                                if (_plage) ...[
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                                    child: Text('à', style: TexteEntrainer.detail(context)),
                                                  ),
                                                  NumberStepper(value: _repsMax, min: _reps + 1, max: 100, compact: true, label: 'Maximum', onChanged: (v) => setState(() => _repsMax = v)),
                                                ],
                                              ],
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            if (widget.suivi.usesDuration)
                              _carte('Durée', aide: _dureeLibre ? 'Rien de prévu : tu la notes pendant la séance.' : 'La durée à tenir.', [
                                SelecteurSegmente<bool>(segments: const [(false, 'Fixée'), (true, 'Libre')], value: _dureeLibre, onChanged: (v) => setState(() => _dureeLibre = v)),
                                _reglage(
                                  _dureeLibre
                                      ? const SizedBox.shrink()
                                      : NumberStepper(value: _duree, min: 5, max: 3600, step: 5, unit: 's', compact: true, label: 'Durée', onChanged: (v) => setState(() => _duree = v)),
                                ),
                              ]),
                            if (widget.suivi.usesDistance)
                              _carte('Distance', [
                                Center(
                                  child: NumberStepper(
                                    value: _distanceKm ?? 0,
                                    min: 0,
                                    max: 100,
                                    step: 0.1,
                                    decimals: 2,
                                    unit: Affichage.distanceLabel,
                                    compact: true,
                                    label: 'Distance',
                                    onChanged: (v) => setState(() => _distanceKm = v == 0 ? null : v),
                                  ),
                                ),
                              ]),
                            if (widget.suivi.usesWeight)
                              _carte(
                                libelleCharge,
                                aide: _chargeLibre ? 'Au lancement, l’appli remet le poids de ta dernière séance sur cet exercice.' : 'La séance démarre toujours avec le poids que tu fixes ici.',
                                [
                                  SelecteurSegmente<bool>(
                                    segments: const [(true, 'Comme la dernière fois'), (false, 'Je la choisis')],
                                    value: _chargeLibre,
                                    onChanged: (v) => setState(() => _chargeLibre = v),
                                  ),
                                  _reglage(
                                    _chargeLibre
                                        ? const SizedBox.shrink()
                                        : NumberStepper(
                                            value: _poids,
                                            min: 0,
                                            max: 1000,
                                            step: widget.unite == UnitePoids.kg ? widget.pas : 5,
                                            decimals: 2,
                                            unit: widget.unite.label,
                                            compact: true,
                                            label: libelleCharge,
                                            onChanged: (v) => setState(() => _poids = v),
                                          ),
                                  ),
                                ],
                              ),
                            _carteLigne(
                              'Type de série',
                              _type.label,
                              _types,
                              () => setState(() => _types = !_types),
                              Column(
                                children: [
                                  for (final st in SetType.ordrePanneau)
                                    InkWell(
                                      borderRadius: AppTokens.radius12,
                                      onTap: () => setState(() {
                                        _type = st;
                                        _types = false;
                                      }),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 34,
                                              child: Text(
                                                st.lettre,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: AppTokens.fontUi,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: st == SetType.normale ? c.text : couleurType(context, st),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    st.label,
                                                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text),
                                                  ),
                                                  Text(
                                                    st.aide,
                                                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 12.5, height: 1.35, color: c.text2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_type == st)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8),
                                                child: IconeTrait(Trait.coche, size: 18, color: c.text),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _carteLigne(
                              'Effort visé',
                              _rpe == null ? 'Aucun' : 'RPE ${Fmt.n(_rpe)}',
                              _effort,
                              () => setState(() => _effort = !_effort),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'La difficulté à atteindre sur cette série. 10 : impossible d\'en faire une de plus. 8 : il en restait deux.',
                                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 12.5, height: 1.4, color: c.text2),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _pilule(label: 'Aucun', choisie: _rpe == null, onTap: () => setState(() => _rpe = null)),
                                      for (var v = 6.0; v <= 10; v += 0.5) _pilule(label: Fmt.n(v), choisie: _rpe == v, onTap: () => setState(() => _rpe = v)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Semantics(
                              checked: _toutes,
                              child: InkWell(
                                borderRadius: AppTokens.radius12,
                                onTap: () => setState(() => _toutes = !_toutes),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                                  child: Row(
                                    children: [
                                      CocheChoix(selected: _toutes, taille: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('Appliquer à toutes les séries du même type', style: TexteEntrainer.detail(context).copyWith(color: c.text, fontSize: 14.5)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Les commandes restent visibles quand le contenu défile.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BoutonPrincipal(
                            label: 'Valider',
                            onPressed: () => Navigator.of(context).pop(SerieEditee(_resultat(), toutes: _toutes)),
                          ),
                          if (widget.peutSupprimer)
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(SerieEditee(widget.serie, supprimer: true)),
                              child: Text(
                                'Supprimer la série',
                                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14, fontWeight: FontWeight.w600, color: c.error),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
