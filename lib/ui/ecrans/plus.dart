import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../calcul/format.dart';
import '../../donnees/depot.dart';
import '../../io/import_excel.dart';
import '../../io/sauvegarde.dart';
import '../../modele/modeles.dart';
import '../composants.dart';
import 'menu.dart';
import 'personnel.dart';
import 'viande.dart';

/// Reprend l'historique du classeur Excel « Comptabilité Faso Resto » (.xlsx).
Future<void> importerExcel(BuildContext context) =>
    _importer(context, (f) async => ImportExcel.lire(await f.xFile.readAsBytes()));

/// Recharge une sauvegarde .json faite avec l'application.
Future<void> importerSauvegarde(BuildContext context) =>
    _importer(context, (f) async => Sauvegarde.importer(await f.xFile.readAsString()));

Future<void> _importer(BuildContext context, Future<Donnees> Function(PlatformFile) lire) async {
  final depot = DepotScope.de(context);
  final vide = depot.donnees.journees.isEmpty && depot.donnees.depenses.isEmpty;
  if (!vide) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer ?'),
        content: const Text(
          'Toutes les données actuelles du téléphone seront remplacées par celles du fichier. '
          "Faites d'abord une sauvegarde si besoin.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Choisir le fichier')),
        ],
      ),
    );
    if (ok != true) return;
  }
  try {
    final fichier = await FilePicker.pickFile();
    if (fichier == null) return;
    final d = await lire(fichier);
    await depot.remplacerTout(d);
    if (context.mounted) {
      message(
        context,
        '${d.journees.length} journées, ${d.depenses.length} dépenses, ${d.impayes.length} impayés '
        'et ${d.remboursements.length} remboursements importés',
      );
    }
  } catch (e) {
    if (context.mounted) message(context, 'Import impossible : $e');
  }
}

class EcranPlus extends StatelessWidget {
  const EcranPlus({super.key});

  void _ouvrir(BuildContext context, Widget ecran) => Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));

  /// Écrit le fichier puis ouvre le menu Partager (WhatsApp, Drive, e-mail…).
  Future<void> _partager(BuildContext context, String nom, String contenu) async {
    try {
      final dossier = await getTemporaryDirectory();
      final fichier = File('${dossier.path}/$nom');
      await fichier.writeAsString(contenu, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(fichier.path)], title: nom));
    } catch (e) {
      if (context.mounted) message(context, 'Erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final jour = dateIso(DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TitreOnglet('Plus'),
        const SizedBox(height: 12),
        _Entree(
          Icons.trending_up,
          'Bilans',
          'Par mois, semaine, jour, et analyse viande & poisson',
          () => _ouvrir(context, const EcranBilans()),
        ),
        _Entree(
          Icons.handshake,
          'Remboursements',
          'Argent rendu à Barka et Fodié',
          () => _ouvrir(context, const EcranRemboursements()),
        ),
        _Entree(
          Icons.restaurant_menu,
          'Menu & prix de vente',
          'Plats, prix, coût matière visé à 30 %',
          () => _ouvrir(context, const EcranMenu()),
        ),
        _Entree(
          Icons.badge,
          'Personnel & salaires',
          'Employés, pointage, versé et reste à verser',
          () => _ouvrir(context, const EcranPersonnel()),
        ),
        _Entree(
          Icons.settings,
          'Paramètres',
          'Loyer et salaires mensuels',
          () => _ouvrir(context, const EcranParametres()),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text('Sauvegarde', style: Theme.of(context).textTheme.titleMedium),
        ),
        _Entree(
          Icons.upload,
          'Enregistrer une sauvegarde',
          'Fichier .json à garder sur Drive ou WhatsApp',
          () => _partager(context, 'fasoresto-$jour.json', Sauvegarde.exporter(depot.donnees)),
        ),
        _Entree(
          Icons.table_view,
          'Exporter les dépenses (Excel)',
          'Fichier .csv lisible dans Excel',
          () => _partager(context, 'depenses-$jour.csv', ExportCsv.depenses(depot.donnees)),
        ),
        _Entree(
          Icons.table_chart,
          'Exporter les recettes (Excel)',
          'Fichier .csv lisible dans Excel',
          () => _partager(context, 'recettes-$jour.csv', ExportCsv.recettes(depot.donnees)),
        ),
        _Entree(
          Icons.download,
          'Importer une sauvegarde',
          'Fichier .json : remplace toutes les données du téléphone',
          () => importerSauvegarde(context),
        ),
        _Entree(
          Icons.grid_on,
          'Importer le fichier Excel',
          '« Comptabilité Faso Resto » (.xlsx) : remplace toutes les données',
          () => importerExcel(context),
        ),
      ],
    );
  }
}

