import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../profil/widgets/ecusson.dart';
import '../../social/data/social_repo.dart';
import '../../social/pages/communaute_page.dart' show LigneDemande;
import '../../social/routes.dart';
import '../../social/widgets/elements.dart';
import '../../social/widgets/reaction.dart';
import '../logic/accueil.dart';
import '../routes.dart';
import '../widgets/accueil.dart' show ouvrirSeance;

/// Les notifications, ouvertes par la cloche de l'accueil : les demandes
/// d'amis en tête, puis ce que mes amis ont fait et mes propres nouvelles
/// (records, bilans, objectif), rangés du plus récent au plus ancien.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.maintenant});

  /// L'heure qu'il est ; fixée dans les tests.
  final DateTime? maintenant;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

/// Les filtres en haut de la page. « Toutes » montre aussi mes bilans et
/// mon objectif de la semaine, qui n'ont pas de filtre à eux.
enum _Filtre {
  toutes('Toutes'),
  reactions('Réactions'),
  commentaires('Commentaires'),
  amis('Amis'),
  records('Records');

  const _Filtre(this.label);
  final String label;
}

class _NotificationsPageState extends State<NotificationsPage> {
  _Filtre _filtre = _Filtre.toutes;

  late final DateTime _maintenant = widget.maintenant ?? DateTime.now();

  /// La dernière ouverture d'avant celle-ci : ce qui est plus récent porte
  /// un point jusqu'à ce qu'on quitte la page.
  DateTime? _vuAvant;
  bool _pret = false;

  @override
  void initState() {
    super.initState();
    final cloche = ClocheRepo.pour(context.read<Store>());
    cloche.pret.then((_) {
      if (!mounted) return;
      setState(() {
        _vuAvant = cloche.vuLe;
        _pret = true;
      });
      cloche.marquerVu(_maintenant);
    });
  }

