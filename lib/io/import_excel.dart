import 'package:excel/excel.dart';

import '../calcul/viande.dart';
import '../modele/modeles.dart';

/// Lit directement le classeur « Comptabilité Faso Resto » (.xlsx).
///
/// Seules les cases de saisie sont lues : Recettes, Dépenses, Impayés,
/// Remboursements, loyer / salaires de « Semaines & mois », et s'ils existent :
/// « Prix de vente » (menu et prix des ingrédients), « Salaire » (employés et
/// pointage) et les hypothèses de rentabilité de l'analyse viande.
/// Tout le reste est recalculé par l'application.
class ImportExcel {
  /// Les données commencent à la ligne 5 dans chaque onglet (index 4).
  static const _premiereLigne = 4;

  static Donnees lire(List<int> octets) {
    final classeur = Excel.decodeBytes(octets);
    Sheet onglet(String nom) {
      final s = classeur.tables[nom];
      if (s == null) throw FormatException("L'onglet « $nom » est introuvable dans ce fichier Excel");
      return s;
    }

    var id = 1;

    final journees = <Journee>[];
    for (final l in _lignes(onglet('Recettes'), 16)) {
      final date = _date(l[0]);
      if (date == null) continue;
      journees.add(
        Journee(
          date: date,
          matin: _montant(l[1]) ?? 0,
          midi: _montant(l[2]) ?? 0,
          soir: _montant(l[3]) ?? 0,
          pate: _montant(l[4]) ?? 0,
          autre: _montant(l[5]) ?? 0,
          argentCompte: _montant(l[9]),
          fondDebut: _montant(l[11]),
          fondFin: _montant(l[12]),
          remarque: _texte(l[15]),
        ),
      );
    }

    final depenses = [
      for (final l in _lignes(onglet('Dépenses'), 8))
        Depense(
          id: id++,
          date: _date(l[0]),
          article: _texte(l[1]),
          quantite: _texte(l[2]),
          montant: _montant(l[3]),
          payeAvec: SourcePaiement.depuisLibelle(_texte(l[4])),
          categorie: Categorie.depuisLibelle(_texte(l[5])),
          fournisseur: _texte(l[6]),
          remarque: _texte(l[7]),
        ),
    ];

    final impayes = <Impaye>[];
    for (final l in _lignes(onglet('Impayés'), 5)) {
      final date = _date(l[0]);
      final montant = _montant(l[2]);
      final paye = _texte(l[3]).toLowerCase() == 'payé';
      impayes.add(
        Impaye(
          id: id++,
          date: date,
          service: Service.depuisLibelle(_texte(l[1])),
          montant: montant,
          remarque: _texte(l[4]),
          // Le classeur ne garde pas la date du règlement : on reprend celle de l'impayé.
          reglements: [if (paye && montant != null && date != null) Reglement(date: date, montant: montant)],
        ),
      );
    }

    final remboursements = <Remboursement>[];
    for (final l in _lignes(onglet('Remboursements'), 5)) {
      final date = _date(l[0]);
      final associe = Associe.depuisLibelle(_texte(l[1]));
      if (date == null || associe == null) continue;
      remboursements.add(
        Remboursement(
          id: id++,
          date: date,
          associe: associe,
          montant: _montant(l[2]) ?? 0,
          payeAvec: SourcePaiement.depuisLibelle(_texte(l[3])) ?? SourcePaiement.tresorerie,
          remarque: _texte(l[4]),
        ),
      );
    }

    // ---- Prix de vente : menu (A à I) et prix d'achat de référence (K, L).
    final produits = <Produit>[];
    final ingredients = <Ingredient>[];
    final pv = classeur.tables['Prix de vente'];
    if (pv != null) {
      for (final l in _lignes(pv, 12)) {
        final nom = _texte(l[1]);
        if (nom.isNotEmpty) {
          produits.add(
            Produit(
              id: id++,
              rubrique: _texte(l[0]),
              nom: nom,
              prix: _montant(l[2]),
              coutMatiere: _montant(l[3]),
              ingredient: _texte(l[6]),
              remarque: _texte(l[8]),
            ),
          );
        }
        final prixKg = _montant(l[11]);
        if (_texte(l[10]).isNotEmpty && prixKg != null) ingredients.add(Ingredient(nom: _texte(l[10]), prixKg: prixKg));
      }
    }

    // ---- Salaire : employés (lignes 5 à « Total ») puis pointage (en-tête ligne 16).
    final employes = <Employe>[];
    final sal = classeur.tables['Salaire'];
    if (sal != null) {
      for (var i = _premiereLigne; i < sal.maxRows; i++) {
        final nom = _texte(_valeur(sal.rows[i], 0));
        if (nom.isEmpty || nom.toLowerCase() == 'total') break;
        employes.add(
          Employe(
            id: id++,
            nom: nom,
            poste: _texte(_valeur(sal.rows[i], 1)),
            salaireMensuel: _montant(_valeur(sal.rows[i], 2)),
          ),
        );
      }
      final entete = sal.rows.indexWhere((r) => _texte(_valeur(r, 0)).toLowerCase() == 'date');
      if (entete >= 0) {
        // Colonne de pointage → employé du même nom.
        final colonnes = <int, int>{};
        for (var c = 1; c < sal.rows[entete].length; c++) {
          final n = _texte(_valeur(sal.rows[entete], c)).toLowerCase();
          final e = employes.indexWhere((x) => x.nom.toLowerCase() == n);
          if (n.isNotEmpty && e >= 0) colonnes[c] = e;
        }
        final jours = {for (var e = 0; e < employes.length; e++) e: <DateTime>[]};
        for (var i = entete + 1; i < sal.maxRows; i++) {
          final date = _date(_valeur(sal.rows[i], 0));
          if (date == null) continue;
          for (final c in colonnes.entries) {
            if ((_montant(_valeur(sal.rows[i], c.key)) ?? 0) > 0) jours[c.value]!.add(date);
          }
        }
        for (var e = 0; e < employes.length; e++) {
          employes[e] = employes[e].copier(jours: jours[e]);
        }
      }
    }

    // ---- Analyse viande, section 2 : prix par morceau et morceaux par kg (lignes 17 à 23).
    final hypotheses = <String, HypotheseViande>{};
    final analyse = classeur.tables.values.where(
      (t) => _texte(_valeur(t.rows.firstOrNull ?? [], 0)).startsWith('ANALYSE VIANDE'),
    );
    if (analyse.isNotEmpty) {
      final f = analyse.first;
      for (var k = 0; k < typesViande.length && 16 + k < f.maxRows; k++) {
        final prix = _decimal(_valeur(f.rows[16 + k], 1));
        final morceaux = _decimal(_valeur(f.rows[16 + k], 2));
        if (prix != null || morceaux != null) {
          hypotheses[typesViande[k]] = HypotheseViande(prixMorceau: prix, morceauxParKg: morceaux);
        }
      }
    }

    final sm = classeur.tables['Semaines & mois'];
    final defaut = const Parametres();
    int? caseBleue(int ligne) => sm == null || sm.maxRows <= ligne ? null : _montant(_valeur(sm.rows[ligne], 1));

    return Donnees(
      journees: journees,
      depenses: depenses,
      impayes: impayes,
      remboursements: remboursements,
      produits: produits,
      ingredients: ingredients,
      employes: employes,
      hypothesesViande: hypotheses,
      parametres: Parametres(
        loyerMensuel: caseBleue(3) ?? defaut.loyerMensuel,
        salairesMensuels: caseBleue(4) ?? defaut.salairesMensuels,
      ),
    );
  }

