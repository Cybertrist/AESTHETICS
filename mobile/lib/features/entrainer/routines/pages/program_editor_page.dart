import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import '../logic/objectif.dart';
import '../logic/program_plan.dart';
import '../logic/routine_stats.dart';
import '../widgets/formulaire.dart';
import '../widgets/icones_editeur.dart';
import '../widgets/jours_selecteur.dart';
import '../widgets/ligne_routine.dart';
import '../widgets/photo_programme.dart';
import '../widgets/sous_page.dart';

/// Durées proposées, en semaines ; « Autre » ouvre une saisie.
const _durees = [4, 6, 8, 12, 16];

Picto _pictoObjectif(ObjectifProgramme o) => switch (o) {
  ObjectifProgramme.muscle => Picto.muscle,
  ObjectifProgramme.force => Picto.force,
  ObjectifProgramme.seche => Picto.seche,
  ObjectifProgramme.fondamentaux => Picto.fondamentaux,
  ObjectifProgramme.condition => Picto.condition,
  ObjectifProgramme.sport => Picto.sport,
};

Picto _pictoProgression(ProgressionType t) => switch (t) {
  ProgressionType.aucune => Picto.stable,
  ProgressionType.charge => Picto.monte,
  ProgressionType.doubleProgression => Picto.paliers,
  ProgressionType.ondulee => Picto.vague,
};

/// Création ou modification d'un programme perso.
class ProgramEditorPage extends StatefulWidget {
  const ProgramEditorPage({super.key, this.programId});
  final String? programId;

  @override
  State<ProgramEditorPage> createState() => _ProgramEditorPageState();
}

class _ProgramEditorPageState extends State<ProgramEditorPage> {
  final _nom = TextEditingController();

  /// Le nom ne prend le curseur qu'à l'ouverture, pas chaque fois qu'il
  /// revient à l'écran.
  bool _curseurAuNom = true;
  final _desc = TextEditingController();
  Program? _base;
  bool _introuvable = false;
  int _semaines = 8;
  int _jours = 3;
  List<String> _cycle = [];
  Set<int> _joursSemaine = {};
  ProgressionType _progression = ProgressionType.charge;
  double _increment = 2.5;
  int _decharge = 0;
  Niveau? _niveau;
  ObjectifProgramme? _objectif;

