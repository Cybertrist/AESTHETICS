import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../data/health_link.dart';
import '../../widgets/maquette.dart';

/// Réglages > Santé : lien avec Health Connect.
class SanteSection extends StatefulWidget {
  const SanteSection({super.key});

  @override
  State<SanteSection> createState() => _SanteSectionState();
}

class _SanteSectionState extends State<SanteSection> with WidgetsBindingObserver {
  EtatSante? _etat;
  bool _historique = false;
  bool _occupe = false;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verifier();
  }

  Future<void> _verifier() async {
    final e = await HealthLink.etat();
    final h = e == EtatSante.autorise && await HealthLink.historiqueAutorise();
    if (!mounted) return;
    setState(() {
      _etat = e;
      _historique = h;
    });
    // Le réglage suit ce qu'Android dit vraiment.
    final repo = context.read<SettingsRepo>();
    final connecte = e == EtatSante.autorise;
    if (repo.settings.santeConnectee != connecte && e != EtatSante.indisponible) {
      await repo.update((s) => s.copyWith(santeConnectee: connecte));
    }
  }

  Future<void> _action(Future<void> Function() f) async {
    setState(() => _occupe = true);
    try {
      await f();
    } catch (e) {
      if (mounted) Toasts.error(context, 'Health Connect ne répond pas : $e');
    } finally {
      if (mounted) setState(() => _occupe = false);
      await _verifier();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = context.watch<SettingsRepo>();
    final etat = _etat;
    if (etat == null) return const SizedBox.shrink();

    final (String titre, String texte) = switch (etat) {
      EtatSante.autorise => ('Connecté', 'Aesthetics lit et écrit tes données de santé.'),
      EtatSante.disponible => ('Pas encore connecté', 'Autorise l\'accès pour récupérer pas, sommeil, poids et cœur.'),
      EtatSante.aMettreAJour => ('Mise à jour nécessaire', 'Health Connect doit être mis à jour avant de s\'y connecter.'),
      EtatSante.indisponible => ('Health Connect absent', HealthLink.supporte ? 'Installe Health Connect depuis le Play Store pour relier tes données.' : 'Disponible seulement sur Android.'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Bloc(
          haut: 2,
          bas: 6,
          child: Carte(
            padding: EdgeInsets.all(e(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Surtitre('Health Connect'),
                SizedBox(height: e(2)),
                Text(titre, style: txt(17, FontWeight.w700, c.text)),
                SizedBox(height: e(4)),
                Text(texte, style: txt(12, FontWeight.w400, c.text2)),
                SizedBox(height: e(12)),
                Row(
                  children: [
                    Expanded(
                      child: switch (etat) {
                        EtatSante.autorise => BoutonDuo(label: 'Ouvrir Santé', onPressed: () => context.push('/sante')),
                        EtatSante.disponible => BoutonDuo(
                            label: 'Autoriser l\'accès',
                            onPressed: _occupe
                                ? null
                                : () => _action(() async {
                                      final ok = await HealthLink.autoriser();
                                      if (mounted && !ok) Toasts.show(this.context, 'Certaines données n\'ont pas été autorisées.');
                                    }),
                          ),
                        EtatSante.aMettreAJour || EtatSante.indisponible => BoutonDuo(
                            label: etat == EtatSante.aMettreAJour ? 'Mettre à jour' : 'Installer',
                            onPressed: HealthLink.supporte && !_occupe ? () => _action(HealthLink.installer) : null,
                          ),
                      },
                    ),
                    if (etat == EtatSante.autorise) ...[
                      SizedBox(width: e(8)),
                      Expanded(
                        child: BoutonDuo(
                          label: 'Déconnecter',
                          secondaire: true,
                          onPressed: _occupe
                              ? null
                              : () async {
                                  final ok = await showConfirmDialog(
                                    context,
                                    title: 'Déconnecter Health Connect ?',
                                    message: 'Aesthetics ne lira plus tes données de santé. Ce qui est déjà importé reste dans l\'appli.',
                                    confirmLabel: 'Déconnecter',
                                    destructive: true,
                                  );
                                  if (ok) {
                                    await _action(HealthLink.revoquer);
                                    await settings.update((s) => s.copyWith(santeConnectee: false));
                                  }
                                },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (etat == EtatSante.autorise)
          GroupeTitre(
            lignes: [
              LigneBascule(
                trace: Trace.horloge,
                titre: 'Historique complet',
                detail: 'Lire plus de 30 jours en arrière',
                valeur: _historique,
                onChanged: (v) {
                  if (!v) {
                    Toasts.show(context, 'Retire cet accès depuis Health Connect.');
                    return;
                  }
                  _action(() async {
                    await HealthLink.autoriserHistorique();
                  });
                },
              ),
            ],
          ),
        GroupeTitre(
          titre: 'Données partagées',
          lignes: [
            for (final d in HealthLink.donnees)
              Ligne(
                icone: Icon(d.icon, size: e(16), color: c.text.withValues(alpha: etat == EtatSante.autorise ? 0.85 : 0.4)),
                titre: d.label,
                valeur: d.acces.name == 'READ' ? 'Lecture' : 'Lecture et écriture',
              ),
          ],
          note: 'Les données passent directement entre Health Connect et ton téléphone, sans serveur.',
        ),
      ],
    );
  }
}
