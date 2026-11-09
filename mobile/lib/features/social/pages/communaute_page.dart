import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../profil/widgets/ecusson.dart';
import '../../progres/ui/communs.dart' show VignetteExercice;
import '../data/social_repo.dart';
import '../routes.dart';
import '../widgets/elements.dart';
import '../widgets/reaction.dart';

/// Ajouter des amis : trois façons d'en trouver, rien d'autre. Les
/// suggestions sont dans « Mes contacts », les demandes reçues dans les
/// notifications de l'accueil, mes amis et mon profil public sur l'onglet
/// Profil, ce que je montre dans les réglages.
class CommunautePage extends StatelessWidget {
  const CommunautePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    return SubPageScaffold(
      title: 'Ajouter des amis',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(margeSociale, 4, margeSociale, 40),
        children: [
          // Sans compte, pas de communauté : d'abord se connecter.
          if (repo.aConnecter)
            const InvitationConnexion()
          else ...[
            if (repo.apercu) ...[const BandeauApercu(), const SizedBox(height: 16)],
            if (repo.etatPseudo == EtatPseudo.pris || repo.etatPseudo == EtatPseudo.invalide) ...[
              CarteSociale(
                onTap: () => context.push(SocialPaths.modifierProfil),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email_rounded, color: c.text, size: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        repo.etatPseudo == EtatPseudo.pris ? 'Ton pseudo est déjà pris : choisis-en un autre pour qu\'on te trouve.' : 'Choisis un pseudo de 3 caractères au moins pour qu\'on te trouve.',
                        style: ts(14.5, FontWeight.w600, c.text, hauteur: 1.35),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.text2),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Le répertoire du téléphone n'est lu que dans l'aperçu.
            if (repo.apercu) ...[
              _Action(icone: Icons.contacts_outlined, titre: 'Trouver dans mes contacts', onTap: () => context.push(SocialPaths.contacts)),
              const SizedBox(height: 12),
            ],
            _Action(icone: Icons.search_rounded, titre: repo.apercu ? 'Chercher par nom' : 'Chercher par pseudo', onTap: () => context.push(SocialPaths.ajouter)),
            const SizedBox(height: 12),
            _Action(titre: 'Partager mon lien', onTap: () => context.push(SocialPaths.lien)),
          ],
        ],
      ),
    );
  }
}

/// Une façon de trouver des amis : une grande case à toucher, une icône et
/// un titre. Sans icône, ma photo de profil et une flèche de partage.
class _Action extends StatelessWidget {
  const _Action({this.icone, required this.titre, required this.onTap});
  final IconData? icone;
  final String titre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CarteSociale(
      contour: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: icone != null
                ? Icon(icone, color: c.text, size: 30)
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const UserAvatar(size: 46),
                      Positioned(
                        right: -5,
                        bottom: -5,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
                          child: Transform.flip(flipX: true, child: Icon(Icons.reply_rounded, size: 17, color: c.text)),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17.5, FontWeight.w600, c.text, hauteur: 1.25)),
          ),
        ],
      ),
    );
  }
}