  /// Lignes de saisie (sans les cellules calculées), avec [colonnes] valeurs chacune.
  static Iterable<List<CellValue?>> _lignes(Sheet onglet, int colonnes) sync* {
    for (var i = _premiereLigne; i < onglet.maxRows; i++) {
      final ligne = [for (var c = 0; c < colonnes; c++) _valeur(onglet.rows[i], c)];
      final remplie = ligne.any((v) => v != null && v is! FormulaCellValue && _texte(v).isNotEmpty);
      if (remplie) yield ligne;
    }
  }

  static CellValue? _valeur(List<Data?> ligne, int colonne) => colonne < ligne.length ? ligne[colonne]?.value : null;

  /// Nombre décimal, y compris une formule simple comme « =250/3 ».
  static double? _decimal(CellValue? v) {
    switch (v) {
      case IntCellValue(:final value):
        return value.toDouble();
      case DoubleCellValue(:final value):
        return value;
      case FormulaCellValue(:final formula):
        final m = RegExp(r'^=?\s*([\d.]+)\s*/\s*([\d.]+)\s*$').firstMatch(formula);
        if (m == null) return null;
        final b = double.parse(m[2]!);
        return b == 0 ? null : double.parse(m[1]!) / b;
      default:
        return null;
    }
  }

  static String _texte(CellValue? v) => switch (v) {
    null || FormulaCellValue() => '',
    TextCellValue(:final value) => (value.text ?? value.toString()).trim(),
    IntCellValue(:final value) => '$value',
    // 1.0 → « 1 », pour les quantités.
    DoubleCellValue(:final value) => value == value.roundToDouble() ? '${value.round()}' : '$value',
    _ => v.toString().trim(),
  };

  static int? _montant(CellValue? v) => switch (v) {
    IntCellValue(:final value) => value,
    DoubleCellValue(:final value) => value.round(),
    // « 18000F » tapé en texte : Excel l'ignore, nous non.
    TextCellValue() => int.tryParse(_texte(v).replaceAll(RegExp(r'[^0-9-]'), '')),
    _ => null,
  };

  static DateTime? _date(CellValue? v) => switch (v) {
    DateCellValue() => v.asDateTimeLocal(),
    DateTimeCellValue(:final year, :final month, :final day) => DateTime(year, month, day),
    TextCellValue() => _dateTexte(_texte(v)),
    _ => null,
  };

  /// « 07/09/2026 » ou « 2026-09-07 ».
  static DateTime? _dateTexte(String t) {
    final fr = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(t);
    if (fr != null) return DateTime(int.parse(fr[3]!), int.parse(fr[2]!), int.parse(fr[1]!));
    return lireDateIso(t);
  }
}
