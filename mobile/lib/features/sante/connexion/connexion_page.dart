import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../common/sante_widgets.dart';
import '../services/activite_journal.dart';
import '../services/health_connect.dart';

/// Lit Health Connect et range tout ; affiche le bilan ou l'erreur.
Future<void> synchroniserSante(BuildContext context, {int jours = 30}) async {
  final repo = context.read<HealthRepo>();
  final journal = ActiviteJournal.of(context.read<Store>());
  if (journal.synchroEnCours) return;
  try {
    final bilan = await HealthConnectService.instance.synchroniser(repo, journal, jours: jours);
    if (context.mounted) Toasts.success(context, bilan.resume);
  } on HcErreur catch (e) {
    if (context.mounted) Toasts.error(context, e.message);
  } catch (_) {
    if (context.mounted) Toasts.error(context, 'La synchronisation a échoué. Réessayez.');
  }
}

/// Connexion à Health Connect : explication, autorisation, refus, synchro.
class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> with WidgetsBindingObserver {
  EtatHc? _etat;
  Set<DonneeHc> _accordees = {};
  bool _action = false;
  String? _erreur;

  ActiviteJournal get _journal => ActiviteJournal.of(context.read<Store>());

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

  /// Retour depuis Health Connect ou le Play Store : on revérifie.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verifier();
  }

  Future<void> _verifier() async {
    setState(() => _erreur = null);
    try {
      if (!_journal.charge) await _journal.charger();
      final e = await HealthConnectService.instance.etat(refus: _journal.refus);
      final a = e == EtatHc.connecte ? await HealthConnectService.instance.accordees() : <DonneeHc>{};
      if (!mounted) return;
      setState(() {
        _etat = e;
        _accordees = a;
      });
      final settings = context.read<SettingsRepo>();
      if (e == EtatHc.connecte && !settings.settings.santeConnectee) {
        await settings.update((s) => s.copyWith(santeConnectee: true));
      }
    } catch (_) {
      if (mounted) setState(() => _erreur = 'Impossible de joindre Health Connect.');
    }
  }

  Future<void> _autoriser() async {
    setState(() => _action = true);
    try {
      final ok = await HealthConnectService.instance.demanderAcces();
      if (!mounted) return;
      if (ok) {
        await _journal.noterRefus(reset: true);
        if (!mounted) return;
        await context.read<SettingsRepo>().update((s) => s.copyWith(santeConnectee: true));
        await _verifier();
        if (mounted) await synchroniserSante(context);
      } else {
        await _journal.noterRefus();
        await _verifier();
      }
    } catch (_) {
      if (mounted) Toasts.error(context, 'La fenêtre d\'autorisation n\'a pas pu s\'ouvrir.');
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }

  Future<void> _installer() async {
    setState(() => _action = true);
    await HealthConnectService.instance.installer();
    if (mounted) setState(() => _action = false);
  }

  Future<void> _deconnecter() async {
    final effacer = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Délier Health Connect ?'),
        content: const Text('L\'appli ne lira plus rien. Voulez-vous aussi effacer les nuits, pesées et l\'activité déjà importées ? Vos saisies manuelles restent.'),
        actions: [
          PillButton.ghost(label: 'Annuler', onPressed: () => Navigator.of(dctx).pop()),
          PillButton.secondary(label: 'Garder les données', onPressed: () => Navigator.of(dctx).pop(false)),
          PillButton(label: 'Tout effacer', variant: PillVariant.danger, onPressed: () => Navigator.of(dctx).pop(true)),
        ],
      ),
    );
    if (effacer == null || !mounted) return;
    final repo = context.read<HealthRepo>();
    final settings = context.read<SettingsRepo>();
    await HealthConnectService.instance.revoquer();
    await settings.update((s) => s.copyWith(santeConnectee: false));
    if (effacer) {
      for (final n in repo.sleep.where((n) => n.source == 'health connect').toList()) {
        await repo.deleteSleep(n.id);
      }
      for (final m in repo.measurements.where((m) => m.source == 'health connect').toList()) {
        await repo.deleteMeasurement(m.id);
      }
      await _journal.effacer();
    }
    await _verifier();
    if (mounted) Toasts.show(context, effacer ? 'Health Connect délié, données importées effacées' : 'Health Connect délié');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final journal = _journal;
    return SubPageScaffold(
      title: 'Health Connect',
      haloColor: c.heart,
      body: ListenableBuilder(
        listenable: journal,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            AppCard(
              margin: santePad,
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  IconHalo.domain(AppDomain.coeur, icon: Icons.health_and_safety_rounded, size: 64),
                  const SizedBox(height: 16),
                  Text('Vos données santé, sans rien saisir', textAlign: TextAlign.center, style: AppType.screenTitle().copyWith(fontSize: 21)),
                  const SizedBox(height: 8),
                  Text(
                    'Health Connect rassemble ce que mesurent votre téléphone, votre montre et votre balance. Aesthetics le lit pour remplir vos nuits, votre poids et votre activité.',
                    textAlign: TextAlign.center,
                    style: AppType.rowSubtitle().copyWith(fontSize: 13.5, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  _Statut(etat: _etat, erreur: _erreur),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._actions(context, journal),
            const SizedBox(height: 12),
            TileGroup(
              label: 'Ce qui est lu',
              children: [
                for (final d in DonneeHc.values)
                  ListTileX(
                    leading: IconHalo(icon: _icone(d), color: _couleur(context, d), size: 38, off: _etat == EtatHc.connecte && !_accordees.contains(d)),
                    title: d.label,
                    subtitle: d.detail,
                    trailing: _etat != EtatHc.connecte
                        ? null
                        : _accordees.contains(d)
                            ? TagPill('Autorisé', color: c.heart)
                            : TagPill('Refusé', color: c.text3),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              margin: santePad,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_rounded, color: c.text3, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lecture seule. Les données restent sur ce téléphone, dans le dossier privé de l\'appli. Vous pouvez retirer l\'accès à tout moment, ici ou dans Health Connect.',
                      style: AppType.rowSubtitle().copyWith(fontSize: 13, height: 1.45),
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

  List<Widget> _actions(BuildContext context, ActiviteJournal journal) {
    final c = context.colors;
    Widget bouton(String label, VoidCallback? onTap, {IconData? icon}) => Padding(
          padding: santePad,
          child: PillButton(label: label, icon: icon, expand: true, size: PillSize.large, loading: _action, onPressed: onTap),
        );
    Widget texte(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 10, AppTokens.gutter + 4, 0),
          child: Text(t, textAlign: TextAlign.center, style: AppType.rowSubtitle().copyWith(fontSize: 13, height: 1.45)),
        );

    switch (_etat) {
      case null:
        return [const Padding(padding: santePad, child: Skeleton(height: 56, radius: 28))];
      case EtatHc.indisponible:
        return [
          texte(_erreur ?? 'Health Connect n\'existe que sur Android. Vous pouvez tout noter à la main.'),
          const SizedBox(height: 12),
          if (_erreur != null) bouton('Réessayer', _verifier, icon: Icons.refresh_rounded),
          TileGroup(children: [
            ListTileX(
              leading: IconHalo.domain(AppDomain.sommeil, size: 38),
              title: 'Noter une nuit',
              showChevron: true,
              onTap: () => context.push('/sante/sommeil/ajouter'),
            ),
            ListTileX(
              leading: IconHalo.domain(AppDomain.poids, size: 38),
              title: 'Noter une pesée',
              showChevron: true,
              onTap: () => context.push('/sante/corps/mesure'),
            ),
          ]),
        ];
      case EtatHc.aInstaller:
        return [
          bouton('Installer Health Connect', _installer, icon: Icons.download_rounded),
          texte('Gratuit, publié par Google. Revenez ensuite ici : la page se met à jour toute seule.'),
        ];
      case EtatHc.aMettreAJour:
        return [
          bouton('Mettre à jour Health Connect', _installer, icon: Icons.system_update_rounded),
          texte('Votre version est trop ancienne pour être lue.'),
        ];
      case EtatHc.nonAutorise:
        return [
          bouton('Autoriser l\'accès', _autoriser, icon: Icons.check_rounded),
          texte('Une fenêtre d\'Android s\'ouvre : cochez ce que vous voulez partager. Vous pourrez changer d\'avis plus tard.'),
        ];
      case EtatHc.refuse:
        return [
          AppCard(
            margin: santePad,
            color: c.surface2,
            border: true,
            borderColor: c.warning.withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_rounded, color: c.warning, size: 20),
                    const SizedBox(width: 10),
                    Text('L\'accès a été refusé', style: AppType.rowTitle()),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  journal.refus >= 2
                      ? 'Après deux refus, Android ne montre plus la fenêtre. Ouvrez Health Connect, puis Autorisations des applis, Aesthetics, et cochez les données voulues.'
                      : 'Rien n\'est lu sans votre accord. Vous pouvez réessayer, ou continuer en notant tout à la main.',
                  style: AppType.rowSubtitle().copyWith(fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (journal.refus < 2) bouton('Réessayer', _autoriser, icon: Icons.refresh_rounded),
          if (journal.refus >= 2)
            Padding(
              padding: santePad,
              child: PillButton(
                label: 'Ouvrir les réglages de l\'appli',
                icon: Icons.settings_rounded,
                expand: true,
                size: PillSize.large,
                onPressed: () => openAppSettings(),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: santePad,
            child: PillButton.ghost(label: 'Continuer sans Health Connect', expand: true, onPressed: () => context.pop()),
          ),
        ];
      case EtatHc.connecte:
        final manquantes = DonneeHc.values.where((d) => !_accordees.contains(d)).toList();
        return [
          Padding(
            padding: santePad,
            child: PillButton(
              label: journal.synchroEnCours ? 'Synchronisation...' : 'Synchroniser maintenant',
              icon: Icons.sync_rounded,
              expand: true,
              size: PillSize.large,
              loading: journal.synchroEnCours,
              onPressed: journal.synchroEnCours ? null : () => synchroniserSante(context),
            ),
          ),
          texte(journal.derniereErreur ??
              (journal.derniereSynchro == null ? 'Pas encore synchronisé.' : 'Dernière synchronisation ${Fmt.ilYa(journal.derniereSynchro!)}, le ${Fmt.jourMois(journal.derniereSynchro!)} à ${Fmt.heure(journal.derniereSynchro!)}.')),
          const SizedBox(height: 12),
          TileGroup(
            children: [
              ListTileX(
                leading: IconHalo(icon: Icons.history_rounded, color: c.sleep, size: 38),
                title: 'Importer l\'historique',
                subtitle: 'Relit les 12 derniers mois (plus long)',
                showChevron: true,
                onTap: journal.synchroEnCours ? null : () => synchroniserSante(context, jours: 365),
              ),
              if (manquantes.isNotEmpty)
                ListTileX(
                  leading: IconHalo(icon: Icons.playlist_add_check_rounded, color: c.warning, size: 38),
                  title: 'Compléter l\'accès',
                  subtitle: 'Non autorisé : ${manquantes.map((d) => d.label.toLowerCase()).join(', ')}',
                  showChevron: true,
                  onTap: _autoriser,
                ),
              ListTileX(
                leading: IconHalo(icon: Icons.link_off_rounded, color: c.error, size: 38),
                title: 'Délier Health Connect',
                subtitle: 'Arrêter la lecture, garder ou effacer les données importées',
                showChevron: true,
                onTap: _deconnecter,
              ),
            ],
          ),
        ];
    }
  }

  static IconData _icone(DonneeHc d) => switch (d) {
        DonneeHc.sommeil => Icons.bedtime_rounded,
        DonneeHc.poids => Icons.monitor_weight_rounded,
        DonneeHc.pas => Icons.directions_walk_rounded,
        DonneeHc.calories => Icons.local_fire_department_rounded,
        DonneeHc.coeur => Icons.favorite_rounded,
      };

  static Color _couleur(BuildContext context, DonneeHc d) => switch (d) {
        DonneeHc.sommeil => context.colors.sleep,
        DonneeHc.poids => context.colors.weight,
        DonneeHc.pas => context.colors.heart,
        DonneeHc.calories => context.colors.warning,
        DonneeHc.coeur => context.colors.heart,
      };
}

class _Statut extends StatelessWidget {
  const _Statut({required this.etat, this.erreur});
  final EtatHc? etat;
  final String? erreur;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (etat == null && erreur == null) return const Skeleton(width: 140, height: 26, radius: 13);
    final (label, col) = erreur != null
        ? (erreur!, c.error)
        : switch (etat!) {
            EtatHc.connecte => (etat!.label, c.heart),
            EtatHc.refuse || EtatHc.aMettreAJour => (etat!.label, c.warning),
            _ => (etat!.label, c.text3),
          };
    return TagPill(label, color: col, large: true, icon: etat == EtatHc.connecte ? Icons.check_circle_rounded : Icons.circle_outlined);
  }
}
