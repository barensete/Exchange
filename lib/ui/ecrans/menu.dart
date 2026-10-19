import 'package:flutter/material.dart';

import '../../calcul/format.dart';
import '../../calcul/menu.dart';
import '../../donnees/depot.dart';
import '../../modele/modeles.dart';
import '../composants.dart';

/// Menu et prix de vente, avec le coût matière visé à 30 % (onglet « Prix de vente »).
class EcranMenu extends StatelessWidget {
  const EcranMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final menu = Menu(depot.donnees);
    final rubriques = menu.parRubrique();
    final theme = Theme.of(context);
    void ouvrir(Produit? p) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => EcranEditionProduit(existant: p)));

    return Scaffold(
      appBar: AppBar(title: const Text('Menu & prix de vente')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ouvrir(null),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un plat'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Coût matière visé : 30 % du prix de vente au maximum. Saisissez le coût matière de chaque plat '
            'pour voir sa part ; en rouge, le plat coûte trop cher à produire.',
            style: theme.textTheme.bodySmall,
          ),
          if (rubriques.isEmpty)
            const Vide('Aucun plat. Appuyez sur « Ajouter un plat » ou importez le fichier Excel.'),
          for (final r in rubriques.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(r.key.isEmpty ? 'Sans rubrique' : r.key, style: theme.textTheme.titleMedium),
            ),
            for (final p in r.value)
              Card(
                child: ListTile(
                  onTap: () => ouvrir(p.produit),
                  title: Row(
                    children: [
                      Expanded(child: Text(p.produit.nom)),
                      Text(p.produit.prix == null ? 'prix à fixer' : enFcfa(p.produit.prix)),
                    ],
                  ),
                  subtitle: Text(
                    [
                      if (p.coutEnPart != null) 'coût ${enPourcent(p.coutEnPart)}',
                      if (p.coutMax != null) 'coût max ${enFcfa(p.coutMax)}',
                      if (p.poidsMaxGrammes != null) '${p.produit.ingredient} ≤ ${p.poidsMaxGrammes} g',
                    ].join(' · '),
                    style: TextStyle(color: p.tropCher ? theme.colorScheme.error : null),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          const _Ingredients(),
        ],
      ),
    );
  }
}

/// Prix d'achat de référence (F par kg) des ingrédients principaux.
class _Ingredients extends StatelessWidget {
  const _Ingredients();

  Future<void> _modifier(BuildContext context, Ingredient? existant) async {
    final depot = DepotScope.de(context);
    var nom = existant?.nom ?? '';
    int? prix = existant?.prixKg;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existant == null ? 'Nouvel ingrédient' : existant.nom),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChampTexte(libelle: 'Ingrédient', valeur: nom, onChange: (t) => nom = t),
            const SizedBox(height: 12),
            ChampMontant(libelle: 'Prix par kg', valeur: prix, onChange: (v) => prix = v),
          ],
        ),
        actions: [
          if (existant != null)
            TextButton(
              onPressed: () {
                depot.supprimerIngredient(existant);
                Navigator.pop(context, false);
              },
              child: Text('Supprimer', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true && nom.trim().isNotEmpty && prix != null) {
      await depot.enregistrerIngredient(
        Ingredient(nom: nom.trim(), prixKg: prix!),
        ancienNom: existant?.nom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = DepotScope.de(context).donnees.ingredients;
    return Section(
      titre: "Prix d'achat de référence",
      enfants: [
        for (final i in ingredients)
          InkWell(
            onTap: () => _modifier(context, i),
            child: LigneMontant(i.nom, i.prixKg, detail: 'par kg'),
          ),
        OutlinedButton.icon(
          onPressed: () => _modifier(context, null),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un ingrédient'),
        ),
        Text(
          "Astuce : le coût moyen au kg de vos achats est dans Bilans → Viande.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class EcranEditionProduit extends StatefulWidget {
  const EcranEditionProduit({super.key, this.existant});
  final Produit? existant;

  @override
  State<EcranEditionProduit> createState() => _EcranEditionProduitState();
}

class _EcranEditionProduitState extends State<EcranEditionProduit> {
  late Produit _p = widget.existant ?? Produit(id: 0, rubrique: '', nom: '');

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final existant = widget.existant;
    final calcul = Menu(depot.donnees).calculer(_p);
    final rubriques = {...depot.donnees.produits.map((x) => x.rubrique).where((r) => r.isNotEmpty)}.toList();
    final ingredients = depot.donnees.ingredients.map((i) => i.nom).toList();

    return Formulaire(
      titre: existant == null ? 'Nouveau plat' : 'Plat',
      peutEnregistrer: _p.nom.trim().isNotEmpty,
      enregistrer: () {
        depot.enregistrerProduit(
          _p.copier(nom: _p.nom.trim(), rubrique: _p.rubrique.trim(), ingredient: _p.ingredient.trim()),
        );
        Navigator.pop(context);
      },
      supprimer: existant == null
          ? null
          : () async {
              if (await confirmerSuppression(context, 'Le plat « ${existant.nom} »')) {
                depot.supprimerProduit(existant);
                if (context.mounted) Navigator.pop(context);
              }
            },
      champs: [
        ChampSuggestions(
          libelle: 'Rubrique (Petit déjeuner, Déjeuner…)',
          valeur: _p.rubrique,
          suggestions: rubriques,
          onChange: (t) => setState(() => _p = _p.copier(rubrique: t)),
        ),
        ChampTexte(
          libelle: 'Nom du plat',
          valeur: _p.nom,
          onChange: (t) => setState(() => _p = _p.copier(nom: t)),
        ),
        ChampMontant(
          libelle: 'Prix de vente',
          valeur: _p.prix,
          onChange: (v) => setState(() => _p = _p.copier(prix: () => v)),
        ),
        ChampMontant(
          libelle: 'Coût matière estimé (une portion)',
          valeur: _p.coutMatiere,
          onChange: (v) => setState(() => _p = _p.copier(coutMatiere: () => v)),
        ),
        ChampSuggestions(
          libelle: 'Ingrédient principal',
          valeur: _p.ingredient,
          suggestions: ingredients,
          onChange: (t) => setState(() => _p = _p.copier(ingredient: t)),
        ),
        ChampTexte(
          libelle: 'Remarque',
          valeur: _p.remarque,
          lignes: 2,
          onChange: (t) => _p = _p.copier(remarque: t),
        ),
        Section(
          titre: 'Calcul automatique',
          enfants: [
            Row(
              children: [
                const Expanded(child: Text('Coût en % du prix')),
                Text(
                  enPourcent(calcul.coutEnPart),
                  style: TextStyle(color: calcul.tropCher ? Theme.of(context).colorScheme.error : null),
                ),
              ],
            ),
            LigneMontant('Coût max à 30 %', calcul.coutMax),
            Row(
              children: [
                const Expanded(child: Text("Poids max d'ingrédient à 30 %")),
                Text(calcul.poidsMaxGrammes == null ? '—' : '${calcul.poidsMaxGrammes} g'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
