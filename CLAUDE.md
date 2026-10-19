# FasoResto — guide de développement

Ce fichier est lu automatiquement par **Claude Code** à chaque session. Il
explique le projet, les règles de calcul et la façon de travailler. Gardez-le
à jour quand une règle change.

## Le projet en bref

Application **Android en Flutter** pour tenir la **caisse et la comptabilité**
du restaurant FasoResto (associés : **Barka** et **Fodié**). Elle remplace le
classeur Excel « Comptabilité Faso Resto » et doit retrouver **exactement**
les mêmes chiffres que lui.

- Utilisateurs : le gérant et la personne qui tient la caisse, sur un
  téléphone Android d'entrée de gamme.
- Langue : **tout en français** (textes de l'app, noms dans le code,
  commentaires, messages de commit).
- **Hors ligne** : aucune connexion n'est nécessaire. Les données restent sur
  le téléphone.
- Monnaie : **franc CFA**, toujours des **entiers** (`int`), jamais de
  virgule. Affichage : `12 500 F`.

## Commandes

```bash
flutter pub get            # dépendances
flutter run                # lancer sur le téléphone ou l'émulateur (F5 dans VS Code)
flutter test               # tous les tests (doivent passer avant chaque commit)
flutter analyze            # vérification du code (doit afficher « No issues found »)
dart format -l 120 lib test  # mise en forme (lignes de 120 caractères)
flutter build apk --release  # APK → build/app/outputs/flutter-apk/app-release.apk
```

La CI GitHub Actions (`.github/workflows/flutter.yml`) lance analyze, test et
build à chaque envoi. L'APK est publié en artefact `FasoResto-apk`.

## Organisation du code

```
lib/
  main.dart                  ouvre le Depot puis lance l'app
  modele/modeles.dart        Journee, Depense, Impaye (+ Reglement), Remboursement,
                             Parametres, Donnees ; enums SourcePaiement, Categorie,
                             Service, Associe
  calcul/comptabilite.dart   TOUTES les formules (Résumé, caisse du jour, bilans)
  calcul/format.dart         enFcfa(), enTexte(date), lireMontant(), nomMois()
  io/sauvegarde.dart         Sauvegarde (JSON) et ExportCsv (Excel, séparateur « ; »)
  io/import_excel.dart       ImportExcel.lire(octets) : lit directement le classeur .xlsx
  donnees/depot.dart         Depot (ChangeNotifier) : données en mémoire + fichier JSON
                             sur le téléphone ; DepotScope.de(context) pour y accéder
  ui/app.dart                MaterialApp (thème vert, français) + 5 onglets du bas
  ui/composants.dart         Section, LigneMontant, ChampMontant, ChampDate,
                             ChoixPastilles, Selecteur, ChampSuggestions, Formulaire…
  ui/ecrans/
    accueil.dart             onglet Résumé
    caisse.dart              onglet Caisse + saisie d'une journée
    depenses.dart            onglet Dépenses + saisie d'une dépense
    impayes.dart             onglet Impayés + paiements partiels
    plus.dart                Plus : Bilans, Remboursements, Paramètres, sauvegarde/export/import
test/
  comptabilite_test.dart     tests des formules, de la sauvegarde et du CSV
  app_test.dart              tests des écrans (saisie caisse, ajout dépense)
outils/excel_vers_json.py    convertit le classeur Excel en sauvegarde importable
docs/CONCEPTION.md           analyse du classeur, choix techniques, suite possible
```

### Principes

1. **Les calculs restent dans `lib/calcul/`**, sans aucun import Flutter. Les
   écrans ne font qu'afficher ce que `Comptabilite` calcule.
2. **Toute modification passe par le `Depot`** (`enregistrerDepense`,
   `supprimerImpaye`…). Il prévient les écrans et écrit le fichier.
3. **Les modèles sont immuables** : on crée une copie avec `copier(...)`. Pour
   remettre un champ nullable à `null`, on passe une fonction :
   `j.copier(argentCompte: () => null)`.