  /// Tant que l'objectif n'est pas touché, le texte d'origine est gardé.
  bool _objectifChange = false;
  String? _photo;
  bool _activer = true;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _curseurAuNom = false);
    if (widget.programId != null) {
      final p = context.read<ProgramRepo>().byId(widget.programId!);
      if (p == null) {
        _introuvable = true;
      } else {
        _base = p;
        _nom.text = p.nom;
        _desc.text = p.description ?? '';
        _semaines = p.dureeSemaines;
        _jours = p.joursParSemaine.clamp(1, 7);
        _cycle = [...p.routineIds];
        _niveau = Niveau.values.where((n) => n.name == p.niveau).firstOrNull;
        _objectif = ObjectifProgramme.depuis(p.objectif);
        final plan = ProgramPlanRepo.of(context.read<Store>()).planFor(p.id);
        _joursSemaine = {...plan.jours};
        _progression = plan.progression;
        _increment = plan.incrementKg;
        _decharge = plan.dechargeToutesLes;
        _photo = plan.photo;
      }
    } else {
      _increment = context.read<SettingsRepo>().settings.incrementPoidsKg;
    }
    _nom.addListener(_touch);
    _desc.addListener(_touch);
  }

  @override
  void dispose() {
    _nom.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _touch() => _dirty = true;

  void _maj(VoidCallback f) => setState(() {
    f();
    _dirty = true;
  });

  Future<void> _changerPhoto() async {
    final store = context.read<Store>();
    try {
      final chemin = await choisirPhotoProgramme(store);
      if (chemin == null || !mounted) return;
      _maj(() => _photo = chemin);
    } catch (_) {
      if (mounted) Toasts.error(context, 'Impossible d’ouvrir tes photos.');
    }
  }

  Future<void> _autreDuree() async {
    final n = await showNumberInputDialog(context, title: 'Durée en semaines', initial: _semaines.toDouble(), unit: 'sem.', decimal: false);
    if (n == null || !mounted) return;
    _maj(() => _semaines = n.round().clamp(1, 52));
  }

  Future<void> _ajouterRoutines() async {
    final routines = context.read<RoutineRepo>().routines;
    if (routines.isEmpty) {
      _nouvelleRoutine();
      return;
    }
    final ids = await showDialog<List<String>>(
      context: context,
      builder: (_) => _ChoixRoutines(routines: routines),
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    _maj(() => _cycle.addAll(ids));
  }

  Future<void> _nouvelleRoutine() async {
    final id = await context.push<String>('/entrainer/routines/nouvelle?retour=1');
    if (id == null || !mounted) return;
    _maj(() => _cycle.add(id));
  }

  /// Retire une routine du programme, avec de quoi revenir en arrière.
  void _retirer(int i) {
    final avant = [..._cycle];
    final nom = context.read<RoutineRepo>().byId(_cycle[i])?.nom ?? 'Routine';
    _maj(() => _cycle.removeAt(i));
    Toasts.show(
      context,
      '$nom retirée du programme.',
      actionLabel: 'Annuler',
      onAction: () {
        if (mounted) _maj(() => _cycle = avant);
      },
    );
  }

  Future<void> _enregistrer() async {
    if (_nom.text.trim().isEmpty) {
      Toasts.error(context, 'Donne un nom au programme.');
      return;
    }
    if (_cycle.isEmpty) {
      Toasts.error(context, 'Ajoute au moins une routine au programme.');
      return;
    }
    setState(() => _saving = true);
    final repo = context.read<ProgramRepo>();
    final plans = ProgramPlanRepo.of(context.read<Store>());
    try {
      final b = _base;
      final description = _desc.text.trim().isEmpty ? null : _desc.text.trim();
      final prog = await repo.save(
        b == null
            ? Program(
                id: '',
                nom: _nom.text.trim(),
                description: description,
                dureeSemaines: _semaines,
                joursParSemaine: _jours,
                routineIds: _cycle,
                niveau: _niveau?.name,
                objectif: _objectif?.label,
                creeLe: DateTime.now(),
              )
            : Program(
                id: b.id,
                nom: _nom.text.trim(),
                description: description,
                dureeSemaines: _semaines,
                joursParSemaine: _jours,
                routineIds: _cycle,
                actif: b.actif,
                debuteLe: b.debuteLe,
                semaineCourante: b.semaineCourante.clamp(0, _semaines - 1),
                prochainIndex: b.prochainIndex % _cycle.length,
                seancesFaites: b.seancesFaites,
                niveau: _niveau?.name,
                objectif: _objectifChange ? _objectif?.label : b.objectif,
                creeLe: b.creeLe,
              ),
      );
      await plans.save(
        ProgramPlan(
          programId: prog.id,
          progression: _progression,
          incrementKg: _increment,
          dechargeToutesLes: _decharge,
          jours: _joursSemaine.toList()..sort(),
          modeleId: plans.hasPlan(prog.id) ? plans.planFor(prog.id).modeleId : null,
          photo: _photo,
        ),
      );
      if (b == null && _activer) await repo.activate(prog.id, restart: true);
      if (!mounted) return;
      _dirty = false;
      Toasts.success(context, 'Programme enregistré.');
      if (b == null) {
        context.pushReplacement('/entrainer/programmes/${prog.id}');
      } else {
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        Toasts.error(context, 'Enregistrement impossible. Réessaie.');
      }
    }
  }

  Future<void> _quitter() async {
    if (!_dirty) {
      context.pop();
      return;
    }
    final ok = await showConfirmDialog(context, title: 'Abandonner les modifications ?', confirmLabel: 'Abandonner', destructive: true);
    if (ok && mounted) context.pop();
  }

  Widget _bloc(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    if (_introuvable) {
      return SousPage(
        title: 'Programme',
        body: EmptyState(icon: Icons.error_outline_rounded, title: 'Programme introuvable', actionLabel: 'Voir les programmes', onAction: () => context.go('/entrainer?onglet=programmes')),
      );
    }
    final c = context.colors;
    final routines = context.watch<RoutineRepo>();
    final wide = context.isExpanded;
    final detail = TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14, height: 1.38, color: c.text2);

    final general = <Widget>[
      const SizedBox(height: 14),
      Center(
        child: ListenableBuilder(
          listenable: _nom,
          builder: (context, _) => CouvertureProgrammeVue(nom: _nom.text, photo: _photo, cote: 156),
        ),
      ),
      const SizedBox(height: 6),
      Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            LienBlanc(label: _photo == null ? 'Ajouter une photo' : 'Changer la photo', icone: const IconeTrait(Trait.appareil, size: 20), onTap: _changerPhoto),
            if (_photo != null) LienBlanc(label: 'Retirer', couleur: c.text2, onTap: () => _maj(() => _photo = null)),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _bloc(ChampBord(controller: _nom, label: 'Nom du programme', autofocus: _base == null && _curseurAuNom, maxLength: 60)),
      const SizedBox(height: 16),
      _bloc(ChampBord(controller: _desc, label: 'Description (facultatif)', maxLength: 400, maxLines: 5)),
      const TitreSection('Niveau'),
      _bloc(
        LayoutBuilder(
          builder: (context, box) {
            final etroit = box.maxWidth < 350;
            return Row(
              children: [
                for (final n in Niveau.values) ...[
                  if (n != Niveau.values.first) SizedBox(width: etroit ? 8 : 10),
                  Expanded(
                    child: CarteChoix(
                      icone: IconeNiveau(n.index + 1, size: 28),
                      label: n.label,
                      taille: etroit ? 13.5 : 15.5,
                      serre: etroit,
                      hauteur: 100,
                      selected: _niveau == n,
                      onTap: () => _maj(() => _niveau = _niveau == n ? null : n),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      const TitreSection('Séances par semaine'),
      _bloc(RangeePastilles<int>(choix: [for (var n = 1; n <= 7; n++) (n, '$n', Fmt.pluriel(n, 'séance'))], choisies: {_jours}, onChanged: (n) => _maj(() => _jours = n))),
      const TitreSection('Durée', detail: 'En semaines.'),
      _bloc(
        RangeePastilles<int>(
          choix: [for (final d in _durees) (d, '$d', '$d semaines'), (-1, 'Autre', 'Autre durée')],
          choisies: {_durees.contains(_semaines) ? _semaines : -1},
          onChanged: (d) => d == -1 ? _autreDuree() : _maj(() => _semaines = d),
        ),
      ),
      if (!_durees.contains(_semaines))
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 12, AppTokens.gutter, 0),
          child: Text('${Fmt.pluriel(_semaines, 'semaine')}. Touche « Autre » pour changer.', style: detail),
        ),
      const TitreSection('Jours d\'entraînement', detail: 'Facultatif : les jours où tu comptes t\'entraîner.'),
      _bloc(JoursSelecteur(jours: _joursSemaine, onChanged: (j) => _maj(() => _joursSemaine = j))),
      if (_joursSemaine.isNotEmpty && _joursSemaine.length != _jours)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, 2, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('${Fmt.pluriel(_joursSemaine.length, 'jour choisi', 'jours choisis')} pour ${Fmt.pluriel(_jours, 'séance')}.', style: detail.copyWith(color: c.warning)),
              ),
              LienBlanc(label: 'Ajuster', onTap: () => _maj(() => _jours = _joursSemaine.length)),
            ],
          ),
        ),
      const TitreSection('Objectif'),
      _bloc(
        LayoutBuilder(
          builder: (context, box) {
            const ecart = 12.0;
            final largeur = (box.maxWidth - ecart) / 2;
            return Wrap(
              spacing: ecart,
              runSpacing: ecart,
              children: [
                for (final o in ObjectifProgramme.values)
                  SizedBox(
                    width: largeur,
                    child: CarteChoix(
                      icone: IconePicto(_pictoObjectif(o), size: 38),
                      label: o.label,
                      hauteur: 120,
                      selected: _objectif == o,
                      onTap: () => _maj(() {
                        _objectif = _objectif == o ? null : o;
                        _objectifChange = true;
                      }),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      const TitreSection('Progression', detail: 'Comment les charges évoluent d\'une séance à l\'autre.'),
      for (final t in ProgressionType.values)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 0, AppTokens.gutter, 10),
          child: LigneChoix(icone: IconePicto(_pictoProgression(t), size: 22), titre: t.label, detail: t.description, selected: _progression == t, onTap: () => _maj(() => _progression = t)),
        ),
      const SizedBox(height: 8),
      if (_progression != ProgressionType.aucune) ...[
        _bloc(
          CadreReglage(
            icone: const IconePicto(Picto.disque, size: 22),
            titre: 'Incrément de charge',
            commande: NumberStepper(value: _increment, min: 0.5, max: 20, step: 0.5, decimals: 1, unit: 'kg', compact: true, onChanged: (v) => _maj(() => _increment = v)),
          ),
        ),
        const SizedBox(height: 10),
      ],
      _bloc(
        CadreReglage(
          icone: const IconePicto(Picto.lune, size: 22),
          titre: 'Semaine de décharge',
          detail: _decharge == 0 ? 'Jamais.' : 'Toutes les $_decharge semaines : moitié des séries, charge à 90 %.',
          commande: NumberStepper(value: _decharge.toDouble(), min: 0, max: 12, compact: true, onChanged: (v) => _maj(() => _decharge = v.round())),
        ),
      ),
      if (_base == null) ...[
        const SizedBox(height: 10),
        _bloc(
          CadreReglage(
            icone: const IconeTrait(Trait.lectureCercle, size: 22),
            titre: 'Le suivre dès maintenant',
            commande: Switch(value: _activer, onChanged: (v) => setState(() => _activer = v)),
          ),
        ),
      ],
    ];

    final cycle = <Widget>[
      TitreSection('Routines du programme', detail: 'Elles s\'enchaînent dans cet ordre, puis recommencent.', haut: wide ? 14 : 36),
      if (_cycle.isEmpty)
        _bloc(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.surface3, width: 1.2),
            ),
            child: Column(
              children: [
                TraitIcone(AppIcone.haltere, size: 30, color: c.text2),
                const SizedBox(height: 10),
                Text(
                  'Aucune routine',
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 16.5, fontWeight: FontWeight.w700, color: c.text),
                ),
                const SizedBox(height: 4),
                Text('Ajoute des routines existantes ou crée-en une.', textAlign: TextAlign.center, style: detail),
              ],
            ),
          ),
        )
      else
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          proxyDecorator: (child, _, _) => Material(color: c.surface, child: child),
          onReorderItem: (a, b) => _maj(() {
            _cycle.insert(b, _cycle.removeAt(a));
          }),
          children: [
            for (var i = 0; i < _cycle.length; i++)
              _LigneCycle(
                key: ValueKey('$i-${_cycle[i]}'),
                index: i,
                routine: routines.byId(_cycle[i]),
                onRetirer: () => _retirer(i),
                onModifier: routines.byId(_cycle[i]) == null
                    ? null
                    : () async {
                        await context.push('/entrainer/routines/${_cycle[i]}/modifier');
                        // Nom, exercices et durée ont pu changer.
                        if (mounted) setState(() {});
                      },
              ),
          ],
        ),
      const SizedBox(height: 16),
      _bloc(BoutonSecondaire(label: 'Ajouter une routine', icone: const IconeTrait(Trait.plus, size: 20), onPressed: _ajouterRoutines)),
      const SizedBox(height: 10),
      _bloc(BoutonSecondaire(label: 'Nouvelle routine', icone: const IconeTrait(Trait.crayon, size: 20), onPressed: _nouvelleRoutine)),
      if (_cycle.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 16, AppTokens.gutter, 0),
          child: Text(
            '${Fmt.pluriel(_semaines * _jours, 'séance')} au total, chaque routine environ ${((_semaines * _jours) / _cycle.length).round()} fois.',
            textAlign: TextAlign.center,
            style: detail,
          ),
        ),
    ];

    const marge = EdgeInsets.only(bottom: 32);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quitter();
      },
      child: SousPage(
        title: _base == null ? 'Nouveau programme' : 'Modifier le programme',
        closeIcon: true,
        onBack: _quitter,
        maxContentWidth: wide ? 1180 : Breakpoints.content,
        bottomBar: BoutonPrincipal(label: 'Enregistrer', onPressed: _saving ? null : _enregistrer),
        body: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(padding: marge, children: general),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ListView(padding: marge, children: cycle),
                  ),
                ],
              )
            : ListView(padding: marge, children: [...general, ...cycle]),
      ),
    );
  }
}

