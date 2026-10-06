import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/pas_repo.dart';

/// Démarre une routine (en demandant quoi faire d'une séance déjà ouverte)
/// puis ouvre l'écran de séance.
Future<void> demarrerRoutine(BuildContext context, Routine r, {String? programId}) async {
  final sessions = context.read<SessionRepo>();
  if (!await _libererSeance(context, sessions)) return;
  await sessions.startFromRoutine(r, programId: programId);
  if (context.mounted) context.push(Paths.seance);
}

/// Démarre une séance vide.
Future<void> demarrerSeanceLibre(BuildContext context) async {
  final sessions = context.read<SessionRepo>();
  if (!await _libererSeance(context, sessions)) return;
  await sessions.startEmpty();
  if (context.mounted) context.push(Paths.seance);
}

Future<bool> _libererSeance(BuildContext context, SessionRepo sessions) async {
  if (!sessions.hasActive) return true;
  final choix = await showChoiceDialog<String>(
    context,
    title: 'Une séance est déjà ouverte',
    message: '« ${sessions.active!.nom} » est en cours. Que veux-tu faire ?',
    options: const [
      ('reprendre', 'Reprendre la séance en cours'),
      ('remplacer', 'L\'abandonner et commencer celle-ci'),
    ],
  );
  if (!context.mounted) return false;
  if (choix == 'reprendre') {
    context.push(Paths.seance);
    return false;
  }
  if (choix == 'remplacer') {
    await sessions.discardActive();
    return true;
  }
  return false;
}

/// Abandonne la séance en cours après confirmation.
Future<void> abandonnerSeance(BuildContext context) async {
  final sessions = context.read<SessionRepo>();
  final ok = await showConfirmDialog(
    context,
    title: 'Abandonner la séance ?',
    message: 'Les séries notées ne seront pas enregistrées.',
    confirmLabel: 'Abandonner',
    destructive: true,
    icon: Icons.delete_outline_rounded,
  );
  if (ok) {
    await sessions.discardActive();
    if (context.mounted) Toasts.show(context, 'Séance abandonnée.');
  }
}

/// Saisie rapide du poids du jour (dialogue). Met à jour la pesée du jour si
/// elle existe déjà.
Future<void> saisirPoids(BuildContext context, {BodyMeasurement? existant}) async {
  final health = context.read<HealthRepo>();
  final unite = context.read<ProfileRepo>().unite;
  final base = existant?.poidsKg ?? health.latestWeight ?? context.read<ProfileRepo>().profile?.poidsKg;
  final v = await showNumberInputDialog(
    context,
    title: existant == null ? 'Poids du jour' : 'Modifier la pesée',
    initial: base == null ? null : double.parse(Fmt.poidsAffiche(base, unite).toStringAsFixed(1)),
    unit: unite.label,
    confirmLabel: 'Enregistrer',
  );
  if (v == null || !context.mounted) return;
  final kg = Fmt.poidsStocke(v, unite);
  if (kg < 25 || kg > 350) {
    Toasts.error(context, 'Ce poids semble incorrect.');
    return;
  }
  final now = DateTime.now();
  final cible = existant ?? health.measurements.firstWhereOrNull((m) => m.poidsKg != null && Dates.memeJour(m.date, now));
  if (cible != null) {
    await health.saveMeasurement(cible.copyWith(poidsKg: kg));
  } else {
    await health.saveMeasurement(BodyMeasurement(id: '', date: now, poidsKg: kg, source: 'manuel'));
  }
  if (context.mounted) Toasts.success(context, 'Pesée enregistrée : ${Fmt.poids(kg, unite)}');
}

/// Saisie manuelle des pas d'un jour.
Future<void> saisirPas(BuildContext context, {DateTime? jour}) async {
  final repo = PasRepo.pour(context.read<Store>());
  final d = jour ?? DateTime.now();
  final v = await showNumberInputDialog(
    context,
    title: Dates.memeJour(d, DateTime.now()) ? 'Pas d\'aujourd\'hui' : 'Pas du ${Fmt.jour(d)}',
    initial: repo.pas(d)?.toDouble(),
    unit: 'pas',
    decimal: false,
  );
  if (v == null || !context.mounted) return;
  await repo.saisir(d, v.round());
  if (context.mounted) Toasts.success(context, '${Fmt.n(v.round(), decimals: 0)} pas enregistrés.');
}

/// Objectif de pas quotidien.
Future<void> choisirObjectifPas(BuildContext context) async {
  final repo = PasRepo.pour(context.read<Store>());
  final v = await showNumberInputDialog(context, title: 'Objectif de pas par jour', initial: repo.objectif.toDouble(), unit: 'pas', decimal: false);
  if (v == null || !context.mounted) return;
  if (v < 1000) {
    Toasts.error(context, 'Choisis au moins 1 000 pas.');
    return;
  }
  await repo.definirObjectif(v.round());
}

/// Ajoute de l'eau au jour, avec annulation.
Future<void> ajouterEau(BuildContext context, int ml) async {
  final n = context.read<NutritionRepo>();
  await n.addWater(ml);
  if (!context.mounted) return;
  Toasts.success(
    context,
    '+${Fmt.n(ml, decimals: 0)} ml d\'eau',
    actionLabel: 'Annuler',
    onAction: () => n.undoWater(DateTime.now()),
  );
}

