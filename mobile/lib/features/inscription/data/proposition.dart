import 'package:flutter/foundation.dart';

import '../../../core/models/models.dart';
import 'program_generator.dart';

/// Programme proposé en cours de relecture, partagé entre la page du
/// programme et ses sous-pages (séance, remplacement d'exercice).
class PropositionCourante extends ChangeNotifier {
  Proposal? proposal;
  UserProfile? profil;
  Set<Muscle> prioritaires = {};

  /// Vrai dès qu'une séance a été retouchée à la main.
  bool retouche = false;

  void definir(Proposal p, UserProfile profil, Set<Muscle> prioritaires) {
    proposal = p;
    this.profil = profil;
    this.prioritaires = prioritaires;
    retouche = false;
    notifyListeners();
  }

  void modifierSeance(int i, void Function(ProposedRoutine r) change) {
    final p = proposal;
    if (p == null || i < 0 || i >= p.seances.length) return;
    change(p.seances[i]);
    retouche = true;
    notifyListeners();
  }

  void vider() {
    proposal = null;
    retouche = false;
    notifyListeners();
  }
}

final propositionCourante = PropositionCourante();
