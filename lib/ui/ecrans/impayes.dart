import 'package:flutter/material.dart';

import '../../calcul/format.dart';
import '../../donnees/depot.dart';
import '../../modele/modeles.dart';
import '../composants.dart';

/// Onglet « Impayés » : ce que les clients doivent encore, puis les impayés réglés.
class EcranImpayes extends StatelessWidget {
  const EcranImpayes({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final tous = [...depot.donnees.impayes]
      ..sort((a, b) {
        final c = (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    final ouverts = tous.where((i) => !i.estSolde).toList();
    final soldes = tous.where((i) => i.estSolde).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EcranEditionImpaye())),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const TitreOnglet('Impayés clients'),
          const SizedBox(height: 12),
          Section(
            titre: 'À recevoir',
            enfants: [
              LigneMontant('Total restant dû', ouverts.fold<int>(0, (s, i) => s + i.resteDu), fort: true),
              Text('${ouverts.length} impayé(s) en cours'),
            ],
          ),
          if (ouverts.isEmpty) const Vide('Aucun impayé en cours.'),
          for (final i in ouverts) _CarteImpaye(i),
          if (soldes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text('Réglés', style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final i in soldes) _CarteImpaye(i),
          ],
        ],
      ),
    );
  }
}

class _CarteImpaye extends StatelessWidget {
  const _CarteImpaye(this.i);
  final Impaye i;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EcranEditionImpaye(existant: i))),
        title: Row(
          children: [
            Expanded(
              child: Text(
                [
                  enTexte(i.date),
                  if (i.service != null) i.service!.libelle,
                  if (i.client.isNotEmpty) i.client,
                ].join(' · '),
              ),
            ),
            Text(i.estSolde ? 'Réglé' : enFcfa(i.resteDu), style: TextStyle(color: i.estSolde ? cs.primary : cs.error)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i.montantRegle > 0 && !i.estSolde)
              Text('${enFcfa(i.montantRegle)} déjà reçus sur ${enFcfa(i.montant)}'),
            if (i.remarque.isNotEmpty) Text(i.remarque, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class EcranEditionImpaye extends StatefulWidget {
  const EcranEditionImpaye({super.key, this.existant});
  final Impaye? existant;

  @override
  State<EcranEditionImpaye> createState() => _EcranEditionImpayeState();
}

class _EcranEditionImpayeState extends State<EcranEditionImpaye> {
  late Impaye _i = widget.existant ?? Impaye(id: 0, date: DateTime.now(), service: null, montant: null);

  Future<void> _ajouterPaiement(Depot depot) async {
    final r = await showDialog<Reglement>(context: context, builder: (_) => _DialoguePaiement(_i.resteDu));
    if (r == null) return;
    setState(() => _i = _i.copier(reglements: [..._i.reglements, r]));
    await depot.enregistrerImpaye(_i);
  }

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final existant = widget.existant;

    return Formulaire(
      titre: existant == null ? 'Nouvel impayé' : 'Impayé',
      peutEnregistrer: !_i.estIncomplet,
      enregistrer: () {
        depot.enregistrerImpaye(_i);
        Navigator.pop(context);
      },
      supprimer: existant == null
          ? null
          : () async {
              if (await confirmerSuppression(context, 'Cet impayé')) {
                depot.supprimerImpaye(existant);
                if (context.mounted) Navigator.pop(context);
              }
            },
      champs: [
        ChampDate(
          libelle: 'Date de la vente',
          date: _i.date,
          onChange: (d) => setState(() => _i = _i.copier(date: d)),
        ),
        ChoixPastilles<Service>(
          libelle: 'Service',
          options: Service.values,
          choisi: _i.service,
          texte: (s) => s.libelle,
          onChange: (s) => setState(() => _i = _i.copier(service: s)),
        ),
        ChampMontant(
          libelle: 'Montant à crédit',
          valeur: _i.montant,
          obligatoire: true,
          onChange: (v) => setState(() => _i = _i.copier(montant: () => v)),
        ),
        ChampTexte(
          libelle: 'Client (nom ou téléphone)',
          valeur: _i.client,
          onChange: (t) => _i = _i.copier(client: t),
        ),
        ChampTexte(
          libelle: 'Remarque',
          valeur: _i.remarque,
          lignes: 2,
          onChange: (t) => _i = _i.copier(remarque: t),
        ),
        // Les paiements ne sont possibles qu'une fois l'impayé enregistré.
        if (existant != null)
          Section(
            titre: 'Paiements reçus',
            enfants: [
              for (final r in _i.reglements) LigneMontant('Reçu le ${enTexte(r.date)}', r.montant),
              LigneMontant('Reste dû', _i.resteDu, fort: true),
              if (!_i.estSolde && !_i.estIncomplet)
                OutlinedButton(onPressed: () => _ajouterPaiement(depot), child: const Text('Enregistrer un paiement')),
              if (_i.reglements.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _i = _i.copier(reglements: _i.reglements.sublist(0, _i.reglements.length - 1)));
                    depot.enregistrerImpaye(_i);
                  },
                  child: const Text('Annuler le dernier paiement'),
                ),
            ],
          ),
      ],
    );
  }
}

/// Paiement total ou partiel : remplace la ligne « Autre » du classeur.
class _DialoguePaiement extends StatefulWidget {
  const _DialoguePaiement(this.resteDu);
  final int resteDu;

  @override
  State<_DialoguePaiement> createState() => _DialoguePaiementState();
}

class _DialoguePaiementState extends State<_DialoguePaiement> {
  late int? _montant = widget.resteDu;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Paiement reçu'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChampMontant(
          libelle: 'Montant reçu',
          valeur: _montant,
          obligatoire: true,
          onChange: (v) => setState(() => _montant = v),
        ),
        const SizedBox(height: 12),
        ChampDate(libelle: 'Date', date: _date, onChange: (d) => setState(() => _date = d)),
        const SizedBox(height: 8),
        Text('Reste dû : ${enFcfa(widget.resteDu)}'),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      TextButton(
        onPressed: (_montant ?? 0) > 0
            ? () => Navigator.pop(
                context,
                Reglement(date: _date, montant: _montant! > widget.resteDu ? widget.resteDu : _montant!),
              )
            : null,
        child: const Text('Valider'),
      ),
    ],
  );
}
