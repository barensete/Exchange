/// Modèles de données du restaurant.
///
/// Les montants sont des entiers en francs CFA (jamais de virgule).
/// Les dates sont des jours sans heure (voir [jourSeul]).
library;

/// Garde seulement l'année, le mois et le jour.
DateTime jourSeul(DateTime d) => DateTime(d.year, d.month, d.day);

/// 2026-09-07 → « 2026-09-07 » (format de la sauvegarde).
String dateIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? lireDateIso(Object? v) {
  if (v is! String || v.length < 10) return null;
  final d = DateTime.tryParse(v.substring(0, 10));
  return d == null ? null : jourSeul(d);
}

bool memeJour(DateTime? a, DateTime? b) =>
    a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

/// D'où vient l'argent d'une dépense (colonne « Payé avec » du classeur).
enum SourcePaiement {
  caisse('Caisse', false),
  tresorerie('Trésorerie', false),
  barka('Barka', true),
  fodie('Fodié', true),
  partage('Partagé', true);

  const SourcePaiement(this.libelle, this.estPersonnel);
  final String libelle;
  final bool estPersonnel;

  static SourcePaiement? depuisLibelle(Object? texte) {
    final t = texte?.toString().trim().toLowerCase();
    for (final s in values) {
      if (s.libelle.toLowerCase() == t) return s;
    }
    return null;
  }
}

enum Categorie {
  achatsAlimentaires('Achats alimentaires'),
  emballages('Emballages / consommables'),
  gazCharbon('Gaz & charbon'),
  materiel('Matériel & équipement'),
  transport('Transport / livraison'),
  chargesDiverses('Charges diverses'),
  personnel('Personnel / Salaires'),
  petitesDepenses('Petites dépenses / non identifiées'),
  entretien("Produits d'entretien"),
  loyer('Loyer');

  const Categorie(this.libelle);
  final String libelle;

  static Categorie? depuisLibelle(Object? texte) {
    final t = texte?.toString().trim().toLowerCase();
    if (t == null || t.isEmpty) return null;
    for (final c in values) {
      if (c.libelle.toLowerCase() == t) return c;
    }
    // Tolère singulier / pluriel (« non identifiée », « Produit d'entretiens »…).
    String sansPluriel(String x) =>
        x.split(' ').map((m) => m.endsWith('s') ? m.substring(0, m.length - 1) : m).join(' ');
    for (final c in values) {
      if (sansPluriel(c.libelle.toLowerCase()) == sansPluriel(t)) return c;
    }
    return null;
  }
}

enum Service {
  matin('Matin'),
  midi('Midi'),
  soir('Soir'),
  pate('Pâté'),
  autre('Autre');

  const Service(this.libelle);
  final String libelle;

  static Service? depuisLibelle(Object? texte) {
    final t = texte?.toString().trim().toLowerCase();
    for (final s in values) {
      if (s.libelle.toLowerCase() == t) return s;
    }
    return null;
  }
}

/// Associés qui avancent de l'argent personnel et se font rembourser.
enum Associe {
  barka('Barka', SourcePaiement.barka),
  fodie('Fodié', SourcePaiement.fodie);

  const Associe(this.libelle, this.source);
  final String libelle;
  final SourcePaiement source;

  static Associe? depuisLibelle(Object? texte) {
    final t = texte?.toString().trim().toLowerCase();
    for (final a in values) {
      if (a.libelle.toLowerCase() == t) return a;
    }
    return null;
  }
}

/// Une ligne de l'onglet Recettes : la caisse d'une journée.
class Journee {
  Journee({
    required DateTime date,
    this.matin = 0,
    this.midi = 0,
    this.soir = 0,
    this.pate = 0,
    this.autre = 0,
    this.argentCompte,
    this.fondDebut,
    this.fondFin,
    this.remarque = '',
  }) : date = jourSeul(date);

  final DateTime date;
  final int matin, midi, soir, pate, autre;

  /// Argent réellement compté le soir ; null si la caisse n'a pas été comptée.
  final int? argentCompte;
  final int? fondDebut, fondFin;
  final String remarque;

  int get totalAvantSorties => matin + midi + soir + pate + autre;

