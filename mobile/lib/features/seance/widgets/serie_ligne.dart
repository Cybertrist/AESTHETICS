import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../profil/widgets/ecusson.dart';
import 'habillage.dart';

/// Largeurs des colonnes du tableau des séries (`.sq` de la maquette), en-tête
/// et lignes alignés.
abstract final class Colonnes {
  static final serie = k(30);
  static final poids = k(46);
  static final reps = k(54);
  static final valeur = k(54);
  static final rpe = k(34);
  static final coche = k(38);
  static final ecart = k(4);

  /// Retrait latéral des lignes, pleine largeur.
  static final marge = k(14);
  static final hauteur = k(46);
}

double? lireNombre(String t) {
  final s = t.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// « 90 », « 1:30 » ou « 1:05:00 » en secondes. Un nombre seul compte en
/// minutes quand [minutes] est vrai (cardio : « 35 » veut dire 35 min).
int? lireDuree(String t, {bool minutes = false}) {
  final s = t.trim();
  if (s.isEmpty) return null;
  if (s.contains(':')) {
    return s.split(':').fold<int>(0, (total, p) => total * 60 + (int.tryParse(p) ?? 0));
  }
  final n = int.tryParse(s);
  return n == null ? null : (minutes ? n * 60 : n);
}

String ecrireNombre(double? v) {
  if (v == null) return '';
  final r = (v * 100).roundToDouble() / 100;
  if (r == r.roundToDouble()) return r.toInt().toString();
  return r.toString().replaceAll('.', ',');
}

String ecrireDuree(int? sec) => sec == null ? '' : Fmt.chrono(Duration(seconds: sec));

/// Couleur du repère d'une série : bleu du minuteur pour le numéro d'une
/// série normale (maquette), couleur du type pour une lettre.
Color couleurType(BuildContext context, SetType t) => t == SetType.normale ? context.colors.minuteur : t.couleur;

/// L'or des records, et sa version pâle pour les reflets et les filets.
const orRecord = Color(0xFFFFBE0B);
const orPale = Color(0xFFFDE68A);

/// Reflet d'une ligne de record : un éclat pâle, en biais, qui traverse
/// lentement puis laisse la ligne au repos. Toutes les lignes suivent la
/// même horloge : deux records voisins brillent ensemble.
class _RefletRecord extends StatefulWidget {
  const _RefletRecord();

  @override
  State<_RefletRecord> createState() => _RefletRecordState();
}

class _RefletRecordState extends State<_RefletRecord> with SingleTickerProviderStateMixin {
  static const _cycle = 3400;
  late final AnimationController _tic = AnimationController(vsync: this, duration: const Duration(milliseconds: _cycle));

  @override
  void initState() {
    super.initState();
    // Pas d'animation sans fin pendant les tests automatiques.
    if (!Platform.environment.containsKey('FLUTTER_TEST')) _tic.repeat();
  }

  @override
  void dispose() {
    _tic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _tic,
        builder: (context, _) {
          // Il ne traverse que le premier tiers du cycle.
          final t = (DateTime.now().millisecondsSinceEpoch % _cycle) / _cycle;
          if (!_tic.isAnimating || t > 0.34) return const SizedBox.shrink();
          final avance = t / 0.34;
          return FractionalTranslation(
            translation: Offset(-1.2 + avance * 2.4, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [orPale.withValues(alpha: 0), orPale.withValues(alpha: 0.16 * math.sin(avance * math.pi)), orPale.withValues(alpha: 0)],
                  stops: const [0.36, 0.5, 0.64],
                ),
              ),
            ),
          );
        },
      );
}

