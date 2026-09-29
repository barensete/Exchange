package com.fasoresto.caisse.ui.ecrans

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Handshake
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.TableView
import androidx.compose.material.icons.filled.Upload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.fasoresto.caisse.ui.BoutonSupprimer
import com.fasoresto.caisse.ui.ChampDate
import com.fasoresto.caisse.ui.ChampMontant
import com.fasoresto.caisse.ui.ChampTexte
import com.fasoresto.caisse.ui.ChoixPastilles
import com.fasoresto.caisse.ui.ConfirmerSuppression
import com.fasoresto.caisse.ui.Ecran
import com.fasoresto.caisse.ui.EcranAvecBarre
import com.fasoresto.caisse.ui.EcranOnglet
import com.fasoresto.caisse.ui.Etat
import com.fasoresto.caisse.ui.FasoViewModel
import com.fasoresto.caisse.ui.Formulaire
import com.fasoresto.caisse.ui.LigneMontant
import com.fasoresto.caisse.ui.Navigation
import com.fasoresto.caisse.ui.Section
import com.fasoresto.caisse.ui.Vide
import com.fasoresto.core.calcul.enFcfa
import com.fasoresto.core.calcul.enTexte
import com.fasoresto.core.modele.Associe
import com.fasoresto.core.modele.Remboursement
import com.fasoresto.core.modele.SourcePaiement
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun EcranPlus(vm: FasoViewModel, nav: Navigation, modifier: Modifier) {
    val aujourdhui = LocalDate.now()
    val sauver = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        uri?.let(vm::exporterSauvegarde)
    }
    val csv = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        uri?.let(vm::exporterCsv)
    }
    var confirmerImport by remember { mutableStateOf(false) }
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let(vm::importerSauvegarde)
    }

    EcranOnglet("Plus", modifier) {
        item { Entree(Icons.AutoMirrored.Filled.TrendingUp, "Bilans", "Par jour, par semaine, par mois") { nav.ouvrir(Ecran.Bilans) } }
        item { Entree(Icons.Filled.Handshake, "Remboursements", "Argent rendu à Barka et Fodié") { nav.ouvrir(Ecran.Remboursements) } }
        item { Entree(Icons.Filled.Settings, "Paramètres", "Loyer et salaires mensuels") { nav.ouvrir(Ecran.Parametres) } }
        item { Text("Sauvegarde", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 8.dp)) }
        item {
            Entree(Icons.Filled.Upload, "Enregistrer une sauvegarde", "Fichier .json à garder sur Drive ou WhatsApp") {
                sauver.launch("fasoresto-$aujourdhui.json")
            }
        }
        item {
            Entree(Icons.Filled.TableView, "Exporter les dépenses (Excel)", "Fichier .csv lisible dans Excel") {
                csv.launch("depenses-$aujourdhui.csv")
            }
        }
        item {
            Entree(Icons.Filled.Download, "Importer une sauvegarde", "Remplace toutes les données du téléphone") {
                confirmerImport = true
            }
        }
    }

    if (confirmerImport) {
        AlertDialog(
            onDismissRequest = { confirmerImport = false },
            title = { Text("Importer ?") },
            text = { Text("Toutes les données actuelles du téléphone seront remplacées par celles du fichier. Faites d'abord une sauvegarde si besoin.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmerImport = false
                    importer.launch(arrayOf("application/json", "application/octet-stream", "text/plain"))
                }) { Text("Choisir le fichier") }
            },
            dismissButton = { TextButton(onClick = { confirmerImport = false }) { Text("Annuler") } },
        )
    }
}

@Composable
private fun Entree(icone: ImageVector, titre: String, sousTitre: String, onClick: () -> Unit) {
    Card(Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        ListItem(
            headlineContent = { Text(titre) },
            supportingContent = { Text(sousTitre) },
            leadingContent = { Icon(icone, null) },
        )
    }
}

// ---------------------------------------------------------------- Remboursements

