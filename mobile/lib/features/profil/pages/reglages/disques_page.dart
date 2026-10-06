import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../data/plates.dart';
import '../../data/prefs.dart';
import '../../widgets/maquette.dart';
import '../../widgets/setting_rows.dart';

/// Réglages > Paramètres de séance > Barres et disques, avec le calculateur.
class DisquesPage extends StatelessWidget {
  const DisquesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageMaquette(
      titre: 'Barres et disques',
      sousTitre: 'Le matériel de ta salle',
      action: BoutonRond(
        trace: Trace.restaurer,
        label: 'Revenir au matériel par défaut',
        onTap: () async {
          final repo = await PrefsRepo.ensure(context.read<Store>());
          if (context.mounted) await _reinitialiser(context, repo);
        },
      ),
      enfants: [
        PrefsBuilder(builder: (context, prefs, repo) => _Contenu(prefs: prefs, repo: repo)),
        SizedBox(height: e(18)),
      ],
    );
  }

  static Future<void> _reinitialiser(BuildContext context, PrefsRepo repo) async {
    final choix = await showPanneauBas<String>(
      context,
      titre: 'Matériel par défaut',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: e(10)),
            child: Text('Remplace tes barres et tes disques.', textAlign: TextAlign.center, style: txt(12, FontWeight.w400, context.colors.text2)),
          ),
          ChoixPanneau(label: 'Disques en kilogrammes', onTap: () => Navigator.pop(context, 'kg')),
          ChoixPanneau(label: 'Disques en livres', onTap: () => Navigator.pop(context, 'lb')),
        ],
      ),
    );
    if (choix == null) return;
    final disques = choix == 'kg'
        ? ProfilPrefs.disquesParDefaut
        : [
            for (final (lb, n) in [(45.0, 4), (35.0, 2), (25.0, 2), (10.0, 2), (5.0, 2), (2.5, 2)])
              Disque(poidsKg: Fmt.poidsStocke(lb, UnitePoids.lb), paires: n),
          ];
    await repo.update((p) => p.copyWith(barres: ProfilPrefs.barresParDefaut, barreParDefaut: 'olympique', disques: disques));
    if (context.mounted) Toasts.success(context, 'Matériel remis par défaut');
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({required this.prefs, required this.repo});
  final ProfilPrefs prefs;
  final PrefsRepo repo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unite = context.watch<ProfileRepo>().unite;
    Widget vide(String texte) => Padding(
          padding: EdgeInsets.symmetric(horizontal: e(12), vertical: e(14)),
          child: Text(texte, textAlign: TextAlign.center, style: txt(12, FontWeight.w400, c.text2)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Bloc(haut: 2, bas: 6, child: _Calculateur(prefs: prefs, unite: unite)),
        GroupeTitre(
          titre: 'Barres',
          fin: LienTitre(label: 'Ajouter', onTap: () => _editerBarre(context, null, unite)),
          lignes: [
            if (prefs.barres.isEmpty) vide('Aucune barre. Ajoute celle de ta salle.'),
            for (final b in prefs.barres) _LigneBarre(barre: b, parDefaut: b.id == prefs.barreParDefaut, repo: repo, unite: unite),
          ],
        ),
        GroupeTitre(
          titre: 'Disques',
          fin: LienTitre(label: 'Ajouter', onTap: () => _ajouterDisque(context, unite)),
          lignes: [
            if (prefs.disques.isEmpty) vide('Aucun disque. Ajoute ceux qui sont disponibles.'),
            for (final d in [...prefs.disques]..sort((a, b) => b.poidsKg.compareTo(a.poidsKg))) _LigneDisque(disque: d, repo: repo, unite: unite),
          ],
          note: 'Touche une barre pour la modifier. Le nombre de paires limite ce que propose le calculateur.',
        ),
      ],
    );
  }

  Future<void> _editerBarre(BuildContext context, Barre? b, UnitePoids unite) async {
    final nom = await showTextInputDialog(context, title: b == null ? 'Nouvelle barre' : 'Nom de la barre', initial: b?.nom ?? '', hint: 'Barre hexagonale', maxLength: 40);
    if (nom == null || !context.mounted) return;
    final poids = await showNumberInputDialog(
      context,
      title: 'Poids de la barre',
      unit: unite.label,
      initial: b == null ? null : Fmt.poidsAffiche(b.poidsKg, unite),
    );
    if (poids == null || poids < 0 || poids > 200) return;
    final kg = Fmt.poidsStocke(poids, unite);
    await repo.update((p) {
      if (b == null) {
        return p.copyWith(barres: [...p.barres, Barre(id: newId(), nom: nom, poidsKg: kg)]);
      }
      return p.copyWith(barres: [for (final x in p.barres) x.id == b.id ? x.copyWith(nom: nom, poidsKg: kg) : x]);
    });
  }

  Future<void> _ajouterDisque(BuildContext context, UnitePoids unite) async {
    final v = await showNumberInputDialog(context, title: 'Poids du disque', unit: unite.label);
    if (v == null || v <= 0 || v > 100) return;
    final kg = Fmt.poidsStocke(v, unite);
    await repo.update((p) {
      final existe = p.disques.any((d) => (d.poidsKg - kg).abs() < 0.01);
      if (existe) {
        return p.copyWith(disques: [for (final d in p.disques) (d.poidsKg - kg).abs() < 0.01 ? d.copyWith(paires: d.paires + 1) : d]);
      }
      return p.copyWith(disques: [...p.disques, Disque(poidsKg: kg, paires: 1)]);
    });
  }
}

