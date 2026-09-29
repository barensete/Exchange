# FasoResto — de l'Excel à l'application Android

Ce document explique comment le classeur « Comptabilité Faso Resto » a été
analysé, ce que l'application reprend, et les choix techniques recommandés.

## 1. Ce que fait le classeur aujourd'hui

| Onglet | Rôle | Dans l'application |
|---|---|---|
| **Recettes** | Une ligne par jour : Matin, Midi, Soir, Pâté, Autre ; sortie de caisse calculée ; argent compté → écart ; fond de caisse | Onglet **Caisse** |
| **Dépenses** | Une ligne par achat : article, quantité, montant, *payé avec* (Caisse, Trésorerie, Barka, Fodié, Partagé), catégorie, fournisseur | Onglet **Dépenses** |
| **Impayés** | Ventes à crédit, statut Payé / Non payé, ligne « Autre » pour le solde d'un paiement partiel | Onglet **Impayés** (paiements partiels gérés directement) |
| **Remboursements** | Argent rendu à Barka / Fodié | **Plus → Remboursements** |
| **Résumé** | Totaux, dettes envers les associés, argent disponible, contrôles | Onglet **Résumé** (écran d'accueil) |
| **Par jour / Semaines & mois** | Bilans, part de la viande, résultat après loyer et salaires | **Plus → Bilans** |
| **Listes** | Articles et fournisseurs déjà utilisés | Suggestions automatiques pendant la saisie |
| **À vérifier** | Points à confirmer | Filtre « À corriger » + contrôles du Résumé |

Toutes les formules du Résumé et des bilans sont reproduites à l'identique dans
`core/src/main/kotlin/com/fasoresto/core/calcul/Comptabilite.kt`. Sur vos
données réelles (29 journées, 293 dépenses, 13 impayés, 2 remboursements),
l'application retrouve exactement les chiffres du classeur, sauf pour
l'erreur n° 1 ci-dessous, qu'elle corrige.

## 2. Problèmes trouvés dans le classeur

1. **Un montant tapé en texte est ignoré par Excel.** Dépenses, « Pomme de
   terre sac 25 kg » : le montant est écrit `18000F` (texte), donc Excel ne
   l'additionne pas. Le Résumé affiche un total de dépenses de 2 678 805 F et un
   total Trésorerie de 912 190 F, alors que les vrais chiffres sont 2 696 805 F
   et 930 190 F. L'argent disponible est donc surestimé de 18 000 F
   (600 230 F au lieu de 582 230 F). Dans l'application, un montant est
   toujours un nombre.
2. **Trois dépenses sont datées du 26/07/2026**, un mois avant l'ouverture
   (Oignons 15 000 F, Pomme de terre 18 000 F, Pain court 11 050 F, soit
   44 050 F). C'est sans doute le 26/09. Elles n'apparaissent dans aucune
   semaine ni aucun mois du classeur. Dans l'application, la date est choisie
   dans un calendrier et vaut aujourd'hui par défaut.
3. **La liste déroulante des catégories** contient « Petites dépenses / non
   identifiée » (sans « s »), alors que les lignes utilisent « non
   identifiées ». L'application utilise une liste fixe.
4. **Les paiements partiels d'impayés** obligent à marquer la ligne « Payé »
   puis à créer une ligne « Autre » pour le reste. L'application enregistre
   chaque paiement (date + montant) et calcule elle-même le reste dû.
5. **La caisse n'a été comptée qu'un seul jour sur 29.** L'écart de caisse est
   le meilleur contrôle contre les erreurs et les pertes. L'écran de caisse
   demande l'argent compté en fin de journée et affiche l'écart tout de suite.
6. **Loyer et salaires à confirmer** : 120 000 F + 150 000 F dans le classeur,
   mais 285 000 F cités ailleurs. Vous pouvez les changer dans **Plus →
   Paramètres**.

## 3. Solution recommandée

**Application Android native (Kotlin + Jetpack Compose), qui fonctionne sans
internet et garde les données sur le téléphone (base Room / SQLite).**

Pourquoi ce choix :

- **Hors ligne d'abord** : la saisie marche même sans connexion. Rien n'est
  perdu si le réseau coupe.
- **Rapide sur des téléphones d'entrée de gamme** (Android 8 et plus).
- **Pas d'abonnement ni de serveur** pour commencer. La sauvegarde est un
  simple fichier que vous gardez sur Google Drive ou envoyez par WhatsApp.
- **La comptabilité est testée à part** (module `core`, du Kotlin pur) :
  chaque règle du classeur a son test automatique, et on peut la réutiliser
  plus tard sur un serveur ou dans une version web.

Autres options envisagées :

| Option | Avantages | Inconvénients |
|---|---|---|
| Google Sheets + AppSheet / Glide (sans code) | Très rapide à mettre en place, multi-utilisateurs | Abonnement, dépend d'internet, formules fragiles (même problème que l'Excel) |
| Flutter / React Native | Android + iPhone | Plus lourd, inutile si tout le monde est sur Android |
| **Kotlin natif, hors ligne (choisi)** | Fiable, rapide, gratuit, contrôle total | Android uniquement ; la synchronisation entre plusieurs téléphones est à ajouter plus tard |