/// Mon coach : ses programmes pour moi, ses messages.
class CoachPage extends StatelessWidget {
  const CoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<SocialRepo>();
    return SubPageScaffold(
      title: 'Mon coach',
      body: ListView(padding: const EdgeInsets.fromLTRB(margeSociale, 4, margeSociale, 40), children: [const BandeauApercu(coach: true), const SizedBox(height: 16), ..._coach(context, repo)]),
    );
  }

  List<Widget> _coach(BuildContext context, SocialRepo repo) {
    final c = context.colors;
    const coach = SocialRepo.coach;
    return [
      if (!repo.aUnCoach) ...[
        CarteSociale(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu as un coach ?', style: ts(19, FontWeight.w700, c.text)),
              const SizedBox(height: 6),
              Text('Saisis le code qu\'il t\'a donné : il pourra te partager ses programmes et suivre tes séances.', style: ts(14, FontWeight.w500, c.text2, hauteur: 1.4)),
              const SizedBox(height: 16),
              const _ChampCode(),
              const SizedBox(height: 14),
              BoutonPrincipal(label: 'Rejoindre mon coach', onPressed: repo.rejoindreCoach),
            ],
          ),
        ),
      ] else ...[
        CarteSociale(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Pastille2(coach, taille: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mon coach', style: ts(12.5, FontWeight.w600, c.text2)),
                        Text(coach.prenom, style: ts(21, FontWeight.w800, c.text, hauteur: 1.2)),
                        Text(coach.phrase ?? '', style: ts(13.5, FontWeight.w500, c.text2)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: BoutonPrincipal(label: 'Lui écrire', petit: true, onPressed: () => _bientot(context, 'La messagerie avec ton coach')),
                  ),
                ],
              ),
            ],
          ),
        ),
        const TitreSection('Ses programmes pour toi'),
        CarteSociale(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final (i, p) in repo.programmesCoach.indexed) ...[
                if (i > 0) Divider(height: 1, indent: 18, color: c.line),
                InkWell(
                  onTap: () => _bientot(context, 'L\'ajout d\'un programme partagé'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(p.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(16, FontWeight.w700, c.text)),
                                  ),
                                  if (p.nouveau) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(color: c.foret, borderRadius: BorderRadius.circular(7)),
                                      child: Text('Nouveau', style: ts(10.5, FontWeight.w800, Colors.white, hauteur: 1.2)),
                                    ),
                                  ],
                                ],
                              ),
                              Text(p.detail, style: ts(13, FontWeight.w500, c.text2)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.text3),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const TitreSection('Ses derniers messages'),
        for (final m in repo.messagesCoach) ...[
          CarteSociale(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Pastille2(coach, taille: 34),
                const SizedBox(width: 12),
                Expanded(child: Text(m, style: ts(14.5, FontWeight.w500, c.text, hauteur: 1.45))),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: repo.quitterCoach,
            child: Text('Quitter ce coach', style: ts(14, FontWeight.w600, c.text2)),
          ),
        ),
      ],
      const SizedBox(height: 14),
      CarteSociale(
        onTap: () => context.push(SocialPaths.espaceCoach),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tu es coach ?', style: ts(16, FontWeight.w700, c.text)),
                  Text('Suis tes élèves et partage-leur tes programmes.', style: ts(13, FontWeight.w500, c.text2)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.text3),
          ],
        ),
      ),
    ];
  }
}

/// Dit qu'une action n'est pas encore branchée, sans mentir sur ce qui s'est passé.
void _bientot(BuildContext context, String quoi) => Toasts.show(context, '$quoi arrive avec les comptes. Rien n\'a été envoyé.');

