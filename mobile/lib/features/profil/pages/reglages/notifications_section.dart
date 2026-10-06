import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/env.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../data/prefs.dart';
import '../../data/reminders.dart';
import '../../widgets/maquette.dart';
import '../../widgets/setting_rows.dart';

/// Réglages > Notifications : rappels de séance, compléments, eau.
class NotificationsSection extends StatefulWidget {
  const NotificationsSection({super.key});

  @override
  State<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<NotificationsSection> with WidgetsBindingObserver {
  bool? _autorise;

  static const _jours = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _nomsJours = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  static const _intervalles = [60, 90, 120, 180, 240];

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

  // Au retour des réglages d'Android, l'autorisation a pu changer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verifier();
  }

  Future<void> _verifier() async {
    final ok = await Reminders.autorisees();
    if (mounted) setState(() => _autorise = ok);
  }

  Future<void> _replanifier() async {
    final prefs = PrefsRepo.maybeInstance?.prefs ?? const ProfilPrefs();
    try {
      await Reminders.planifier(
        context.read<SettingsRepo>().settings,
        prefs,
        complements: context.read<HealthRepo>().supplements,
      );
    } catch (e) {
      if (mounted) Toasts.error(context, 'Rappels non planifiés : $e');
    }
  }

  /// Active un rappel : demande d'abord l'autorisation si besoin.
  Future<bool> _pourActiver() async {
    if (_autorise == true) return true;
    final ok = await Reminders.demander();
    if (mounted) setState(() => _autorise = ok);
    if (!ok && mounted) {
      Toasts.show(context, 'Autorise les notifications dans Android pour recevoir les rappels.', actionLabel: 'Ouvrir', onAction: Reminders.ouvrirReglagesSysteme);
    }
    return ok;
  }

  Future<void> _maj(AppSettings Function(AppSettings s) f, {bool activation = false}) async {
    if (activation && !await _pourActiver()) return;
    if (!mounted) return;
    await context.read<SettingsRepo>().update(f);
    await _replanifier();
  }

