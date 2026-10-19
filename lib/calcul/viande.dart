import '../modele/modeles.dart';

/// Types de viande et de poisson, dans l'ordre du classeur.
const typesViande = [
  'Viande sans os',
  'Viande avec os',
  'Viande hachée',
  'Foie',
  'Poulet',
  'Poisson',
  'Autre / mélange',
];

/// Une dépense de viande ou de poisson, avec son type et son poids.
class AchatViande {
  AchatViande(this.depense, this.type, this.kg);
  final Depense depense;
  final String type;

  /// Poids en kg ; null si la quantité ne le dit pas.
  final double? kg;
}

/// Section 1 : achats d'un type.
class AchatsParType {
  AchatsParType(this.type, this.achats, this.semaines, this.totalCout);

  final String type;
  final List<AchatViande> achats;
  final double? semaines;
  final int totalCout;

  int get nombre => achats.length;
  double get kg => achats.fold(0.0, (s, a) => s + (a.kg ?? 0));
  int get cout => achats.fold(0, (s, a) => s + (a.depense.montant ?? 0));
  double? get coutParKg => kg > 0 ? cout / kg : null;
  double? get part => totalCout == 0 ? null : cout / totalCout;
  DateTime? get premier =>
      achats.isEmpty ? null : achats.map((a) => a.depense.date!).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime? get dernier =>
      achats.isEmpty ? null : achats.map((a) => a.depense.date!).reduce((a, b) => a.isAfter(b) ? a : b);

  /// 1 achat tous les … jours.
  double? get frequenceJours => nombre > 1 ? dernier!.difference(premier!).inDays / (nombre - 1) : null;
  double? get kgParSemaine => kg == 0 || semaines == null || semaines == 0 ? null : kg / semaines!;
}

/// Section 2 : rentabilité théorique d'un type, selon les hypothèses saisies.
class RentabiliteViande {
  RentabiliteViande(this.achats, this.hypothese);
  final AchatsParType achats;
  final HypotheseViande hypothese;

  bool get chiffree => hypothese.prixMorceau != null && hypothese.morceauxParKg != null;

  /// Morceaux par kg minimum pour couvrir le coût.
  double? get seuilMorceauxParKg {
    final c = achats.coutParKg, p = hypothese.prixMorceau;
    return c == null || p == null || p == 0 ? null : c / p;
  }

  double? get coutParMorceau {
    final c = achats.coutParKg, m = hypothese.morceauxParKg;
    return c == null || m == null || m == 0 ? null : c / m;
  }

  /// Ce que la viande achetée rapporterait si tout était vendu en morceaux.
  double? get caTheorique => chiffree ? achats.kg * hypothese.morceauxParKg! * hypothese.prixMorceau! : null;
  double? get margeTheorique => caTheorique == null ? null : caTheorique! - achats.cout;
  double? get tauxMarge => caTheorique == null || caTheorique == 0 ? null : margeTheorique! / caTheorique!;
}

/// Onglet d'analyse « Viande & poisson » du classeur (achats, fréquence, coûts et rentabilité).
class AnalyseViande {
  AnalyseViande(this.d) {
    final dates = d.journees.map((j) => j.date).toList()..sort();
    debut = dates.isEmpty ? null : dates.first;
    fin = dates.isEmpty ? null : dates.last;
    semaines = debut == null ? null : (fin!.difference(debut!).inDays + 1) / 7;
    achats = [
      for (final x in d.depenses)
        if (x.date != null && estViandeOuPoisson(x.article))
          AchatViande(x, typeDe(x.article), kgDe(x.article, x.quantite)),
    ];
    final totalCout = achats.fold(0, (s, a) => s + (a.depense.montant ?? 0));
    parType = [
      for (final t in typesViande) AchatsParType(t, achats.where((a) => a.type == t).toList(), semaines, totalCout),
    ];
  }

  final Donnees d;

  /// Période des recettes (première et dernière journée de caisse).
  DateTime? debut, fin;
  double? semaines;
  late final List<AchatViande> achats;
  late final List<AchatsParType> parType;

  static bool estViandeOuPoisson(String article) {
    final a = article.toLowerCase();
    final concerne = a.contains('viande') || a.contains('foie') || a.startsWith('poulet') || a.contains('poisson');
    return concerne && !a.contains('épices') && !a.contains('poisson s');
  }

  static String typeDe(String article) {
    final a = article.toLowerCase();
    if (a.contains('foie')) return 'Foie';
    if (a.startsWith('poulet')) return 'Poulet';
    if (a.startsWith('poisson')) return 'Poisson';
    if (a.contains('sans os')) return 'Viande sans os';
    if (a.contains('avec os')) return 'Viande avec os';
    if (a.contains('hach')) return 'Viande hachée';
    return 'Autre / mélange';
  }

  /// « 5 Kg » → 5 ; « 1/2 kg » → 0,5 ; un carton = 10 kg.
  static double? kgDe(String article, String quantite) {
    final q = quantite.toLowerCase().trim();
    double? nombre(String t) => double.tryParse(t.trim().replaceAll(',', '.'));
    if ('${article.toLowerCase()} $q'.contains('carton')) return 10 * (nombre(q) ?? 1);
    if (!q.contains('kg')) return null;
    if (q.contains('1/2')) return 0.5;
    return nombre(q.replaceAll('kg', ''));
  }

  int get nombreTotal => achats.length;
  double get kgTotal => parType.fold(0.0, (s, t) => s + t.kg);
  int get coutTotal => parType.fold(0, (s, t) => s + t.cout);

  /// Coût moyen par kg, sur les seuls types dont on connaît le poids.
  double? get coutParKgTotal {
    final kg = kgTotal;
    return kg == 0 ? null : parType.where((t) => t.kg > 0).fold(0, (s, t) => s + t.cout) / kg;
  }

  double? get kgParSemaineTotal => kgTotal == 0 || semaines == null || semaines == 0 ? null : kgTotal / semaines!;

  List<RentabiliteViande> rentabilite() => [
    for (final t in parType) RentabiliteViande(t, d.hypothesesViande[t.type] ?? const HypotheseViande()),
  ];

  double get caTheoriqueTotal => rentabilite().fold(0.0, (s, r) => s + (r.caTheorique ?? 0));
  double get margeTheoriqueTotale => rentabilite().fold(0.0, (s, r) => s + (r.margeTheorique ?? 0));

  // Section 3 : comparaison avec le chiffre d'affaires réel.
  Iterable<Journee> get _periode => d.journees;
  int get caReel => _periode.fold(0, (s, j) => s + j.totalAvantSorties);
  int get caPate => _periode.fold(0, (s, j) => s + j.pate);
  double? get coutEnPartDuCa => caReel == 0 ? null : coutTotal / caReel;
  double? get caTheoriqueEnPartDuCa => caReel == 0 ? null : caTheoriqueTotal / caReel;
}
