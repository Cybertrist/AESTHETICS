import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../profil/data/plates.dart';
import '../../profil/data/prefs.dart';
import '../logic/editeur.dart';
import '../widgets/habillage.dart';
import '../widgets/pages.dart';

/// Calculateur de disques et d'échauffement, sur les barres et disques
/// réglés dans Réglages > Entraînement.
/// [poidsKg] : charge de départ ; [seId] : exercice de la séance en cours
/// auquel ajouter les séries d'échauffement.
class DisquesPage extends StatefulWidget {
  const DisquesPage({super.key, this.poidsKg, this.seId});

  final double? poidsKg;
  final String? seId;

  @override
  State<DisquesPage> createState() => _DisquesPageState();
}

class _DisquesPageState extends State<DisquesPage> {
  PrefsRepo? _prefs;
  bool _erreur = false;
  late double _cibleKg = widget.poidsKg ?? 60;
  String? _barreId;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final p = await PrefsRepo.ensure(context.read<Store>());
      if (mounted) setState(() => _prefs = p);
    } catch (_) {
      if (mounted) setState(() => _erreur = true);
    }
  }

  Future<void> _ajouterEchauffement(List<({double poids, int reps})> paliers) async {
    final ed = EditeurDirect(context.read<SessionRepo>());
    await ed.ajouterEchauffement(widget.seId!, paliers);
    ed.dispose();
    if (!mounted) return;
    Toasts.success(context, paliers.length > 1 ? '${paliers.length} séries d\'échauffement ajoutées' : 'Série d\'échauffement ajoutée');
    Navigator.of(context).maybePop();
  }

  String _cote(ChargementBarre ch, UnitePoids u) =>
      ch.parCote.isEmpty ? 'Barre seule' : 'Par côté : ${ch.parCote.map((d) => Fmt.n(Fmt.poidsAffiche(d, u), decimals: 2)).join(' + ')}';

  Future<void> _saisir(UnitePoids u) async {
    final v = await showNumberInputDialog(context, title: 'Charge visée', initial: Fmt.poidsAffiche(_cibleKg, u), unit: u.label);
    if (v == null || !mounted) return;
    setState(() => _cibleKg = Fmt.poidsStocke(v.clamp(0, 1000).toDouble(), u));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final u = context.watch<ProfileRepo>().unite;
    final pasKg = context.watch<SettingsRepo>().settings.incrementPoidsKg;
    final repo = context.watch<SessionRepo>();
    final peutAjouter = widget.seId != null && repo.active?.exercices.any((e) => e.id == widget.seId) == true;
    const titre = 'Disques et échauffement';

    if (_erreur) {
      return PageSeance(
        titre: titre,
        body: VideSeance(
          icone: const Trait(IconeSeance.alerte),
          titre: 'Matériel illisible',
          message: 'Tes barres et disques n\'ont pas pu être lus.',
          action: 'Réessayer',
          onAction: () {
            setState(() => _erreur = false);
            _charger();
          },
        ),
      );
    }
    final pr = _prefs;
    if (pr == null) {
      return PageSeance(titre: titre, body: Center(child: CircularProgressIndicator(color: c.text2, strokeWidth: 2)));
    }

    return ListenableBuilder(
      listenable: pr,
      builder: (context, _) {
        final p = pr.prefs;
        final barres = p.barres.where((b) => b.active).toList();
        final barre = barres.where((b) => b.id == _barreId).firstOrNull ?? p.barre;
        final barreKg = barre?.poidsKg ?? 0;
        final disques = p.disques.where((d) => d.paires > 0).toList();
        final ch = Plates.charger(_cibleKg, barreKg, disques);
        final pas = pasKg <= 0 ? 2.5 : pasKg;
        final paliers = Strength.echauffement(_cibleKg, barre: barreKg, pas: pas);
        final large = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
        final maxDisque = disques.isEmpty ? 1.0 : disques.map((d) => d.poidsKg).reduce((a, b) => a > b ? a : b);
        final gris = TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), height: 1.4, color: c.text2, fontFeatures: AppTokens.tabular);
        final gras = TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.35, fontWeight: FontWeight.w600, color: c.text, fontFeatures: AppTokens.tabular);

        void bouger(int sens) {
          final v = (Fmt.poidsAffiche(_cibleKg, u) + sens * Fmt.poidsAffiche(pas, u)).clamp(0.0, 1000.0);
          setState(() => _cibleKg = Fmt.poidsStocke(double.parse(v.toStringAsFixed(2)), u));
        }

        final calcul = <Widget>[
          const Surtitre('Charge visée'),
          SizedBox(height: k(8)),
          Container(
            padding: EdgeInsets.all(k(14)),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(18))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BoutonRond(label: 'Moins', onTap: () => bouger(-1), child: Trait(IconeSeance.moins, size: k(18), epaisseur: 2)),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Saisir la charge',
                        child: InkWell(
                          borderRadius: AppTokens.radius8,
                          onTap: () => _saisir(u),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: k(2)),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text.rich(
                                TextSpan(children: [
                                  TextSpan(text: Fmt.n(Fmt.poidsAffiche(_cibleKg, u), decimals: 2)),
                                  TextSpan(text: ' ${u.label}', style: TextStyle(fontSize: k(14), fontWeight: FontWeight.w600, color: c.text2)),
                                ]),
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: AppTokens.fontUi,
                                  fontSize: k(28),
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.7,
                                  color: c.text,
                                  fontFeatures: AppTokens.tabular,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    BoutonRond(label: 'Plus', onTap: () => bouger(1), child: Trait(IconeSeance.plus, size: k(18), epaisseur: 2)),
                  ],
                ),
                SizedBox(height: k(14)),
                _Barre(parCote: ch.parCote, maxDisque: maxDisque, unite: u),
                SizedBox(height: k(12)),
                Text(_cote(ch, u), textAlign: TextAlign.center, style: gras),
                if (!ch.exact) ...[
                  SizedBox(height: k(4)),
                  Text(
                    ch.ecartKg < 0 ? 'La barre seule pèse déjà ${Fmt.poids(barreKg, u)}.' : 'Au plus près avec ton matériel : ${Fmt.poids(ch.totalKg, u)}.',
                    textAlign: TextAlign.center,
                    style: gris.copyWith(color: c.warning),
                  ),
                ],
              ],
            ),
          ),
        ];

        final materiel = <Widget>[
          const Surtitre('Mon matériel'),
          SizedBox(height: k(8)),
          if (barres.isEmpty)
            Text('Aucune barre active : le calcul se fait sans barre.', style: gris)
          else
            Wrap(
              spacing: k(6),
              runSpacing: k(6),
              children: [
                for (final b in barres)
                  _Choix(label: '${b.nom} · ${Fmt.poids(b.poidsKg, u)}', retenu: b.id == barre?.id, onTap: () => setState(() => _barreId = b.id)),
              ],
            ),
          SizedBox(height: k(10)),
          Text(
            disques.isEmpty
                ? 'Aucun disque réglé.'
                : 'Paires de disques : ${disques.map((d) => '${Fmt.n(Fmt.poidsAffiche(d.poidsKg, u), decimals: 2)} ${u.label} × ${d.paires}').join(', ')}.',
            style: gris,
          ),
          SizedBox(height: k(4)),
          Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(-k(6), 0),
              child: LienTexte(label: 'Modifier mon matériel', onTap: () => context.push('/reglages/entrainement/disques')),
            ),
          ),
        ];

        final echauffement = <Widget>[
          const Surtitre('Échauffement conseillé'),
          SizedBox(height: k(8)),
          if (paliers.isEmpty)
            Text('Charge trop légère pour un échauffement progressif : quelques répétitions à vide suffisent.', style: gris)
          else ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: k(12), vertical: k(4)),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(14))),
              child: Column(
                children: [
                  for (var i = 0; i < paliers.length; i++)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: k(8)),
                      decoration: BoxDecoration(border: i < paliers.length - 1 ? Border(bottom: BorderSide(color: c.line)) : null),
                      child: Row(
                        children: [
                          SizedBox(
                            width: k(24),
                            child: Text(
                              SetType.echauffement.lettre,
                              style: gras.copyWith(fontSize: k(15), fontWeight: FontWeight.w800, color: SetType.echauffement.couleur),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${Fmt.poids(paliers[i].poids, u)} × ${paliers[i].reps}', style: gras),
                                Text(_cote(Plates.charger(paliers[i].poids, barreKg, disques), u), style: gris.copyWith(fontSize: k(11))),
                              ],
                            ),
                          ),
                          Text('${(paliers[i].poids / (_cibleKg == 0 ? 1 : _cibleKg) * 100).round()} %', style: gris),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (peutAjouter) ...[
              SizedBox(height: k(8)),
              BoutonSeance(label: 'Ajouter à l\'exercice', fond: c.surface2, encre: c.text, onTap: () => _ajouterEchauffement(paliers)),
            ],
          ],
        ];

        final ecart = SizedBox(height: k(18));
        return PageSeance(
          titre: titre,
          largeurMax: large ? 1100 : 640,
          body: large
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ListView(padding: EdgeInsets.fromLTRB(margeSeance, k(6), k(8), k(24)), children: [...calcul, ecart, ...materiel])),
                    Expanded(child: ListView(padding: EdgeInsets.fromLTRB(k(8), k(6), margeSeance, k(24)), children: echauffement)),
                  ],
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(margeSeance, k(6), margeSeance, k(24)),
                  children: [...calcul, ecart, ...echauffement, ecart, ...materiel],
                ),
        );
      },
    );
  }
}