  bool _nouvelle(DateTime d) => _pret && (_vuAvant == null || d.isAfter(_vuAvant!));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>();
    final settings = context.watch<SettingsRepo>().settings;
    final social = context.watch<SocialRepo?>();
    final miennes = nouveautes(
      sessions: sessions.sessions,
      now: _maintenant,
      objectif: context.watch<ProfileRepo>().profile?.joursParSemaine ?? 3,
      premierJour: settings.premierJourSemaine,
    );
    final amis = activitesAmis(social, sessions.sessions);
    final demandes = social?.demandes ?? const <Ami>[];
    final toutes = <(DateTime, _Filtre?, Widget)>[
      for (final n in miennes) (n.date, n.cible == CibleNouveaute.seance ? _Filtre.records : null, _LigneMienne(n, nouvelle: _nouvelle(n.date), maintenant: _maintenant)),
      for (final a in amis)
        (
          a.date,
          switch (a.type) {
            TypeActivite.reaction => _Filtre.reactions,
            TypeActivite.commentaire => _Filtre.commentaires,
            TypeActivite.accepte => _Filtre.amis,
            TypeActivite.record => _Filtre.records,
          },
          _LigneAmi(a, nouvelle: _nouvelle(a.date), maintenant: _maintenant),
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final lignes = [
      for (final (date, filtre, ligne) in toutes)
        if (_filtre == _Filtre.toutes || filtre == _filtre) (date, ligne),
    ];
    final avecDemandes = demandes.isNotEmpty && (_filtre == _Filtre.toutes || _filtre == _Filtre.amis);

    final jour = DateTime(_maintenant.year, _maintenant.month, _maintenant.day);
    final semaine = jour.subtract(const Duration(days: 6));
    final groupes = <String, List<Widget>>{};
    for (final (date, ligne) in lignes) {
      final titre = !date.isBefore(jour) ? 'Aujourd\'hui' : (!date.isBefore(semaine) ? 'Cette semaine' : 'Plus tôt');
      (groupes[titre] ??= []).add(ligne);
    }

    return SubPageScaffold(
      title: 'Notifications',
      actions: [
        RoundIconButton(icon: Icons.settings_outlined, color: c.surface2, iconColor: c.text, tooltip: 'Régler les notifications', onPressed: () => context.push('${Paths.reglages}/notifications')),
      ],
      body: demandes.isEmpty && toutes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                      child: Icon(Icons.notifications_none_rounded, size: 36, color: c.text2),
                    ),
                    const SizedBox(height: 20),
                    Text('Rien de nouveau', style: ts(20, FontWeight.w700, c.text)),
                    const SizedBox(height: 6),
                    Text(
                      social == null ? 'Tes records et tes bilans arriveront ici.' : 'Tes records, tes bilans et les nouvelles de tes amis arriveront ici.',
                      textAlign: TextAlign.center,
                      style: ts(15, FontWeight.w500, c.text2, hauteur: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(margeSociale, 4, margeSociale, 40),
              children: [
                if (social != null) ...[
                  // Les filtres vont d'un bord à l'autre de l'écran et défilent.
                  SizedBox(
                    height: 42,
                    child: OverflowBox(
                      maxWidth: MediaQuery.sizeOf(context).width,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: margeSociale),
                        itemCount: _Filtre.values.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final f = _Filtre.values[i];
                          return Semantics(
                            selected: f == _filtre,
                            child: Pilule(label: f.label, plein: f == _filtre, onTap: () => setState(() => _filtre = f)),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (demandes.isNotEmpty || amis.isNotEmpty) const BandeauApercu(),
                if (!avecDemandes && lignes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Text('Rien ici pour l\'instant.', textAlign: TextAlign.center, style: ts(15, FontWeight.w500, c.text2)),
                  ),
                if (avecDemandes) ...[
                  TitreSection('Demandes d\'amis', droite: '${demandes.length}'),
                  for (final a in demandes) LigneDemande(a),
                ],
                for (final g in groupes.entries) ...[TitreSection(g.key), ...g.value],
              ],
            ),
    );
  }
}

/// Une ligne : une image ronde à gauche, une phrase, une seconde
/// ligne grise avec l'heure, et un point rouge tant qu'elle n'a pas été vue.
class _Ligne extends StatelessWidget {
  const _Ligne({required this.image, required this.phrase, this.quand, this.detail, required this.nouvelle, required this.onTap});
  final Widget image;

  /// Les morceaux de la phrase : en gras quand le booléen est vrai.
  final List<(String, bool)> phrase;

  /// « il y a 2 h » ; absent quand la seconde ligne porte déjà la date.
  final String? quand;
  final String? detail;
  final bool nouvelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.radius12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 52, height: 52, child: image),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        for (final (texte, gras) in phrase) TextSpan(text: texte, style: ts(15.5, gras ? FontWeight.w700 : FontWeight.w500, c.text, hauteur: 1.35)),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text([?detail, ?quand].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(14, FontWeight.w500, c.text2, hauteur: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle, color: nouvelle ? c.accent : Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

/// La pastille d'un ami, avec en bas à droite ce qu'il a fait.
class _PastilleAvec extends StatelessWidget {
  const _PastilleAvec(this.ami, this.insigne);
  final Ami ami;
  final Widget insigne;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Pastille2(ami, taille: 50),
        Positioned(
          right: -4,
          bottom: -3,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
            child: insigne,
          ),
        ),
      ],
    );
  }
}

class _LigneAmi extends StatelessWidget {
  const _LigneAmi(this.a, {required this.nouvelle, required this.maintenant});
  final Activite a;
  final bool nouvelle;
  final DateTime maintenant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    final gens = [for (final id in a.amis) repo.ami(id)].nonNulls.toList();
    if (gens.isEmpty) return const SizedBox.shrink();
    final premier = gens.first;
    final plusieurs = gens.length > 1;
    final noms = <(String, bool)>[
      (premier.prenom, true),
      if (gens.length == 2) ...[(' et ', false), (gens[1].prenom, true)],
      if (gens.length > 2) (' et ${gens.length - 1} autres', false),
    ];
    Widget disque(IconData icone, Color fond) => Container(
          width: 21,
          height: 21,
          decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
          child: Icon(icone, size: 13, color: Colors.white),
        );
    final publication = a.publicationId == null ? null : repo.publication(a.publicationId!);
    final (insigne, suite, detail, onTap) = switch (a.type) {
      TypeActivite.reaction => (
          Image.asset((a.reaction ?? Reaction.coeur).asset, width: 20, height: 20),
          plusieurs ? ' ont réagi à ta séance' : ' a réagi à ta séance',
          a.texte,
          () => ouvrirSeance(context, a.seanceId!),
        ),
      TypeActivite.commentaire => (
          disque(Icons.chat_bubble_rounded, const Color(0xFF2F6FB5)),
          ' a commenté ta séance',
          a.texte == null ? null : '« ${a.texte} »',
          () => ouvrirSeance(context, a.seanceId!),
        ),
      TypeActivite.accepte => (
          disque(Icons.check_rounded, c.foret),
          ' a accepté ta demande d\'ami',
          null,
          () => context.push(SocialPaths.ami(premier.id)),
        ),
      TypeActivite.record => (
          Ecusson.record(largeur: 21) as Widget,
          (publication?.records ?? 1) > 1 ? ' a battu ${publication!.records} records' : ' a battu un record',
          a.texte,
          () => context.push(SocialPaths.publication(a.publicationId!)),
        ),
    };
    return _Ligne(
      image: _PastilleAvec(premier, insigne),
      phrase: [...noms, (suite, false)],
      quand: Fmt.ilYa(a.date, now: maintenant),
      detail: detail,
      nouvelle: nouvelle,
      onTap: onTap,
    );
  }
}

class _LigneMienne extends StatelessWidget {
  const _LigneMienne(this.n, {required this.nouvelle, required this.maintenant});
  final Nouveaute n;
  final bool nouvelle;
  final DateTime maintenant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final image = switch (n.cible) {
      CibleNouveaute.seance => Ecusson.record(largeur: 30) as Widget,
      CibleNouveaute.bilanMois => Icon(Icons.auto_awesome_rounded, size: 24, color: c.text),
      CibleNouveaute.semaine => Icon(Icons.flag_rounded, size: 25, color: c.text),
    };
    return _Ligne(
      image: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
        child: image,
      ),
      phrase: [(n.titre, true)],
      quand: n.cible == CibleNouveaute.seance ? null : Fmt.ilYa(n.date, now: maintenant),
      detail: n.detail,
      nouvelle: nouvelle,
      onTap: () => switch (n.cible) {
        CibleNouveaute.bilanMois => context.push(AujourdhuiPaths.bilanMois(n.id!)),
        CibleNouveaute.seance => ouvrirSeance(context, n.id!),
        CibleNouveaute.semaine => RetourOrigine.ouvrir(context, AujourdhuiPaths.bilanSemaine),
      },
    );
  }
}