enum _ActionBarre { defaut, modifier, supprimer }

class _LigneBarre extends StatelessWidget {
  const _LigneBarre({required this.barre, required this.parDefaut, required this.repo, required this.unite});
  final Barre barre;
  final bool parDefaut;
  final PrefsRepo repo;
  final UnitePoids unite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Ligne(
      trace: Trace.barre,
      titre: barre.nom,
      detail: parDefaut ? 'Par défaut' : (barre.active ? 'Disponible' : 'Masquée'),
      valeur: Fmt.poids(barre.poidsKg, unite),
      fin: Semantics(
        label: '${barre.nom} disponible',
        child: Switch(
          value: barre.active,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          activeThumbColor: c.onBouton,
          activeTrackColor: c.bouton,
          inactiveThumbColor: c.text2,
          inactiveTrackColor: c.surface2,
          trackOutlineColor: WidgetStatePropertyAll(c.surface2.withValues(alpha: 0)),
          onChanged: (v) => repo.update((p) => p.copyWith(barres: [for (final x in p.barres) x.id == barre.id ? x.copyWith(active: v) : x])),
        ),
      ),
      onTap: () async {
        final a = await showPanneauBas<_ActionBarre>(
          context,
          titre: barre.nom,
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!parDefaut) LigneAction(icone: const IconeTrait(Trace.etoile, taille: 24), label: 'Utiliser par défaut', onTap: () => Navigator.pop(context, _ActionBarre.defaut)),
              LigneAction(icone: const IconeTrait(Trace.crayon, taille: 24), label: 'Modifier', onTap: () => Navigator.pop(context, _ActionBarre.modifier)),
              LigneAction(
                icone: IconeTrait(Trace.poubelle, taille: 24, couleur: context.colors.error),
                label: 'Supprimer',
                destructif: true,
                onTap: () => Navigator.pop(context, _ActionBarre.supprimer),
              ),
            ],
          ),
        );
        if (!context.mounted || a == null) return;
        switch (a) {
          case _ActionBarre.defaut:
            await repo.update((p) => p.copyWith(
                  barreParDefaut: barre.id,
                  barres: [for (final x in p.barres) x.id == barre.id ? x.copyWith(active: true) : x],
                ));
          case _ActionBarre.modifier:
            final state = context.findAncestorWidgetOfExactType<_Contenu>();
            await state?._editerBarre(context, barre, unite);
          case _ActionBarre.supprimer:
            final ok = await showConfirmDialog(context, title: 'Supprimer ${barre.nom} ?', confirmLabel: 'Supprimer', destructive: true);
            if (ok) await repo.update((p) => p.copyWith(barres: p.barres.where((x) => x.id != barre.id).toList()));
        }
      },
    );
  }
}

