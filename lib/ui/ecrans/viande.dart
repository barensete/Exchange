import 'package:flutter/material.dart';

import '../../calcul/format.dart';
import '../../calcul/viande.dart';
import '../../donnees/depot.dart';
import '../../modele/modeles.dart';
import '../composants.dart';

String _jours(double? v) => v == null ? '—' : '${v.toStringAsFixed(1).replaceAll('.', ',')} j';
String _nombre(double? v) => v == null ? '—' : v.toStringAsFixed(1).replaceAll('.', ',');

/// Analyse viande & poisson : achats, fréquence, coûts et rentabilité.
/// Tout se calcule à partir des dépenses (articles « Viande… », « Foie… », « Poulet… », « Poisson… »).
class OngletViande extends StatelessWidget {
  const OngletViande({super.key});

  Future<void> _hypothese(BuildContext context, String type, HypotheseViande h) async {
    final depot = DepotScope.de(context);
    final prix = TextEditingController(text: h.prixMorceau == null ? '' : _nombre(h.prixMorceau));
    final morceaux = TextEditingController(text: h.morceauxParKg == null ? '' : _nombre(h.morceauxParKg));
    double? lire(String t) => double.tryParse(t.trim().replaceAll(',', '.'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: prix,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix de vente par morceau (F)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: morceaux,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Morceaux par kg', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true) {
      await depot.enregistrerHypothese(
        type,
        HypotheseViande(prixMorceau: lire(prix.text), morceauxParKg: lire(morceaux.text)),
      );
    }
    prix.dispose();
    morceaux.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = AnalyseViande(DepotScope.de(context).donnees);
    final petit = Theme.of(context).textTheme.bodySmall;
    if (a.achats.isEmpty) {
      return const Vide('Aucun achat de viande ou de poisson dans les dépenses.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Section(
          titre: 'Achats par type',
          enfants: [
            for (final t in a.parType.where((t) => t.nombre > 0)) ...[
              Text(t.type, style: const TextStyle(fontWeight: FontWeight.bold)),
              LigneJauge('${t.nombre} achat(s) · ${enKg(t.kg)}', t.cout, a.coutTotal),
              Text(
                'Coût moyen ${enFcfaDecimal(t.coutParKg)}/kg · 1 achat tous les ${_jours(t.frequenceJours)}'
                ' · ${t.kgParSemaine == null ? '—' : enKg(t.kgParSemaine)} par semaine',
                style: petit,
              ),
              const SizedBox(height: 4),
            ],
            const Divider(),
            LigneMontant('Total viande & poisson', a.coutTotal, fort: true),
            Text(
              '${a.nombreTotal} achats · ${enKg(a.kgTotal)} · coût moyen ${enFcfaDecimal(a.coutParKgTotal)}/kg · '
              '${a.kgParSemaineTotal == null ? '—' : enKg(a.kgParSemaineTotal)} par semaine',
              style: petit,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Section(
          titre: 'Rentabilité théorique',
          enfants: [
            Text(
              'Si toute la viande achetée était vendue en morceaux. Touchez un type pour changer le prix par morceau '
              'et le nombre de morceaux par kg (à confirmer).',
              style: petit,
            ),
            for (final r in a.rentabilite().where((r) => r.achats.nombre > 0))
              InkWell(
                onTap: () => _hypothese(context, r.achats.type, r.hypothese),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.achats.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const Icon(Icons.edit, size: 16),
                        ],
                      ),
                      if (!r.chiffree)
                        Text('Hypothèses à saisir', style: petit)
                      else ...[
                        Text(
                          '${enFcfaDecimal(r.hypothese.prixMorceau)} le morceau · ${_nombre(r.hypothese.morceauxParKg)} morceaux/kg'
                          ' · coût ${enFcfaDecimal(r.coutParMorceau)}/morceau · seuil ${_nombre(r.seuilMorceauxParKg)} morceaux/kg',
                          style: petit,
                        ),
                        LigneMontant('CA théorique', r.caTheorique?.round()),
                        LigneMontant(
                          'Marge théorique (${enPourcent(r.tauxMarge)})',
                          r.margeTheorique?.round(),
                          couleur: couleurResultat(context, (r.margeTheorique ?? 0).round()),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const Divider(),
            LigneMontant('CA théorique total', a.caTheoriqueTotal.round(), fort: true),
            LigneMontant(
              'Marge théorique totale',
              a.margeTheoriqueTotale.round(),
              couleur: couleurResultat(context, a.margeTheoriqueTotale.round()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Section(
          titre: 'Comparaison avec le chiffre d\'affaires réel',
          enfants: [
            Text('Du ${enTexte(a.debut)} au ${enTexte(a.fin)} (${_nombre(a.semaines)} semaines)', style: petit),
            LigneMontant('CA réel (total avant sorties)', a.caReel, fort: true),
            LigneMontant('   dont Pâté', a.caPate),
            LigneMontant('CA réel hors Pâté', a.caReel - a.caPate),
            LigneMontant('Coût viande & poisson', a.coutTotal, detail: '${enPourcent(a.coutEnPartDuCa)} du CA réel'),
            LigneMontant(
              'CA théorique viande & poisson',
              a.caTheoriqueTotal.round(),
              detail: '${enPourcent(a.caTheoriqueEnPartDuCa)} du CA réel',
            ),
            LigneMontant(
              'Écart CA réel − CA théorique',
              (a.caReel - a.caTheoriqueTotal).round(),
              detail: 'Positif : les autres produits (riz, boissons, pâté…) rapportent en plus de la viande',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Section(
          titre: 'Détail des achats',
          enfants: [
            for (final x in [...a.achats]..sort((p, q) => q.depense.date!.compareTo(p.depense.date!)))
              LigneMontant(
                '${enTexte(x.depense.date)} · ${x.depense.article}',
                x.depense.montant,
                detail: '${x.type} · ${x.kg == null ? 'poids inconnu' : enKg(x.kg)}',
              ),
          ],
        ),
      ],
    );
  }
}
