import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../import/data/fichiers.dart';
import '../../sante/services/corps_hc.dart';
import '../../sante/services/health_connect.dart';
import '../../sante/services/pesees_fichier.dart';
import '../data/mensurations.dart';
import '../widgets/maquette.dart';

/// Balance connectée : ce que Health Connect laisse lire, et l'import de
/// toutes les pesées, mois par mois, avec le compte qui monte à l'écran.
class BalancePage extends StatefulWidget {
  const BalancePage({super.key});

  @override
  State<BalancePage> createState() => _BalancePageState();
}

class _BalancePageState extends State<BalancePage> with WidgetsBindingObserver {
  AccesCorps? _acces;
  bool _enCours = false;
  BilanCorps? _bilan;

  /// Mois en cours de lecture.
  DateTime? _mois;
  String? _erreur;

  /// La dernière lecture venait d'un fichier, pas de Health Connect.
  bool _fichier = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifier();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Retour depuis Health Connect : les accès ont pu changer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verifier();
  }

  Future<void> _verifier() async {
    final a = await HealthConnectService.instance.accesCorps();
    if (mounted) setState(() => _acces = a);
  }

  /// Demande les accès qui manquent, puis relit tout.
  Future<void> _importer() async {
    if (_enCours) return;
    final sante = context.read<HealthRepo>();
    final hc = HealthConnectService.instance;
    setState(() {
      _enCours = true;
      _fichier = false;
      _erreur = null;
      _bilan = null;
      _mois = null;
    });
    try {
      final ok = await hc.demanderCorps();
      await _verifier();
      if (!ok) {
        if (mounted) setState(() => _erreur = 'Health Connect n\'a pas donné accès au poids.');
        return;
      }
      final bilan = await hc.importerToutCorps(sante, surAvancee: (b, mois) {
        if (mounted) {
          setState(() {
            _bilan = b;
            _mois = mois;
          });
        }
      });
      if (mounted) setState(() => _bilan = bilan);
    } catch (e) {
      if (mounted) setState(() => _erreur = 'La lecture s\'est arrêtée : $e');
    } finally {
      if (mounted) {
        setState(() {
          _enCours = false;
          _mois = null;
        });
      }
    }
  }

  /// Range les pesées d'un export de la balance (zip ou weight.csv) : ce
  /// que Health Connect n'a jamais reçu.
  Future<void> _importerFichier() async {
    if (_enCours) return;
    final sante = context.read<HealthRepo>();
    final f = await Fichiers.courant.choisir();
    if (f == null || !mounted) return;
    setState(() {
      _enCours = true;
      _fichier = true;
      _erreur = null;
      _bilan = null;
    });
    try {
      final bilan = await HealthConnectService.instance.rangerPesees(sante, PeseesFichier.lire(f.octets));
      if (mounted) setState(() => _bilan = bilan);
    } on PeseesIllisibles catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (e) {
      if (mounted) setState(() => _erreur = 'Le fichier n\'a pas pu être lu : $e');
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final acces = _acces;
    final bilan = _bilan;
    final (String titre, String texte) = switch ((_enCours, bilan)) {
      (true, null) => _fichier ? ('Lecture du fichier', 'Les pesées sont rangées jour par jour.') : ('Demande d\'accès', 'Réponds à Health Connect pour lancer la lecture.'),
      (true, final b?) => (Fmt.pluriel(b.valeurs, 'valeur lue', 'valeurs lues'), _mois == null ? 'Lecture en cours' : 'Lecture de ${Fmt.mois(_mois!).toLowerCase()}'),
      (false, final b?) when b.valeurs > 0 => (
          Fmt.pluriel(b.valeurs, 'valeur lue', 'valeurs lues'),
          '${Fmt.pluriel(b.jours, 'jour')}, du ${Mensurations.jourComplet(b.premier!)} au ${Mensurations.jourComplet(b.dernier!)}. '
              '${b.modifies == 0 ? 'Tout était déjà à jour.' : '${Fmt.pluriel(b.modifies, 'jour')} ${b.modifies >= 2 ? 'ajoutés ou corrigés' : 'ajouté ou corrigé'}.'}',
        ),
      (false, _?) => ('Aucune pesée trouvée', _fichier ? 'Ce fichier ne contient aucune pesée.' : 'Health Connect ne contient ni poids ni taux de gras lisible par l\'appli.'),
      (false, null) => ('Toutes tes pesées', 'Le poids et le taux de gras que ta balance envoie à Health Connect, un jour après l\'autre, depuis le début.'),
    };

    String etat(bool? ok, {String non = 'Non autorisé'}) => ok == null ? '' : (ok ? 'Autorisé' : non);

    return PageMaquette(
      titre: 'Balance connectée',
      bas: BoutonPrincipal(label: _enCours ? 'Lecture en cours' : (bilan == null ? 'Tout importer' : 'Relire tout'), onPressed: _enCours ? null : _importer),
      enfants: [
        Bloc(
          haut: 2,
          child: Carte(
            padding: EdgeInsets.all(e(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Surtitre(_fichier ? 'Fichier' : 'Health Connect'),
                SizedBox(height: e(2)),
                Text(titre, style: txt(22, FontWeight.w800, c.text)),
                SizedBox(height: e(4)),
                Text(texte, style: txt(12, FontWeight.w400, c.text2, interligne: 1.4)),
                if (_erreur != null) ...[
                  SizedBox(height: e(8)),
                  Text(_erreur!, style: txt(12, FontWeight.w600, c.error, interligne: 1.4)),
                ],
              ],
            ),
          ),
        ),
        GroupeTitre(
          titre: 'Historique plus ancien',
          lignes: [
            Ligne(
              trace: Trace.importer,
              titre: 'Importer un fichier',
              detail: 'L\'export de l\'appli de ta balance : le zip ou weight.csv',
              detailLignes: 2,
              actif: !_enCours,
              onTap: _importerFichier,
            ),
          ],
          note: 'Health Connect ne reçoit que les pesées récentes. Le fichier apporte tout le reste.',
        ),
        GroupeTitre(
          titre: 'Accès',
          lignes: [
            Ligne(trace: Trace.jauge, titre: 'Poids', valeur: etat(acces?.poids)),
            Ligne(trace: Trace.goutte, titre: 'Taux de gras', valeur: etat(acces?.gras)),
            Ligne(trace: Trace.horloge, titre: 'Historique complet', valeur: etat(acces?.historique, non: '30 jours seulement')),
          ],
          note: acces != null && !acces.historique
              ? 'Sans l\'historique complet, Health Connect ne donne que les 30 jours qui précèdent ta première autorisation. '
                  '« Tout importer » le demande ; s\'il ne le propose plus, ouvre Health Connect, Autorisations des applis, Aesthetics, '
                  'puis active « Accéder aux données antérieures ».'
              : 'Une saisie par jour : la dernière pesée du jour. Ce que tu as saisi à la main est gardé.',
        ),
      ],
    );
  }
}
