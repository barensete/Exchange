import 'package:fasoresto/calcul/comptabilite.dart';
import 'package:fasoresto/calcul/menu.dart';
import 'package:fasoresto/calcul/salaires.dart';
import 'package:fasoresto/calcul/viande.dart';
import 'package:fasoresto/io/sauvegarde.dart';
import 'package:fasoresto/modele/modeles.dart';
import 'package:flutter_test/flutter_test.dart';

Depense _dep(
  int id,
  DateTime date,
  String article,
  int montant, {
  String quantite = '',
  Categorie categorie = Categorie.achatsAlimentaires,
}) => Depense(
  id: id,
  date: date,
  article: article,
  quantite: quantite,
  montant: montant,
  payeAvec: SourcePaiement.tresorerie,
  categorie: categorie,
);

void main() {
  test('le loyer déjà versé ne compte pas deux fois dans le bilan du mois', () {
    final d = Donnees(
      journees: [Journee(date: DateTime(2026, 10, 1), matin: 500000)],
      depenses: [
        _dep(1, DateTime(2026, 10, 2), 'Pain', 10000),
        _dep(2, DateTime(2026, 10, 3), 'Versement loyer', 120000, categorie: Categorie.loyer),
        _dep(3, DateTime(2026, 10, 4), 'Versement salaire Zineb', 50000, categorie: Categorie.personnel),
      ],
      parametres: const Parametres(loyerMensuel: 120000, salairesMensuels: 180000),
    );
    final m = Comptabilite(d).bilansParMois().single;
    expect(m.versementsLoyer, 120000);
    // 500 000 − (180 000 − 50 000 − 120 000) − 120 000 − 180 000
    expect(m.resultatApresCharges, 190000);
  });

  test('menu : coût en %, coût max à 30 %, poids max', () {
    final d = Donnees(
      ingredients: const [Ingredient(nom: 'Viande sans os', prixKg: 4809)],
      produits: [
        Produit(
          id: 1,
          rubrique: 'Petit déjeuner',
          nom: 'Sandwich',
          prix: 700,
          coutMatiere: 245,
          ingredient: 'viande sans os',
        ),
        Produit(id: 2, rubrique: 'Autres', nom: 'Pâté'),
      ],
    );
    final menu = Menu(d);
    final s = menu.calculer(d.produits.first);
    expect(s.coutEnPart, 0.35);
    expect(s.tropCher, isTrue);
    expect(s.coutMax, 210);
    expect(s.poidsMaxGrammes, 44);
    final pate = menu.calculer(d.produits.last);
    expect(pate.coutMax, isNull);
    expect(menu.parRubrique().keys, ['Petit déjeuner', 'Autres']);
  });

  test('salaires du mois : jours, versé par nom, reste, non attribué', () {
    final d = Donnees(
      employes: [
        Employe(
          id: 1,
          nom: 'Zineb',
          salaireMensuel: 50000,
          jours: [DateTime(2026, 10, 1), DateTime(2026, 10, 2), DateTime(2026, 9, 30)],
        ),
        Employe(id: 2, nom: 'Hawa', jours: [DateTime(2026, 10, 1)]),
      ],
      depenses: [
        _dep(3, DateTime(2026, 10, 2), 'Versement salaire ZINEB', 60000, categorie: Categorie.personnel),
        _dep(4, DateTime(2026, 10, 16), 'Versement salaire mama', 15000, categorie: Categorie.personnel),
        _dep(5, DateTime(2026, 9, 14), 'Versement salaire Zineb', 15500, categorie: Categorie.personnel),
      ],
      parametres: const Parametres(salairesMensuels: 180000),
    );
    final b = bilanSalaires(d, DateTime(2026, 10, 19));
    expect(b.employes.first.joursTravailles, 2);
    expect(b.employes.first.verse, 60000);
    expect(b.employes.first.resteAVerser, -10000);
    expect(b.employes.last.resteAVerser, isNull);
    expect(b.nonAttribue, 15000);
    expect(b.ecartAvecParametres, 50000 - 180000);
  });

  test('viande : type, poids et totaux comme le classeur', () {
    expect(AnalyseViande.typeDe('Foie de bœuf'), 'Foie');
    expect(AnalyseViande.typeDe('Poulet'), 'Poulet');
    expect(AnalyseViande.typeDe('Viande sans os'), 'Viande sans os');
    expect(AnalyseViande.typeDe('Viande'), 'Autre / mélange');
    expect(AnalyseViande.estViandeOuPoisson('Épices pour viande'), isFalse);
    expect(AnalyseViande.estViandeOuPoisson('Poisson sec'), isFalse);
    expect(AnalyseViande.estViandeOuPoisson('Bouillon poulet'), isFalse);
    expect(AnalyseViande.kgDe('Poulet', '1 carton'), 10);
    expect(AnalyseViande.kgDe('Poisson (Carton 10kg)', '2'), 20);
    expect(AnalyseViande.kgDe('Viande sans os', '5 Kg'), 5);
    expect(AnalyseViande.kgDe('Foie', '1/2 kg'), 0.5);
    expect(AnalyseViande.kgDe('Foie', '2,5 kg'), 2.5);
    expect(AnalyseViande.kgDe('Foie', ''), isNull);

    final d = Donnees(
      journees: [
        Journee(date: DateTime(2026, 9, 1), matin: 100000, pate: 10000),
        Journee(date: DateTime(2026, 9, 14), matin: 90000),
      ],
      depenses: [
        _dep(1, DateTime(2026, 9, 1), 'Viande sans os', 24000, quantite: '5 Kg'),
        _dep(2, DateTime(2026, 9, 5), 'Viande sans os', 26000, quantite: '5 kg'),
        _dep(3, DateTime(2026, 9, 3), 'Poulet', 26000, quantite: '1 carton'),
        _dep(4, DateTime(2026, 9, 3), 'Pain', 4000),
      ],
      hypothesesViande: const {'Viande sans os': HypotheseViande(prixMorceau: 100, morceauxParKg: 70)},
    );
    final a = AnalyseViande(d);
    expect(a.nombreTotal, 3);
    expect(a.semaines, 2);
    final sansOs = a.parType.first;
    expect(sansOs.kg, 10);
    expect(sansOs.coutParKg, 5000);
    expect(sansOs.frequenceJours, 4);
    expect(sansOs.kgParSemaine, 5);
    expect(a.coutTotal, 76000);
    final r = a.rentabilite().first;
    expect(r.caTheorique, 70000);
    expect(r.margeTheorique, 20000);
    expect(r.seuilMorceauxParKg, 50);
    expect(a.caPate, 10000);
    expect(a.coutEnPartDuCa, 76000 / 200000);
  });

  test('sauvegarde v2 aller-retour, et lecture des sauvegardes v1', () {
    final d = Donnees(
      produits: [Produit(id: 1, rubrique: 'Dîner', nom: 'Brochette', prix: 500, ingredient: 'Foie')],
      ingredients: const [Ingredient(nom: 'Foie', prixKg: 2900)],
      employes: [
        Employe(id: 2, nom: 'Zineb', poste: 'Gérante cuisine', salaireMensuel: 50000, jours: [DateTime(2026, 10, 1)]),
      ],
      hypothesesViande: const {'Foie': HypotheseViande(prixMorceau: 250 / 3, morceauxParKg: 70)},
    );
    final texte = Sauvegarde.exporter(d);
    final relu = Sauvegarde.importer(texte);
    expect(Sauvegarde.exporter(relu), texte);
    expect(relu.employes.single.aTravaille(DateTime(2026, 10, 1, 15)), isTrue);
    expect(relu.hypothesesViande['Foie']!.prixMorceau, closeTo(83.33, 0.01));
    expect(relu.prochainId, 3);

    final v1 = Sauvegarde.importer(
      '{"format":"fasoresto","version":1,"depenses":[{"date":"2026-09-01","montant":500,'
      '"categorie":"Produit d\'entretien"}]}',
    );
    expect(v1.produits, isEmpty);
    expect(v1.depenses.single.categorie, Categorie.entretien);
  });
}
