import '../modele/modeles.dart';

/// Situation d'un employé pour un mois (onglet « Salaire » du classeur).
class SalaireMois {
  SalaireMois(this.employe, this.joursTravailles, this.verse);

  final Employe employe;
  final int joursTravailles;

  /// Versements du mois : dépenses « Personnel / Salaires » dont l'article contient le nom.
  final int verse;

  int? get resteAVerser => employe.salaireMensuel == null ? null : employe.salaireMensuel! - verse;
}

class BilanSalaires {
  BilanSalaires({required this.mois, required this.employes, required this.totalVerse, required this.salairesPrevus});

  /// Premier jour du mois.
  final DateTime mois;
  final List<SalaireMois> employes;

  /// Tous les versements « Personnel / Salaires » du mois.
  final int totalVerse;

  /// Salaires mensuels du bilan par mois (Paramètres).
  final int salairesPrevus;

  int get totalConvenu => employes.fold(0, (s, e) => s + (e.employe.salaireMensuel ?? 0));
  int get totalJours => employes.fold(0, (s, e) => s + e.joursTravailles);
  int get totalAttribue => employes.fold(0, (s, e) => s + e.verse);
  int get totalReste => employes.fold(0, (s, e) => s + (e.resteAVerser ?? 0));

  /// Écart entre la somme des salaires convenus et les salaires du bilan par mois.
  int get ecartAvecParametres => totalConvenu - salairesPrevus;

  /// Versements de salaire dont l'article ne nomme aucun employé.
  int get nonAttribue => totalVerse - totalAttribue;
}

BilanSalaires bilanSalaires(Donnees d, DateTime unJourDuMois) {
  final mois = DateTime(unJourDuMois.year, unJourDuMois.month);
  bool dansLeMois(DateTime? x) => x != null && x.year == mois.year && x.month == mois.month;
  final versements = d.depenses
      .where((x) => x.categorie == Categorie.personnel && dansLeMois(x.date) && x.montant != null)
      .toList();
  return BilanSalaires(
    mois: mois,
    salairesPrevus: d.parametres.salairesMensuels,
    totalVerse: versements.fold(0, (s, x) => s + x.montant!),
    employes: [
      for (final e in d.employes)
        SalaireMois(
          e,
          e.jours.where(dansLeMois).length,
          versements
              .where((x) => x.article.toLowerCase().contains(e.nom.trim().toLowerCase()))
              .fold(0, (s, x) => s + x.montant!),
        ),
    ],
  );
}
