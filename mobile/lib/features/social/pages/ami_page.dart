import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../profil/data/photo_profil.dart';
import '../data/moi.dart';
import '../data/social_repo.dart';
import '../routes.dart';
import '../widgets/elements.dart';
import '../widgets/vue_profil.dart';
import 'trouver_page.dart';

enum _Menu { retirer, bloquer, signaler }

/// Le profil public d'une personne : ce qu'elle a choisi de montrer, et à qui.
/// À l'ouverture, la source relit son profil (sur le serveur, il a pu changer).
class AmiPage extends StatefulWidget {
  const AmiPage({super.key, required this.id});
  final String id;

  @override
  State<AmiPage> createState() => _AmiPageState();
}

class _AmiPageState extends State<AmiPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SocialRepo>().voir(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) => _VueAmi(id: widget.id);
}

class _VueAmi extends StatelessWidget {
  const _VueAmi({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    final a = repo.ami(id);
    if (a == null) {
      // Sur le serveur, le profil peut être encore en route.
      return SubPageScaffold(title: 'Profil', body: Center(child: repo.apercu ? const Text('Ce profil n\'existe plus.') : const CircularProgressIndicator()));
    }
    final lien = repo.lien(id);
    if (lien == Lien.bloque) {
      return SubPageScaffold(
        title: a.prenom,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pastille2(a, taille: 76),
                const SizedBox(height: 16),
                Text('Tu as bloqué ${a.prenom}', textAlign: TextAlign.center, style: ts(19, FontWeight.w700, c.text)),
                const SizedBox(height: 6),
                Text('Vous ne voyez plus rien l\'un de l\'autre.', textAlign: TextAlign.center, style: ts(14.5, FontWeight.w500, c.text2)),
                const SizedBox(height: 18),
                Pilule(label: 'Débloquer', onTap: () => repo.debloquer(id)),
              ],
            ),
          ),
        ),
      );
    }
    return SubPageScaffold(
      title: a.prenom,
      halo: false,
      actions: [
        IconButton(tooltip: 'Plus d\'actions', onPressed: () => _menu(context, repo, a), icon: Icon(Icons.more_horiz_rounded, color: c.text)),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(margeSociale, 4, margeSociale, 40),
        children: [
          VueProfil(
            personne: a,
            ouvert: repo.ouvert(a),
            publications: repo.publicationsDe(id),
            jours: repo.joursDe(a),
            enCommun: [for (final e in a.enCommun) if (repo.estAmi(e)) repo.ami(e)].whereType<Ami>().toList(),
            actions: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: switch (lien) {
                Lien.ami => [Pilule(label: 'Ami', icone: Icons.check_rounded, onTap: () => _retirer(context, repo, a))],
                Lien.demandeRecue => [
                    Pilule(label: 'Accepter', plein: true, onTap: () => repo.accepter(id)),
                    Pilule(label: 'Refuser', onTap: () => repo.refuser(id)),
                  ],
                Lien.demandeEnvoyee => [Pilule(label: 'Demande envoyée · Annuler', icone: Icons.schedule_rounded, onTap: () => repo.annulerInvitation(id))],
                _ => [Pilule(label: 'Ajouter en ami', icone: Icons.person_add_alt_1_rounded, plein: true, onTap: () => repo.inviter(id))],
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, SocialRepo repo, Ami a) async {
    final choix = await showActionMenu<_Menu>(
      context,
      title: a.prenom,
      items: [
        if (repo.estAmi(a.id)) const ActionMenuItem(value: _Menu.retirer, label: 'Retirer de mes amis', icon: Icons.person_remove_outlined),
        const ActionMenuItem(value: _Menu.bloquer, label: 'Bloquer', icon: Icons.block_rounded, destructive: true),
        const ActionMenuItem(value: _Menu.signaler, label: 'Signaler', icon: Icons.flag_outlined, destructive: true),
      ],
    );
    if (choix == null || !context.mounted) return;
    switch (choix) {
      case _Menu.retirer:
        await _retirer(context, repo, a);
      case _Menu.bloquer:
        final ok = await showConfirmDialog(
          context,
          title: 'Bloquer ${a.prenom} ?',
          message: 'Vous ne verrez plus rien l\'un de l\'autre, et ${a.prenom} ne pourra plus t\'ajouter. Personne n\'est prévenu.',
          confirmLabel: 'Bloquer',
          destructive: true,
        );
        if (ok) repo.bloquer(a.id);
      case _Menu.signaler:
        bientot(context, 'Le signalement');
    }
  }

  Future<void> _retirer(BuildContext context, SocialRepo repo, Ami a) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Retirer ${a.prenom} de tes amis ?',
      message: 'Vous ne verrez plus vos séances l\'un de l\'autre. ${a.prenom} n\'est pas prévenu.',
      confirmLabel: 'Retirer',
      destructive: true,
    );
    if (ok) repo.retirer(a.id);
  }
}

/// Chercher quelqu'un par son prénom ou son pseudo.
class AjouterAmiPage extends StatefulWidget {
  const AjouterAmiPage({super.key});

  @override
  State<AjouterAmiPage> createState() => _AjouterAmiPageState();
}

class _AjouterAmiPageState extends State<AjouterAmiPage> {
  final _champ = TextEditingController();

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    // Rien tant que rien n'est tapé : la page n'est que le champ.
    final vide = _champ.text.trim().isEmpty;
    final trouves = repo.chercher(_champ.text);
    return SubPageScaffold(
      title: 'Rechercher des amis',
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: margeSociale),
            child: TextField(
              controller: _champ,
              onChanged: (_) => setState(() {}),
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              style: ts(16, FontWeight.w600, c.text),
              cursorColor: c.text,
              decoration: InputDecoration(
                hintText: repo.apercu ? 'Nom ou pseudo' : 'Pseudo',
                hintStyle: ts(16, FontWeight.w500, c.text3),
                prefixIcon: Icon(Icons.search_rounded, color: c.text2),
                filled: true,
                fillColor: c.surface2,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: c.text, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (repo.aConnecter) const Padding(padding: EdgeInsets.symmetric(horizontal: margeSociale), child: InvitationConnexion()),
          if (!vide && trouves.isEmpty && !repo.aConnecter)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Personne à ce nom.', textAlign: TextAlign.center, style: ts(14.5, FontWeight.w500, c.text2)),
            ),
          for (final a in trouves) LignePersonne(a),
        ],
      ),
    );
  }
}

