import 'package:flutter/material.dart';

import '../../calcul/format.dart';
import '../../calcul/salaires.dart';
import '../../donnees/depot.dart';
import '../../modele/modeles.dart';
import '../composants.dart';

/// Salaires par employé et pointage des jours travaillés (onglet « Salaire »).
class EcranPersonnel extends StatefulWidget {
  const EcranPersonnel({super.key});

  @override
  State<EcranPersonnel> createState() => _EcranPersonnelState();
}

class _EcranPersonnelState extends State<EcranPersonnel> {
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);

  void _decaler(int n) => setState(() => _mois = DateTime(_mois.year, _mois.month + n));

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final b = bilanSalaires(depot.donnees, _mois);
    final theme = Theme.of(context);
    void ouvrir(Employe? e) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => EcranEditionEmploye(existant: e)));

    return Scaffold(
      appBar: AppBar(title: const Text('Personnel & salaires')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => EcranPointage(date: DateTime.now()))),
        icon: const Icon(Icons.how_to_reg),
        label: const Text('Pointage du jour'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _decaler(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Mois précédent',
              ),
              Expanded(
                child: Text(nomMois(_mois), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              ),
              IconButton(onPressed: () => _decaler(1), icon: const Icon(Icons.chevron_right), tooltip: 'Mois suivant'),
            ],
          ),
          if (b.employes.isEmpty) const Vide('Aucun employé. Ajoutez-en un ci-dessous ou importez le fichier Excel.'),
          for (final e in b.employes)
            Card(
              child: ListTile(
                onTap: () => ouvrir(e.employe),
                title: Row(
                  children: [
                    Expanded(child: Text(e.employe.nom)),
                    Text(e.employe.salaireMensuel == null ? 'salaire ?' : enFcfa(e.employe.salaireMensuel)),
                  ],
                ),
                subtitle: Text(
                  [
                    if (e.employe.poste.isNotEmpty) e.employe.poste,
                    '${e.joursTravailles} jour(s)',
                    'versé ${enFcfa(e.verse)}',
                    if (e.resteAVerser != null) 'reste ${enFcfa(e.resteAVerser)}',
                  ].join(' · '),
                  style: TextStyle(color: (e.resteAVerser ?? 0) < 0 ? theme.colorScheme.error : null),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => ouvrir(null),
            icon: const Icon(Icons.person_add),
            label: const Text('Ajouter un employé'),
          ),
          const SizedBox(height: 12),
          Section(
            titre: 'Total du mois',
            enfants: [
              LigneMontant('Salaires convenus', b.totalConvenu),
              Text('Jours travaillés : ${b.totalJours}'),
              LigneMontant('Versé aux employés', b.totalAttribue),
              LigneMontant('Reste à verser', b.totalReste, fort: true),
              const Divider(),
              LigneMontant(
                'Écart avec les salaires du bilan',
                b.ecartAvecParametres,
                couleur: b.ecartAvecParametres == 0 ? null : orange,
                detail: 'Salaires convenus − ${enFcfa(b.salairesPrevus)} (Plus → Paramètres)',
              ),
              LigneMontant(
                'Versements sans nom d\'employé',
                b.nonAttribue,
                couleur: b.nonAttribue == 0 ? null : orange,
                detail: 'Dépenses « Personnel / Salaires » dont l\'article ne nomme personne',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Un versement est compté pour un employé quand son nom figure dans l\'article de la dépense, '
            'par exemple « Versement salaire Zineb ».',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Cocher les employés qui ont travaillé un jour donné.
class EcranPointage extends StatefulWidget {
  const EcranPointage({super.key, required this.date});
  final DateTime date;

  @override
  State<EcranPointage> createState() => _EcranPointageState();
}

class _EcranPointageState extends State<EcranPointage> {
  late DateTime _date = jourSeul(widget.date);
  Set<int>? _presents;

  Set<int> _lire(Depot depot) => {
    for (final e in depot.donnees.employes)
      if (e.aTravaille(_date)) e.id,
  };

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final presents = _presents ??= _lire(depot);
    return Formulaire(
      titre: 'Pointage',
      peutEnregistrer: true,
      enregistrer: () {
        depot.pointer(_date, presents);
        Navigator.pop(context);
      },
      champs: [
        ChampDate(
          libelle: 'Date',
          date: _date,
          onChange: (d) => setState(() {
            _date = jourSeul(d);
            _presents = _lire(depot);
          }),
        ),
        if (depot.donnees.employes.isEmpty) const Vide('Aucun employé.'),
        for (final e in depot.donnees.employes)
          CheckboxListTile(
            value: presents.contains(e.id),
            title: Text(e.nom),
            subtitle: e.poste.isEmpty ? null : Text(e.poste),
            onChanged: (v) => setState(() => v == true ? presents.add(e.id) : presents.remove(e.id)),
          ),
      ],
    );
  }
}

class EcranEditionEmploye extends StatefulWidget {
  const EcranEditionEmploye({super.key, this.existant});
  final Employe? existant;

  @override
  State<EcranEditionEmploye> createState() => _EcranEditionEmployeState();
}

class _EcranEditionEmployeState extends State<EcranEditionEmploye> {
  late Employe _e = widget.existant ?? Employe(id: 0, nom: '');

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final existant = widget.existant;
    return Formulaire(
      titre: existant == null ? 'Nouvel employé' : existant.nom,
      peutEnregistrer: _e.nom.trim().isNotEmpty,
      enregistrer: () {
        depot.enregistrerEmploye(_e.copier(nom: _e.nom.trim(), poste: _e.poste.trim()));
        Navigator.pop(context);
      },
      supprimer: existant == null
          ? null
          : () async {
              if (await confirmerSuppression(context, '« ${existant.nom} » et son pointage')) {
                depot.supprimerEmploye(existant);
                if (context.mounted) Navigator.pop(context);
              }
            },
      champs: [
        ChampTexte(
          libelle: 'Nom',
          valeur: _e.nom,
          onChange: (t) => setState(() => _e = _e.copier(nom: t)),
        ),
        ChampTexte(
          libelle: 'Poste',
          valeur: _e.poste,
          onChange: (t) => _e = _e.copier(poste: t),
        ),
        ChampMontant(
          libelle: 'Salaire mensuel convenu',
          valeur: _e.salaireMensuel,
          onChange: (v) => setState(() => _e = _e.copier(salaireMensuel: () => v)),
        ),
        if (existant != null) Text('${existant.jours.length} jour(s) travaillé(s) au total depuis le début.'),
      ],
    );
  }
}