class _Entree extends StatelessWidget {
  const _Entree(this.icone, this.titre, this.sousTitre, this.onTap);
  final IconData icone;
  final String titre, sousTitre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(leading: Icon(icone), title: Text(titre), subtitle: Text(sousTitre), onTap: onTap),
  );
}

// ---------------------------------------------------------------- Remboursements

class EcranRemboursements extends StatelessWidget {
  const EcranRemboursements({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final r = depot.compta.resume();
    final liste = [...depot.donnees.remboursements]..sort((a, b) => b.date.compareTo(a.date));
    void ouvrir(Remboursement? x) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => EcranEditionRemboursement(existant: x)));

    return Scaffold(
      appBar: AppBar(title: const Text('Remboursements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ouvrir(null),
        icon: const Icon(Icons.handshake),
        label: const Text('Rembourser'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Section(
            titre: "Ce que l'entreprise doit encore",
            enfants: [
              for (final a in Associe.values) LigneMontant(a.libelle, r.detteParAssocie[a]),
              LigneMontant('Partagé (à répartir)', r.dettePartagee),
            ],
          ),
          const SizedBox(height: 8),
          if (liste.isEmpty) const Vide('Aucun remboursement.'),
          for (final x in liste)
            Card(
              child: ListTile(
                onTap: () => ouvrir(x),
                title: Row(
                  children: [
                    Expanded(child: Text('${enTexte(x.date)} · ${x.associe.libelle}')),
                    Text(enFcfa(x.montant)),
                  ],
                ),
                subtitle: Text(
                  'Payé avec ${x.payeAvec.libelle}${x.remarque.isEmpty ? '' : ' · ${x.remarque}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EcranEditionRemboursement extends StatefulWidget {
  const EcranEditionRemboursement({super.key, this.existant});
  final Remboursement? existant;

  @override
  State<EcranEditionRemboursement> createState() => _EcranEditionRemboursementState();
}

class _EcranEditionRemboursementState extends State<EcranEditionRemboursement> {
  late Remboursement _r =
      widget.existant ??
      Remboursement(
        id: 0,
        date: DateTime.now(),
        associe: Associe.barka,
        montant: 0,
        payeAvec: SourcePaiement.tresorerie,
      );

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final existant = widget.existant;
    return Formulaire(
      titre: existant == null ? 'Nouveau remboursement' : 'Remboursement',
      peutEnregistrer: _r.montant > 0,
      enregistrer: () {
        depot.enregistrerRemboursement(_r);
        Navigator.pop(context);
      },
      supprimer: existant == null
          ? null
          : () async {
              if (await confirmerSuppression(context, 'Ce remboursement')) {
                depot.supprimerRemboursement(existant);
                if (context.mounted) Navigator.pop(context);
              }
            },
      champs: [
        ChampDate(
          libelle: 'Date',
          date: _r.date,
          onChange: (d) => setState(() => _r = _r.copier(date: d)),
        ),
        ChoixPastilles<Associe>(
          libelle: 'À qui',
          options: Associe.values,
          choisi: _r.associe,
          texte: (a) => a.libelle,
          onChange: (a) => setState(() => _r = _r.copier(associe: a)),
        ),
        ChampMontant(
          libelle: 'Montant',
          valeur: _r.montant == 0 ? null : _r.montant,
          obligatoire: true,
          onChange: (v) => setState(() => _r = _r.copier(montant: v ?? 0)),
        ),
        ChoixPastilles<SourcePaiement>(
          libelle: 'Payé avec',
          options: const [SourcePaiement.caisse, SourcePaiement.tresorerie],
          choisi: _r.payeAvec,
          texte: (s) => s.libelle,
          onChange: (s) => setState(() => _r = _r.copier(payeAvec: s)),
        ),
        ChampTexte(
          libelle: 'Remarque',
          valeur: _r.remarque,
          lignes: 2,
          onChange: (t) => _r = _r.copier(remarque: t),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Bilans

class EcranBilans extends StatelessWidget {
  const EcranBilans({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DepotScope.de(context).compta;
    const marge = EdgeInsets.all(16);
    Widget espace(BuildContext _, int _) => const SizedBox(height: 12);

    final mois = c.bilansParMois();
    final semaines = c.bilansParSemaine();
    final jours = c.bilansParJour();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bilans'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mois'),
              Tab(text: 'Semaines'),
              Tab(text: 'Jours'),
              Tab(text: 'Viande'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView.separated(
              padding: marge,
              itemCount: mois.length + 1,
              separatorBuilder: espace,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const Text(
                    'Loyer et salaires appliqués aux mois qui ont des recettes (modifiables dans Paramètres).',
                  );
                }
                final m = mois[i - 1];
                return Section(
                  titre: nomMois(m.mois),
                  enfants: [
                    LigneMontant('Recette', m.recette),
                    LigneMontant('Dépenses', m.depenses),
                    LigneMontant('   dont matériel & équipement', m.depensesMateriel),
                    LigneMontant('Loyer', m.loyer),
                    LigneMontant('Salaires', m.salaires),
                    LigneMontant(
                      'Résultat après charges',
                      m.resultatApresCharges,
                      fort: true,
                      couleur: couleurResultat(context, m.resultatApresCharges),
                    ),
                    LigneMontant(
                      'Résultat hors matériel',
                      m.resultatHorsMateriel,
                      couleur: couleurResultat(context, m.resultatHorsMateriel),
                    ),
                    if (m.joursOuverts > 0) ...[
                      const Divider(),
                      LigneMontant(
                        'Recette moyenne par jour',
                        m.recetteMoyenneParJour,
                        detail: '${m.joursOuverts} journée(s) de caisse saisie(s)',
                      ),
                      Text('Recette par service', style: Theme.of(context).textTheme.titleSmall),
                      for (final e in m.recetteParService.entries)
                        if (e.value > 0) LigneJauge(e.key.libelle, e.value, m.recette),
                    ],
                    if (m.depensesParCategorie.isNotEmpty) ...[
                      const Divider(),
                      Text('Dépenses par catégorie', style: Theme.of(context).textTheme.titleSmall),
                      for (final e in m.depensesParCategorie.entries) LigneJauge(e.key.libelle, e.value, m.depenses),
                    ],
                  ],
                );
              },
            ),
            ListView.separated(
              padding: marge,
              itemCount: semaines.length,
              separatorBuilder: espace,
              itemBuilder: (context, i) {
                final s = semaines[i];
                return Section(
                  titre: 'Semaine du ${enTexte(s.debut)} au ${enTexte(s.fin)}',
                  enfants: [
                    LigneMontant('Recette', s.recette),
                    LigneMontant('Dépenses', s.depenses),
                    LigneMontant('Résultat', s.resultat, fort: true, couleur: couleurResultat(context, s.resultat)),
                    LigneMontant(
                      'Achats viande & foie',
                      s.achatsViande,
                      detail: '${enPourcent(s.partViande)} de la recette',
                    ),
                  ],
                );
              },
            ),
            ListView.separated(
              padding: marge,
              itemCount: jours.length,
              separatorBuilder: espace,
              itemBuilder: (context, i) {
                final j = jours[i];
                return Section(
                  titre: enTexte(j.date),
                  enfants: [
                    LigneMontant('Recette (avant sorties)', j.recette),
                    LigneMontant('Dépenses du jour', j.depenses),
                    LigneMontant(
                      'Recette − dépenses',
                      j.resultat,
                      fort: true,
                      couleur: couleurResultat(context, j.resultat),
                    ),
                    LigneMontant('Dont argent personnel', j.depensesArgentPersonnel),
                    if (j.achatsViande > 0)
                      LigneMontant('Achats viande & foie', j.achatsViande, detail: enPourcent(j.partViande)),
                  ],
                );
              },
            ),
            const OngletViande(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Paramètres

class EcranParametres extends StatefulWidget {
  const EcranParametres({super.key});

  @override
  State<EcranParametres> createState() => _EcranParametresState();
}

class _EcranParametresState extends State<EcranParametres> {
  Parametres? _p;

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.de(context);
    final p = _p ??= depot.donnees.parametres;
    return Formulaire(
      titre: 'Paramètres',
      peutEnregistrer: true,
      enregistrer: () {
        depot.enregistrerParametres(p);
        Navigator.pop(context);
      },
      champs: [
        const Text('Charges mensuelles utilisées dans le bilan par mois.'),
        ChampMontant(
          libelle: 'Loyer mensuel',
          valeur: p.loyerMensuel,
          onChange: (v) => setState(() => _p = Parametres(loyerMensuel: v ?? 0, salairesMensuels: p.salairesMensuels)),
        ),
        ChampMontant(
          libelle: 'Salaires mensuels',
          valeur: p.salairesMensuels,
          onChange: (v) => setState(() => _p = Parametres(loyerMensuel: p.loyerMensuel, salairesMensuels: v ?? 0)),
        ),
      ],
    );
  }
}
