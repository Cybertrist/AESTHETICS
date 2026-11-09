import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/social_repo.dart';
import '../routes.dart';
import '../widgets/elements.dart';

Ami _commeAmi(Eleve e) => Ami(id: e.id, prenom: e.prenom, pseudo: e.prenom.toLowerCase(), couleur: e.couleur);

/// La barre des séances de la semaine : faites sur prévues.
class _Semaine extends StatelessWidget {
  const _Semaine(this.e);
  final Eleve e;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < e.prevues; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(color: i < e.faites ? c.foretClair : c.surface3, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ],
      ],
    );
  }
}

/// L'espace du coach : ses élèves, où ils en sont cette semaine.
class EspaceCoachPage extends StatelessWidget {
  const EspaceCoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    final eleves = [...repo.eleves]..sort((a, b) => (b.alerte == null ? 0 : 1).compareTo(a.alerte == null ? 0 : 1));
    final faites = eleves.fold(0, (a, e) => a + e.faites), prevues = eleves.fold(0, (a, e) => a + e.prevues);
    final aJour = eleves.where((e) => e.faites >= e.prevues).length;
    return SubPageScaffold(
      title: 'Espace coach',
      actions: [
        RoundIconButton(icon: Icons.person_add_alt_1_rounded, tooltip: 'Inviter un élève', onPressed: () => Toasts.show(context, 'Le code d\'invitation arrive avec les comptes. Rien n\'a été envoyé.')),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(margeSociale, 4, margeSociale, 40),
        children: [
          const BandeauApercu(coach: true),
          const SizedBox(height: 14),
          CarteSociale(
            child: Row(
              children: [
                Expanded(child: Chiffre('${eleves.length}', 'Élèves')),
                Expanded(child: Chiffre('$faites / $prevues', 'Séances cette semaine')),
                Expanded(child: Chiffre('$aJour', 'À jour')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BoutonPrincipal(label: 'Partager un programme', onPressed: () => Toasts.show(context, 'Le partage d\'un programme arrive avec les comptes. Rien n\'a été envoyé.')),
          const TitreSection('Mes élèves'),
          for (final e in eleves) ...[
            CarteSociale(
              onTap: () => context.push(SocialPaths.eleve(e.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pastille2(_commeAmi(e), taille: 46),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.prenom, style: ts(16.5, FontWeight.w700, c.text, hauteur: 1.2)),
                            Text(e.programme, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, FontWeight.w500, c.text2)),
                          ],
                        ),
                      ),
                      Text('${e.faites} / ${e.prevues}', style: ts(16, FontWeight.w800, c.text)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Semaine(e),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (e.alerte != null) ...[
                        Icon(Icons.error_outline_rounded, size: 16, color: c.orange),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(e.alerte ?? e.derniere, style: ts(13, e.alerte != null ? FontWeight.w700 : FontWeight.w500, e.alerte != null ? c.orange : c.text2)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Un élève, vu par son coach.
class ElevePage extends StatelessWidget {
  const ElevePage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    final e = repo.eleves.where((x) => x.id == id).firstOrNull;
    if (e == null) return const SubPageScaffold(title: 'Élève', body: Center(child: Text('Cet élève n\'est plus dans ta liste.')));
    void bientot(String quoi) => Toasts.show(context, '$quoi arrive avec les comptes. Rien n\'a été envoyé.');
    Widget ligne(String titre, String valeur) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              Text(titre, style: ts(14.5, FontWeight.w500, c.text2)),
              const SizedBox(width: 12),
              Expanded(child: Text(valeur, textAlign: TextAlign.right, style: ts(15, FontWeight.w700, c.text))),
            ],
          ),
        );
    return SubPageScaffold(
      title: e.prenom,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(margeSociale, 4, margeSociale, 40),
        children: [
          CarteSociale(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Pastille2(_commeAmi(e), taille: 60),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.prenom, style: ts(21, FontWeight.w800, c.text, hauteur: 1.2)),
                          Text('Cette semaine : ${e.faites} séances sur ${e.prevues}', style: ts(13.5, FontWeight.w500, c.text2)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Semaine(e),
                if (e.alerte != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 17, color: c.orange),
                      const SizedBox(width: 6),
                      Text(e.alerte!, style: ts(13.5, FontWeight.w700, c.orange)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: BoutonPrincipal(label: 'Lui écrire', petit: true, onPressed: () => bientot('La messagerie'))),
              const SizedBox(width: 10),
              Expanded(child: BoutonSecondaire(label: 'Ses séances', petit: true, onPressed: () => bientot('Le détail de ses séances'))),
            ],
          ),
          const TitreSection('Son programme'),
          CarteSociale(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ligne('Programme', e.programme),
                Divider(height: 1, indent: 18, color: c.line),
                ligne('Dernière séance', e.derniere),
                Divider(height: 1, indent: 18, color: c.line),
                InkWell(
                  onTap: () => bientot('Le changement de programme'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    child: Row(
                      children: [
                        Expanded(child: Text('Changer son programme', style: ts(15, FontWeight.w700, c.text))),
                        Icon(Icons.chevron_right_rounded, color: c.text3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
