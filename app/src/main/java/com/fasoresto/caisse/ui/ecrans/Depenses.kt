package com.fasoresto.caisse.ui.ecrans

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
import com.fasoresto.caisse.ui.ChampSuggestions
import com.fasoresto.caisse.ui.ChampTexte
import com.fasoresto.caisse.ui.ChoixPastilles
import com.fasoresto.caisse.ui.ConfirmerSuppression
import com.fasoresto.caisse.ui.Ecran
import com.fasoresto.caisse.ui.EcranAvecBarre
import com.fasoresto.caisse.ui.EcranOnglet
import com.fasoresto.caisse.ui.Etat
import com.fasoresto.caisse.ui.FasoViewModel
import com.fasoresto.caisse.ui.Formulaire
import com.fasoresto.caisse.ui.Navigation
import com.fasoresto.caisse.ui.Selecteur
import com.fasoresto.caisse.ui.Vide
import com.fasoresto.caisse.ui.theme.Orange
import com.fasoresto.core.calcul.enFcfa
import com.fasoresto.core.calcul.enTexte
import com.fasoresto.core.modele.Categorie
import com.fasoresto.core.modele.Depense
import com.fasoresto.core.modele.SourcePaiement
import java.time.LocalDate

/** Onglet « Dépenses » : regroupées par jour, filtrables par « Payé avec ». */
@Composable
fun EcranDepenses(etat: Etat, nav: Navigation, modifier: Modifier) {
    var filtre by remember { mutableStateOf<SourcePaiement?>(null) }
    var incompletes by remember { mutableStateOf(false) }
    val liste = etat.donnees.depenses
        .filter { filtre == null || it.payeAvec == filtre }
        .filter { !incompletes || it.estIncomplete }
    val parJour = liste.groupBy { it.date }.toSortedMap(nullsFirst(reverseOrder()))

    EcranOnglet("Dépenses", modifier, ajouter = { nav.ouvrir(Ecran.EditionDepense(null)) }) {
        item {
            LazyRow {
                item {
                    FilterChip(filtre == null && !incompletes, { filtre = null; incompletes = false }, { Text("Toutes") })
                }
                items(SourcePaiement.entries.toList()) { s ->
                    FilterChip(
                        filtre == s, { filtre = if (filtre == s) null else s }, { Text(s.libelle) },
                        Modifier.padding(start = 8.dp),
                    )
                }
                item {
                    FilterChip(
                        incompletes, { incompletes = !incompletes }, { Text("À corriger") },
                        Modifier.padding(start = 8.dp),
                    )
                }
            }
        }
        item {
            Text(
                "${liste.size} ligne(s) · ${liste.sumOf { it.montant ?: 0 }.enFcfa()}",
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        if (liste.isEmpty()) item { Vide("Aucune dépense.") }
        parJour.forEach { (date, deps) ->
            item {
                Row(Modifier.padding(top = 8.dp)) {
                    Text(date?.enTexte() ?: "Sans date", Modifier.weight(1f), fontWeight = FontWeight.Bold)
                    Text(deps.sumOf { it.montant ?: 0 }.enFcfa(), fontWeight = FontWeight.Bold)
                }
            }
            items(deps, key = { it.id }) { d -> CarteDepense(d) { nav.ouvrir(Ecran.EditionDepense(d.id)) } }
        }
    }
}

@Composable
private fun CarteDepense(d: Depense, ouvrir: () -> Unit) {
    Card(
        Modifier.fillMaxWidth().clickable(onClick = ouvrir),
        colors = if (d.estIncomplete) CardDefaults.cardColors(containerColor = Orange.copy(alpha = 0.18f)) else CardDefaults.cardColors(),
    ) {
        Column(Modifier.padding(12.dp)) {
            Row {
                Text(d.article.ifBlank { "(sans article)" }, Modifier.weight(1f), fontWeight = FontWeight.Medium)
                Text(d.montant?.enFcfa() ?: "montant ?")
            }
            Text(
                listOfNotNull(
                    d.quantite.takeIf { it.isNotBlank() },
                    d.payeAvec?.libelle ?: "payé avec ?",
                    d.categorie?.libelle ?: "catégorie ?",
                    d.fournisseur.takeIf { it.isNotBlank() },
                ).joinToString(" · "),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
fun EcranEditionDepense(etat: Etat, vm: FasoViewModel, nav: Navigation, ecran: Ecran.EditionDepense, modifier: Modifier) {
    val existante = ecran.id?.let { id -> etat.donnees.depenses.firstOrNull { it.id == id } }
    var d by remember(existante) {
        mutableStateOf(
            existante ?: Depense(
                date = ecran.date ?: LocalDate.now(), article = "", montant = null,
                payeAvec = ecran.source, categorie = Categorie.ACHATS_ALIMENTAIRES,
            ),
        )
    }
    var confirmer by remember { mutableStateOf(false) }
    val articles = remember(etat.donnees.depenses) { etat.donnees.depenses.map { it.article }.filter { it.isNotBlank() }.distinct().sorted() }
    val fournisseurs = remember(etat.donnees.depenses) { etat.donnees.depenses.map { it.fournisseur }.filter { it.isNotBlank() }.distinct().sorted() }

    EcranAvecBarre(
        if (existante == null) "Nouvelle dépense" else "Dépense", nav, modifier,
        actions = { if (existante != null) BoutonSupprimer { confirmer = true } },
    ) { marges ->
        Formulaire(marges, peutEnregistrer = !d.estIncomplete && d.article.isNotBlank(), enregistrer = {
            vm.enregistrer(d.copy(article = d.article.trim(), fournisseur = d.fournisseur.trim()))
            nav.retour()
        }) {
            ChampDate("Date", d.date, { d = d.copy(date = it) })
            ChampSuggestions("Article", d.article, articles) { d = d.copy(article = it) }
            ChampTexte("Quantité", d.quantite, { d = d.copy(quantite = it) })
            ChampMontant("Montant", d.montant, { d = d.copy(montant = it) }, obligatoire = true)
            ChoixPastilles("Payé avec", SourcePaiement.entries.toList(), d.payeAvec, { it.libelle }) { d = d.copy(payeAvec = it) }
            if (d.payeAvec?.estPersonnel == true) {
                Text(
                    "Argent personnel : l'entreprise aura une dette envers ${d.payeAvec?.libelle}.",
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary,
                )
            }
            Selecteur("Catégorie", Categorie.entries.toList(), d.categorie, { it.libelle }) { d = d.copy(categorie = it) }
            ChampSuggestions("Fournisseur", d.fournisseur, fournisseurs) { d = d.copy(fournisseur = it) }
            ChampTexte("Remarque", d.remarque, { d = d.copy(remarque = it) }, lignes = 2)
        }
    }

    if (confirmer && existante != null) {
        ConfirmerSuppression(
            "La dépense « ${existante.article} »",
            onConfirmer = { vm.supprimer(existante); confirmer = false; nav.retour() },
            onAnnuler = { confirmer = false },
        )
    }
}