/// Rappel de la fois précédente : « 10 kg × 15 » (espace avant l'unité, signe ×).
String precedentCourt(WorkoutSet p, ExerciseTracking suivi, UnitePoids u) {
  final parts = <String>[];
  if (suivi.usesWeight && p.poids != null) {
    final signe = suivi == ExerciseTracking.poidsDuCorpsAssiste ? '-' : (suivi == ExerciseTracking.poidsDuCorpsLeste && p.poids! > 0 ? '+' : '');
    parts.add('$signe${ecrireNombre(Fmt.poidsAffiche(p.poids!, u))} ${u.label}');
  }
  if (suivi.usesReps && p.reps != null) parts.add('${p.reps}');
  if (suivi.usesDistance && p.distanceM != null) {
    parts.add(Affichage.distance(p.distanceM!));
  }
  if (suivi.usesDuration && p.dureeSec != null) parts.add(Fmt.chrono(Duration(seconds: p.dureeSec!)));
  if (parts.isEmpty) return '-';
  // Seules les répétitions sont connues (poids du corps, lest non saisi).
  if (suivi.usesReps && p.reps != null && parts.length == 1) return '${p.reps} reps';
  return parts.join(' × ');
}

/// Dans un champ décimal, le point du clavier devient une virgule (« 72,5 »),
/// et il n'y en a qu'une.
final virguleDecimale = TextInputFormatter.withFunction((ancien, nouveau) {
  final t = nouveau.text.replaceAll('.', ',');
  if (','.allMatches(t).length > 1) return ancien;
  return t == nouveau.text ? nouveau : nouveau.copyWith(text: t);
});

/// Une ligne du tableau : repère (numéro ou lettre du type), précédent, valeurs
/// à saisir sans cases, coche en pilule. Pleine largeur ; validée, elle passe
/// sur fond vert sombre.
class SerieLigne extends StatefulWidget {
  const SerieLigne({
    super.key,
    required this.set,
    required this.label,
    required this.suivi,
    required this.unite,
    required this.onChanged,
    required this.onToggle,
    required this.onMenu,
    this.precedent,
    this.afficherRpe = false,
    this.effortRir = false,
    this.alterne = false,
    this.record = false,
    this.cibleReps,
    this.repsPrevues,
  });

  final WorkoutSet set;
  final String label;
  final ExerciseTracking suivi;
  final UnitePoids unite;
  final WorkoutSet? precedent;
  final bool afficherRpe;

  /// Effort affiché et saisi en répétitions en réserve (10 − RPE).
  final bool effortRir;

  /// Une ligne sur deux, non validée, sur fond à peine plus clair.
  final bool alterne;

  /// La série validée bat un record : ligne dorée, avec un reflet qui passe.
  final bool record;

  /// Fourchette prévue par la routine (« 12-15 ») : montrée en gris tant que
  /// la série n'est ni saisie ni validée.
  final String? cibleReps;

  /// Répétitions posées par la routine au départ (le bas de la fourchette).
  final int? repsPrevues;
  final ValueChanged<WorkoutSet> onChanged;

  /// Cocher : reçoit la série complétée par le précédent si des champs sont vides.
  final ValueChanged<WorkoutSet> onToggle;

  /// Toucher le repère : panneau « Type de série ».
  final VoidCallback onMenu;

  @override
  State<SerieLigne> createState() => _SerieLigneState();
}

class _SerieLigneState extends State<SerieLigne> {
  late final _poids = TextEditingController();
  late final _reps = TextEditingController();
  late final _duree = TextEditingController();
  late final _dist = TextEditingController();
  final _fPoids = FocusNode();
  final _fReps = FocusNode();
  final _fDuree = FocusNode();
  final _fDist = FocusNode();

  /// Les reps ont été saisies à la main : on ne montre plus la fourchette.
  bool _repsSaisies = false;

  WorkoutSet get s => widget.set;
  UnitePoids get u => widget.unite;

  /// Tant que rien n'est saisi, la fourchette de la routine tient lieu de valeur.
  bool get _montrerCible =>
      widget.cibleReps != null && !s.fait && !_repsSaisies && (s.reps == null || widget.repsPrevues == null || s.reps == widget.repsPrevues);

  @override
  void initState() {
    super.initState();
    _remplir(force: true);
    _fDuree.addListener(() {
      if (!_fDuree.hasFocus) _duree.text = ecrireDuree(s.dureeSec);
    });
    // Le champ qui a le curseur reprend ses gestes, les autres les laissent passer.
    for (final f in [_fPoids, _fReps, _fDuree, _fDist]) {
      f.addListener(_surFocus);
    }
  }

  final _avaitLaMain = <FocusNode, bool>{};