/// Mes amis, mes demandes en attente, les personnes que j'ai bloquées.
class MesAmisPage extends StatelessWidget {
  const MesAmisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    Widget titre(String t, int n) => Padding(padding: const EdgeInsets.symmetric(horizontal: margeSociale), child: TitreSection(t, droite: '$n'));
    return SubPageScaffold(
      title: 'Mes amis',
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: margeSociale), child: BandeauApercu()),
          if (repo.aConnecter)
            const Padding(padding: EdgeInsets.fromLTRB(margeSociale, 8, margeSociale, 0), child: InvitationConnexion())
          else if (repo.amis.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 50, 30, 20),
              child: Column(
                children: [
                  Text('Pas encore d\'amis', style: ts(19, FontWeight.w700, c.text)),
                  const SizedBox(height: 6),
                  Text('Ajoute tes amis pour voir leurs séances sur l\'accueil.', textAlign: TextAlign.center, style: ts(14.5, FontWeight.w500, c.text2, hauteur: 1.4)),
                  const SizedBox(height: 18),
                  Pilule(label: 'Ajouter des amis', plein: true, onTap: () => context.pop()),
                ],
              ),
            )
          else ...[
            titre('Amis', repo.amis.length),
            for (final a in repo.amis) LignePersonne(a),
          ],
          if (repo.envoyees.isNotEmpty) ...[
            titre('Demandes envoyées', repo.envoyees.length),
            for (final a in repo.envoyees) LignePersonne(a),
          ],
          if (repo.bloques.isNotEmpty) ...[
            titre('Personnes bloquées', repo.bloques.length),
            for (final a in repo.bloques) LignePersonne(a),
          ],
        ],
      ),
    );
  }
}

/// Mon profil public, comme le voit un ami ou un inconnu.
class MonProfilPublicPage extends StatefulWidget {
  const MonProfilPublicPage({super.key});

  @override
  State<MonProfilPublicPage> createState() => _MonProfilPublicPageState();
}

