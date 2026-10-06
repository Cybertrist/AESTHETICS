import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/env.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/permissions.dart';
import '../inscription_controller.dart';
import '../widgets/widgets.dart';
import 'steps_objectifs.dart';
import 'steps_profil.dart';

const _pad = EdgeInsets.symmetric(horizontal: AppTokens.gutter);

// ---------------------------------------------------------------- Nutrition

class NutritionStep extends StatelessWidget {
  const NutritionStep({super.key});

  void _modifier(InscriptionController ctrl, NutritionGoals Function(NutritionGoals g) change) {
    final base = ctrl.objectifsEffectifs;
    ctrl.set((d) {
      d.nutritionAuto = false;
      d.objectifsNutrition = change(base);
    });
  }

  /// Change une macro et recalcule les calories.
  NutritionGoals _macro(NutritionGoals g, {double? p, double? gl, double? l}) {
    final n = g.copyWith(proteinesG: p, glucidesG: gl, lipidesG: l);
    return n.copyWith(kcal: NutritionCalc.kcalDesMacros(proteines: n.proteinesG, glucides: n.glucidesG, lipides: n.lipidesG).roundToDouble());
  }

  /// Change les calories : les glucides absorbent l'écart.
  NutritionGoals _kcal(NutritionGoals g, double kcal) {
    final glucides = ((kcal - g.proteinesG * 4 - g.lipidesG * 9) / 4).clamp(0, 1500).roundToDouble();
    return g.copyWith(kcal: kcal, glucidesG: glucides);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final c = context.colors;
    final d = ctrl.draft;
    final p = d.toProfile();
    final g = ctrl.objectifsEffectifs;
    final bmr = NutritionCalc.metabolismeDeBase(sexe: p.sexe, poidsKg: p.poidsKg ?? 75, tailleCm: p.tailleCm ?? 175, age: p.age ?? 28);
    final tdee = NutritionCalc.depenseTotale(p);
    final ajust = NutritionCalc.ajustement(p.objectif);
    final kP = g.proteinesG * 4, kG = g.glucidesG * 4, kL = g.lipidesG * 9;
    final total = (kP + kG + kL).clamp(1, double.infinity);
    final protParKg = (p.poidsKg ?? 0) > 0 ? g.proteinesG / p.poidsKg! : null;
    final macro = <(String, double, Color, void Function(double))>[
      ('Protéines', g.proteinesG, c.text, (v) => _modifier(ctrl, (g) => _macro(g, p: v))),
      ('Glucides', g.glucidesG, c.text2, (v) => _modifier(ctrl, (g) => _macro(g, gl: v))),
      ('Lipides', g.lipidesG, c.text3, (v) => _modifier(ctrl, (g) => _macro(g, l: v))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(
          title: 'Tes objectifs nutritionnels',
          subtitle: 'Calculés d\'après ton profil et ton objectif. Ajuste-les si tu suis déjà un plan.',
        ),
        Padding(
          padding: _pad,
          child: AppCard(
            label: 'Chaque jour',
            labelTrailing: d.nutritionAuto
                ? TagPill('Calcul automatique', icon: Icons.auto_awesome_rounded, color: c.text2)
                : TagPill('Ajusté', icon: Icons.tune_rounded, color: c.text),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: BigNumber(value: Fmt.n(g.kcal, decimals: 0), unit: 'kcal', size: 44)),
                    RoundIconButton(
                      icon: Icons.edit_rounded,
                      filled: false,
                      tooltip: 'Saisir les calories',
                      onPressed: () async {
                        final v = await showNumberInputDialog(context, title: 'Calories par jour', initial: g.kcal, unit: 'kcal', decimal: false);
                        if (v == null) return;
                        if (v < 1000 || v > 6000) {
                          if (context.mounted) Toasts.error(context, 'Choisis entre 1 000 et 6 000 kcal.');
                          return;
                        }
                        _modifier(ctrl, (g) => _kcal(g, v));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SegmentedBar(parts: [(kP, c.text), (kG, c.text2), (kL, c.text3)]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    for (final (nom, v, col) in [('Protéines', kP, c.text), ('Glucides', kG, c.text2), ('Lipides', kL, c.text3)])
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('$nom ${(v / total * 100).round()} %', style: AppType.rowSubtitle(color: c.text2)),
                      ]),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: _pad,
          child: AppCard(
            label: 'Macronutriments',
            labelTrailing: protParKg == null ? null : LabelCount('${Fmt.n(protParKg, decimals: 1)} g de protéines par kg'),
            child: Column(
              children: [
                for (final (nom, v, col, set) in macro) ...[
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(nom, style: AppType.rowTitle())),
                      NumberStepper(value: v, step: 5, min: 0, max: 800, unit: 'g', compact: true, onChanged: set),
                    ],
                  ),
                  if (nom != 'Lipides') const SizedBox(height: 10),
                ],
                Divider(height: 28, color: c.line),
                Row(
                  children: [
                    IconHalo(icon: Icons.water_drop_rounded, size: 30),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Eau', style: AppType.rowTitle())),
                    NumberStepper(
                      value: g.eauMl.toDouble(),
                      step: 250,
                      min: 500,
                      max: 6000,
                      unit: 'ml',
                      compact: true,
                      onChanged: (v) => _modifier(ctrl, (g) => g.copyWith(eauMl: v.round())),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TileGroup(
          label: 'D\'où vient ce calcul',
          children: [
            ListTileX(title: 'Métabolisme de base', subtitle: 'Ce que ton corps brûle au repos', value: Fmt.kcal(bmr.round())),
            ListTileX(title: 'Dépense totale', subtitle: 'Avec ton quotidien : ${p.activite.label.toLowerCase()}', value: Fmt.kcal(tdee.round())),
            ListTileX(
              title: 'Ajustement',
              subtitle: p.objectif.label,
              value: '${ajust >= 0 ? '+' : ''}${Fmt.n(ajust, decimals: 0)} kcal',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!d.nutritionAuto)
          Padding(
            padding: _pad,
            child: PillButton.secondary(
              label: 'Revenir au calcul automatique',
              icon: Icons.restart_alt_rounded,
              expand: true,
              onPressed: () => ctrl.set((d) {
                d.nutritionAuto = true;
                d.objectifsNutrition = null;
              }),
            ),
          )
        else
          const Padding(
            padding: _pad,
            child: InfoNote(text: 'En calcul automatique, tes objectifs suivent ton poids : à chaque nouvelle pesée, ils se mettent à jour.'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Historique

class HistoriqueStep extends StatelessWidget {
  const HistoriqueStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<InscriptionController>();
    final sessions = context.watch<SessionRepo>().sessions;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(
          title: 'Reprendre mon historique',
          subtitle: 'Tu notais déjà tes séances ailleurs ? Importe-les pour garder tes records et tes courbes.',
        ),
        Padding(
          padding: _pad,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconHalo(icon: Icons.upload_file_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Importer depuis une autre application (CSV)', style: AppType.rowTitle()),
                      const SizedBox(height: 2),
                      Text('Exporte ton historique en CSV depuis ton ancienne appli, puis choisis le fichier.', style: AppType.rowSubtitle()),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                for (final (ic, t) in [
                  (Icons.fact_check_rounded, 'Les exercices sont reconnus, tu confirmes ceux qui sont douteux'),
                  (Icons.content_copy_rounded, 'Les séances déjà présentes ne sont pas doublées'),
                  (Icons.emoji_events_rounded, 'Tes records sont recalculés'),
                ]) ...[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(ic, size: 18, color: c.text3),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t, style: AppType.rowSubtitle(color: c.text2))),
                  ]),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                PillButton(
                  label: sessions.isEmpty ? 'Choisir un fichier' : 'Importer un autre fichier',
                  icon: Icons.upload_file_rounded,
                  expand: true,
                  onPressed: () async {
                    await ctrl.sauver();
                    if (context.mounted) await context.push('${Paths.import}?retour=${Paths.bienvenue}/profil');
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (sessions.isNotEmpty)
          Padding(
            padding: _pad,
            child: AppCard(
              border: true,
              borderColor: c.success.withValues(alpha: 0.35),
              child: Row(children: [
                IconHalo(icon: Icons.check_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${Fmt.pluriel(sessions.length, 'séance')} dans ton historique', style: AppType.rowTitle()),
                    Text('Du ${Fmt.date(sessions.last.debut)} au ${Fmt.date(sessions.first.debut)}', style: AppType.rowSubtitle()),
                  ]),
                ),
              ]),
            ),
          )
        else
          const Padding(
            padding: _pad,
            child: InfoNote(text: 'Pas d\'historique ? Passe cette étape : tu pourras importer plus tard depuis ton profil.'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Autorisations

class AutorisationsStep extends StatefulWidget {
  const AutorisationsStep({super.key});

  @override
  State<AutorisationsStep> createState() => _AutorisationsStepState();
}

class _AutorisationsStepState extends State<AutorisationsStep> with WidgetsBindingObserver {
  EtatAutorisation? _sante;
  EtatAutorisation? _notif;
  bool _santeEnCours = false;
  bool _notifEnCours = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifier();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Retour des réglages du téléphone : on relit les états.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verifier();
  }

  Future<void> _verifier() async {
    final s = await Autorisations.etatSante();
    final n = await Autorisations.etatNotifications();
    if (!mounted) return;
    final ctrl = context.read<InscriptionController>();
    setState(() {
      _sante = s;
      _notif = n;
    });
    if (s == EtatAutorisation.accordee && !ctrl.draft.santeConnectee) ctrl.set((d) => d.santeConnectee = true);
  }

  Future<void> _demanderSante() async {
    final ctrl = context.read<InscriptionController>();
    if (_sante == EtatAutorisation.indisponible) {
      await Autorisations.installerSante();
      return;
    }
    setState(() => _santeEnCours = true);
    final r = await Autorisations.demanderSante();
    if (!mounted) return;
    setState(() {
      _sante = r;
      _santeEnCours = false;
    });
    ctrl.set((d) => d.santeConnectee = r == EtatAutorisation.accordee);
    if (r == EtatAutorisation.refusee) Toasts.show(context, 'Refusé. Tu pourras l\'activer plus tard dans les réglages.');
  }

  Future<void> _basculerRappels(bool on) async {
    final ctrl = context.read<InscriptionController>();
    if (!on) {
      ctrl.set((d) => d.rappels = false);
      return;
    }
    if (_notif == EtatAutorisation.bloquee) {
      final ok = await showConfirmDialog(
        context,
        title: 'Notifications bloquées',
        message: 'Tu les as refusées pour Aesthetics. Ouvre les réglages du téléphone pour les autoriser.',
        confirmLabel: 'Ouvrir les réglages',
        icon: Icons.notifications_off_rounded,
      );
      if (ok) await Autorisations.ouvrirReglages();
      return;
    }
    setState(() => _notifEnCours = true);
    final r = _notif == EtatAutorisation.accordee ? EtatAutorisation.accordee : await Autorisations.demanderNotifications();
    if (!mounted) return;
    setState(() {
      _notif = r;
      _notifEnCours = false;
    });
    final accorde = r == EtatAutorisation.accordee || r == EtatAutorisation.indisponible;
    ctrl.set((d) => d.rappels = accorde);
    if (!accorde) Toasts.show(context, 'Sans autorisation, pas de rappel. Tu pourras changer d\'avis plus tard.');
  }

  Future<void> _heure() async {
    final ctrl = context.read<InscriptionController>();
    final parts = ctrl.draft.heureRappel.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(parts.first) ?? 18, minute: int.tryParse(parts.last) ?? 0),
      helpText: 'Heure du rappel',
    );
    if (t == null) return;
    ctrl.set((d) => d.heureRappel = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  Widget _etat(EtatAutorisation? e, {required bool actif}) {
    final c = context.colors;
    return switch (e) {
      null => const Skeleton(width: 80, height: 22),
      EtatAutorisation.accordee when actif => TagPill('Autorisé', icon: Icons.check_rounded, color: c.success),
      EtatAutorisation.bloquee => TagPill('Bloqué', icon: Icons.block_rounded, color: c.error),
      EtatAutorisation.indisponible => TagPill('Indisponible', icon: Icons.info_outline_rounded, color: c.text3),
      _ => TagPill('Pas encore', color: c.text3),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final c = context.colors;
    final d = ctrl.draft;
    final jours = (d.jours.toList()..sort()).map((j) => joursNoms[j - 1]).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepTitle(
          title: Env.muscuSeule ? 'Tes rappels' : 'Deux autorisations',
          subtitle: Env.muscuSeule
              ? 'Facultatif. Une notification les jours de séance, rien de plus.'
              : 'Toutes les deux sont facultatives. Voici exactement à quoi elles servent.',
        ),
        // Health Connect parle de sommeil, de pas et de calories : rangé avec le reste.
        if (!Env.muscuSeule) ...[
        Padding(
          padding: _pad,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconHalo(icon: Icons.monitor_heart_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Health Connect', style: AppType.rowTitle()),
                      Text('Relie ta montre et tes autres applis santé', style: AppType.rowSubtitle()),
                    ]),
                  ),
                  _etat(_sante, actif: d.santeConnectee || _sante == EtatAutorisation.accordee),
                ]),
                const SizedBox(height: 14),
                Text('AESTHETICS LIRA', style: AppType.overline()),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final (ic, t) in [
                    (Icons.directions_walk_rounded, 'Pas'),
                    (Icons.monitor_weight_rounded, 'Poids et masse grasse'),
                    (Icons.bedtime_rounded, 'Sommeil'),
                    (Icons.favorite_rounded, 'Fréquence cardiaque'),
                    (Icons.local_fire_department_rounded, 'Calories dépensées'),
                  ])
                    TagPill(t, icon: ic, color: c.text2),
                ]),
                const SizedBox(height: 12),
                Text('AESTHETICS ÉCRIRA', style: AppType.overline()),
                const SizedBox(height: 8),
                TagPill('Tes séances terminées', icon: Icons.fitness_center_rounded, color: c.text2),
                const SizedBox(height: 12),
                Text('Rien ne quitte ton téléphone.', style: AppType.rowSubtitle(color: c.text2)),
                const SizedBox(height: 14),
                if (_sante == EtatAutorisation.accordee)
                  PillButton(label: 'Health Connect est relié', icon: Icons.check_rounded, variant: PillVariant.outline, expand: true, onPressed: null)
                else
                  PillButton(
                    label: _sante == EtatAutorisation.indisponible
                        ? (Autorisations.plateformeMobile ? 'Installer Health Connect' : 'Disponible sur le téléphone')
                        : 'Autoriser Health Connect',
                    icon: _sante == EtatAutorisation.indisponible ? Icons.download_rounded : Icons.link_rounded,
                    expand: true,
                    loading: _santeEnCours,
                    onPressed: _sante == null || (_sante == EtatAutorisation.indisponible && !Autorisations.plateformeMobile) ? null : _demanderSante,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ],
        Padding(
          padding: _pad,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconHalo(icon: Icons.notifications_active_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Rappels d\'entraînement', style: AppType.rowTitle()),
                      Text('Une notification les jours de séance', style: AppType.rowSubtitle()),
                    ]),
                  ),
                  if (_notifEnCours)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                  else
                    Switch(value: d.rappels, onChanged: _notif == null ? null : _basculerRappels),
                ]),
                if (d.rappels) ...[
                  // L'heure et les jours : deux lignes aérées, séparées par un
                  // filet, leurs icônes alignées sous la cloche.
                  const SizedBox(height: 14),
                  Divider(height: 1, thickness: 1, color: c.surface2),
                  InkWell(
                    onTap: _heure,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(children: [
                        SizedBox(width: 44, child: Icon(Icons.schedule_rounded, size: 24, color: c.text2)),
                        const SizedBox(width: 14),
                        Expanded(child: Text('Heure', style: AppType.rowTitle())),
                        Text(d.heureRappel.replaceAll(':', ' h '), style: AppType.rowTitle()),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 22, color: c.text2),
                      ]),
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: c.surface2),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 44, child: Icon(Icons.event_repeat_rounded, size: 24, color: c.text2)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Jours', style: AppType.rowTitle()),
                          const SizedBox(height: 3),
                          Text(jours.isEmpty ? 'Aucun jour choisi' : 'Le $jours', style: AppType.rowSubtitle()),
                        ]),
                      ),
                    ]),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Text('Pas de publicité, pas de relance : seulement tes jours de séance, à l\'heure choisie.', style: AppType.rowSubtitle(color: c.text2)),
                ],
                if (_notif == EtatAutorisation.bloquee) ...[
                  const SizedBox(height: 10),
                  AccentLink(label: 'Ouvrir les réglages du téléphone', icon: Icons.open_in_new_rounded, onTap: Autorisations.ouvrirReglages),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Récapitulatif

/// Récapitulatif des réponses, chaque ligne rouvre l'étape correspondante.
class Recapitulatif extends StatelessWidget {
  const Recapitulatif({super.key, required this.onEdit, this.titre = true});

  final ValueChanged<Etape> onEdit;
  final bool titre;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final c = context.colors;
    final d = ctrl.draft;
    final p = d.toProfile();
    final g = ctrl.objectifsEffectifs;
    final manque = ctrl.premiereIncomplete;
    String ou(String? v) => v == null || v.isEmpty ? 'À compléter' : v;
    ListTileX ligne(Etape e, String titre, String? valeur, {String? sous}) => ListTileX(
          title: titre,
          subtitle: sous,
          value: ou(valeur),
          valueColor: valeur == null ? c.warning : null,
          showChevron: true,
          onTap: () => onEdit(e),
        );
    final jours = (d.jours.toList()..sort()).map((j) => joursCourts[j - 1]).join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titre)
          StepTitle(
            eyebrow: 'Presque fini',
            title: d.prenom.trim().isEmpty ? 'Tout est bon ?' : 'Tout est bon, ${d.prenom.trim()} ?',
            subtitle: 'Touche une ligne pour la corriger. Tu pourras tout modifier plus tard depuis ton profil.',
          ),
        if (manque != null) ...[
          Padding(
            padding: _pad,
            child: AppCard(
              onTap: () => onEdit(manque),
              border: true,
              borderColor: c.warning.withValues(alpha: 0.4),
              child: Row(children: [
                IconHalo(icon: Icons.warning_amber_rounded),
                const SizedBox(width: 14),
                Expanded(child: Text('Il manque une réponse : ${manque.label.toLowerCase()}.', style: AppType.rowTitle())),
                Icon(Icons.chevron_right_rounded, color: c.text3),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TileGroup(label: 'Toi', children: [
          ligne(Etape.prenom, 'Prénom', d.prenom.trim().isEmpty ? null : d.prenom.trim()),
          ligne(Etape.sexe, 'Sexe', d.sexe?.label),
          ligne(Etape.naissance, 'Âge', d.age == null ? null : '${d.age} ans'),
          ligne(Etape.taille, 'Taille', d.tailleCm == null ? null : tailleTexte(d.tailleCm!, d.uniteTaille)),
          ligne(Etape.poids, 'Poids', d.poidsKg == null ? null : Fmt.poids(d.poidsKg, d.unitePoids),
              sous: d.poidsCibleKg == null ? null : 'Objectif : ${Fmt.poids(d.poidsCibleKg, d.unitePoids)}'),
        ]),
        const SizedBox(height: 12),
        TileGroup(label: 'Ton but', children: [
          ligne(Etape.objectif, 'Objectif', d.objectif?.label),
          ligne(Etape.niveau, 'Niveau', d.niveau?.label),
          if (Etape.parcours.contains(Etape.activite)) ligne(Etape.activite, 'Quotidien', d.activite?.label),
        ]),
        const SizedBox(height: 12),
        TileGroup(label: 'Entraînement', children: [
          ligne(Etape.frequence, 'Semaine type', d.jours.isEmpty ? null : '${d.jours.length} × ${d.dureeSeanceMin} min', sous: jours),
          ligne(Etape.materiel, 'Matériel', d.materiel.isEmpty ? null : (d.materielPreset?.label ?? 'Sur mesure'),
              sous: d.materiel.contains(Materiel.salleComplete) ? null : d.materiel.map((m) => m.label).join(', ')),
          ligne(Etape.muscles, 'Priorités', d.muscles.isEmpty ? 'Équilibré' : '${d.muscles.length}',
              sous: d.muscles.isEmpty ? null : d.muscles.map((m) => m.label).join(', ')),
        ]),
        const SizedBox(height: 12),
        if (Etape.parcours.contains(Etape.nutrition)) ...[
        TileGroup(label: 'Nutrition', children: [
          ligne(Etape.nutrition, 'Calories', Fmt.kcal(g.kcal), sous: 'P ${g.proteinesG.round()} g · G ${g.glucidesG.round()} g · L ${g.lipidesG.round()} g'),
        ]),
        const SizedBox(height: 12),
        ],
        TileGroup(label: Env.muscuSeule ? 'Rappels' : 'Connexions', children: [
          if (!Env.muscuSeule) ligne(Etape.autorisations, 'Health Connect', d.santeConnectee ? 'Relié' : 'Non'),
          ligne(Etape.autorisations, 'Rappels', d.rappels ? d.heureRappel.replaceAll(':', ' h ') : 'Non'),
        ]),
        if (p.prenom.isNotEmpty) const SizedBox(height: 4),
      ],
    );
  }
}
