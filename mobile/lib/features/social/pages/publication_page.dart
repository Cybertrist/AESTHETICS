import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/social_repo.dart';
import '../routes.dart';
import '../widgets/elements.dart';
import 'communaute_page.dart' show CartePublication;

/// La séance d'un ami, ses commentaires dessous, et de quoi en écrire un.
class PublicationPage extends StatefulWidget {
  const PublicationPage({super.key, required this.id, this.maintenant});
  final String id;
  final DateTime? maintenant;

  @override
  State<PublicationPage> createState() => _PublicationPageState();
}

class _PublicationPageState extends State<PublicationPage> {
  final _texte = TextEditingController();
  final _champ = FocusNode();
  final _defilement = ScrollController();

  @override
  void dispose() {
    _texte.dispose();
    _champ.dispose();
    _defilement.dispose();
    super.dispose();
  }

  void _envoyer() {
    if (_texte.text.trim().isEmpty) return;
    context.read<SocialRepo>().commenter(widget.id, _texte.text, maintenant: widget.maintenant);
    _texte.clear();
    // Le commentaire vient d'être ajouté en bas : on y descend.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_defilement.hasClients) _defilement.animateTo(_defilement.position.maxScrollExtent, duration: AppTokens.fast, curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    final p = repo.publication(widget.id);
    final auteur = p == null ? null : repo.ami(p.amiId);
    if (p == null || auteur == null) {
      return SubPageScaffold(
        title: 'Séance',
        body: Center(child: Text('Cette séance n\'est plus disponible.', style: ts(15, FontWeight.w500, c.text2))),
      );
    }
    final commentaires = repo.commentairesDe(p.id);
    return SubPageScaffold(
      title: 'Séance',
      bottomBar: Row(
        children: [
          const UserAvatar(size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _texte,
              focusNode: _champ,
              minLines: 1,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              style: ts(15.5, FontWeight.w500, c.text, hauteur: 1.35),
              cursorColor: c.text,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Écrire à ${auteur.prenom}…',
                hintStyle: ts(15.5, FontWeight.w500, c.text3, hauteur: 1.35),
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: c.surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Envoyer le commentaire',
            excludeSemantics: true,
            child: Material(
              color: _texte.text.trim().isEmpty ? c.surface2 : c.bouton,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _texte.text.trim().isEmpty ? null : _envoyer,
                child: SizedBox.square(
                  dimension: 42,
                  child: Icon(Icons.arrow_upward_rounded, size: 22, color: _texte.text.trim().isEmpty ? c.text3 : c.onBouton),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _defilement,
        padding: const EdgeInsets.fromLTRB(margeSociale, 4, margeSociale, 24),
        children: [
          const BandeauApercu(),
          const SizedBox(height: 16),
          CartePublication(p, maintenant: widget.maintenant, onCommenter: _champ.requestFocus),
          TitreSection('Commentaires', droite: commentaires.isEmpty ? null : '${commentaires.length}'),
          if (commentaires.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Personne n\'a encore commenté. Sois le premier.', style: ts(14.5, FontWeight.w500, c.text2, hauteur: 1.4)),
            ),
          for (final com in commentaires) _LigneCommentaire(com, maintenant: widget.maintenant),
        ],
      ),
    );
  }
}

/// Un commentaire : qui, quand, et le texte. Les miens se retirent.
class _LigneCommentaire extends StatelessWidget {
  const _LigneCommentaire(this.com, {this.maintenant});
  final Commentaire com;
  final DateTime? maintenant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.read<SocialRepo>();
    final ami = com.mien ? null : repo.ami(com.amiId!);
    if (!com.mien && ami == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ami == null)
            const UserAvatar(size: 38)
          else
            InkWell(onTap: () => context.push(SocialPaths.ami(ami.id)), customBorder: const CircleBorder(), child: Pastille2(ami, taille: 38)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: ami?.prenom ?? 'Toi', style: ts(14.5, FontWeight.w700, c.text)),
                      TextSpan(text: '  ${Fmt.ilYa(com.date, now: maintenant)}', style: ts(13, FontWeight.w500, c.text3)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(com.texte, style: ts(15, FontWeight.w500, c.text, hauteur: 1.4)),
                if (com.mien)
                  InkWell(
                    onTap: () => repo.retirerCommentaire(com.id),
                    borderRadius: AppTokens.radius8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text('Supprimer', style: ts(13, FontWeight.w600, c.text2)),
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