class _MonProfilPublicPageState extends State<MonProfilPublicPage> {
  /// Qui regarde : un ami, ou quelqu'un qui ne me connaît pas.
  bool _ami = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final moi = MoiPublic.de(context);
    if (moi == null) {
      return const SubPageScaffold(title: 'Mon profil public', body: Center(child: Text('Crée d\'abord ton profil.')));
    }
    final a = moi.personne;
    final ouvert = SocialRepo.ouvertA(a.acces, ami: _ami);
    Widget cote(String label, bool valeur) => Expanded(
          child: Material(
            color: _ami == valeur ? c.bouton : Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _ami = valeur),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                child: Text(label, style: ts(14.5, FontWeight.w700, _ami == valeur ? c.onBouton : c.text2, hauteur: 1.2)),
              ),
            ),
          ),
        );
    return SubPageScaffold(
      title: 'Mon profil public',
      halo: false,
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(margeSociale, 8, margeSociale, 12),
          child: BoutonPrincipal(label: 'Régler ce que je montre', onPressed: () => context.push(SocialPaths.confidentialite)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(margeSociale, 4, margeSociale, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(99)),
            child: Row(children: [cote('Vu par un ami', true), cote('Vu par un inconnu', false)]),
          ),
          const SizedBox(height: 10),
          Text(
            switch (a.acces) {
              AccesProfil.tous => 'Ton profil est ouvert à tout le monde.',
              AccesProfil.amis => _ami ? 'Tes amis voient ton profil.' : 'Un inconnu ne voit que ta photo et ton prénom.',
              AccesProfil.personne => 'Ton profil est privé : personne ne voit rien de plus.',
            },
            textAlign: TextAlign.center,
            style: ts(13.5, FontWeight.w500, c.text2),
          ),
          const SizedBox(height: 14),
          VueProfil(personne: a, ouvert: ouvert, publications: moi.publications, jours: moi.jours),
        ],
      ),
    );
  }
}

/// Qui je suis pour les autres : ma photo, mon prénom, mon pseudo, ma
/// phrase, ma ville, ma salle. Ce que j'en montre se règle ailleurs
/// ([ConfidentialitePage]).
class ModifierProfilPage extends StatefulWidget {
  const ModifierProfilPage({super.key});

  @override
  State<ModifierProfilPage> createState() => _ModifierProfilPageState();
}

class _ModifierProfilPageState extends State<ModifierProfilPage> {
  late final ProfileRepo _repo = context.read<ProfileRepo>();
  late final _prenom = TextEditingController(text: _repo.profile?.prenom ?? '');
  late final _pseudo = TextEditingController(text: _repo.profile?.pseudo ?? '');
  late final _phrase = TextEditingController(text: _repo.profile?.phrase ?? '');
  late final _ville = TextEditingController(text: _repo.profile?.ville ?? '');
  late final _salle = TextEditingController(text: _repo.profile?.salle ?? '');
  Timer? _attente;

  /// Le pseudo : minuscules, chiffres, point et tiret bas, 20 caractères.
  static final _pseudoPermis = [
    TextInputFormatter.withFunction((avant, apres) => apres.copyWith(text: apres.text.toLowerCase())),
    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9._]')),
  ];

  @override
  void dispose() {
    // Ce qui vient d'être tapé part avant de quitter la page.
    if (_attente?.isActive ?? false) _enregistrer();
    _attente?.cancel();
    for (final c in [_prenom, _pseudo, _phrase, _ville, _salle]) {
      c.dispose();
    }
    super.dispose();
  }

  void _taper() {
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 500), _enregistrer);
  }

  void _enregistrer() {
    final prenom = _prenom.text.trim(), pseudo = _pseudo.text.trim(), phrase = _phrase.text.trim(), ville = _ville.text.trim(), salle = _salle.text.trim();
    // Un prénom effacé ne s'enregistre pas : l'ancien reste.
    _repo.update((p) => p.copyWith(prenom: prenom.isEmpty ? null : prenom, pseudo: pseudo, phrase: phrase, ville: ville, salle: salle));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = context.watch<ProfileRepo>().profile;
    if (p == null) {
      return const SubPageScaffold(title: 'Modifier mon profil', body: Center(child: Text('Crée d\'abord ton profil.')));
    }

    Widget champ(String libelle, TextEditingController ctrl, String exemple, {String? prefixe, List<TextInputFormatter>? formats, int longueur = 40, int lignes = 1, String? aide}) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 7),
                child: Text(libelle, style: ts(14, FontWeight.w600, c.text2)),
              ),
              TextField(
                controller: ctrl,
                onChanged: (_) => _taper(),
                autocorrect: lignes > 1,
                minLines: lignes,
                maxLines: lignes,
                inputFormatters: [LengthLimitingTextInputFormatter(longueur), ...?formats],
                textCapitalization: prefixe != null ? TextCapitalization.none : (lignes > 1 ? TextCapitalization.sentences : TextCapitalization.words),
                style: ts(16, FontWeight.w600, c.text, hauteur: 1.4),
                cursorColor: c.text,
                decoration: InputDecoration(
                  hintText: exemple,
                  hintStyle: ts(16, FontWeight.w500, c.text3, hauteur: 1.4),
                  prefixText: prefixe,
                  prefixStyle: ts(16, FontWeight.w600, c.text2, hauteur: 1.4),
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.text, width: 1.5)),
                ),
              ),
              if (aide != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: Text(aide, style: ts(12.5, FontWeight.w500, c.text3)),
                ),
            ],
          ),
        );

    return SubPageScaffold(
      title: 'Modifier mon profil',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(margeSociale, 8, margeSociale, 40),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: 'Changer la photo de profil',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => changerPhotoProfil(context, _repo, context.read<Store>()),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const UserAvatar(size: 104),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: c.bouton, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 3)),
                        child: Icon(Icons.photo_camera_outlined, size: 17, color: c.onBouton),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          champ('Prénom', _prenom, 'Tristan'),
          champ(
            'Pseudo',
            _pseudo,
            'tristan.jcr',
            prefixe: '@',
            formats: _pseudoPermis,
            longueur: 20,
            // Ce que le serveur dit du pseudo enregistré.
            aide: switch (context.watch<SocialRepo?>()?.etatPseudo) {
              EtatPseudo.pris => 'Déjà pris par quelqu’un d’autre : choisis-en un autre.',
              EtatPseudo.invalide => '3 caractères au moins : lettres, chiffres, point, tiret bas.',
              _ => 'Tes amis te trouvent avec.',
            },
          ),
          champ('Ta phrase', _phrase, 'Ta devise, ton but.', longueur: 140, lignes: 3),
          champ('Ville', _ville, 'Brest'),
          champ('Ma salle', _salle, 'Basic-Fit Brest'),
          const SizedBox(height: 4),
          Text('Ce que les autres voient de ce profil se règle dans Réglages, « Ce que je montre ».', style: ts(13, FontWeight.w500, c.text2, hauteur: 1.4)),
        ],
      ),
    );
  }
}