  Future<void> _majPrefs(ProfilPrefs Function(ProfilPrefs p) f) async {
    await PrefsRepo.instance.update(f);
    await _replanifier();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<SettingsRepo>().settings;
    final complements = context.watch<HealthRepo>().activeSupplements;
    return PrefsBuilder(
      builder: (context, prefs, repo) {
        final heuresEau = Reminders.heuresEau(prefs);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_autorise == false)
              Bloc(
                haut: 2,
                bas: 6,
                child: Carte(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: e(30),
                        height: e(30),
                        decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(e(9))),
                        alignment: Alignment.center,
                        child: IconeTrait(Trace.alerte, taille: e(16), couleur: c.text),
                      ),
                      SizedBox(width: e(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notifications bloquées', style: txt(13, FontWeight.w600, c.text)),
                            Text('Android n\'autorise pas encore Aesthetics à te prévenir.', style: txt(12, FontWeight.w400, c.text2)),
                            SizedBox(height: e(10)),
                            SizedBox(
                              width: e(120),
                              child: BoutonDuo(
                                label: 'Autoriser',
                                onPressed: () async {
                                  final ok = await Reminders.demander();
                                  if (!ok) await Reminders.ouvrirReglagesSysteme();
                                  await _verifier();
                                  if (ok) await _replanifier();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            GroupeTitre(
              premier: true,
              titre: 'Séances',
              lignes: [
                LigneBascule(
                  trace: Trace.haltere,
                  titre: 'Rappel d\'entraînement',
                  detail: s.rappelsEntrainement ? _resumeJours(s.joursRappel, s.heureRappel) : 'Désactivé',
                  valeur: s.rappelsEntrainement,
                  onChanged: (v) => _maj((x) => x.copyWith(rappelsEntrainement: v), activation: v),
                ),
                if (s.rappelsEntrainement) ...[
                  Ligne(
                    trace: Trace.horloge,
                    titre: 'Heure',
                    valeur: s.heureRappel,
                    onTap: () async {
                      final h = await choisirHeure(context, s.heureRappel, titre: 'Heure du rappel');
                      if (h != null) await _maj((x) => x.copyWith(heureRappel: h));
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: e(8), vertical: e(6)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var j = 1; j <= 7; j++)
                          _Jour(
                            lettre: _jours[j - 1],
                            nom: _nomsJours[j - 1],
                            actif: s.joursRappel.contains(j),
                            onTap: () {
                              final set = {...s.joursRappel};
                              if (!set.remove(j)) set.add(j);
                              if (set.isEmpty) {
                                Toasts.show(context, 'Garde au moins un jour, ou coupe le rappel.');
                                return;
                              }
                              _maj((x) => x.copyWith(joursRappel: set.toList()..sort()));
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            // Compléments et eau appartiennent aux modules rangés.
            if (!Env.muscuSeule) ...[
              GroupeTitre(
                titre: 'Compléments',
                lignes: [
                  LigneBascule(
                    trace: Trace.plus,
                    titre: 'Rappel des compléments',
                    detail: complements.isEmpty ? 'Aucun complément suivi pour l\'instant' : complements.map((x) => x.nom).join(', '),
                    valeur: s.rappelsComplements,
                    onChanged: (v) => _maj((x) => x.copyWith(rappelsComplements: v), activation: v),
                  ),
                  if (s.rappelsComplements)
                    Ligne(
                      trace: Trace.horloge,
                      titre: 'Heure',
                      detail: complements.any((x) => x.heures.isNotEmpty) ? 'Les heures propres à chaque complément passent avant' : null,
                      detailLignes: 2,
                      valeur: prefs.heureComplements,
                      onTap: () async {
                        final h = await choisirHeure(context, prefs.heureComplements, titre: 'Heure des compléments');
                        if (h != null) await _majPrefs((p) => p.copyWith(heureComplements: h));
                      },
                    ),
                ],
              ),
              GroupeTitre(
                titre: 'Eau',
                lignes: [
                  LigneBascule(
                    trace: Trace.goutte,
                    titre: 'Rappels pour boire',
                    detail: s.rappelsEau ? '${heuresEau.length} rappels par jour' : 'Désactivé',
                    valeur: s.rappelsEau,
                    onChanged: (v) => _maj((x) => x.copyWith(rappelsEau: v), activation: v),
                  ),
                  if (s.rappelsEau) ...[
                    Ligne(
                      trace: Trace.horloge,
                      titre: 'À partir de',
                      valeur: prefs.eauDebut,
                      onTap: () async {
                        final h = await choisirHeure(context, prefs.eauDebut, titre: 'Premier rappel');
                        if (h == null) return;
                        if (h.compareTo(prefs.eauFin) >= 0) {
                          if (context.mounted) Toasts.error(context, 'Le début doit précéder la fin (${prefs.eauFin}).');
                          return;
                        }
                        await _majPrefs((p) => p.copyWith(eauDebut: h));
                      },
                    ),
                    Ligne(
                      trace: Trace.horloge,
                      titre: 'Jusqu\'à',
                      valeur: prefs.eauFin,
                      onTap: () async {
                        final h = await choisirHeure(context, prefs.eauFin, titre: 'Dernier rappel');
                        if (h == null) return;
                        if (h.compareTo(prefs.eauDebut) <= 0) {
                          if (context.mounted) Toasts.error(context, 'La fin doit suivre le début (${prefs.eauDebut}).');
                          return;
                        }
                        await _majPrefs((p) => p.copyWith(eauFin: h));
                      },
                    ),
                    Ligne(
                      trace: Trace.echange,
                      titre: 'Toutes les',
                      valeur: _intervalle(prefs.eauIntervalleMin),
                      onTap: () async {
                        final v = await showPanneauBas<int>(
                          context,
                          titre: 'Intervalle',
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final i in _intervalles)
                                ChoixPanneau(label: _intervalle(i), selected: i == prefs.eauIntervalleMin, onTap: () => Navigator.pop(context, i)),
                            ],
                          ),
                        );
                        if (v != null) await _majPrefs((p) => p.copyWith(eauIntervalleMin: v));
                      },
                    ),
                  ],
                ],
              ),
            ],
            GroupeTitre(
              titre: 'Android',
              lignes: [
                Ligne(
                  trace: Trace.cloche,
                  titre: 'Envoyer une notification d\'essai',
                  chevron: false,
                  onTap: () async {
                    if (!await _pourActiver()) return;
                    await Reminders.essai();
                    if (context.mounted) Toasts.success(context, 'Notification envoyée');
                  },
                ),
                Ligne(trace: Trace.externe, titre: 'Réglages Android des notifications', onTap: Reminders.ouvrirReglagesSysteme),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _intervalle(int min) => min % 60 == 0 ? '${min ~/ 60} h' : '${min ~/ 60} h ${min % 60}';

  static String _resumeJours(List<int> jours, String heure) {
    final j = [...jours]..sort();
    final txt = j.length == 7 ? 'Tous les jours' : j.map((d) => _nomsJours[d - 1].substring(0, 3)).join(', ');
    return '$txt à $heure';
  }
}

/// Pastille d'un jour de rappel : blanche quand le jour est retenu.
class _Jour extends StatelessWidget {
  const _Jour({required this.lettre, required this.nom, required this.actif, required this.onTap});
  final String lettre;
  final String nom;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: actif,
      label: nom,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: e(2), vertical: e(4)),
          child: AnimatedContainer(
            duration: AppTokens.fast,
            width: e(30),
            height: e(30),
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: actif ? c.bouton : c.surface2),
            child: Text(lettre, style: txt(12, FontWeight.w700, actif ? c.onBouton : c.text2, interligne: 1.2)),
          ),
        ),
      ),
    );
  }
}
