import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../data/import_flow.dart';
import '../data/import_journal.dart';
import '../data/repo_extensions.dart';
import '../../profil/widgets/maquette.dart';

/// `/import` : importer un historique (l'export et la sauvegarde sont dans les Réglages).
class ImportAccueilPage extends StatefulWidget {
  const ImportAccueilPage({super.key, this.retour});

  /// Où revenir à la fin d'un import (l'inscription par exemple).
  final String? retour;

  @override
  State<ImportAccueilPage> createState() => _ImportAccueilPageState();
}

class _ImportAccueilPageState extends State<ImportAccueilPage> {
  late Future<List<ImportJournalEntry>> _journal;

  @override
  void initState() {
    super.initState();
    _journal = ImportJournal.lire(context.read<Store>());
  }

  void _recharger() => setState(() => _journal = ImportJournal.lire(context.read<Store>()));

  Future<void> _importer(ImportSource s) async {
    ImportFlow.instance.demarrer(s, retour: widget.retour);
    await context.push('/import/fichier');
    if (mounted) _recharger();
  }

  Future<void> _ouvrir(String chemin) async {
    await context.push(chemin);
    if (mounted) _recharger();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionRepo>();
    final total = sessions.sessions.length;
    final importees = sessions.seancesImportees.length;
    final sansProfil = !context.watch<ProfileRepo>().hasProfile;

    return PageMaquette(
      titre: 'Importer mes séances',
      enfants: [
        GroupeTitre(
          premier: true,
          titre: 'D\'où vient ton historique ?',
          note: total == 0
              ? 'Ramène ton historique pour retrouver tes records dès le premier jour.'
              : importees == 0
                  ? '${Fmt.pluriel(total, 'séance enregistrée', 'séances enregistrées')}, toutes faites dans l\'appli.'
                  : '${Fmt.pluriel(total, 'séance enregistrée', 'séances enregistrées')}, dont ${Fmt.pluriel(importees, 'importée', 'importées')}.',
          lignes: [
            Ligne(
              trace: Trace.importer,
              titre: 'Mon ancienne appli',
              detail: 'Son export CSV : séances, séries, charges',
              detailLignes: 2,
              onTap: () => _importer(ImportSource.application),
            ),
            Ligne(
              trace: Trace.document,
              titre: 'Un tableau CSV',
              detail: 'Tu indiques quelle colonne contient quoi',
              detailLignes: 2,
              onTap: () => _importer(ImportSource.tableau),
            ),
            Ligne(
              trace: Trace.info,
              titre: 'Fichiers acceptés',
              detail: 'Formats, colonnes, unités et dates',
              onTap: () => _ouvrir('/import/aide'),
            ),
          ],
        ),
        if (sansProfil)
          GroupeTitre(
            titre: 'Tu avais déjà l\'appli ?',
            lignes: [
              Ligne(
                trace: Trace.restaurer,
                titre: 'Restaurer une sauvegarde',
                detail: 'Faite sur un autre téléphone',
                onTap: () => _ouvrir('/import/sauvegarde/restaurer'),
              ),
            ],
          ),
        FutureBuilder<List<ImportJournalEntry>>(
          future: _journal,
          builder: (context, snap) {
            final list = snap.data ?? const <ImportJournalEntry>[];
            if (list.isEmpty) return const SizedBox();
            return GroupeTitre(
              titre: 'Imports précédents',
              note: 'Chaque import peut être revu ou annulé.',
              lignes: [
                for (final e in list.take(3))
                  Ligne(
                    trace: Trace.horloge,
                    titre: e.fichier,
                    detail: '${Fmt.relatif(e.date)} · ${Fmt.pluriel(e.seanceIds.length, 'séance')}',
                    onTap: () => _ouvrir('/import/journal/${e.id}'),
                  ),
                if (list.length > 3)
                  Ligne(trace: Trace.horloge, titre: 'Tous les imports', onTap: () => _ouvrir('/import/journal')),
              ],
            );
          },
        ),
      ],
    );
  }
}
