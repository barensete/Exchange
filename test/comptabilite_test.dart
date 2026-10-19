import 'package:fasoresto/calcul/comptabilite.dart';
import 'package:fasoresto/calcul/format.dart';
import 'package:fasoresto/io/sauvegarde.dart';
import 'package:fasoresto/modele/modeles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final j1 = DateTime(2026, 9, 7); // lundi
  final j2 = DateTime(2026, 9, 8);
  var n = 0;

  Depense dep(
    DateTime? date,
    int? montant,
    SourcePaiement? source, {
    Categorie? cat = Categorie.achatsAlimentaires,
    String article = 'Pain',
  }) => Depense(id: ++n, date: date, article: article, montant: montant, payeAvec: source, categorie: cat);

  final donnees = Donnees(
    journees: [
      Journee(date: j1, matin: 48000, midi: 9000, soir: 31050, pate: 9500, argentCompte: 90000),
      Journee(date: j2, matin: 32500, midi: 15500, soir: 41500, pate: 5800),
    ],
    depenses: [
      dep(j1, 4000, SourcePaiement.caisse),
      dep(j1, 2000, SourcePaiement.caisse, article: 'Viande sans os'),
      dep(j1, 50000, SourcePaiement.tresorerie, cat: Categorie.materiel),
      dep(j2, 30000, SourcePaiement.barka, article: 'Foie'),
      dep(j2, 10000, SourcePaiement.fodie),
      dep(j2, 6000, SourcePaiement.partage),
      dep(j2, 20000, SourcePaiement.tresorerie, cat: Categorie.personnel, article: 'Versement salaire'),
      dep(null, 1000, null, cat: null), // ligne incomplète
    ],
    impayes: [
      Impaye(id: 20, date: j1, service: Service.midi, montant: 2000),
      Impaye(
        id: 21,
        date: j1,
        service: Service.pate,
        montant: 3000,
        reglements: [Reglement(date: j2, montant: 2500)],
      ),
      Impaye(id: 22, date: j1, service: Service.autre, montant: 500),
    ],
    remboursements: [
      Remboursement(id: 30, date: j2, associe: Associe.barka, montant: 10000, payeAvec: SourcePaiement.tresorerie),
    ],
  );
  final compta = Comptabilite(donnees);

  test('colonnes calculées de la journée', () {
    final jour = compta.journees().first;
    expect(jour.journee.totalAvantSorties, 97550);
    expect(jour.sortieDeCaisse, 6000);
    expect(jour.resteEnCaisse, 91550);
    expect(jour.ecart, -1550);
    // « Autre » ne compte pas dans les impayés du jour, comme dans le classeur.
    expect(jour.impayesDuJour, 5000);
    expect(jour.recettePlusImpayes, 102550);
    expect(compta.journees()[1].ecart, isNull);
  });

  test('résumé', () {
    final r = compta.resume();
    expect(r.totalRecette, 97550 + 95300);
    expect(r.impayesARecevoir, 2000 + 500 + 500);
    expect(r.totalDepenses, 123000);
    expect(r.depensesParSource[SourcePaiement.caisse], 6000);
    expect(r.depensesParSource[SourcePaiement.tresorerie], 70000);
    expect(r.detteParAssocie[Associe.barka], 20000);
    expect(r.detteParAssocie[Associe.fodie], 10000);
    expect(r.dettePartagee, 6000);
    expect(r.totalDettes, 36000);
    expect(r.argentDisponible, 192850 - 6000 - 70000 - 10000);
    expect(r.ecartCumule, -1550);
    expect(r.joursCaisseComptee, 1);
    expect(r.depensesACorriger, 1);
  });

  test('bilans jour, semaine, mois', () {
    final jour = compta.bilanJour(j2);
    expect(jour.depenses, 66000);
    expect(jour.depensesArgentPersonnel, 46000);
    expect(jour.achatsViande, 30000);

    final semaine = compta.bilansParSemaine().single;
    expect(semaine.debut, j1);
    expect(semaine.achatsViande, 32000);

    final mois = compta.bilansParMois().single;
    expect(mois.mois, DateTime(2026, 9));
    expect(mois.depensesMateriel, 50000);
    // 192 850 − (122 000 − 20 000) − 120 000 − 150 000
    expect(mois.resultatApresCharges, -179150);
    expect(mois.resultatHorsMateriel, -129150);
  });

  test('sauvegarde aller-retour', () {
    final relu = Sauvegarde.importer(Sauvegarde.exporter(donnees));
    expect(Sauvegarde.exporter(relu), Sauvegarde.exporter(donnees));
    expect(Comptabilite(relu).resume().argentDisponible, compta.resume().argentDisponible);
  });

  test('import sans identifiants (fichier venant de l\'Excel)', () {
    final d = Sauvegarde.importer(
      '{"format":"fasoresto","depenses":[{"date":"2026-09-01","montant":"18000F"},{"date":"2026-09-01","montant":500}]}',
    );
    expect(d.depenses.map((x) => x.id).toSet().length, 2);
    expect(d.depenses.first.montant, 18000);
    expect(d.prochainId, 3);
  });

  test('libellés du classeur', () {
    expect(Categorie.depuisLibelle('Petites dépenses / non identifiée'), Categorie.petitesDepenses);
    expect(Categorie.depuisLibelle("Produit d'entretiens"), Categorie.entretien);
    expect(SourcePaiement.depuisLibelle('fodié'), SourcePaiement.fodie);
  });

  test('montants et CSV', () {
    expect(lireMontant('18000F'), 18000);
    expect(lireMontant('12 500'), 12500);
    expect(lireMontant(''), isNull);
    expect(enFcfa(12500), '12 500 F');
    expect(enFcfa(-1550), '−1 550 F');
    expect(enFcfa(500), '500 F');
    final csv = ExportCsv.depenses(
      Donnees(
        depenses: [
          Depense(
            id: 1,
            date: DateTime(2026, 9, 1),
            article: 'Sel; fin',
            montant: 500,
            payeAvec: SourcePaiement.caisse,
            categorie: Categorie.achatsAlimentaires,
          ),
        ],
      ),
    );
    final lignes = csv.substring(1).trimRight().split('\r\n');
    expect(lignes[1], '2026-09-01;"Sel; fin";;500;Caisse;Achats alimentaires;;');
  });

  test('dates suspectes (faute de frappe sur le mois, ou date future)', () {
    final avecErreurs = donnees.copier(
      depenses: [
        ...donnees.depenses,
        dep(DateTime(2026, 7, 26), 18000, SourcePaiement.tresorerie), // 26/07 au lieu du 26/09
        dep(DateTime(2026, 9, 2), 500, SourcePaiement.caisse), // 5 jours avant l'ouverture : normal
        dep(DateTime(2026, 12, 1), 700, SourcePaiement.caisse), // dans le futur
      ],
    );
    final c = Comptabilite(avecErreurs, aujourdhui: DateTime(2026, 10, 1));
    expect(c.ouverture, j1);
    expect(c.resume().depensesDateSuspecte, 2);
    expect(c.aCorriger(avecErreurs.depenses.last), isTrue);
    expect(c.aCorriger(avecErreurs.depenses[avecErreurs.depenses.length - 2]), isFalse);
  });

  test('détail du mois : services, catégories, moyenne par jour', () {
    final mois = compta.bilansParMois().single;
    expect(mois.joursOuverts, 2);
    expect(mois.recetteMoyenneParJour, 96425);
    expect(mois.recetteParService[Service.matin], 48000 + 32500);
    expect(mois.recetteParService[Service.pate], 9500 + 5800);
    // Triées de la plus grosse à la plus petite, sans les catégories vides.
    expect(mois.depensesParCategorie.keys.take(2), [Categorie.achatsAlimentaires, Categorie.materiel]);
    expect(mois.depensesParCategorie[Categorie.achatsAlimentaires], 4000 + 2000 + 30000 + 10000 + 6000);
    expect(mois.depensesParCategorie.containsKey(Categorie.transport), isFalse);
  });

  test('dernières journées pour le graphique', () {
    expect(compta.dernieresJournees(1).single.journee.date, j2);
    expect(compta.dernieresJournees(10).length, 2);
  });
}
