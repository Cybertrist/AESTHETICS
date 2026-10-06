import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/fichiers.dart';
import '../data/import_flow.dart';
import '../widgets/import_widgets.dart';

/// `/import/fichier` : choix du fichier puis analyse.
class FichierPage extends StatefulWidget {
  const FichierPage({super.key});

  @override
  State<FichierPage> createState() => _FichierPageState();
}

class _FichierPageState extends State<FichierPage> {
  final flow = ImportFlow.instance;
  bool _ouverture = false;

  /// Sauvegarde Aesthetics choisie par erreur ici.
  bool _sauvegarde = false;

  Future<void> _choisir() async {
    setState(() {
      _ouverture = true;
      _sauvegarde = false;
    });
    FichierLu? f;
    try {
      f = await Fichiers.courant.choisir();
    } catch (_) {
      if (mounted) Toasts.error(context, 'Impossible d\'ouvrir le sélecteur de fichiers.');
    }
    if (!mounted) return;
    setState(() => _ouverture = false);
    if (f == null) return;
    final ext = f.nom.contains('.') ? f.nom.split('.').last.toLowerCase() : '';
    if (ext == 'json' || (ext == 'zip' && f.nom.toLowerCase().contains('aesthetic'))) {
      setState(() => _sauvegarde = true);
      return;
    }
    final data = context.read<AppData>();
    await flow.chargerFichier(f.nom, f.octets, data);
    if (!mounted || flow.etat != EtatAnalyse.pret) return;
    _suite();
  }

  void _suite() {
    context.push(flow.besoinColonnes ? '/import/colonnes' : '/import/apercu');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        final analyse = flow.etat == EtatAnalyse.analyse;
        return SubPageScaffold(
          title: 'Importer un historique',
          subtitle: flow.source.label,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const EtapesImport(courante: 0),
              padded(
                SegmentedControl<ImportSource>(
                  segments: const [
                    (ImportSource.application, 'Autre application'),
                    (ImportSource.tableau, 'Tableau'),
                  ],
                  value: flow.source,
                  onChanged: analyse ? (_) {} : (s) => setState(() => flow.source = s),
                ),
              ),
              const SizedBox(height: 16),
              padded(_zone(context, analyse)),
              const SizedBox(height: 14),
              if (_sauvegarde)
                padded(Encart(
                  ton: TonEncart.attention,
                  titre: 'C\'est une sauvegarde Aesthetics',
                  texte: 'Ce fichier se restaure depuis la page Sauvegarde, pas depuis l\'import d\'historique.',
                  action: PillButton.link(label: 'Aller à la restauration', onPressed: () => context.push('/import/sauvegarde')),
                ))
              else if (flow.etat == EtatAnalyse.erreur)
                padded(Encart(
                  ton: TonEncart.erreur,
                  titre: 'Lecture impossible',
                  texte: flow.erreur ?? 'Le fichier n\'a pas pu être lu.',
                  action: PillButton.link(label: 'Voir les fichiers acceptés', onPressed: () => context.push('/import/aide?depuis=fichier')),
                ))
              else if (flow.etat == EtatAnalyse.pret && flow.nomFichier != null)
                padded(AppCard(
                  label: 'Fichier analysé',
                  child: ListTileX(
                    padding: ListTileX.cardPadding,
                    leading: IconHalo(icon: Icons.description_rounded),
                    title: flow.nomFichier!,
                    subtitle: '${tailleLisible(flow.taille ?? 0)} · ${flow.rapport?.seances ?? 0} séances trouvées',
                    showChevron: true,
                    onTap: _suite,
                  ),
                )),
              const SizedBox(height: 8),
              SectionHeader(title: flow.source == ImportSource.application ? 'Où trouver le fichier' : 'Ce qu\'il faut dans le tableau'),
              padded(AppCard(
                child: Column(
                  children: [
                    for (final (i, t) in (flow.source == ImportSource.application ? _conseilsAppli : _conseilsTableau).indexed)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                              child: Text('${i + 1}', style: AppType.rowValue(color: c.text).copyWith(fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(t, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 13.5))),
                          ],
                        ),
                      ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              padded(Align(
                alignment: Alignment.centerLeft,
                child: AccentLink(label: 'Détail des formats acceptés', icon: Icons.help_outline_rounded, onTap: () => context.push('/import/aide?depuis=fichier')),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _zone(BuildContext context, bool analyse) {
    final c = context.colors;
    return AppCard(
      onTap: analyse || _ouverture ? null : _choisir,
      border: true,
      borderColor: c.text3,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          if (analyse)
            SizedBox(width: 42, height: 42, child: CircularProgressIndicator(strokeWidth: 3, color: c.text))
          else
            IconHalo(icon: Icons.upload_file_rounded, size: 52),
          const SizedBox(height: 16),
          Text(
            analyse ? 'Analyse de ${flow.nomFichier ?? 'ton fichier'}' : 'Choisir un fichier CSV',
            textAlign: TextAlign.center,
            style: AppType.rowTitle().copyWith(fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            analyse
                ? 'Lecture des séances et rapprochement des exercices…'
                : 'Depuis le téléphone, Google Drive ou tes téléchargements',
            textAlign: TextAlign.center,
            style: AppType.rowSubtitle(),
          ),
          if (!analyse) ...[
            const SizedBox(height: 18),
            PillButton(
              label: flow.aUnFichier ? 'Choisir un autre fichier' : 'Parcourir',
              icon: Icons.folder_open_rounded,
              loading: _ouverture,
              onPressed: _ouverture ? null : _choisir,
            ),
          ],
        ],
      ),
    );
  }

  static const _conseilsAppli = [
    'Dans ton ancienne appli, ouvre les réglages ou ton profil et cherche « Exporter les données » ou « Exporter en CSV ».',
    'Enregistre le fichier sur le téléphone ou envoie-le toi par mail, puis reviens ici.',
    'Le format est reconnu tout seul : séances, séries, charges, répétitions, échauffements et supersets.',
  ];

  static const _conseilsTableau = [
    'Une ligne par série, avec au moins la date, le nom de l\'exercice et une charge, des répétitions, une durée ou une distance.',
    'Dans ton tableur, choisis « Enregistrer sous » puis le format CSV.',
    'Tu associeras ensuite chaque colonne à ce qu\'elle contient.',
  ];
}
