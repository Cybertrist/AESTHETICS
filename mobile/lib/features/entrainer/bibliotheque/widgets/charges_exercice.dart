import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../profil/widgets/maquette.dart' as mq;
import '../../commun/elements.dart';

/// Ligne « Charges » de la fiche d'un exercice : ce que l'appli utilise
/// pour proposer la charge d'après (« Pile de 15 lb, appoint de 5 lb ·
/// déduit de tes séances »). La toucher ouvre le réglage.
class LigneCharges extends StatelessWidget {
  const LigneCharges({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final charges = context.watch<ChargesRepo>();
    // L'historique change la déduction : la ligne suit les séances.
    context.watch<SessionRepo>();
    return mq.Groupe(
      lignes: [
        mq.Ligne(
          trace: mq.Trace.haltere,
          titre: 'Charges',
          detail: charges.resume(exerciseId),
          detailLignes: 2,
          onTap: () => reglerCharges(context, exerciseId),
        ),
      ],
    );
  }
}

/// Le panneau du bas qui règle les charges d'un exercice : la sorte de
/// matériel, puis ce qui la décrit (unité, pas, départ, appoints ; barre ou
/// chariot). « Revenir à la déduction » oublie le réglage.
Future<void> reglerCharges(BuildContext context, String exerciseId) => showPanneauBas<void>(
      context,
      titre: 'Charges',
      builder: (_) => TexteNet(child: _PanneauCharges(repo: context.read<ChargesRepo>(), exerciseId: exerciseId)),
    );

class _PanneauCharges extends StatefulWidget {
  const _PanneauCharges({required this.repo, required this.exerciseId});

  final ChargesRepo repo;
  final String exerciseId;

  @override
  State<_PanneauCharges> createState() => _PanneauChargesState();
}

class _PanneauChargesState extends State<_PanneauCharges> {
  late final _depart = widget.repo.pour(widget.exerciseId);
  late Graduation _g = _depart.graduation;

  /// Ce que chaque sorte devient quand on la choisit : la graduation de
  /// départ si c'est la sienne, sinon une valeur courante.
  Graduation _sorte(SorteCharges s) {
    if (s == _depart.graduation.sorte) return _depart.graduation;
    return switch (s) {
      SorteCharges.pile => const Graduation.pile(),
      SorteCharges.disques => const Graduation.disques(base: 20),
      SorteCharges.halteres => const Graduation.halteres(),
      SorteCharges.kettlebell => const Graduation.kettlebell(),
      SorteCharges.libre => Graduation.libre(pas: widget.repo.settings.settings.incrementPoidsKg),
    };
  }

  /// La dernière charge notée, pour montrer la suivante.
  double get _exemple {
    final notees = widget.repo.chargesNotees(widget.exerciseId);
    return notees.isEmpty ? 40 : notees.first;
  }

  Future<void> _enregistrer() async {
    await widget.repo.regler(widget.exerciseId, _g);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _oublier() async {
    await widget.repo.revenirALaDeduction(widget.exerciseId);
    if (mounted) Navigator.of(context).pop();
  }

  String _n(double v) => Fmt.n(v, decimals: 2);

  Widget _titre(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 8), child: Surtitre(t));

