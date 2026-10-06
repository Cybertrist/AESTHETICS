import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/draft.dart';
import '../inscription_controller.dart';
import '../widgets/widgets.dart';

const _pad = EdgeInsets.symmetric(horizontal: AppTokens.gutter);

/// Taille lisible dans l'unité choisie.
String tailleTexte(double cm, UniteTaille u) {
  if (u == UniteTaille.cm) return '${cm.round()} cm';
  final pouces = (cm / 2.54).round();
  return '${pouces ~/ 12}\' ${pouces % 12}"';
}

// ---------------------------------------------------------------- Prénom

class PrenomStep extends StatefulWidget {
  const PrenomStep({super.key, this.onSubmit});
  final VoidCallback? onSubmit;

  @override
  State<PrenomStep> createState() => _PrenomStepState();
}

class _PrenomStepState extends State<PrenomStep> {
  late final TextEditingController _ctrl;
  bool _photoEnCours = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: context.read<InscriptionController>().draft.prenom);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    final ctrl = context.read<InscriptionController>();
    final store = context.read<Store>();
    final choix = await showChoiceDialog<String>(
      context,
      title: 'Photo de profil',
      options: [
        ('camera', 'Prendre une photo'),
        ('galerie', 'Choisir dans la galerie'),
        if (ctrl.draft.photo != null) ('retirer', 'Retirer la photo'),
      ],
    );
    if (choix == null || !mounted) return;
    if (choix == 'retirer') {
      ctrl.set((d) => d.photo = null);
      return;
    }
    setState(() => _photoEnCours = true);
    try {
      final x = await ImagePicker().pickImage(
        source: choix == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 88,
      );
      if (x == null) return;
      final dir = await store.mediaDir();
      final dest = '${dir.path}${Platform.pathSeparator}profil_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(x.path).copy(dest);
      ctrl.set((d) => d.photo = dest);
    } catch (_) {
      if (mounted) Toasts.error(context, 'Impossible de récupérer la photo.');
    } finally {
      if (mounted) setState(() => _photoEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final c = context.colors;
    final d = ctrl.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(
          eyebrow: 'Faisons connaissance',
          title: 'Comment tu t\'appelles ?',
          subtitle: 'Ton prénom sert à te saluer, rien de plus. Tout reste sur ton téléphone.',
        ),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: _photoEnCours ? null : _photo,
                child: _photoEnCours
                    ? const Skeleton.circle(size: 96)
                    : d.photo != null && File(d.photo!).existsSync()
                        ? CircleAvatar(radius: 48, backgroundImage: FileImage(File(d.photo!)))
                        : Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(color: c.surface3, shape: BoxShape.circle, border: Border.all(color: c.line)),
                            alignment: Alignment.center,
                            child: d.prenom.trim().isEmpty
                                ? Icon(Icons.person_rounded, size: 44, color: c.text3)
                                : Text(d.prenom.trim()[0].toUpperCase(), style: AppType.number(40)),
                          ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: RoundIconButton(icon: Icons.photo_camera_rounded, size: 36, onPressed: _photoEnCours ? null : _photo, tooltip: 'Photo de profil'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text('Photo facultative', style: AppType.rowSubtitle())),
        const SizedBox(height: 24),
        Padding(
          padding: _pad,
          child: TextField(
            controller: _ctrl,
            autofocus: d.prenom.isEmpty,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: 30,
            style: AppType.rowTitle().copyWith(fontSize: 20),
            decoration: const InputDecoration(hintText: 'Ton prénom', counterText: '', prefixIcon: Icon(Icons.badge_rounded)),
            onChanged: (v) => ctrl.set((d) => d.prenom = v),
            onSubmitted: (_) {
              if (ctrl.valide(Etape.prenom)) widget.onSubmit?.call();
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Sexe

class SexeStep extends StatelessWidget {
  const SexeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final d = ctrl.draft;
    final prenom = d.prenom.trim();
    IconData icone(Sexe s) => switch (s) {
          Sexe.homme => Icons.male_rounded,
          Sexe.femme => Icons.female_rounded,
          Sexe.autre => Icons.transgender_rounded,
        };
    String detail(Sexe s) => switch (s) {
          Sexe.homme => 'Calcul des besoins pour un homme',
          Sexe.femme => 'Calcul des besoins pour une femme',
          Sexe.autre => 'Moyenne des deux formules',
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepTitle(
          eyebrow: prenom.isEmpty ? null : 'Enchanté, $prenom',
          title: 'Ton sexe',
          subtitle: 'Il change le calcul de ta dépense d\'énergie et le personnage affiché.',
        ),
        Padding(
          padding: _pad,
          child: OptionGrid(children: [
            for (final s in Sexe.values)
              OptionCard(
                title: s == Sexe.autre ? 'Autre, ou je préfère ne pas le dire' : s.label,
                subtitle: detail(s),
                icon: icone(s),
                selected: d.sexe == s,
                onTap: () => ctrl.set((d) => d.sexe = s),
              ),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Naissance

const _moisNoms = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

class NaissanceStep extends StatefulWidget {
  const NaissanceStep({super.key});

  @override
  State<NaissanceStep> createState() => _NaissanceStepState();
}

class _NaissanceStepState extends State<NaissanceStep> {
  late final int _anneeMax = DateTime.now().year - 13;
  late final int _anneeMin = DateTime.now().year - 100;
  late FixedExtentScrollController _j, _m, _a;
  late int jour, mois, annee;

  @override
  void initState() {
    super.initState();
    final d = context.read<InscriptionController>().draft.naissance ?? DateTime(DateTime.now().year - 25, 1, 1);
    jour = d.day;
    mois = d.month;
    annee = d.year.clamp(_anneeMin, _anneeMax);
    _j = FixedExtentScrollController(initialItem: jour - 1);
    _m = FixedExtentScrollController(initialItem: mois - 1);
    _a = FixedExtentScrollController(initialItem: annee - _anneeMin);
  }

  @override
  void dispose() {
    _j.dispose();
    _m.dispose();
    _a.dispose();
    super.dispose();
  }

  int get _joursDuMois => DateUtils.getDaysInMonth(annee, mois);

  void _maj() {
    if (jour > _joursDuMois) {
      jour = _joursDuMois;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_j.hasClients) _j.jumpToItem(jour - 1);
      });
    }
    context.read<InscriptionController>().set((d) => d.naissance = DateTime(annee, mois, jour));
    setState(() {});
  }

  Future<void> _calendrier() async {
    final ctrl = context.read<InscriptionController>();
    final r = await showDatePicker(
      context: context,
      initialDate: DateTime(annee, mois, jour),
      firstDate: DateTime(_anneeMin),
      lastDate: DateTime(_anneeMax, 12, 31),
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Date de naissance',
    );
    if (r == null || !mounted) return;
    setState(() {
      jour = r.day;
      mois = r.month;
      annee = r.year;
    });
    _j.jumpToItem(jour - 1);
    _m.jumpToItem(mois - 1);
    _a.jumpToItem(annee - _anneeMin);
    ctrl.set((d) => d.naissance = r);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final c = context.colors;
    final age = ctrl.draft.age;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(
          title: 'Ta date de naissance',
          subtitle: 'Ton âge affine le calcul de ton métabolisme et de ta récupération.',
        ),
        Center(child: HeroValue(value: age == null ? '-' : '$age', unit: 'ans', onTap: _calendrier, caption: 'Touche le chiffre pour saisir la date au clavier')),
        const SizedBox(height: 16),
        Padding(
          padding: _pad,
          child: Container(
            height: 220,
            decoration: BoxDecoration(color: c.surface, borderRadius: AppTokens.radius16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 46,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: c.surface3, borderRadius: AppTokens.radius12),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: WheelColumn(
                        controller: _j,
                        items: [for (var i = 1; i <= _joursDuMois; i++) '$i'],
                        onChanged: (i) {
                          jour = i + 1;
                          _maj();
                        },
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: WheelColumn(
                        controller: _m,
                        items: _moisNoms,
                        onChanged: (i) {
                          mois = i + 1;
                          _maj();
                        },
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: WheelColumn(
                        controller: _a,
                        items: [for (var y = _anneeMin; y <= _anneeMax; y++) '$y'],
                        onChanged: (i) {
                          annee = _anneeMin + i;
                          _maj();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (age != null && age < 16) ...[
          const SizedBox(height: 16),
          const Padding(
            padding: _pad,
            child: InfoNote(
              icon: Icons.child_care_rounded,
              text: 'Avant 16 ans, entraîne-toi avec un adulte et privilégie la technique aux charges lourdes.',
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Taille

class TailleStep extends StatelessWidget {
  const TailleStep({super.key});

  Future<void> _saisir(BuildContext context, InscriptionController ctrl) async {
    final d = ctrl.draft;
    final cm = d.uniteTaille == UniteTaille.cm;
    final v = await showNumberInputDialog(
      context,
      title: cm ? 'Ta taille en centimètres' : 'Ta taille en pouces (1 pied = 12 pouces)',
      initial: cm ? (d.tailleCm ?? 175).roundToDouble() : ((d.tailleCm ?? 175) / 2.54).roundToDouble(),
      unit: cm ? 'cm' : 'in',
      decimal: false,
    );
    if (v == null) return;
    final enCm = cm ? v : v * 2.54;
    if (enCm < 120 || enCm > 230) {
      if (context.mounted) Toasts.error(context, 'Choisis une taille entre 120 et 230 cm.');
      return;
    }
    ctrl.set((d) => d.tailleCm = enCm.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final d = ctrl.draft;
    final cm = d.tailleCm ?? 175;
    final enCm = d.uniteTaille == UniteTaille.cm;
    final valeur = tailleTexte(cm, d.uniteTaille);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(title: 'Ta taille', subtitle: 'Fais glisser la règle, ou touche le chiffre pour le saisir.'),
        Padding(
          padding: _pad,
          child: SegmentedControl<UniteTaille>(
            segments: [for (final u in UniteTaille.values) (u, u.label)],
            value: d.uniteTaille,
            onChanged: (u) => ctrl.set((d) => d.uniteTaille = u),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: HeroValue(
            value: enCm ? '${cm.round()}' : valeur,
            unit: enCm ? 'cm' : null,
            caption: enCm ? tailleTexte(cm, UniteTaille.ftIn) : '${cm.round()} cm',
            onTap: () => _saisir(context, ctrl),
          ),
        ),
        const SizedBox(height: 20),
        if (enCm)
          RulerPicker(
            key: const ValueKey('cm'),
            value: cm,
            min: 120,
            max: 230,
            step: 1,
            majorEvery: 10,
            spacing: 12,
            onChanged: (v) => ctrl.set((d) => d.tailleCm = v),
          )
        else
          RulerPicker(
            key: const ValueKey('in'),
            value: (cm / 2.54).roundToDouble(),
            min: 48,
            max: 90,
            step: 1,
            majorEvery: 12,
            spacing: 14,
            labelOf: (v) => '${v ~/ 12}\'',
            onChanged: (v) => ctrl.set((d) => d.tailleCm = (v * 2.54).roundToDouble()),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Poids

class PoidsStep extends StatelessWidget {
  const PoidsStep({super.key});

  Future<void> _saisir(BuildContext context, InscriptionController ctrl, {bool cible = false}) async {
    final d = ctrl.draft;
    final u = d.unitePoids;
    final actuel = cible ? (d.poidsCibleKg ?? d.poidsKg ?? 75) : (d.poidsKg ?? 75);
    final v = await showNumberInputDialog(
      context,
      title: cible ? 'Poids visé' : 'Ton poids actuel',
      initial: double.parse(Fmt.poidsAffiche(actuel, u).toStringAsFixed(1)),
      unit: u.label,
    );
    if (v == null) return;
    final kg = Fmt.poidsStocke(v, u);
    if (kg < 30 || kg > 250) {
      if (context.mounted) Toasts.error(context, 'Choisis un poids entre ${u == UnitePoids.kg ? '30 et 250 kg' : '66 et 550 lb'}.');
      return;
    }
    ctrl.set((d) => cible ? d.poidsCibleKg = kg : d.poidsKg = kg);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final c = context.colors;
    final d = ctrl.draft;
    final u = d.unitePoids;
    final kg = d.poidsKg ?? 75;
    final affiche = Fmt.poidsAffiche(kg, u);
    final imc = NutritionCalc.imc(kg, d.tailleCm);
    final cible = d.poidsCibleKg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepTitle(title: 'Ton poids', subtitle: 'Ta première pesée. Tu suivras son évolution dans Progrès.'),
        Padding(
          padding: _pad,
          child: SegmentedControl<UnitePoids>(
            segments: const [(UnitePoids.kg, 'Kilogrammes'), (UnitePoids.lb, 'Livres')],
            value: u,
            onChanged: (v) => ctrl.set((d) => d.unitePoids = v),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: HeroValue(
            value: Fmt.n(affiche, decimals: 1),
            unit: u.label,
            caption: imc == null ? null : 'Indice de masse corporelle : ${Fmt.n(imc, decimals: 1)}',
            onTap: () => _saisir(context, ctrl),
          ),
        ),
        const SizedBox(height: 20),
        if (u == UnitePoids.kg)
          RulerPicker(
            key: const ValueKey('kg'),
            value: double.parse(kg.toStringAsFixed(1)),
            min: 30,
            max: 250,
            step: 0.1,
            majorEvery: 10,
            spacing: 10,
            labelOf: (v) => '${v.round()}',
            onChanged: (v) => ctrl.set((d) => d.poidsKg = v),
          )
        else
          RulerPicker(
            key: const ValueKey('lb'),
            value: (affiche * 2).roundToDouble() / 2,
            min: 66,
            max: 550,
            step: 0.5,
            majorEvery: 10,
            spacing: 10,
            labelOf: (v) => '${v.round()}',
            onChanged: (v) => ctrl.set((d) => d.poidsKg = Fmt.poidsStocke(v, UnitePoids.lb)),
          ),
        const SizedBox(height: 24),
        Padding(
          padding: _pad,
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconHalo(icon: Icons.flag_rounded, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Un poids à atteindre', style: AppType.rowTitle()),
                          Text('Facultatif, affiché dans tes progrès', style: AppType.rowSubtitle()),
                        ],
                      ),
                    ),
                    Switch(
                      value: cible != null,
                      onChanged: (on) => ctrl.set((d) => d.poidsCibleKg = on ? d.poidsKg : null),
                    ),
                  ],
                ),
                if (cible != null) ...[
                  const SizedBox(height: 12),
                  NumberStepper(
                    value: double.parse(Fmt.poidsAffiche(cible, u).toStringAsFixed(1)),
                    step: 0.5,
                    min: u == UnitePoids.kg ? 30 : 66,
                    max: u == UnitePoids.kg ? 250 : 550,
                    decimals: 1,
                    unit: u.label,
                    onChanged: (v) => ctrl.set((d) => d.poidsCibleKg = Fmt.poidsStocke(v, u)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ecart(cible - kg, u),
                    style: AppType.rowSubtitle(color: c.text2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _ecart(double diffKg, UnitePoids u) {
    if (diffKg.abs() < 0.05) return 'Tu es déjà à ce poids : on vise la stabilité.';
    final v = Fmt.poids(diffKg.abs(), u);
    return diffKg > 0 ? '$v à prendre' : '$v à perdre';
  }
}
