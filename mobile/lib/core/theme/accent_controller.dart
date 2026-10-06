import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'tokens.dart';

/// Accent de l'appli : le rouge. [set] ne sert plus qu'à la page développeur.
class AccentController extends ChangeNotifier {
  static const _key = 'apparence.accent';

  AccentChoice _choice = AccentChoice.corail;
  ThemeData? _theme;

  AccentChoice get choice => _choice;
  Color get color => _choice.color;

  /// Thème complet pour l'accent courant (mis en cache).
  ThemeData get theme => _theme ??= AppTheme.dark(_choice.color);

  /// L'accent ne se choisit plus : c'est le rouge de l'appli, quel que
  /// soit ce qui avait été enregistré avant.
  Future<void> load() async {}

  Future<void> set(AccentChoice choice) async {
    if (choice == _choice) return;
    _choice = choice;
    _theme = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, choice.name);
    } catch (_) {}
  }
}
