import '../modele/modeles.dart';

/// Colonnes calculées d'une ligne de l'onglet Recettes.
class JourneeCalculee {
  JourneeCalculee(this.journee, this.sortieDeCaisse, this.impayesDuJour);

  final Journee journee;
  final int sortieDeCaisse;
  final int impayesDuJour;

  int get resteEnCaisse => journee.totalAvantSorties - sortieDeCaisse;

  /// Argent compté − reste en caisse ; null si la caisse n'a pas été comptée.
  int? get ecart => journee.argentCompte == null ? null : journee.argentCompte! - resteEnCaisse;
  int get recettePlusImpayes => journee.totalAvantSorties + impayesDuJour;
}

/// Onglet Résumé.
class Resume {
  Resume({
    required this.totalRecette,
    required this.impayesARecevoir,
    required this.totalDepenses,
    required this.depensesParSource,
    required this.detteParAssocie,
    required this.dettePartagee,
    required this.argentDisponible,
    required this.ecartCumule,
    required this.joursCaisseComptee,
    required this.depensesACorriger,
    required this.impayesACorriger,
    required this.depensesDateSuspecte,
  });

  final int totalRecette;
  final int impayesARecevoir;
  final int totalDepenses;
  final Map<SourcePaiement, int> depensesParSource;
  final Map<Associe, int> detteParAssocie;
  final int dettePartagee;
  final int argentDisponible;
  final int ecartCumule;
  final int joursCaisseComptee;
  final int depensesACorriger;
  final int impayesACorriger;

  /// Dépenses datées bien avant l'ouverture ou dans le futur (faute de frappe probable).
  final int depensesDateSuspecte;

  int get totalDettes => detteParAssocie.values.fold(0, (a, b) => a + b) + dettePartagee;
}

/// Onglet Par jour.
class BilanJour {
  BilanJour(this.date, this.recette, this.depenses, this.depensesArgentPersonnel, this.achatsViande);

  final DateTime date;
  final int recette, depenses, depensesArgentPersonnel, achatsViande;

  int get resultat => recette - depenses;
  double? get partViande => recette == 0 ? null : achatsViande / recette;
}

/// Tableau des semaines (lundi → dimanche).
class BilanSemaine {
  BilanSemaine(this.debut, this.recette, this.depenses, this.achatsViande);

  final DateTime debut;
  final int recette, depenses, achatsViande;

  DateTime get fin => DateTime(debut.year, debut.month, debut.day + 6);
  int get resultat => recette - depenses;
  double? get partViande => recette == 0 ? null : achatsViande / recette;
}

/// Tableau des mois, avec loyer et salaires.
class BilanMois {
  BilanMois({
    required this.mois,
    required this.recette,
    required this.depenses,
    required this.depensesMateriel,
    required this.versementsSalaires,
    required this.loyer,
    required this.salaires,
    required this.joursOuverts,
    required this.recetteParService,
    required this.depensesParCategorie,
  });

  /// Premier jour du mois.
  final DateTime mois;
  final int recette, depenses, depensesMateriel, versementsSalaires, loyer, salaires;

  /// Nombre de journées de caisse saisies dans le mois.
  final int joursOuverts;

  /// Recette du mois par service (Matin, Midi, Soir, Pâté, Autre).
  final Map<Service, int> recetteParService;

  /// Dépenses du mois par catégorie, de la plus grosse à la plus petite.
  final Map<Categorie, int> depensesParCategorie;

  int? get recetteMoyenneParJour => joursOuverts == 0 ? null : (recette / joursOuverts).round();

  /// Recette − (dépenses sans les versements de salaire déjà saisis) − loyer − salaires.
  int get resultatApresCharges => recette - (depenses - versementsSalaires) - loyer - salaires;
  int get resultatHorsMateriel => resultatApresCharges + depensesMateriel;
}

int _somme(Iterable<Depense> ds) => ds.fold(0, (s, d) => s + (d.montant ?? 0));