/// Une routine du programme : poignée, carte de jour, nom, résumé, croix.
class _LigneCycle extends StatelessWidget {
  const _LigneCycle({super.key, required this.index, required this.routine, required this.onRetirer, this.onModifier});

  final int index;
  final Routine? routine;
  final VoidCallback onRetirer;

  /// Ouvre la routine dans son éditeur (un appui sur la ligne).
  final VoidCallback? onModifier;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = routine;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 7, 4, 7),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: 'Déplacer',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
                child: IconePicto(Picto.poignee, size: 22, color: c.text3, epaisseur: 2),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              button: onModifier != null,
              label: r == null ? null : 'Modifier la routine ${r.nom}',
              child: InkWell(
                borderRadius: AppTokens.radius12,
                onTap: onModifier,
                child: Row(
                  children: [
                    r == null ? Tuile(taille: 50, child: Icon(Icons.help_outline_rounded, color: c.warning, size: 24)) : VignetteRoutineVue(routine: r, rang: index, taille: 50),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r?.nom ?? 'Routine supprimée',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 16.5, height: 1.25, fontWeight: FontWeight.w700, color: c.text),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            r == null ? 'Retire-la ou remplace-la.' : resumeRoutine(r),
                            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.5, height: 1.3, color: r == null ? c.warning : c.text2),
                          ),
                        ],
                      ),
                    ),
                    if (onModifier != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: IconeTrait(Trait.crayon, size: 18, color: c.text3),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Retirer du programme',
            visualDensity: VisualDensity.compact,
            icon: IconeTrait(Trait.fermer, size: 20, color: c.text2),
            onPressed: onRetirer,
          ),
        ],
      ),
    );
  }
}

