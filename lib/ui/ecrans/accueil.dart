import 'package:flutter/material.dart';

import '../../calcul/format.dart';
import '../../donnees/depot.dart';
import '../../modele/modeles.dart';
import '../composants.dart';
import 'caisse.dart';
import 'plus.dart';

/// Équivalent de l'onglet « Résumé » du classeur, plus la caisse du jour.
class EcranAccueil extends StatelessWidget {
  const EcranAccueil({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final r = depot.compta.resume();
    final theme = Theme.of(context);
    final aujourdhui = jourSeul(DateTime.now());
    final saisie = depot.donnees.journees.where((j) => memeJour(j.date, aujourdhui)).firstOrNull;
    final jour = saisie == null ? null : depot.compta.journee(saisie);
    final derniere = depot.donnees.journees.isEmpty
        ? null
        : depot.donnees.journees.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    final petit = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TitreOnglet('FasoResto'),
        const SizedBox(height: 12),
        if (depot.donnees.journees.isEmpty && depot.donnees.depenses.isEmpty) ...[
          Section(
            titre: 'Bienvenue',
            enfants: [
              const Text(
                "Aucune donnée pour l'instant. Vous pouvez reprendre tout l'historique de votre "
                'classeur Excel « Comptabilité Faso Resto » en une fois.',
              ),
              FilledButton.icon(
                onPressed: () => importerExcel(context),
                icon: const Icon(Icons.grid_on),
                label: const Text('Importer mon fichier Excel'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Section(
          titre: "Aujourd'hui",
          enfants: [
            if (jour == null)
              const Text("La caisse du jour n'est pas encore saisie.")
            else ...[
              LigneMontant('Recette (avant sorties)', jour.journee.totalAvantSorties),
              LigneMontant('Sortie de caisse', jour.sortieDeCaisse),
              LigneMontant('Reste en caisse', jour.resteEnCaisse, fort: true),
              if (jour.ecart != null)
                LigneMontant('Écart (compté − reste)', jour.ecart, couleur: couleurEcart(context, jour.ecart!)),
            ],
            FilledButton(
              onPressed: () => ouvrirJournee(context, aujourdhui),
              child: Text(jour == null ? 'Saisir la caisse du jour' : 'Modifier la caisse du jour'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Section(
          titre: 'Recettes',
          enfants: [
            LigneMontant('Total recette (avant sorties)', r.totalRecette, fort: true),
            LigneMontant('Impayés clients à recevoir', r.impayesARecevoir, detail: 'Vendu à crédit, pas encore reçu'),
            if (depot.donnees.journees.length >= 2) ...[
              Text('Recette des 14 dernières journées', style: petit),
              GraphiqueRecettes(depot.compta.dernieresJournees(14)),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Section(
          titre: 'Dépenses',
          enfants: [
            LigneMontant('Total dépenses', r.totalDepenses, fort: true),
            for (final s in SourcePaiement.values)
              LigneMontant(switch (s) {
                SourcePaiement.caisse => '   payées par la Caisse',
                SourcePaiement.tresorerie => '   payées par la Trésorerie',
                SourcePaiement.partage => '   avancées à deux (Partagé)',
                _ => '   avancées par ${s.libelle}',
              }, r.depensesParSource[s]),
          ],
        ),
        const SizedBox(height: 12),
        Section(
          titre: "Dettes de l'entreprise",
          enfants: [
            for (final a in Associe.values)
              LigneMontant('Dette envers ${a.libelle}', r.detteParAssocie[a], detail: 'Avancé − remboursé'),
            LigneMontant('Dette partagée (Barka + Fodié)', r.dettePartagee),
            const Divider(),
            LigneMontant('Total des dettes', r.totalDettes, fort: true),
          ],
        ),
        const SizedBox(height: 12),
        Section(
          titre: 'Argent disponible',
          enfants: [
            LigneMontant('Argent réellement disponible', r.argentDisponible, fort: true),
            Text(
              'Recette − dépenses Caisse − dépenses Trésorerie − remboursements versés. '
              'Les avances personnelles sont des dettes, non retranchées ici.',
              style: petit,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Section(
          titre: 'Contrôles',
          enfants: [
            LigneMontant('Écart de caisse cumulé', r.ecartCumule, couleur: couleurEcart(context, r.ecartCumule)),
            Text('Jours de caisse comptée : ${r.joursCaisseComptee} / ${depot.donnees.journees.length}'),
            if (r.depensesDateSuspecte > 0)
              Text(
                '${r.depensesDateSuspecte} dépense(s) avec une date suspecte (avant l\'ouverture ou dans le futur)',
                style: const TextStyle(color: orange),
              ),
            if (r.depensesACorriger > 0)
              Text('${r.depensesACorriger} dépense(s) incomplète(s) à corriger', style: const TextStyle(color: orange)),
            if (r.impayesACorriger > 0)
              Text('${r.impayesACorriger} impayé(s) incomplet(s) à corriger', style: const TextStyle(color: orange)),
            OutlinedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EcranBilans())),
              child: const Text('Voir les bilans (jour, semaine, mois)'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Dernière journée saisie : '
          '${derniere == null ? 'aucune' : '${enTexte(derniere.date)} — ${enFcfa(derniere.totalAvantSorties)}'}',
          style: petit,
        ),
      ],
    );
  }
}
