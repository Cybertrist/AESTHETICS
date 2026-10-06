import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/env.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../data/draft.dart';
import '../inscription_controller.dart';
import '../widgets/widgets.dart';

const _pad = EdgeInsets.symmetric(horizontal: AppTokens.gutter);

IconData iconeObjectif(Objectif o) => switch (o) {
      Objectif.prendreDuMuscle => Icons.fitness_center_rounded,
      Objectif.secher => Icons.local_fire_department_rounded,
      Objectif.recomposition => Icons.autorenew_rounded,
      Objectif.force => Icons.bolt_rounded,
      Objectif.forme => Icons.favorite_rounded,
    };

IconData iconeMateriel(Materiel m) => switch (m) {
      Materiel.salleComplete => Icons.store_rounded,
      Materiel.barre => Icons.fitness_center_rounded,
      Materiel.halteres => Icons.fitness_center_rounded,
      Materiel.banc => Icons.chair_alt_rounded,
      Materiel.barreTraction => Icons.horizontal_rule_rounded,
      Materiel.kettlebell => Icons.sports_handball_rounded,
      Materiel.elastiques => Icons.gesture_rounded,
      Materiel.poidsDuCorps => Icons.accessibility_new_rounded,
    };

IconData iconePreset(MaterielPreset p) => switch (p) {
      MaterielPreset.salle => Icons.store_rounded,
      MaterielPreset.halteres => Icons.fitness_center_rounded,
      MaterielPreset.maison => Icons.home_rounded,
      MaterielPreset.poidsDuCorps => Icons.accessibility_new_rounded,
      MaterielPreset.surMesure => Icons.tune_rounded,
    };

const joursCourts = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const joursNoms = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

// ---------------------------------------------------------------- Objectif