class _LigneDisque extends StatelessWidget {
  const _LigneDisque({required this.disque, required this.repo, required this.unite});
  final Disque disque;
  final PrefsRepo repo;
  final UnitePoids unite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Ligne(
      icone: IconeTrait(Trace.disque, taille: e(16), couleur: _couleur(c, disque.poidsKg)),
      titre: _poids(disque.poidsKg, unite),
      detail: disque.paires == 0 ? 'Aucune paire' : '${Fmt.pluriel(disque.paires, 'paire')} · ${disque.paires * 2} disques',
      fin: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pas(trace: Trace.moins, label: 'Une paire de moins', onTap: () => _changer(context, -1)),
          SizedBox(width: e(26), child: Text('${disque.paires}', textAlign: TextAlign.center, style: txt(13, FontWeight.w700, c.text))),
          _Pas(trace: Trace.plus, label: 'Une paire de plus', onTap: disque.paires >= 20 ? null : () => _changer(context, 1)),
        ],
      ),
    );
  }

  Future<void> _changer(BuildContext context, int delta) async {
    final n = disque.paires + delta;
    if (n <= 0) {
      final ok = await showConfirmDialog(
        context,
        title: 'Retirer les disques de ${_poids(disque.poidsKg, unite)} ?',
        confirmLabel: 'Retirer',
        destructive: true,
      );
      if (!ok) return;
      await repo.update((p) => p.copyWith(disques: p.disques.where((d) => d.poidsKg != disque.poidsKg).toList()));
      return;
    }
    await repo.update((p) => p.copyWith(disques: [for (final d in p.disques) d.poidsKg == disque.poidsKg ? d.copyWith(paires: n) : d]));
  }
}

