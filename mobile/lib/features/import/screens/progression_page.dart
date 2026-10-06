import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/import_flow.dart';
import '../widgets/import_widgets.dart';

/// `/import/progression` : l'import en train de se faire.
class ProgressionPage extends StatefulWidget {
  const ProgressionPage({super.key});

  @override
  State<ProgressionPage> createState() => _ProgressionPageState();
}

class _ProgressionPageState extends State<ProgressionPage> {
  final flow = ImportFlow.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lancer());
  }

  Future<void> _lancer() async {
    if (flow.preview == null || flow.importEnCours) return;
    final data = context.read<AppData>();
    // Après un échec, on relit le fichier pour marquer ce qui a déjà été ajouté.
    if (flow.erreurImport != null) await flow.analyser(data);
    final res = await flow.importer(data);
    if (!mounted || res == null) return;
    context.pushReplacement('/import/resume');
  }

  @override
  Widget build(BuildContext context) {
    if (flow.preview == null && flow.resultat == null) return const SansFichier(titre: 'Import');
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        final c = context.colors;
        final erreur = flow.erreurImport;
        return PopScope(
          canPop: !flow.importEnCours,
          child: PageImport(
            title: 'Import',
            subtitle: flow.nomFichier,
            onBack: flow.importEnCours ? () => Toasts.show(context, 'Patiente quelques secondes, l\'import se termine.') : null,
            bottomBar: erreur == null
                ? null
                : Row(
                    children: [
                      Expanded(child: PillButton.secondary(label: 'Retour', onPressed: () => context.pop())),
                      const SizedBox(width: 10),
                      Expanded(child: PillButton(label: 'Réessayer', icon: Icons.refresh_rounded, onPressed: _lancer)),
                    ],
                  ),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const EtapesImport(courante: 4),
                const SizedBox(height: 24),
                Center(
                  child: ProgressRing(
                    value: flow.progression,
                    size: 190,
                    stroke: 12,
                    color: erreur == null ? c.text : c.error,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(flow.progression * 100).round()} %', style: AppType.number(40)),
                        Text(erreur == null ? 'importé' : 'interrompu', style: AppType.rowSubtitle()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                padded(Text(
                  erreur == null ? flow.etape : 'L\'import s\'est arrêté',
                  textAlign: TextAlign.center,
                  style: AppType.rowTitle().copyWith(fontSize: 17),
                )),
                const SizedBox(height: 6),
                padded(Text(
                  erreur == null
                      ? '${Fmt.pluriel(flow.rapport?.seances ?? 0, 'séance')} en cours d\'enregistrement. Ne ferme pas l\'appli.'
                      : 'Relance l\'import ou reviens aux options. Les séances déjà ajoutées seront reconnues comme doublons.',
                  textAlign: TextAlign.center,
                  style: AppType.rowSubtitle(),
                )),
                if (erreur != null) ...[
                  const SizedBox(height: 18),
                  padded(Encart(ton: TonEncart.erreur, texte: erreur)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
