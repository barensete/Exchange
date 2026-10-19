import '../modele/modeles.dart';

/// Part du coût matière visée : 30 % du prix de vente (onglet « Prix de vente »).
const partCoutVisee = 0.30;

/// Colonnes calculées d'un produit du menu.
class ProduitCalcule {
  ProduitCalcule(this.produit, this.prixKgIngredient);

  final Produit produit;

  /// Prix au kg de l'ingrédient principal ; null si inconnu.
  final int? prixKgIngredient;

  /// Coût matière en part du prix de vente (0,25 = 25 %).
  double? get coutEnPart {
    final p = produit.prix, c = produit.coutMatiere;
    return p == null || c == null || p == 0 ? null : c / p;
  }

  /// Coût matière maximum pour rester à 30 % du prix.
  int? get coutMax => produit.prix == null ? null : (produit.prix! * partCoutVisee).round();

  /// Grammes d'ingrédient principal qu'on peut mettre en restant à 30 %.
  int? get poidsMaxGrammes {
    final max = coutMax, kg = prixKgIngredient;
    return max == null || kg == null || kg == 0 ? null : (max / kg * 1000).round();
  }

  bool get tropCher => (coutEnPart ?? 0) > partCoutVisee;
}

/// Le menu, rubrique par rubrique, dans l'ordre de saisie.
class Menu {
  Menu(this.d);
  final Donnees d;

  int? prixKg(String ingredient) {
    for (final i in d.ingredients) {
      if (i.nom.toLowerCase() == ingredient.trim().toLowerCase()) return i.prixKg;
    }
    return null;
  }

  ProduitCalcule calculer(Produit p) => ProduitCalcule(p, p.ingredient.isEmpty ? null : prixKg(p.ingredient));

  Map<String, List<ProduitCalcule>> parRubrique() {
    final r = <String, List<ProduitCalcule>>{};
    for (final p in d.produits) {
      r.putIfAbsent(p.rubrique, () => []).add(calculer(p));
    }
    return r;
  }
}
