import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/env.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/accueil.dart';
import '../logic/pas_repo.dart';
import '../routes.dart';
import '../widgets/accueil.dart';
import '../widgets/cartes.dart';

/// Onglet Accueil : la série et la cloche, le résumé du mois (du 1er au 3),
/// la semaine en cours, puis les dernières séances.
class AujourdhuiPage extends StatefulWidget {
  const AujourdhuiPage({super.key, this.maintenant, this.horloge, this.nbSeances = 5});

  /// Horloge figée (tests de rendu) ; l'heure réelle sinon.
  final DateTime? maintenant;

  /// Horloge de remplacement, relue à chaque construction (tests).
  final DateTime Function()? horloge;

  /// Nombre de séances affichées.
  final int nbSeances;

  @override
  State<AujourdhuiPage> createState() => _AujourdhuiPageState();
}

class _AujourdhuiPageState extends State<AujourdhuiPage> with WidgetsBindingObserver {
  /// L'alerte « fichier illisible » a été lue et refermée.
  bool _alerteFermee = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!Env.muscuSeule) WidgetsBinding.instance.addPostFrameCallback((_) => _synchroPas());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// L'appli revient au premier plan, parfois des jours plus tard : la date,
  /// la semaine et la carte bleue se recalculent.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Future<void> _synchroPas() async {
    if (!mounted) return;
    final sante = context.read<SettingsRepo>().settings.santeConnectee;
    final repo = PasRepo.pour(context.read<Store>());
    await repo.pret;
    if (!sante && repo.derniereSynchro == null) return;
    await repo.synchroniserSiAncien();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = widget.horloge?.call() ?? widget.maintenant ?? DateTime.now();
    final sessions = context.watch<SessionRepo>();
    final terminees = sessions.sessions.where((s) => s.fin != null).toList();
    final recentes = terminees.take(widget.nbSeances).toList();
    final records = recordsParSeance(sessions.sessions);
    final mois = moisDuResume(now, sessions.sessions);
    final large = MediaQuery.sizeOf(context).width >= 700;
    final mq = MediaQuery.paddingOf(context);
    const ecart = SizedBox(height: 25);

    final gauche = <Widget>[
      if (mois != null) ...[
        CarteResumeMensuel(
          mois: libelleMois(mois),
          onTap: () => context.push(AujourdhuiPaths.bilanMois('${mois.year}-${mois.month}')),
        ),
        ecart,
      ],
      CarteCetteSemaine(maintenant: now),
      if (!Env.muscuSeule) ...[
        ecart,
        const CarteCoach(),
        const SizedBox(height: 12),
        const CarteNutrition(),
        const SizedBox(height: 12),
        const GrilleSante(),
      ],
    ];
    final droite = <Widget>[
      TitreDernieresSeances(lien: terminees.isNotEmpty),
      const SizedBox(height: 11.5),
      if (recentes.isEmpty)
        const AccueilVide()
      else
        for (final (i, s) in recentes.indexed) ...[
          if (i > 0) const SizedBox(height: 12.5),
          CarteSeance(session: s, records: records[s.id] ?? 0, maintenant: now),
        ],
    ];

    final abimes = fichiersAbimes(context.read<Store>(), context.read<AppData?>());
    final alerte = abimes.isNotEmpty && !_alerteFermee;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: large ? 1100 : 560),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.fromLTRB(CotesAccueil.marge, mq.top + 12.5, CotesAccueil.marge, 32),
                children: [
                  EnTeteAccueil(maintenant: now),
                  if (alerte) ...[
                    ecart,
                    AlerteDonnees(fichiers: abimes, onFermer: () => setState(() => _alerteFermee = true)),
                  ],
                  ecart,
                  if (large)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gauche)),
                        const SizedBox(width: 22),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: droite)),
                      ],
                    )
                  else ...[
                    ...gauche,
                    const SizedBox(height: 22.5),
                    ...droite,
                  ],
                ],
              ),
            ),
          ),
          // Zone haute opaque : le contenu ne défile pas sous l'heure et
          // les icônes du système.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mq.top,
            child: IgnorePointer(child: ColoredBox(key: const ValueKey('zone-haute'), color: c.bg)),
          ),
        ],
      ),
    );
  }
}
