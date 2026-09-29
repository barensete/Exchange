# FasoResto — caisse et comptabilité

Application Android (Kotlin, Jetpack Compose, Room) pour tenir la caisse et la
comptabilité du restaurant FasoResto. Elle remplace le classeur Excel
« Comptabilité Faso Resto » et en reprend toutes les règles de calcul.

- **Résumé** : recettes, dépenses par source, dettes envers Barka et Fodié,
  argent disponible, contrôles.
- **Caisse** : recette par service (Matin, Midi, Soir, Pâté, Autre), sortie
  de caisse automatique, argent compté et écart.
- **Dépenses** : saisie avec suggestions d'articles et de fournisseurs, filtre
  par « payé avec », lignes incomplètes signalées.
- **Impayés** : ventes à crédit et paiements partiels.
- **Plus** : remboursements, bilans jour / semaine / mois, loyer et salaires,
  sauvegarde, import et export Excel (CSV).

Tout fonctionne sans internet. Les données restent sur le téléphone.

La conception, les problèmes trouvés dans le classeur et la suite possible
sont décrits dans [docs/CONCEPTION.md](docs/CONCEPTION.md).

## Développement

```bash
./gradlew :core:test          # tests des calculs (sans Android)
./gradlew :app:assembleDebug  # APK → app/build/outputs/apk/debug/
```

Il faut le JDK 17 et le SDK Android (installé avec Android Studio). La CI
GitHub Actions construit l'APK à chaque envoi (artefact `FasoResto-apk`).

## Reprendre l'historique Excel

```bash
pip install openpyxl
python3 outils/excel_vers_json.py Comptabilite_faso_resto.xlsx fasoresto.json
```

Puis, dans l'application : **Plus → Importer une sauvegarde**.