  Widget _reglage(String titre, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Expanded(child: Text(titre, style: TexteEntrainer.ligne(context))),
            child,
          ],
        ),
      );

  List<Widget> _pile() {
    final lb = _g.unite == UniteCharges.lb;
    final u = _g.unite.label;
    final pasPossibles = lb ? const [5.0, 10.0, 15.0, 20.0] : const [2.5, 5.0, 10.0];
    final appointsPossibles = lb ? const [2.5, 5.0] : const [1.25, 2.5];
    final grain = lb ? 5.0 : 1.25;
    return [
      _titre('Unité des plaques'),
      SelecteurSegmente<UniteCharges>(
        segments: const [(UniteCharges.lb, 'Livres'), (UniteCharges.kg, 'Kilos')],
        value: _g.unite,
        onChanged: (v) => setState(() {
          if (v == _g.unite) return;
          final pas = v == UniteCharges.lb ? 10.0 : 5.0;
          _g = Graduation.pile(unite: v, pas: pas, depart: pas);
        }),
      ),
      _titre('Écart entre deux plaques'),
      SelecteurSegmente<double>(
        segments: [for (final p in pasPossibles) (p, '${_n(p)} $u')],
        value: pasPossibles.contains(_g.pas) ? _g.pas : pasPossibles.first,
        onChanged: (v) => setState(() => _g = _g.copyWith(pas: v)),
      ),
      _reglage(
        'Première plaque',
        NumberStepper(
          value: _g.depart,
          step: grain,
          min: grain,
          max: lb ? 500 : 250,
          decimals: 2,
          unit: u,
          compact: true,
          label: 'Première plaque',
          onChanged: (v) => setState(() => _g = _g.copyWith(depart: v)),
        ),
      ),
      _titre('Plaques d’appoint'),
      mq.Groupe(
        lignes: [
          for (final a in appointsPossibles)
            mq.LigneBascule(
              titre: '${_n(a)} $u',
              detail: lb ? 'Écrite ${_n(Graduation.etiquetteAppoint(a))} kg' : null,
              valeur: _g.appoints.contains(a),
              onChanged: (oui) => setState(() {
                final l = {..._g.appoints};
                oui ? l.add(a) : l.remove(a);
                _g = _g.copyWith(appoints: l.toList()..sort());
              }),
            ),
        ],
      ),
    ];
  }

  List<Widget> _disques() => [
        _titre('Plus petit écart (une paire)'),
        SelecteurSegmente<double>(
          segments: const [(1.0, '1 kg'), (2.5, '2,5 kg'), (5.0, '5 kg')],
          value: const [1.0, 2.5, 5.0].contains(_g.pas) ? _g.pas : 2.5,
          onChanged: (v) => setState(() => _g = _g.copyWith(pas: v)),
        ),
        _titre('Ce qui porte les disques'),
        SelecteurSegmente<bool>(
          segments: const [(false, 'Une barre'), (true, 'Un chariot')],
          value: _g.chariot,
          onChanged: (v) => setState(() => _g = _g.copyWith(chariot: v, base: v ? Graduation.chariotPresse : 20)),
        ),
        _reglage(
          _g.chariot ? 'Poids du chariot' : 'Poids de la barre',
          NumberStepper(
            value: _g.base,
            step: 0.5,
            max: 300,
            decimals: 2,
            unit: 'kg',
            compact: true,
            label: _g.chariot ? 'Poids du chariot' : 'Poids de la barre',
            onChanged: (v) => setState(() => _g = _g.copyWith(base: v)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Tu notes les disques seuls ; ${_g.chariot ? 'le chariot' : 'la barre'} s’affiche à part.', style: TexteEntrainer.detail(context)),
        ),
      ];

  List<Widget> _libre() => [
        _reglage(
          'Pas',
          NumberStepper(
            value: _g.pas,
            step: 0.25,
            min: 0.25,
            max: 20,
            decimals: 2,
            unit: 'kg',
            compact: true,
            label: 'Pas',
            onChanged: (v) => setState(() => _g = _g.copyWith(pas: v)),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final regle = widget.repo.reglage(widget.exerciseId) != null;
    final x = _g.arrondir(_exemple);
    final apres = _g.suivante(x);
    String charge(double kg) => [Fmt.poids(kg), ?_g.libelleMachine(kg)].join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          regle ? 'Réglé à la main pour cet exercice.' : 'Pour l’instant : ${_depart.graduation.description}, ${_depart.origine.label}.',
          style: TexteEntrainer.detail(context),
        ),
        _titre('Matériel'),
        for (final s in SorteCharges.values)
          ChoixPanneau(
            label: s.label,
            selected: _g.sorte == s,
            onTap: () => setState(() => _g = _sorte(s)),
          ),
        ...switch (_g.sorte) {
          SorteCharges.pile => _pile(),
          SorteCharges.disques => _disques(),
          SorteCharges.libre => _libre(),
          SorteCharges.halteres || SorteCharges.kettlebell => [Text(_g.description, style: TexteEntrainer.detail(context))],
        },
        const SizedBox(height: 16),
        // Ce que la proposition de fin de séance ferait.
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(16)),
          child: Text('Après ${charge(x)}, la charge d’après : ${charge(apres)}.', style: TexteEntrainer.detail(context).copyWith(color: c.text)),
        ),
        const SizedBox(height: 16),
        BoutonPrincipal(label: 'Enregistrer', onPressed: _enregistrer),
        if (regle) ...[
          const SizedBox(height: 10),
          BoutonSecondaire(label: 'Revenir à la déduction', fond: AppTokens.surface3, onPressed: _oublier),
        ],
      ],
    );
  }
}
