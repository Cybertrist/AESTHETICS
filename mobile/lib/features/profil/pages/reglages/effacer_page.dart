import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/navigation.dart';
import '../../../../core/data/data.dart';
import '../../../../core/env.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../data/backup_service.dart';
import '../../data/prefs.dart';
import '../../data/reminders.dart';
import '../../widgets/maquette.dart';

/// Réglages > Données > Tout effacer, avec une confirmation forte.
class EffacerPage extends StatefulWidget {
  const EffacerPage({super.key});

  static const motCle = 'EFFACER';

  @override
  State<EffacerPage> createState() => _EffacerPageState();
}

class _EffacerPageState extends State<EffacerPage> {
  final _ctrl = TextEditingController();
  bool _sauvegarder = true;
  bool _effacerSauvegardes = false;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _pret => _ctrl.text.trim().toUpperCase() == EffacerPage.motCle;

  Future<void> _effacer() async {
    final data = context.read<AppData>();
    final accent = context.read<AccentController>();
    final ok = await showConfirmDialog(
      context,
      title: 'Dernière vérification',
      message: 'Tout sera effacé maintenant. Cette action ne peut pas être annulée.',
      confirmLabel: 'Tout effacer',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _occupe = true);
    try {
      if (_sauvegarder && !_effacerSauvegardes) await BackupService(data).sauvegarderSurTelephone();
      await Reminders.toutAnnuler();
      await data.resetAll();
      await PrefsRepo.maybeInstance?.load();
      await accent.set(AccentChoice.values.first);
      if (_effacerSauvegardes) await BackupService.effacerSauvegardesLocales();
      if (!mounted) return;
      Toasts.show(context, 'Toutes les données ont été effacées');
      context.go(Paths.bienvenue);
    } catch (e) {
      if (mounted) {
        setState(() => _occupe = false);
        Toasts.error(context, 'Effacement interrompu : $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final seances = context.watch<SessionRepo>().sessions.length;
    final routines = context.watch<RoutineRepo>().routines.length;
    final health = context.watch<HealthRepo>();
    final repas = context.watch<NutritionRepo>();
    // Seuls les modules visibles sont cités.
    final perdu = <(Trace, String)>[
      (Trace.silhouette, 'Ton profil et tes réglages'),
      (Trace.haltere, '${Fmt.pluriel(seances, 'séance')} et ${Fmt.pluriel(routines, 'routine')}'),
      (Trace.regle, '${Fmt.pluriel(health.measurements.length, 'mesure')} et ${Fmt.pluriel(health.photos.length, 'photo')}'),
      if (!Env.muscuSeule) ...[
        (Trace.horloge, Fmt.pluriel(health.sleep.length, 'nuit')),
        (Trace.donnees, 'Ton journal alimentaire (${Fmt.pluriel(repas.meals.length, 'repas enregistré', 'repas enregistrés')})'),
        (Trace.etoile, 'Tes conversations avec le coach'),
      ],
    ];

    return PageMaquette(
      titre: 'Tout effacer',
      bas: BoutonDestructif(label: _occupe ? 'Effacement...' : 'Tout effacer', onPressed: _pret && !_occupe ? _effacer : null),
      enfants: [
        GroupeTitre(
          premier: true,
          titre: 'Ce qui disparaît',
          lignes: [for (final (trace, texte) in perdu) Ligne(trace: trace, titre: texte)],
        ),
        GroupeTitre(
          titre: 'Avant d\'effacer',
          lignes: [
            LigneBascule(
              trace: Trace.boite,
              titre: 'Sauvegarder avant d\'effacer',
              detail: 'Une copie reste sur le téléphone, au cas où',
              valeur: _sauvegarder && !_effacerSauvegardes,
              actif: !_effacerSauvegardes,
              onChanged: (v) => setState(() => _sauvegarder = v),
            ),
            LigneBascule(
              trace: Trace.poubelle,
              titre: 'Supprimer aussi les sauvegardes',
              detail: 'Rien ne restera sur le téléphone',
              valeur: _effacerSauvegardes,
              onChanged: (v) => setState(() => _effacerSauvegardes = v),
            ),
          ],
        ),
        Bloc(
          haut: 4,
          bas: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Surtitre('Confirmation'),
              SizedBox(height: e(6)),
              Carte(
                rayon: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Écris '),
                        TextSpan(text: EffacerPage.motCle, style: TextStyle(color: c.error, fontWeight: FontWeight.w700)),
                        const TextSpan(text: ' pour débloquer le bouton.'),
                      ]),
                      style: txt(12, FontWeight.w400, c.text2),
                    ),
                    SizedBox(height: e(10)),
                    TextField(
                      controller: _ctrl,
                      enabled: !_occupe,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      cursorColor: c.text,
                      style: txt(14, FontWeight.w600, c.text),
                      decoration: InputDecoration(
                        hintText: EffacerPage.motCle,
                        hintStyle: txt(14, FontWeight.w600, c.text3),
                        filled: true,
                        fillColor: c.surface2,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: e(12), vertical: e(11)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(e(10)), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(e(10)), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(e(10)), borderSide: BorderSide(color: c.text, width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(e(2), e(7), e(2), e(18)),
                child: Note(Env.muscuSeule
                    ? 'L\'appli repartira sur l\'inscription.'
                    : 'L\'appli repartira sur l\'inscription. L\'autorisation Health Connect reste à retirer depuis Health Connect.'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