DateTime lundiDe(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

/// Reproduit fidèlement les formules du classeur « Comptabilité Faso Resto ».
/// Aucune dépendance Flutter : testable avec `flutter test`.
class Comptabilite {
  Comptabilite(this.d, {DateTime? aujourdhui})
    : _depenses = d.depenses.where((x) => x.montant != null).toList(),
      _aujourdhui = jourSeul(aujourdhui ?? DateTime.now());

  final Donnees d;
  final List<Depense> _depenses;
  final DateTime _aujourdhui;

  /// Date d'ouverture : la première journée de caisse saisie.
  DateTime? get ouverture =>
      d.journees.isEmpty ? null : d.journees.map((j) => j.date).reduce((a, b) => a.isBefore(b) ? a : b);

  /// Une dépense datée plus de 7 jours avant l'ouverture, ou dans le futur,
  /// vient sans doute d'une faute de frappe (ex. 26/07 au lieu du 26/09).
  bool dateSuspecte(Depense x) {
    final date = x.date;
    if (date == null) return false;
    final o = ouverture;
    return date.isAfter(_aujourdhui) || (o != null && date.isBefore(DateTime(o.year, o.month, o.day - 7)));
  }

  /// Dépense à corriger : incomplète ou datée de façon suspecte.
  bool aCorriger(Depense x) => x.estIncomplete || dateSuspecte(x);

  Iterable<Depense> _du(DateTime date) => _depenses.where((x) => memeJour(x.date, date));

  JourneeCalculee journee(Journee j) {
    final sortie = _somme(_du(j.date).where((x) => x.payeAvec == SourcePaiement.caisse));
    final impayes = d.impayes
        .where((i) => memeJour(i.date, j.date) && i.service != Service.autre)
        .fold(0, (s, i) => s + (i.montant ?? 0));
    return JourneeCalculee(j, sortie, impayes);
  }

  /// Journées de la plus ancienne à la plus récente.
  List<JourneeCalculee> journees() => ([...d.journees]..sort((a, b) => a.date.compareTo(b.date))).map(journee).toList();

  Resume resume() {
    final parSource = {for (final s in SourcePaiement.values) s: _somme(_depenses.where((x) => x.payeAvec == s))};
    final totalRecette = d.journees.fold(0, (s, j) => s + j.totalAvantSorties);
    final totalRembourse = d.remboursements.fold(0, (s, r) => s + r.montant);
    return Resume(
      totalRecette: totalRecette,
      impayesARecevoir: d.impayes.fold(0, (s, i) => s + i.resteDu),
      totalDepenses: _somme(_depenses),
      depensesParSource: parSource,
      detteParAssocie: {
        for (final a in Associe.values)
          a: parSource[a.source]! - d.remboursements.where((r) => r.associe == a).fold(0, (s, r) => s + r.montant),
      },
      dettePartagee: parSource[SourcePaiement.partage]!,
      argentDisponible:
          totalRecette - parSource[SourcePaiement.caisse]! - parSource[SourcePaiement.tresorerie]! - totalRembourse,
      ecartCumule: journees().fold(0, (s, j) => s + (j.ecart ?? 0)),
      joursCaisseComptee: d.journees.where((j) => j.argentCompte != null).length,
      depensesACorriger: d.depenses.where((x) => x.estIncomplete).length,
      impayesACorriger: d.impayes.where((i) => i.estIncomplet).length,
      depensesDateSuspecte: d.depenses.where(dateSuspecte).length,
    );
  }

  /// Les [n] dernières journées saisies, de la plus ancienne à la plus récente (pour le graphique).
  List<JourneeCalculee> dernieresJournees(int n) {
    final toutes = journees();
    return toutes.sublist(toutes.length > n ? toutes.length - n : 0);
  }

  BilanJour bilanJour(DateTime date) {
    final deps = _du(date).toList();
    return BilanJour(
      jourSeul(date),
      d.journees.where((j) => memeJour(j.date, date)).fold(0, (s, j) => s + j.totalAvantSorties),
      _somme(deps),
      // Comme le classeur : tout ce qui n'est pas Caisse ni Trésorerie.
      _somme(deps.where((x) => x.payeAvec?.estPersonnel ?? true)),
      _somme(deps.where((x) => x.estViande)),
    );
  }

  List<DateTime> _dates() => [
    ...d.journees.map((j) => j.date),
    ..._depenses.where((x) => x.date != null).map((x) => x.date!),
  ];

  List<DateTime> _distinctesDecroissantes(Iterable<DateTime> dates) {
    final vues = <String, DateTime>{for (final x in dates) dateIso(x): x};
    return vues.values.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Un bilan pour chaque date qui a une recette ou une dépense, du plus récent au plus ancien.
  List<BilanJour> bilansParJour() => _distinctesDecroissantes(_dates()).map(bilanJour).toList();

  List<BilanSemaine> bilansParSemaine() => _distinctesDecroissantes(_dates().map(lundiDe)).map((lundi) {
    final fin = DateTime(lundi.year, lundi.month, lundi.day + 6);
    bool dedans(DateTime? x) => x != null && !x.isBefore(lundi) && !x.isAfter(fin);
    final deps = _depenses.where((x) => dedans(x.date)).toList();
    return BilanSemaine(
      lundi,
      d.journees.where((j) => dedans(j.date)).fold(0, (s, j) => s + j.totalAvantSorties),
      _somme(deps),
      _somme(deps.where((x) => x.estViande)),
    );
  }).toList();

  List<BilanMois> bilansParMois() => _distinctesDecroissantes(_dates().map((x) => DateTime(x.year, x.month))).map((
    mois,
  ) {
    bool dedans(DateTime? x) => x != null && x.year == mois.year && x.month == mois.month;
    final deps = _depenses.where((x) => dedans(x.date)).toList();
    final jours = d.journees.where((j) => dedans(j.date)).toList();
    final recette = jours.fold(0, (s, j) => s + j.totalAvantSorties);
    // Comme dans le classeur : loyer et salaires seulement pour les mois qui ont des recettes.
    final actif = recette != 0;
    final parCategorie = {for (final c in Categorie.values) c: _somme(deps.where((x) => x.categorie == c))}
      ..removeWhere((_, v) => v == 0);
    return BilanMois(
      mois: mois,
      recette: recette,
      depenses: _somme(deps),
      depensesMateriel: _somme(deps.where((x) => x.categorie == Categorie.materiel)),
      versementsSalaires: _somme(deps.where((x) => x.categorie == Categorie.personnel)),
      loyer: actif ? d.parametres.loyerMensuel : 0,
      salaires: actif ? d.parametres.salairesMensuels : 0,
      joursOuverts: jours.length,
      recetteParService: {
        Service.matin: jours.fold(0, (s, j) => s + j.matin),
        Service.midi: jours.fold(0, (s, j) => s + j.midi),
        Service.soir: jours.fold(0, (s, j) => s + j.soir),
        Service.pate: jours.fold(0, (s, j) => s + j.pate),
        Service.autre: jours.fold(0, (s, j) => s + j.autre),
      },
      depensesParCategorie: Map.fromEntries(parCategorie.entries.toList()..sort((a, b) => b.value.compareTo(a.value))),
    );
  }).toList();
}