  Journee copier({
    DateTime? date,
    int? matin,
    int? midi,
    int? soir,
    int? pate,
    int? autre,
    int? Function()? argentCompte,
    int? Function()? fondDebut,
    int? Function()? fondFin,
    String? remarque,
  }) => Journee(
    date: date ?? this.date,
    matin: matin ?? this.matin,
    midi: midi ?? this.midi,
    soir: soir ?? this.soir,
    pate: pate ?? this.pate,
    autre: autre ?? this.autre,
    argentCompte: argentCompte != null ? argentCompte() : this.argentCompte,
    fondDebut: fondDebut != null ? fondDebut() : this.fondDebut,
    fondFin: fondFin != null ? fondFin() : this.fondFin,
    remarque: remarque ?? this.remarque,
  );
}

class Depense {
  Depense({
    required this.id,
    required DateTime? date,
    required this.article,
    this.quantite = '',
    required this.montant,
    required this.payeAvec,
    required this.categorie,
    this.fournisseur = '',
    this.remarque = '',
  }) : date = date == null ? null : jourSeul(date);

  final int id;
  final DateTime? date;
  final String article;
  final String quantite;
  final int? montant;
  final SourcePaiement? payeAvec;
  final Categorie? categorie;
  final String fournisseur;
  final String remarque;

  /// Ligne orange du classeur : date, montant, « Payé avec » ou catégorie manquants.
  bool get estIncomplete => date == null || montant == null || payeAvec == null || categorie == null;

  bool get estViande {
    final a = article.trim().toLowerCase();
    return a.startsWith('viande') || a.startsWith('foie');
  }

  Depense copier({
    int? id,
    DateTime? date,
    String? article,
    String? quantite,
    int? Function()? montant,
    SourcePaiement? payeAvec,
    Categorie? categorie,
    String? fournisseur,
    String? remarque,
  }) => Depense(
    id: id ?? this.id,
    date: date ?? this.date,
    article: article ?? this.article,
    quantite: quantite ?? this.quantite,
    montant: montant != null ? montant() : this.montant,
    payeAvec: payeAvec ?? this.payeAvec,
    categorie: categorie ?? this.categorie,
    fournisseur: fournisseur ?? this.fournisseur,
    remarque: remarque ?? this.remarque,
  );
}

/// Paiement (total ou partiel) d'un impayé.
class Reglement {
  Reglement({required DateTime date, required this.montant}) : date = jourSeul(date);
  final DateTime date;
  final int montant;
}

/// Vente à crédit. Le reste dû se calcule à partir des règlements.
class Impaye {
  Impaye({
    required this.id,
    required DateTime? date,
    required this.service,
    required this.montant,
    this.client = '',
    this.remarque = '',
    this.reglements = const [],
  }) : date = date == null ? null : jourSeul(date);

  final int id;
  final DateTime? date;
  final Service? service;
  final int? montant;
  final String client;
  final String remarque;
  final List<Reglement> reglements;

  int get montantRegle => reglements.fold(0, (s, r) => s + r.montant);
  int get resteDu {
    final reste = (montant ?? 0) - montantRegle;
    return reste < 0 ? 0 : reste;
  }

  bool get estSolde => montant != null && resteDu == 0;
  bool get estIncomplet => date == null || montant == null || service == null;

  Impaye copier({
    DateTime? date,
    Service? service,
    int? Function()? montant,
    String? client,
    String? remarque,
    List<Reglement>? reglements,
  }) => Impaye(
    id: id,
    date: date ?? this.date,
    service: service ?? this.service,
    montant: montant != null ? montant() : this.montant,
    client: client ?? this.client,
    remarque: remarque ?? this.remarque,
    reglements: reglements ?? this.reglements,
  );
}

/// Argent rendu par l'entreprise à un associé.
class Remboursement {
  Remboursement({
    required this.id,
    required DateTime date,
    required this.associe,
    required this.montant,
    required this.payeAvec,
    this.remarque = '',
  }) : date = jourSeul(date);

  final int id;
  final DateTime date;
  final Associe associe;
  final int montant;
  final SourcePaiement payeAvec;
  final String remarque;

  Remboursement copier({DateTime? date, Associe? associe, int? montant, SourcePaiement? payeAvec, String? remarque}) =>
      Remboursement(
        id: id,
        date: date ?? this.date,
        associe: associe ?? this.associe,
        montant: montant ?? this.montant,
        payeAvec: payeAvec ?? this.payeAvec,
        remarque: remarque ?? this.remarque,
      );
}

class Parametres {
  const Parametres({this.loyerMensuel = 120000, this.salairesMensuels = 150000});
  final int loyerMensuel;
  final int salairesMensuels;
}

/// Un plat ou une boisson du menu (onglet « Prix de vente » du classeur).
class Produit {
  Produit({
    required this.id,
    required this.rubrique,
    required this.nom,
    this.prix,
    this.coutMatiere,
    this.ingredient = '',
    this.remarque = '',
  });

