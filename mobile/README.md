# AESTHETICS, l'application

Le code de l'application Android, en Flutter. La présentation du projet est
dans le [README du dépôt](../README.md).

## Construire

    flutter pub get
    flutter build apk --release --target-platform android-arm64
    # la démo : six mois de séances inventées, dans un dossier de données à part
    flutter build apk --release --target-platform android-arm64 --dart-define=DEMO=true

`--dart-define=COMPLET=true` rallume les modules rangés (nutrition, sommeil,
coach).

## Le pack d'exercices

Le catalogue, les animations, les poses et le personnage viennent d'un pack
sous licence commerciale, qui n'est pas dans le dépôt :

- `assets/data/exercises.json`
- `assets/exercises/anim/`, `assets/exercises/poses/`, `assets/exercises/materiel/`
- `assets/body/pack/`

Ces dossiers sont déclarés dans `pubspec.yaml` : sans eux, la construction
s'arrête. `tools/repdb/` dit comment ils sont produits à partir du pack.

## Où est quoi

- `lib/app/` : le routeur et les dépôts fournis à tout l'arbre.
- `lib/core/` : les modèles, les dépôts (un fichier JSON par collection), les
  calculs sans écran (`logic/`), le thème et les composants partagés.
- `lib/features/` : un dossier par module, chacun avec ses routes.
- `test/` : rangé comme le code, un dossier par module.
- `tools/` et `tool/` : les scripts qui préparent le personnage, l'icône et
  le catalogue.

## Tester

    flutter analyze lib test
    flutter test

Les tests de rendu écrivent leurs images dans `build/rendus/`.