@Composable
fun EcranRemboursements(etat: Etat, nav: Navigation, modifier: Modifier) {
    val r = etat.compta.resume()
    val liste = etat.donnees.remboursements.sortedByDescending { it.date }
    EcranAvecBarre(
        "Remboursements", nav, modifier,
        boutonFlottant = {
            ExtendedFloatingActionButton(
                onClick = { nav.ouvrir(Ecran.EditionRemboursement(null)) },
                icon = { Icon(Icons.Filled.Handshake, null) },
                text = { Text("Rembourser") },
            )
        },
    ) { marges ->
        LazyColumn(
            Modifier.padding(marges),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Section("Ce que l'entreprise doit encore") {
                    Associe.entries.forEach { a -> LigneMontant(a.libelle, r.detteParAssocie[a]) }
                    LigneMontant("Partagé (à répartir)", r.dettePartagee)
                }
            }
            if (liste.isEmpty()) item { Vide("Aucun remboursement.") }
            items(liste, key = { it.id }) { rb ->
                Card(Modifier.fillMaxWidth().clickable { nav.ouvrir(Ecran.EditionRemboursement(rb.id)) }) {
                    Column(Modifier.padding(12.dp)) {
                        Row {
                            Text("${rb.date.enTexte()} · ${rb.associe.libelle}", Modifier.weight(1f), fontWeight = FontWeight.Medium)
                            Text(rb.montant.enFcfa())
                        }
                        Text(
                            "Payé avec ${rb.payeAvec.libelle}" + if (rb.remarque.isNotBlank()) " · ${rb.remarque}" else "",
                            style = MaterialTheme.typography.bodySmall, maxLines = 2,
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun EcranEditionRemboursement(etat: Etat, vm: FasoViewModel, nav: Navigation, id: Long?, modifier: Modifier) {
    val existant = id?.let { x -> etat.donnees.remboursements.firstOrNull { it.id == x } }
    var r by remember(existant) {
        mutableStateOf(existant ?: Remboursement(date = LocalDate.now(), associe = Associe.BARKA, montant = 0, payeAvec = SourcePaiement.TRESORERIE))
    }
    var confirmer by remember { mutableStateOf(false) }
    EcranAvecBarre(
        if (existant == null) "Nouveau remboursement" else "Remboursement", nav, modifier,
        actions = { if (existant != null) BoutonSupprimer { confirmer = true } },
    ) { marges ->
        Formulaire(marges, peutEnregistrer = r.montant > 0, enregistrer = { vm.enregistrer(r); nav.retour() }) {
            ChampDate("Date", r.date, { r = r.copy(date = it) })
            ChoixPastilles("À qui", Associe.entries.toList(), r.associe, { it.libelle }) { r = r.copy(associe = it) }
            ChampMontant("Montant", r.montant.takeIf { it > 0 }, { r = r.copy(montant = it ?: 0) }, obligatoire = true)
            ChoixPastilles("Payé avec", listOf(SourcePaiement.CAISSE, SourcePaiement.TRESORERIE), r.payeAvec, { it.libelle }) {
                r = r.copy(payeAvec = it)
            }
            ChampTexte("Remarque", r.remarque, { r = r.copy(remarque = it) }, lignes = 2)
        }
    }
    if (confirmer && existant != null) {
        ConfirmerSuppression(
            "Ce remboursement",
            onConfirmer = { vm.supprimer(existant); confirmer = false; nav.retour() },
            onAnnuler = { confirmer = false },
        )
    }
}

// ---------------------------------------------------------------- Bilans

private val MOIS = DateTimeFormatter.ofPattern("MMMM yyyy", Locale.FRENCH)

private fun Double?.enPourcent() = this?.let { "%.1f %%".format(Locale.FRENCH, it * 100) } ?: "—"

@Composable
fun EcranBilans(etat: Etat, nav: Navigation, modifier: Modifier) {
    var onglet by remember { mutableIntStateOf(0) }
    val c = etat.compta
    EcranAvecBarre("Bilans", nav, modifier) { marges ->
        Column(Modifier.padding(marges)) {
            TabRow(selectedTabIndex = onglet) {
                listOf("Mois", "Semaines", "Jours").forEachIndexed { i, t ->
                    Tab(selected = onglet == i, onClick = { onglet = i }, text = { Text(t) })
                }
            }
            LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                when (onglet) {
                    0 -> {
                        item {
                            Text(
                                "Loyer et salaires appliqués aux mois qui ont des recettes (modifiables dans Paramètres).",
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                        items(c.bilansParMois()) { m ->
                            Section(m.mois.format(MOIS).replaceFirstChar { it.uppercase() }) {
                                LigneMontant("Recette", m.recette)
                                LigneMontant("Dépenses", m.depenses)
                                LigneMontant("   dont matériel & équipement", m.depensesMateriel)
                                LigneMontant("Loyer", m.loyer)
                                LigneMontant("Salaires", m.salaires)
                                LigneMontant("Résultat après charges", m.resultatApresCharges, fort = true, couleur = couleurResultat(m.resultatApresCharges))
                                LigneMontant("Résultat hors matériel", m.resultatHorsMateriel, couleur = couleurResultat(m.resultatHorsMateriel))
                            }
                        }
                    }
                    1 -> items(c.bilansParSemaine()) { s ->
                        Section("Semaine du ${s.debut.enTexte()} au ${s.fin.enTexte()}") {
                            LigneMontant("Recette", s.recette)
                            LigneMontant("Dépenses", s.depenses)
                            LigneMontant("Résultat", s.resultat, fort = true, couleur = couleurResultat(s.resultat))
                            LigneMontant("Achats viande & foie", s.achatsViande, detail = "${s.partViande.enPourcent()} de la recette")
                        }
                    }
                    else -> items(c.bilansParJour()) { j ->
                        Section(j.date.enTexte()) {
                            LigneMontant("Recette (avant sorties)", j.recette)
                            LigneMontant("Dépenses du jour", j.depenses)
                            LigneMontant("Recette − dépenses", j.resultat, fort = true, couleur = couleurResultat(j.resultat))
                            LigneMontant("Dont argent personnel", j.depensesArgentPersonnel)
                            if (j.achatsViande > 0) LigneMontant("Achats viande & foie", j.achatsViande, detail = j.partViande.enPourcent())
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun couleurResultat(v: Long) = if (v >= 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error

// ---------------------------------------------------------------- Paramètres

@Composable
fun EcranParametres(etat: Etat, vm: FasoViewModel, nav: Navigation, modifier: Modifier) {
    var p by remember(etat.donnees.parametres) { mutableStateOf(etat.donnees.parametres) }
    EcranAvecBarre("Paramètres", nav, modifier) { marges ->
        Formulaire(marges, peutEnregistrer = true, enregistrer = { vm.enregistrer(p); nav.retour() }) {
            Text("Charges mensuelles utilisées dans le bilan par mois.", style = MaterialTheme.typography.bodyMedium)
            ChampMontant("Loyer mensuel", p.loyerMensuel, { p = p.copy(loyerMensuel = it ?: 0) })
            ChampMontant("Salaires mensuels", p.salairesMensuels, { p = p.copy(salairesMensuels = it ?: 0) })
        }
    }
}