4. **Dates sans heure** : toujours passer par `jourSeul()` et comparer avec
   `memeJour()`. Format de sauvegarde : `dateIso()` (« 2026-09-07 »).
5. Un nouvel élément a `id: 0`. Le `Depot` lui donne un identifiant libre à
   l'enregistrement.
6. **Chaque nouvelle règle de calcul a son test** dans
   `test/comptabilite_test.dart`.

## Règles de calcul (reprises du classeur Excel)

### Recettes du jour (onglet Caisse)
- Recette **avant sorties** par service : Matin, Midi, Soir, Pâté,
  Non détaillée / autre.
- `total avant sorties` = somme des services.
- `sortie de caisse` = somme des **dépenses du jour payées avec « Caisse »**.
- `reste en caisse` = total avant sorties − sortie de caisse.
- `écart` = argent compté − reste en caisse (seulement si l'argent a été
  compté ; 0 = caisse juste).
- `impayés du jour` = impayés de cette date, **sauf ceux du service
  « Autre »**.
- `recette + impayés` = total avant sorties + impayés du jour.

### Dépenses
- « Payé avec » : **Caisse** (ventes du jour), **Trésorerie** (réserve de
  l'entreprise), **Barka**, **Fodié**, **Partagé** (argent personnel des
  deux). Les trois derniers créent une **dette** de l'entreprise.
- Catégories : Achats alimentaires, Emballages / consommables, Gaz & charbon,
  Matériel & équipement, Transport / livraison, Charges diverses,
  Personnel / Salaires, Petites dépenses / non identifiées, Produit d'entretien.
- Une dépense est **incomplète** (en orange) s'il manque la date, le montant,
  « payé avec » ou la catégorie.
- Une dépense a une **date suspecte** (aussi en orange, filtre « À corriger »)
  si elle est datée plus de 7 jours avant l'ouverture (première journée de
  caisse) ou dans le futur. Exemple réel : 3 dépenses datées du 26/07 au lieu
  du 26/09.
- Est compté comme **viande** tout article dont le nom commence par
  « Viande » ou « Foie ».

### Résumé
- Total recette = somme des totaux avant sorties.
- Impayés à recevoir = somme des **restes dus** des impayés.
- Dette envers Barka (ou Fodié) = ce qu'il a avancé − ce qui lui a été
  remboursé. Dette partagée = total « Partagé ».
- **Argent disponible** = total recette − dépenses Caisse − dépenses
  Trésorerie − tous les remboursements versés. Les avances personnelles ne
  sont pas retranchées : ce sont des dettes.
- Contrôles : écart de caisse cumulé, nombre de jours où la caisse a été
  comptée, lignes à corriger.