class _ChampCode extends StatelessWidget {
  const _ChampCode();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      textCapitalization: TextCapitalization.characters,
      style: ts(18, FontWeight.w700, c.text),
      cursorColor: c.text,
      decoration: InputDecoration(
        hintText: 'Code du coach',
        hintStyle: ts(16, FontWeight.w500, c.text3),
        filled: true,
        fillColor: c.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

/// Une séance d'un ami dans le fil.
class CartePublication extends StatelessWidget {
  const CartePublication(this.p, {super.key, this.auteur, this.avecAuteur = true, this.charges, this.actif = true, this.maintenant, this.onCommenter});
  final Publication p;

  /// Celui qui l'a publiée ; par défaut, la personne du dépôt.
  final Ami? auteur;

  /// Faux sur le profil de l'ami, où son nom est déjà en haut.
  final bool avecAuteur;

  /// Montrer les kilos ; par défaut, ce que l'auteur a choisi.
  final bool? charges;

  /// Faux dans l'aperçu de mon profil : les boutons ne font rien.
  final bool actif;
  final DateTime? maintenant;

  /// Ce que fait « Commenter » ; par défaut, ouvrir la séance et ses commentaires.
  final VoidCallback? onCommenter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    final exos = context.watch<ExerciseRepo>();
    final ami = auteur ?? repo.ami(p.amiId);
    final kilos = charges ?? (ami?.montre.contains(Visible.charges) ?? false);
    final quand = Fmt.ilYa(p.date, now: maintenant);
    final unite = context.watch<ProfileRepo?>()?.unite ?? UnitePoids.kg;
    final commentaires = repo.nbCommentaires(p.id);
    return CarteSociale(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avecAuteur && ami != null) ...[
            InkWell(
              onTap: () => context.push(SocialPaths.ami(ami.id)),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Pastille2(ami, taille: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ami.prenom, style: ts(16, FontWeight.w700, c.text, hauteur: 1.2)),
                        Text(quand, style: ts(13, FontWeight.w500, c.text2)),
                      ],
                    ),
                  ),
                  SerieAmi(ami.serieSemaines),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(child: Text(p.titre.toUpperCase(), style: ts(20, FontWeight.w800, c.text, hauteur: 1.2))),
              if (!avecAuteur) Text(quand, style: ts(13, FontWeight.w500, c.text2)),
            ],
          ),
          if (p.note != null) ...[const SizedBox(height: 6), Text(p.note!, style: ts(14.5, FontWeight.w500, c.text2, hauteur: 1.4))],
          const SizedBox(height: 14),
          Row(
            children: [
              // Sur un écran étroit ou en texte agrandi, les chiffres rétrécissent plutôt que de déborder.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Chiffre(Fmt.duree(p.duree), 'Durée'),
                      const SizedBox(width: 26),
                      if (kilos && p.volumeKg > 0) ...[Chiffre(Fmt.volume(p.volumeKg, unite), 'Volume'), const SizedBox(width: 26)],
                      if (p.series > 0) Chiffre('${p.series}', 'Séries'),
                    ],
                  ),
                ),
              ),
              if (p.records > 0) ...[const SizedBox(width: 12), Ecusson.record(largeur: 30), const SizedBox(width: 6), Text('${p.records}', style: ts(18, FontWeight.w800, c.text, hauteur: 1))],
            ],
          ),
          if (p.exercices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (final (i, id) in p.exercices.take(3).indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: LayoutBuilder(
                            builder: (context, box) => VignetteExercice(exercice: exos.byId(id), taille: box.maxWidth, fond: c.surface2, rayon: 16),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(exos.nameOf(id), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: ts(11.5, FontWeight.w500, c.text2, hauteur: 1.25)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                BoutonReaction(p, actif: actif),
                const SizedBox(width: 10),
                Pilule(label: commentaires == 0 ? 'Commenter' : 'Commentaires · $commentaires', icone: Icons.chat_bubble_outline_rounded, onTap: actif ? (onCommenter ?? () => context.push(SocialPaths.publication(p.id))) : () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une demande d'ami reçue : accepter ou refuser. Elle s'affiche dans les
/// notifications de l'accueil.
class LigneDemande extends StatelessWidget {
  const LigneDemande(this.a, {super.key, this.onProfil});
  final Ami a;

  /// Ouvre le profil de la personne (par défaut, sa page par-dessus).
  final VoidCallback? onProfil;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.read<SocialRepo>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          InkWell(onTap: onProfil ?? () => context.push(SocialPaths.ami(a.id)), customBorder: const CircleBorder(), child: Pastille2(a)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.prenom, style: ts(16.5, FontWeight.w700, c.text, hauteur: 1.2)),
                Text('veut t\'ajouter en ami', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, FontWeight.w500, c.text2)),
              ],
            ),
          ),
          Pilule(label: 'Accepter', plein: true, onTap: () => repo.accepter(a.id)),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Refuser',
            onPressed: () => repo.refuser(a.id),
            icon: Icon(Icons.close_rounded, color: c.text2),
          ),
        ],
      ),
    );
  }
}
