import 'package:flutter/material.dart';

import '../../calcul/comptabilite.dart';
import '../../calcul/format.dart';
import '../../donnees/depot.dart';
import '../../modele/modeles.dart';
import '../composants.dart';
import 'depenses.dart';

void ouvrirJournee(BuildContext context, DateTime? date) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => EcranEditionJournee(date: date)));

/// Onglet « Recettes » : une carte par journée, la plus récente en haut.
class EcranCaisse extends StatelessWidget {
  const EcranCaisse({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final jours = depot.compta.journees().reversed.toList();
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ouvrirJournee(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const TitreOnglet('Caisse du jour'),
          const SizedBox(height: 12),
          if (jours.isEmpty) const Vide('Aucune journée saisie. Appuyez sur « Ajouter ».'),
          for (final j in jours)
            Card(
              child: ListTile(
                onTap: () => ouvrirJournee(context, j.journee.date),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(enTexte(j.journee.date), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Text(enFcfa(j.journee.totalAvantSorties), style: theme.textTheme.titleMedium),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sortie ${enFcfa(j.sortieDeCaisse)} · Reste ${enFcfa(j.resteEnCaisse)}'
                      '${j.impayesDuJour > 0 ? ' · Crédit ${enFcfa(j.impayesDuJour)}' : ''}',
                    ),
                    if (j.ecart != null)
                      Text(
                        j.ecart == 0 ? 'Caisse juste ✓' : 'Écart ${enFcfa(j.ecart)}',
                        style: TextStyle(color: couleurEcart(context, j.ecart!)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Saisie d'une journée : services, argent compté, fond de caisse. Tout le reste se calcule.
class EcranEditionJournee extends StatefulWidget {
  const EcranEditionJournee({super.key, this.date});

  /// Date à ouvrir ; null pour une nouvelle journée.
  final DateTime? date;

  @override
  State<EcranEditionJournee> createState() => _EcranEditionJourneeState();
}

class _EcranEditionJourneeState extends State<EcranEditionJournee> {
  Journee? _existante;
  late Journee _j;
  bool _pret = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pret) return;
    final d = widget.date;
    _existante = d == null
        ? null
        : DepotScope.de(context).donnees.journees.where((j) => memeJour(j.date, d)).firstOrNull;
    _j = _existante ?? Journee(date: d ?? DateTime.now());
    _pret = true;
  }

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final existante = _existante;
    final calcul = Comptabilite(depot.donnees).journee(_j);
    final dejaPrise = existante == null && depot.donnees.journees.any((x) => memeJour(x.date, _j.date));
    final achats = depot.donnees.depenses
        .where((x) => memeJour(x.date, _j.date) && x.payeAvec == SourcePaiement.caisse)
        .toList();
    int? nonNul(int v) => v == 0 ? null : v;
    final soustitre = Theme.of(context).textTheme.titleSmall;

    return Formulaire(
      titre: 'Caisse du ${enTexte(_j.date)}',
      peutEnregistrer: !dejaPrise,
      enregistrer: () {
        depot.enregistrerJournee(_j);
        Navigator.pop(context);
      },
      supprimer: existante == null
          ? null
          : () async {
              if (await confirmerSuppression(context, 'La journée du ${enTexte(existante.date)}')) {
                depot.supprimerJournee(existante);
                if (context.mounted) Navigator.pop(context);
              }
            },
      champs: [
        if (existante == null) ...[
          ChampDate(
            libelle: 'Date',
            date: _j.date,
            onChange: (d) => setState(() => _j = _j.copier(date: d)),
          ),
          if (dejaPrise)
            Text(
              'Cette date est déjà saisie : ouvrez-la depuis la liste.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
        Text('Recette AVANT sorties, par service', style: soustitre),
        ChampMontant(
          libelle: 'Matin',
          valeur: nonNul(_j.matin),
          onChange: (v) => setState(() => _j = _j.copier(matin: v ?? 0)),
        ),
        ChampMontant(
          libelle: 'Midi',
          valeur: nonNul(_j.midi),
          onChange: (v) => setState(() => _j = _j.copier(midi: v ?? 0)),
        ),
        ChampMontant(
          libelle: 'Soir',
          valeur: nonNul(_j.soir),
          onChange: (v) => setState(() => _j = _j.copier(soir: v ?? 0)),
        ),
        ChampMontant(
          libelle: 'Pâté',
          valeur: nonNul(_j.pate),
          onChange: (v) => setState(() => _j = _j.copier(pate: v ?? 0)),
        ),
        ChampMontant(
          libelle: 'Non détaillée / autre',
          valeur: nonNul(_j.autre),
          onChange: (v) => setState(() => _j = _j.copier(autre: v ?? 0)),
        ),
        Section(
          titre: 'Calcul automatique',
          enfants: [
            LigneMontant('Total avant sorties', _j.totalAvantSorties, fort: true),
            LigneMontant('Sortie de caisse', calcul.sortieDeCaisse, detail: 'Achats du jour payés avec « Caisse »'),
            LigneMontant('Reste en caisse', calcul.resteEnCaisse, fort: true),
            LigneMontant('Impayés du jour (à crédit)', calcul.impayesDuJour),
            LigneMontant('Recette + impayés', calcul.recettePlusImpayes),
            if (achats.isNotEmpty) const Divider(),
            for (final a in achats) LigneMontant('• ${a.article}', a.montant),
            OutlinedButton.icon(
              // La saisie en cours reste à l'écran pendant l'ajout de l'achat.
              onPressed: dejaPrise
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EcranEditionDepense(date: _j.date, source: SourcePaiement.caisse),
                      ),
                    ),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Ajouter un achat payé par la caisse'),
            ),
          ],
        ),
        Text('Fin de journée', style: soustitre),
        ChampMontant(
          libelle: 'Argent compté (fin de journée)',
          valeur: _j.argentCompte,
          onChange: (v) => setState(() => _j = _j.copier(argentCompte: () => v)),
        ),
        if (calcul.ecart != null)
          LigneMontant(
            'Écart (compté − reste)',
            calcul.ecart,
            fort: true,
            couleur: couleurEcart(context, calcul.ecart!),
          ),
        ChampMontant(
          libelle: 'Fond de caisse début',
          valeur: _j.fondDebut,
          onChange: (v) => setState(() => _j = _j.copier(fondDebut: () => v)),
        ),
        ChampMontant(
          libelle: 'Fond de caisse fin',
          valeur: _j.fondFin,
          onChange: (v) => setState(() => _j = _j.copier(fondFin: () => v)),
        ),
        ChampTexte(
          libelle: 'Remarque',
          valeur: _j.remarque,
          lignes: 3,
          onChange: (t) => _j = _j.copier(remarque: t),
        ),
      ],
    );
  }
}
