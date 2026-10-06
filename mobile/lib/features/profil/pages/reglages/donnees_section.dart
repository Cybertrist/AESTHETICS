import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/env.dart';
import '../../data/backup_service.dart';
import '../../widgets/maquette.dart';

/// Réglages > Données : importer, exporter, sauvegarder, restaurer, effacer.
class DonneesSection extends StatefulWidget {
  const DonneesSection({super.key});

  /// Ce que contient l'export : seuls les modules visibles sont cités.
  static const detailExport = Env.muscuSeule
      ? 'Séances et mesures en CSV ou JSON, pour un tableur ou une autre appli'
      : 'Séances, mesures, sommeil, repas en CSV ou JSON, pour un tableur ou une autre appli';

  /// Ce que « Tout effacer » emporte.
  static const detailEffacer = Env.muscuSeule
      ? 'Profil, séances, mesures, photos : l\'appli repart de zéro'
      : 'Profil, séances, repas, mesures : l\'appli repart de zéro';

  @override
  State<DonneesSection> createState() => _DonneesSectionState();
}

class _DonneesSectionState extends State<DonneesSection> {
  late Future<(int, List<SauvegardeLocale>)> _infos = _charger();

  Future<(int, List<SauvegardeLocale>)> _charger() async {
    final data = context.read<AppData>();
    final taille = await BackupService(data).tailleDonnees();
    final locales = await BackupService.sauvegardesLocales();
    return (taille, locales);
  }

  void _rafraichir() => setState(() => _infos = _charger());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions.length;
    final routines = context.watch<RoutineRepo>().routines.length;
    final mesures = context.watch<HealthRepo>().measurements.length;

    return FutureBuilder<(int, List<SauvegardeLocale>)>(
      future: _infos,
      builder: (context, snap) {
        final taille = snap.data?.$1;
        final locales = snap.data?.$2 ?? const [];
        final derniere = locales.firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Bloc(
              haut: 2,
              bas: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Surtitre('Sur ce téléphone')),
                      Text(taille == null ? (snap.hasError ? 'taille inconnue' : '') : formatOctets(taille), style: txt(11, FontWeight.w400, c.text2)),
                    ],
                  ),
                  SizedBox(height: e(6)),
                  Row(
                    children: [
                      Expanded(child: TuileChiffre(valeur: '$sessions', label: sessions >= 2 ? 'séances' : 'séance')),
                      SizedBox(width: e(8)),
                      Expanded(child: TuileChiffre(valeur: '$routines', label: routines >= 2 ? 'routines' : 'routine')),
                      SizedBox(width: e(8)),
                      Expanded(child: TuileChiffre(valeur: '$mesures', label: mesures >= 2 ? 'mesures' : 'mesure')),
                    ],
                  ),
                ],
              ),
            ),
            GroupeTitre(
              titre: 'Mettre mes données à l\'abri',
              lignes: [
                Ligne(
                  trace: Trace.donnees,
                  titre: 'Faire une sauvegarde',
                  detail: 'Un fichier avec tout, photos comprises, à garder ailleurs que sur ce téléphone',
                  detailLignes: 2,
                  onTap: () => context.push('/import/sauvegarde'),
                ),
                Ligne(
                  trace: Trace.restaurer,
                  titre: 'Restaurer une sauvegarde',
                  detail: 'Remettre un fichier de sauvegarde : il remplace les données actuelles',
                  detailLignes: 2,
                  onTap: () => context.push('/import/sauvegarde'),
                ),
                Ligne(
                  trace: Trace.boite,
                  titre: 'Copies du téléphone',
                  detail: derniere == null
                      ? 'Copies rapides, sans les photos. Aucune pour l\'instant'
                      : 'Copies rapides, sans les photos. Dernière : ${Fmt.relatif(derniere.date).toLowerCase()} à ${Fmt.heure(derniere.date)}',
                  detailLignes: 2,
                  valeur: snap.hasData ? '${locales.length}' : null,
                  onTap: () async {
                    await context.push('/reglages/donnees/sauvegardes');
                    _rafraichir();
                  },
                ),
              ],
            ),
            GroupeTitre(
              titre: 'Venir d\'une autre appli',
              lignes: [
                Ligne(
                  trace: Trace.importer,
                  titre: 'Importer mes séances',
                  detail: 'Depuis le fichier CSV exporté par ton ancienne appli',
                  detailLignes: 2,
                  onTap: () => context.push('/import'),
                ),
                Ligne(
                  trace: Trace.horloge,
                  titre: 'Imports précédents',
                  detail: 'Revoir ou annuler un import',
                  onTap: () => context.push('/import/journal'),
                ),
              ],
            ),
            GroupeTitre(
              titre: 'Utiliser mes données ailleurs',
              lignes: [
                Ligne(
                  trace: Trace.exporter,
                  titre: 'Exporter en tableau',
                  detail: DonneesSection.detailExport,
                  detailLignes: 2,
                  onTap: () => context.push('/import/export'),
                ),
              ],
            ),
            GroupeTitre(
              titre: 'Zone sensible',
              lignes: [
                Ligne(
                  trace: Trace.poubelle,
                  titre: 'Tout effacer',
                  couleurTitre: c.error,
                  detail: DonneesSection.detailEffacer,
                  detailLignes: 2,
                  onTap: () => context.push('/reglages/donnees/effacer'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Montre le contenu d'une sauvegarde et demande confirmation avant de
/// remplacer les données. Faux si le fichier est invalide ou refusé.
Future<bool> confirmerRestauration(BuildContext context, String raw) async {
  final ResumeSauvegarde r;
  try {
    r = BackupService.lire(raw);
  } on FormatException catch (e) {
    await showConfirmDialog(context, title: 'Fichier refusé', message: e.message, confirmLabel: 'Compris', cancelLabel: 'Fermer', icon: Icons.error_outline_rounded, destructive: true);
    return false;
  }
  if (!context.mounted) return false;
  final details = [
    if (r.date != null) 'Faite le ${Fmt.date(r.date!)} à ${Fmt.heure(r.date!)}',
    if (r.prenom != null && r.prenom!.isNotEmpty) 'Profil de ${r.prenom}',
    Fmt.pluriel(r.seances, 'séance'),
  ].join('\n');
  return showConfirmDialog(
    context,
    title: 'Restaurer cette sauvegarde ?',
    message: '$details\n\nToutes les données actuelles seront remplacées.',
    confirmLabel: 'Restaurer',
    destructive: true,
    icon: Icons.restore_rounded,
  );
}
