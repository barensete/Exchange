import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../calcul/comptabilite.dart';
import '../io/sauvegarde.dart';
import '../modele/modeles.dart';

/// Garde toutes les données du restaurant et les enregistre sur le téléphone
/// (un fichier JSON au même format que la sauvegarde). Les écrans l'écoutent
/// et se redessinent à chaque changement.
class Depot extends ChangeNotifier {
  Depot._(this._fichier, this._donnees);

  final File? _fichier;
  Donnees _donnees;
  Comptabilite? _compta;
  Future<void> _ecriture = Future.value();

  Donnees get donnees => _donnees;
  Comptabilite get compta => _compta ??= Comptabilite(_donnees);

  /// Ouvre les données enregistrées sur le téléphone.
  static Future<Depot> ouvrir() async {
    final dossier = await getApplicationDocumentsDirectory();
    final fichier = File('${dossier.path}/fasoresto.json');
    var donnees = const Donnees();
    if (await fichier.exists()) {
      donnees = Sauvegarde.importer(await fichier.readAsString());
    }
    return Depot._(fichier, donnees);
  }

  /// Dépôt en mémoire, sans fichier (pour les tests).
  @visibleForTesting
  factory Depot.enMemoire([Donnees donnees = const Donnees()]) => Depot._(null, donnees);

  Future<void> _modifier(Donnees nouvelles) async {
    _donnees = nouvelles;
    _compta = null;
    notifyListeners();
    final f = _fichier;
    if (f == null) return;
    // Les écritures passent l'une après l'autre. Écriture sûre : fichier
    // temporaire puis renommage, pour ne jamais laisser un fichier à moitié
    // écrit si le téléphone s'éteint.
    _ecriture = _ecriture.catchError((_) {}).then((_) async {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(Sauvegarde.exporter(nouvelles), flush: true);
      await tmp.rename(f.path);
    });
    return _ecriture;
  }

  // ------------------------------------------------------------ Journées

  Future<void> enregistrerJournee(Journee j) =>
      _modifier(_donnees.copier(journees: [..._donnees.journees.where((x) => !memeJour(x.date, j.date)), j]));

  Future<void> supprimerJournee(Journee j) =>
      _modifier(_donnees.copier(journees: _donnees.journees.where((x) => !memeJour(x.date, j.date)).toList()));

  // ------------------------------------------------------------ Dépenses

  /// Ajoute (id = 0) ou remplace une dépense.
  Future<void> enregistrerDepense(Depense d) {
    final avecId = d.id == 0 ? d.copier(id: _donnees.prochainId) : d;
    return _modifier(_donnees.copier(depenses: _remplacer(_donnees.depenses, avecId, (x) => x.id)));
  }

  Future<void> supprimerDepense(Depense d) =>
      _modifier(_donnees.copier(depenses: _donnees.depenses.where((x) => x.id != d.id).toList()));

  // ------------------------------------------------------------ Impayés

  Future<void> enregistrerImpaye(Impaye i) {
    final avecId = i.id == 0
        ? Impaye(
            id: _donnees.prochainId,
            date: i.date,
            service: i.service,
            montant: i.montant,
            client: i.client,
            remarque: i.remarque,
            reglements: i.reglements,
          )
        : i;
    return _modifier(_donnees.copier(impayes: _remplacer(_donnees.impayes, avecId, (x) => x.id)));
  }

  Future<void> supprimerImpaye(Impaye i) =>
      _modifier(_donnees.copier(impayes: _donnees.impayes.where((x) => x.id != i.id).toList()));

  // ------------------------------------------------------------ Remboursements

  Future<void> enregistrerRemboursement(Remboursement r) {
    final avecId = r.id == 0
        ? Remboursement(
            id: _donnees.prochainId,
            date: r.date,
            associe: r.associe,
            montant: r.montant,
            payeAvec: r.payeAvec,
            remarque: r.remarque,
          )
        : r;
    return _modifier(_donnees.copier(remboursements: _remplacer(_donnees.remboursements, avecId, (x) => x.id)));
  }

  Future<void> supprimerRemboursement(Remboursement r) =>
      _modifier(_donnees.copier(remboursements: _donnees.remboursements.where((x) => x.id != r.id).toList()));

  // ------------------------------------------------------------ Menu

  Future<void> enregistrerProduit(Produit p) {
    final avecId = p.id == 0 ? p.copier(id: _donnees.prochainId) : p;
    return _modifier(_donnees.copier(produits: _remplacer(_donnees.produits, avecId, (x) => x.id)));
  }

  Future<void> supprimerProduit(Produit p) =>
      _modifier(_donnees.copier(produits: _donnees.produits.where((x) => x.id != p.id).toList()));

  /// Ajoute ou met à jour le prix au kg d'un ingrédient (même nom = même ingrédient).
  Future<void> enregistrerIngredient(Ingredient i, {String? ancienNom}) {
    final cle = (ancienNom ?? i.nom).toLowerCase();
    final liste = [..._donnees.ingredients];
    final idx = liste.indexWhere((x) => x.nom.toLowerCase() == cle);
    if (idx < 0) {
      liste.add(i);
    } else {
      liste[idx] = i;
    }
    return _modifier(_donnees.copier(ingredients: liste));
  }

  Future<void> supprimerIngredient(Ingredient i) =>
      _modifier(_donnees.copier(ingredients: _donnees.ingredients.where((x) => x.nom != i.nom).toList()));

  // ------------------------------------------------------------ Personnel

  Future<void> enregistrerEmploye(Employe e) {
    final avecId = e.id == 0 ? e.copier(id: _donnees.prochainId) : e;
    return _modifier(_donnees.copier(employes: _remplacer(_donnees.employes, avecId, (x) => x.id)));
  }

  Future<void> supprimerEmploye(Employe e) =>
      _modifier(_donnees.copier(employes: _donnees.employes.where((x) => x.id != e.id).toList()));

  /// Pointage d'une journée : [presents] = identifiants des employés qui ont travaillé.
  Future<void> pointer(DateTime date, Set<int> presents) => _modifier(
    _donnees.copier(
      employes: [
        for (final e in _donnees.employes)
          e.copier(
            jours: [...e.jours.where((j) => !memeJour(j, date)), if (presents.contains(e.id)) jourSeul(date)]..sort(),
          ),
      ],
    ),
  );

  // ------------------------------------------------------------ Analyse viande

  Future<void> enregistrerHypothese(String type, HypotheseViande h) =>
      _modifier(_donnees.copier(hypothesesViande: {..._donnees.hypothesesViande, type: h}));

  // ------------------------------------------------------------ Divers

  Future<void> enregistrerParametres(Parametres p) => _modifier(_donnees.copier(parametres: p));

  /// Remplace toutes les données (import d'une sauvegarde ou de l'Excel converti).
  Future<void> remplacerTout(Donnees d) => _modifier(d);

  static List<T> _remplacer<T>(List<T> liste, T element, int Function(T) id) {
    final i = liste.indexWhere((x) => id(x) == id(element));
    if (i < 0) return [...liste, element];
    return [...liste]..[i] = element;
  }
}

/// Donne accès au [Depot] à tous les écrans : `DepotScope.de(context)`.
class DepotScope extends InheritedNotifier<Depot> {
  const DepotScope({super.key, required Depot depot, required super.child}) : super(notifier: depot);

  static Depot de(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DepotScope>()!.notifier!;
}