/// Quantité d'eau libre.
Future<void> ajouterEauLibre(BuildContext context) async {
  final v = await showNumberInputDialog(context, title: 'Ajouter de l\'eau', unit: 'ml', decimal: false, confirmLabel: 'Ajouter');
  if (v == null || !context.mounted) return;
  if (v <= 0 || v > 3000) {
    Toasts.error(context, 'Entre une quantité entre 1 et 3 000 ml.');
    return;
  }
  await ajouterEau(context, v.round());
}

/// Dialogue de saisie d'une nuit (coucher, lever, qualité).
Future<void> saisirSommeil(BuildContext context, {SleepEntry? existant}) async {
  final r = await showDialog<SleepEntry>(context: context, builder: (_) => _DialogueSommeil(existant: existant));
  if (r == null || !context.mounted) return;
  await context.read<HealthRepo>().saveSleep(r);
  if (context.mounted) Toasts.success(context, 'Nuit enregistrée : ${Fmt.sommeil(r.duree)}');
}

class _DialogueSommeil extends StatefulWidget {
  const _DialogueSommeil({this.existant});
  final SleepEntry? existant;

  @override
  State<_DialogueSommeil> createState() => _DialogueSommeilState();
}

class _DialogueSommeilState extends State<_DialogueSommeil> {
  late TimeOfDay _coucher;
  late TimeOfDay _lever;
  late DateTime _jour;
  int? _qualite;

  @override
  void initState() {
    super.initState();
    final e = widget.existant;
    _coucher = e == null ? const TimeOfDay(hour: 23, minute: 0) : TimeOfDay.fromDateTime(e.coucher);
    _lever = e == null ? const TimeOfDay(hour: 7, minute: 0) : TimeOfDay.fromDateTime(e.lever);
    _jour = e?.jour ?? Dates.jour(DateTime.now());
    _qualite = e?.qualite;
  }

  DateTime get _dLever => DateTime(_jour.year, _jour.month, _jour.day, _lever.hour, _lever.minute);

  DateTime get _dCoucher {
    final memeJour = DateTime(_jour.year, _jour.month, _jour.day, _coucher.hour, _coucher.minute);
    return memeJour.isBefore(_dLever) ? memeJour : memeJour.subtract(const Duration(days: 1));
  }

  Future<void> _choisir(bool coucher) async {
    final t = await showTimePicker(
      context: context,
      initialTime: coucher ? _coucher : _lever,
      helpText: coucher ? 'Heure du coucher' : 'Heure du lever',
    );
    if (t == null) return;
    setState(() => coucher ? _coucher = t : _lever = t);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.textStyles;
    final duree = _dLever.difference(_dCoucher);
    const qualites = ['Très mauvaise', 'Mauvaise', 'Correcte', 'Bonne', 'Excellente'];
    Widget ligne(String label, TimeOfDay v, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: AppTokens.radius12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: c.bg, borderRadius: AppTokens.radius12),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppType.rowTitle())),
                Text(v.format(context), style: AppType.rowValue()),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: c.text3, size: 20),
              ],
            ),
          ),
        );
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existant == null ? 'Noter ma nuit' : 'Modifier la nuit', style: t.titleLarge),
              const SizedBox(height: 4),
              Text('Nuit du ${Fmt.jour(_dCoucher)} au ${Fmt.jour(_dLever)}', style: t.bodySmall?.copyWith(color: c.text3)),
              const SizedBox(height: 16),
              ligne('Coucher', _coucher, () => _choisir(true)),
              const SizedBox(height: 8),
              ligne('Lever', _lever, () => _choisir(false)),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  duree.inMinutes <= 0 ? '-' : Fmt.sommeil(duree),
                  style: AppType.number(34, color: c.sleep),
                ),
              ),
              const SizedBox(height: 14),
              Text('QUALITÉ', style: AppType.overline()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 1; i <= 5; i++)
                    ChipFilter(
                      label: qualites[i - 1],
                      selected: _qualite == i,
                      color: c.sleep,
                      onTap: () => setState(() => _qualite = _qualite == i ? null : i),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PillButton.ghost(label: 'Annuler', onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 8),
                  PillButton(
                    label: 'Enregistrer',
                    onPressed: duree.inMinutes < 30 || duree.inHours > 20
                        ? null
                        : () {
                            final e = widget.existant;
                            Navigator.pop(
                              context,
                              e == null
                                  ? SleepEntry(id: '', coucher: _dCoucher, lever: _dLever, qualite: _qualite, source: 'manuel')
                                  : SleepEntry(
                                      id: e.id,
                                      coucher: _dCoucher,
                                      lever: _dLever,
                                      qualite: _qualite,
                                      profondMin: e.profondMin,
                                      legerMin: e.legerMin,
                                      paradoxalMin: e.paradoxalMin,
                                      eveilMin: e.eveilMin,
                                      notes: e.notes,
                                      source: e.source,
                                    ),
                            );
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