  final int id;

  /// Petit déjeuner, Déjeuner, Dîner, Autres…
  final String rubrique;
  final String nom;

  /// Prix de vente ; null si pas encore fixé.
  final int? prix;

  /// Ce que coûte la matière d'une portion ; null si pas encore estimé.
  final int? coutMatiere;

  /// Ingrédient principal (nom d'un [Ingredient]), vide si aucun.
  final String ingredient;
  final String remarque;

  Produit copier({
    int? id,
    String? rubrique,
    String? nom,
    int? Function()? prix,
    int? Function()? coutMatiere,
    String? ingredient,
    String? remarque,
  }) => Produit(
    id: id ?? this.id,
    rubrique: rubrique ?? this.rubrique,
    nom: nom ?? this.nom,
    prix: prix != null ? prix() : this.prix,
    coutMatiere: coutMatiere != null ? coutMatiere() : this.coutMatiere,
    ingredient: ingredient ?? this.ingredient,
    remarque: remarque ?? this.remarque,
  );
}

/// Prix d'achat de référence d'un ingrédient (F par kg).
class Ingredient {
  const Ingredient({required this.nom, required this.prixKg});
  final String nom;
  final int prixKg;
}

/// Employé : salaire convenu et jours travaillés (pointage).
class Employe {
  Employe({required this.id, required this.nom, this.poste = '', this.salaireMensuel, this.jours = const []});

  final int id;
  final String nom;
  final String poste;

  /// Salaire mensuel convenu ; null si pas fixé (renfort, extra…).
  final int? salaireMensuel;

  /// Jours où la personne a travaillé.
  final List<DateTime> jours;

  bool aTravaille(DateTime date) => jours.any((j) => memeJour(j, date));

  Employe copier({int? id, String? nom, String? poste, int? Function()? salaireMensuel, List<DateTime>? jours}) =>
      Employe(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        poste: poste ?? this.poste,
        salaireMensuel: salaireMensuel != null ? salaireMensuel() : this.salaireMensuel,
        jours: jours ?? this.jours,
      );
}

/// Hypothèses de rentabilité pour un type de viande ou de poisson
/// (section 2 de l'analyse viande du classeur).
class HypotheseViande {
  const HypotheseViande({this.prixMorceau, this.morceauxParKg});

  /// Prix de vente d'un morceau (ex. 100 F ; 83,33 F pour le foie à 250 F les 3).
  final double? prixMorceau;
  final double? morceauxParKg;
}

/// Toutes les données du restaurant.
class Donnees {
  const Donnees({
    this.journees = const [],
    this.depenses = const [],
    this.impayes = const [],
    this.remboursements = const [],
    this.parametres = const Parametres(),
    this.produits = const [],
    this.ingredients = const [],
    this.employes = const [],
    this.hypothesesViande = const {},
  });

  final List<Journee> journees;
  final List<Depense> depenses;
  final List<Impaye> impayes;
  final List<Remboursement> remboursements;
  final Parametres parametres;
  final List<Produit> produits;
  final List<Ingredient> ingredients;
  final List<Employe> employes;

  /// Par type de viande (« Viande sans os », « Foie »…).
  final Map<String, HypotheseViande> hypothesesViande;

  Donnees copier({
    List<Journee>? journees,
    List<Depense>? depenses,
    List<Impaye>? impayes,
    List<Remboursement>? remboursements,
    Parametres? parametres,
    List<Produit>? produits,
    List<Ingredient>? ingredients,
    List<Employe>? employes,
    Map<String, HypotheseViande>? hypothesesViande,
  }) => Donnees(
    journees: journees ?? this.journees,
    depenses: depenses ?? this.depenses,
    impayes: impayes ?? this.impayes,
    remboursements: remboursements ?? this.remboursements,
    parametres: parametres ?? this.parametres,
    produits: produits ?? this.produits,
    ingredients: ingredients ?? this.ingredients,
    employes: employes ?? this.employes,
    hypothesesViande: hypothesesViande ?? this.hypothesesViande,
  );

  /// Prochain identifiant libre pour une nouvelle ligne.
  int get prochainId {
    var max = 0;
    for (final x in [
      ...depenses.map((e) => e.id),
      ...impayes.map((e) => e.id),
      ...remboursements.map((e) => e.id),
      ...produits.map((e) => e.id),
      ...employes.map((e) => e.id),
    ]) {
      if (x > max) max = x;
    }
    return max + 1;
  }
}
