package com.fasoresto.caisse.ui.ecrans

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
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
import com.fasoresto.core.modele.Impaye
import com.fasoresto.core.modele.Reglement
import com.fasoresto.core.modele.Service
import java.time.LocalDate

/** Onglet « Impayés » : ce que les clients doivent encore, puis l'historique des impayés soldés. */
@Composable
fun EcranImpayes(etat: Etat, nav: Navigation, modifier: Modifier) {
    val (soldes, ouverts) = etat.donnees.impayes
        .sortedWith(compareByDescending<Impaye> { it.date }.thenByDescending { it.id })
        .partition { it.estSolde }

    EcranOnglet("Impayés clients", modifier, ajouter = { nav.ouvrir(Ecran.EditionImpaye(null)) }) {
        item {
            Section("À recevoir") {
                LigneMontant("Total restant dû", ouverts.sumOf { it.resteDu }, fort = true)
                Text("${ouverts.size} impayé(s) en cours", style = MaterialTheme.typography.bodySmall)
            }
        }
        if (ouverts.isEmpty()) item { Vide("Aucun impayé en cours.") }
        items(ouverts, key = { it.id }) { CarteImpaye(it) { nav.ouvrir(Ecran.EditionImpaye(it.id)) } }
        if (soldes.isNotEmpty()) {
            item { Text("Réglés", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 8.dp)) }
            items(soldes, key = { it.id }) { CarteImpaye(it) { nav.ouvrir(Ecran.EditionImpaye(it.id)) } }
        }
    }
}

@Composable
private fun CarteImpaye(i: Impaye, ouvrir: () -> Unit) {
    Card(Modifier.fillMaxWidth().clickable(onClick = ouvrir)) {
        Column(Modifier.padding(12.dp)) {
            Row {
                Text(
                    listOfNotNull(i.date?.enTexte(), i.service?.libelle, i.client.takeIf { it.isNotBlank() }).joinToString(" · "),
                    Modifier.weight(1f), fontWeight = FontWeight.Medium,
                )
                Text(if (i.estSolde) "Réglé" else i.resteDu.enFcfa(), color = if (i.estSolde) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
            }
            if (i.montantRegle > 0 && !i.estSolde) {
                Text("${i.montantRegle.enFcfa()} déjà reçus sur ${i.montant?.enFcfa()}", style = MaterialTheme.typography.bodySmall)
            }
            if (i.remarque.isNotBlank()) {
                Text(i.remarque, style = MaterialTheme.typography.bodySmall, maxLines = 2, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
fun EcranEditionImpaye(etat: Etat, vm: FasoViewModel, nav: Navigation, id: Long?, modifier: Modifier) {
    val existant = id?.let { x -> etat.donnees.impayes.firstOrNull { it.id == x } }
    var i by remember(existant) { mutableStateOf(existant ?: Impaye(date = LocalDate.now(), service = null, montant = null)) }
    var confirmer by remember { mutableStateOf(false) }
    var paiement by remember { mutableStateOf(false) }

    EcranAvecBarre(
        if (existant == null) "Nouvel impayé" else "Impayé", nav, modifier,
        actions = { if (existant != null) BoutonSupprimer { confirmer = true } },
    ) { marges ->
        Formulaire(marges, peutEnregistrer = !i.estIncomplet, enregistrer = { vm.enregistrer(i); nav.retour() }) {
            ChampDate("Date de la vente", i.date, { i = i.copy(date = it) })
            ChoixPastilles("Service", Service.entries.toList(), i.service, { it.libelle }) { i = i.copy(service = it) }
            ChampMontant("Montant à crédit", i.montant, { i = i.copy(montant = it) }, obligatoire = true)
            ChampTexte("Client (nom ou téléphone)", i.client, { i = i.copy(client = it) })
            ChampTexte("Remarque", i.remarque, { i = i.copy(remarque = it) }, lignes = 2)

            if (existant != null) {
                Section("Paiements reçus") {
                    existant.reglements.forEach { r -> LigneMontant("Reçu le ${r.date.enTexte()}", r.montant) }
                    LigneMontant("Reste dû", existant.resteDu, fort = true)
                    if (!existant.estSolde) {
                        OutlinedButton(onClick = { paiement = true }, modifier = Modifier.fillMaxWidth()) {
                            Text("Enregistrer un paiement")
                        }
                    }
                    if (existant.reglements.isNotEmpty()) {
                        TextButton(onClick = { vm.supprimer(existant.reglements.last()) }) {
                            Text("Annuler le dernier paiement")
                        }
                    }
                }
            }
        }
    }

    if (paiement && existant != null) {
        DialoguePaiement(
            resteDu = existant.resteDu,
            onValider = { r -> vm.ajouterReglement(existant, r); paiement = false },
            onAnnuler = { paiement = false },
        )
    }
    if (confirmer && existant != null) {
        ConfirmerSuppression(
            "Cet impayé",
            onConfirmer = { vm.supprimer(existant); confirmer = false; nav.retour() },
            onAnnuler = { confirmer = false },
        )
    }
}

/** Paiement total ou partiel : remplace la ligne « Autre » du classeur. */
@Composable
private fun DialoguePaiement(resteDu: Long, onValider: (Reglement) -> Unit, onAnnuler: () -> Unit) {
    var montant by remember { mutableStateOf<Long?>(resteDu) }
    var date by remember { mutableStateOf(LocalDate.now()) }
    AlertDialog(
        onDismissRequest = onAnnuler,
        title = { Text("Paiement reçu") },
        text = {
            Column {
                ChampMontant("Montant reçu", montant, { montant = it }, obligatoire = true)
                ChampDate("Date", date, { date = it })
                Text("Reste dû : ${resteDu.enFcfa()}", style = MaterialTheme.typography.bodySmall)
            }
        },
        confirmButton = {
            TextButton(
                onClick = { montant?.let { onValider(Reglement(date = date, montant = it.coerceAtMost(resteDu))) } },
                enabled = (montant ?: 0) > 0,
            ) { Text("Valider") }
        },
        dismissButton = { TextButton(onClick = onAnnuler) { Text("Annuler") } },
    )
}