/// Choix en pilule encadrée : cadre blanc quand il est retenu.
class _Choix extends StatelessWidget {
  const _Choix({required this.label, required this.retenu, required this.onTap});

  final String label;
  final bool retenu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: retenu,
      child: InkWell(
        borderRadius: AppTokens.radiusPill,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: k(36)),
          padding: EdgeInsets.symmetric(horizontal: k(12), vertical: k(6)),
          decoration: BoxDecoration(borderRadius: AppTokens.radiusPill, border: Border.all(color: retenu ? c.text : c.frame, width: 1.5)),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTokens.fontUi,
              fontSize: k(12),
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: retenu ? c.text : c.text2,
              fontFeatures: AppTokens.tabular,
            ),
          ),
        ),
      ),
    );
  }
}

/// Un côté de la barre chargée, disques du plus lourd au plus léger : du
/// blanc pour le plus lourd au gris pour le plus léger.
class _Barre extends StatelessWidget {
  const _Barre({required this.parCote, required this.maxDisque, required this.unite});
  final List<double> parCote;
  final double maxDisque;
  final UnitePoids unite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          Container(width: 34, height: 12, decoration: BoxDecoration(color: c.surface3, borderRadius: AppTokens.radius8)),
          Container(width: 8, height: 34, decoration: BoxDecoration(color: c.text3, borderRadius: BorderRadius.circular(3))),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 10, decoration: BoxDecoration(color: c.surface3, borderRadius: AppTokens.radius8)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final d in parCote)
                        Container(
                          width: d >= 10 ? 22 : 16,
                          height: 40 + 76 * (d / maxDisque).clamp(0.0, 1.0),
                          margin: const EdgeInsets.only(right: 3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Color.lerp(c.text2, c.text, (d / maxDisque).clamp(0.0, 1.0)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              Fmt.n(Fmt.poidsAffiche(d, unite), decimals: 2),
                              style: TextStyle(fontFamily: AppTokens.fontUi, color: c.onBouton, fontWeight: FontWeight.w700, fontSize: 11, fontFeatures: AppTokens.tabular),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