### Bilans
- **Par jour** : recette, dépenses, recette − dépenses, dépenses payées en
  argent personnel (tout ce qui n'est ni Caisse ni Trésorerie), achats
  viande et % de la recette.
- **Par semaine** (lundi → dimanche) : recette, dépenses, résultat, viande en %.
- **Par mois** : résultat après charges = recette − (dépenses − dépenses
  « Personnel / Salaires ») − loyer − salaires. Loyer et salaires
  (Paramètres, par défaut 120 000 F et 150 000 F) ne comptent **que pour les
  mois qui ont des recettes**. Résultat hors matériel = résultat après
  charges + dépenses « Matériel & équipement ». Le mois affiche aussi la
  recette moyenne par jour de caisse saisi, la recette par service et les
  dépenses par catégorie (de la plus grosse à la plus petite).

### Impayés
- Un impayé a une liste de **règlements** (date + montant). Reste dû =
  montant − règlements (jamais négatif). Réglé quand le reste dû vaut 0.
- Cela remplace la ligne « Autre » que le classeur utilisait pour les
  paiements partiels.

## Vérification sur les vraies données

Avec l'historique Excel converti (29 journées, 293 dépenses), l'app doit
donner : total recette **1 979 675 F**, impayés à recevoir **17 400 F**,
total dépenses **2 696 805 F**, Trésorerie **930 190 F**, dette Barka
**525 560 F**, dette Fodié **633 900 F**, partagé **139 900 F**, argent
disponible **582 230 F**, recette de septembre **1 794 225 F**.

Le classeur affiche 18 000 F de moins en dépenses (et 18 000 F de plus en
argent disponible), parce que le montant « 18000F » de la Pomme de terre est
tapé en texte. C'est l'app qui a raison.

Pour charger l'historique : **Plus → Importer le fichier Excel** (ou le
bouton « Importer mon fichier Excel » du Résumé quand l'app est vide).

Ne jamais mettre les vraies données (`*.xlsx`, `fasoresto*.json`) dans Git :
elles sont dans `.gitignore`.

## Format de sauvegarde (JSON)

```json
{
  "format": "fasoresto", "version": 1,
  "parametres": {"loyerMensuel": 120000, "salairesMensuels": 150000},
  "journees": [{"date": "2026-09-07", "matin": 48000, "midi": 9000, "soir": 31050,
                "pate": 9500, "autre": 0, "argentCompte": null,
                "fondDebut": 17000, "fondFin": 0, "remarque": ""}],
  "depenses": [{"id": 1, "date": "2026-09-07", "article": "Pain", "quantite": "",
                "montant": 4000, "payeAvec": "Caisse",
                "categorie": "Achats alimentaires", "fournisseur": "", "remarque": ""}],
  "impayes": [{"id": 2, "date": "2026-09-10", "service": "Midi", "montant": 2550,
               "client": "", "remarque": "",
               "reglements": [{"date": "2026-09-11", "montant": 2550}]}],
  "remboursements": [{"id": 3, "date": "2026-09-05", "associe": "Barka",
                      "montant": 150000, "payeAvec": "Trésorerie", "remarque": ""}]
}
```

Les listes utilisent les **libellés** affichés (« Caisse », « Pâté »…). Un
fichier sans `id` (venant de l'Excel) est accepté : des identifiants sont
attribués à l'import. Si le format change, augmenter `version` et garder la
lecture des anciennes sauvegardes.

## Travailler avec Claude Code

- Demander **une chose à la fois**, par exemple : « Ajoute un champ Client
  dans la dépense », ou « Dans l'onglet Caisse, affiche le total de la
  semaine ».
- Toujours finir par : **`flutter analyze` puis `flutter test`**, les deux
  sans erreur.
- Pour une nouvelle règle de calcul : d'abord le test dans
  `test/comptabilite_test.dart`, puis le code dans `lib/calcul/`.
- Garder les noms en français, comme dans le code existant (`enregistrer`,
  `supprimer`, `montant`, `journee`…).
- Commits courts en français, par exemple : « Ajoute le menu des plats ».
- Ne pas changer une formule du Résumé sans le noter ici, dans la section
  « Règles de calcul ».

## Questions encore ouvertes (à décider avec Barka et Fodié)

1. Un client qui **paie plus tard** son impayé : l'argent reçu doit-il
   s'ajouter à la caisse du jour où il est reçu ? Aujourd'hui, non (comme
   dans l'Excel).
2. Un **remboursement payé avec la Caisse** doit-il compter dans la sortie de
   caisse du jour ? Aujourd'hui, non.
3. **Loyer + salaires** : 120 000 F + 150 000 F, ou 285 000 F au total ?
4. Dépenses **« Partagé »** : faut-il noter la part de chacun ?

## Suite possible (par ordre d'utilité)

1. **Menu et prix des plats** : saisir « 3 riz mafé + 2 fonio » au lieu d'un
   total par service, et savoir quels plats se vendent.
2. **Plusieurs téléphones** (caissier + gérant) avec synchronisation
   (Firebase ou Supabase). Il suffira de remplacer `donnees/depot.dart`.
3. **Stock** de viande, gaz et charbon.
4. **Orange Money / Moov Money** comme moyen de paiement à part.
5. **Rapport PDF mensuel** et impression de tickets en Bluetooth.
6. **Code PIN** à l'ouverture et rôles (le caissier ne voit pas les bilans).
