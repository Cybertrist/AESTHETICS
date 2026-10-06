import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../data/draft.dart';
import '../data/program_generator.dart';
import '../data/proposition.dart';
import '../widgets/widgets.dart';

/// Programme conseillé selon les réponses de l'inscription.
class ProgramPage extends StatefulWidget {
  const ProgramPage({super.key, this.premier = false});

  /// Juste après l'inscription : « Plus tard » mène à l'accueil.
  final bool premier;

  @override
  State<ProgramPage> createState() => _ProgramPageState();
}

class _ProgramPageState extends State<ProgramPage> {
  Object? _erreur;
  bool _pret = false;
  bool _adoption = false;

  @override
  void initState() {
    super.initState();
    propositionCourante.addListener(_maj);
    _preparer();
  }

  @override
  void dispose() {
    propositionCourante.removeListener(_maj);
    super.dispose();
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  Future<void> _preparer({Formule? formule}) async {
    setState(() {
      _erreur = null;
      _pret = false;
    });
    try {
      final profils = context.read<ProfileRepo>();
      final exos = context.read<ExerciseRepo>();
      final store = context.read<Store>();
      if (!exos.loaded) await exos.load();
      final profil = profils.profile;
      if (profil == null) throw StateError('profil');
      if (exos.catalogueVide) throw StateError('catalogue');
      final x = await ProfileExtras.load(store);
      final p = ProgramGenerator(exos).generer(profil, x.musclesPrioritaires, formule: formule);
      propositionCourante.definir(p, profil, x.musclesPrioritaires);
      if (mounted) setState(() => _pret = true);
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  Future<void> _changerFormule(Formule f) async {
    if (propositionCourante.retouche) {
      final ok = await showConfirmDialog(
        context,
        title: 'Changer de découpage ?',
        message: 'Tes retouches sur les séances seront perdues.',
        confirmLabel: 'Changer',
      );
      if (!ok) return;
    }
    await _preparer(formule: f);
  }

  void _quitter() {
    if (widget.premier || !context.canPop()) {
      context.go('/');
    } else {
      context.pop();
    }
  }

  Future<void> _adopter() async {
    final p = propositionCourante.proposal;
    final profil = propositionCourante.profil;
    if (p == null || profil == null) return;
    final programmes = context.read<ProgramRepo>();
    final actif = programmes.active;
    if (actif != null) {
      final ok = await showConfirmDialog(
        context,
        title: 'Remplacer ton programme actif ?',
        message: '« ${actif.nom} » sera mis en pause. Tu pourras le réactiver depuis Entraînement.',
        confirmLabel: 'Remplacer',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _adoption = true);
    try {
      await ProgramGenerator.adopter(p, profil, routines: context.read<RoutineRepo>(), programmes: programmes);
      propositionCourante.vider();
      if (!mounted) return;
      Toasts.success(context, 'Programme activé. Ta première séance t\'attend dans Entraînement.');
      context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() => _adoption = false);
        Toasts.error(context, 'Le programme n\'a pas pu être enregistré.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = propositionCourante.proposal;
    final wide = context.isExpanded;

    Widget corps;
    if (_erreur != null) {
      final sansProfil = _erreur is StateError && (_erreur as StateError).message == 'profil';
      final sansCatalogue = _erreur is StateError && (_erreur as StateError).message == 'catalogue';
      corps = EmptyState(
        icon: sansProfil ? Icons.person_off_rounded : Icons.error_outline_rounded,
        title: sansProfil ? 'Pas encore de profil' : (sansCatalogue ? 'Catalogue d\'exercices absent' : 'Programme impossible à calculer'),
        message: sansProfil
            ? 'Réponds d\'abord aux questions de l\'inscription.'
            : (sansCatalogue ? 'Le catalogue n\'a pas pu être chargé. Relance l\'appli.' : 'Une erreur est survenue pendant le calcul.'),
        actionLabel: sansProfil ? 'Commencer' : 'Réessayer',
        onAction: sansProfil ? () => context.go('/bienvenue') : () => _preparer(),
      );
    } else if (!_pret || p == null) {
      corps = const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 6));
    } else {
      final resume = _Resume(proposal: p, formules: ProgramGenerator.formulesPour(p.jours), onFormule: _changerFormule);
      final seances = _ListeSeances(proposal: p);
      corps = wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [resume])),
                VerticalDivider(width: 1, color: c.line),
                Expanded(child: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [seances])),
              ],
            )
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [resume, const SizedBox(height: 8), seances]);
    }

    return SubPageScaffold(
      title: 'Programme conseillé',
      subtitle: widget.premier ? 'Ton profil est prêt' : null,
      onBack: _quitter,
      closeIcon: widget.premier,
      maxContentWidth: wide ? 1100 : Breakpoints.content,
      actions: [
        if (_pret && p != null)
          IconButton(
            tooltip: 'Recalculer',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _changerFormule(p.formule),
          ),
      ],
      body: BottomActions(
      bar: _pret && p != null
          ? Row(children: [
              PillButton.ghost(label: 'Plus tard', onPressed: _adoption ? null : _quitter),
              const SizedBox(width: 8),
              Expanded(
                child: PillButton(
                  label: 'Adopter',
                  icon: Icons.check_rounded,
                  size: PillSize.large,
                  expand: true,
                  loading: _adoption,
                  onPressed: _adoption || p.seances.every((s) => s.exercices.isEmpty) ? null : _adopter,
                ),
              ),
            ])
          : null,
      body: corps,
      ),
    );
  }
}

