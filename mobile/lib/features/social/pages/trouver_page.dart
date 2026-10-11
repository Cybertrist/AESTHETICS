import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/social_repo.dart';
import '../routes.dart';
import '../widgets/elements.dart';

/// Une personne : sa pastille, son nom, son pseudo, et le bouton qui va
/// avec notre lien (ajouter, annuler ma demande, accepter).
class LignePersonne extends StatelessWidget {
  const LignePersonne(this.a, {super.key});
  final Ami a;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    final lien = repo.lien(a.id);
    final enCommun = a.enCommun.where(repo.estAmi).length;
    return InkWell(
      onTap: () => context.push(SocialPaths.ami(a.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: margeSociale, vertical: 10),
        child: Row(
          children: [
            Pastille2(a, taille: 58),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.prenom, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, FontWeight.w600, c.text, hauteur: 1.25)),
                  Text(
                    enCommun > 0 ? '@${a.pseudo} · $enCommun en commun' : '@${a.pseudo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(13.5, FontWeight.w500, c.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            switch (lien) {
              Lien.ami => SerieAmi(a.serieSemaines, taille: 15),
              Lien.demandeRecue => Pilule(label: 'Accepter', plein: true, onTap: () => repo.accepter(a.id)),
              Lien.demandeEnvoyee => Pilule(label: 'Envoyée', icone: Icons.close_rounded, onTap: () => repo.annulerInvitation(a.id)),
              Lien.bloque => Pilule(label: 'Débloquer', onTap: () => repo.debloquer(a.id)),
              Lien.aucun => Pilule(label: 'Ajouter', plein: true, onTap: () => repo.inviter(a.id)),
            },
          ],
        ),
      ),
    );
  }
}

/// Ceux de mon répertoire qui ont l'appli.
class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SocialRepo>();
    return SubPageScaffold(
      title: 'Mes contacts',
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: margeSociale), child: BandeauApercu()),
          const Padding(padding: EdgeInsets.symmetric(horizontal: margeSociale), child: TitreSection('Personnes à ajouter')),
          if (repo.suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(margeSociale),
              child: Text('Aucun de tes contacts n\'a encore l\'appli.', textAlign: TextAlign.center, style: ts(14.5, FontWeight.w500, c.text2)),
            ),
          for (final a in repo.suggestions) LignePersonne(a),
        ],
      ),
    );
  }
}

/// Mon lien d'ami : une carte blanche avec ma photo, mon nom et mon code QR,
/// à faire scanner ou à envoyer.
class LienPage extends StatelessWidget {
  const LienPage({super.key});

  /// Le lien que porte le code QR.
  static String lien(String prenom) => 'aesthetics://ami?nom=${Uri.encodeQueryComponent(prenom.trim().toLowerCase())}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final prenom = context.watch<ProfileRepo>().profile?.prenom.trim() ?? '';
    const encre = Color(0xFF0B0B0C);
    Widget bouton(IconData icone, String label, VoidCallback onTap, {bool retourne = false}) => Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.flip(flipX: retourne, child: Icon(icone, color: encre, size: 24)),
                    const SizedBox(height: 4),
                    Text(label, maxLines: 1, style: ts(14, FontWeight.w600, encre, hauteur: 1.2)),
                  ],
                ),
              ),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(tooltip: 'Fermer', onPressed: () => context.pop(), icon: Icon(Icons.close_rounded, color: c.text, size: 28)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Scanner le code d\'un ami',
                    onPressed: () => context.push(SocialPaths.scanner),
                    icon: Icon(Icons.qr_code_scanner_rounded, color: c.text, size: 28),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // La photo dépasse du haut de la carte.
                        Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 44),
                              padding: const EdgeInsets.fromLTRB(26, 62, 26, 24),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                              child: Column(
                                children: [
                                  Text(prenom.isEmpty ? 'Moi' : prenom, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(24, FontWeight.w800, encre, hauteur: 1.2)),
                                  const SizedBox(height: 18),
                                  AspectRatio(
                                    aspectRatio: 1,
                                    child: QrImageView(
                                      data: lien(prenom),
                                      padding: EdgeInsets.zero,
                                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: encre),
                                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: encre),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text('AESTHETICS', style: ts(15, FontWeight.w800, encre, hauteur: 1.2).copyWith(letterSpacing: 1.2)),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                              child: const UserAvatar(size: 88),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            bouton(Icons.reply_rounded, 'Partager le profil', () => bientot(context, 'Le partage de ton lien'), retourne: true),
                            const SizedBox(width: 10),
                            bouton(Icons.link_rounded, 'Copier le lien', () => bientot(context, 'Ton lien d\'ami')),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text('Aperçu : ton lien marchera avec les comptes.', textAlign: TextAlign.center, style: ts(13, FontWeight.w500, c.text2)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scanner le code QR d'un ami, en plein écran.
class ScannerAmiPage extends StatefulWidget {
  const ScannerAmiPage({super.key});

  @override
  State<ScannerAmiPage> createState() => _ScannerAmiPageState();
}

class _ScannerAmiPageState extends State<ScannerAmiPage> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _lu = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_lu || !capture.barcodes.any((b) => (b.rawValue ?? '').startsWith('aesthetics://ami'))) return;
    _lu = true;
    HapticFeedback.mediumImpact();
    bientot(context, 'L\'ajout d\'un ami par son code');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final haut = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: c.bg,
      body: LayoutBuilder(builder: (context, box) {
        final cote = (box.maxWidth - 72).clamp(200.0, 360.0);
        final cadre = Rect.fromCenter(center: Offset(box.maxWidth / 2, box.maxHeight * 0.44), width: cote, height: cote);
        return Stack(
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: cadre,
                errorBuilder: (context, error) => ColoredBox(
                  color: c.bg,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? 'Autorise la caméra dans les réglages du téléphone pour scanner un code.'
                            : 'La caméra ne répond pas.',
                        textAlign: TextAlign.center,
                        style: ts(15, FontWeight.w500, c.text2, hauteur: 1.4),
                      ),
                    ),
                  ),
                ),
                placeholderBuilder: (context) => ColoredBox(color: c.bg),
              ),
            ),
            Positioned.fromRect(
              rect: cadre,
              child: IgnorePointer(
                child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white, width: 2.5))),
              ),
            ),
            Positioned(
              top: haut + 6,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(tooltip: 'Retour', onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26)),
                  const SizedBox(width: 6),
                  Text('Scanner', style: ts(19, FontWeight.w600, Colors.white).copyWith(shadows: const [Shadow(blurRadius: 8, color: Colors.black)])),
                ],
              ),
            ),
            Positioned(
              top: cadre.bottom + 26,
              left: 24,
              right: 24,
              child: Text(
                'Scanne le code QR de ton ami pour l\'ajouter.',
                textAlign: TextAlign.center,
                style: ts(16, FontWeight.w500, Colors.white, hauteur: 1.35).copyWith(shadows: const [Shadow(blurRadius: 8, color: Colors.black)]),
              ),
            ),
          ],
        );
      }),
    );
  }
}
