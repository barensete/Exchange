import 'dart:convert';

import '../calcul/comptabilite.dart';
import '../modele/modeles.dart';

/// Format de sauvegarde (JSON). C'est aussi le format produit par
/// `outils/excel_vers_json.py` pour reprendre l'historique du classeur Excel,
/// et le fichier où l'application garde ses données sur le téléphone.
class Sauvegarde {
  /// 2 : menu, ingrédients, employés (pointage) et hypothèses viande.
  static const version = 2;

  static String exporter(Donnees d) => const JsonEncoder.withIndent(' ').convert({
    'format': 'fasoresto',
    'version': version,
    'parametres': {'loyerMensuel': d.parametres.loyerMensuel, 'salairesMensuels': d.parametres.salairesMensuels},
    'journees': [
      for (final j in d.journees)
        {
          'date': dateIso(j.date),
          'matin': j.matin,
          'midi': j.midi,
          'soir': j.soir,
          'pate': j.pate,
          'autre': j.autre,
          'argentCompte': j.argentCompte,
          'fondDebut': j.fondDebut,
          'fondFin': j.fondFin,
          'remarque': j.remarque,
        },
    ],
    'depenses': [
      for (final x in d.depenses)
        {
          'id': x.id,
          'date': x.date == null ? null : dateIso(x.date!),
          'article': x.article,
          'quantite': x.quantite,
          'montant': x.montant,
          'payeAvec': x.payeAvec?.libelle,
          'categorie': x.categorie?.libelle,
          'fournisseur': x.fournisseur,
          'remarque': x.remarque,
        },
    ],
    'impayes': [
      for (final i in d.impayes)
        {
          'id': i.id,
          'date': i.date == null ? null : dateIso(i.date!),
          'service': i.service?.libelle,
          'montant': i.montant,
          'client': i.client,
          'remarque': i.remarque,
          'reglements': [
            for (final r in i.reglements) {'date': dateIso(r.date), 'montant': r.montant},
          ],
        },
    ],
    'remboursements': [
      for (final r in d.remboursements)
        {
          'id': r.id,
          'date': dateIso(r.date),
          'associe': r.associe.libelle,
          'montant': r.montant,
          'payeAvec': r.payeAvec.libelle,
          'remarque': r.remarque,
        },
    ],
    'produits': [
      for (final p in d.produits)
        {
          'id': p.id,
          'rubrique': p.rubrique,
          'nom': p.nom,
          'prix': p.prix,
          'coutMatiere': p.coutMatiere,
          'ingredient': p.ingredient,
          'remarque': p.remarque,
        },
    ],
    'ingredients': [
      for (final i in d.ingredients) {'nom': i.nom, 'prixKg': i.prixKg},
    ],
    'employes': [
      for (final e in d.employes)
        {
          'id': e.id,
          'nom': e.nom,
          'poste': e.poste,
          'salaireMensuel': e.salaireMensuel,
          'jours': [for (final j in e.jours) dateIso(j)],
        },
    ],
    'hypothesesViande': {
      for (final h in d.hypothesesViande.entries)
        h.key: {'prixMorceau': h.value.prixMorceau, 'morceauxParKg': h.value.morceauxParKg},
    },
  });