  void _surFocus() {
    // Un champ qui prend la main sélectionne sa valeur : le premier chiffre
    // tapé la remplace, au lieu de s'ajouter à la suite (70 puis « 72,5 »
    // donnait 7072,5).
    for (final (f, c) in [(_fPoids, _poids), (_fReps, _reps), (_fDuree, _duree), (_fDist, _dist)]) {
      final aLaMain = f.hasFocus;
      if (aLaMain && _avaitLaMain[f] != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && f.hasFocus) c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
        });
      }
      _avaitLaMain[f] = aLaMain;
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SerieLigne old) {
    super.didUpdateWidget(old);
    _remplir();
  }

  void _remplir({bool force = false}) {
    void maj(TextEditingController c, FocusNode f, String texte, bool Function() pareil) {
      if (force || (!f.hasFocus && !pareil())) c.text = texte;
    }

    final p = s.poids == null ? null : Fmt.poidsAffiche(s.poids!, u);
    maj(_poids, _fPoids, ecrireNombre(p), () => lireNombre(_poids.text) == (p == null ? null : (p * 100).roundToDouble() / 100));
    final reps = _montrerCible ? '' : (s.reps?.toString() ?? '');
    maj(_reps, _fReps, reps, () => _reps.text == reps);
    maj(_duree, _fDuree, ecrireDuree(s.dureeSec), () => lireDuree(_duree.text, minutes: widget.suivi.usesDistance) == s.dureeSec);
    final km = s.distanceM == null ? null : Affichage.distanceAffichee(s.distanceM!);
    maj(_dist, _fDist, ecrireNombre(km), () => lireNombre(_dist.text) == km);
  }

  @override
  void dispose() {
    for (final c in [_poids, _reps, _duree, _dist]) {
      c.dispose();
    }
    for (final f in [_fPoids, _fReps, _fDuree, _fDist]) {
      f.dispose();
    }
    super.dispose();
  }

  WorkoutSet _avec({double? poids, bool clearPoids = false, int? reps, bool clearReps = false, int? duree, bool clearDuree = false, double? dist, bool clearDist = false}) =>
      WorkoutSet(
        id: s.id,
        type: s.type,
        poids: clearPoids ? null : (poids ?? s.poids),
        reps: clearReps ? null : (reps ?? s.reps),
        rpe: s.rpe,
        fait: s.fait,
        tempsReposSec: s.tempsReposSec,
        dureeSec: clearDuree ? null : (duree ?? s.dureeSec),
        distanceM: clearDist ? null : (dist ?? s.distanceM),
        faitLe: s.faitLe,
      );

  void _copierPrecedent() {
    final p = widget.precedent;
    if (p == null) return;
    HapticFeedback.selectionClick();
    _repsSaisies = true;
    final x = _avec(poids: p.poids, reps: p.reps, duree: p.dureeSec, dist: p.distanceM);
    widget.onChanged(x);
    // Les champs prennent tout de suite les valeurs copiées, même celui qui
    // a le curseur (la reconstruction ne touche pas un champ en cours de saisie).
    _poids.text = ecrireNombre(x.poids == null ? null : Fmt.poidsAffiche(x.poids!, u));
    _reps.text = x.reps?.toString() ?? '';
    _duree.text = ecrireDuree(x.dureeSec);
    _dist.text = ecrireNombre(x.distanceM == null ? null : Affichage.distanceAffichee(x.distanceM!));
  }

  /// Le champ sans lequel la série n'a rien à enregistrer, s'il est vide.
  FocusNode? _manquant(WorkoutSet x) {
    final suivi = widget.suivi;
    if (suivi.usesReps && x.reps == null) return _fReps;
    if (suivi.usesDistance && x.distanceM == null && x.dureeSec == null) return _fDist;
    if (suivi.usesDuration && !suivi.usesDistance && x.dureeSec == null) return _fDuree;
    return null;
  }

  void _cocher() {
    final p = widget.precedent;
    var x = s;
    if (!s.fait && p != null) {
      x = _avec(
        poids: s.poids ?? (widget.suivi.usesWeight ? p.poids : null),
        reps: s.reps ?? (widget.suivi.usesReps ? p.reps : null),
        duree: s.dureeSec ?? (widget.suivi.usesDuration ? p.dureeSec : null),
        dist: s.distanceM ?? (widget.suivi.usesDistance ? p.distanceM : null),
      );
    }
    if (!s.fait) {
      // Rien de saisi et rien à reprendre : on ne valide pas une série vide,
      // on donne la main au champ à remplir.
      final vide = _manquant(x);
      if (vide != null) {
        HapticFeedback.selectionClick();
        vide.requestFocus();
        return;
      }
    }
    if (s.fait) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    widget.onToggle(x);
  }

  Future<void> _choisirRpe() async {
    final c = context.colors;
    final rir = widget.effortRir;
    // En RIR, de 0 (à fond) à 4 en réserve ; la série garde un RPE.
    final valeurs = [for (var v = 6.0; v <= 10; v += 0.5) v];
    if (rir) valeurs.setAll(0, valeurs.reversed.toList());
    final r = await showDialog<double>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rir ? 'Répétitions en réserve (RIR)' : 'Effort ressenti (RPE)', style: ctx.textStyles.titleLarge),
              const SizedBox(height: 6),
              Text(rir ? '0 : impossible d\'en faire une de plus. 2 : il en restait deux.' : '10 : impossible d\'en faire une de plus. 8 : il en restait deux.', style: ctx.textStyles.bodySmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in valeurs)
                    ChoiceChip(
                      label: Text(Fmt.n(rir ? 10 - v : v)),
                      selected: s.rpe == v,
                      onSelected: (_) => Navigator.of(ctx).pop(v),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(-1),
                  child: Text('Effacer', style: TextStyle(color: c.text2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (r == null) return;
    widget.onChanged(WorkoutSet(
      id: s.id,
      type: s.type,
      poids: s.poids,
      reps: s.reps,
      rpe: r < 0 ? null : r,
      fait: s.fait,
      tempsReposSec: s.tempsReposSec,
      dureeSec: s.dureeSec,
      distanceM: s.distanceM,
      faitLe: s.faitLe,
    ));
  }

  TextStyle _valeur(Color couleur) => TextStyle(
        fontFamily: AppTokens.fontUi,
        fontSize: k(16),
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: couleur,
        fontFeatures: AppTokens.tabular,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final suivi = widget.suivi;
    final p = widget.precedent;
    final fait = s.fait;
    // Valeurs en blanc une fois validées, en gris clair avant.
    final encre = fait ? c.text : Color.lerp(c.text2, c.text, 0.18)!;
    final cellules = <Widget>[];

    Widget champ(TextEditingController ctrl, FocusNode f, String hint, double largeur, ValueChanged<String> onChanged, {bool decimal = true, String? cle, String filtre = r'[0-9.,]', int longueur = 7}) {
      // Tant qu'il n'a pas le curseur, le champ laisse passer les gestes : un
      // toucher lui donne la main, un glissé part de n'importe où sur la
      // ligne pour supprimer la série (un champ de saisie garderait le
      // glissé horizontal pour lui).
      return SizedBox(
        width: largeur,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: f.hasFocus ? null : f.requestFocus,
          child: IgnorePointer(
            ignoring: !f.hasFocus,
            child: TextField(
          key: cle == null ? null : ValueKey('${s.id}-$cle'),
          controller: ctrl,
          focusNode: f,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(filtre)),
            if (filtre.contains(',')) virguleDecimale,
            LengthLimitingTextInputFormatter(longueur),
          ],
          textInputAction: TextInputAction.next,
          cursorColor: c.minuteur,
          // Clavier ouvert, la page défile pour garder la ligne saisie (et la suivante) à l'écran.
          scrollPadding: EdgeInsets.only(top: k(40), bottom: Colonnes.hauteur + k(10)),
          style: _valeur(encre),
          // Sans case : le chiffre est posé sur la ligne.
          decoration: InputDecoration(
            isDense: true,
            isCollapsed: true,
            hintText: hint,
            hintStyle: _valeur(Color.lerp(c.text2, c.text, 0.18)!),
            hintMaxLines: 1,
            filled: false,
            contentPadding: EdgeInsets.symmetric(vertical: k(9)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
          ),
        ),
      );
    }

    if (suivi.usesWeight) {
      final hint = p?.poids == null ? (suivi == ExerciseTracking.poidsDuCorpsLeste ? '+0' : '0') : ecrireNombre(Fmt.poidsAffiche(p!.poids!, u));
      cellules.add(champ(_poids, _fPoids, hint, Colonnes.poids, (t) {
        final v = lireNombre(t);
        widget.onChanged(v == null ? _avec(clearPoids: true) : _avec(poids: Fmt.poidsStocke(v, u)));
      }, cle: 'poids'));
    }
    if (suivi.usesDistance) {
      cellules.add(champ(_dist, _fDist, p?.distanceM == null ? Affichage.distanceLabel : ecrireNombre(Affichage.distanceAffichee(p!.distanceM!)), Colonnes.valeur, (t) {
        final v = lireNombre(t);
        widget.onChanged(v == null ? _avec(clearDist: true) : _avec(dist: Affichage.distanceStockee(v)));
      }, cle: 'dist'));
    }
    if (suivi.usesReps) {
      final hint = _montrerCible ? widget.cibleReps! : (p?.reps?.toString() ?? '0');
      cellules.add(champ(_reps, _fReps, hint, Colonnes.reps, (t) {
        _repsSaisies = true;
        final v = int.tryParse(t.trim());
        widget.onChanged(v == null ? _avec(clearReps: true) : _avec(reps: v));
      }, decimal: false, cle: 'reps', filtre: r'[0-9]', longueur: 4));
    }
    if (suivi.usesDuration) {
      cellules.add(champ(_duree, _fDuree, p?.dureeSec == null ? '0:00' : ecrireDuree(p!.dureeSec), Colonnes.valeur, (t) {
        final v = lireDuree(t, minutes: suivi.usesDistance);
        widget.onChanged(v == null ? _avec(clearDuree: true) : _avec(duree: v));
      }, decimal: false, cle: 'duree', filtre: r'[0-9:]', longueur: 8));
    }
    if (widget.afficherRpe) {
      cellules.add(SizedBox(
        width: Colonnes.rpe,
        child: InkWell(
          borderRadius: AppTokens.radius8,
          onTap: _choisirRpe,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: k(9)),
            child: Text(
              s.rpe == null ? '-' : Fmt.n(widget.effortRir ? 10 - s.rpe! : s.rpe),
              textAlign: TextAlign.center,
              style: _valeur(s.rpe == null ? c.text3 : encre).copyWith(fontSize: k(13)),
            ),
          ),
        ),
      ));
    }

    // Curseur, poignée et sélection en bleu du minuteur, comme les numéros de série.
    return TextSelectionTheme(
      data: TextSelectionThemeData(cursorColor: c.minuteur, selectionHandleColor: c.minuteur, selectionColor: c.minuteur.withValues(alpha: 0.35)),
      child: _ligne(context, c, fait, p, cellules),
    );
  }

  Widget _ligne(BuildContext context, AppColors c, bool fait, WorkoutSet? p, List<Widget> cellules) {
    final suivi = widget.suivi;
    final dore = fait && widget.record;
    final ligne = AnimatedContainer(
      duration: AppTokens.fast,
      height: Colonnes.hauteur,
      padding: EdgeInsets.symmetric(horizontal: Colonnes.marge),
      // Validée : vert sombre. Record : fond sombre à peine réchauffé, entre
      // deux filets dorés. Sinon une ligne sur deux à peine éclaircie.
      decoration: BoxDecoration(
        color: dore ? const Color(0xFF1D180B) : (fait ? c.setDone : (widget.alterne ? c.surface2.withValues(alpha: 0.85) : c.bg.withValues(alpha: 0))),
        border: Border.symmetric(horizontal: BorderSide(color: orPale.withValues(alpha: dore ? 0.24 : 0))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: Colonnes.serie,
            height: Colonnes.hauteur,
            child: Semantics(
              button: true,
              label: 'Type de série',
              child: InkWell(
                borderRadius: AppTokens.radius8,
                onTap: widget.onMenu,
                child: Center(
                  // Record : l'écusson « PR » prend la place du numéro.
                  child: dore
                      ? Ecusson.record(largeur: k(30))
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(widget.label, maxLines: 1, style: _valeur(couleurType(context, s.type))),
                        ),
                ),
              ),
            ),
          ),
          SizedBox(width: Colonnes.ecart),
          Expanded(
            child: InkWell(
              borderRadius: AppTokens.radius8,
              onTap: p == null ? null : _copierPrecedent,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: k(9)),
                // Colonne étroite (RPE affiché, Fold fermé) : le rappel se réduit plutôt que d'être coupé.
                child: dore
                    ? Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: k(8), vertical: k(3)),
                          decoration: BoxDecoration(color: orPale.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(k(99))),
                          child: Text(
                            'RECORD',
                            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(10), height: 1.2, fontWeight: FontWeight.w800, letterSpacing: k(1), color: orPale),
                          ),
                        ),
                      )
                    : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                  p == null ? '-' : precedentCourt(p, suivi, u),
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), color: c.text2, fontFeatures: AppTokens.tabular),
                ),
                ),
              ),
            ),
          ),
          for (final w in cellules) ...[SizedBox(width: Colonnes.ecart), w],
          SizedBox(width: Colonnes.ecart),
          SizedBox(
            width: Colonnes.coche,
            child: Semantics(
              button: true,
              label: fait ? 'Décocher la série' : 'Valider la série',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _cocher,
                child: SizedBox(
                  height: Colonnes.hauteur,
                  child: Center(
                    child: AnimatedContainer(
                      duration: AppTokens.fast,
                      width: k(38),
                      height: k(28),
                      decoration: BoxDecoration(color: dore ? orPale : (fait ? c.foret : AppTokens.poignee), borderRadius: AppTokens.radiusPill),
                      alignment: Alignment.center,
                      child: Trait(IconeSeance.coche, size: k(15), epaisseur: dore ? 2.2 : 1.8, color: dore ? Colors.black : c.text),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!dore) return ligne;
    return Stack(
      children: [
        ligne,
        const Positioned.fill(child: IgnorePointer(child: ClipRect(child: _RefletRecord()))),
      ],
    );
  }
}

/// En-tête des colonnes (« Série, Précédent, Kg, Reps »), aligné sur [SerieLigne].
class EnteteSeries extends StatelessWidget {
  const EnteteSeries({super.key, required this.suivi, required this.unite, this.afficherRpe = false, this.effortRir = false});

  final ExerciseTracking suivi;
  final UnitePoids unite;
  final bool afficherRpe;
  final bool effortRir;

  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), color: context.colors.text2);
    Widget col(String t, double w) => SizedBox(
          width: w,
          child: Text(t, textAlign: TextAlign.center, style: st, maxLines: 1, softWrap: false, overflow: TextOverflow.visible),
        );
    final unit = unite.label[0].toUpperCase() + unite.label.substring(1);
    final poidsLabel = switch (suivi) {
      ExerciseTracking.poidsDuCorpsLeste => '+$unit',
      ExerciseTracking.poidsDuCorpsAssiste => '-$unit',
      _ => unit,
    };
    return Container(
      height: k(32),
      padding: EdgeInsets.symmetric(horizontal: Colonnes.marge),
      child: Row(
        children: [
          col('Série', Colonnes.serie),
          SizedBox(width: Colonnes.ecart),
          Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Précédent', textAlign: TextAlign.center, style: st, maxLines: 1, softWrap: false))),
          if (suivi.usesWeight) ...[SizedBox(width: Colonnes.ecart), col(poidsLabel, Colonnes.poids)],
          if (suivi.usesDistance) ...[SizedBox(width: Colonnes.ecart), col('Km', Colonnes.valeur)],
          if (suivi.usesReps) ...[SizedBox(width: Colonnes.ecart), col('Reps', Colonnes.reps)],
          if (suivi.usesDuration) ...[SizedBox(width: Colonnes.ecart), col('Temps', Colonnes.valeur)],
          if (afficherRpe) ...[SizedBox(width: Colonnes.ecart), col(effortRir ? 'RIR' : 'RPE', Colonnes.rpe)],
          SizedBox(width: Colonnes.ecart + Colonnes.coche),
        ],
      ),
    );
  }
}