/// Choix de plusieurs routines, dans l'ordre des coches.
class _ChoixRoutines extends StatefulWidget {
  const _ChoixRoutines({required this.routines});
  final List<Routine> routines;

  @override
  State<_ChoixRoutines> createState() => _ChoixRoutinesState();
}

class _ChoixRoutinesState extends State<_ChoixRoutines> {
  final _sel = <String>[];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
              child: Text(
                'Ajouter des routines',
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 19, fontWeight: FontWeight.w700, color: c.text),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (i, r) in widget.routines.indexed)
                    Builder(
                      builder: (context) {
                        final rang = _sel.indexOf(r.id);
                        return InkWell(
                          onTap: () => setState(() => rang >= 0 ? _sel.remove(r.id) : _sel.add(r.id)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
                            child: Row(
                              children: [
                                VignetteRoutineVue(routine: r, rang: i, taille: 44, fond: c.surface),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.nom,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 16, height: 1.25, fontWeight: FontWeight.w700, color: c.text),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        resumeRoutine(r),
                                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13.5, height: 1.3, color: c.text2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Le rang de la coche donne l'ordre d'ajout.
                                rang >= 0
                                    ? Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: c.bouton),
                                        child: Text(
                                          '${rang + 1}',
                                          style: TextStyle(fontFamily: AppTokens.fontUi, color: c.onBouton, fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                      )
                                    : const CocheChoix(selected: false, taille: 26),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: BoutonSecondaire(label: 'Annuler', petit: true, fond: c.surface3, onPressed: () => Navigator.of(context).pop()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BoutonPrincipal(
                      label: _sel.isEmpty ? 'Ajouter' : 'Ajouter (${_sel.length})',
                      petit: true,
                      onPressed: _sel.isEmpty ? null : () => Navigator.of(context).pop(List<String>.from(_sel)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
