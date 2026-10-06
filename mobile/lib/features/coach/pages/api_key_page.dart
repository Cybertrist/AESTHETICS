import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/claude_client.dart';
import '../logic/coach_engine.dart';
import '../widgets/coach_scope.dart';
import 'settings_page.dart';

/// Saisie, test et suppression de la clé API du coach.
class ApiKeyPage extends StatefulWidget {
  const ApiKeyPage({super.key});

  @override
  State<ApiKeyPage> createState() => _ApiKeyPageState();
}

enum _Etat { repos, test, ok, erreur }

class _ApiKeyPageState extends State<ApiKeyPage> {
  final _ctrl = TextEditingController();
  bool _visible = false;
  _Etat _etat = _Etat.repos;
  String? _message;

  static final _console = Uri.parse('https://console.anthropic.com/settings/keys');

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {
          if (_etat != _Etat.test) {
            _etat = _Etat.repos;
            _message = null;
          }
        }));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _coller() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim();
    if (t == null || t.isEmpty) {
      if (mounted) Toasts.show(context, 'Le presse-papiers est vide.');
      return;
    }
    _ctrl.text = t;
  }

  Future<void> _tester({bool enregistrer = true, String? cle}) async {
    final k = (cle ?? _ctrl.text).trim();
    if (k.isEmpty) return;
    final settingsRepo = context.read<SettingsRepo>();
    final prefs = context.coachPrefs;
    final engine = context.coachEngine;
    setState(() {
      _etat = _Etat.test;
      _message = null;
    });
    final client = ClaudeClient(apiKey: k);
    try {
      final modeles = await client.listModels();
      await prefs.update((p) => p.copyWith(modelesApi: modeles.where((m) => m.$1.startsWith('claude')).toList()));
      if (enregistrer) {
        await settingsRepo.update((s) => s.copyWith(coachApiKey: k));
        await prefs.update((p) => p.copyWith(clearPhrase: true));
        engine.oublierRefus();
      }
      if (!mounted) return;
      if (enregistrer) _ctrl.clear();
      setState(() {
        _etat = _Etat.ok;
        _message = '${enregistrer ? 'Clé enregistrée' : 'Clé valide'} : ${modeles.length} modèles disponibles.';
      });
      if (enregistrer) Toasts.success(context, 'Le coach est connecté.');
    } on CoachApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _etat = _Etat.erreur;
        _message = e.message;
      });
    } finally {
      client.close();
    }
  }

  Future<void> _supprimer() async {
    final settingsRepo = context.read<SettingsRepo>();
    final prefs = context.coachPrefs;
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer la clé ?',
      message: 'Le coach repassera en mode hors ligne. Tes conversations sont gardées.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.key_off_rounded,
    );
    if (!ok) return;
    await settingsRepo.update((s) => s.copyWith(clearCoachApiKey: true));
    await prefs.update((p) => p.copyWith(modelesApi: const [], clearPhrase: true));
    if (!mounted) return;
    setState(() {
      _etat = _Etat.repos;
      _message = null;
    });
    Toasts.show(context, 'Clé supprimée : le coach est hors ligne.');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepo>().settings;
    final actuelle = CoachEngine.cle(settings);
    final saisie = _ctrl.text.trim();
    final formatDouteux = saisie.isNotEmpty && !saisie.startsWith('sk-');

    return SubPageScaffold(
      title: 'Clé API',
      subtitle: actuelle == null ? 'Coach hors ligne' : 'Coach connecté',
      body: Column(
        children: [
          Expanded(child: _contenu(context, actuelle, saisie, formatDouteux)),
          CoachBottomBar(
            child: PillButton(
              label: actuelle == null ? 'Tester et enregistrer' : 'Remplacer la clé',
              icon: Icons.check_rounded,
              expand: true,
              loading: _etat == _Etat.test,
              onPressed: saisie.isEmpty ? null : () => _tester(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenu(BuildContext context, String? actuelle, String saisie, bool formatDouteux) {
    final c = context.colors;
    return ListView(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, AppTokens.gutter, 24),
        children: [
          if (actuelle != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconHalo(icon: Icons.key_rounded, color: AppTokens.domainCoach),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Clé enregistrée', style: AppType.rowTitle().copyWith(fontWeight: FontWeight.w700)),
                            Text(CoachSettingsPage.masque(actuelle), style: AppType.rowSubtitle().copyWith(fontFeatures: AppTokens.tabular)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PillButton.secondary(
                        label: 'Tester',
                        icon: Icons.wifi_tethering_rounded,
                        size: PillSize.small,
                        loading: _etat == _Etat.test && saisie.isEmpty,
                        onPressed: _etat == _Etat.test ? null : () => _tester(enregistrer: false, cle: actuelle),
                      ),
                      PillButton(
                        label: 'Supprimer',
                        icon: Icons.delete_outline_rounded,
                        variant: PillVariant.danger,
                        size: PillSize.small,
                        onPressed: _supprimer,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          Text(actuelle == null ? 'COLLE TA CLÉ' : 'NOUVELLE CLÉ', style: AppType.overline(color: c.text3)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            obscureText: !_visible,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            style: AppType.rowTitle().copyWith(fontFeatures: AppTokens.tabular),
            onSubmitted: (_) => _tester(),
            decoration: InputDecoration(
              hintText: 'sk-ant-…',
              prefixIcon: Icon(Icons.key_rounded, color: c.text3),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _visible ? 'Masquer' : 'Afficher',
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(_visible ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: c.text3),
                  ),
                  IconButton(tooltip: 'Coller', onPressed: _coller, icon: Icon(Icons.content_paste_rounded, color: c.text3)),
                ],
              ),
            ),
          ),
          if (formatDouteux) ...[
            const SizedBox(height: 8),
            Text('Une clé API commence normalement par « sk-ant- ».', style: AppType.rowSubtitle(color: c.warning).copyWith(fontSize: 13)),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _etat == _Etat.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  size: 18,
                  color: _etat == _Etat.ok ? c.accent : c.error,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_message!, style: AppType.rowSubtitle(color: _etat == _Etat.ok ? c.text : c.error))),
              ],
            ),
          ],
          const SizedBox(height: 24),
          AppCard(
            label: 'Obtenir une clé',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, t) in const [
                  'Crée un compte sur la console d\'Anthropic et ajoute un peu de crédit.',
                  'Dans « API Keys », crée une clé et copie-la.',
                  'Colle-la ici puis touche « Tester et enregistrer ».',
                ].indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                          child: Text('${i + 1}', style: AppType.number(12, color: c.accent)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(t, style: AppType.rowSubtitle(color: c.text))),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                PillButton.link(
                  label: 'Ouvrir la console',
                  size: PillSize.small,
                  onPressed: () async {
                    final ok = await launchUrl(_console, mode: LaunchMode.externalApplication);
                    if (!ok && context.mounted) Toasts.error(context, 'Impossible d\'ouvrir le navigateur.');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            label: 'Confidentialité',
            child: Text(
              'La clé reste sur ce téléphone, dans les fichiers privés de l\'appli ; une sauvegarde exportée depuis le profil la contient aussi. '
              'Chaque question part directement vers l\'API d\'Anthropic avec le résumé des données '
              'que tu as choisi de partager. Tu paies à l\'usage sur ton compte : quelques centimes par jour en usage normal.',
              style: AppType.rowSubtitle(),
            ),
          ),
        ],
      );
  }
}
