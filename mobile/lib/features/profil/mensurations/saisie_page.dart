import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/mensurations.dart';
import '../widgets/maquette.dart';

/// Saisir ou modifier : un seul écran pour une nouvelle saisie et pour
/// corriger une ancienne. La date se change en haut, chaque mesure se règle
/// par « − » et « + » ou au clavier en touchant sa valeur.
class SaisiePage extends StatefulWidget {
  const SaisiePage({super.key, this.id, this.zone});

  /// Saisie à corriger ; null pour une nouvelle.
  final String? id;

  /// Mesure d'où l'on vient : elle est mise en avant.
  final ZoneMesure? zone;

  @override
  State<SaisiePage> createState() => _SaisiePageState();
}

class _SaisiePageState extends State<SaisiePage> {
  BrouillonSaisie? _b;
  bool _introuvable = false;
  bool _enCours = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_b != null || _introuvable) return;
    final sante = context.read<HealthRepo>();
    final profil = context.read<ProfileRepo>();
    final champs = ChampSaisie.tous(unite: profil.unite, poidsProfilKg: profil.profile?.poidsKg);
    final mesures = sante.measurements;
    if (widget.id == null) {
      _b = BrouillonSaisie.nouvelle(champs, mesures);
    } else {
      final m = mesures.where((x) => x.id == widget.id).firstOrNull;
      if (m == null) {
        _introuvable = true;
      } else {
        _b = BrouillonSaisie.depuis(champs, m, mesures);
      }
    }
  }

  Future<void> _choisirDate() async {
    final b = _b!;
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: b.date.isAfter(now) ? now : b.date,
      // Une saisie importée peut être plus vieille que vingt ans.
      firstDate: b.date.year < now.year - 20 ? DateTime(b.date.year) : DateTime(now.year - 20),
      lastDate: now,
      helpText: 'Date de la saisie',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (d != null && mounted) setState(() => b.date = d);
  }

  Future<void> _clavier(ChampSaisie champ) async {
    final b = _b!;
    final r = await showPanneauBas<_Reponse>(
      context,
      titre: champ.label,
      builder: (context) => _PanneauValeur(champ: champ, valeur: b.valeur(champ), retirable: b.estSaisi(champ)),
    );
    if (r == null || !mounted) return;
    setState(() => r.retirer ? b.retirer(champ) : b.fixer(champ, r.valeur!));
  }

  Future<void> _enregistrer() async {
    final b = _b!;
    if (b.vide || _enCours) return;
    setState(() => _enCours = true);
    final sante = context.read<HealthRepo>();
    // Une seule saisie par jour : on complète celle qui existe déjà.
    final reunie = b.modification && saisieAReunir(sante.measurements, b) != null;
    await enregistrerSaisie(sante, b);
    if (!mounted) return;
    Toasts.success(
      context,
      reunie ? 'Saisie réunie avec celle du ${Mensurations.jourLong(b.date)}' : (b.modification ? 'Saisie modifiée' : 'Mesures enregistrées'),
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _supprimer() async {
    final b = _b!;
    final ok = await showPanneauBas<bool>(
      context,
      titre: 'Supprimer cette saisie ?',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Les mesures du ${Mensurations.jourLong(b.date)} seront effacées.',
            textAlign: TextAlign.center,
            style: txt(12, FontWeight.w400, context.colors.text2),
          ),
          SizedBox(height: e(14)),
          BoutonDestructif(label: 'Supprimer', fond: AppTokens.surface3, onPressed: () => Navigator.pop(context, true)),
          SizedBox(height: e(8)),
          BoutonSecondaire(label: 'Annuler', fond: AppTokens.surface3, onPressed: () => Navigator.pop(context, false)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<HealthRepo>().deleteMeasurement(b.origine!.id);
    if (!mounted) return;
    Toasts.success(context, 'Saisie supprimée');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = _b;
    if (b == null) {
      return const PageMaquette(
        titre: 'Saisie introuvable',
        enfants: [Vide(titre: 'Cette saisie n\'existe plus', message: 'Elle a peut-être été supprimée.')],
      );
    }
    return PageMaquette(
      titre: b.modification ? 'Modifier la saisie' : 'Nouvelle saisie',
      bas: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoutonPrincipal(label: 'Enregistrer', onPressed: b.vide || _enCours ? null : _enregistrer),
          if (b.modification)
            Padding(
              padding: EdgeInsets.only(top: e(4)),
              child: TextButton(
                onPressed: _supprimer,
                style: TextButton.styleFrom(foregroundColor: c.error, padding: EdgeInsets.symmetric(vertical: e(13)), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('Supprimer cette saisie', style: txt(13, FontWeight.w600, c.error)),
              ),
            ),
        ],
      ),
      enfants: [
        Bloc(
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: _choisirDate,
              borderRadius: BorderRadius.circular(e(14)),
              child: Container(
                height: e(48),
                padding: EdgeInsets.symmetric(horizontal: e(12)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(e(14)),
                  border: Border.all(color: c.surface3, width: e(1.5)),
                ),
                child: Row(
                  children: [
                    IconeTrait(Trace.calendrier, taille: e(18), couleur: c.text2),
                    SizedBox(width: e(12)),
                    Expanded(child: Text('Date', style: txt(13, FontWeight.w600, c.text))),
                    Text(DateFormat('d MMMM y', 'fr_FR').format(b.date), style: txt(12, FontWeight.w400, c.text2)),
                    SizedBox(width: e(12)),
                    IconeTrait(Trace.chevron, taille: e(14), couleur: c.text3, epaisseur: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
        Bloc(
          child: Groupe(
            lignes: [
              for (final champ in b.champs)
                _LigneChamp(
                  champ: champ,
                  valeur: b.valeur(champ),
                  saisi: b.estSaisi(champ),
                  avant: champ.zone != null && champ.zone == widget.zone,
                  onMoins: () => setState(() => b.cran(champ, -1)),
                  onPlus: () => setState(() => b.cran(champ, 1)),
                  onValeur: () => _clavier(champ),
                ),
            ],
          ),
        ),
        if (b.champs.any((ch) => !b.estSaisi(ch)))
          Bloc(
            haut: 0,
            child: Text(
              'En gris : la dernière valeur connue, pas encore saisie. Règle-la ou touche-la pour la retenir.',
              style: txt(11, FontWeight.w400, c.text2),
            ),
          ),
      ],
    );
  }
}

class _LigneChamp extends StatelessWidget {
  const _LigneChamp({
    required this.champ,
    required this.valeur,
    required this.saisi,
    required this.avant,
    required this.onMoins,
    required this.onPlus,
    required this.onValeur,
  });

  final ChampSaisie champ;
  final double valeur;
  final bool saisi;
  final bool avant;
  final VoidCallback onMoins;
  final VoidCallback onPlus;
  final VoidCallback onValeur;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget bouton(String signe, String label, VoidCallback onTap) => Semantics(
          button: true,
          label: '$label ${champ.label}',
          excludeSemantics: true,
          child: Material(
            color: c.surface2,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: SizedBox.square(
                dimension: e(32),
                child: Center(child: Text(signe, style: txt(16, FontWeight.w700, c.text, interligne: 1))),
              ),
            ),
          ),
        );
    return SizedBox(
      height: e(46) - 1,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: e(12)),
        child: Row(
          children: [
            Expanded(
              child: Text(champ.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(13, avant ? FontWeight.w800 : FontWeight.w600, c.text)),
            ),
            bouton('−', 'Diminuer', onMoins),
            SizedBox(width: e(6)),
            Semantics(
              button: true,
              label: '${champ.label}, ${Fmt.n(valeur)} ${champ.unite}${saisi ? '' : ', pas encore saisi'}. Toucher pour taper la valeur',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onValeur,
                child: SizedBox(
                  width: e(62),
                  height: e(44),
                  child: Center(
                    child: Text.rich(
                      TextSpan(
                        text: Fmt.n(valeur),
                        children: [TextSpan(text: ' ${champ.unite}', style: txt(10.5, FontWeight.w500, c.text2))],
                      ),
                      maxLines: 1,
                      style: txt(14, FontWeight.w700, saisi ? c.text : c.text3),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: e(6)),
            bouton('+', 'Augmenter', onPlus),
          ],
        ),
      ),
    );
  }
}

class _Reponse {
  const _Reponse.valeur(this.valeur) : retirer = false;
  const _Reponse.retirer()
      : valeur = null,
        retirer = true;
  final double? valeur;
  final bool retirer;
}

/// Saisie directe d'une valeur au clavier.
class _PanneauValeur extends StatefulWidget {
  const _PanneauValeur({required this.champ, required this.valeur, required this.retirable});
  final ChampSaisie champ;
  final double valeur;
  final bool retirable;

  @override
  State<_PanneauValeur> createState() => _PanneauValeurState();
}

class _PanneauValeurState extends State<_PanneauValeur> {
  late final _ctrl = TextEditingController(text: Fmt.n(widget.valeur));

  @override
  void initState() {
    super.initState();
    _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double? get _lu {
    final v = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
    return v == null || v < widget.champ.min || v > widget.champ.max ? null : v;
  }

  void _valider() {
    final v = _lu;
    if (v != null) Navigator.pop(context, _Reponse.valeur(v));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), LengthLimitingTextInputFormatter(6)],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _valider(),
          style: txt(28, FontWeight.w800, c.text, interligne: 1.2),
          cursorColor: c.text,
          decoration: InputDecoration(
            suffixText: widget.champ.unite,
            suffixStyle: txt(13, FontWeight.w500, c.text2),
            filled: true,
            fillColor: AppTokens.surface3,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(e(14)), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(e(14)), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(e(14)), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: e(14), vertical: e(10)),
          ),
        ),
        SizedBox(height: e(8)),
        // La plage acceptée, en clair : sinon « Valider » grisé reste muet.
        Text(
          'De ${Fmt.n(widget.champ.min)} à ${Fmt.n(widget.champ.max)} ${widget.champ.unite}',
          textAlign: TextAlign.center,
          style: txt(11, FontWeight.w400, _lu == null && _ctrl.text.trim().isNotEmpty ? c.error : c.text2),
        ),
        SizedBox(height: e(10)),
        BoutonPrincipal(label: 'Valider', onPressed: _lu == null ? null : _valider),
        if (widget.retirable) ...[
          SizedBox(height: e(8)),
          BoutonDestructif(
            label: 'Retirer de cette saisie',
            fond: AppTokens.surface3,
            onPressed: () => Navigator.pop(context, const _Reponse.retirer()),
          ),
        ],
      ],
    );
  }
}