## 4. Architecture du code

```
core/   Kotlin pur, sans Android : modèles, calculs (= formules Excel),
        sauvegarde JSON, export CSV. Tests : ./gradlew :core:test
app/    Application Android : base de données Room, écrans Compose.
outils/excel_vers_json.py   Reprend l'historique du classeur Excel.
```

- `core/modele/Modeles.kt` : Journée, Dépense, Impayé (+ paiements),
  Remboursement, Paramètres.
- `core/calcul/Comptabilite.kt` : sortie de caisse, reste, écart, Résumé,
  bilans par jour, semaine et mois.
- `app/donnees/` : tables Room et `Depot`, qui convertit la base vers les
  modèles de `core`.
- `app/ui/ecrans/` : un fichier par onglet.

Les montants sont des nombres entiers en francs CFA (jamais de virgule), ce
qui évite les erreurs d'arrondi.

## 5. Mettre vos données Excel dans l'application

```bash
pip install openpyxl
python3 outils/excel_vers_json.py Comptabilite_faso_resto.xlsx fasoresto.json
```

Copiez ensuite `fasoresto.json` sur le téléphone (WhatsApp, Drive, câble
USB), puis dans l'application : **Plus → Importer une sauvegarde**.

Corrigez d'abord les trois dates du 26/07 dans l'Excel, ou modifiez-les
ensuite dans l'application.

## 6. Obtenir et installer l'APK

- **Sans rien installer** : à chaque envoi sur GitHub, l'onglet *Actions* du
  dépôt construit l'application. Ouvrez la dernière exécution « Android »,
  téléchargez l'artefact **FasoResto-apk**, puis ouvrez le `.apk` sur le
  téléphone (autorisez « sources inconnues »).
- **Avec Android Studio** : ouvrez le dossier du projet, puis cliquez sur
  ▶ Run avec le téléphone branché en USB (mode développeur activé).

## 7. Suite possible (par ordre d'utilité)

1. **Menu et prix des plats** : taper « 3 riz mafé + 2 fonio » au lieu d'un
   total par service. L'application calcule le montant et vous savez quels
   plats se vendent.
2. **Plusieurs téléphones** (caissier + gérant) avec synchronisation
   (Firebase ou Supabase), et des rôles : le caissier saisit, le gérant voit
   les bilans.
3. **Stock** de viande, gaz et charbon, pour suivre le coût réel par semaine
   (aujourd'hui la viande est achetée pour plusieurs jours).
4. **Orange Money / Moov Money** comme moyen de paiement à part, pour
   rapprocher la caisse espèces.
5. **Rapport PDF mensuel** à partager, et **impression de tickets** sur
   imprimante Bluetooth.

## 8. Questions à trancher

- **Paiement d'un impayé reçu plus tard** : le classeur ne l'ajoute ni à la
  caisse du jour ni à l'argent disponible, et l'application fait pareil pour
  rester fidèle. Si cet argent entre réellement dans la caisse, il faut
  décider s'il doit s'ajouter au « reste en caisse » du jour où il est reçu.
- **Remboursement payé par la Caisse** (ex. 12 700 F à Fodié le 16/09) : il
  est déduit de l'argent disponible, mais pas de la sortie de caisse du jour.
  Même question.
- **Dépenses « Partagé »** (139 900 F) : faut-il noter la part de Barka et la
  part de Fodié pour chaque achat ?
