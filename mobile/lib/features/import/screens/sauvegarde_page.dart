import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/exporters.dart';
import '../data/fichiers.dart';
import '../data/sauvegarde.dart';
import '../widgets/import_widgets.dart';

/// Collection qui retient la date de la dernière sauvegarde.
const _derniere = 'import_derniere_sauvegarde';

/// Sauvegarde lue, en attente de confirmation (page de restauration).
SauvegardeLue? sauvegardeEnAttente;
String? nomSauvegardeEnAttente;

/// `/import/sauvegarde` : créer ou restaurer une sauvegarde.
class SauvegardePage extends StatefulWidget {
  const SauvegardePage({super.key});

  @override
  State<SauvegardePage> createState() => _SauvegardePageState();
}

class _SauvegardePageState extends State<SauvegardePage> {
  bool _complete = true;
  String? _action;
  late Future<({int fichiers, int octets})> _medias = Sauvegarde.medias(context.read<AppData>());
  late Future<Map<String, dynamic>?> _der = context.read<Store>().readObject(_derniere);

  Future<void> _creer(String action) async {
    final data = context.read<AppData>();
    setState(() => _action = action);
    try {
      final octets = _complete ? await Sauvegarde.complete(data) : await Sauvegarde.json(data);
      final nom = Exporteurs.nomFichier('sauvegarde', _complete ? 'zip' : 'json');
      final mime = _complete ? Mime.zip : Mime.json;
      final ok = action == 'partager'
          ? await Fichiers.courant.partager(nom, octets, mime, sujet: 'Sauvegarde Aesthetics')
          : await Fichiers.courant.enregistrer(nom, octets, mime);
      if (!mounted) return;
      if (ok) {
        await data.store.write(_derniere, {'date': DateTime.now().toIso8601String(), 'complete': _complete, 'taille': octets.length});
        if (!mounted) return;
        Toasts.success(context, 'Sauvegarde prête (${tailleLisible(octets.length)})');
        setState(() => _der = data.store.readObject(_derniere));
      }
    } catch (e) {
      if (mounted) Toasts.error(context, 'Sauvegarde impossible : $e');
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  Future<void> _restaurer() async {
    setState(() => _action = 'restaurer');
    try {
      final f = await Fichiers.courant.choisir();
      if (f == null || !mounted) return;
      final lue = Sauvegarde.lire(f.octets);
      sauvegardeEnAttente = lue;
      nomSauvegardeEnAttente = f.nom;
      await context.push('/import/sauvegarde/restaurer');
      if (mounted) {
        setState(() {
          _medias = Sauvegarde.medias(context.read<AppData>());
          _der = context.read<Store>().readObject(_derniere);
        });
      }
    } on SauvegardeInvalide catch (e) {
      if (mounted) Toasts.error(context, e.message);
    } catch (_) {
      if (mounted) Toasts.error(context, 'Ce fichier n\'a pas pu être lu.');
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final aDesDonnees = context.watch<ProfileRepo>().hasProfile;
    final seances = context.watch<SessionRepo>().sessions.length;
    final busy = _action != null;

    final creer = <Widget>[
      const SectionHeader(title: 'Créer une sauvegarde'),
      FutureBuilder<Map<String, dynamic>?>(
        future: _der,
        builder: (context, snap) {
          final d = DateTime.tryParse('${snap.data?['date']}');
          return padded(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Encart(
              ton: d == null || DateTime.now().difference(d).inDays > 30 ? TonEncart.attention : TonEncart.succes,
              titre: d == null ? 'Aucune sauvegarde pour l\'instant' : 'Dernière sauvegarde ${Fmt.ilYa(d)}',
              texte: d == null
                  ? 'Tes données ne vivent que sur ce téléphone. Une sauvegarde régulière évite de tout perdre.'
                  : 'Le ${Fmt.date(d)} à ${Fmt.heure(d)}${snap.data?['taille'] is num ? ', ${tailleLisible((snap.data!['taille'] as num).toInt())}' : ''}.',
            ),
          ));
        },
      ),
      padded(FutureBuilder<({int fichiers, int octets})>(
        future: _medias,
        builder: (context, snap) {
          final m = snap.data;
          return Column(
            children: [
              CarteChoix(
                titre: 'Sauvegarde complète',
                description: m == null
                    ? 'Données et photos, dans une archive ZIP'
                    : 'Données et ${Fmt.pluriel(m.fichiers, 'photo')} (${tailleLisible(m.octets)}), dans une archive ZIP',
                icon: Icons.inventory_2_rounded,
                selectionne: _complete,
                onTap: () => setState(() => _complete = true),
              ),
              CarteChoix(
                titre: 'Données seules',
                description: 'Un fichier JSON léger, sans les photos',
                icon: Icons.data_object_rounded,
                selectionne: !_complete,
                onTap: () => setState(() => _complete = false),
              ),
            ],
          );
        },
      )),
      padded(Row(
        children: [
          Expanded(
            child: PillButton.secondary(
              label: 'Enregistrer',
              icon: Icons.save_alt_rounded,
              loading: _action == 'enregistrer',
              onPressed: busy ? null : () => _creer('enregistrer'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PillButton(
              label: 'Partager',
              icon: Icons.ios_share_rounded,
              loading: _action == 'partager',
              onPressed: busy ? null : () => _creer('partager'),
            ),
          ),
        ],
      )),
      const SizedBox(height: 8),
      padded(Text(
        'Partager permet de l\'envoyer sur Google Drive, par mail ou vers un ordinateur. Contient ${Fmt.pluriel(seances, 'séance')}, tes mesures, ton sommeil, ta nutrition, tes réglages et tes conversations avec le coach.',
        style: AppType.rowSubtitle(),
      )),
    ];

    final restaurer = <Widget>[
      const SectionHeader(title: 'Restaurer'),
      padded(AppCard(
        onTap: busy ? null : _restaurer,
        padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
        child: ListTileX(
          padding: ListTileX.cardPadding,
          leading: IconHalo(icon: Icons.settings_backup_restore_rounded),
          title: 'Choisir une sauvegarde',
          subtitle: 'Fichier .zip ou .json créé par Aesthetics',
          trailing: _action == 'restaurer' ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.text)) : null,
          showChevron: _action != 'restaurer',
        ),
      )),
      const SizedBox(height: 10),
      padded(Text(
        'Tu verras son contenu avant de confirmer. La restauration remplace toutes les données de ce téléphone.',
        style: AppType.rowSubtitle(),
      )),
    ];

    return PageImport(
      title: 'Exporter une sauvegarde',
      subtitle: 'Garder ou transférer toutes tes données',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (aDesDonnees) DeuxVolets(gauche: creer, droite: restaurer) else ...restaurer,
        ],
      ),
    );
  }
}