/// Qui voit mon profil, et ce qu'il montre.
class ConfidentialitePage extends StatelessWidget {
  const ConfidentialitePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<ProfileRepo>();
    final p = repo.profile;
    if (p == null) {
      return const SubPageScaffold(title: 'Ce que je montre', body: Center(child: Text('Crée d\'abord ton profil.')));
    }
    final ferme = p.acces == AccesProfil.personne;

    Widget choix(AccesProfil a) => InkWell(
          onTap: () => repo.update((x) => x.copyWith(acces: a)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.titre, style: ts(16, FontWeight.w700, c.text)),
                      Text(a.detail, style: ts(13, FontWeight.w500, c.text2, hauteur: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  selected: p.acces == a,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.acces == a ? c.bouton : Colors.transparent,
                      border: Border.all(color: p.acces == a ? c.bouton : c.text3, width: 2),
                    ),
                    child: p.acces == a ? Icon(Icons.check_rounded, size: 17, color: c.onBouton) : null,
                  ),
                ),
              ],
            ),
          ),
        );

    Widget interrupteur(Visible v) {
      final actif = !ferme && p.montre.contains(v);
      return MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.titre, style: ts(16, FontWeight.w700, ferme ? c.text3 : c.text)),
                    Text(v.detail, style: ts(13, FontWeight.w500, c.text2, hauteur: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: actif,
                onChanged: ferme ? null : (_) => repo.update((x) => x.copyWith(montre: actif ? ({...x.montre}..remove(v)) : {...x.montre, v})),
                activeTrackColor: c.foret,
                activeThumbColor: Colors.white,
              ),
            ],
          ),
        ),
      );
    }

    Widget filet() => Divider(height: 1, indent: 18, color: c.line);

    return SubPageScaffold(
      title: 'Ce que je montre',
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(margeSociale, 8, margeSociale, 12),
          child: BoutonSecondaire(label: 'Voir mon profil public', onPressed: () => context.push(SocialPaths.monProfil)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(margeSociale, 4, margeSociale, 30),
        children: [
          const BandeauApercu(),
          const TitreSection('Qui voit mon profil'),
          CarteSociale(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (i, a) in AccesProfil.values.indexed) ...[if (i > 0) filet(), choix(a)],
              ],
            ),
          ),
          const TitreSection('Ce que je montre'),
          CarteSociale(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (i, v) in VisibleTexte.ordre.indexed) ...[if (i > 0) filet(), interrupteur(v)],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tes mensurations, ton poids et tes photos d\'évolution ne sont jamais partagés.',
            style: ts(13, FontWeight.w500, c.text2, hauteur: 1.4),
          ),
        ],
      ),
    );
  }
}
