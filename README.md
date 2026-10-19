# FasoResto — caisse et comptabilité

Application Android en **Flutter** pour tenir la caisse et la comptabilité du
restaurant FasoResto. Elle remplace le classeur Excel « Comptabilité Faso
Resto » et en reprend toutes les règles de calcul.

- **Résumé** : recettes, dépenses par source, dettes envers Barka et Fodié,
  argent disponible, contrôles.
- **Caisse** : recette par service (Matin, Midi, Soir, Pâté, Autre), sortie
  de caisse automatique, argent compté et écart.
- **Dépenses** : saisie avec suggestions d'articles et de fournisseurs,
  filtre par « payé avec », lignes incomplètes signalées.
- **Impayés** : ventes à crédit et paiements partiels.
- **Plus** : remboursements, bilans jour / semaine / mois, loyer et salaires,
  sauvegarde, import et export Excel (CSV).

Tout fonctionne sans internet. Les données restent sur le téléphone.

La conception, les erreurs trouvées dans le classeur et la suite possible sont
décrites dans [docs/CONCEPTION.md](docs/CONCEPTION.md).

## Installer l'environnement sur le PC (une seule fois)

1. **Flutter** : suivez https://docs.flutter.dev/get-started/install (choisir
   Windows, puis Android). Ajoutez `flutter\bin` au `PATH`.
2. **Android Studio** : à installer seulement pour le SDK Android et
   l'émulateur. Ouvrez-le une fois, puis *More Actions → SDK Manager* et
   installez le SDK et les *Command-line Tools*.
3. Dans un terminal, lancez `flutter doctor --android-licenses` (répondez `y`),
   puis `flutter doctor`. Tout doit être vert pour Flutter et Android.
4. **VS Code** : installez l'extension **Flutter** (Dart-Code). VS Code la
   propose tout seul à l'ouverture du projet.

## Travailler sur le projet dans VS Code

```bash
git clone https://github.com/barensete/Exchange.git fasoresto
cd fasoresto
git checkout flutter-fasoresto
code .
```

- `flutter pub get` télécharge les dépendances (VS Code le fait aussi tout seul).
- Branchez le téléphone en USB (mode développeur + débogage USB activés) ou
  lancez un émulateur. Choisissez l'appareil en bas à droite de VS Code.
- **F5** lance l'application. Pendant qu'elle tourne, chaque enregistrement
  d'un fichier met l'écran à jour (*hot reload*).
- `flutter test` lance les tests. `flutter analyze` vérifie le code.
- `flutter build apk --release` construit l'APK dans
  `build/app/outputs/flutter-apk/app-release.apk`.

À chaque envoi sur GitHub, l'onglet **Actions** vérifie le code, lance les
tests et construit l'APK (artefact `FasoResto-apk`).

## Organisation du code

```
lib/
  main.dart               démarrage
  modele/modeles.dart     Journée, Dépense, Impayé, Remboursement, Paramètres
  calcul/comptabilite.dart  les formules du classeur (Résumé, caisse, bilans)
  calcul/format.dart      affichage des montants (12 500 F) et des dates
  io/sauvegarde.dart      sauvegarde JSON et export CSV pour Excel
  io/import_excel.dart    lecture directe du classeur Excel (.xlsx)
  donnees/depot.dart      garde les données et les enregistre sur le téléphone
  ui/app.dart             thème et onglets du bas
  ui/composants.dart      champs de saisie et cartes réutilisables
  ui/ecrans/              un fichier par onglet
test/                     tests des calculs et des écrans
outils/excel_vers_json.py reprise de l'historique Excel
```

## Reprendre l'historique Excel

Copiez le fichier `Comptabilite_faso_resto.xlsx` sur le téléphone (WhatsApp,
Drive, câble USB), puis dans l'application : **Plus → Importer le fichier
Excel**. Quand l'application est vide, le Résumé propose aussi un bouton
**Importer mon fichier Excel**.

Sur le PC, `outils/excel_vers_json.py` produit la même chose sous forme de
sauvegarde `.json` (Plus → Importer une sauvegarde).
