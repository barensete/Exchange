import 'package:flutter/material.dart';

import '../../calcul/format.dart';
import '../../donnees/depot.dart';
import '../../modele/modeles.dart';
import '../composants.dart';

/// Onglet « Dépenses » : regroupées par jour, filtrables par « Payé avec ».
class EcranDepenses extends StatefulWidget {
  const EcranDepenses({super.key});

  @override
  State<EcranDepenses> createState() => _EcranDepensesState();
}

class _EcranDepensesState extends State<EcranDepenses> {
  SourcePaiement? _filtre;
  bool _incompletes = false;

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final liste = depot.donnees.depenses
        .where((x) => _filtre == null || x.payeAvec == _filtre)
        .where((x) => !_incompletes || x.estIncomplete)
        .toList();
    // Regroupe par jour, du plus récent au plus ancien ; « sans date » en premier.
    final parJour = <String, List<Depense>>{};
    for (final x in liste) {
      parJour.putIfAbsent(x.date == null ? '' : dateIso(x.date!), () => []).add(x);
    }
    final cles = parJour.keys.toList()..sort((a, b) => a.isEmpty ? -1 : (b.isEmpty ? 1 : b.compareTo(a)));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EcranEditionDepense())),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const TitreOnglet('Dépenses'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Toutes'),
                  selected: _filtre == null && !_incompletes,
                  onSelected: (_) => setState(() {
                    _filtre = null;
                    _incompletes = false;
                  }),
                ),
                for (final s in SourcePaiement.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(s.libelle),
                      selected: _filtre == s,
                      onSelected: (_) => setState(() => _filtre = _filtre == s ? null : s),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: const Text('À corriger'),
                    selected: _incompletes,
                    onSelected: (_) => setState(() => _incompletes = !_incompletes),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('${liste.length} ligne(s) · ${enFcfa(liste.fold<int>(0, (s, x) => s + (x.montant ?? 0)))}'),
          if (liste.isEmpty) const Vide('Aucune dépense.'),
          for (final cle in cles) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cle.isEmpty ? 'Sans date' : enTexte(lireDateIso(cle)),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    enFcfa(parJour[cle]!.fold<int>(0, (s, x) => s + (x.montant ?? 0))),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            for (final x in parJour[cle]!) _CarteDepense(x),
          ],
        ],
      ),
    );
  }
}

class _CarteDepense extends StatelessWidget {
  const _CarteDepense(this.d);
  final Depense d;

  @override
  Widget build(BuildContext context) => Card(
    color: d.estIncomplete ? orange.withValues(alpha: 0.18) : null,
    child: ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EcranEditionDepense(existante: d))),
      title: Row(
        children: [
          Expanded(child: Text(d.article.isEmpty ? '(sans article)' : d.article)),
          Text(d.montant == null ? 'montant ?' : enFcfa(d.montant)),
        ],
      ),
      subtitle: Text(
        [
          if (d.quantite.isNotEmpty) d.quantite,
          d.payeAvec?.libelle ?? 'payé avec ?',
          d.categorie?.libelle ?? 'catégorie ?',
          if (d.fournisseur.isNotEmpty) d.fournisseur,
        ].join(' · '),
      ),
    ),
  );
}

class EcranEditionDepense extends StatefulWidget {
  const EcranEditionDepense({super.key, this.existante, this.date, this.source});

  final Depense? existante;
  final DateTime? date;
  final SourcePaiement? source;

  @override
  State<EcranEditionDepense> createState() => _EcranEditionDepenseState();
}

class _EcranEditionDepenseState extends State<EcranEditionDepense> {
  late Depense _d =
      widget.existante ??
      Depense(
        id: 0,
        date: widget.date ?? DateTime.now(),
        article: '',
        montant: null,
        payeAvec: widget.source,
        categorie: Categorie.achatsAlimentaires,
      );

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final existante = widget.existante;
    List<String> distincts(Iterable<String> v) => (v.where((s) => s.trim().isNotEmpty).toSet().toList()..sort());
    final articles = distincts(depot.donnees.depenses.map((x) => x.article));
    final fournisseurs = distincts(depot.donnees.depenses.map((x) => x.fournisseur));

    return Formulaire(
      titre: existante == null ? 'Nouvelle dépense' : 'Dépense',
      peutEnregistrer: !_d.estIncomplete && _d.article.trim().isNotEmpty,
      enregistrer: () {
        depot.enregistrerDepense(_d.copier(article: _d.article.trim(), fournisseur: _d.fournisseur.trim()));
        Navigator.pop(context);
      },
      supprimer: existante == null
          ? null
          : () async {
              if (await confirmerSuppression(context, 'La dépense « ${existante.article} »')) {
                depot.supprimerDepense(existante);
                if (context.mounted) Navigator.pop(context);
              }
            },
      champs: [
        ChampDate(
          libelle: 'Date',
          date: _d.date,
          onChange: (v) => setState(() => _d = _d.copier(date: v)),
        ),
        ChampSuggestions(
          libelle: 'Article',
          valeur: _d.article,
          suggestions: articles,
          onChange: (v) => setState(() => _d = _d.copier(article: v)),
        ),
        ChampTexte(
          libelle: 'Quantité',
          valeur: _d.quantite,
          onChange: (v) => _d = _d.copier(quantite: v),
        ),
        ChampMontant(
          libelle: 'Montant',
          valeur: _d.montant,
          obligatoire: true,
          onChange: (v) => setState(() => _d = _d.copier(montant: () => v)),
        ),
        ChoixPastilles<SourcePaiement>(
          libelle: 'Payé avec',
          options: SourcePaiement.values,
          choisi: _d.payeAvec,
          texte: (s) => s.libelle,
          onChange: (s) => setState(() => _d = _d.copier(payeAvec: s)),
        ),
        if (_d.payeAvec?.estPersonnel ?? false)
          Text(
            "Argent personnel : l'entreprise aura une dette envers ${_d.payeAvec!.libelle}.",
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
        Selecteur<Categorie>(
          libelle: 'Catégorie',
          options: Categorie.values,
          choisi: _d.categorie,
          texte: (c) => c.libelle,
          onChange: (c) => setState(() => _d = _d.copier(categorie: c)),
        ),
        ChampSuggestions(
          libelle: 'Fournisseur',
          valeur: _d.fournisseur,
          suggestions: fournisseurs,
          onChange: (v) => _d = _d.copier(fournisseur: v),
        ),
        ChampTexte(
          libelle: 'Remarque',
          valeur: _d.remarque,
          lignes: 2,
          onChange: (v) => _d = _d.copier(remarque: v),
        ),
      ],
    );
  }
}
