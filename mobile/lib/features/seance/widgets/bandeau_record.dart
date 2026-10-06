import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../entrainer/commun/elements.dart';
import '../../profil/widgets/ecusson.dart';
import 'habillage.dart';
import 'serie_ligne.dart' show orPale;

/// Un record à annoncer : l'exercice et une ligne par record battu
/// (« Charge maximale · 35 kg », « 1RM estimé · 41 kg »).
class AnnonceRecord {
  AnnonceRecord({required this.exercise, required this.nom, required this.lignes});
  final Exercise? exercise;
  final String nom;
  final List<String> lignes;
}

/// Annonce d'un record en haut de la séance : l'écusson « PR » apparaît
/// seul, s'ouvre en pilule avec l'exercice et fait défiler les records
/// battus, puis se referme.
class BandeauRecord extends StatefulWidget {
  const BandeauRecord({super.key, required this.annonce});

  /// Chaque nouvelle valeur lance une annonce.
  final ValueListenable<AnnonceRecord?> annonce;

  /// Temps de l'écusson seul, puis de chaque ligne.
  static const tempsEcusson = Duration(milliseconds: 900);
  static const tempsLigne = Duration(milliseconds: 2100);

  @override
  State<BandeauRecord> createState() => _BandeauRecordState();
}

class _BandeauRecordState extends State<BandeauRecord> {
  AnnonceRecord? _a;

  /// -1 : l'écusson seul ; sinon le rang de la ligne affichée.
  int _ligne = -1;
  Timer? _suite;

  @override
  void initState() {
    super.initState();
    widget.annonce.addListener(_lancer);
  }

  @override
  void dispose() {
    widget.annonce.removeListener(_lancer);
    _suite?.cancel();
    super.dispose();
  }

  void _lancer() {
    final a = widget.annonce.value;
    if (a == null || a.lignes.isEmpty || !mounted) return;
    _suite?.cancel();
    setState(() {
      _a = a;
      _ligne = -1;
    });
    // Une vibration à l'apparition de l'écusson, puis à chaque record annoncé.
    HapticFeedback.mediumImpact();
    _suite = Timer(BandeauRecord.tempsEcusson, _avancer);
  }

  void _avancer() {
    if (!mounted) return;
    final a = _a;
    if (a == null) return;
    if (_ligne + 1 >= a.lignes.length) {
      setState(() => _a = null);
      return;
    }
    setState(() => _ligne++);
    HapticFeedback.mediumImpact();
    _suite = Timer(BandeauRecord.tempsLigne, _avancer);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = _a;
    final ouvert = a != null && _ligne >= 0;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)), child: child),
        ),
        child: a == null
            ? const SizedBox.shrink()
            : Semantics(
                key: ValueKey(a),
                liveRegion: true,
                label: 'Record battu, ${a.nom}${ouvert ? ', ${a.lignes[_ligne]}' : ''}',
                excludeSemantics: true,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  height: k(56),
                  width: ouvert ? k(300) : k(56),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E0E10),
                    borderRadius: BorderRadius.circular(k(28)),
                    border: Border.all(color: orPale.withValues(alpha: 0.35), width: 1.2),
                    boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 6))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ouvert
                      // La pilule : l'exercice, puis le record battu en doré.
                      ? OverflowBox(
                          maxWidth: k(300),
                          minWidth: k(300),
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: k(8)),
                            child: Row(
                              children: [
                                TuileExercice(a.exercise, taille: k(40)),
                                SizedBox(width: k(10)),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.nom,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.25, fontWeight: FontWeight.w700, color: c.text),
                                      ),
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 220),
                                        child: Align(
                                          key: ValueKey(_ligne),
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            a.lignes[_ligne],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.3, fontWeight: FontWeight.w600, color: orPale, fontFeatures: AppTokens.tabular),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Ecusson.record(largeur: k(30)),
                                SizedBox(width: k(4)),
                              ],
                            ),
                          ),
                        )
                      : Center(child: Ecusson.record(largeur: k(38))),
                ),
              ),
      ),
    );
  }
}