class ObjectifStep extends StatelessWidget {
  const ObjectifStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final d = ctrl.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(
          title: 'Ton objectif principal',
          subtitle: Env.muscuSeule
              ? 'Il règle tes séries, tes répétitions et tes repos. Tu pourras en changer quand tu veux.'
              : 'Il règle tes séries, tes répétitions, tes repos et tes calories. Tu pourras en changer quand tu veux.',
        ),
        Padding(
          padding: _pad,
          child: OptionGrid(children: [
            for (final o in Objectif.values)
              OptionCard(
                title: o.label,
                subtitle: o.description,
                icon: iconeObjectif(o),
                selected: d.objectif == o,
                onTap: () => ctrl.set((d) => d.objectif = o),
              ),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Niveau

class NiveauStep extends StatelessWidget {
  const NiveauStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final d = ctrl.draft;
    IconData icone(Niveau n) => switch (n) {
          Niveau.debutant => Icons.signal_cellular_alt_1_bar_rounded,
          Niveau.intermediaire => Icons.signal_cellular_alt_2_bar_rounded,
          Niveau.avance => Icons.signal_cellular_alt_rounded,
        };
    String detail(Niveau n) => switch (n) {
          Niveau.debutant => '${n.description}. On commence par les bases.',
          Niveau.intermediaire => '${n.description}. Tu connais les grands mouvements.',
          Niveau.avance => '${n.description}. Tu progresses lentement, il faut du volume.',
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(title: 'Ton niveau en musculation', subtitle: 'Sois honnête : il décide du volume de départ.'),
        Padding(
          padding: _pad,
          child: Column(children: [
            for (final n in Niveau.values) ...[
              OptionCard(
                title: n.label,
                subtitle: detail(n),
                icon: icone(n),
                selected: d.niveau == n,
                onTap: () => ctrl.set((d) => d.niveau = n),
              ),
              const SizedBox(height: 10),
            ],
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Activité

class ActiviteStep extends StatelessWidget {
  const ActiviteStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final d = ctrl.draft;
    IconData icone(NiveauActivite a) => switch (a) {
          NiveauActivite.sedentaire => Icons.weekend_rounded,
          NiveauActivite.leger => Icons.directions_walk_rounded,
          NiveauActivite.modere => Icons.hiking_rounded,
          NiveauActivite.actif => Icons.directions_run_rounded,
          NiveauActivite.tresActif => Icons.sports_martial_arts_rounded,
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(
          title: 'Ton quotidien',
          subtitle: 'En dehors des séances : ton travail, tes trajets, ton sport. Il compte beaucoup dans tes besoins.',
        ),
        Padding(
          padding: _pad,
          child: Column(children: [
            for (final a in NiveauActivite.values) ...[
              OptionCard(
                title: a.label,
                subtitle: a.description,
                icon: icone(a),
                selected: d.activite == a,
                onTap: () => ctrl.set((d) => d.activite = a),
              ),
              const SizedBox(height: 10),
            ],
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Fréquence

class FrequenceStep extends StatelessWidget {
  const FrequenceStep({super.key});

  static int exercicesPour(int min) => switch (min) {
        <= 30 => 4,
        <= 45 => 5,
        <= 60 => 6,
        <= 75 => 7,
        _ => 8,
      };

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final c = context.colors;
    final d = ctrl.draft;
    final n = d.jours.length;
    final conseil = switch (d.niveau) {
      Niveau.debutant => 'Pour débuter, 3 séances par semaine suffisent largement.',
      Niveau.avance => 'À ton niveau, 4 à 6 séances permettent de travailler chaque muscle deux fois.',
      _ => '3 à 5 séances par semaine, c\'est le bon rythme pour progresser.',
    };
    final jours = (d.jours.toList()..sort()).map((j) => joursNoms[j - 1]).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(title: 'Ta semaine type', subtitle: 'Choisis tes jours d\'entraînement et le temps que tu as par séance.'),
        Padding(
          padding: _pad,
          child: AppCard(
            label: 'Jours d\'entraînement',
            labelTrailing: LabelCount(n == 0 ? 'aucun' : '$n par semaine'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(builder: (context, box) {
                  final taille = ((box.maxWidth - 6 * 6) / 7).clamp(34.0, 52.0);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var j = 1; j <= 7; j++)
                        _Jour(
                          lettre: joursCourts[j - 1],
                          nom: joursNoms[j - 1],
                          taille: taille,
                          choisi: d.jours.contains(j),
                          onTap: () => ctrl.set((d) {
                            d.jours = {...d.jours};
                            d.jours.contains(j) ? d.jours.remove(j) : d.jours.add(j);
                          }),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 14),
                Text(
                  n == 0 ? 'Choisis au moins un jour.' : 'Le ${jours.join(', ').replaceFirst(RegExp(r', (?=[^,]*$)'), ' et ')}.',
                  style: AppType.rowSubtitle(color: n == 0 ? c.warning : c.text2),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in [2, 3, 4, 5, 6])
                      ChipFilter(
                        label: '$k jours',
                        selected: n == k,
                        onTap: () => ctrl.set((d) => d.jours = Draft.joursParDefaut(k)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(padding: _pad, child: InfoNote(text: conseil, icon: Icons.lightbulb_rounded)),
        const SizedBox(height: 12),
        Padding(
          padding: _pad,
          child: AppCard(
            label: 'Durée d\'une séance',
            labelTrailing: LabelCount('${exercicesPour(d.dureeSeanceMin)} exercices environ'),
            child: SegmentedChips<int>(
              segments: const [(30, '30 min'), (45, '45 min'), (60, '1 h'), (75, '1 h 15'), (90, '1 h 30')],
              value: d.dureeSeanceMin,
              onChanged: (v) => ctrl.set((d) => d.dureeSeanceMin = v),
            ),
          ),
        ),
      ],
    );
  }
}

class _Jour extends StatelessWidget {
  const _Jour({required this.lettre, required this.nom, required this.taille, required this.choisi, required this.onTap});

  final String lettre;
  final String nom;
  final double taille;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: nom,
      selected: choisi,
      button: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppTokens.fast,
          width: taille,
          height: taille,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: choisi ? c.bouton : c.surface3,
            border: Border.all(color: choisi ? c.bouton : c.line),
          ),
          child: Text(lettre, style: AppType.rowTitle(color: choisi ? c.onBouton : c.text2).copyWith(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Matériel

class MaterielStep extends StatelessWidget {
  const MaterielStep({super.key});

  static const _details = [
    Materiel.barre,
    Materiel.halteres,
    Materiel.banc,
    Materiel.barreTraction,
    Materiel.kettlebell,
    Materiel.elastiques,
    Materiel.poidsDuCorps,
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final d = ctrl.draft;
    const presets = MaterielPreset.values;
    final salle = d.materiel.contains(Materiel.salleComplete);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(title: 'Où t\'entraînes-tu ?', subtitle: 'Les exercices proposés s\'adaptent à ce que tu as sous la main.'),
        Padding(
          padding: _pad,
          child: OptionGrid(children: [
            for (final p in presets)
              OptionCard(
                title: p.label,
                subtitle: p.description,
                icon: iconePreset(p),
                selected: d.materielPreset == p,
                onTap: () => ctrl.set((d) {
                  d.materielPreset = p;
                  d.materiel = {...p.materiel};
                }),
              ),
          ]),
        ),
        if (d.materielPreset != null && !salle) ...[
          const SizedBox(height: 16),
          Padding(
            padding: _pad,
            child: AppCard(
              label: 'Précisément, j\'ai',
              labelTrailing: d.materielPreset == MaterielPreset.surMesure ? const LabelCount('sur mesure') : null,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in _details)
                    ChipFilter(
                      label: m.label,
                      icon: iconeMateriel(m),
                      selected: d.materiel.contains(m),
                      onTap: () => ctrl.set((d) {
                        d.materiel = {...d.materiel};
                        d.materiel.contains(m) ? d.materiel.remove(m) : d.materiel.add(m);
                        final correspond = MaterielPreset.values.where((p) => p != MaterielPreset.surMesure && p.materiel.length == d.materiel.length && p.materiel.containsAll(d.materiel));
                        d.materielPreset = correspond.isEmpty ? MaterielPreset.surMesure : correspond.first;
                      }),
                    ),
                ],
              ),
            ),
          ),
          if (d.materiel.isEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: _pad,
              child: InfoNote(text: 'Choisis au moins une ligne, ne serait-ce que le poids du corps.', icon: Icons.warning_amber_rounded),
            ),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Muscles prioritaires

/// Zones proposées en grand, comme des raccourcis vers plusieurs muscles.
enum ZoneMuscles {
  pectoraux('Pectoraux', {Muscle.pectoraux}, BodyView.front, 0.28, 3.2),
  dos('Dos', {Muscle.grandDorsal, Muscle.rhomboides, Muscle.trapezes}, BodyView.back, 0.31, 2.6),
  epaules('Épaules', {Muscle.deltoidesAnterieurs, Muscle.deltoidesLateraux, Muscle.deltoidesPosterieurs}, BodyView.front, 0.25, 2.9),
  bras('Bras', {Muscle.biceps, Muscle.triceps}, BodyView.front, 0.33, 2.2),
  abdos('Abdos', {Muscle.abdominaux, Muscle.obliques}, BodyView.front, 0.4, 3.0),
  jambes('Jambes', {Muscle.quadriceps, Muscle.ischios}, BodyView.front, 0.67, 1.6),
  fessiers('Fessiers', {Muscle.fessiers}, BodyView.back, 0.5, 2.9),
  mollets('Mollets', {Muscle.mollets}, BodyView.back, 0.8, 2.3);

  const ZoneMuscles(this.label, this.muscles, this.vue, this.centreY, this.zoom);
  final String label;
  final Set<Muscle> muscles;
  final BodyView vue;

  /// Hauteur du centre de la vignette dans le personnage (0 tête, 1 pieds).
  final double centreY;

  /// Hauteur du personnage rapportée à celle de la vignette.
  final double zoom;
}

/// Vignette ronde du personnage cadrée sur une zone, muscles en rouge.
class MuscleVignette extends StatelessWidget {
  const MuscleVignette({super.key, required this.zone, required this.size});

  final ZoneMuscles zone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final h = size * zone.zoom;
    final w = h * BodyMap.aspectRatio;
    return Container(
      width: size,
      height: size,
      color: context.colors.surface2,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: (size - w) / 2,
            top: size / 2 - zone.centreY * h,
            width: w,
            height: h,
            child: IgnorePointer(child: BodyMap(view: zone.vue, height: h, intensities: {for (final m in zone.muscles) m: 1.0})),
          ),
        ],
      ),
    );
  }
}

class MusclesStep extends StatelessWidget {
  const MusclesStep({super.key});

  static const max = 8;

  void _changer(BuildContext context, InscriptionController ctrl, Set<Muscle> ajout, Set<Muscle> retrait) {
    final d = ctrl.draft;
    final nouveau = {...d.muscles}
      ..removeAll(retrait)
      ..addAll(ajout);
    if (nouveau.length > max && nouveau.length > d.muscles.length) {
      Toasts.show(context, 'Huit muscles au plus : au-delà, plus rien n\'est prioritaire.');
      return;
    }
    ctrl.set((d) => d.muscles = nouveau);
  }

  void _basculer(BuildContext context, InscriptionController ctrl, Muscle m) {
    final dedans = ctrl.draft.muscles.contains(m);
    _changer(context, ctrl, dedans ? {} : {m}, dedans ? {m} : {});
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final c = context.colors;
    final d = ctrl.draft;
    final hauteur = (MediaQuery.sizeOf(context).height * 0.4).clamp(260.0, 420.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(
          title: 'Des zones à faire ressortir ?',
          subtitle: 'Elles recevront une série de plus. Laisse vide pour un programme équilibré.',
        ),
        Padding(
          padding: _pad,
          child: RoundChoiceGrid(
            itemCount: ZoneMuscles.values.length,
            itemBuilder: (context, i, size) {
              final z = ZoneMuscles.values[i];
              final choisi = d.muscles.containsAll(z.muscles);
              return RoundChoice(
                label: z.label,
                size: size,
                selected: choisi,
                onTap: () => _changer(context, ctrl, choisi ? {} : z.muscles, choisi ? z.muscles : {}),
                child: MuscleVignette(zone: z, size: size),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: _pad,
          child: AppCard(
            label: 'Muscle par muscle',
            labelTrailing: LabelCount(d.muscles.isEmpty ? 'équilibré' : '${d.muscles.length} sur $max'),
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
            child: Column(
              children: [
                Text('Touche un muscle sur le personnage pour l\'ajouter ou le retirer.', style: AppType.rowSubtitle(color: c.text2), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Center(
                  child: LayoutBuilder(
                    builder: (context, box) => TouchBodyDual(
                      height: hauteur.clamp(120.0, (box.maxWidth - 8) / 2 / BodyMap.aspectRatio),
                      intensities: {for (final m in d.muscles) m: 1.0},
                      onTap: (m) => _basculer(context, ctrl, m),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final m in Muscle.values)
                      ChipFilter(label: m.label, selected: d.muscles.contains(m), onTap: () => _basculer(context, ctrl, m)),
                  ],
                ),
                if (d.muscles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AccentLink(label: 'Tout retirer', onTap: () => ctrl.set((d) => d.muscles = {})),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Face et dos touchables. Le toucher est lu ici dans les masques du
/// personnage (le `onTap` de `BodyMap` est signalé en demande au socle).
class TouchBodyDual extends StatelessWidget {
  const TouchBodyDual({super.key, required this.height, required this.intensities, required this.onTap});

  final double height;
  final Map<Muscle, double> intensities;
  final ValueChanged<Muscle> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget une(BodyView v) {
      final w = height * BodyMap.aspectRatio;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) async {
            final imgs = BodyImageRepository.peek(v, BodyFraming.corps) ?? await BodyImageRepository.load(v, BodyFraming.corps);
            // Image posée en BoxFit.contain dans la zone, comme dans BodyMap.
            final zone = Size(w, height);
            final s = (zone.width / imgs.size.width) < (zone.height / imgs.size.height) ? zone.width / imgs.size.width : zone.height / imgs.size.height;
            final iw = imgs.size.width * s, ih = imgs.size.height * s;
            final r = Rect.fromLTWH((zone.width - iw) / 2, (zone.height - ih) / 2, iw, ih);
            final f = Offset((d.localPosition.dx - r.left) / r.width, (d.localPosition.dy - r.top) / r.height);
            if (f.dx < 0 || f.dy < 0 || f.dx > 1 || f.dy > 1) return;
            final m = await BodyImageRepository.hitTest(imgs, f);
            if (m != null) {
              HapticFeedback.selectionClick();
              onTap(m);
            }
          },
          child: SizedBox(width: w, height: height, child: BodyMap(view: v, height: height, intensities: intensities)),
        ),
        const SizedBox(height: 6),
        Text(v == BodyView.front ? 'Face' : 'Dos', style: AppType.rowSubtitle(color: c.text3)),
      ]);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [une(BodyView.front), const SizedBox(width: 8), une(BodyView.back)]);
  }
}