/// Petit bouton rond gris (une paire de plus ou de moins).
class _Pas extends StatelessWidget {
  const _Pas({required this.trace, required this.label, required this.onTap});
  final Trace trace;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: c.surface2,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: e(34),
              child: Center(child: IconeTrait(trace, taille: e(13), couleur: c.text.withValues(alpha: onTap == null ? 0.3 : 1), epaisseur: 2)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Teinte d'un disque selon son poids : du blanc (lourd) au gris (léger),
/// sans couleur de domaine.
Color _couleur(AppColors c, double kg) {
  final double force;
  if (kg >= 20) {
    force = 1;
  } else if (kg >= 15) {
    force = 0.82;
  } else if (kg >= 10) {
    force = 0.66;
  } else if (kg >= 5) {
    force = 0.5;
  } else {
    force = 0.36;
  }
  return c.text.withValues(alpha: force);
}

class _Calculateur extends StatefulWidget {
  const _Calculateur({required this.prefs, required this.unite});
  final ProfilPrefs prefs;
  final UnitePoids unite;

  @override
  State<_Calculateur> createState() => _CalculateurState();
}

class _CalculateurState extends State<_Calculateur> {
  double? _cible;
  String? _barreId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = widget.prefs;
    final u = widget.unite;
    final actives = p.barres.where((b) => b.active).toList();
    final barre = actives.where((b) => b.id == (_barreId ?? p.barreParDefaut)).firstOrNull ?? actives.firstOrNull;
    if (barre == null) {
      return Carte(
        padding: EdgeInsets.all(e(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Surtitre('Calculateur'),
            SizedBox(height: e(8)),
            Text('Aucune barre active', style: txt(14, FontWeight.w700, c.text)),
            Text('Active ou ajoute une barre pour calculer une charge.', style: txt(12, FontWeight.w400, c.text2)),
          ],
        ),
      );
    }
    final pas = u == UnitePoids.kg ? 2.5 : 5.0;
    final mini = Fmt.poidsAffiche(barre.poidsKg, u);
    final cibleAffichee = math.max(mini, _cible ?? (mini + (u == UnitePoids.kg ? 40 : 90)));
    final res = Plates.charger(Fmt.poidsStocke(cibleAffichee, u), barre.poidsKg, p.disques);
    final max = Plates.maximum(barre.poidsKg, p.disques);
    return Carte(
      padding: EdgeInsets.all(e(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Surtitre('Calculateur')),
              Text('max ${Fmt.poids(max, u)}', style: txt(11, FontWeight.w400, c.text2)),
            ],
          ),
          if (actives.length > 1) ...[
            SizedBox(height: e(8)),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final b in actives)
                    Padding(
                      padding: EdgeInsets.only(right: e(6)),
                      child: Puce(label: b.nom, choisie: b.id == barre.id, onTap: () => setState(() => _barreId = b.id)),
                    ),
                ],
              ),
            ),
          ],
          SizedBox(height: e(6)),
          Row(
            children: [
              _Pas(trace: Trace.moins, label: 'Charge plus légère', onTap: cibleAffichee - pas < mini ? null : () => setState(() => _cible = cibleAffichee - pas)),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Charge visée, ${Fmt.n(cibleAffichee, decimals: 2)} ${u.label}. Toucher pour la saisir',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(e(10)),
                    onTap: () async {
                      final v = await showNumberInputDialog(context, title: 'Charge visée', unit: u.label, initial: cibleAffichee);
                      if (v != null && v >= mini && v <= 1000) setState(() => _cible = v);
                    },
                    child: Column(
                      children: [
                        Text.rich(
                          TextSpan(
                            text: Fmt.n(cibleAffichee, decimals: 2),
                            children: [TextSpan(text: ' ${u.label}', style: txt(13, FontWeight.w600, c.text2))],
                          ),
                          style: txt(26, FontWeight.w800, c.text, interligne: 1.1, espacement: -0.02),
                        ),
                        Text('Charge visée', style: txt(10.5, FontWeight.w400, c.text2)),
                      ],
                    ),
                  ),
                ),
              ),
              _Pas(trace: Trace.plus, label: 'Charge plus lourde', onTap: cibleAffichee + pas > 1000 ? null : () => setState(() => _cible = cibleAffichee + pas)),
            ],
          ),
          SizedBox(height: e(12)),
          _BarreDessin(parCote: res.parCote),
          SizedBox(height: e(10)),
          Text(
            res.parCote.isEmpty ? 'Barre seule' : 'Par côté : ${res.parCote.map((d) => Fmt.n(Fmt.poidsAffiche(d, u), decimals: 2)).join(' + ')}',
            style: txt(13, FontWeight.w600, c.text),
          ),
          SizedBox(height: e(2)),
          Text(
            res.exact
                ? 'Total ${Fmt.poids(res.totalKg, u)} avec ${barre.nom.toLowerCase()}'
                : 'Au plus près : ${Fmt.poids(res.totalKg, u)}, il manque ${Fmt.poids(res.ecartKg, u)}',
            style: txt(12, FontWeight.w400, res.exact ? c.text2 : c.warning),
          ),
        ],
      ),
    );
  }
}

/// La barre vue de face, disques d'un côté (en miroir).
class _BarreDessin extends StatelessWidget {
  const _BarreDessin({required this.parCote});
  final List<double> parCote;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget disque(double kg) {
      final h = 26 + 58 * math.min(1.0, kg / 25).toDouble();
      return Container(
        width: kg >= 10 ? 13 : 9,
        height: h,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: _couleur(c, kg), borderRadius: BorderRadius.circular(3)),
      );
    }

    final droite = [for (final d in parCote) disque(d)];
    return Semantics(
      image: true,
      label: 'Dessin de la barre chargée',
      child: SizedBox(
        height: 90,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(height: 8, decoration: BoxDecoration(color: c.text3, borderRadius: AppTokens.radiusPill)),
            Container(width: 64, height: 14, decoration: BoxDecoration(color: c.text2, borderRadius: AppTokens.radius8)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...droite.reversed,
                  const SizedBox(width: 72),
                  ...droite,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Poids d'un disque avec deux décimales au besoin (1,25 kg).
String _poids(double kg, UnitePoids u) => '${Fmt.n(Fmt.poidsAffiche(kg, u), decimals: 2)} ${u.label}';