class _Resume extends StatelessWidget {
  const _Resume({required this.proposal, required this.formules, required this.onFormule});

  final Proposal proposal;
  final List<Formule> formules;
  final ValueChanged<Formule> onFormule;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = proposal;
    final actif = context.watch<ProgramRepo>().active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepTitle(eyebrow: 'Conseillé pour toi', title: p.nom, subtitle: p.description),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(borderRadius: AppTokens.radius12, border: Border.all(color: c.line, width: 1.2)),
            child: Row(children: [
              for (final (l, v) in [
                ('Par semaine', Fmt.pluriel(p.jours, 'séance')),
                ('Durée', '${p.semaines} semaines'),
                ('Séries', '${p.nbSeries} / sem.'),
              ])
                Expanded(
                  child: Column(children: [
                    Text(l, style: AppType.rowSubtitle(color: c.text2)),
                    const SizedBox(height: 4),
                    Text(v, style: AppType.rowValue()),
                  ]),
                ),
            ]),
          ),
        ),
        if (formules.length > 1) ...[
          const SectionHeader(title: 'Découpage de la semaine'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
            child: Column(children: [
              for (final f in formules) ...[
                OptionCard(
                  title: f.label,
                  subtitle: f.description,
                  selected: f == p.formule,
                  onTap: () {
                    if (f != p.formule) onFormule(f);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ]),
          ),
        ],
        const SectionHeader(title: 'Pourquoi ce programme'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
          child: AppCard(
            child: Column(children: [
              for (final r in p.raisons)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.check_circle_rounded, size: 18, color: c.text),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 13.5))),
                  ]),
                ),
            ]),
          ),
        ),
        if (actif != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
            child: InfoNote(text: 'Il remplacera ton programme actif « ${actif.nom} », qui restera dans tes programmes.', icon: Icons.swap_horiz_rounded),
          ),
        ],
      ],
    );
  }
}

class _ListeSeances extends StatelessWidget {
  const _ListeSeances({required this.proposal});
  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<ExerciseRepo>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Les séances', trailing: LabelCount('cycle de ${proposal.seances.length}')),
        for (var i = 0; i < proposal.seances.length; i++)
          Builder(builder: (context) {
            final s = proposal.seances[i];
            final muscles = s.muscles(repo);
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 0, AppTokens.gutter, 10),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
                onTap: () => context.push('/bienvenue/programme/seance/$i'),
                child: Row(children: [
                  Container(
                    width: 64,
                    height: 84,
                    decoration: BoxDecoration(color: c.surface2, borderRadius: AppTokens.radius12),
                    alignment: Alignment.center,
                    child: IgnorePointer(
                      child: BodyMap(
                        height: 78,
                        view: _vuePrincipale(muscles),
                        intensities: {for (final m in muscles) m: 1.0},
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.nom, style: AppType.rowTitle()),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.pluriel(s.exercices.length, 'exercice')} · ${Fmt.pluriel(s.nbSeries, 'série')} · ${s.dureeEstimeeMin} min',
                        style: AppType.rowSubtitle(color: c.text2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.exercices.isEmpty ? 'Aucun exercice' : s.exercices.map((e) => repo.nameOf(e.exerciseId)).join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.rowSubtitle(),
                      ),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.text3),
                ]),
              ),
            );
          }),
      ],
    );
  }

  static BodyView _vuePrincipale(Set<Muscle> muscles) {
    final dos = muscles.where((m) => m.side == MuscleSide.dos).length;
    final face = muscles.where((m) => m.side == MuscleSide.face).length;
    return dos > face ? BodyView.back : BodyView.front;
  }
}