  static Donnees importer(String texte) {
    final racine = jsonDecode(texte);
    if (racine is! Map || racine['format'] != 'fasoresto') {
      throw const FormatException("Ce fichier n'est pas une sauvegarde FasoResto");
    }
    final p = racine['parametres'] is Map ? racine['parametres'] as Map : const {};
    const defaut = Parametres();

    // Les fichiers venant de l'Excel n'ont pas d'identifiants : on en attribue.
    var prochainId = 1;
    int id(Map m) {
      final v = _entier(m['id']);
      if (v != null && v >= prochainId) prochainId = v + 1;
      return v ?? 0;
    }

    final depenses = [
      for (final m in _liste(racine['depenses']))
        Depense(
          id: id(m),
          date: lireDateIso(m['date']),
          article: _texte(m['article']),
          quantite: _texte(m['quantite']),
          montant: _entier(m['montant']),
          payeAvec: SourcePaiement.depuisLibelle(m['payeAvec']),
          categorie: Categorie.depuisLibelle(m['categorie']),
          fournisseur: _texte(m['fournisseur']),
          remarque: _texte(m['remarque']),
        ),
    ];
    final impayes = [
      for (final m in _liste(racine['impayes']))
        Impaye(
          id: id(m),
          date: lireDateIso(m['date']),
          service: Service.depuisLibelle(m['service']),
          montant: _entier(m['montant']),
          client: _texte(m['client']),
          remarque: _texte(m['remarque']),
          reglements: [
            for (final r in _liste(m['reglements']))
              if (lireDateIso(r['date']) != null)
                Reglement(date: lireDateIso(r['date'])!, montant: _entier(r['montant']) ?? 0),
          ],
        ),
    ];
    final remboursements = [
      for (final m in _liste(racine['remboursements']))
        if (lireDateIso(m['date']) != null)
          Remboursement(
            id: id(m),
            date: lireDateIso(m['date'])!,
            associe:
                Associe.depuisLibelle(m['associe']) ?? (throw FormatException('Associé inconnu : ${m['associe']}')),
            montant: _entier(m['montant']) ?? 0,
            payeAvec: SourcePaiement.depuisLibelle(m['payeAvec']) ?? SourcePaiement.tresorerie,
            remarque: _texte(m['remarque']),
          ),
    ];
    final produits = [
      for (final m in _liste(racine['produits']))
        Produit(
          id: id(m),
          rubrique: _texte(m['rubrique']),
          nom: _texte(m['nom']),
          prix: _entier(m['prix']),
          coutMatiere: _entier(m['coutMatiere']),
          ingredient: _texte(m['ingredient']),
          remarque: _texte(m['remarque']),
        ),
    ];
    final employes = [
      for (final m in _liste(racine['employes']))
        Employe(
          id: id(m),
          nom: _texte(m['nom']),
          poste: _texte(m['poste']),
          salaireMensuel: _entier(m['salaireMensuel']),
          jours: [
            for (final j in (m['jours'] is List ? m['jours'] as List : const []))
              if (lireDateIso(j) != null) lireDateIso(j)!,
          ],
        ),
    ];
    final hypotheses = racine['hypothesesViande'] is Map ? racine['hypothesesViande'] as Map : const {};
    int attribuer(int v) => v != 0 ? v : prochainId++;

    return Donnees(
      parametres: Parametres(
        loyerMensuel: _entier(p['loyerMensuel']) ?? defaut.loyerMensuel,
        salairesMensuels: _entier(p['salairesMensuels']) ?? defaut.salairesMensuels,
      ),
      journees: [
        for (final m in _liste(racine['journees']))
          if (lireDateIso(m['date']) != null)
            Journee(
              date: lireDateIso(m['date'])!,
              matin: _entier(m['matin']) ?? 0,
              midi: _entier(m['midi']) ?? 0,
              soir: _entier(m['soir']) ?? 0,
              pate: _entier(m['pate']) ?? 0,
              autre: _entier(m['autre']) ?? 0,
              argentCompte: _entier(m['argentCompte']),
              fondDebut: _entier(m['fondDebut']),
              fondFin: _entier(m['fondFin']),
              remarque: _texte(m['remarque']),
            ),
      ],
      depenses: [for (final x in depenses) x.copier(id: attribuer(x.id))],
      impayes: [
        for (final i in impayes)
          Impaye(
            id: attribuer(i.id),
            date: i.date,
            service: i.service,
            montant: i.montant,
            client: i.client,
            remarque: i.remarque,
            reglements: i.reglements,
          ),
      ],
      remboursements: [
        for (final r in remboursements)
          Remboursement(
            id: attribuer(r.id),
            date: r.date,
            associe: r.associe,
            montant: r.montant,
            payeAvec: r.payeAvec,
            remarque: r.remarque,
          ),
      ],
      produits: [for (final p in produits) p.copier(id: attribuer(p.id))],
      ingredients: [
        for (final m in _liste(racine['ingredients']))
          if (_entier(m['prixKg']) != null) Ingredient(nom: _texte(m['nom']), prixKg: _entier(m['prixKg'])!),
      ],
      employes: [for (final e in employes) e.copier(id: attribuer(e.id))],
      hypothesesViande: {
        for (final h in hypotheses.entries)
          if (h.value is Map)
            h.key.toString(): HypotheseViande(
              prixMorceau: _decimal((h.value as Map)['prixMorceau']),
              morceauxParKg: _decimal((h.value as Map)['morceauxParKg']),
            ),
      },
    );
  }

  static double? _decimal(Object? v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v.replaceAll(',', '.')) : null);

  static List<Map> _liste(Object? v) => v is List ? v.whereType<Map>().toList() : const [];

  static String _texte(Object? v) => v?.toString() ?? '';

  static int? _entier(Object? v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) {
      final c = v.replaceAll(RegExp(r'[^0-9-]'), '');
      return c.isEmpty ? null : int.tryParse(c);
    }
    return null;
  }
}

/// Export CSV lisible par Excel en français : séparateur « ; » et BOM UTF-8
/// pour que les accents s'affichent correctement.
class ExportCsv {
  static String _cellule(Object? v) {
    final s = v is DateTime ? dateIso(v) : (v?.toString() ?? '');
    return s.contains(RegExp('[;"\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  static String _csv(List<String> entete, List<List<Object?>> lignes) =>
      '﻿${[entete, ...lignes].map((l) => l.map(_cellule).join(';')).join('\r\n')}\r\n';

  static String depenses(Donnees d) {
    final triees = [...d.depenses]
      ..sort((a, b) {
        final c = (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return _csv(
      ['Date', 'Article', 'Quantité', 'Montant (F)', 'Payé avec', 'Catégorie', 'Fournisseur', 'Remarque'],
      [
        for (final x in triees)
          [
            x.date,
            x.article,
            x.quantite,
            x.montant,
            x.payeAvec?.libelle,
            x.categorie?.libelle,
            x.fournisseur,
            x.remarque,
          ],
      ],
    );
  }

  static String recettes(Donnees d) => _csv(
    [
      'Date',
      'Matin',
      'Midi',
      'Soir',
      'Pâté',
      'Autre',
      'Total avant sorties',
      'Sortie de caisse',
      'Reste en caisse',
      'Argent compté',
      'Écart',
      'Impayés du jour',
      'Remarque',
    ],
    [
      for (final c in Comptabilite(d).journees())
        [
          c.journee.date,
          c.journee.matin,
          c.journee.midi,
          c.journee.soir,
          c.journee.pate,
          c.journee.autre,
          c.journee.totalAvantSorties,
          c.sortieDeCaisse,
          c.resteEnCaisse,
          c.journee.argentCompte,
          c.ecart,
          c.impayesDuJour,
          c.journee.remarque,
        ],
    ],
  );
}
