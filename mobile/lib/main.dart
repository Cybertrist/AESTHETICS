import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'core/data/data.dart';
import 'core/demo/demo_data.dart';
import 'core/demo/demo_images.dart';
import 'core/env.dart';
import 'core/theme/accent_controller.dart';
import 'core/theme/tokens.dart';
import 'core/ui/body/body_svg.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTokens.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  _declarerLicences();

  final store = await Store.open(demo: Env.demo);
  final data = AppData(store, demo: Env.demo);
  final accent = AccentController();
  await Future.wait([data.loadAll(), accent.load()]);

  // Variante démo : six mois de données inventées au premier lancement.
  if (Env.demo && !data.profile.hasProfile) {
    await DemoData.seed(data);
  } else if (Env.demo) {
    // Démo déjà installée : ses images de séance suivent le dessin en cours.
    DemoImages.rafraichir(Directory('${store.dir.path}${Platform.pathSeparator}medias'));
  }

  // Personnage lu et analysé une fois pour toutes, sans blanc au premier affichage.
  unawaited(BodySvgRepository.precache());

  runApp(AestheticApp(data: data, accent: accent));
}

/// Mentions MIT des dessins embarqués : elles apparaissent dans
/// Réglages > À propos > Licences, avec celles des bibliothèques.
void _declarerLicences() {
  const mit = 'Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated '
      'documentation files (the "Software"), to deal in the Software without restriction, including without limitation the '
      'rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit '
      'persons to whom the Software is furnished to do so, subject to the following conditions:\n\n'
      'The above copyright notice and this permission notice shall be included in all copies or substantial portions of the '
      'Software.\n\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE '
      'WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR '
      'COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR '
      'OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.';
  LicenseRegistry.addLicense(() => Stream.fromIterable(const [
        LicenseEntryWithLineBreaks(['Phosphor Icons'], 'MIT License\n\nCopyright (c) 2020 Phosphor Icons\n\n$mit'),
        LicenseEntryWithLineBreaks(['Fluent Emoji'], 'MIT License\n\nCopyright (c) Microsoft Corporation.\n\n$mit'),
      ]));
}
