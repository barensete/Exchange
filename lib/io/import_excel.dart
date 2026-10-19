import 'package:excel/excel.dart';

import '../modele/modeles.dart';

/// Lit directement le classeur « Comptabilité Faso Resto » (.xlsx).
///
/// Seuls les onglets de saisie sont lus : Recettes, Dépenses, Impayés,
/// Remboursements, et les deux cases bleues loyer / salaires de
/// « Semaines & mois ». Tout le reste est recalculé par l'application.
/// Fait la même chose que `outils/excel_vers_json.py`.
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

    final sm = classeur.tables['Semaines & mois'];
    final defaut = const Parametres();
    int? caseBleue(int ligne) => sm == null || sm.maxRows <= ligne ? null : _montant(_valeur(sm.rows[ligne], 1));

    return Donnees(
      journees: journees,
      depenses: depenses,
      impayes: impayes,
      remboursements: remboursements,
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
