import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/logic/logic.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../compte/logic/compte_repo.dart';
import '../../../compte/logic/copie_serveur.dart';
import '../../widgets/maquette.dart';

/// Réglages > Compte : connexion Google, copie des données sur le serveur,
/// et le choix entre deux copies quand le téléphone et le serveur diffèrent.
class CompteSection extends StatelessWidget {
  const CompteSection({super.key});

  /// Valeur de la ligne « Compte » des Réglages.
  static String valeur(CompteRepo repo) => !repo.connecte ? 'Non connecté' : etatCourt(repo);

  /// L'état de la copie en deux ou trois mots.
  static String etatCourt(CompteRepo repo) => repo.choix != null
      ? 'Choix à faire'
      : switch (repo.etat) {
          EtatCopie.aucune => 'Connecté',
          EtatCopie.enCours => 'Envoi…',
          EtatCopie.aJour => 'À jour',
          EtatCopie.enAttente => 'En attente',
        };

  /// Ce que contient une copie, en une ligne.
  static String contenu(ResumeCopie r) => '${Fmt.pluriel(r.seances, 'séance')}, ${Fmt.pluriel(r.routines, 'routine')}';

  static String _quand(DateTime d) => '${Fmt.relatif(d).toLowerCase()} à ${Fmt.heure(d)}';

  Future<void> _deconnecter(BuildContext context, CompteRepo repo) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Se déconnecter ?',
      message: 'Tes données restent sur ce téléphone et la copie reste sur le serveur. Seul l\'envoi s\'arrête.',
      confirmLabel: 'Se déconnecter',
      icon: Icons.logout_rounded,
    );
    if (ok) await repo.deconnecter();
  }

  Future<void> _garderTelephone(BuildContext context, CompteRepo repo, ChoixCopie choix) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Garder ce téléphone ?',
      message: 'La copie du serveur (${contenu(choix.serveur)}) sera remplacée par les données de ce téléphone.',
      confirmLabel: 'Garder ce téléphone',
      destructive: true,
      icon: Icons.phone_android_rounded,
    );
    if (ok) await repo.garderTelephone();
  }

  Future<void> _reprendreServeur(BuildContext context, CompteRepo repo, ChoixCopie choix) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reprendre la copie du serveur ?',
      message: 'Les données de ce téléphone (${contenu(choix.telephone)}) seront remplacées par la copie du serveur.',
      confirmLabel: 'Reprendre',
      destructive: true,
      icon: Icons.restore_rounded,
    );
    if (ok) await repo.reprendreServeur();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<CompteRepo?>();

    if (repo == null || !repo.disponible) {
      return const Bloc(child: Note('Le compte n\'est pas disponible dans cette version de l\'appli : tout reste sur ce téléphone.'));
    }

    final erreur = repo.erreur;
    final u = repo.utilisateur;
    if (u == null) {
      return Bloc(
        haut: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sans compte, tout reste sur ce téléphone. Avec un compte Google, tes séances sont copiées sur le serveur : un téléphone neuf les retrouve, et la communauté s\'ouvre.',
                style: txt(13, FontWeight.w400, c.text2, interligne: 1.4)),
            SizedBox(height: e(14)),
            BoutonPrincipal(label: 'Se connecter avec Google', onPressed: repo.connecter),
            if (erreur != null) ...[
              SizedBox(height: e(10)),
              Text(erreur, style: txt(12, FontWeight.w400, c.error)),
            ],
          ],
        ),
      );
    }

    final choix = repo.choix;
    final dernier = repo.dernierEnvoi;
    final enCours = repo.etat == EtatCopie.enCours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupeTitre(
          titre: 'Compte connecté',
          premier: true,
          lignes: [
            Ligne(
              trace: Trace.silhouette,
              titre: u.nom ?? u.email ?? 'Compte Google',
              detail: u.nom != null ? u.email : null,
            ),
          ],
        ),
        if (choix != null)
          GroupeTitre(
            titre: 'Deux copies différentes',
            note: 'Ce téléphone et le serveur ont chacun des données. Rien n\'est envoyé ni remplacé tant que tu n\'as pas choisi.',
            lignes: [
              Ligne(
                trace: Trace.ecran,
                titre: 'Garder ce téléphone',
                detail: contenu(choix.telephone),
                onTap: () => _garderTelephone(context, repo, choix),
              ),
              Ligne(
                trace: Trace.restaurer,
                titre: 'Reprendre la copie du serveur',
                detail: '${contenu(choix.serveur)}, envoyée ${_quand(choix.serveur.date)}',
                detailLignes: 2,
                onTap: () => _reprendreServeur(context, repo, choix),
              ),
            ],
          )
        else
          GroupeTitre(
            titre: 'Copie sur le serveur',
            note: erreur ?? 'Chaque changement part sur le serveur quelques secondes après. Les photos restent sur ce téléphone.',
            lignes: [
              Ligne(
                trace: switch (repo.etat) {
                  EtatCopie.aJour => Trace.coche,
                  EtatCopie.enAttente => Trace.alerte,
                  _ => Trace.horloge,
                },
                titre: switch (repo.etat) {
                  EtatCopie.aucune => 'Pas encore envoyée',
                  EtatCopie.enCours => 'Envoi en cours',
                  EtatCopie.aJour => 'À jour',
                  EtatCopie.enAttente => 'En attente du réseau',
                },
                detail: dernier == null ? null : 'Dernier envoi ${_quand(dernier)}',
              ),
              Ligne(
                trace: Trace.exporter,
                titre: 'Envoyer maintenant',
                actif: !enCours,
                onTap: repo.envoyer,
                chevron: false,
              ),
            ],
          ),
        GroupeTitre(
          lignes: [
            Ligne(
              trace: Trace.retour,
              titre: 'Se déconnecter',
              couleurTitre: c.error,
              onTap: () => _deconnecter(context, repo),
              chevron: false,
            ),
          ],
        ),
      ],
    );
  }
}