/// `/import/sauvegarde/restaurer` : contenu de la sauvegarde puis confirmation.
class RestaurerPage extends StatefulWidget {
  const RestaurerPage({super.key});

  @override
  State<RestaurerPage> createState() => _RestaurerPageState();
}

enum _Etat { apercu, enCours, fini, erreur }

class _RestaurerPageState extends State<RestaurerPage> {
  _Etat _etat = _Etat.apercu;
  String? _erreur;

  Future<void> _confirmer(SauvegardeLue s) async {
    final aDesDonnees = context.read<ProfileRepo>().hasProfile;
    if (aDesDonnees) {
      final ok = await showConfirmDialog(
        context,
        title: 'Remplacer toutes tes données ?',
        message: 'Tout ce qui est sur ce téléphone sera remplacé par la sauvegarde. Cette action ne peut pas être annulée.',
        confirmLabel: 'Restaurer',
        destructive: true,
        icon: Icons.warning_amber_rounded,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _etat = _Etat.enCours);
    try {
      await Sauvegarde.restaurer(context.read<AppData>(), s);
      sauvegardeEnAttente = null;
      if (mounted) setState(() => _etat = _Etat.fini);
    } catch (e) {
      if (mounted) {
        setState(() {
          _etat = _Etat.erreur;
          _erreur = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = sauvegardeEnAttente;
    final c = context.colors;
    if (_etat == _Etat.fini) {
      return PopScope(
        canPop: false,
        child: PageImport(
          title: 'Restauration',
          bottomBar: PillButton(
            label: 'Ouvrir l\'appli',
            trailingIcon: Icons.arrow_forward_rounded,
            expand: true,
            size: PillSize.large,
            onPressed: () => context.go(context.read<ProfileRepo>().hasProfile ? '/' : '/bienvenue'),
          ),
          body: const Center(
            child: EmptyState(
              icon: Icons.check_rounded,
              title: 'Données restaurées',
              message: 'Tes séances, mesures, réglages et photos sont de retour.',
            ),
          ),
        ),
      );
    }
    if (s == null) {
      return PageImport(
        title: 'Restaurer',
        body: EmptyState(
          icon: Icons.settings_backup_restore_rounded,
          title: 'Aucune sauvegarde choisie',
          message: 'Choisis d\'abord le fichier de sauvegarde.',
          actionLabel: 'Retour',
          onAction: () => context.canPop() ? context.pop() : context.go('/import/sauvegarde'),
        ),
      );
    }
    final comptes = s.comptes.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final enCours = _etat == _Etat.enCours;
    return PopScope(
      canPop: !enCours,
      child: PageImport(
        title: 'Restaurer',
        subtitle: nomSauvegardeEnAttente,
        bottomBar: PillButton(
          label: enCours ? 'Restauration…' : 'Restaurer cette sauvegarde',
          icon: Icons.settings_backup_restore_rounded,
          expand: true,
          size: PillSize.large,
          loading: enCours,
          onPressed: enCours ? null : () => _confirmer(s),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: BigNumber(
                label: 'Séances dans la sauvegarde',
                value: Fmt.n(s.seances, decimals: 0),
                caption: s.date == null ? 'Date inconnue' : 'Créée le ${Fmt.date(s.date!)} à ${Fmt.heure(s.date!)}',
                footer: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TagPill(s.complete ? 'Complète' : 'Données seules', icon: s.complete ? Icons.inventory_2_rounded : Icons.data_object_rounded, color: c.text),
                    if (s.medias.isNotEmpty) TagPill(Fmt.pluriel(s.medias.length, 'photo'), icon: Icons.photo_library_outlined, color: c.text2),
                    if (s.aProfil) TagPill('Profil inclus', icon: Icons.person_outline_rounded, color: c.text2),
                  ],
                ),
              ),
            ),
            if (_etat == _Etat.erreur)
              padded(Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Encart(ton: TonEncart.erreur, titre: 'La restauration a échoué', texte: _erreur ?? ''),
              )),
            padded(const Encart(
              ton: TonEncart.attention,
              titre: 'Tout sera remplacé',
              texte: 'Les données actuelles de ce téléphone seront effacées et remplacées par celles de la sauvegarde.',
            )),
            TileGroup(
              margin: const EdgeInsets.fromLTRB(AppTokens.gutter, 16, AppTokens.gutter, 0),
              label: 'Contenu',
              children: [
                if (comptes.isEmpty)
                  const ListTileX(title: 'Sauvegarde vide', subtitle: 'Seulement des réglages.')
                else
                  for (final e in comptes)
                    ListTileX(
                      dense: true,
                      title: libellesCollections[e.key] ?? e.key,
                      value: Fmt.n(e.value, decimals: 0),
                    ),
              ],
            ),
            if (context.watch<ProfileRepo>().hasProfile) ...[
              const SizedBox(height: 14),
              padded(AccentLink(
                label: 'Sauvegarder d\'abord mes données actuelles',
                icon: Icons.backup_rounded,
                onTap: () => context.pop(),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
